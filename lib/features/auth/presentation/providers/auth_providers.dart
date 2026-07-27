import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/sign_in_email_usecase.dart';
import '../../domain/usecases/sign_up_email_usecase.dart';
import '../../domain/usecases/sign_in_google_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../../presence/presentation/providers/presence_providers.dart';
import '../../../presence/domain/repositories/presence_repository.dart';

// ─── Core service providers ───────────────────────────────────────────────────
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn();
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ─── Data source & repository ─────────────────────────────────────────────────
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

// ─── Use case providers ───────────────────────────────────────────────────────
final signInEmailUseCaseProvider = Provider<SignInEmailUseCase>((ref) {
  return SignInEmailUseCase(ref.watch(authRepositoryProvider));
});

final signUpEmailUseCaseProvider = Provider<SignUpEmailUseCase>((ref) {
  return SignUpEmailUseCase(ref.watch(authRepositoryProvider));
});

final signInGoogleUseCaseProvider = Provider<SignInGoogleUseCase>((ref) {
  return SignInGoogleUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final changePasswordUseCaseProvider = Provider<ChangePasswordUseCase>((ref) {
  return ChangePasswordUseCase(ref.watch(authRepositoryProvider));
});

// ─── Auth state stream ────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Stream of the underlying Firebase [User] (not our `AppUser`
/// model). Used to read `providerData` and detect the
/// sign-in method.
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// True when the current Firebase user has a 'password' provider
/// in their `providerData` list (i.e. signed up with
/// email/password). False for Google sign-in (or any other
/// federation) — and for the unauthenticated state.
final isPasswordAccountProvider = Provider<bool>((ref) {
  final user = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (user == null) return false;
  return user.providerData.any((p) => p.providerId == 'password');
});

// ─── Auth controller ──────────────────────────────────────────────────────────
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController({
    required SignInEmailUseCase signInEmail,
    required SignUpEmailUseCase signUpEmail,
    required SignInGoogleUseCase signInGoogle,
    required SignOutUseCase signOut,
    required PresenceRepository presenceRepoProvider,
  })  : _signInEmail = signInEmail,
        _signUpEmail = signUpEmail,
        _signInGoogle = signInGoogle,
        _signOut = signOut,
        _presenceRepoProvider = presenceRepoProvider,
        super(const AsyncValue.data(null));

  final SignInEmailUseCase _signInEmail;
  final SignUpEmailUseCase _signUpEmail;
  final SignInGoogleUseCase _signInGoogle;
  final SignOutUseCase _signOut;
  final PresenceRepository _presenceRepoProvider;

  Future<bool> signInEmail({required String email, required String password}) async {
    state = const AsyncValue.loading();
    final result = await _signInEmail(email: email, password: password);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> signUpEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    final result = await _signUpEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> signInGoogle() async {
    state = const AsyncValue.loading();
    final result = await _signInGoogle();
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> signOut() async {
    state = const AsyncValue.loading();
    // Mark offline BEFORE signing out so partner sees it immediately
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await _presenceRepoProvider.goOffline(uid);
      } catch (_) {}
    }
    final result = await _signOut();
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    signInEmail: ref.watch(signInEmailUseCaseProvider),
    signUpEmail: ref.watch(signUpEmailUseCaseProvider),
    signInGoogle: ref.watch(signInGoogleUseCaseProvider),
    signOut: ref.watch(signOutUseCaseProvider),
    presenceRepoProvider: ref.watch(presenceRepositoryProvider),
  );
});

// ─── Change password controller ───────────────────────────────────────────────
/// Drives the "Change Password" flow. `state.isLoading` is true
/// during reauthenticate + updatePassword; `state.hasError`
/// carries the failure message.
class ChangePasswordController extends StateNotifier<AsyncValue<void>> {
  ChangePasswordController({required ChangePasswordUseCase changePassword})
      : _changePassword = changePassword,
        super(const AsyncValue.data(null));

  final ChangePasswordUseCase _changePassword;

  /// Returns `null` on success, or a user-facing error string on
  /// failure (e.g. "Current password is incorrect").
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    final result = await _changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final changePasswordControllerProvider =
    StateNotifierProvider<ChangePasswordController, AsyncValue<void>>((ref) {
  return ChangePasswordController(
    changePassword: ref.watch(changePasswordUseCaseProvider),
  );
});

// ─── Delete-account use case providers ───────────────────────────────────────
final reauthenticateGoogleUseCaseProvider =
    Provider<ReauthenticateGoogleUseCase>((ref) {
  return ReauthenticateGoogleUseCase(ref.watch(authRepositoryProvider));
});

final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>((ref) {
  return DeleteAccountUseCase(ref.watch(authRepositoryProvider));
});

// ─── Delete-account controller ────────────────────────────────────────────────
/// Orchestrates the full "delete account" flow:
///
///   1. Re-authenticate the user via Google Sign-In (required by
///      Firebase for sensitive operations like `delete()`).
///   2. If re-auth fails or is cancelled, abort with an error.
///   3. Delete the account (Firestore + Firebase Auth).
///   4. On `requires-recent-login`, automatically retry the
///      re-auth flow once more before failing.
///
/// Returns `null` on success, or a user-facing error string on
/// failure. The caller is responsible for navigating the user
/// out of the app on success.
class DeleteAccountController extends StateNotifier<AsyncValue<void>> {
  DeleteAccountController({
    required ReauthenticateGoogleUseCase reauthenticateGoogle,
    required DeleteAccountUseCase deleteAccount,
    required PresenceRepository presenceRepoProvider,
  })  : _reauthenticateGoogle = reauthenticateGoogle,
        _deleteAccount = deleteAccount,
        _presenceRepoProvider = presenceRepoProvider,
        super(const AsyncValue.data(null));

  final ReauthenticateGoogleUseCase _reauthenticateGoogle;
  final DeleteAccountUseCase _deleteAccount;
  final PresenceRepository _presenceRepoProvider;

  Future<String?> deleteAccount() async {
    state = const AsyncValue.loading();

    // Step 1: Re-authenticate (first attempt).
    final reauth1 = await _reauthenticateGoogle.call();
    final reauth1Err = reauth1.fold((f) => f.message, (_) => null);
    if (reauth1Err != null) {
      state = AsyncValue.error(reauth1Err, StackTrace.current);
      return reauth1Err;
    }

    // Step 2: Attempt the deletion.
    Future<String?> attemptDelete() async {
      final res = await _deleteAccount.call();
      return res.fold((f) => f.message, (_) => null);
    }

    var err = await attemptDelete();
    if (err != null) {
      // Step 3: If Firebase told us the session is too old, try
      // re-auth one more time before giving up.
      final lower = err.toLowerCase();
      final needsRecentLogin = lower.contains('requires-recent-login') ||
          lower.contains('recent login') ||
          lower.contains('re-authenticate') ||
          lower.contains('reauthenticate');
      if (needsRecentLogin) {
        final reauth2 = await _reauthenticateGoogle.call();
        final reauth2Err = reauth2.fold((f) => f.message, (_) => null);
        if (reauth2Err != null) {
          state = AsyncValue.error(reauth2Err, StackTrace.current);
          return reauth2Err;
        }
        err = await attemptDelete();
        if (err != null) {
          state = AsyncValue.error(err, StackTrace.current);
          return err;
        }
      } else {
        state = AsyncValue.error(err, StackTrace.current);
        return err;
      }
    }

    // Step 4: Best-effort presence cleanup; ignore errors.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await _presenceRepoProvider.goOffline(uid);
      } catch (_) {}
    }

    state = const AsyncValue.data(null);
    return null;
  }
}

final deleteAccountControllerProvider =
    StateNotifierProvider<DeleteAccountController, AsyncValue<void>>((ref) {
  return DeleteAccountController(
    reauthenticateGoogle: ref.watch(reauthenticateGoogleUseCaseProvider),
    deleteAccount: ref.watch(deleteAccountUseCaseProvider),
    presenceRepoProvider: ref.watch(presenceRepositoryProvider),
  );
});
