plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aws_saa_trainer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    flavorDimensions += "bank"

    productFlavors {
        create("saa") {
            dimension = "bank"
            applicationId = "com.example.aws_saa_trainer"
            manifestPlaceholders["appLabel"] = "SAA 练习"
        }
        create("sap") {
            dimension = "bank"
            applicationId = "com.example.aws_sap_trainer"
            manifestPlaceholders["appLabel"] = "SAP 练习"
        }
        create("ispm") {
            dimension = "bank"
            applicationId = "com.example.ispm.trainer"
            manifestPlaceholders["appLabel"] = "ISPM 练习(实验)"
        }
        create("pm") {
            dimension = "bank"
            applicationId = "com.example.acca.pm"
            manifestPlaceholders["appLabel"] = "ACCA PM 练习"
        }
        create("tx") {
            dimension = "bank"
            applicationId = "com.example.acca.tx"
            manifestPlaceholders["appLabel"] = "ACCA TX 练习"
        }
        create("fr") {
            dimension = "bank"
            applicationId = "com.example.acca.fr"
            manifestPlaceholders["appLabel"] = "ACCA FR 练习"
        }
        create("aa") {
            dimension = "bank"
            applicationId = "com.example.acca.aa"
            manifestPlaceholders["appLabel"] = "ACCA AA 练习"
        }
        create("fm") {
            dimension = "bank"
            applicationId = "com.example.acca.fm"
            manifestPlaceholders["appLabel"] = "ACCA FM 练习"
        }
        create("sbl") {
            dimension = "bank"
            applicationId = "com.example.acca.sbl"
            manifestPlaceholders["appLabel"] = "ACCA SBL 练习"
        }
        create("sbr") {
            dimension = "bank"
            applicationId = "com.example.acca.sbr"
            manifestPlaceholders["appLabel"] = "ACCA SBR 练习"
        }
        create("afm") {
            dimension = "bank"
            applicationId = "com.example.acca.afm"
            manifestPlaceholders["appLabel"] = "ACCA AFM 练习"
        }
        create("apm") {
            dimension = "bank"
            applicationId = "com.example.acca.apm"
            manifestPlaceholders["appLabel"] = "ACCA APM 练习"
        }
        create("aaa") {
            dimension = "bank"
            applicationId = "com.example.acca.aaa"
            manifestPlaceholders["appLabel"] = "ACCA AAA 练习"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.aws_saa_trainer"
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
}

flutter {
    source = "../.."
}
