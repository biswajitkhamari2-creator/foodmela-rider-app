package com.foodmela.driver

import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ─── Food Mela Rider — incoming-order ALERT engine ───────────────────────────
// Drives the call-style alert from native code so it survives background /
// lock-screen states where Dart isolates can't reliably loop audio:
//
//  • startOrderAlert(orderId): wake + show over lock screen, loop the bundled
//    FoodMela ringtone on the ALARM stream (audible even in silent mode),
//    and vibrate on a repeating waveform. Ref-counted per orderId — a second
//    order never double-plays; the sound stops only when the set is empty.
//  • stopOrderAlert(orderId) / stopAllAlerts(): release player, vibration,
//    wake-lock and lock-screen flags.
//
// Returns true from startOrderAlert only when the custom ringtone actually
// started — Dart plays the system-ringtone fallback when it returns false.
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.foodmela.driver/alert"

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val alertOrders = mutableSetOf<String>()

    // Vibrate 0.8s — pause 0.4s — vibrate 0.8s — pause 0.4s — vibrate 1.2s, repeat.
    private val VIB_PATTERN = longArrayOf(0, 800, 400, 800, 400, 1200)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startOrderAlert" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    var soundOn = false
                    runOnUiThread {
                        try {
                            if (orderId.isNotEmpty()) alertOrders.add(orderId)
                            wakeUpScreenAndShowOverLockScreen()
                            bringToForeground(orderId)
                            soundOn = startLoopingRingtone()
                            startRepeatingVibration()
                        } catch (_: Exception) { }
                        result.success(soundOn)
                    }
                }
                "stopOrderAlert" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    runOnUiThread {
                        try {
                            if (orderId.isNotEmpty()) alertOrders.remove(orderId)
                            if (alertOrders.isNotEmpty()) {
                                result.success(true)
                                return@runOnUiThread
                            }
                            releaseAlert()
                        } catch (_: Exception) { }
                        result.success(true)
                    }
                }
                "stopAllAlerts" -> {
                    runOnUiThread {
                        try {
                            alertOrders.clear()
                            releaseAlert()
                        } catch (_: Exception) { }
                        result.success(true)
                    }
                }
                // Can the OS auto-launch the full-screen call UI from background?
                // Android 14+ gates this behind a user-granted special permission.
                "canUseFullScreenIntent" -> {
                    var allowed = true
                    try {
                        if (Build.VERSION.SDK_INT >= 34) {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            allowed = nm.canUseFullScreenIntent()
                        }
                    } catch (_: Exception) { }
                    result.success(allowed)
                }
                // Open the exact Settings page where the user grants it.
                "openFullScreenIntentSettings" -> {
                    runOnUiThread {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= 34) {
                                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            } else {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                // Check if Display over other apps (Overlay) is granted
                "canDrawOverlays" -> {
                    var allowed = true
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            allowed = Settings.canDrawOverlays(this)
                        }
                    } catch (_: Exception) { }
                    result.success(allowed)
                }
                // Open Overlay Settings
                "openOverlaySettings" -> {
                    runOnUiThread {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(true)
                            }
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                // Check if Battery Optimization is ignored
                "isIgnoringBatteryOptimizations" -> {
                    var ignoring = true
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            ignoring = pm.isIgnoringBatteryOptimizations(packageName)
                        }
                    } catch (_: Exception) { }
                    result.success(ignoring)
                }
                // Request Battery Optimization Exemption
                "requestIgnoreBatteryOptimizations" -> {
                    runOnUiThread {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(true)
                            }
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                // Bring app to foreground over other apps (WhatsApp call behavior)
                "bringAppToForeground" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    runOnUiThread {
                        try {
                            bringToForeground(orderId)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                // Legacy one-shot entry (kept so older Dart code never crashes).
                "playLoudBell" -> {
                    runOnUiThread {
                        try {
                            alertOrders.add("legacy")
                            wakeUpScreenAndShowOverLockScreen()
                            startLoopingRingtone()
                            startRepeatingVibration()
                        } catch (_: Exception) { }
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            alertOrders.clear()
            releaseAlert()
        } catch (_: Exception) { }
        super.onDestroy()
    }

    // ── Ringtone ─────────────────────────────────────────────────────────────
    private fun startLoopingRingtone(): Boolean {
        if (mediaPlayer != null) return true
        return try {
            val afd: AssetFileDescriptor =
                assets.openFd("flutter_assets/assets/sounds/food_mela_ringtone.wav")
            val mp = MediaPlayer()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            } else {
                @Suppress("DEPRECATION")
                mp.setAudioStreamType(AudioManager.STREAM_ALARM)
            }
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            mp.isLooping = true
            mp.setVolume(1.0f, 1.0f)
            mp.prepare()
            mp.start()
            mediaPlayer = mp
            true
        } catch (_: Exception) {
            false
        }
    }

    // ── Vibration (repeating waveform until released) ────────────────────────
    private fun defaultVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun startRepeatingVibration() {
        try {
            val vib = defaultVibrator() ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(VibrationEffect.createWaveform(VIB_PATTERN, 0))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(VIB_PATTERN, 0)
            }
        } catch (_: Exception) { }
    }

    // ── Wake + show over lock screen ─────────────────────────────────────────
    private fun wakeUpScreenAndShowOverLockScreen() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                km.requestDismissKeyguard(this, null)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (wakeLock == null) {
                @Suppress("DEPRECATION")
                wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "FoodMelaDriver:OrderAlert"
                )
                wakeLock?.setReferenceCounted(false)
            }
            if (wakeLock?.isHeld != true) wakeLock?.acquire(10 * 60 * 1000L)
        } catch (_: Exception) { }
    }

    // ── Bring Activity to front over any active app (WhatsApp Call behavior) ─
    private fun bringToForeground(orderId: String = "") {
        try {
            wakeUpScreenAndShowOverLockScreen()
            val intent = Intent(applicationContext, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                if (orderId.isNotEmpty()) {
                    putExtra("orderId", orderId)
                    putExtra("incoming_order_call", true)
                }
            }

            val bundle: Bundle? = if (Build.VERSION.SDK_INT >= 34) {
                try {
                    val opts = ActivityOptions.makeBasic()
                    val method = opts.javaClass.getMethod(
                        "setPendingIntentBackgroundActivityStartMode",
                        Int::class.javaPrimitiveType
                    )
                    method.invoke(opts, 1) // 1 = MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    opts.toBundle()
                } catch (_: Exception) {
                    null
                }
            } else {
                null
            }

            val pendingIntent = PendingIntent.getActivity(
                applicationContext,
                2024,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            try {
                if (bundle != null) {
                    pendingIntent.send(applicationContext, 0, null, null, null, null, bundle)
                } else {
                    pendingIntent.send()
                }
            } catch (_: Exception) {
                if (bundle != null) {
                    startActivity(intent, bundle)
                } else {
                    startActivity(intent)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("FoodMela", "bringToForeground error: ${e.message}")
        }
    }

    // ── Release everything ───────────────────────────────────────────────────
    private fun releaseAlert() {
        try {
            mediaPlayer?.let {
                try { it.stop() } catch (_: Exception) { }
                try { it.release() } catch (_: Exception) { }
            }
        } catch (_: Exception) { }
        mediaPlayer = null
        try {
            defaultVibrator()?.cancel()
        } catch (_: Exception) { }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            } else {
                @Suppress("DEPRECATION")
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
        } catch (_: Exception) { }
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) { }
        wakeLock = null
    }
}
