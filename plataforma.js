/* J.A.R.V.I.S. Nova — PlatformAdapter (fase 1 do multiplataforma).
 *
 * Um único ponto que responde "onde estou rodando?" e "o que existe aqui?". Antes, cada
 * módulo perguntava sozinho pelo Capacitor, pelo Electron ou pelo navegador; agora o resto
 * do aplicativo consulta este adaptador. Com isso:
 *
 *  - Android/iOS: plugins do Capacitor, quando instalados;
 *  - Desktop (Electron): pontes de preload.js (janela, arquivos, status do PC);
 *  - Web/PWA: só o que o navegador oferece.
 *
 * Nenhuma capacidade é inventada: `capacidades` reflete o que está realmente presente. O
 * layout também entra aqui (tela compacta x ampla), porque o app precisa parecer um app de
 * celular no celular e um painel de computador no PC.
 */
(function (raiz) {
  'use strict';

  var Cap = raiz.Capacitor;
  var desk = raiz.jarvisNative || null;
  var nativePlatform = !!(Cap && typeof Cap.isNativePlatform === 'function' && Cap.isNativePlatform());
  var plataformaNativa = '';
  try { plataformaNativa = (Cap && typeof Cap.getPlatform === 'function') ? String(Cap.getPlatform() || '') : ''; } catch (e) { plataformaNativa = ''; }
  var ua = '';
  try { ua = String((raiz.navigator && raiz.navigator.userAgent) || ''); } catch (e) { ua = ''; }
  var ehIOS = nativePlatform && (plataformaNativa === 'ios' || /iPhone|iPad|iPod/i.test(ua));
  var ehAndroid = nativePlatform && !ehIOS;
  var tipo = ehAndroid ? 'android' : ehIOS ? 'ios' : desk ? 'desktop' : 'web';

  function plug(nome) {
    if (!ehAndroid && !ehIOS) return null;
    try {
      if (Cap.Plugins && Cap.Plugins[nome]) return Cap.Plugins[nome];
      if (typeof Cap.registerPlugin === 'function') return Cap.registerPlugin(nome);
    } catch (e) { /* plugin ausente nesta plataforma */ }
    return null;
  }

  var adaptador = {
    tipo: tipo,
    android: ehAndroid,
    ios: ehIOS,
    desktop: tipo === 'desktop',
    web: tipo === 'web',
    nativo: ehAndroid || ehIOS,
    /** Nome legível para a interface e para o diagnóstico. */
    nome: tipo === 'android' ? 'Android' : tipo === 'ios' ? 'iOS' : tipo === 'desktop' ? 'Computador' : 'Navegador',
    versaoSistema: (raiz.navigator && raiz.navigator.platform) || '',
    plug: plug,

    capacidades: {
      vozNativa: ehAndroid,
      segundoPlano: ehAndroid,
      camera: ehAndroid || !!(raiz.navigator && raiz.navigator.mediaDevices && raiz.navigator.mediaDevices.getUserMedia),
      arquivos: tipo === 'desktop',
      sistema: tipo === 'desktop' || ehAndroid,
      atualizadorApk: ehAndroid,
      notificacoes: ehAndroid,
      tecladoAtalhos: tipo === 'desktop' || tipo === 'web'
    },

    /** Chama um plugin nativo quando existe; devolve null quando não existe. */
    async chamar(nomePlugin, metodo, args) {
      var p = plug(nomePlugin);
      if (!p || typeof p[metodo] !== 'function') return null;
      return p[metodo](args || {});
    },

    /** Ponte do desktop (main.js). Fora do Electron devolve null. */
    async desktopComando(nome, args) {
      if (!desk || typeof desk.run !== 'function') return null;
      return desk.run(nome, args || {});
    },

    /** Aplica plataforma e faixa de tela em body[data-plataforma] / body[data-tela]. */
    layout() {
      var doc = raiz.document;
      if (!doc || !doc.body) return;
      doc.body.dataset.plataforma = tipo;
      var largura = raiz.innerWidth || (doc.documentElement && doc.documentElement.clientWidth) || 0;
      doc.body.dataset.tela = largura >= 1024 ? 'ampla' : largura >= 640 ? 'media' : 'compacta';
      doc.body.classList.toggle('modo-pc', tipo === 'desktop');
    },

    /** Observa mudanças de largura para reaplicar o layout (sem custo por quadro). */
    observarTela() {
      if (!raiz.addEventListener) return;
      var timer = 0;
      raiz.addEventListener('resize', function () {
        if (timer) return;
        timer = setTimeout(function () { timer = 0; adaptador.layout(); }, 180);
      }, { passive: true });
      adaptador.layout();
    }
  };

  raiz.Plataforma = adaptador;
  if (typeof module === 'object' && module.exports) module.exports = adaptador;
})(typeof window !== 'undefined' ? window : globalThis);
