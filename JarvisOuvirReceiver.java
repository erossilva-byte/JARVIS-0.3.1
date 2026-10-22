package com.jarvis.nova;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/**
 * Ação "Ouvir agora" da notificação persistente.
 *
 * Um toque na notificação já abre o app; este receptor é necessário para o app saber
 * que deve começar a ouvir assim que a tela aparecer, mesmo que o processo tenha
 * acabado de nascer. O pedido fica marcado em JarvisPrefs e a interface consome
 * quando volta a ficar visível — nada é gravado nem enviado.
 */
public class JarvisOuvirReceiver extends BroadcastReceiver {

    static final String ACAO = "com.jarvis.nova.OUVIR_AGORA";

    @Override
    public void onReceive(Context context, Intent intent) {
        Context ctx = context.getApplicationContext();
        JarvisPrefs.pedidoOuvir(ctx, true);
        // O microfone precisa estar livre quando a interface abrir o reconhecimento.
        JarvisService.pausarEscuta();
        try {
            Intent abrir = new Intent(ctx, MainActivity.class);
            abrir.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_SINGLE_TOP
                | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            abrir.putExtra("jarvis_ouvir", true);
            if (Build.VERSION.SDK_INT >= 29) abrir.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            ctx.startActivity(abrir);
        } catch (Exception e) {
            JarvisPrefs.ultimoErro(ctx, "não consegui abrir a tela pelo botão Ouvir agora: " + e.getMessage());
        }
    }
}
