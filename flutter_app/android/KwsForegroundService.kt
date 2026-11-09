package com.jarvis.nova

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Serviço foreground dedicado ao KWS Flutter. A captura só começa após permissão
 * explícita e após o Android aceitar o serviço do tipo microphone.
 */
class KwsForegroundService : Service() {
    companion object {
        const val ENGINE = "sherpa-onnx-kws-gigaspeech-en"
        const val ACTION_START = "com.jarvis.nova.KWS_START"
        const val EXTRA_TEST_SECONDS = "test_seconds"
        private const val CHANNEL_ID = "jarvis_kws_local"
        private const val NOTIFICATION_ID = 14701

        @Volatile private var running = false
        @Volatile private var listening = false
        @Volatile private var error = ""

        @JvmStatic fun isServiceRunning() = running
        @JvmStatic fun isListening() = listening
        @JvmStatic fun lastError() = error
        @JvmStatic fun clearError() { error = "" }
        @JvmStatic fun clearState() {
            running = false
            listening = false
            error = ""
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var engine: JarvisKwsEngine? = null
    private var testStop: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = buildNotification("Preparando detector acústico local…")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val testSeconds = intent.getIntExtra(EXTRA_TEST_SECONDS, 0).coerceIn(0, 60)

        // Um pedido "Ativar" recebido durante o teste deve transformar a sessão
        // temporária em escuta contínua, não ser ignorado e deixar o timer desligá-la.
        if (engine?.isRunning == true) {
            testStop?.let(handler::removeCallbacks)
            testStop = null
            if (testSeconds > 0) scheduleTestStop(testSeconds)
            else updateNotification("Ouvindo palavra de ativação localmente")
            return START_NOT_STICKY
        }

        testStop?.let(handler::removeCallbacks)
        testStop = null
        error = ""
        listening = false
        engine?.stop()
        engine = JarvisKwsEngine(
            applicationContext,
            object : JarvisKwsEngine.Listener {
                override fun onDetected(keyword: String) {
                    handler.post {
                        listening = false
                        updateNotification("Palavra de ativação detectada")
                        MainActivity.emitWake(keyword)
                        // Reabre o app em primeiro plano. O fluxo de comando de voz é
                        // iniciado pela camada de conversa numa etapa seguinte.
                        val launch = packageManager.getLaunchIntentForPackage(packageName)
                        launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        launch?.putExtra("jarvis_wake_keyword", keyword)
                        if (launch != null) startActivity(launch)
                        stopSelf()
                    }
                }

                override fun onError(message: String) {
                    handler.post {
                        listening = false
                        error = message
                        updateNotification("Detector parado: falha")
                        stopSelf()
                    }
                }

                override fun onState(state: String) {
                    handler.post {
                        listening = state.startsWith("KWS local ativo")
                        updateNotification(if (listening) "Ouvindo palavra de ativação localmente" else state)
                    }
                }
            },
            55,
            ""
        )
        engine?.start()
        if (testSeconds > 0) scheduleTestStop(testSeconds)
        return START_NOT_STICKY
    }

    private fun scheduleTestStop(seconds: Int) {
        testStop?.let(handler::removeCallbacks)
        val stopTest = Runnable {
            testStop = null
            engine?.stop()
            listening = false
            updateNotification("Teste de ativação concluído")
            stopSelf()
        }
        testStop = stopTest
        handler.postDelayed(stopTest, seconds * 1000L)
    }

    override fun onDestroy() {
        testStop?.let(handler::removeCallbacks)
        testStop = null
        engine?.stop()
        engine = null
        listening = false
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Palavra de ativação do J.A.R.V.I.S.",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Estado do detector acústico local sherpa-onnx." }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(message: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("J.A.R.V.I.S. Nova")
            .setContentText(message)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()

    private fun updateNotification(message: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(message))
    }
}
