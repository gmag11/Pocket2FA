plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "net.gmartin.pocket2fa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Load keystore properties if present
    val keystoreProperties = Properties().apply {
        // IMPORTANT: resolve relative to the :app module directory
        val keystoreFile = file("../key.properties")
        if (keystoreFile.exists()) {
            keystoreFile.inputStream().use { this.load(it) }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "net.gmartin.pocket2fa"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 14
        versionName = flutter.versionName
    }

    // Check if we have valid signing configuration
    val hasValidSigningConfig = run {
        val envStorePath = System.getenv("KEYSTORE_PATH")
        val keystoreFromProps = keystoreProperties.getProperty("storeFile")
        
        val keystoreFile = when {
            !envStorePath.isNullOrBlank() -> file(envStorePath)
            !keystoreFromProps.isNullOrBlank() -> file(keystoreFromProps)
            else -> null
        }
        
        keystoreFile?.exists() == true
    }

    // Signing configs should be declared at the android level (not nested inside buildTypes)
    signingConfigs {
        if (hasValidSigningConfig) {
            create("release") {
                // Prefer environment variables for sensitive data; fallback to android/key.properties if provided
                val envStorePath = System.getenv("KEYSTORE_PATH")
                val envStorePassword = System.getenv("KEYSTORE_PASSWORD")
                val envKeyAlias = System.getenv("KEY_ALIAS")
                val envKeyPassword = System.getenv("KEY_PASSWORD")

                val resolvedStoreFile = when {
                    !envStorePath.isNullOrBlank() -> {
                        // Resolve environment variable path relative to app directory
                        file(envStorePath)
                    }
                    !keystoreProperties.getProperty("storeFile").isNullOrBlank() -> {
                        // Resolve property file path relative to app directory
                        file(keystoreProperties.getProperty("storeFile"))
                    }
                    else -> null
                }
                
                if (resolvedStoreFile != null) {
                    println("=== Keystore Configuration ===")
                    println("Project directory: ${projectDir.absolutePath}")
                    println("Keystore path from env: $envStorePath")
                    println("Resolved keystore file: ${resolvedStoreFile.absolutePath}")
                    println("Keystore exists: ${resolvedStoreFile.exists()}")
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
                
                println("Signing config - Store password set: ${!storePassword.isNullOrBlank()}")
                println("Signing config - Key alias set: ${!keyAlias.isNullOrBlank()}")
                println("Signing config - Key password set: ${!keyPassword.isNullOrBlank()}")
            }
        } else {
            println("=== WARNING: No keystore configuration found ===")
            println("Building release APK without signing (will use debug signature)")
            println("To sign the release, provide either:")
            println("  1. Environment variables: KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD")
            println("  2. File android/key.properties with storeFile, storePassword, keyAlias, keyPassword")
        }
    }

    buildTypes {
        release {
            // Use release signing config if available, otherwise use debug signing
            signingConfig = if (hasValidSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
