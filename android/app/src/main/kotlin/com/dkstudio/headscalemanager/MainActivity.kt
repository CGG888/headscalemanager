package com.dkstudio.headscalemanager

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Required for Android 15+ edge-to-edge compliance (Google Play).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
