package com.financetrack.finance_track

import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zyvault/speech")
            .setMethodCallHandler { call, result ->
                if (call.method == "installMalayalamVoice") {
                    result.success(openVoiceInstall())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openVoiceInstall(): Boolean {
        val install = Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).apply {
            setPackage("com.google.android.tts")
            putStringArrayListExtra(
                TextToSpeech.Engine.EXTRA_CHECK_VOICE_DATA_FOR,
                arrayListOf("ml-IN"),
            )
        }
        if (startIfFound(install)) return true
        return startIfFound(Intent("com.android.settings.TTS_SETTINGS"))
    }

    private fun startIfFound(intent: Intent): Boolean {
        if (intent.resolveActivity(packageManager) == null) return false
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
