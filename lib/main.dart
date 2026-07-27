import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'config/app_router.dart';
import 'core/perf/cold_start_tracer.dart';
import 'core/perf/startup_phases.dart';
import 'core/perf/perf_service.dart';
import 'core/security/anti_tamper_service.dart';
import 'core/security/audit_logger.dart';
import 'core/security/play_integrity_service.dart';
import 'core/theme/theme.dart';
import 'core/localization/localization_service.dart';
import 'features/auth/domain/entities/app_user.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/couple/presentation/providers/couple_providers.dart';
import 'features/notifications/data/services/onesignal_service.dart';
import 'features/notifications/presentation/providers/onesignal_providers.dart';
import 'features/settings/presentation/providers/font_scale_provider.dart';
import 'features/settings/presentation/providers/notification_providers.dart';
import 'services/checkin_reminder_service.dart';
import 'services/foreground_notification_service.dart';
import 'services/background_refresh_service.dart';
import 'services/local_reminder_service.dart';
import 'services/local_notification_inbox_service.dart';
import 'features/notifications/domain/entities/notification_item.dart';

/// Top-level navigator key used to route from notifications that
/// fire when the app is already in the foreground. We can't get a
/// [BuildContext] from a static notification callback, so we use
/// this key as a stable handle and push the target screen directly.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigatorKey');

Future<void> main() async {
  // Cold-start tracer starts ticking as soon as we enter main().
  ColdStartTracer.instance.mark('main_enter');

  // Pre-phase 1: Flutter binding + system chrome (always cheap).
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.backgroundPrimary,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  ColdStartTracer.instance.mark('binding_ready');

  // Phase 1 must complete BEFORE the first frame is painted, so we
  // cap it at work that absolutely has to run synchronously. We split
  // initialization into two waves so the dependency order is explicit:
  //
  //   1. Firebase.initializeApp  — everything else depends on this
  //   2. All other phase-1 tasks — run in parallel once Firebase is up
  //
  // Running (2) in parallel was the bug that caused
  // "No Firebase App '[DEFAULT]' has been created" — Firestore
  // persistence was being set before Firebase.initializeApp() finished.
  await _initFirebase();

  StartupPhases.instance
    ..addPhase1(_initLocalization)
    ..addPhase1(_initFirestorePersistence)
    ..addPhase1(_initWorkManager)
    ..addPhase1(_initCrashlytics);

  // Schedule phase-2 work. Anything user-facing but not strictly
  // needed for the first frame goes here: OneSignal, audit log,
  // integrity probe, notification re-arming.
  StartupPhases.instance
    ..addPhase2(_initOneSignal)
    ..addPhase2(_initAuditLog)
    ..addPhase2(_probeIntegrity)
    ..addPhase2(_probeAntiTamper);

  await StartupPhases.instance.runPhase1();
  ColdStartTracer.instance.mark('phase1_done');

  runApp(
    const ProviderScope(
      child: LoveHubApp(),
    ),
  );

  // Phase 2 runs after the first frame is on-screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ColdStartTracer.instance.mark('first_frame');

    // Record cold-start gap to Firebase Performance.
    final gap = ColdStartTracer.instance.longestGap();
    if (gap != null) {
      PerfService.instance.recordMetric('cold_start_gap_ms', gap.ms);
    }

    StartupPhases.instance.runPhase2();
  });
}

// ─── Phase 1 (must finish ≤ 800 ms total) ────────────────────────────────
Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Enable Crashlytics. In debug mode it collects nothing; in release
  // it uploads crash reports to Firebase Console.
  if (!kDebugMode) {
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }
  ColdStartTracer.instance.mark('firebase_ready');
}

Future<void> _initCrashlytics() async {
  // FlutterError → Crashlytics (fatal). Non-fatal errors are caught
  // by the SafeErrorBoundary and reported via this.
  if (!kDebugMode) {
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
  }
}

Future<void> _initLocalization() async {
  await EasyLocalization.ensureInitialized();
  // DateFormat() needs the intl locale tables loaded before it can
  // format a date in any non-default locale. Without this call, screens
  // that use DateFormat('dd MMM yyyy', 'vi') throw
  // LocaleDataException on first build.
  await initializeDateFormatting('vi', 'en');
  ColdStartTracer.instance.mark('i18n_ready');
}

Future<void> _initFirestorePersistence() async {
  // Guard: if Firebase init is somehow skipped or this task runs out
  // of order, Firebase.app() will throw "No Firebase App '[DEFAULT]'
  // has been created". Falling back to `FirebaseFirestore.instance`
  // when no app is registered is the documented way to detect that
  // state, because the instance getter itself throws the same error.
  try {
    Firebase.app();
  } catch (_) {
    if (kDebugMode) {
      debugPrint('[STARTUP] _initFirestorePersistence skipped: '
          'Firebase not initialized yet');
    }
    return;
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  ColdStartTracer.instance.mark('firestore_ready');
}

Future<void> _initWorkManager() async {
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
}

// ─── Phase 2 (post-frame; up to a few seconds) ───────────────────────────
Future<void> _initOneSignal() async {
  OneSignalService().init();
  await auditInfo('onesignal_init');
}

Future<void> _initAuditLog() async {
  await auditInfo('cold_start', fields: <String, Object?>{
    'ts': DateTime.now().toIso8601String(),
    'mode': kReleaseMode ? 'release' : 'debug',
  });
}

Future<void> _probeIntegrity() async {
  try {
    final v = await PlayIntegrityService.instance.currentVerdict();
    await auditInfo('integrity', fields: v.toJson());
  } catch (e) {
    await auditWarn('integrity_error', fields: <String, Object?>{'error': e.toString()});
  }
}

Future<void> _probeAntiTamper() async {
  try {
    final r = await AntiTamperService.instance.scan();
    if (!r.isClean) {
      await auditWarn(
        'anti_tamper',
        fields: <String, Object?>{'issues': r.issues},
      );
    }
  } catch (_) {/* best-effort */}
}

// ─── OneSignal push tap routing ────────────────────────────────
void _handleOneSignalPushTap(Map<String, dynamic> additionalData) {
  final type = _inferNotifType(additionalData);
  final title = additionalData['title'] as String? ?? 'LoveHub';
  final body = additionalData['body'] as String? ?? '';
  LocalNotificationInboxService.appendNotification(
    title: title,
    body: body,
    type: type,
  );
  Future.microtask(() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
  });
}

NotificationItemType _inferNotifType(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  switch (type) {
    case 'partner_checkin':
    case 'partnerMood':
    case 'partnerMemory':
      return NotificationItemType.partnerCheckin;
    case 'milestone':
      return NotificationItemType.milestone;
    case 'pet':
      return NotificationItemType.pet;
    case 'pairing':
    case 'couple_link':
      return NotificationItemType.pairing;
    default:
      return NotificationItemType.other;
  }
}

class LoveHubApp extends ConsumerStatefulWidget {
  const LoveHubApp({super.key});

  @override
  ConsumerState<LoveHubApp> createState() => _LoveHubAppState();
}

class _LoveHubAppState extends ConsumerState<LoveHubApp> {
  String? _lastOneSignalUid;
  bool _oneSignalWired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreNotification();
      _wireOneSignalListeners();
    });
  }

  void _wireOneSignalListeners() {
    if (_oneSignalWired) return;
    _oneSignalWired = true;
    final service = ref.read(oneSignalServiceProvider);
    service.addClickListener(_handleOneSignalPushTap);
    final repo = ref.read(oneSignalRepositoryProvider);
    repo.onSubscriptionChanged((_) {});
  }

  Future<void> _restoreNotification() async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;
    final days = ref.read(loveDurationProvider)?.days ?? 0;
    final names = _buildNames();
    await ForegroundNotificationService.restartIfNeeded(days: days, names: names);
    await _restoreCheckinReminder();
    await _restoreMoodReminder();
    await _cacheBackgroundData();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    _syncOneSignalAuth(authAsync.valueOrNull);

    final router = ref.watch(routerProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'LoveHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: appSupportedLocales,
      builder: (context, child) {
        return EasyLocalization(
          supportedLocales: appSupportedLocales,
          fallbackLocale: appFallbackLocale,
          path: 'assets/translations',
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(fontScale.scale)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  void _syncOneSignalAuth(AppUser? user) {
    final repo = ref.read(oneSignalRepositoryProvider);
    final uid = user?.uid;
    if (uid == _lastOneSignalUid) return;
    final previous = _lastOneSignalUid;
    _lastOneSignalUid = uid;
    if (uid != null) {
      () async {
        try {
          await repo.loginUser(uid);
          await repo.requestPermission();
        } catch (_) {/* best-effort */}
      }();
    } else if (previous != null) {
      () async {
        try {
          await repo.logout();
        } catch (_) {}
      }();
    }
  }

  Future<void> _restoreCheckinReminder() async {
    final notifier = ref.read(checkinReminderEnabledProvider.notifier);
    await notifier.ready;
    final enabled = ref.read(checkinReminderEnabledProvider);
    if (!enabled) {
      await CheckinReminderService.cancel();
      return;
    }
    await CheckinReminderService.init();
    final granted = await CheckinReminderService.requestPermission();
    if (!granted) return;
    await CheckinReminderService.scheduleDaily();
  }

  Future<void> _restoreMoodReminder() async {
    final notifier = ref.read(moodReminderEnabledProvider.notifier);
    await notifier.ready;
    final enabled = ref.read(moodReminderEnabledProvider);
    if (!enabled) {
      await LocalReminderService.cancel(LocalReminders.dailyMood.id);
      return;
    }
    await CheckinReminderService.init();
    final granted = await CheckinReminderService.requestPermission();
    if (!granted) return;
    await LocalReminderService.schedule(spec: LocalReminders.dailyMood);
  }

  Future<void> _cacheBackgroundData() async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;
    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) return;
    final coupleAsync = ref.read(watchCoupleProvider(coupleId));
    final couple = coupleAsync.valueOrNull;
    final startDate = couple?.startDate;
    if (startDate == null) return;
    final notifEnabled = ref.read(loveCounterNotificationEnabledProvider);
    final names = _buildNames();
    await BackgroundRefreshService.cacheForBackground(
      startDate: startDate,
      names: names,
      notifEnabled: notifEnabled,
    );
    await BackgroundRefreshService.registerPeriodicTask();
  }

  String _buildNames() {
    final authUser = ref.read(authStateProvider).valueOrNull;
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    final yourName = authUser?.displayName ?? '';
    final partnerName = partner?.displayName ?? '';
    if (yourName.isNotEmpty && partnerName.isNotEmpty) {
      return '$yourName & $partnerName';
    }
    return yourName.isNotEmpty ? yourName : partnerName;
  }
}