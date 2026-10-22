package com.jarvis.nova;

import com.getcapacitor.JSObject;

/**
 * Ponte entre o serviço de escuta (que continua vivo em segundo plano) e a interface.
 * Se o app estiver fechado quando “Jarvis” for detectado, o evento fica guardado e é
 * entregue assim que a interface registrar o ouvinte.
 */
public final class JarvisWakeBus {

    public interface Ouvinte {
        void aoAcordar(String texto, String detector);
        void aoParar(String motivo);
    }

    private static Ouvinte ouvinte;
    private static String textoPendente;
    private static String detectorPendente;
    private static String motivoPendente;

    private JarvisWakeBus() { }

    public static synchronized void registrar(Ouvinte o) {
        ouvinte = o;
    }

    /**
     * Entrega o evento que ficou guardado enquanto o app estava fechado.
     * A interface chama isto depois de registrar os ouvintes, senão o aviso se perde.
     */
    public static synchronized JSObject consumirPendente() {
        if (textoPendente != null) {
            JSObject o = evento(textoPendente, detectorPendente);
            o.put("tipo", "wake");
            textoPendente = null;
            detectorPendente = null;
            return o;
        }
        if (motivoPendente != null) {
            JSObject o = new JSObject();
            o.put("tipo", "parou");
            o.put("motivo", motivoPendente);
            motivoPendente = null;
            return o;
        }
        return null;
    }

    public static synchronized void remover(Ouvinte o) {
        if (ouvinte == o) ouvinte = null;
    }

    public static synchronized void acordou(String texto, String detector) {
        if (ouvinte != null) {
            ouvinte.aoAcordar(texto, detector);
        } else {
            textoPendente = texto;
            detectorPendente = detector;
            motivoPendente = null;
        }
    }

    public static synchronized void parou(String motivo) {
        if (ouvinte != null) {
            ouvinte.aoParar(motivo);
        } else {
            motivoPendente = motivo;
        }
    }

    static JSObject evento(String texto, String detector) {
        JSObject o = new JSObject();
        o.put("texto", texto == null ? "Jarvis" : texto);
        o.put("detector", detector == null ? "" : detector);
        return o;
    }
}
