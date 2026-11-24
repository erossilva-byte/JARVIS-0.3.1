package com.jarvis.nova

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

/**
 * Agenda real do Android para tarefas e automações de horário.
 *
 * Usa `setAlarmClock`, que é tratado pelo sistema como alarme do usuário e não
 * exige a permissão SCHEDULE_EXACT_ALARM. O registro é gravado antes de
 * programar; se programar falhar, o registro é removido para a tela não dizer
 * que existe um lembrete que nunca vai tocar. Alarme diário é reprogramado pelo
 * receptor depois de disparar, porque o `AlarmManager` não tem repetição diária
 * exata.
 */
object JarvisAgenda {
    private const val PREFS = "jarvis_agenda"
    private const val PREFIXO = "lembrete_"
    const val ACAO_ALARME = "com.jarvis.nova.AGENDA_ALARME"
    const val CANAL = "jarvis_agenda_avisos"

    fun agendar(
        contexto: Context,
        id: Int,
        quando: Long,
        titulo: String,
        texto: String,
        repetirDiario: Boolean,
        repeticao: String = "umaVez"
    ): Map<String, Any> {
        if (id < 1) {
            return mapOf("ok" to false, "mensagem" to "Identificador de lembrete inválido.")
        }
        if (quando <= System.currentTimeMillis() - 60_000L) {
            return mapOf("ok" to false, "mensagem" to "O horário do lembrete já passou.")
        }
        val registro = JSONObject().apply {
            put("id", id)
            put("quando", quando)
            put("titulo", titulo.ifBlank { "Jarvis" })
            put("texto", texto)
            put("repetirDiario", repetirDiario)
            put("repeticao", normalizarRepeticao(repeticao))
        }
        return try {
            preferencias(contexto).edit().putString(PREFIXO + id, registro.toString()).commit()
            programar(contexto, registro)
            mapOf("ok" to true, "mensagem" to "Lembrete agendado no Android.")
        } catch (e: Exception) {
            preferencias(contexto).edit().remove(PREFIXO + id).apply()
            mapOf(
                "ok" to false,
                "mensagem" to "O Android recusou o alarme: ${e.message ?: e.javaClass.simpleName}"
            )
        }
    }

    fun cancelar(contexto: Context, id: Int) {
        try {
            val gerenciador =
                contexto.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intencao = Intent(contexto, JarvisAgendaReceiver::class.java)
                .setAction(ACAO_ALARME)
            val pendente = PendingIntent.getBroadcast(contexto, id, intencao, flagsPendente())
            gerenciador.cancel(pendente)
            pendente.cancel()
        } catch (_: Exception) {
            // Sem o alarme programado, cancelar é só limpar o registro abaixo.
        }
        preferencias(contexto).edit().remove(PREFIXO + id).apply()
    }

    fun concluir(contexto: Context, id: Int) {
        preferencias(contexto).edit().remove(PREFIXO + id).apply()
    }

    fun restaurar(contexto: Context) {
        val sp = preferencias(contexto)
        val agora = System.currentTimeMillis()
        for ((chave, valor) in HashMap(sp.all)) {
            if (!chave.startsWith(PREFIXO) || valor !is String) continue
            val registro = try {
                JSONObject(valor)
            } catch (_: Exception) {
                sp.edit().remove(chave).apply()
                continue
            }
            val id = registro.optInt("id", -1)
            val quando = registro.optLong("quando", 0L)
            if (id < 1) {
                sp.edit().remove(chave).apply()
                continue
            }
            if (quando <= agora) {
                val repeticao = registro.optString("repeticao").ifEmpty {
                    if (registro.optBoolean("repetirDiario", false)) "diaria" else "umaVez"
                }
                if (repeticao != "umaVez") {
                    registro.put("quando", proximoCiclo(quando, repeticao))
                    sp.edit().putString(chave, registro.toString()).apply()
                    try {
                        programar(contexto, registro)
                    } catch (_: Exception) {
                        // Mantém o registro: pode ser uma falha temporária.
                    }
                } else {
                    sp.edit().remove(chave).apply()
                }
                continue
            }
            try {
                programar(contexto, registro)
            } catch (_: Exception) {
                // Mantém o registro para tentar de novo na próxima abertura.
            }
        }
    }

    fun repetir(
        contexto: Context,
        id: Int,
        titulo: String,
        texto: String,
        repeticao: String = "diaria"
    ): Boolean {
        val ciclo = normalizarRepeticao(repeticao)
        val quando = proximoCiclo(System.currentTimeMillis(), ciclo)
        val registro = JSONObject().apply {
            put("id", id)
            put("quando", quando)
            put("titulo", titulo.ifBlank { "Jarvis" })
            put("texto", texto)
            put("repetirDiario", ciclo == "diaria")
            put("repeticao", ciclo)
        }
        return try {
            preferencias(contexto).edit().putString(PREFIXO + id, registro.toString()).commit()
            programar(contexto, registro)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun notificar(contexto: Context, id: Int, titulo: String, texto: String) {
        try {
            val gerenciador =
                contexto.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26 &&
                gerenciador.getNotificationChannel(CANAL) == null
            ) {
                val canal = NotificationChannel(
                    CANAL,
                    "Tarefas e automações",
                    NotificationManager.IMPORTANCE_HIGH
                )
                canal.description = "Avisos de tarefas e automações do JARVIS Nova"
                gerenciador.createNotificationChannel(canal)
            }
            val abrir = Intent(contexto, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val mostrar = PendingIntent.getActivity(contexto, id, abrir, flagsPendente())
            val construtor = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(contexto, CANAL)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(contexto)
            }
            construtor
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(titulo)
                .setContentText(texto)
                .setStyle(Notification.BigTextStyle().bigText(texto))
                .setContentIntent(mostrar)
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_REMINDER)
            if (Build.VERSION.SDK_INT < 26) {
                @Suppress("DEPRECATION")
                construtor.setPriority(Notification.PRIORITY_HIGH)
            }
            gerenciador.notify(id, construtor.build())
        } catch (_: Exception) {
            // Sem permissão de notificação o alarme ainda tocou; a tela informa
            // essa limitação e não finge que o aviso apareceu.
        }
    }

    private fun programar(contexto: Context, registro: JSONObject) {
        val id = registro.getInt("id")
        val quando = registro.getLong("quando")
        val intencao = Intent(contexto, JarvisAgendaReceiver::class.java).apply {
            action = ACAO_ALARME
            putExtra("id", id)
            putExtra("titulo", registro.optString("titulo", "Jarvis"))
            putExtra("texto", registro.optString("texto", ""))
            putExtra("repetirDiario", registro.optBoolean("repetirDiario", false))
            putExtra("repeticao", registro.optString("repeticao", "umaVez"))
        }
        val pendente = PendingIntent.getBroadcast(contexto, id, intencao, flagsPendente())

        val abrir = Intent(contexto, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val mostrar = PendingIntent.getActivity(contexto, id, abrir, flagsPendente())
        val gerenciador =
            contexto.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: throw IllegalStateException("AlarmManager indisponível")
        gerenciador.setAlarmClock(AlarmManager.AlarmClockInfo(quando, mostrar), pendente)
    }

    /** Aceita só os nomes que o Dart manda; qualquer outra coisa vira uma vez só. */
    private fun normalizarRepeticao(valor: String): String =
        when (valor.trim().lowercase()) {
            "diaria", "semanal", "mensal", "anual" -> valor.trim().lowercase()
            else -> "umaVez"
        }

    /** Próximo ciclo depois de [quando]: dia, semana, mês ou ano. */
    private fun proximoCiclo(quando: Long, repeticao: String): Long {
        val calendario = Calendar.getInstance().apply { timeInMillis = quando }
        do {
            when (repeticao) {
                "semanal" -> calendario.add(Calendar.DAY_OF_YEAR, 7)
                "mensal" -> calendario.add(Calendar.MONTH, 1)
                "anual" -> calendario.add(Calendar.YEAR, 1)
                else -> calendario.add(Calendar.DAY_OF_YEAR, 1)
            }
        } while (calendario.timeInMillis <= System.currentTimeMillis())
        return calendario.timeInMillis
    }

    private fun proximoDia(quando: Long): Long {
        val calendario = Calendar.getInstance().apply { timeInMillis = quando }
        do {
            calendario.add(Calendar.DAY_OF_YEAR, 1)
        } while (calendario.timeInMillis <= System.currentTimeMillis())
        return calendario.timeInMillis
    }

    private fun preferencias(contexto: Context) =
        contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun flagsPendente(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
}

/** Receptor do alarme e da restauração depois de reiniciar o aparelho. */
class JarvisAgendaReceiver : BroadcastReceiver() {
    override fun onReceive(contexto: Context, intencao: Intent) {
        val ctx = contexto.applicationContext
        when (intencao.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> JarvisAgenda.restaurar(ctx)

            JarvisAgenda.ACAO_ALARME -> {
                val id = intencao.getIntExtra("id", -1)
                if (id < 1) return
                val titulo = intencao.getStringExtra("titulo") ?: "Jarvis"
                val texto = intencao.getStringExtra("texto") ?: ""
                val repeticao = intencao.getStringExtra("repeticao").orEmpty()
                    .ifEmpty {
                        if (intencao.getBooleanExtra("repetirDiario", false)) {
                            "diaria"
                        } else {
                            "umaVez"
                        }
                    }
                JarvisAgenda.concluir(ctx, id)
                JarvisAgenda.notificar(ctx, id, titulo, texto)
                if (repeticao != "umaVez") {
                    JarvisAgenda.repetir(ctx, id, titulo, texto, repeticao)
                }
            }
        }
    }
}
