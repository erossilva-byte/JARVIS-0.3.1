package com.jarvis.nova

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private var eventSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun emitWake(keyword: String) {
            mainHandler.post {
                eventSink?.success(keyword)
            }
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingTestSeconds: Int? = null
    private val requestAudioCode = 47147

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws")
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws/events")
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(statusMap())
            "start" -> ensurePermissionAndStart(result, null)
            "test" -> {
                val seconds = (call.argument<Number>("seconds")?.toInt() ?: 20).coerceIn(10, 60)
                ensurePermissionAndStart(result, seconds)
            }
            "stop" -> {
                stopService(Intent(this, KwsForegroundService::class.java))
                KwsForegroundService.clearState()
                result.success(statusMap())
            }
            else -> result.notImplemented()
        }
    }

    private fun ensurePermissionAndStart(result: MethodChannel.Result, testSeconds: Int?) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED) {
            startAndAwaitEngine(result, testSeconds)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("request_in_progress", "Já existe uma solicitação de microfone em andamento.", null)
            return
        }
        pendingPermissionResult = result
        pendingTestSeconds = testSeconds
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), requestAudioCode)
    }

    @Deprecated("Deprecated in Android API; retained for FlutterActivity compatibility")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != requestAudioCode) return
        val result = pendingPermissionResult ?: return
        val testSeconds = pendingTestSeconds
        pendingPermissionResult = null
        pendingTestSeconds = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startAndAwaitEngine(result, testSeconds)
        } else {
            result.success(mapOf(
                "available" to true,
                "listening" to false,
                "engine" to KwsForegroundService.ENGINE,
                "detail" to "Permissão de microfone negada. O KWS não foi iniciado."
            ))
        }
    }

    private fun startAndAwaitEngine(result: MethodChannel.Result, testSeconds: Int?) {
        KwsForegroundService.clearError()
        val intent = Intent(this, KwsForegroundService::class.java).apply {
            action = KwsForegroundService.ACTION_START
            if (testSeconds != null) putExtra(KwsForegroundService.EXTRA_TEST_SECONDS, testSeconds)
        }
        try {
            ContextCompat.startForegroundService(this, intent)
        } catch (error: Exception) {
            result.success(mapOf(
                "available" to true,
                "listening" to false,
                "engine" to KwsForegroundService.ENGINE,
                "detail" to "Não foi possível iniciar o serviço KWS: ${error.message ?: error.javaClass.simpleName}"
            ))
            return
        }
        awaitEngineState(result, System.currentTimeMillis() + 10000L)
    }

    private fun awaitEngineState(result: MethodChannel.Result, deadline: Long) {
        val listening = KwsForegroundService.isListening()
        val error = KwsForegroundService.lastError()
        if (listening || error.isNotEmpty() || System.currentTimeMillis() >= deadline) {
            result.success(statusMap())
            return
        }
        mainHandler.postDelayed({ awaitEngineState(result, deadline) }, 120L)
    }

    private fun statusMap(): Map<String, Any> = mapOf(
        "available" to true,
        "listening" to KwsForegroundService.isListening(),
        "engine" to KwsForegroundService.ENGINE,
        "detail" to KwsForegroundService.lastError().ifEmpty {
            if (KwsForegroundService.isListening()) "Detector sherpa-onnx ativo; áudio processado localmente."
            else if (KwsForegroundService.isServiceRunning()) "Serviço ativo; aguardando confirmação de captura e inferência."
            else "Plugin Android carregado; serviço KWS parado."
        }
    )

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDestroy() {
        if (pendingPermissionResult != null) {
            pendingPermissionResult?.error("activity_destroyed", "A tela foi encerrada durante a permissão do microfone.", null)
            pendingPermissionResult = null
        }
        super.onDestroy()
    }
}
