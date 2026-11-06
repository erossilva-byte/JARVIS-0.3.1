/* J.A.R.V.I.S. Nova — Avatar 3D procedural.
 *
 * Um rosto holográfico construído com geometria Three.js, sem modelo externo e sem
 * download. A boca reage à amplitude real do microfone/fala (sincronização labial
 * por volume), os olhos piscam e o conjunto acompanha os estados do assistente.
 * Não é um modelo facial realista nem visemas por fonema: essa distinção aparece
 * na interface e no diagnóstico.
 *
 * API: iniciar(canvas), parar(), destruir(), estado(nome), nivel(0..1), ativo(),
 * tipo(), diagnostico(). Sem WebGL, desenha o mesmo rosto em Canvas 2D.
 */
(function (raiz) {
  'use strict';

  var PALETAS = {
    idle: { prim: 0x06b6d4, nucleo: 0x22d3ee, olho: 0x9dfcff },
    listening: { prim: 0x2563eb, nucleo: 0x60a5fa, olho: 0xc7f7ff },
    thinking: { prim: 0xd97706, nucleo: 0xfbbf24, olho: 0xffe7a3 },
    speaking: { prim: 0x059669, nucleo: 0x34d399, olho: 0xc7ffe5 },
    processing: { prim: 0xb45309, nucleo: 0xfcd34d, olho: 0xfff0b0 },
    error: { prim: 0xb91c1c, nucleo: 0xfca5a5, olho: 0xffc7c7 }
  };
  PALETAS.erro = PALETAS.error;
  PALETAS.ouvindo = PALETAS.listening;
  PALETAS.falando = PALETAS.speaking;
  PALETAS.pensando = PALETAS.thinking;

  function suportaWebGL() {
    try {
      var c = document.createElement('canvas');
      c.width = c.height = 2;
      var ctx = c.getContext('webgl2') || c.getContext('webgl') || c.getContext('experimental-webgl');
      if (!ctx) return false;
      try { var perca = ctx.getExtension('WEBGL_lose_context'); if (perca) perca.loseContext(); } catch (e) { /* opcional */ }
      return true;
    } catch (e) { return false; }
  }

  function texturaAura() {
    var c = document.createElement('canvas');
    c.width = c.height = 128;
    var g = c.getContext('2d');
    var grd = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    grd.addColorStop(0, 'rgba(210,255,255,.9)');
    grd.addColorStop(.35, 'rgba(80,230,240,.28)');
    grd.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = grd;
    g.fillRect(0, 0, 128, 128);
    return c;
  }

  function Render3D(canvas) {
    var T = raiz.THREE;
    this.T = T;
    this.canvas = canvas;
    this.estadoAtual = 'idle';
    this.audioNivel = 0;
    this.nivelAlvo = 0;
    this.rodando = false;
    this.desejado = false;
    this.ultimo = 0;
    this.blink = 2.5;
    this.quadros = 0;
    this.ultimoFps = 0;
    this.inicioFps = 0;
    this.largura = 0;
    this.altura = 0;
    this.paleta = PALETAS.idle;

    this.renderer = new T.WebGLRenderer({ canvas: canvas, alpha: true, antialias: false, powerPreference: 'high-performance' });
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.setPixelRatio(Math.min(raiz.devicePixelRatio || 1, (raiz.innerWidth || 400) < 640 ? 1.25 : 1.6));
    this.cena = new T.Scene();
    this.camera = new T.PerspectiveCamera(34, 1, 0.1, 50);
    this.camera.position.set(0, 0, 4.5);
    this.grupo = new T.Group();
    this.cena.add(this.grupo);

    var self = this;
    this.corA = new T.Color(PALETAS.idle.prim);
    this.corN = new T.Color(PALETAS.idle.nucleo);
    this.corO = new T.Color(PALETAS.idle.olho);
    this.alvoA = this.corA.clone();
    this.alvoN = this.corN.clone();
    this.alvoO = this.corO.clone();

    var matCabeca = new T.MeshBasicMaterial({ color: 0x071a2a, transparent: true, opacity: .96 });
    this.cabeca = new T.Mesh(new T.SphereGeometry(1, 40, 28), matCabeca);
    this.cabeca.scale.set(.76, .92, .72);
    this.grupo.add(this.cabeca);

    var matArame = new T.MeshBasicMaterial({ color: this.corA, wireframe: true, transparent: true, opacity: .30 });
    this.arame = new T.Mesh(new T.SphereGeometry(1.012, 22, 14), matArame);
    this.arame.scale.copy(this.cabeca.scale);
    this.grupo.add(this.arame);

    var matFace = new T.MeshBasicMaterial({ color: 0x071a2a, transparent: true, opacity: .72, side: T.DoubleSide });
    this.face = new T.Mesh(new T.CircleGeometry(.58, 40), matFace);
    this.face.position.set(0, -.02, .690);
    this.face.scale.set(.94, 1.06, 1);
    this.grupo.add(this.face);

    var matOlho = new T.MeshBasicMaterial({ color: this.corO });
    this.olhos = [];
    this.olhosGlow = [];
    [-1, 1].forEach(function (lado) {
      var olho = new T.Mesh(new T.SphereGeometry(.105, 18, 12), matOlho);
      olho.position.set(.255 * lado, .17, .704);
      olho.scale.set(1, .52, .38);
      self.grupo.add(olho);
      self.olhos.push(olho);
      var brilho = new T.Mesh(new T.SphereGeometry(.17, 12, 10), new T.MeshBasicMaterial({ color: self.corO, transparent: true, opacity: .13, blending: T.AdditiveBlending, depthWrite: false }));
      brilho.position.copy(olho.position);
      self.grupo.add(brilho);
      self.olhosGlow.push(brilho);
    });

    var matSobrancelha = new T.MeshBasicMaterial({ color: this.corA, transparent: true, opacity: .72 });
    [-1, 1].forEach(function (lado) {
      var s = new T.Mesh(new T.BoxGeometry(.24, .026, .035), matSobrancelha);
      s.position.set(.25 * lado, .335, .705);
      s.rotation.z = -.12 * lado;
      self.grupo.add(s);
    });

    var matBoca = new T.MeshBasicMaterial({ color: this.corN, transparent: true, opacity: .92 });
    this.boca = new T.Mesh(new T.TorusGeometry(.165, .022, 8, 34), matBoca);
    this.boca.position.set(0, -.235, .707);
    this.boca.scale.set(1, .16, .55);
    this.grupo.add(this.boca);
    this.bocaInterna = new T.Mesh(new T.CircleGeometry(.135, 24), new T.MeshBasicMaterial({ color: 0x01070c, transparent: true, opacity: .92 }));
    this.bocaInterna.position.set(0, -.235, .700);
    this.bocaInterna.scale.set(1, .16, 1);
    this.grupo.add(this.bocaInterna);

    this.aneis = [];
    for (var i = 0; i < 2; i++) {
      var anel = new T.Mesh(new T.TorusGeometry(1.22 + i * .15, .010, 8, 80), new T.MeshBasicMaterial({ color: this.corA, transparent: true, opacity: .26 - i * .07, blending: T.AdditiveBlending, depthWrite: false }));
      anel.position.z = -.20 - i * .08;
      anel.rotation.x = 1.12 + i * .28;
      anel.rotation.y = i * .40;
      this.grupo.add(anel);
      this.aneis.push(anel);
    }

    var geo = new T.BufferGeometry();
    var pos = new Float32Array(150 * 3);
    for (var p = 0; p < 150; p++) {
      var u = Math.random() * 2 - 1, th = Math.random() * Math.PI * 2, r = Math.sqrt(1 - u * u);
      pos[p * 3] = Math.cos(th) * r * (1.1 + Math.random() * .5);
      pos[p * 3 + 1] = u * (1.0 + Math.random() * .35);
      pos[p * 3 + 2] = Math.sin(th) * r * (1.1 + Math.random() * .5);
    }
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    this.poeira = new T.Points(geo, new T.PointsMaterial({ color: this.corN, size: .027, transparent: true, opacity: .55, blending: T.AdditiveBlending, depthWrite: false }));
    this.grupo.add(this.poeira);

    var aura = new T.Sprite(new T.SpriteMaterial({ map: new T.CanvasTexture(texturaAura()), color: this.corA, transparent: true, opacity: .18, blending: T.AdditiveBlending, depthWrite: false }));
    aura.scale.set(3.4, 3.4, 1);
    aura.position.z = -.35;
    this.grupo.add(aura);
    this.aura = aura;

    this.medir();
    this.observadorTamanho = null;
    if (typeof raiz.ResizeObserver === 'function') {
      try {
        this.observadorTamanho = new raiz.ResizeObserver(function () { self.medir(); });
        this.observadorTamanho.observe(canvas);
      } catch (e) { this.observadorTamanho = null; }
    }
  }

  Render3D.prototype.medir = function () {
    if (!this.renderer) return;
    var r = this.canvas.getBoundingClientRect ? this.canvas.getBoundingClientRect() : { width: 300, height: 300 };
    var w = Math.max(1, Math.round(r.width || 300)), h = Math.max(1, Math.round(r.height || 300));
    if (w === this.largura && h === this.altura) return;
    this.largura = w; this.altura = h;
    this.renderer.setPixelRatio(Math.min(raiz.devicePixelRatio || 1, w < 640 ? 1.25 : 1.6));
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  };

  Render3D.prototype.iniciar = function () {
    if (this.rodando) return;
    this.desejado = true; this.rodando = true; this.ultimo = 0;
    var self = this, ultimoQuadro = 0;
    var intervalo = (raiz.innerWidth || 400) < 640 ? (1000 / 30) : (1000 / 50);
    var laco = function (t) {
      if (!self.rodando) return;
      self.raf = raiz.requestAnimationFrame(laco);
      t = Number.isFinite(t) ? t : (raiz.performance ? raiz.performance.now() : Date.now());
      if (t - ultimoQuadro < intervalo) return;
      ultimoQuadro = t;
      self.quadro(t);
    };
    this.raf = raiz.requestAnimationFrame(laco);
  };
  Render3D.prototype.parar = function () {
    this.desejado = false; this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };
  Render3D.prototype.estado = function (nome) {
    var p = PALETAS[nome]; if (!p) return;
    this.estadoAtual = nome; this.paleta = p;
    this.alvoA.setHex(p.prim); this.alvoN.setHex(p.nucleo); this.alvoO.setHex(p.olho);
  };
  Render3D.prototype.nivel = function (v) {
    var n = Number(v);
    if (Number.isFinite(n)) this.nivelAlvo = Math.max(0, Math.min(1, n));
  };
  Render3D.prototype.quadro = function (t) {
    if (!this.renderer) return;
    var dt = this.ultimo ? Math.min(.05, (t - this.ultimo) / 1000) : .016;
    this.ultimo = t;
    var agora = t / 1000;
    var k = Math.min(1, dt * 6);
    this.audioNivel += (this.nivelAlvo - this.audioNivel) * Math.min(1, dt * 12);
    this.corA.lerp(this.alvoA, k); this.corN.lerp(this.alvoN, k); this.corO.lerp(this.alvoO, k);
    this.arame.material.color.copy(this.corA); this.aura.material.color.copy(this.corA);
    this.boca.material.color.copy(this.corN); this.poeira.material.color.copy(this.corN);
    this.olhos.forEach(function (o) { o.material.color.copy(this.corO); }, this);
    this.olhosGlow.forEach(function (o) { o.material.color.copy(this.corO); }, this);

    this.grupo.rotation.y = Math.sin(agora * .32) * .10;
    this.grupo.rotation.x = Math.sin(agora * .21) * .035;
    var pulso = 1 + this.audioNivel * .018;
    this.cabeca.scale.set(.76 * pulso, .92 * pulso, .72 * pulso);

    this.blink -= dt;
    if (this.blink < -.12) this.blink = 2.4 + Math.random() * 2.8;
    var pisca = this.blink < 0 ? .08 : 1;
    this.olhos.forEach(function (o) { o.scale.y = .52 * pisca; });
    var fala = this.estadoAtual === 'speaking' ? Math.max(.08, this.audioNivel) : 0;
    var abertura = .16 + fala * 3.6 + (this.estadoAtual === 'listening' ? .08 : 0);
    this.boca.scale.y = abertura;
    this.bocaInterna.scale.y = abertura * .82;
    this.boca.position.y = -.235 - fala * .02;
    this.bocaInterna.position.y = this.boca.position.y;

    this.poeira.rotation.y += dt * .12;
    this.poeira.rotation.x += dt * .03;
    this.aneis.forEach(function (anel, i) { anel.rotation.z += dt * (i ? -.16 : .22); });
    this.aura.material.opacity = .13 + this.audioNivel * .18;
    this.renderer.render(this.cena, this.camera);
  };
  Render3D.prototype.destruir = function () {
    this.parar();
    try { if (this.observadorTamanho) this.observadorTamanho.disconnect(); } catch (e) { /* opcional */ }
    try {
      this.cena.traverse(function (o) {
        if (o.geometry) o.geometry.dispose();
        if (o.material) { if (o.material.map) o.material.map.dispose(); o.material.dispose(); }
      });
      this.renderer.dispose();
      this.renderer.forceContextLoss();
    } catch (e) { /* contexto já perdido */ }
  };

  function Render2D(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.rodando = false; this.desejado = false;
    this.audioNivel = 0; this.nivelAlvo = 0; this.estadoAtual = 'idle'; this.paleta = PALETAS.idle;
    this.ultimo = 0; this.blink = 2.5;
    var self = this;
    this.aoRedimensionar = function () { self.medir(); };
    if (raiz.addEventListener) { raiz.addEventListener('resize', this.aoRedimensionar, false); }
    this.observadorTamanho = null;
    if (typeof raiz.ResizeObserver === 'function') {
      try { this.observadorTamanho = new raiz.ResizeObserver(function () { self.medir(); }); this.observadorTamanho.observe(canvas); }
      catch (e) { this.observadorTamanho = null; }
    }
    this.medir();
  }
  Render2D.prototype.medir = function () {
    var r = this.canvas.getBoundingClientRect ? this.canvas.getBoundingClientRect() : { width: 300, height: 300 };
    this.w = Math.max(1, Math.round(r.width || 300)); this.h = Math.max(1, Math.round(r.height || 300));
    var dpr = Math.min(raiz.devicePixelRatio || 1, 1.5);
    this.canvas.width = Math.round(this.w * dpr); this.canvas.height = Math.round(this.h * dpr);
    this.dpr = dpr;
  };
  Render2D.prototype.iniciar = function () {
    if (this.rodando) return;
    this.desejado = true; this.rodando = true; this.ultimo = 0;
    var self = this, ultimoQuadro = 0;
    var intervalo = (raiz.innerWidth || 400) < 640 ? (1000 / 30) : (1000 / 50);
    var laco = function (t) {
      if (!self.rodando) return;
      self.raf = raiz.requestAnimationFrame(laco);
      t = Number.isFinite(t) ? t : (raiz.performance ? raiz.performance.now() : Date.now());
      if (t - ultimoQuadro < intervalo) return;
      ultimoQuadro = t;
      self.quadro(t);
    };
    this.raf = raiz.requestAnimationFrame(laco);
  };
  Render2D.prototype.parar = function () {
    this.desejado = false; this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };
  Render2D.prototype.estado = function (n) { if (PALETAS[n]) { this.estadoAtual = n; this.paleta = PALETAS[n]; } };
  Render2D.prototype.nivel = function (v) { if (Number.isFinite(Number(v))) this.nivelAlvo = Math.max(0, Math.min(1, Number(v))); };
  Render2D.prototype.quadro = function (t) {
    var dt = this.ultimo ? Math.min(64, t - this.ultimo) : 16; this.ultimo = t;
    this.audioNivel += (this.nivelAlvo - this.audioNivel) * .12;
    this.blink -= dt / 1000; if (this.blink < -.12) this.blink = 2.5 + Math.random() * 2.5;
    var g = this.ctx, w = this.w, h = this.h, cx = w / 2, cy = h / 2, s = Math.min(w, h) * .27;
    var p = this.paleta;
    var rgb = function (x) { return 'rgba(' + ((x >> 16) & 255) + ',' + ((x >> 8) & 255) + ',' + (x & 255); };
    g.setTransform(this.dpr, 0, 0, this.dpr, 0, 0); g.clearRect(0, 0, w, h);
    var halo = g.createRadialGradient(cx, cy, s * .2, cx, cy, s * 2.5);
    halo.addColorStop(0, rgb(p.prim) + ',.20)'); halo.addColorStop(1, rgb(p.prim) + ',0)');
    g.fillStyle = halo; g.beginPath(); g.arc(cx, cy, s * 2.5, 0, Math.PI * 2); g.fill();
    g.strokeStyle = rgb(p.prim) + ',.55)'; g.lineWidth = 1.5;
    g.beginPath(); g.ellipse(cx, cy, s * 1.28, s * 1.55, 0, 0, Math.PI * 2); g.stroke();
    g.fillStyle = '#071a2a'; g.beginPath(); g.ellipse(cx, cy, s * .78, s * .98, 0, 0, Math.PI * 2); g.fill();
    g.strokeStyle = rgb(p.nucleo) + ',.45)'; g.lineWidth = 1;
    g.beginPath(); g.ellipse(cx, cy, s * .80, s * 1.0, 0, 0, Math.PI * 2); g.stroke();
    var fala = this.estadoAtual === 'speaking' ? Math.max(.08, this.audioNivel) : 0;
    var blink = this.blink < 0 ? .10 : 1;
    [-1, 1].forEach(function (lado) {
      g.fillStyle = rgb(p.olho) + ',.92)';
      g.beginPath(); g.ellipse(cx + lado * s * .28, cy - s * .16, s * .10, s * .052 * blink, 0, 0, Math.PI * 2); g.fill();
    });
    g.strokeStyle = rgb(p.nucleo) + ',.95)'; g.lineWidth = 2;
    g.beginPath(); g.ellipse(cx, cy + s * .30, s * .22, s * (.035 + fala * .15), 0, 0, Math.PI * 2); g.stroke();
    g.fillStyle = rgb(p.nucleo) + ',' + (.22 + this.audioNivel * .4) + ')';
    g.beginPath(); g.arc(cx, cy, s * .06, 0, Math.PI * 2); g.fill();
  };
  Render2D.prototype.destruir = function () {
    this.parar();
    try { if (raiz.removeEventListener) raiz.removeEventListener('resize', this.aoRedimensionar, false); } catch (e) { /* opcional */ }
    try { if (this.observadorTamanho) this.observadorTamanho.disconnect(); } catch (e) { /* opcional */ }
  };

  var atual = null, canvasAtual = null, observador = null, pausadoPorTela = false;

  function criar(canvas) {
    if (raiz.THREE && suportaWebGL()) {
      try { return new Render3D(canvas); }
      catch (e) {
        try { if (raiz.console) raiz.console.warn('Avatar: WebGL falhou, usando Canvas 2D.', e && e.message); } catch (x) { /* sem console */ }
      }
    }
    return new Render2D(canvas);
  }
  function pausar() { if (atual && atual.rodando) { pausadoPorTela = true; atual.parar(); } }
  function retomar() { if (atual && pausadoPorTela) { pausadoPorTela = false; atual.iniciar(); } }
  function aoVisibilidade() { if (raiz.document && raiz.document.hidden) pausar(); else retomar(); }
  if (raiz.document && raiz.document.addEventListener) raiz.document.addEventListener('visibilitychange', aoVisibilidade, false);

  var api = {
    iniciar: function (canvas) {
      if (!canvas || !raiz.document) return null;
      if (atual && canvasAtual === canvas) { atual.iniciar(); return atual; }
      api.destruir();
      canvasAtual = canvas;
      try { atual = criar(canvas); } catch (e) { atual = null; }
      if (!atual) return null;
      canvasAtual = atual.canvas || canvas;
      try {
        if (typeof raiz.IntersectionObserver === 'function') {
          if (observador) observador.disconnect();
          observador = new raiz.IntersectionObserver(function (entradas) {
            if (entradas.some(function (x) { return x.isIntersecting; })) retomar(); else pausar();
          }, { threshold: .01 });
          observador.observe(canvasAtual);
        }
      } catch (e) { /* observador opcional */ }
      atual.iniciar();
      return atual;
    },
    parar: function () { if (atual) atual.parar(); },
    destruir: function () {
      try { if (observador) { observador.disconnect(); observador = null; } } catch (e) { /* opcional */ }
      if (atual && atual.destruir) atual.destruir(); else if (atual) atual.parar();
      atual = null; canvasAtual = null; pausadoPorTela = false;
    },
    estado: function (n) { if (atual && typeof atual.estado === 'function') atual.estado(n); },
    nivel: function (v) { if (atual && typeof atual.nivel === 'function') atual.nivel(v); },
    ativo: function () { return !!(atual && atual.rodando); },
    tipo: function () { return !atual ? null : (atual.renderer ? 'webgl' : 'canvas2d'); },
    diagnostico: function () {
      if (!atual) return { tipo: null, rodando: false, motivo: 'avatar não iniciado' };
      return { tipo: atual.renderer ? 'webgl' : 'canvas2d', rodando: !!atual.rodando, sincronia: 'amplitude da voz, não visemas fonéticos' };
    }
  };
  raiz.AvatarJarvis = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
