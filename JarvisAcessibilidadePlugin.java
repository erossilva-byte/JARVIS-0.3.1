package com.jarvis.nova;

import android.content.Intent;
import android.provider.Settings;

import com.getcapacitor.JSObject;
import org.json.JSONObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;

@CapacitorPlugin(name = "JarvisAcessibilidade")
public class JarvisAcessibilidadePlugin extends Plugin {

    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    /**
     * Percorrer a árvore da tela custa tempo, e `esperar` dorme de verdade até o tempo
     * limite. Na thread principal (onde o Capacitor chama os métodos de plugin) isso
     * travaria a interface por segundos e poderia dar ANR. O Capacitor aceita
     * resolve/reject de qualquer thread, então o trabalho roda numa fila própria.
     */
    private void emSegundoPlano(PluginCall call, Supplier<JSONObject> tarefa) {
        worker.execute(() -> {
            try {
                resolver(call, tarefa.get());
            } catch (Throwable e) {
                call.reject("Falha na automação de tela: "
                    + (e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage()));
            }
        });
    }

    @Override
    protected void handleOnDestroy() {
        worker.shutdownNow();
        super.handleOnDestroy();
    }

    private void resolver(PluginCall call, JSONObject dados) {
        try {
            call.resolve(JSObject.fromJSONObject(dados));
        } catch (Exception e) {
            call.reject("Falha ao converter a resposta de acessibilidade: " + e.getMessage());
        }
    }

    @PluginMethod
    public void status(PluginCall call) {
        resolver(call, JarvisAcessibilidade.status());
    }

    @PluginMethod
    public void abrirConfiguracoes(PluginCall call) {
        try {
            Intent i = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            JSObject o = new JSObject();
            o.put("ok", true);
            o.put("info", "Abrindo Acessibilidade. Ative “J.A.R.V.I.S. Nova — Automação”; sem isso nenhuma ação de tela funciona.");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui abrir as configurações de acessibilidade: " + e.getMessage());
        }
    }

    @PluginMethod
    public void arvore(PluginCall call) {
        Integer limite = call.getInt("limite", 120);
        final int maximo = limite == null ? 120 : limite;
        emSegundoPlano(call, () -> JarvisAcessibilidade.arvore(maximo));
    }

    @PluginMethod
    public void clicar(PluginCall call) {
        String texto = call.getString("texto", "");
        if (texto == null || texto.trim().isEmpty()) {
            call.reject("Informe o texto ou a descrição do elemento.");
            return;
        }
        Integer ocorrencia = call.getInt("ocorrencia", 0);
        final int vezes = ocorrencia == null ? 0 : ocorrencia;
        emSegundoPlano(call, () -> JarvisAcessibilidade.clicar(texto, vezes));
    }

    @PluginMethod
    public void digitar(PluginCall call) {
        String texto = call.getString("texto", "");
        if (texto == null) {
            call.reject("Texto ausente.");
            return;
        }
        emSegundoPlano(call, () -> JarvisAcessibilidade.digitar(texto));
    }

    @PluginMethod
    public void rolar(PluginCall call) {
        final String direcao = call.getString("direcao", "baixo");
        emSegundoPlano(call, () -> JarvisAcessibilidade.rolar(direcao));
    }

    @PluginMethod
    public void voltar(PluginCall call) {
        resolver(call, JarvisAcessibilidade.voltar());
    }

    @PluginMethod
    public void inicio(PluginCall call) {
        resolver(call, JarvisAcessibilidade.inicio());
    }

    @PluginMethod
    public void esperar(PluginCall call) {
        String texto = call.getString("texto", "");
        if (texto == null || texto.trim().isEmpty()) {
            call.reject("Informe o texto que devo esperar.");
            return;
        }
        Integer ms = call.getInt("timeoutMs", 4000);
        final int limiteMs = ms == null ? 4000 : ms;
        emSegundoPlano(call, () -> JarvisAcessibilidade.esperar(texto, limiteMs));
    }

    @PluginMethod
    public void parar(PluginCall call) {
        resolver(call, JarvisAcessibilidade.parar());
    }
}
