plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.kotlin.parcelize) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt.android) apply false
    alias(libs.plugins.firebase.appdistribution) apply false
}

configurations.all {
    resolutionStrategy {
        // Force AAR version of JNA
        force("net.java.dev.jna:jna:${libs.versions.jna.get()}@aar")
    }

    // Exclude JAR version of JNA
    exclude(group = "net.java.dev.jna", module = "jna")
}
