plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing secrets from ../key.properties (kept out of the repo).
val _mbpKeyFile = file("/home/hatch/workspace/apk-build/key.properties")
if (_mbpKeyFile.exists()) {
    for (_mbpLine in _mbpKeyFile.readLines()) {
        val _mbpEq = _mbpLine.indexOf('=')
        if (_mbpEq > 0) {
            project.extensions.extraProperties.set(
                "mbp." + _mbpLine.substring(0, _mbpEq).trim(),
                _mbpLine.substring(_mbpEq + 1).trim()
            )
        }
    }
}

android {
    namespace = "com.kazem.monopolybankerpro"
    packaging {
        resources {
            excludes += "commonMain/**"
            excludes += "nativeMain/**"
            excludes += "META-INF/kotlin-project-structure-metadata.json"
            excludes += "META-INF/*.kotlin_module"
        }
    }
    // Offline sandbox: SDK 35 is installed; Flutter 3.47 defaults to 36.
    compileSdk = 35
    // Offline sandbox: NDK 28.0.13004108 installed; Flutter 3.47 defaults to 28.2.13676358.
    ndkVersion = "28.0.13004108"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kazem.monopolybankerpro"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // key.properties values are loaded into extra properties at the top of this script.
            storeFile = file(findProperty("mbp.storeFile") as String? ?: "../release.keystore")
            storePassword = findProperty("mbp.storePassword") as String? ?: ""
            keyAlias = findProperty("mbp.keyAlias") as String? ?: "monopolybankerpro"
            keyPassword = findProperty("mbp.keyPassword") as String? ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
