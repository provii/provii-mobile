plugins {
    alias(libs.plugins.android.library)
}

tasks.register("fixUniffiImports") {
    doLast {
        val generatedFile = file("src/main/java/app/provii/wallet/sdk/provii_mobile_sdk_ffi.kt")
        if (generatedFile.exists()) {
            val content = generatedFile.readText()
            if (!content.contains("import androidx.annotation.RequiresApi")) {
                // Add the import after the package declaration
                val updatedContent = content.replaceFirst(
                    "package app.provii.wallet.sdk",
                    "package app.provii.wallet.sdk\n\nimport androidx.annotation.RequiresApi"
                )
                generatedFile.writeText(updatedContent)
                println("Fixed UniFFI imports - added RequiresApi")
            }
        }
    }
}

// Lazy task configuration (Gradle 9 compatible, replaces afterEvaluate)
tasks.configureEach {
    if (name == "compileDebugKotlin" || name == "compileReleaseKotlin") {
        dependsOn("fixUniffiImports")
    }
}

android {
    namespace = "uniffi.provii_mobile_sdk_ffi"
    compileSdk = 36

    defaultConfig {
        minSdk = 28
        consumerProguardFiles("proguard-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        // UniFFI-generated code uses java.lang.ref.Cleaner with runtime
        // reflection fallback for API < 33. Safe to suppress.
        disable.add("NewApi")
    }
}

kotlin {
    jvmToolchain(17)
}

// Force JNA version resolution
configurations.all {
    resolutionStrategy {
        force("net.java.dev.jna:jna:${libs.versions.jna.get()}")
        force("net.java.dev.jna:jna-platform:${libs.versions.jna.get()}")
    }
}

dependencies {
    implementation(libs.kotlinx.coroutines.android)

    // Use only the AAR version of JNA
    implementation(libs.jna) {
        artifact {
            type = "aar"
        }
        isTransitive = false
    }

    implementation(libs.androidx.annotation)
}
