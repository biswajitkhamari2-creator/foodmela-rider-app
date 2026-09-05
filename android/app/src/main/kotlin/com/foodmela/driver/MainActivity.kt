package com.foodmela.driver

import android.app.KeyguardManager
import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.foodmela.driver/alert"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playLoudBell") {
                try {
                    // 1. Wake Up Screen and Show Over Keyguard / Lock Screen
                    wakeUpScreenAndShowOverLockScreen()

                    // 2. Play Loud Alarm Tone (rings at max alarm volume)
                    val toneGen = ToneGenerator(AudioManager.STREAM_ALARM, 100)
                    toneGen.startTone(ToneGenerator.TONE_CDMA_HIGH_L, 1200)

                    // 3. Heavy Vibration
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                        val vibrator = vibratorManager.defaultVibrator
                        vibrator.vibrate(VibrationEffect.createOneShot(1000, VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                        vibrator.vibrate(1000)
                    }

                    result.success(true)
                } catch (e: Exception) {
                    result.error("ALERT_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun wakeUpScreenAndShowOverLockScreen() {
        try {
            // Turn on screen via PowerManager
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "FoodMelaDriver:LockScreenWakeLock"
            )
            wakeLock.acquire(5000) // Keep screen awake for 5s per ring

            // Dismiss Keyguard and turn screen on
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
        } catch (e: Exception) {
            // Ignore if device permission restricted
        }
    }
}
