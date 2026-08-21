package com.hariverse.hledger

import com.hariverse.hledger.detection.CaptureBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Uses the application context: the capture layer outlives this Activity.
        CaptureBridge.register(applicationContext, flutterEngine)
    }
}
