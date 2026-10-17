plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// VERSION is the native Android and bundled About version source.
val inkoraVersion = rootProject.file("../VERSION").readText().trim()
val inkoraCalendar = Regex("(20[0-9]{2})\\.([1-9]|[1-4][0-9]|5[0-3])\\.([1-9][0-9]{0,3})")
val inkoraVersionCode = if (inkoraVersion == "0.1.0") {
    1 // Unreleased development baseline; no public tag is fabricated.
} else {
    val parts = requireNotNull(inkoraCalendar.matchEntire(inkoraVersion)) {
        "VERSION must contain YYYY.W.ID with week 1–53 and ID 1–9999."
    }.groupValues.drop(1).map(String::toInt)
    parts[0] * 1_000_000 + parts[1] * 10_000 + parts[2]
}
val inkoraKeystorePath = System.getenv("INKORA_KEYSTORE_PATH")
val inkoraRequireSigning = System.getenv("INKORA_REQUIRE_RELEASE_SIGNING") == "true"
if (inkoraRequireSigning) {
    require(!inkoraKeystorePath.isNullOrBlank()) { "A release keystore is required." }
}


android {
    namespace = "dev.inkora.inkora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.inkora.inkora"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = inkoraVersionCode
        versionName = inkoraVersion
    }

    signingConfigs {
        if (!inkoraKeystorePath.isNullOrBlank()) {
            create("distribution") {
                storeFile = file(inkoraKeystorePath)
                storePassword = requireNotNull(System.getenv("INKORA_KEYSTORE_PASSWORD"))
                keyAlias = requireNotNull(System.getenv("INKORA_KEY_ALIAS"))
                keyPassword = requireNotNull(System.getenv("INKORA_KEY_PASSWORD"))
            }
        }
    }

    buildTypes {
        release {
            // Local development keeps its existing signature. CI requires the
            // stable distribution keystore; it never publishes a debug-signed APK.
            signingConfig = signingConfigs.getByName(
                if (inkoraKeystorePath.isNullOrBlank()) "debug" else "distribution"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Compile against the exact navigator already supplied by flutter_readium.
    // The app's typed presentation bridge does not add a second engine/version.
    implementation("org.readium.kotlin-toolkit:readium-navigator:3.3.0")
    implementation("org.readium.kotlin-toolkit:readium-shared:3.3.0")
}
