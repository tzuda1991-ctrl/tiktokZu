package com.retrytech.shortzz

import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "shortzz/google_picker"
    private val PICK_ACCOUNT_REQUEST = 9001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickGoogleAccount") {
                pendingResult = result
                try {
                    val intent = AccountManager.newChooseAccountIntent(
                        null,
                        null,
                        arrayOf("com.google"),
                        null,
                        null,
                        null,
                        null
                    )
                    startActivityForResult(intent, PICK_ACCOUNT_REQUEST)
                } catch (e: Throwable) {
                    pendingResult = null
                    result.error("PICKER_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
        super.configureFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PICK_ACCOUNT_REQUEST) {
            val res = pendingResult
            pendingResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val accountName = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                res?.success(accountName)
            } else {
                res?.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
