package com.example.taul

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.taul/installer"
    private val TAG = "TaulInstaller"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val filePath = call.argument<String>("filePath")
                    Log.d(TAG, "installApk called with filePath: $filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            Log.d(TAG, "File exists: ${file.exists()}, size: ${file.length()}")
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileProvider",
                                file
                            )
                            Log.d(TAG, "FileProvider URI: $uri")
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            Log.d(TAG, "Starting install intent...")
                            startActivity(intent)
                            Log.d(TAG, "Install intent started successfully")
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Install failed", e)
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    } else {
                        Log.e(TAG, "filePath is null")
                        result.error("INVALID_ARGS", "filePath is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
