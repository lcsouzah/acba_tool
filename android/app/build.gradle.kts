plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.acba.app.acba_tool"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.acba.app.acba_tool"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePath: String? = project.findProperty("KEYSTORE_PATH") as String?
        ?: System.getenv("KEYSTORE_PATH")
    val keystorePassword: String? = project.findProperty("KEYSTORE_PASSWORD") as String?
        ?: System.getenv("KEYSTORE_PASSWORD")
    val keyAliasProp: String? = project.findProperty("KEY_ALIAS") as String?
        ?: System.getenv("KEY_ALIAS")
    val keyPasswordProp: String? = project.findProperty("KEY_PASSWORD") as String?
        ?: System.getenv("KEY_PASSWORD")

    signingConfigs {
        create("release") {
            if (
                keystorePath != null &&
                keystorePassword != null &&
                keyAliasProp != null &&
                keyPasswordProp != null
            ) {
                storeFile = file(keystorePath)
                storePassword = keystorePassword
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}