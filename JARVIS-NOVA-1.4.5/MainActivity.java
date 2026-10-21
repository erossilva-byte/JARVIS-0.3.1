package com.jarvis.nova;

import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.view.View;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    private static final int FUNDO = 0xFF060A12;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(JarvisBackgroundPlugin.class);
        registerPlugin(JarvisUtilPlugin.class);
        registerPlugin(JarvisLocalAIPlugin.class);
        super.onCreate(savedInstanceState);
        aparenciaNativa();
    }

    /** Barras do sistema na cor do app, sem clarão branco e sem "cara de página web". */
    private void aparenciaNativa() {
        try {
            getWindow().setStatusBarColor(FUNDO);
            getWindow().setNavigationBarColor(FUNDO);
            getWindow().setBackgroundDrawable(new ColorDrawable(FUNDO));
            View decor = getWindow().getDecorView();
            // ícones claros nas barras escuras
            int flags = decor.getSystemUiVisibility();
            flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            flags &= ~View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            decor.setSystemUiVisibility(flags);
        } catch (Exception e) {
            // sem problema: só estética
        }
        try {
            if (getBridge() != null && getBridge().getWebView() != null) {
                getBridge().getWebView().setBackgroundColor(FUNDO);
                getBridge().getWebView().setOverScrollMode(View.OVER_SCROLL_NEVER);
                getBridge().getWebView().setVerticalScrollBarEnabled(false);
                getBridge().getWebView().setHorizontalScrollBarEnabled(false);
            }
        } catch (Exception e) {
            // sem problema: só estética
        }
    }
}
