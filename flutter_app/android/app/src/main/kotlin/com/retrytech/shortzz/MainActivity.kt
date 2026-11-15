package com.retrytech.shortzz

import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import com.baseflow.permissionhandler.PermissionHandlerPlugin
import com.retrytech.retrytech_plugin.RetrytechPlugin
import com.revenuecat.purchases_flutter.PurchasesFlutterPlugin
import com.ryanheise.just_audio.JustAudioPlugin
import com.tekartik.sqflite.SqflitePlugin
import im.zego.zego_express_engine.ZegoExpressEnginePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.videoplayer.VideoPlayerPlugin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "shortzz/google_picker"
    private val PICK_ACCOUNT_REQUEST = 9001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PurchasesFlutterPlugin())
        flutterEngine.plugins.add(SqflitePlugin())
        flutterEngine.plugins.add(VideoPlayerPlugin())
        flutterEngine.plugins.add(ZegoExpressEnginePlugin())
        flutterEngine.plugins.add(PermissionHandlerPlugin())
        flutterEngine.plugins.add(JustAudioPlugin())
        flutterEngine.plugins.add(RetrytechPlugin())

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
                } catch (e: Exception) {
                    pendingResult = null
                    result.error("PICKER_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_ACCOUNT_REQUEST) {
            val res = pendingResult
            pendingResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val accountName = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                res?.success(accountName)
            } else {
                res?.success(null)
            }
        }
    }
}
