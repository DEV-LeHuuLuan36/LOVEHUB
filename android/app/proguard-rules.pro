# ═══════════════════════════════════════════════════════════════════════════
# ProGuard / R8 rules for LoveHub release builds.
#
# R8 full mode is used for release builds (AGP default).
# These rules ensure:
#   1. Code that is called via reflection keeps its names.
#   2. Firebase SDK classes are not stripped.
#   3. Rive / Lottie animation files keep their class structure.
#   4. Groq API responses are parsed correctly.
#   5. Dart-specific symbols are preserved.
#
# Reference:
#   https://developer.android.com/studio/build/shrink-code
# ═══════════════════════════════════════════════════════════════════════════

# ─── Flutter / Dart ────────────────────────────────────────────────────

# Keep Flutter engine symbols that may be stripped.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter's Platform (for platform channel calls).
-keep class com.example.lovehub.** { *; }

# ─── Firebase (Firestore, Auth) ──────────────────────────────────────

# Firebase BOM keeps all SDKs consistent.
-keep class com.google.firebase.** { *; }
-keepnames class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firestore metadata (required for offline persistence).
-keep class com.google.firebase.firestore.** { *; }
-keepnames class com.google.firebase.firestore.** { *; }

# Firebase Auth identity toolkit.
-keep class com.google.firebase.auth.** { *; }
-keepnames class com.google.firebase.auth.** { *; }

# ─── Google Play Services ────────────────────────────────────────────

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── OneSignal Push ───────────────────────────────────────────────────

-keep class com.onesignal.** { *; }
-keepnames class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# ─── WorkManager ─────────────────────────────────────────────────────

-keep class androidx.work.** { *; }
-keepnames class androidx.work.** { *; }
-dontwarn androidx.work.**

# ─── Kotlin Coroutines ────────────────────────────────────────────────

-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ─── Kotlin / Java Reflection ─────────────────────────────────────────

# Keep Kotlin metadata for coroutines and other libraries that
# rely on runtime reflection.
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions

# Keep data classes (used extensively in Riverpod state).
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ─── Rive Animation Engine ───────────────────────────────────────────

-keep class app.rive.runtime.** { *; }
-keepnames class app.rive.runtime.** { *; }
-dontwarn app.rive.runtime.**

# ─── Lottie ──────────────────────────────────────────────────────────

-dontwarn com.airbnb.lottie.**
-keep class com.airbnb.lottie.** { *; }

# ─── Groq / OkHttp / Networking ──────────────────────────────────────

# OkHttp (used by Groq HTTP client).
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keepnames class okhttp3.** { *; }

# ─── Riverpod ────────────────────────────────────────────────────────

# Riverpod uses code generation — keep generated classes.
-keep class * extends com.google.devtools.ksp.processing.Generator { *; }
-keep class * extends com.google.devtools.ksp.symbol.KotlinProvided { *; }
# Keep Riverpod providers (generated code).
-keepclassmembers @dagger.hilt.android.lifecycle.HiltViewModel class * { *; }

# Keep Riverpod Notifier and AsyncNotifier state classes.
-keep class * extends androidx.lifecycle.ViewModel { *; }

# Keep Riverpod annotations.
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault

# ─── go_router ───────────────────────────────────────────────────────

# go_router generates route classes.
-keep class go.router.** { *; }
-keepnames class go.router.** { *; }

# ─── Easy Localization ────────────────────────────────────────────────

-keep class easy_localization.** { *; }
-keepnames class easy_localization.** { *; }
-dontwarn easy_localization.**

# ─── Flutter Secure Storage ──────────────────────────────────────────

-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keepnames class com.it_nomads.fluttersecurestorage.** { *; }

# ─── Google Sign In ──────────────────────────────────────────────────

-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.api.** { *; }

# ─── Cloudinary ──────────────────────────────────────────────────────

-keep class com.cloudinary.** { *; }
-keepnames class com.cloudinary.** { *; }

# ─── Connectivity Plus ──────────────────────────────────────────────

-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ─── Crypto Package ─────────────────────────────────────────────────

# HMAC/SHA256 used by ReplayGuard.
-keep class javax.crypto.** { *; }
-keepnames class javax.crypto.** { *; }

# ─── Hilt / Dagger (if used) ────────────────────────────────────────

# Hilt generated classes.
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keep class * extends dagger.hilt.android.internal.managers.ComponentSupplier { *; }
-keep class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper { *; }

# ─── Data Classes / Entities ──────────────────────────────────────────

# Keep all entity classes that may be serialized.
# Since we use Riverpod + Firestore, entities are plain Dart classes.
-keep class com.example.lovehub.features.**.entities.** { *; }
-keep class com.example.lovehub.features.**.domain.** { *; }

# ─── General Android ─────────────────────────────────────────────────

# Prevent R8 from stripping interface information from TypeAdapter,
# TypeAdapterFactory, JsonSerializer, and JsonDeserializer.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep line numbers for crash reports.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ─── Optimization ────────────────────────────────────────────────────

# Overload by-fold (reduces DEX size).
-overloadremoving

# Remove logging in release.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# ─── Do NOT optimize ─────────────────────────────────────────────────

# Some libraries are incompatible with R8 full mode. Add them here.
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# Flutter's plugin registrar must be preserved.
-keep class io.flutter.plugins.** { *; }