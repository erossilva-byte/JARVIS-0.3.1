package com.jarvis.nova

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte da tela "Segundo plano" com o serviço de escuta.
 *
 * Só expõe o estado real e as duas decisões do usuário: ligar o modo sem tela e
 * autorizar "Exibir sobre outros apps" (necessário para abrir apps a partir do
 * segundo plano). [executarTexto] existe para o usuário testar um comando sem
 * falar; ele passa pelo mesmo interpretador e executor do serviço.
 */
class JarvisFundoCanal(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CANAL = "com.jarvis.nova/fundo"
    }

    fun registrar(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "estado" -> result.success(JarvisFundo.estado(activity))
            "definirModoSemTela" -> {
                val ativo = call.argument<Boolean>("ativo") ?: false
                JarvisFundo.definirModoSemTela(activity, ativo)
                result.success(JarvisFundo.estado(activity))
            }
            "abrirAjusteSobreposicao" -> result.success(abrirAjusteSobreposicao())
            "limparHistorico" -> {
                JarvisFundo.limparHistorico(activity)
                result.success(JarvisFundo.estado(activity))
            }
            "historicoExecucoes" -> result.success(JarvisFundo.historico(activity))
            "registrarExecucao" -> {
                val pedido = call.argument<String>("pedido").orEmpty().trim()
                if (pedido.isEmpty()) {
                    result.error("pedido_vazio", "O pedido executado não pode ficar vazio.", null)
                    return
                }
                JarvisFundo.registrarHistorico(
                    activity,
                    origem = call.argument<String>("origem") ?: JarvisFundo.ORIGEM_VOZ,
                    pedido = pedido,
                    acao = call.argument<String>("acao").orEmpty(),
                    ok = call.argument<Boolean>("ok") ?: false,
                    mensagem = call.argument<String>("mensagem").orEmpty(),
                )
                result.success(true)
            }
            "executarTexto" -> {
                val texto = call.argument<String>("texto").orEmpty().trim()
                if (texto.isEmpty()) {
                    result.error("texto_vazio", "Diga ou escreva o comando.", null)
                    return
                }
                val comando = JarvisFundo.interpretar(texto)
                val executado = JarvisFundo.executar(activity, comando)
                JarvisFundo.registrar(
                    activity,
                    comando,
                    executado,
                    origem = JarvisFundo.ORIGEM_TESTE,
                    pedido = texto,
                )
                result.success(
                    mapOf(
                        "ok" to executado.ok,
                        "mensagem" to executado.mensagem,
                        "acao" to comando.resumo(),
                        "ambiguidade" to executado.ambiguidade,
                    )
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun abrirAjusteSobreposicao(): Boolean {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${activity.packageName}")
        )
        return try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
