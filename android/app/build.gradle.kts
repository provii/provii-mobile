plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.parcelize)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt.android)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.firebase.appdistribution)
    jacoco
}

android {
    namespace = "app.provii.wallet"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.provii.wallet"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        vectorDrawables {
            useSupportLibrary = true
        }

        // Per-ABI SHA-256 hashes of libprovii_mobile_sdk_ffi.so for integrity verification.
        // Set via NATIVE_LIB_HASHES env var in CI as "arm64-v8a=<hex>;armeabi-v7a=<hex>;..."
        // Empty string disables verification (local dev builds).
        buildConfigField("String", "NATIVE_LIB_HASHES", "\"${System.getenv("NATIVE_LIB_HASHES") ?: ""}\"")

        // Supported languages for localization and RTL - 62 total including English
        resourceConfigurations += listOf(
            "en",      // English
            "am",      // Amharic
            "ar",      // Arabic (RTL)
            "bg",      // Bulgarian
            "bn",      // Bengali
            "bo",      // Tibetan
            "bs",      // Bosnian
            "cnh",     // Hakha Chin
            "de",      // German
            "din",     // Dinka
            "el",      // Greek
            "es",      // Spanish
            "fa",      // Persian (RTL)
            "fa-rAF",  // Dari (RTL)
            "fi",      // Finnish
            "fr",      // French
            "gu",      // Gujarati
            "haz",     // Hazaragi (RTL)
            "he",      // Hebrew (RTL)
            "hi",      // Hindi
            "hmn",     // Hmong
            "hr",      // Croatian
            "hy",      // Armenian
            "id",      // Indonesian
            "it",      // Italian
            "ja",      // Japanese
            "kar",     // Karen
            "km",      // Khmer
            "ko",      // Korean
            "ku",      // Kurdish (RTL)
            "lo",      // Lao
            "mk",      // Macedonian
            "ml",      // Malayalam
            "mt",      // Maltese
            "ne",      // Nepali
            "nl",      // Dutch
            "pa",      // Punjabi
            "pl",      // Polish
            "ps",      // Pashto (RTL)
            "pt",      // Portuguese
            "rhg",     // Rohingya
            "rn",      // Kirundi
            "ro",      // Romanian
            "ru",      // Russian
            "si",      // Sinhala
            "sk",      // Slovak
            "sl",      // Slovenian
            "sm",      // Samoan
            "so",      // Somali
            "sq",      // Albanian
            "sr",      // Serbian
            "sw",      // Swahili
            "ta",      // Tamil
            "th",      // Thai
            "ti",      // Tigrinya
            "tl",      // Tagalog
            "tr",      // Turkish
            "ur",      // Urdu (RTL)
            "vi",      // Vietnamese
            "zh-rCN",  // Simplified Chinese
            "zh-rTW"   // Traditional Chinese
        )
    }

    signingConfigs {
        create("release") {
            // TODO: Set these in CI via environment variables or local.properties
            storeFile = file(System.getenv("RELEASE_KEYSTORE_PATH") ?: "release.keystore")
            storePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("RELEASE_KEY_ALIAS") ?: ""
            keyPassword = System.getenv("RELEASE_KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Firebase App Distribution config ().
            // Tester groups must exist in the Firebase console; release notes
            // are written by the fastlane lane and read from the file below.
            // Service-account credentials are passed via env variable
            // FIREBASE_APP_DISTRIBUTION_CREDENTIALS in CI.
            firebaseAppDistributionDefault {
                artifactType = "AAB"
                groups = "provii-internal,provii-external-beta"
                releaseNotesFile = "$rootDir/fastlane/release_notes.txt"
                serviceCredentialsFile = System.getenv("FIREBASE_APP_DISTRIBUTION_CREDENTIALS_PATH") ?: ""
            }
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    lint {
        baseline = file("lint-baseline.xml")
        abortOnError = true
        warningsAsErrors = false
        checkDependencies = true
    }
}

// Fail release builds if the signing certificate hash placeholder
// has not been replaced in SignatureVerifier.kt. This catches the mistake at
// build time rather than waiting for the runtime check in validateConfiguration().
tasks.register("validateIntegrityHashes") {
    description = "Validates that integrity hash placeholders have been replaced for release builds"
    doLast {
        val verifierFile = file("src/main/java/com/provii/wallet/security/integrity/SignatureVerifier.kt")
        if (!verifierFile.exists()) {
            throw GradleException("SignatureVerifier.kt not found at ${verifierFile.absolutePath}")
        }
        val content = verifierFile.readText()
        if (content.contains("PLACEHOLDER_REPLACE_BEFORE_RELEASE")) {
            throw GradleException(
                "SignatureVerifier.kt still contains PLACEHOLDER_REPLACE_BEFORE_RELEASE. " +
                "Replace EXPECTED_SIGNING_CERT_HASH with the actual release signing certificate " +
                "SHA-256 hash before building a release. Generate it with: " +
                "keytool -list -v -keystore release.keystore | grep SHA256"
            )
        }
    }
}

// Fail release builds if NATIVE_LIB_HASHES env var is empty, preventing
// accidental release without native library integrity verification.
tasks.register("validateNativeLibHashes") {
    description = "Validates that NATIVE_LIB_HASHES is set for release builds"
    doLast {
        val hashes = System.getenv("NATIVE_LIB_HASHES") ?: ""
        if (hashes.isEmpty()) {
            throw GradleException(
                "NATIVE_LIB_HASHES environment variable is empty. Release builds require " +
                "per-ABI SHA-256 hashes of libprovii_mobile_sdk_ffi.so for integrity verification. " +
                "Set NATIVE_LIB_HASHES as 'arm64-v8a=<hex>;armeabi-v7a=<hex>;...' or build " +
                "via CI which computes hashes automatically."
            )
        }
    }
}

// Hook the validations into release assembly tasks
tasks.configureEach {
    if (name.contains("Release") && (name.startsWith("assemble") || name.startsWith("bundle"))) {
        dependsOn("validateIntegrityHashes")
        dependsOn("validateNativeLibHashes")
    }
}

// ---------------------------------------------------------------------------
// JaCoCo code coverage configuration
// ---------------------------------------------------------------------------
// Scope: testable logic layers only. Pure UI (@Composable), generated UniFFI
// bindings, platform entrypoints, and Hilt DI modules are excluded.
//
// Exclusions:
//   ui/**          – Jetpack Compose screens, components, theme, previews
//   search/SearchScreen – @Composable screen (SearchManager logic IS included)
//   navigation/BottomNavigation, NavGraph – pure Compose navigation wiring
//   sdk/**         – generated UniFFI bindings (FFI contract)
//   MainActivity, WalletApplication – platform entrypoints
//   di/**          – Hilt @Module/@Provides wiring, no logic
//   strings/**     – Resource string references
// ---------------------------------------------------------------------------
android {
    buildTypes {
        debug {
            enableUnitTestCoverage = true
        }
    }
}

val jacocoExcludes = listOf(
    // Pure Compose UI: screens, components, theme, previews, accessibility
    "app/provii/wallet/ui/**",
    // Generated UniFFI bindings (FFI contract with provii-mobile-sdk)
    "app/provii/wallet/sdk/**",
    // Platform entrypoints and biometric/keystore bridges
    "app/provii/wallet/MainActivity*",
    "app/provii/wallet/WalletApplication*",
    "app/provii/wallet/KeystoreBridge*",
    // Hilt DI wiring
    "app/provii/wallet/di/**",
    // String resource references
    "app/provii/wallet/strings/**",
    // Navigation composables and route sealed classes (BottomNavigation and NavGraph)
    "app/provii/wallet/navigation/BottomNav*",
    "app/provii/wallet/navigation/NavGraph*",
    "app/provii/wallet/navigation/Screen*",
    // Search composable screen (SearchManager logic IS included)
    "app/provii/wallet/search/SearchScreen*",
    // Hilt/Dagger generated classes
    "*_HiltModules*",
    "*_Factory*",
    "*_MembersInjector*",
    "Hilt_*",
    "dagger/**",
    "*_Impl*",
    // Android generated
    "app/provii/wallet/BuildConfig*",
    "**/R.class",
    "**/R\$*.class",
    // EncryptedSharedPreferences-dependent classes: JaCoCo cannot instrument
    // these when tested via Robolectric (class loader mismatch). Tests exist
    // but coverage is recorded as zero. Excluded from the gate, not from testing.
    "app/provii/wallet/deeplink/**",
    "app/provii/wallet/officer/**",
    "app/provii/wallet/data/WalletRepository*",
    "app/provii/wallet/data/StorageHelper*",
    "app/provii/wallet/data/IssuersRepository*",
    "app/provii/wallet/data/YubikeyManager*",
    "app/provii/wallet/data/QrCoder*",
    "app/provii/wallet/security/NativeKeystoreManager*",
    "app/provii/wallet/security/SecurePreferencesManager*",
    "app/provii/wallet/security/AuditLogger*",
    "app/provii/wallet/security/ClipboardManager*",
    "app/provii/wallet/security/SecurityManager*",
    "app/provii/wallet/security/ScreenshotBlocker*",
    "app/provii/wallet/security/antiDebug/**",
    "app/provii/wallet/security/integrity/RootDetector*",
    "app/provii/wallet/security/integrity/SignatureVerifier*",
    "app/provii/wallet/privacy/PrivacyPreferences*",
    "app/provii/wallet/config/EnvironmentManager*",
    "app/provii/wallet/config/SandboxCredentialFetcher*",
    // Audio tone generation requires AudioTrack (hardware-dependent)
    "app/provii/wallet/audio/ToneGenerator*",
    "app/provii/wallet/audio/VerificationSoundManager*",
    // ErrorHandler/ErrorMapper require Android Context for string resources;
    // JaCoCo cannot measure Robolectric-loaded classes.
    "app/provii/wallet/error/**",
    // SearchManager requires Context for createSearchableItems string resources
    "app/provii/wallet/search/SearchManager*",
    "app/provii/wallet/search/ComposableSingletons*",
    // NetworkManager requires OkHttp runtime
    "app/provii/wallet/network/NetworkManager*",
    // Composable singletons in top-level package
    "app/provii/wallet/ComposableSingletons*",
    // Onboarding state machine
    "app/provii/wallet/OnboardingState*",
    // LocalizationUtils and Validators require Android Context for getString()
    "app/provii/wallet/utils/LocalizationUtils*",
    "app/provii/wallet/utils/LocalizationUtilsKt*",
    "app/provii/wallet/utils/Validators*",
    // ErrorMapper requires Context for getString()
    "app/provii/wallet/utils/ErrorMapper*",
    // QrUtils uses android.util.Base64 and android.net.Uri (Robolectric-dependent)
    "app/provii/wallet/utils/QrUtils*",
    // RtlUtils isRtlLayout requires Context
    "app/provii/wallet/utils/RtlUtilsKt*",
    // SandboxCredential data classes and worker
    "app/provii/wallet/config/SandboxCredential*",
    "app/provii/wallet/config/SandboxGatewayException*",
    "app/provii/wallet/config/SandboxLifetimeExhausted*",
    "app/provii/wallet/config/SandboxEmulatorUnsupported*",
    "app/provii/wallet/config/KeyStoreAttestationProvider*",
    "app/provii/wallet/config/SandboxRefreshWorker*",
    "app/provii/wallet/config/AttestationProvider*",
    // Data models that are pure data classes used only by the excluded WalletRepository
    "app/provii/wallet/data/AuthenticationRequiredException*",
    "app/provii/wallet/data/IssuerRegistry*",
    "app/provii/wallet/data/Location*",
    "app/provii/wallet/data/IssuerCategory*",
    "app/provii/wallet/data/Issuer*",
    // Resilience checker periodic scheduling (coroutine/handler dependent)
    "app/provii/wallet/security/resilience/ResilienceChecker\$startPeriodicChecks*",
    "app/provii/wallet/security/resilience/ResilienceChecker\$performAllChecks*",
    "app/provii/wallet/security/resilience/ResilienceChecker\$Builder*",
    // EncryptedData wrapper
    "app/provii/wallet/security/EncryptedData*",
    // Cleaner actions (GC-triggered, not directly testable)
    "app/provii/wallet/security/SensitiveDataHolder\$CleanerAction*",
    "app/provii/wallet/security/SensitiveStringHolder\$StringCleanerAction*",
)

tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn("testDebugUnitTest")

    reports {
        xml.required.set(true)
        html.required.set(true)
    }

    val debugTree = fileTree("build/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes") {
        exclude(jacocoExcludes)
    }

    classDirectories.setFrom(debugTree)
    sourceDirectories.setFrom(files("src/main/java"))
    executionData.setFrom(fileTree("build") {
        include("outputs/unit_test_code_coverage/debugUnitTest/testDebugUnitTest.exec")
        include("jacoco/testDebugUnitTest.exec")
    })
}

tasks.register<JacocoCoverageVerification>("jacocoCoverageGate") {
    dependsOn("testDebugUnitTest")

    val debugTree = fileTree("build/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes") {
        exclude(jacocoExcludes)
    }

    classDirectories.setFrom(debugTree)
    sourceDirectories.setFrom(files("src/main/java"))
    executionData.setFrom(fileTree("build") {
        include("outputs/unit_test_code_coverage/debugUnitTest/testDebugUnitTest.exec")
        include("jacoco/testDebugUnitTest.exec")
    })

    violationRules {
        rule {
            limit {
                minimum = "0.85".toBigDecimal()
            }
        }
    }
}

dependencies {
    // Core Android
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.compose.material.icons.extended)

    // Compose
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.google.material)
    implementation(libs.gson)

    // Navigation
    implementation(libs.androidx.navigation.compose)

    // Hilt DI
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Security
    implementation(libs.androidx.security.crypto)
    implementation(libs.androidx.biometric)

    // Background work (sandbox credential auto-refresh)
    implementation(libs.androidx.work.runtime.ktx)

    // Camera for QR scanning (1.4.2+ required for 16KB page alignment on Android 15+)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.mlkit.barcode)

    // QR Code Generation
    implementation(libs.zxing.core)

    // YubiKey SDK
    implementation(libs.yubikit.android)
    implementation(libs.yubikit.yubiotp)

    // Networking
    implementation(libs.okhttp)
    implementation(libs.retrofit)

    // JSON Serialization
    implementation(libs.kotlinx.serialization.json)

    // Image Loading (for SVG support in issuer logos)
    implementation(libs.coil.compose)
    implementation(libs.coil.svg)
    implementation(libs.coil.network.okhttp)

    // Logging
    implementation(libs.timber)

    // Wallet SDK module
    implementation(project(":walletsdk"))

    // JNA for UniFFI
    implementation(libs.jna) {
        artifact {
            type = "aar"
        }
        isTransitive = false
    }

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.mockito.core)
    testImplementation(libs.mockito.kotlin)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.work.testing)
    testImplementation(libs.okhttp.mockwebserver)
    androidTestImplementation(libs.test.ext.junit)
    androidTestImplementation(libs.espresso.core)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)
}
