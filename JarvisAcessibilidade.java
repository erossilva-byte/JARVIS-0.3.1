package com.jarvis.nova;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Automação opt-in por acessibilidade.
 *
 * Só funciona depois que o usuário habilita o serviço nas configurações especiais do
 * Android. Não usa coordenadas livres, não lê campos de senha e limita a árvore para
 * evitar varrer a tela inteira sem necessidade. Quem decide se uma ação pode rodar é
 * o núcleo JavaScript (JarvisOS), com confirmação e escopo; este serviço é o executor.
 */
public class JarvisAcessibilidade extends AccessibilityService {
    private static volatile JarvisAcessibilidade instancia;
    private static volatile String pacoteAtual = "";
    private static volatile boolean cancelado = false;

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        instancia = this;
        cancelado = false;
        try {
            AccessibilityServiceInfo info = getServiceInfo();
            if (info != null) {
                info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                    | AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED;
                info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
                info.notificationTimeout = 100;
                info.flags |= AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
                    | AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                    | AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS;
                setServiceInfo(info);
            }
        } catch (Exception ignored) { }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null) return;
        try {
            CharSequence pkg = event.getPackageName();
            if (pkg != null && pkg.length() > 0) pacoteAtual = pkg.toString();
        } catch (Exception ignored) { }
    }

    @Override
    public void onInterrupt() { }

    @Override
    public void onDestroy() {
        if (instancia == this) instancia = null;
        super.onDestroy();
    }

    static boolean ativo() { return instancia != null; }
    static String pacote() { return pacoteAtual == null ? "" : pacoteAtual; }

    static JSONObject status() {
        JSONObject o = new JSONObject();
        try {
            o.put("habilitado", ativo());
            o.put("pacote", pacote());
            o.put("servico", "JarvisAcessibilidade");
            o.put("cancelado", cancelado);
            o.put("limiteNos", 220);
        } catch (Exception ignored) { }
        return o;
    }

    static JSONObject parar() {
        cancelado = true;
        JSONObject o = new JSONObject();
        try { o.put("ok", true); o.put("mensagem", "Automação marcada para parar; nenhuma nova ação será executada."); }
        catch (Exception ignored) { }
        return o;
    }

    private static AccessibilityNodeInfo raiz() {
        JarvisAcessibilidade s = instancia;
        if (s == null) return null;
        try {
            AccessibilityNodeInfo r = s.getRootInActiveWindow();
            if (r != null) return r;
            List<AccessibilityWindowInfo> janelas = s.getWindows();
            if (janelas != null) {
                for (AccessibilityWindowInfo w : janelas) {
                    if (w == null) continue;
                    AccessibilityNodeInfo x = w.getRoot();
                    if (x != null) return x;
                }
            }
        } catch (Exception ignored) { }
        return null;
    }

    private static String textoDe(AccessibilityNodeInfo n) {
        if (n == null) return "";
        try {
            if (n.isPassword()) return "";
            CharSequence t = n.getText();
            if (t != null && t.length() > 0) return t.toString();
            CharSequence d = n.getContentDescription();
            if (d != null && d.length() > 0) return d.toString();
        } catch (Exception ignored) { }
        return "";
    }

    private static String normalizar(String s) {
        if (s == null) return "";
        String t = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD)
            .replaceAll("[\\u0300-\\u036f]", "").toLowerCase(java.util.Locale.ROOT);
        return t.replaceAll("[^a-z0-9 ]+", " ").replaceAll("\\s+", " ").trim();
    }

    private static boolean visivel(AccessibilityNodeInfo n) {
        try {
            if (n == null) return false;
            Rect r = new Rect();
            n.getBoundsInScreen(r);
            return r.width() > 0 && r.height() > 0;
        } catch (Exception e) { return false; }
    }

    private static void coletar(AccessibilityNodeInfo n, JSONArray saida, int max, int profundidade) {
        if (n == null || saida.length() >= max || profundidade > 18 || cancelado) return;
        try {
            if (visivel(n) && !n.isPassword()) {
                String texto = textoDe(n);
                if (texto.length() > 0 || n.isClickable() || n.isEditable() || n.isScrollable()) {
                    JSONObject item = new JSONObject();
                    item.put("texto", texto.length() > 220 ? texto.substring(0, 220) : texto);
                    item.put("classe", n.getClassName() == null ? "" : n.getClassName().toString());
                    item.put("pacote", n.getPackageName() == null ? "" : n.getPackageName().toString());
                    item.put("clicavel", n.isClickable());
                    item.put("editavel", n.isEditable());
                    item.put("rolavel", n.isScrollable());
                    item.put("senha", n.isPassword());
                    Rect r = new Rect();
                    n.getBoundsInScreen(r);
                    JSONObject b = new JSONObject();
                    b.put("x", r.left); b.put("y", r.top); b.put("largura", r.width()); b.put("altura", r.height());
                    item.put("bounds", b);
                    item.put("profundidade", profundidade);
                    saida.put(item);
                }
            }
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo filho = n.getChild(i);
                coletar(filho, saida, max, profundidade + 1);
            }
        } catch (Exception ignored) { }
    }

    static JSONObject arvore(int limite) {
        JSONObject o = new JSONObject();
        try {
            if (!ativo()) {
                o.put("ok", false);
                o.put("erro", "Serviço de acessibilidade desligado. Ative em Configurações ▸ Acessibilidade ▸ J.A.R.V.I.S. Nova.");
                return o;
            }
            AccessibilityNodeInfo r = raiz();
            if (r == null) {
                o.put("ok", false);
                o.put("erro", "Não há janela ativa para ler.");
                return o;
            }
            int max = Math.max(1, Math.min(220, limite));
            JSONArray lista = new JSONArray();
            coletar(r, lista, max, 0);
            o.put("ok", true);
            o.put("pacote", pacote());
            o.put("nos", lista);
            o.put("quantidade", lista.length());
            o.put("limitado", lista.length() >= max);
            return o;
        } catch (Exception e) {
            try { o.put("ok", false); o.put("erro", "Falha ao ler a árvore: " + e.getMessage()); } catch (Exception ignored) { }
            return o;
        }
    }

    private static AccessibilityNodeInfo achar(AccessibilityNodeInfo raiz, String alvo, boolean exato, int ocorrencia) {
        if (raiz == null || alvo == null || alvo.trim().isEmpty()) return null;
        String procurado = normalizar(alvo);
        if (procurado.isEmpty()) return null;
        ArrayList<AccessibilityNodeInfo> achados = new ArrayList<>();
        coletarNos(raiz, achados, procurado, exato, 0);
        if (achados.isEmpty()) return null;
        int i = Math.max(0, Math.min(achados.size() - 1, ocorrencia));
        return achados.get(i);
    }

    private static void coletarNos(AccessibilityNodeInfo n, ArrayList<AccessibilityNodeInfo> saida, String alvo, boolean exato, int profundidade) {
        if (n == null || cancelado || profundidade > 18) return;
        try {
            String t = normalizar(textoDe(n));
            if (!t.isEmpty()) {
                boolean bate = exato ? t.equals(alvo) : (t.equals(alvo) || t.contains(alvo));
                if (bate && visivel(n)) saida.add(n);
            }
            for (int i = 0; i < n.getChildCount(); i++) coletarNos(n.getChild(i), saida, alvo, exato, profundidade + 1);
        } catch (Exception ignored) { }
    }

    static JSONObject clicar(String alvo, int ocorrencia) {
        JSONObject o = new JSONObject();
        try {
            if (!ativo()) { o.put("ok", false); o.put("erro", "Serviço de acessibilidade desligado."); return o; }
            cancelado = false;
            AccessibilityNodeInfo n = achar(raiz(), alvo, false, ocorrencia);
            if (n == null) { o.put("ok", false); o.put("erro", "Não encontrei um elemento visível com esse texto."); return o; }
            AccessibilityNodeInfo alvoClick = n;
            for (int i = 0; i < 5 && alvoClick != null && !alvoClick.isClickable(); i++) alvoClick = alvoClick.getParent();
            boolean feito = false;
            if (alvoClick != null && alvoClick.isClickable()) feito = alvoClick.performAction(AccessibilityNodeInfo.ACTION_CLICK);
            if (!feito) {
                try { feito = n.performAction(AccessibilityNodeInfo.ACTION_CLICK); } catch (Exception ignored) { }
            }
            o.put("ok", feito);
            o.put("texto", textoDe(n));
            o.put("pacote", pacote());
            if (!feito) o.put("erro", "O elemento foi encontrado, mas o aplicativo recusou o clique.");
            return o;
        } catch (Exception e) {
            try { o.put("ok", false); o.put("erro", "Falha ao clicar: " + e.getMessage()); } catch (Exception ignored) { }
            return o;
        }
    }

    private static AccessibilityNodeInfo editavel(AccessibilityNodeInfo n, int profundidade) {
        if (n == null || profundidade > 18) return null;
        try {
            if (n.isEditable() && visivel(n)) return n;
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo x = editavel(n.getChild(i), profundidade + 1);
                if (x != null) return x;
            }
        } catch (Exception ignored) { }
        return null;
    }

    static JSONObject digitar(String texto) {
        JSONObject o = new JSONObject();
        try {
            if (!ativo()) { o.put("ok", false); o.put("erro", "Serviço de acessibilidade desligado."); return o; }
            cancelado = false;
            AccessibilityNodeInfo r = raiz();
            AccessibilityNodeInfo foco = r == null ? null : r.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            AccessibilityNodeInfo alvo = (foco != null && foco.isEditable()) ? foco : editavel(r, 0);
            if (alvo == null) { o.put("ok", false); o.put("erro", "Não encontrei um campo de texto editável na tela."); return o; }
            try { alvo.performAction(AccessibilityNodeInfo.ACTION_FOCUS); } catch (Exception ignored) { }
            Bundle b = new Bundle();
            b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, texto == null ? "" : texto);
            boolean feito = alvo.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b);
            o.put("ok", feito);
            o.put("pacote", pacote());
            if (!feito) o.put("erro", "O aplicativo recusou a digitação no campo encontrado.");
            return o;
        } catch (Exception e) {
            try { o.put("ok", false); o.put("erro", "Falha ao digitar: " + e.getMessage()); } catch (Exception ignored) { }
            return o;
        }
    }

    private static AccessibilityNodeInfo rolavel(AccessibilityNodeInfo n, int profundidade) {
        if (n == null || profundidade > 18) return null;
        try {
            if (n.isScrollable() && visivel(n)) return n;
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo x = rolavel(n.getChild(i), profundidade + 1);
                if (x != null) return x;
            }
        } catch (Exception ignored) { }
        return null;
    }

    static JSONObject rolar(String direcao) {
        JSONObject o = new JSONObject();
        try {
            if (!ativo()) { o.put("ok", false); o.put("erro", "Serviço de acessibilidade desligado."); return o; }
            cancelado = false;
            AccessibilityNodeInfo alvo = rolavel(raiz(), 0);
            if (alvo == null) { o.put("ok", false); o.put("erro", "Não encontrei uma área rolável na tela."); return o; }
            int acao = "cima".equalsIgnoreCase(direcao) || "back".equalsIgnoreCase(direcao)
                ? AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD : AccessibilityNodeInfo.ACTION_SCROLL_FORWARD;
            boolean feito = alvo.performAction(acao);
            o.put("ok", feito);
            o.put("direcao", acao == AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD ? "cima" : "baixo");
            o.put("pacote", pacote());
            if (!feito) o.put("erro", "A área rolável recusou a rolagem.");
            return o;
        } catch (Exception e) {
            try { o.put("ok", false); o.put("erro", "Falha ao rolar: " + e.getMessage()); } catch (Exception ignored) { }
            return o;
        }
    }

    static JSONObject voltar() {
        JSONObject o = new JSONObject();
        try { boolean ok = ativo() && performGlobal(AccessibilityService.GLOBAL_ACTION_BACK); o.put("ok", ok); if (!ok) o.put("erro", "Serviço desligado ou ação recusada."); }
        catch (Exception e) { try { o.put("ok", false); o.put("erro", e.getMessage()); } catch (Exception ignored) { } }
        return o;
    }

    static JSONObject inicio() {
        JSONObject o = new JSONObject();
        try { boolean ok = ativo() && performGlobal(AccessibilityService.GLOBAL_ACTION_HOME); o.put("ok", ok); if (!ok) o.put("erro", "Serviço desligado ou ação recusada."); }
        catch (Exception e) { try { o.put("ok", false); o.put("erro", e.getMessage()); } catch (Exception ignored) { } }
        return o;
    }

    private static boolean performGlobal(int acao) {
        JarvisAcessibilidade s = instancia;
        return s != null && s.performGlobalAction(acao);
    }

    static JSONObject esperar(String alvo, int timeoutMs) {
        JSONObject o = new JSONObject();
        long fim = System.currentTimeMillis() + Math.max(500, Math.min(8000, timeoutMs));
        try {
            if (!ativo()) { o.put("ok", false); o.put("erro", "Serviço de acessibilidade desligado."); return o; }
            cancelado = false;
            while (System.currentTimeMillis() < fim && !cancelado) {
                AccessibilityNodeInfo n = achar(raiz(), alvo, false, 0);
                if (n != null) {
                    o.put("ok", true); o.put("texto", textoDe(n)); o.put("pacote", pacote()); return o;
                }
                SystemClock.sleep(180);
            }
            o.put("ok", false);
            o.put("erro", cancelado ? "Espera cancelada." : "O texto não apareceu dentro do tempo limite.");
            return o;
        } catch (Exception e) {
            try { o.put("ok", false); o.put("erro", "Falha ao esperar: " + e.getMessage()); } catch (Exception ignored) { }
            return o;
        }
    }
}
