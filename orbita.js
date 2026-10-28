/* J.A.R.V.I.S. Nova — Núcleo "Órbita".
 *
 * Adaptação para o aplicativo do visualizador enviado (jarvis_ai_core_visualizer.html).
 * O original usa Three.js e shaders carregados por CDN; aqui a mesma ideia — esfera de
 * partículas com ruído, três anéis holográficos e núcleo luminoso — é desenhada em
 * Canvas 2D, sem dependência externa, sem CDN e sem WebGL obrigatório. Isso mantém o APK
 * funcionando offline, sob a Content-Security-Policy do app e em aparelhos modestos.
 *
 * Paletas e intensidades vêm dos quatro estados do assistente (idle, listening, thinking,
 * speaking). O nível do microfone entra por NucleoOrbita.nivel() e expande a nuvem, como no
 * arquivo de referência. Tudo é opcional: se este arquivo não carregar, os outros dois
 * estilos de núcleo continuam funcionando.
 */
(function (raiz) {
  'use strict';

  var PALETAS = {
    idle: { prim: [6, 182, 212], sec: [2, 132, 199], nucleo: [34, 211, 238], giro: 0.30, ruido: 0.10, anel: 0.34 },
    listening: { prim: [37, 99, 235], sec: [6, 182, 212], nucleo: [96, 165, 250], giro: 0.80, ruido: 0.42, anel: 0.62 },
    thinking: { prim: [217, 119, 6], sec: [124, 58, 237], nucleo: [251, 191, 36], giro: 2.00, ruido: 0.74, anel: 1.10 },
    speaking: { prim: [5, 150, 105], sec: [6, 182, 212], nucleo: [52, 211, 153], giro: 1.05, ruido: 0.52, anel: 0.80 }
  };

  var reduzido = false;
  try { reduzido = !!(raiz.matchMedia && raiz.matchMedia('(prefers-reduced-motion: reduce)').matches); } catch (e) { reduzido = false; }

  function misturar(a, b, t) {
    var k = Math.max(0, Math.min(1, t));
    return [
      Math.round(a[0] + (b[0] - a[0]) * k),
      Math.round(a[1] + (b[1] - a[1]) * k),
      Math.round(a[2] + (b[2] - a[2]) * k)
    ];
  }
  function rgba(c, a) { return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a.toFixed(3) + ')'; }

  function Renderizador(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d', { alpha: true });
    this.estado = 'idle';
    this.nivel = 0;
    this.nivelAlvo = 0;
    this.atual = null;
    this.alvo = PALETAS.idle;
    this.giro = 0;
    this.anel = { prim: 0.30 };
    this.rodando = false;
    this.ultimo = 0;
    this.pontos = [];
    this.largura = 0;
    this.altura = 0;
    this.dpr = 1;
    this.gerarPontos();
    this.atual = JSON.parse(JSON.stringify(PALETAS.idle));
    var self = this;
    this.aoRedimensionar = function () { self.medir(); };
    raiz.addEventListener('resize', this.aoRedimensionar, false);
    raiz.addEventListener('orientationchange', this.aoRedimensionar, false);
    if (typeof raiz.addEventListener === 'function') {
      this.aoVisibilidade = function () {
        if (raiz.document && raiz.document.hidden) self.parar();
        else if (self.desejado) self.iniciar();
      };
      raiz.document.addEventListener('visibilitychange', this.aoVisibilidade);
    }
  }

  Renderizador.prototype.gerarPontos = function () {
    var compacto = this.largura && this.largura < 520;
    var n = reduzido ? 260 : (compacto ? 430 : 820);
    var pontos = [];
    var ouro = Math.PI * (3 - Math.sqrt(5));
    for (var i = 0; i < n; i++) {
      var y = 1 - (i / (n - 1)) * 2;
      var r = Math.sqrt(Math.max(0, 1 - y * y));
      var t = ouro * i;
      var raio = 1.02 + Math.random() * 1.28;
      pontos.push({
        x: Math.cos(t) * r * raio,
        y: y * raio,
        z: Math.sin(t) * r * raio,
        camada: Math.random(),
        tam: 0.8 + Math.random() * 1.5,
        fase: Math.random() * Math.PI * 2
      });
    }
    this.pontos = pontos;
  };

  Renderizador.prototype.medir = function () {
    var canvas = this.canvas;
    if (!canvas) return;
    var r = canvas.getBoundingClientRect ? canvas.getBoundingClientRect() : { width: 0, height: 0 };
    var largura = Math.max(1, Math.round(r.width || canvas.clientWidth || 300));
    var altura = Math.max(1, Math.round(r.height || canvas.clientHeight || 300));
    var dpr = Math.min(raiz.devicePixelRatio || 1, largura < 520 ? 1.5 : 2);
    if (largura === this.largura && altura === this.altura && dpr === this.dpr) return;
    this.largura = largura;
    this.altura = altura;
    this.dpr = dpr;
    canvas.width = Math.round(largura * dpr);
    canvas.height = Math.round(altura * dpr);
    if (!this.pontos.length || Math.abs(this.pontos.length - (largura < 520 ? 430 : 820)) > 380) this.gerarPontos();
  };

  Renderizador.prototype.iniciar = function () {
    if (this.rodando || !this.canvas) return;
    this.desejado = true;
    this.rodando = true;
    this.medir();
    var self = this;
    this.ultimo = 0;
    var passo = function (ts) {
      if (!self.rodando) return;
      self.quadro(ts);
      self.raf = raiz.requestAnimationFrame(passo);
    };
    this.raf = raiz.requestAnimationFrame(passo);
  };

  Renderizador.prototype.parar = function () {
    this.desejado = false;
    this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };

  Renderizador.prototype.estado = function (nome) {
    var p = PALETAS[nome];
    if (!p) return;
    this.estado = nome;
    this.alvo = p;
  };

  Renderizador.prototype.nivel = function (v) {
    var n = Number(v);
    if (Number.isFinite(n)) this.nivelAlvo = Math.max(0, Math.min(1, n));
  };

  Renderizador.prototype.quadro = function (ts) {
    var ctx = this.ctx;
    if (!ctx) return;
    var dt = this.ultimo ? Math.min(64, ts - this.ultimo) : 16;
    this.ultimo = ts;
    var passo = dt / 16.667;
    var alvo = this.alvo || PALETAS.idle;
    var at = this.atual;

    at.prim = misturar(at.prim, alvo.prim, 0.06 * passo);
    at.sec = misturar(at.sec, alvo.sec, 0.06 * passo);
    at.nucleo = misturar(at.nucleo, alvo.nucleo, 0.06 * passo);
    at.giro += (alvo.giro - at.giro) * 0.05 * passo;
    at.ruido += (alvo.ruido - at.ruido) * 0.05 * passo;
    at.anel += (alvo.anel - at.anel) * 0.05 * passo;
    this.nivel += (this.nivelAlvo - this.nivel) * 0.12 * passo;

    var lento = reduzido ? 0.25 : 1;
    this.giro += (at.giro * 0.0025 + 0.0012) * passo * lento;

    var w = this.largura, h = this.altura;
    if (!w || !h) { this.medir(); return; }
    var cx = w / 2, cy = h / 2;
    var raio = Math.min(w, h) * 0.20;
    var expansao = 1 + this.nivel * 0.14;

    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    // Halo de fundo: dá o "aquário" luminoso do visualizador sem custo de blur.
    var halo = ctx.createRadialGradient(cx, cy, raio * 0.1, cx, cy, raio * 3.1);
    halo.addColorStop(0, rgba(at.prim, 0.20 + this.nivel * 0.14));
    halo.addColorStop(0.45, rgba(at.sec, 0.09));
    halo.addColorStop(1, rgba(at.prim, 0));
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.arc(cx, cy, raio * 3.1, 0, Math.PI * 2); ctx.fill();

    // Anéis holográficos (três elipses inclinadas, como no arquivo de referência).
    var giroAnel = this.giro * 0.8;
    var inclinacoes = [0.12, 0.42, 0.78];
    for (var a = 0; a < inclinacoes.length; a++) {
      var inc = inclinacoes[a];
      var r = raio * (1.62 + a * 0.34) * expansao;
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(giroAnel * (a % 2 ? -1 : 1) + inc);
      ctx.scale(1, 0.30 + inc * 0.16);
      ctx.beginPath();
      ctx.arc(0, 0, r, 0, Math.PI * 2);
      ctx.lineWidth = 1 + a * 0.25;
      ctx.strokeStyle = rgba(a === 1 ? at.nucleo : at.prim, 0.16 + at.anel * 0.30 + this.nivel * 0.10);
      ctx.stroke();
      ctx.restore();
    }

    // Esfera de partículas com rotação em Y e leve inclinação em X.
    var rotY = this.giro;
    var rotX = 0.32 + Math.sin(this.giro * 0.6) * 0.12;
    var cyR = Math.cos(rotY), syR = Math.sin(rotY);
    var cxR = Math.cos(rotX), sxR = Math.sin(rotX);
    var dist = 3.4;
    ctx.globalCompositeOperation = 'lighter';
    for (var i = 0; i < this.pontos.length; i++) {
      var p = this.pontos[i];
      var ond = Math.sin(this.giro * 3 + p.fase) * at.ruido * 0.12;
      var rr = 1 + ond + this.nivel * 0.22;
      var px = p.x * rr, py = p.y * rr, pz = p.z * rr;
      var x1 = px * cyR - pz * syR;
      var z1 = px * syR + pz * cyR;
      var y1 = py * cxR - z1 * sxR;
      var z2 = py * sxR + z1 * cxR;
      var esc = dist / (dist - z2);
      var sx = cx + x1 * esc * raio * expansao;
      var sy = cy + y1 * esc * raio * expansao;
      var prof = Math.max(0, Math.min(1, (z2 + 2.4) / 4.8));
      var cor = misturar(at.sec, at.prim, p.camada * 0.7 + prof * 0.3);
      var alfa = 0.10 + prof * 0.55 + this.nivel * 0.14;
      var tamanho = p.tam * esc * (0.7 + prof * 0.7);
      ctx.fillStyle = rgba(cor, alfa);
      ctx.fillRect(sx - tamanho / 2, sy - tamanho / 2, tamanho, tamanho);
    }
    ctx.globalCompositeOperation = 'source-over';

    // Núcleo: miolo luminoso e ponto central, respirando com o microfone.
    var pulso = 1 + Math.sin(ts / 900) * 0.04 + this.nivel * 0.20;
    var rNucleo = raio * 0.34 * pulso;
    var miolo = ctx.createRadialGradient(cx, cy, 0, cx, cy, rNucleo);
    miolo.addColorStop(0, rgba(at.nucleo, 0.95));
    miolo.addColorStop(0.35, rgba(at.nucleo, 0.40));
    miolo.addColorStop(1, rgba(at.prim, 0));
    ctx.fillStyle = miolo;
    ctx.beginPath(); ctx.arc(cx, cy, rNucleo, 0, Math.PI * 2); ctx.fill();

    ctx.beginPath();
    ctx.arc(cx, cy, raio * 0.055 * pulso, 0, Math.PI * 2);
    ctx.fillStyle = rgba([240, 255, 254], 0.9);
    ctx.fill();

    // Aro fino do miolo.
    ctx.beginPath();
    ctx.arc(cx, cy, raio * 0.52 * pulso, 0, Math.PI * 2);
    ctx.lineWidth = 1;
    ctx.strokeStyle = rgba(at.nucleo, 0.22 + this.nivel * 0.18);
    ctx.stroke();
  };

  var instancia = null;
  var api = {
    /** Liga o desenho no canvas indicado (idempotente). */
    iniciar: function (canvas) {
      if (!canvas || !canvas.getContext) return null;
      if (instancia && instancia.canvas === canvas) { instancia.iniciar(); return instancia; }
      if (instancia) instancia.parar();
      instancia = new Renderizador(canvas);
      instancia.iniciar();
      return instancia;
    },
    parar: function () { if (instancia) instancia.parar(); },
    estado: function (nome) { if (instancia) instancia.estado(nome); },
    nivel: function (v) { if (instancia) instancia.nivel(v); },
    ativo: function () { return !!(instancia && instancia.rodando); },
    paletas: PALETAS
  };

  raiz.NucleoOrbita = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
