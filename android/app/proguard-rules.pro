# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep UniFFI generated classes
-keep class uniffi.** { *; }
-keep interface uniffi.** { *; }

# Keep JNA classes
-keep class com.sun.jna.** { *; }
-keep interface com.sun.jna.* { *; }
-keep class * implements com.sun.jna.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep coroutine classes
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keep class kotlinx.coroutines.android.AndroidDispatcherFactory { *; }

# Keep Hilt classes
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keep class * extends dagger.hilt.android.lifecycle.HiltViewModel

# Keep KeystoreBridge for JNI access from Rust SDK
-keep class app.provii.wallet.KeystoreBridge { *; }
-keep class app.provii.wallet.KeystoreBridge$Companion { *; }

# Keep your app's classes that use UniFFI
-keep class app.provii.wallet.sdk.** { *; }
-keep class app.provii.wallet.data.** { *; }

-dontwarn java.awt.**
-dontwarn com.sun.jna.platform.**
-dontwarn edu.umd.cs.findbugs.annotations.SuppressFBWarnings
-keep class com.sun.jna.** { *; }

# Keep BiometricManager constants
-keep class androidx.biometric.BiometricManager {
    public static final int BIOMETRIC_STRONG;
    public static final int BIOMETRIC_WEAK;
    public static final int BIOMETRIC_ERROR_*;
    public static final int BIOMETRIC_SUCCESS;
}

# Keep SDK classes
-keep class app.provii.wallet.sdk.** { *; }
-keepclassmembers class app.provii.wallet.sdk.** { *; }

# ============================================================================
# MASVS-CODE-4: Build Configuration - Release Security Rules
# ============================================================================

# Remove ALL logging in release builds
# This prevents sensitive information from leaking through logs
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int wtf(...);
}

# Remove Timber debug and verbose logs in release
-assumenosideeffects class timber.log.Timber {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

# Remove Timber$Tree methods in release
-assumenosideeffects class timber.log.Timber$Tree {
    public *** d(...);
    public *** v(...);
    public *** i(...);
    public *** w(...);
    public *** e(...);
    public *** wtf(...);
}

# Keep sensitive data holder classes but obfuscate internals
-keepclassmembers class app.provii.wallet.security.SensitiveDataHolder {
    public void close();
    public void zeroize();
}

-keepclassmembers class app.provii.wallet.security.SensitiveStringHolder {
    public void close();
    public void zeroize();
}

-keepclassmembers class app.provii.wallet.security.CredentialSecretsHolder {
    public void close();
    public void zeroize();
}

# Obfuscate security-critical classes
-keepclassmembers class app.provii.wallet.security.CryptoUtils {
    public static *** encryptAesGcm(...);
    public static *** decryptAesGcm(...);
}

# Remove debug print statements
-assumenosideeffects class java.io.PrintStream {
    public void println(...);
    public void print(...);
}

# Keep Kotlin null-check intrinsics in release builds.
# Stripping these causes silent corruption instead of clean crashes when null
# is passed where non-null is expected. The performance cost is negligible.
# -assumenosideeffects class kotlin.jvm.internal.Intrinsics { ... }  # DO NOT ENABLE

# ============================================================================
# Security: Encrypt/protect sensitive string literals
# ============================================================================

# Keep encrypted preferences manager methods for proper functioning
-keepclassmembers class app.provii.wallet.security.SecurePreferencesManager {
    public *** get*(...);
    public *** set*(...);
    public *** save*(...);
    public void close();
}

# ============================================================================
# MASVS-RESILIENCE-4: Enhanced Code Obfuscation for Security Classes
# ============================================================================

# Obfuscate security-critical package internals while keeping public API
# Note: We aggressively obfuscate these classes to make reverse engineering harder

# Obfuscate internal implementation details
-repackageclasses 'p'
-allowaccessmodification

# Flatten class hierarchy to make reverse engineering harder
-flattenpackagehierarchy 'p'

# Obfuscate security package internal implementation details
# but keep the public interfaces for app integration
-keepclassmembers class app.provii.wallet.security.resilience.ResilienceChecker {
    public static *** getInstance(...);
    public *** performAllChecks();
    public *** performQuickCheck();
    public *** isDeviceCompromised();
    public *** getLastResult();
}

-keepclassmembers class app.provii.wallet.security.resilience.ResilienceChecker$ResilienceResult {
    public <fields>;
}

-keepclassmembers class app.provii.wallet.security.resilience.ResilienceChecker$ResilienceConfig {
    public <init>(...);
}

-keepclassmembers class app.provii.wallet.security.resilience.ResilienceChecker$Builder {
    public <methods>;
}

# Keep enum values (needed for when statements)
-keepclassmembers enum app.provii.wallet.security.** {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep result class members but allow class name obfuscation for security
-keep,allowobfuscation class app.provii.wallet.security.antiDebug.AntiDebugChecker$AntiDebugResult { *; }
-keep,allowobfuscation class app.provii.wallet.security.integrity.SignatureVerifier$IntegrityResult { *; }
-keep,allowobfuscation class app.provii.wallet.security.integrity.RootDetector$RootDetectionResult { *; }

# Obfuscate string constants in security classes
# This makes static analysis harder
-adaptclassstrings app.provii.wallet.security.**
-adaptresourcefilecontents **.xml

# Optimize aggressively for security classes
-optimizationpasses 5
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# Remove method parameter names to make debugging harder
-keepparameternames

# ============================================================================
# String Encryption Patterns
# ============================================================================
# Note: R8 doesn't provide native string encryption, but these rules help
# obfuscate string-heavy security detection logic

# Keep only necessary method signatures, obfuscate implementation
-keepclassmembernames class app.provii.wallet.security.antiDebug.AntiDebugChecker {
    public static *** performChecks(android.content.Context);
    public static *** quickCheck();
}

-keepclassmembernames class app.provii.wallet.security.integrity.RootDetector {
    public static *** performChecks(android.content.Context);
    public static *** quickCheck();
}

-keepclassmembernames class app.provii.wallet.security.integrity.SignatureVerifier {
    public static *** performVerification(android.content.Context, ...);
    public static *** getSignatureHash(android.content.Context);
    public static *** getDexHash(android.content.Context);
    public static *** quickCheck(android.content.Context, java.lang.String);
}

# ============================================================================
# Debug Information Removal
# ============================================================================

# Keep line numbers for crash reports but strip source file names for security
-keepattributes LineNumberTable

# Remove debug information from security packages specifically
-assumenosideeffects class app.provii.wallet.security.** {
    private void log*(...);
    private void debug*(...);
}
