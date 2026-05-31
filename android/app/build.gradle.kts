plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.usherer.usherer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.usherer.usherer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as? com.android.build.gradle.api.ApkVariantOutput
            if (output != null) {
                val version = variant.versionName ?: "1.0.0"
                output.outputFileName = "usherer-$version.apk"
            }
        }

        // Copy the renamed APK to the standard flutter-apk output folder after assembling
        variant.assembleProvider.configure {
            doLast {
                val version = variant.versionName ?: "1.0.0"
                val buildDir = layout.buildDirectory.get()
                // variant.name is "release" or "debug"
                val src = file("$buildDir/outputs/apk/${variant.name}/usherer-$version.apk")
                val destDir = file("$buildDir/outputs/flutter-apk")
                if (src.exists()) {
                    destDir.mkdirs()
                    src.copyTo(file("$destDir/usherer-$version.apk"), overwrite = true)
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
