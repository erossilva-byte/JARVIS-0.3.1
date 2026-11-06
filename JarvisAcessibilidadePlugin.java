package com.jarvis.nova;

import android.content.Intent;
import android.provider.Settings;

import com.getcapacitor.JSObject;
import org.json.JSONObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "JarvisAcessibilidade")
public class JarvisAcessibilidadePlugin extends Plugin {

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
        resolver(call, JarvisAcessibilidade.arvore(limite == null ? 120 : limite));
    }

    @PluginMethod
    public void clicar(PluginCall call) {
        String texto = call.getString("texto", "");
        if (texto == null || texto.trim().isEmpty()) {
            call.reject("Informe o texto ou a descrição do elemento.");
            return;
        }
        Integer ocorrencia = call.getInt("ocorrencia", 0);
        resolver(call, JarvisAcessibilidade.clicar(texto, ocorrencia == null ? 0 : ocorrencia));
    }

    @PluginMethod
    public void digitar(PluginCall call) {
        String texto = call.getString("texto", "");
        if (texto == null) {
            call.reject("Texto ausente.");
            return;
        }
        resolver(call, JarvisAcessibilidade.digitar(texto));
    }

    @PluginMethod
    public void rolar(PluginCall call) {
        resolver(call, JarvisAcessibilidade.rolar(call.getString("direcao", "baixo")));
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
        resolver(call, JarvisAcessibilidade.esperar(texto, ms == null ? 4000 : ms));
    }

    @PluginMethod
    public void parar(PluginCall call) {
        resolver(call, JarvisAcessibilidade.parar());
    }
}
