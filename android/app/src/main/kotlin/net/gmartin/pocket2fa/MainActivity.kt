package net.gmartin.pocket2fa

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    // Override onActivityResult to handle null bundles gracefully
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        try {
            super.onActivityResult(requestCode, resultCode, data)
        } catch (e: NullPointerException) {
            // Handle null pointer exception gracefully
            android.util.Log.w("MainActivity", "NullPointerException in onActivityResult: ${e.message}")
        }
    }
}
