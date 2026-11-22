/* J.A.R.V.I.S. Nova — núcleo 3D v3 (motor próprio, sem dependência).
 *
 * Desenha um reator de arco animado: esfera de malha em wireframe com rotação real em
 * três eixos, três anéis giroscópicos com marcações, satélites em órbita e um sweep de
 * radar. Tudo em Canvas 2D com projeção em perspectiva — não depende de three.js, não
 * baixa nada e não quebra se o WebGL não existir.
 *
 * Regras de desempenho (porque a interface não pode travar):
 *  - teto de 60 quadros por segundo, com passo de tempo limitado;
 *  - densidade de pixels limitada a 2 (celular com tela densa não desenha 3x);
 *  - pausa automática quando a aba/app vai para segundo plano ou a tela apaga;
 *  - modo reduzido quando o sistema pede menos movimento: sem rotação, só respiração;
 *  - desenho em camadas com transparência, sem sombra de canvas (caro em celular fraco).
 *
 * API: window.JarvisNucleoV3 = { iniciar(canvas), parar(), estado(nome), nivel(0..1),
 *                                ativo(), fps(), diagnostico() }.
 */
(function (raiz) {
  'use strict';

  // Cada estado tem cor e velocidade próprias: a diferença precisa ser visível no
  // celular, com brilho de sol na tela, não só no nome do chip ao lado.
  var PALETAS = {
    idle: { a: '#22d3ee', b: '#0e7490', c: '#a5f3fc', giro: 0.18 },
    listening: { a: '#60a5fa', b: '#1d4ed8', c: '#dbeafe', giro: 0.46 },
    thinking: { a: '#fbbf24', b: '#b45309', c: '#fde68a', giro: 0.62 },
    processing: { a: '#f59e0b', b: '#c2410c', c: '#fef3c7', giro: 0.52 },
    speaking: { a: '#34d399', b: '#047857', c: '#d1fae5', giro: 0.42 },
    error: { a: '#f87171', b: '#991b1b', c: '#fee2e2', giro: 0.16 }
  };

  function paleta(nome) { return PALETAS[nome] || PALETAS.idle; }

  function limita(v, min, max) { return v < min ? min : (v > max ? max : v); }

  // Matriz de rotação aplicada a um ponto (x,y,z). Rotação em Y e X, na ordem do desenho.
  function gira(p, ax, ay) {
    var cosY = Math.cos(ay), sinY = Math.sin(ay);
    var x1 = p.x * cosY + p.z * sinY;
    var z1 = -p.x * sinY + p.z * cosY;
    var cosX = Math.cos(ax), sinX = Math.sin(ax);
    var y1 = p.y * cosX - z1 * sinX;
    var z2 = p.y * sinX + z1 * cosX;
    return { x: x1, y: y1, z: z2 };
  }

  function Render(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.rodando = false;
    this.quadro = 0;
    this.tempo = 0;
    this.estadoAtual = 'idle';
    this.nivelAlvo = 0;
    this.nivelAtual = 0;
    this.fps = 0;
    this.ultimoFps = 0;
    this.contagemFps = 0;
    this.w = 0;
    this.h = 0;
    this.dpr = 1;
    this.menor = false;      // tela estreita: menos elementos
    this.reduzido = false;   // sistema pediu menos movimento
    this.escondido = false;
    this.ultimoQuadro = 0;
    this.agendado = 0;
  }

  Render.prototype.capacidade = function () {
    return {
      quadros: this.quadro,
      fps: Math.round(this.fps),
      largura: this.w,
      altura: this.h,
      densidade: this.dpr,
      reduzido: this.reduzido,
      escondido: this.escondido,
      estado: this.estadoAtual
    };
  };

  Render.prototype.ajustar = function () {
    if (!this.canvas || !this.ctx) return;
    var largura = this.canvas.clientWidth || this.canvas.parentNode && this.canvas.parentNode.clientWidth || 320;
    var altura = this.canvas.clientHeight || this.canvas.parentNode && this.canvas.parentNode.clientHeight || 320;
    var dpr = Math.min(raiz.devicePixelRatio || 1, 2);
    if (largura === this.w && altura === this.h && dpr === this.dpr) return;
    this.w = largura;
    this.h = altura;
    this.dpr = dpr;
    this.canvas.width = Math.max(1, Math.round(largura * dpr));
    this.canvas.height = Math.max(1, Math.round(altura * dpr));
    this.menor = largura < 300;
    var self = this;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.centro = { x: largura / 2, y: altura / 2, raio: Math.min(largura, altura) * 0.42 };
    // Recalcula a malha do globo no tamanho atual.
    this.pontos = this.malha();
    void self;
  };

  /* Malha esférica: meridianos e paralelos, já em coordenadas 3D. */
  Render.prototype.malha = function () {
    var pontos = [];
    var meridianos = this.menor ? 10 : 16;
    var paralelos = this.menor ? 6 : 10;
    var i, j;
    for (i = 0; i < meridianos; i++) {
      var lon = (i / meridianos) * Math.PI * 2;
      var linha = [];
      for (j = 0; j <= 24; j++) {
        var lat = (j / 24) * Math.PI - Math.PI / 2;
        linha.push({ x: Math.cos(lat) * Math.cos(lon), y: Math.sin(lat), z: Math.cos(lat) * Math.sin(lon) });
      }
      pontos.push(linha);
    }
    for (i = 1; i < paralelos; i++) {
      var l = (i / paralelos) * Math.PI - Math.PI / 2;
      var anel = [];
      for (j = 0; j <= 32; j++) {
        var lo = (j / 32) * Math.PI * 2;
        anel.push({ x: Math.cos(l) * Math.cos(lo), y: Math.sin(l), z: Math.cos(l) * Math.sin(lo) });
      }
      pontos.push(anel);
    }
    return pontos;
  };

  Render.prototype.projetar = function (p, escala) {
    var foco = 3.1;
    var z = p.z + foco;
    if (z <= 0.2) z = 0.2;
    var k = (this.centro.raio * 1.9 * escala) / z;
    return { x: this.centro.x + p.x * k, y: this.centro.y + p.y * k, z: p.z };
  };

  Render.prototype.globo = function (cor, alphaBase) {
    var ctx = this.ctx;
    var malha = this.pontos || [];
    var ax = 0.42, ay = this.tempo * 0.5;   // inclinação fixa + giro lento
    var i, j, linha, a, b, pa, pb;
    ctx.lineWidth = 1;
    for (i = 0; i < malha.length; i++) {
      linha = malha[i];
      for (j = 1; j < linha.length; j++) {
        a = gira(linha[j - 1], ax, ay);
        b = gira(linha[j], ax, ay);
        pa = this.projetar(a, 1);
        pb = this.projetar(b, 1);
        // Frente clara, fundo quase invisível: dá a sensação de volume sem custo.
        var prof = (a.z + b.z) / 2;
        var alfa = alphaBase * (prof > 0 ? 1 : 0.16) * (0.55 + prof * 0.45);
        if (alfa <= 0.01) continue;
        ctx.strokeStyle = cor;
        ctx.globalAlpha = limita(alfa, 0.02, 0.92);
        ctx.beginPath();
        ctx.moveTo(pa.x, pa.y);
        ctx.lineTo(pb.x, pb.y);
        ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;
  };

  Render.prototype.anel = function (raio, inclinacao, fase, cor, grossura, marcas) {
    var ctx = this.ctx;
    var passos = this.menor ? 60 : 96;
    var i, ang, p, q, a, b;
    ctx.strokeStyle = cor;
    ctx.globalAlpha = 0.5;
    ctx.lineWidth = grossura;
    ctx.beginPath();
    for (i = 0; i <= passos; i++) {
      ang = (i / passos) * Math.PI * 2 + fase;
      p = gira({ x: Math.cos(ang) * raio, y: 0, z: Math.sin(ang) * raio }, inclinacao, fase * 0.4);
      q = this.projetar(p, 1);
      if (i === 0) ctx.moveTo(q.x, q.y); else ctx.lineTo(q.x, q.y);
    }
    ctx.stroke();
    if (!marcas) { ctx.globalAlpha = 1; return; }
    // Marcações radiais: o que dá a leitura de instrumento, não de enfeite.
    ctx.globalAlpha = 0.75;
    var total = this.menor ? 24 : 48;
    for (i = 0; i < total; i++) {
      ang = (i / total) * Math.PI * 2 + fase;
      var maior = i % 6 === 0;
      p = gira({ x: Math.cos(ang) * raio, y: 0, z: Math.sin(ang) * raio }, inclinacao, fase * 0.4);
      var dentro = gira({ x: Math.cos(ang) * (raio - (maior ? 0.075 : 0.035)), y: 0, z: Math.sin(ang) * (raio - (maior ? 0.075 : 0.035)) }, inclinacao, fase * 0.4);
      a = this.projetar(p, 1);
      b = this.projetar(dentro, 1);
      ctx.lineWidth = maior ? 1.4 : 0.8;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  };

  Render.prototype.nucleo = function (corA, corC, nivel) {
    var ctx = this.ctx;
    var c = this.centro;
    var r = c.raio * (0.30 + nivel * 0.06);
    // Brilho contido: o reator ilumina sem apagar a malha por cima dele.
    var brilho = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, r * 2.8);
    brilho.addColorStop(0, 'rgba(255,255,255,.50)');
    brilho.addColorStop(0.10, corC);
    brilho.addColorStop(0.34, corA);
    brilho.addColorStop(1, 'rgba(4,12,22,0)');
    ctx.globalAlpha = 0.34 + nivel * 0.34;
    ctx.fillStyle = brilho;
    ctx.beginPath();
    ctx.arc(c.x, c.y, r * 2.8, 0, Math.PI * 2);
    ctx.fill();
    // Contorno do miolo: dá o desenho de reator, em vez de uma mancha clara.
    ctx.globalAlpha = 0.55 + nivel * 0.3;
    ctx.strokeStyle = corC;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(c.x, c.y, r * 0.92, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
    // Ponto de luz, pequeno e definido.
    var ponto = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, r * 0.55);
    ponto.addColorStop(0, 'rgba(255,255,255,.98)');
    ponto.addColorStop(0.45, corC);
    ponto.addColorStop(1, 'rgba(4,12,22,0)');
    ctx.fillStyle = ponto;
    ctx.beginPath();
    ctx.arc(c.x, c.y, r * 0.55, 0, Math.PI * 2);
    ctx.fill();
  };

  Render.prototype.satelites = function (cor, nivel) {
    var ctx = this.ctx;
    var total = this.menor ? 3 : 5;
    for (var i = 0; i < total; i++) {
      var ang = this.tempo * (0.5 + i * 0.12) + i * 1.7;
      var raio = 1.22 + (i % 2) * 0.12;
      var p = gira({ x: Math.cos(ang) * raio, y: Math.sin(ang * 0.7) * 0.35, z: Math.sin(ang) * raio }, 0.42, 0);
      var q = this.projetar(p, 1);
      var r = (1.6 + nivel * 2.2) * (q.z > 0 ? 1.5 : 0.8);
      ctx.globalAlpha = q.z > 0 ? 0.9 : 0.35;
      ctx.fillStyle = cor;
      ctx.beginPath();
      ctx.arc(q.x, q.y, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  };

  Render.prototype.sweep = function (cor) {
    var ctx = this.ctx;
    var c = this.centro;
    var r = c.raio * 0.95;
    var inicio = this.tempo * 0.9;
    ctx.globalAlpha = 0.5;
    ctx.strokeStyle = cor;
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.arc(c.x, c.y, r, inicio, inicio + 0.55);
    ctx.stroke();
    ctx.globalAlpha = 1;
  };

  Render.prototype.desenhar = function () {
    var ctx = this.ctx;
    if (!ctx) return;
    var c = this.centro;
    if (!c) return;
    ctx.clearRect(0, 0, this.w, this.h);
    var p = paleta(this.estadoAtual);
    var nivel = this.nivelAtual;
    var escala = 1 + nivel * 0.05;

    this.nucleo(p.c, p.c, nivel);
    this.globo(p.b, this.reduzido ? 0.35 : 0.62);
    this.anel(1.05, 0.42, this.tempo * 0.30, p.a, 1.6, true);
    this.anel(1.22, -0.55, -this.tempo * 0.22, p.b, 1.1, true);
    this.anel(0.86, 0.95, this.tempo * 0.16, p.c, 0.9, false);
    if (!this.reduzido) this.satelites(p.c, nivel);
    this.sweep(p.c);
    void escala;
  };

  Render.prototype.laco = function (agora) {
    if (!this.rodando) return;
    var self = this;
    this.agendado = raiz.requestAnimationFrame(function (t) { self.laco(t); });
    if (this.escondido) return;
    var dt = agora - (this.ultimoQuadro || agora);
    this.ultimoQuadro = agora;
    // Passo limitado: se houve engasgo, o desenho não salta.
    dt = limita(dt, 0, 64) / 1000;
    // Teto de 60 fps: em tela de 120 Hz não gastamos o dobro à toa.
    if (dt < 0.0155) return;
    this.contagemFps++;
    if (agora - this.ultimoFps > 500) {
      this.fps = (this.contagemFps * 1000) / (agora - this.ultimoFps);
      this.contagemFps = 0;
      this.ultimoFps = agora;
    }
    var p = paleta(this.estadoAtual);
    if (!this.reduzido) this.tempo += dt * (0.55 + p.giro + this.nivelAtual * 0.9);
    this.nivelAtual += (this.nivelAlvo - this.nivelAtual) * Math.min(1, dt * 9);
    this.ajustar();
    this.desenhar();
    this.quadro++;
  };

  var atual = null;

  function lerEstado() {
    try {
      var s = raiz.document && raiz.document.body && raiz.document.body.dataset.state;
      return PALETAS[s] ? s : 'idle';
    } catch (e) { return 'idle'; }
  }

  function lerNivel() {
    // O app publica o nível do microfone em --nv; se não houver, o núcleo respira sozinho.
    try {
      var bruto = raiz.getComputedStyle(raiz.document.documentElement).getPropertyValue('--nv').trim();
      var n = parseFloat(bruto);
      if (Number.isFinite(n)) return limita(n > 1 ? n / 100 : n, 0, 1);
    } catch (e) { /* sem estilo computável: segue o repouso */ }
    return 0.12 + Math.sin(Date.now() / 900) * 0.06;
  }

  function iniciar(canvas) {
    var alvo = canvas || (raiz.document && raiz.document.getElementById('nucleo-v3'));
    if (!alvo || typeof alvo.getContext !== 'function') return false;
    if (atual && atual.canvas === alvo && atual.rodando) return true;
    parar();
    var r = new Render(alvo);
    if (!r.ctx) return false;
    r.reduzido = !!(raiz.matchMedia && raiz.matchMedia('(prefers-reduced-motion: reduce)').matches);
    r.estadoAtual = lerEstado();
    r.ajustar();
    r.rodando = true;
    r.ultimoFps = raiz.performance && raiz.performance.now ? raiz.performance.now() : Date.now();
    atual = r;
    var laco = function (t) { r.laco(t); };
    if (raiz.requestAnimationFrame) raiz.requestAnimationFrame(laco);
    // Esconde/pausa: nada de animação escondida gastando bateria.
    var doc = raiz.document;
    if (doc && doc.addEventListener) {
      doc.addEventListener('visibilitychange', function () {
        if (!atual) return;
        atual.escondido = doc.hidden === true;
        if (!atual.escondido) atual.ultimoQuadro = 0;
      });
    }
    if (raiz.document && raiz.document.body && raiz.MutationObserver) {
      var observador = new raiz.MutationObserver(function () {
        if (atual) atual.estadoAtual = lerEstado();
      });
      observador.observe(raiz.document.body, { attributes: true, attributeFilter: ['data-state'] });
      r.observador = observador;
    }
    return true;
  }

  function parar() {
    if (!atual) return;
    atual.rodando = false;
    if (atual.agendado && raiz.cancelAnimationFrame) raiz.cancelAnimationFrame(atual.agendado);
    if (atual.observador) atual.observador.disconnect();
    atual = null;
  }

  raiz.JarvisNucleoV3 = {
    iniciar: iniciar,
    parar: parar,
    ativo: function () { return !!(atual && atual.rodando); },
    estado: function (nome) {
      if (!atual) return lerEstado();
      if (nome && PALETAS[nome]) atual.estadoAtual = nome;
      return atual.estadoAtual;
    },
    nivel: function (v) {
      if (!atual) return 0;
      if (Number.isFinite(Number(v))) atual.nivelAlvo = limita(Number(v), 0, 1);
      return atual.nivelAlvo;
    },
    fps: function () { return atual ? Math.round(atual.fps) : 0; },
    diagnostico: function () {
      if (!atual) return { ativo: false, motivo: 'núcleo não iniciado' };
      return Object.assign({ ativo: atual.rodando }, atual.capacidade());
    }
  };

  // Inicia sozinho quando a tela já existe; a cada quadro o nível vem de --nv.
  var bombeando = false;
  function bombear() {
    if (atual) atual.nivelAlvo = lerNivel();
    if (raiz.requestAnimationFrame) raiz.requestAnimationFrame(bombear);
  }

  function arrancar() {
    try {
      var canvas = raiz.document && raiz.document.getElementById('nucleo-v3');
      if (!canvas) return false;
      if (atual && atual.canvas === canvas && atual.rodando) return true;
      if (!iniciar(canvas)) return false;
      if (!bombeando) { bombeando = true; bombear(); }
      return true;
    } catch (e) { return false; /* o núcleo é opcional: a interface continua inteira */ }
  }

  // Tentativas repetidas e baratas: cobrem app que monta a tela depois do DOM pronto.
  // arrancar() é idempotente, então repetir não duplica animação nem canva.
  if (raiz.document) {
    if (raiz.document.readyState === 'loading') {
      raiz.document.addEventListener('DOMContentLoaded', arrancar, { once: true });
    } else {
      arrancar();
    }
    if (raiz.addEventListener) raiz.addEventListener('load', arrancar);
    [120, 400, 1200, 2600].forEach(function (atraso) {
      if (raiz.setTimeout) raiz.setTimeout(arrancar, atraso);
    });
    if (raiz.document.body && raiz.MutationObserver) {
      var volta = new raiz.MutationObserver(function () { if (!atual) arrancar(); });
      volta.observe(raiz.document.body, { childList: true, subtree: true });
    }
  }
})(typeof window !== 'undefined' ? window : this);
