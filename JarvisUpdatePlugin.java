package com.jarvis.nova;

import android.content.Intent;
import android.content.pm.PackageInfo;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Atualizador do J.A.R.V.I.S. Nova — modo: Atualizador + ApkProvider + release no GitHub.
 *
 * 1) verificarAtualizacao: consulta o release mais novo publicado em
 *    api.github.com/repos/<repositorio>/releases/latest e compara com a versão instalada.
 * 2) baixarAtualizacao: baixa o APK do release para o armazenamento PRIVADO do app
 *    (files/updates/), medindo SHA-256 para conferir o digesto publicado.
 * 3) instalarAtualizacao: entrega o arquivo ao instalador do Android pelo FileProvider
 *    (com.jarvis.nova.fileprovider). A instalação final sempre pede confirmação no sistema.
 */
@CapacitorPlugin(name = "JarvisUpdate")
public class JarvisUpdatePlugin extends Plugin {

    private static final String REPOSITORIO = "erossilva-byte/JARVIS-0.3.1";
    private static final String API_RELEASE = "https://api.github.com/repos/" + REPOSITORIO + "/releases/latest";
    // Usado quando não existe release "latest": lista os releases e procura o primeiro com APK.
    private static final String API_RELEASES = "https://api.github.com/repos/" + REPOSITORIO + "/releases?per_page=10";
    private static final String URL_RELEASES = "https://github.com/" + REPOSITORIO + "/releases";
    private static final String PASTA_ATUALIZACOES = "updates";
    private static final String NOME_ARQUIVO = "jarvis-update.apk";
    private static final int TIMEOUT_MS = 20000;
    private static final long MAX_APK_BYTES = 400L * 1024L * 1024L; // trava de sanidade
    private static final String AUTORIDADE = "com.jarvis.nova.fileprovider";

    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    /** Erro HTTP com o código preservado, para explicar a falha ao usuário. */
    private static class ErroHttp extends RuntimeException {
        final int codigo;
        ErroHttp(int codigo, String detalhe) {
            super("HTTP " + codigo + (detalhe == null || detalhe.isEmpty() ? "" : " — " + detalhe));
            this.codigo = codigo;
        }
    }

    private File arquivoAtualizacao() {
        File dir = new File(getContext().getFilesDir(), PASTA_ATUALIZACOES);
        if (!dir.exists()) dir.mkdirs();
        return new File(dir, NOME_ARQUIVO);
    }

    private String versaoInstalada() {
        try {
            PackageInfo pi = getContext().getPackageManager().getPackageInfo(getContext().getPackageName(), 0);
            return pi.versionName == null ? "" : pi.versionName;
        } catch (Exception e) {
            return "";
        }
    }

    private long codigoInstalado() {
        try {
            PackageInfo pi = getContext().getPackageManager().getPackageInfo(getContext().getPackageName(), 0);
            if (Build.VERSION.SDK_INT >= 28) return pi.getLongVersionCode();
            return pi.versionCode;
        } catch (Exception e) {
            return -1;
        }
    }

    private static int[] numeros(String texto) {
        if (texto == null) return null;
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?").matcher(texto);
        if (!m.find()) return null;
        int a = Integer.parseInt(m.group(1));
        int b = m.group(2) == null ? 0 : Integer.parseInt(m.group(2));
        int c = m.group(3) == null ? 0 : Integer.parseInt(m.group(3));
        return new int[] { a, b, c };
    }

    private static boolean versaoMaior(String nova, String atual) {
        int[] x = numeros(nova), y = numeros(atual);
        if (x == null || y == null) return nova != null && atual != null && !nova.equals(atual);
        for (int i = 0; i < 3; i++) {
            if (x[i] != y[i]) return x[i] > y[i];
        }
        return false;
    }

    private String httpGet(String endereco) throws Exception {
        HttpURLConnection con = (HttpURLConnection) new URL(endereco).openConnection();
        con.setConnectTimeout(TIMEOUT_MS);
        con.setReadTimeout(TIMEOUT_MS);
        con.setRequestProperty("User-Agent", "JARVIS-Nova-Updater");
        con.setRequestProperty("Accept", "application/vnd.github+json");
        try {
            int codigo = con.getResponseCode();
            if (codigo < 200 || codigo >= 300) {
                String detalhe = "";
                try {
                    InputStream erro = con.getErrorStream();
                    if (erro != null) {
                        java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
                        byte[] b = new byte[2048];
                        int l;
                        while ((l = erro.read(b)) > 0) buf.write(b, 0, l);
                        erro.close();
                        detalhe = buf.toString("UTF-8");
                        int msg = detalhe.indexOf("\"message\"");
                        detalhe = msg >= 0 ? detalhe.substring(0, Math.min(detalhe.length(), msg + 160)) : detalhe;
                    }
                } catch (Exception ignored) { }
                throw new ErroHttp(codigo, detalhe.trim());
            }
            InputStream in = con.getInputStream();
            StringBuilder sb = new StringBuilder();
            byte[] buf = new byte[8192];
            int l;
            while ((l = in.read(buf)) > 0) sb.append(new String(buf, 0, l, StandardCharsets.UTF_8));
            in.close();
            return sb.toString();
        } finally {
            con.disconnect();
        }
    }

    /** Fallback: primeiro release (inclusive pré-release) que tenha um APK publicado. */
    private JSONObject primeiroReleaseComApk() throws Exception {
        JSONArray lista = new JSONArray(httpGet(API_RELEASES));
        for (int i = 0; i < lista.length(); i++) {
            JSONObject rel = lista.getJSONObject(i);
            if (rel.optBoolean("draft", false)) continue;
            JSONArray assets = rel.optJSONArray("assets");
            if (assets == null) continue;
            for (int a = 0; a < assets.length(); a++) {
                if (assets.getJSONObject(a).optString("name", "").toLowerCase(Locale.ROOT).endsWith(".apk")) {
                    return rel;
                }
            }
        }
        return null;
    }

    private JSObject semReleasePublicado() {
        JSObject out = new JSObject();
        out.put("disponivel", false);
        out.put("motivo", "nenhum-release");
        out.put("versaoInstalada", versaoInstalada());
        out.put("versionCodeInstalado", codigoInstalado());
        out.put("repositorio", REPOSITORIO);
        out.put("urlReleases", URL_RELEASES);
        return out;
    }

    /** Consulta o release e monta a resposta compartilhada por verificar/baixar. */
    private JSObject consultarRelease() throws Exception {
        JSONObject rel;
        try {
            rel = new JSONObject(httpGet(API_RELEASE));
        } catch (ErroHttp e) {
            // 404 no /latest = o repositório existe, mas não há release marcado como mais recente.
            if (e.codigo != 404) throw e;
            rel = primeiroReleaseComApk();
            if (rel == null) return semReleasePublicado();
        }
        JSObject out = new JSObject();
        String tag = rel.optString("tag_name", "");
        String versao = tag.replaceFirst("^[vV]", "");
        JSONArray assets = rel.optJSONArray("assets");
        String urlApk = null, nomeAsset = null, digesto = "";
        long tamanho = -1;
        if (assets != null) {
            for (int i = 0; i < assets.length(); i++) {
                JSONObject a = assets.getJSONObject(i);
                String nome = a.optString("name", "");
                if (!nome.toLowerCase(Locale.ROOT).endsWith(".apk")) continue;
                urlApk = a.optString("browser_download_url", "");
                nomeAsset = nome;
                tamanho = a.optLong("size", -1);
                digesto = a.optString("digest", "");
                if (digesto.startsWith("sha256:")) digesto = digesto.substring("sha256:".length());
                if (urlApk.startsWith("https://")) break;
            }
        }
        if (urlApk == null || !urlApk.startsWith("https://")) {
            out.put("disponivel", false);
            out.put("motivo", "sem-apk");
            out.put("detalhe", "O release mais novo não contém um arquivo .apk anexado.");
            out.put("versao", versao);
            out.put("repositorio", REPOSITORIO);
            out.put("urlReleases", URL_RELEASES);
            return out;
        }
        String atual = versaoInstalada();
        boolean disponivel = versaoMaior(versao, atual);
        out.put("disponivel", disponivel);
        out.put("versao", versao);
        out.put("versaoInstalada", atual);
        out.put("versionCodeInstalado", codigoInstalado());
        out.put("urlApk", urlApk);
        out.put("nomeAsset", nomeAsset);
        out.put("tamanho", tamanho);
        out.put("digesto", digesto == null ? "" : digesto);
        out.put("urlRelease", rel.optString("html_url", ""));
        out.put("notas", String.valueOf(rel.optString("body", "")).replace('\n', ' ').trim());
        out.put("repositorio", REPOSITORIO);
        out.put("urlReleases", URL_RELEASES);
        return out;
    }

    /** Explica o erro HTTP em português, sem mostrar uma mensagem enganosa de “conexão”. */
    private static String explicar(Exception e) {
        if (e instanceof ErroHttp) {
            int c = ((ErroHttp) e).codigo;
            if (c == 403) return "o GitHub recusou a consulta (HTTP 403): limite de requisições deste endereço de rede ou acesso bloqueado. Tente mais tarde ou abra a página de releases";
            if (c == 404) return "o endereço do repositório não foi encontrado (HTTP 404)";
            if (c == 401) return "o repositório exige autenticação (HTTP 401)";
            return "o GitHub respondeu HTTP " + c;
        }
        String m = e == null || e.getMessage() == null ? "erro desconhecido" : e.getMessage();
        return m;
    }

    @PluginMethod
    public void status(PluginCall call) {
        JSObject o = new JSObject();
        o.put("versao", versaoInstalada());
        o.put("versionCode", codigoInstalado());
        o.put("repositorio", REPOSITORIO);
        o.put("urlReleases", URL_RELEASES);
        File f = arquivoAtualizacao();
        o.put("baixado", f.exists() && f.length() > 0);
        o.put("baixadoBytes", f.exists() ? f.length() : 0);
        call.resolve(o);
    }

    @PluginMethod
    public void verificarAtualizacao(PluginCall call) {
        worker.execute(() -> {
            try {
                call.resolve(consultarRelease());
            } catch (Exception e) {
                call.reject("Não consegui consultar as atualizações no GitHub: " + explicar(e) + ".");
            }
        });
    }

    @PluginMethod
    public void baixarAtualizacao(PluginCall call) {
        worker.execute(() -> {
            File destino = arquivoAtualizacao();
            FileOutputStream fos = null;
            HttpURLConnection con = null;
            try {
                JSObject rel = consultarRelease();
                if (!rel.getBoolean("disponivel")) {
                    if ("nenhum-release".equals(rel.optString("motivo", ""))) {
                        call.reject("Ainda não há nenhum release publicado no GitHub, então não existe APK para baixar. Publique uma versão em Releases ou abra a página de releases no navegador.");
                    } else if ("sem-apk".equals(rel.optString("motivo", ""))) {
                        call.reject("O release mais novo não tem um arquivo .apk anexado. Abra a página de releases para conferir.");
                    } else {
                        call.reject("Você já está na versão mais recente publicada.");
                    }
                    return;
                }
                String endereco = rel.getString("urlApk");
                String digestoPublicado = rel.optString("digesto", "");
                con = (HttpURLConnection) new URL(endereco).openConnection();
                con.setConnectTimeout(TIMEOUT_MS);
                con.setReadTimeout(60000);
                con.setRequestProperty("User-Agent", "JARVIS-Nova-Updater");
                int codigo = con.getResponseCode();
                if (codigo < 200 || codigo >= 300) throw new RuntimeException("download HTTP " + codigo);
                long total = con.getContentLength();
                InputStream in = con.getInputStream();
                fos = new FileOutputStream(destino);
                MessageDigest sha = MessageDigest.getInstance("SHA-256");
                byte[] buf = new byte[16384];
                long lidos = 0;
                int l;
                int ultimoPct = -1;
                while ((l = in.read(buf)) > 0) {
                    if (lidos + l > MAX_APK_BYTES) throw new RuntimeException("arquivo maior que o limite de segurança");
                    fos.write(buf, 0, l);
                    sha.update(buf, 0, l);
                    lidos += l;
                    if (total > 0) {
                        int pct = (int) (lidos * 100 / total);
                        if (pct / 10 != ultimoPct / 10) {
                            ultimoPct = pct;
                            JSObject p = new JSObject();
                            p.put("pct", pct);
                            p.put("bytes", lidos);
                            notifyListeners("atualizacao-progresso", p);
                        }
                    }
                }
                in.close();
                fos.flush();
                fos.close();
                fos = null;

                StringBuilder hex = new StringBuilder();
                for (byte b : sha.digest()) hex.append(String.format(Locale.US, "%02x", b));
                String sha256 = hex.toString();
                if (digestoPublicado != null && !digestoPublicado.isEmpty()
                    && !digestoPublicado.toLowerCase(Locale.US).equals(sha256)) {
                    destino.delete();
                    throw new RuntimeException("checksum divergente do publicado; o download foi descartado");
                }
                JSObject out = new JSObject();
                out.put("bytes", destino.length());
                out.put("sha256", sha256);
                out.put("versao", rel.optString("versao", ""));
                out.put("verificado", digestoPublicado != null && !digestoPublicado.isEmpty());
                call.resolve(out);
            } catch (Exception e) {
                if (destino.exists()) destino.delete();
                String msg = e == null || e.getMessage() == null ? "erro desconhecido" : e.getMessage();
                call.reject("Não consegui baixar a atualização: " + msg + ".");
            } finally {
                if (fos != null) { try { fos.close(); } catch (Exception ignored) { } }
                if (con != null) con.disconnect();
            }
        });
    }

    /** Abre a página de releases no navegador do celular (útil quando ainda não há release). */
    @PluginMethod
    public void abrirReleases(PluginCall call) {
        try {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(URL_RELEASES));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui abrir o navegador: " + (e == null || e.getMessage() == null ? "erro" : e.getMessage()));
        }
    }

    @PluginMethod
    public void instalarAtualizacao(PluginCall call) {
        File apk = arquivoAtualizacao();
        if (!apk.exists() || apk.length() < 1024) {
            call.reject("Nenhuma atualização baixada ainda. Use “atualizar Jarvis” ou toque em Baixar atualização.");
            return;
        }
        try {
            if (Build.VERSION.SDK_INT >= 26
                && !getContext().getPackageManager().canRequestPackageInstalls()) {
                // O Android exige autorização explícita para instalar apps de fontes desconhecidas.
                try {
                    Intent permissao = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + getContext().getPackageName()));
                    permissao.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    getContext().startActivity(permissao);
                } catch (Exception ignored) { }
                call.reject("Permita a instalação de apps desta origem (a tela do Android já abriu) e toque em Instalar atualização de novo.");
                return;
            }
            Uri uri = FileProvider.getUriForFile(getContext(), AUTORIDADE, apk);
            Intent instalar = new Intent(Intent.ACTION_VIEW);
            instalar.setDataAndType(uri, "application/vnd.android.package-archive");
            instalar.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            instalar.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            // resolveActivity volta nulo em vários Androids 11+ sem <queries>; tentamos abrir e tratamos
            // apenas a ausência real de instalador, em vez de recusar por engano.
            try {
                getContext().startActivity(instalar);
            } catch (android.content.ActivityNotFoundException anf) {
                call.reject("Este aparelho não expôs um instalador de APK. Baixe o arquivo de novo e tente instalar pelas Configurações > Apps.");
                return;
            }
            JSObject o = new JSObject();
            o.put("info", "Instalador aberto. Confira a versão e toque em Instalar.");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui abrir o instalador: "
                + (e == null || e.getMessage() == null ? "erro desconhecido" : e.getMessage()) + ".");
        }
    }

    @Override
    protected void handleOnDestroy() {
        worker.shutdownNow();
        super.handleOnDestroy();
    }
}
