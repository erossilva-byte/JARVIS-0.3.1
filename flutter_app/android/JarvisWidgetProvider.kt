package com.jarvis.nova

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Widget da tela inicial: mostra o último estado conhecido do JARVIS e abre a voz ou a
 * conversa. O estado chega pelo canal `com.jarvis.nova/sistema` (método `atualizarWidget`);
 * sem atualização, o widget mostra o texto neutro em vez de inventar "online".
 */
class JarvisWidgetProvider : AppWidgetProvider() {
    companion object {
        const val PREFS = "jarvis_widget"
        const val CHAVE_STATUS = "status"
        private const val STATUS_NEUTRO = "JARVIS pronto"

        fun atualizar(contexto: Context, texto: String) {
            val limpo = texto.trim().ifEmpty { STATUS_NEUTRO }
            contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(CHAVE_STATUS, limpo).apply()
            val gerente = AppWidgetManager.getInstance(contexto) ?: return
            val ids = gerente.getAppWidgetIds(
                android.content.ComponentName(contexto, JarvisWidgetProvider::class.java)
            )
            ids.forEach { gerente.updateAppWidget(it, montar(contexto, limpo)) }
        }

        fun montar(contexto: Context, status: String): RemoteViews {
            val views = RemoteViews(contexto.packageName, R.layout.jarvis_widget)
            views.setTextViewText(R.id.widget_status, status)
            views.setOnClickPendingIntent(R.id.widget_falar, abrir(contexto, MainActivity.ACAO_VOZ))
            views.setOnClickPendingIntent(R.id.widget_conversa, abrir(contexto, MainActivity.ACAO_CONVERSA))
            return views
        }

        private fun abrir(contexto: Context, acao: String): PendingIntent {
            val intent = Intent(contexto, MainActivity::class.java).apply {
                action = acao
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                contexto,
                acao.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    override fun onUpdate(contexto: Context, gerente: AppWidgetManager, ids: IntArray) {
        val status = contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(CHAVE_STATUS, STATUS_NEUTRO)
            ?: STATUS_NEUTRO
        ids.forEach { gerente.updateAppWidget(it, montar(contexto, status)) }
    }
}
