plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// Load signing properties from android/key.properties (if present)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { fis ->
        keystoreProperties.load(fis)
    }
}

android {
    namespace = "net.gmartin.twofactorauth"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "net.gmartin.twofactorauth"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use signing config loaded from key.properties if available.
            // Expected keys in `android/key.properties`: storeFile, storePassword, keyAlias, keyPassword
            signingConfigs {
                create("release") {
                    // Prefer environment variables for sensitive data; fallback to key.properties if provided
                    val envStorePath = System.getenv("KEYSTORE_PATH")
                    val envStorePassword = System.getenv("KEYSTORE_PASSWORD")
                    val envKeyAlias = System.getenv("KEY_ALIAS")
                    val envKeyPassword = System.getenv("KEY_PASSWORD")

                    val resolvedStoreFile = when {
                        !envStorePath.isNullOrBlank() -> file(envStorePath)
                        !keystoreProperties.getProperty("storeFile").isNullOrBlank() -> file(keystoreProperties.getProperty("storeFile"))
                        else -> null
                    }
                    if (resolvedStoreFile != null) {
                        println("Current directory: ${projectDir.absolutePath}")
                        println("Keystore path from env: $envStorePath")
                        println("Resolved keystore path: ${resolvedStoreFile.absolutePath}")
                        storeFile = resolvedStoreFile
                    }

                    storePassword = when {
                        !envStorePassword.isNullOrBlank() -> envStorePassword
                        !keystoreProperties.getProperty("storePassword").isNullOrBlank() -> keystoreProperties.getProperty("storePassword")
                        else -> null
                    }

                    keyAlias = when {
                        !envKeyAlias.isNullOrBlank() -> envKeyAlias
                        !keystoreProperties.getProperty("keyAlias").isNullOrBlank() -> keystoreProperties.getProperty("keyAlias")
                        else -> null
                    }

                    keyPassword = when {
                        !envKeyPassword.isNullOrBlank() -> envKeyPassword
                        !keystoreProperties.getProperty("keyPassword").isNullOrBlank() -> keystoreProperties.getProperty("keyPassword")
                        else -> null
                    }
                }
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true // Activar ofuscación y optimización
            isShrinkResources = true // Activar reducción de recursos
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }


    dependenciesInfo {
        // Disables dependency metadata when building APKs (for IzzyOnDroid/F-Droid)
        includeInApk = false
        // Disables dependency metadata when building Android App Bundles (for Google Play)
        includeInBundle = false
    }
}

flutter {
    source = "../.."
}
