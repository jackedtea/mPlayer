plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.icedtea.mplayer"
    // Pinned ahead of flutter.compileSdkVersion (36 on Flutter 3.44):
    // flutter_secure_storage 11.x requires compiling against SDK 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.icedtea.mplayer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // CI sets these for dev-channel builds so a dev APK installs
        // alongside a release one instead of replacing it. Empty locally.
        System.getenv("APP_ID_SUFFIX")?.takeIf { it.isNotBlank() }?.let {
            applicationIdSuffix = it
        }
        System.getenv("VERSION_NAME_SUFFIX")?.takeIf { it.isNotBlank() }?.let {
            versionNameSuffix = it
        }
    }

    signingConfigs {
        create("release") {
            // Supplied by the workflow from repository secrets. Never read
            // from a file in the repo — no keystore is ever committed.
            val storePath = System.getenv("KEYSTORE_PATH")
            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no keystore is configured, so
            // `flutter build apk --release` still works on a dev machine.
            signingConfig = if (System.getenv("KEYSTORE_PATH").isNullOrBlank()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    // Chromecast. The only Google Play Services dependency in the app, and it
    // is optional at runtime: a device without Play Services throws from the
    // first CastContext call, which `CastChannel` answers with "unavailable"
    // so the picker simply lists no Chromecasts. DLNA needs none of this and
    // is what covers Windows and Linux.
    implementation("com.google.android.gms:play-services-cast-framework:21.5.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
