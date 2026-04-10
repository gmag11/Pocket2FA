# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage — keep EncryptedSharedPreferences and its Jetpack Security dependencies.
# EncryptedSharedPreferences uses Tink via reflection at runtime; without these rules R8 strips
# the crypto classes and the first secure-storage call throws a ClassNotFoundException, which
# causes main() to abort before runApp() is reached (blank screen on release builds).
-keep class androidx.security.crypto.** { *; }
-keepclassmembers class androidx.security.crypto.** { *; }

# Tink (used internally by EncryptedSharedPreferences / Jetpack Security Crypto)
-keep class com.google.crypto.tink.** { *; }
-keepclassmembers class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# local_auth — BiometricPrompt / BiometricManager are loaded reflectively by the plugin.
-keep class androidx.biometric.** { *; }
-keepclassmembers class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Flutter engine references Play Core (deferred components) but this app does not use Play Store
# delivery. Suppress the missing-class warnings that R8 raises when following those references.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
