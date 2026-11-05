package com.financetrack.finance_track

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.speech.tts.TextToSpeech
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zyvault/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "versionCode" -> {
                        result.success(installedVersionCode())
                        return@setMethodCallHandler
                    }
                    "install" -> Unit
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("path", "Missing update file", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(installApk(path))
                } catch (error: Exception) {
                    result.error("install", error.message, null)
                }
            }
    }

    private fun installedVersionCode(): Int {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toInt()
        } else {
            @Suppress("DEPRECATION")
            info.versionCode
        }
    }

    private fun installApk(path: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return "permission"
        }
        val file = File(path)
        if (!file.exists()) throw IllegalArgumentException("Update file is missing")
        val uri = FileProvider.getUriForFile(this, "$packageName.update", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        return "ok"
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
