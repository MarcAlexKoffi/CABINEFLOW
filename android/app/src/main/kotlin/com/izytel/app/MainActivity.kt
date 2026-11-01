package com.izytel.app

import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val sessionChannel = "com.izytel/session_preferences"
    private val preferencesName = "izytel_session_preferences"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.izytel/ussd_dialer").setMethodCallHandler { call, result ->
            if (call.method != "openDialer") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val code = call.argument<String>("code") ?: ""
            if (code.length > 182 || !Regex("^(?:\\*{1,2}|#)[0-9]+(?:\\*[0-9]+)*#$").matches(code)) {
                result.error("invalid_template", "Syntaxe USSD invalide.", null)
                return@setMethodCallHandler
            }
            try {
                // fromParts encodes '#'; ACTION_DIAL always requires the user's
                // own confirmation in the phone app. Never request CALL_PHONE.
                startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", code, null)))
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("dialer_unavailable", "Composeur indisponible.", null)
            } catch (_: SecurityException) {
                result.error("dialer_unavailable", "Composeur inaccessible.", null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            sessionChannel
        ).setMethodCallHandler { call, result ->
            val preferences = getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

            when (call.method) {
                "getRememberedSession" -> {
                    result.success(
                        mapOf(
                            "rememberMe" to preferences.getBoolean("remember_me", false),
                            "email" to (preferences.getString("email", "") ?: "")
                        )
                    )
                }

                "saveRememberedSession" -> {
                    val rememberMe = call.argument<Boolean>("rememberMe") ?: false
                    val email = call.argument<String>("email") ?: ""
                    preferences.edit()
                        .putBoolean("remember_me", rememberMe)
                        .putString("email", email)
                        .apply()
                    result.success(null)
                }

                "clearRememberedSession" -> {
                    preferences.edit().clear().apply()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
