plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.petapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.0.13004108"

    //compileSdkVersion 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // defaultConfig {
    //     // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    //     applicationId = "com.example.petapp"
    //     // You can update the following values to match your application needs.
    //     // For more information, see: https://flutter.dev/to/review-gradle-config.
    //     minSdk = 23
    //     targetSdk = flutter.targetSdkVersion
    //     minSdkVersion 21
    //     targetSdkVersion 34
    //     versionCode = flutter.versionCode
    //     versionName = flutter.versionName
    // }

    defaultConfig {
        applicationId = "com.example.petapp"
        minSdk = 23
        targetSdk = 34
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

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.10.0"))
    implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}
