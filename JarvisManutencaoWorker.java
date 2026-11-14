package com.jarvis.nova;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import java.util.concurrent.TimeUnit;

/**
 * Manutenção periódica do segundo plano (Fase 4B) com WorkManager.
 *
 * O WorkManager é o caminho que o Android aceita dentro do Doze: o sistema escolhe a hora,
 * respeita a restrição de bateria e retoma depois do reinício. Aqui ele faz o que não
 * depende da tela: restaura os lembretes futuros, devolve a escuta ao vigia quando ela
 * deveria estar no ar e registra quando rodou, para o diagnóstico mostrar a hora real.
 *
 * As rotinas em si continuam rodando na interface: um Worker não abre a WebView nem
 * executa o JavaScript das rotinas. Prometer isso seria mentira.
 */
public class JarvisManutencaoWorker extends Worker {

    static final String NOME = "jarvis-manutencao";
    static final long INTERVALO_HORAS = 6;

    public JarvisManutencaoWorker(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context c = getApplicationContext();
        try {
            JarvisAlarmScheduler.restaurar(c);
            JarvisPrefs.ultimaManutencao(c, System.currentTimeMillis());
            boolean deveOuvir = JarvisPrefs.desejaOuvir(c)
                && !JarvisPrefs.pausadoManual(c)
                && JarvisService.bloqueioBateria(c).isEmpty();
            if (deveOuvir && !JarvisService.ativo()) {
                // Serviço fora do ar: o alarme rápido tem a isenção que o Worker não tem
                // para iniciar um serviço de microfone.
                JarvisWatchdog.agendarRapido(c, 5000L);
            }
            return Result.success();
        } catch (Throwable e) {
            String msg = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            JarvisPrefs.ultimoErro(c, "manutenção periódica falhou: " + msg);
            // Duas tentativas bastam: o ciclo de 6 h já cobre a próxima. Insistir para
            // sempre num erro permanente (permissão, arquivo) só gastaria bateria.
            if (getRunAttemptCount() >= 2) return Result.success();
            return Result.retry();
        }
    }

    /** Agenda a manutenção a cada 6 h, sem rodar com bateria baixa. */
    static void agendar(Context c) {
        try {
            Constraints restricoes = new Constraints.Builder()
                .setRequiresBatteryNotLow(true)
                .build();
            PeriodicWorkRequest pedido = new PeriodicWorkRequest.Builder(
                    JarvisManutencaoWorker.class, INTERVALO_HORAS, TimeUnit.HOURS)
                .setConstraints(restricoes)
                .build();
            WorkManager.getInstance(c).enqueueUniquePeriodicWork(NOME, ExistingPeriodicWorkPolicy.KEEP, pedido);
            JarvisPrefs.manutencaoAgendada(c, true);
        } catch (Throwable e) {
            JarvisPrefs.manutencaoAgendada(c, false);
            JarvisPrefs.ultimoErro(c, "WorkManager indisponível: "
                + (e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage()));
        }
    }

    /** Roda uma vez agora, para o diagnóstico conferir sem esperar 6 h. */
    static void rodarAgora(Context c) {
        try {
            WorkManager.getInstance(c).enqueue(OneTimeWorkRequest.from(JarvisManutencaoWorker.class));
        } catch (Throwable e) {
            JarvisPrefs.ultimoErro(c, "WorkManager indisponível: "
                + (e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage()));
        }
    }

    static void cancelar(Context c) {
        try {
            WorkManager.getInstance(c).cancelUniqueWork(NOME);
        } catch (Throwable ignored) { }
        JarvisPrefs.manutencaoAgendada(c, false);
    }
}
