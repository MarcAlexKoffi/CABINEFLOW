package com.cabineflow.cabine_flow

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val sessionChannel = "com.izytel/session_preferences"
    private val preferencesName = "izytel_session_preferences"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
