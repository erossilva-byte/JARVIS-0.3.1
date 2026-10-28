/* J.A.R.V.I.S. Nova — Núcleo "Órbita" 3D.
 *
 * Cena 3D real (Three.js local, sem CDN) com partículas em shader, três anéis em planos
 * diferentes, miolo em arame e brilho aditivo. Reage ao nível do microfone.
 *
 * 1.17.0 — correção e fluidez:
 *  - BUG CORRIGIDO: o construtor gravava `nivel` como número (0) por cima do método
 *    `nivel(v)` do protótipo. Chamar NucleoOrbita.nivel() estourava com
 *    "instancia.nivel is not a function". O valor agora vive em `audioNivel` e a fachada
 *    confere o tipo antes de chamar, então uma instância parcial nunca derruba o app.
 *  - Sem alocação por quadro: cores são instâncias compartilhadas com os materiais e os
 *    uniformes apontam para os mesmos objetos; nada de `new` dentro do laço.
 *  - Pausa quando o canvas sai da tela (IntersectionObserver) ou a aba fica oculta.
 *  - Qualidade adaptativa: se o FPS cai, reduz o pixel ratio e o número de partículas
 *    desenhadas (setDrawRange) uma única vez, sem tocar na aparência geral.
 *  - Antialias só quando o pixel ratio é baixo (em telas 2x ele custa caro e quase não
 *    aparece); contexto liberado ao trocar de estilo (forceContextLoss).
 *  - Fallback em Canvas 2D se WebGL não existir ou falhar: o estilo nunca fica vazio.
 *
 * 1.18.0 — mesmo desenho no celular e no PC:
 *  - BUG CORRIGIDO: o tamanho do ponto era `aSize * (250 / profundidade)`. Com a câmera a
 *    5,4 unidades isso dava ~46x, ou seja, sprites de até ~150 px cada. Com milhares de
 *    partículas em blending aditivo, a esfera virava um quadrado branco estourado (o que
 *    aparecia na tela) e o custo de preenchimento travava o aparelho. Agora o tamanho é
 *    `aSize * pixelRatio * (3.2 / profundidade)`, limitado a 22 px, com brilho menor.
 *  - O teste de WebGL não usa mais o canvas real: pedir o contexto antes do Three.js
 *    fixava os atributos (alpha desligado) e deixava a esfera num quadro preto/opaco.
 *  - Contexto WebGL perdido (memória apertada no Android, driver reiniciado no PC) é
 *    recuperado em vez de congelar a animação.
 *  - ResizeObserver: abrir o painel, girar o aparelho ou mudar a janela recalcula o
 *    tamanho sem esperar o evento `resize` da janela.
 *  - Vigia de visibilidade: se o IntersectionObserver não acusar visibilidade (layout
 *    tardio, navegador embutido), a animação começa mesmo assim.
 *
 * API pública (inalterada): iniciar(canvas), parar(), estado(nome), nivel(v), ativo(),
 * tipo(), diagnostico().
 */
(function (raiz) {
  'use strict';

  var PALETAS = {
    idle: { prim: 0x06b6d4, sec: 0x0284c7, nucleo: 0x22d3ee, giro: 0.30, ruido: 0.10, anel: 0.34, pulso: 1.0 },
    listening: { prim: 0x2563eb, sec: 0x06b6d4, nucleo: 0x60a5fa, giro: 0.80, ruido: 0.42, anel: 0.62, pulso: 1.5 },
    thinking: { prim: 0xd97706, sec: 0x7c3aed, nucleo: 0xfbbf24, giro: 2.00, ruido: 0.74, anel: 1.10, pulso: 1.9 },
    speaking: { prim: 0x059669, sec: 0x06b6d4, nucleo: 0x34d399, giro: 1.05, ruido: 0.52, anel: 0.80, pulso: 1.6 }
  };

  var reduzido = false;
  try { reduzido = !!(raiz.matchMedia && raiz.matchMedia('(prefers-reduced-motion: reduce)').matches); } catch (e) { reduzido = false; }

  var VERTEX = [
    'uniform float uTime;',
    'uniform float uAudio;',
    'uniform float uEscala;',
    'uniform float uPixelRatio;',
    'attribute float aSize;',
    'attribute float aSeed;',
    'varying float vSeed;',
    'varying float vDepth;',
    'void main() {',
    '  vec3 p = position;',
    '  float w = sin(p.x * 3.0 + uTime * 0.85 + aSeed * 6.2831) * 0.5',
    '          + sin(p.y * 2.4 - uTime * 0.62 + aSeed * 3.1415) * 0.5',
    '          + sin(p.z * 3.6 + uTime * 0.95) * 0.35;',
    '  p *= 1.0 + w * (0.035 + uAudio * 0.16);',
    '  p += normalize(p) * uAudio * (0.16 + 0.10 * sin(aSeed * 9.0 + uTime * 2.2));',
    '  vec4 mv = modelViewMatrix * vec4(p, 1.0);',
    '  vSeed = aSeed;',
    '  vDepth = -mv.z;',
    '  float tamanho = aSize * uEscala * uPixelRatio * (3.2 / max(0.9, vDepth));',
    '  gl_PointSize = clamp(tamanho * (1.0 + uAudio * 0.55), 1.0, 22.0);',
    '  gl_Position = projectionMatrix * mv;',
    '}'
  ].join('\n');

  var FRAGMENT = [
    'uniform vec3 uColorA;',
    'uniform vec3 uColorB;',
    'uniform float uOpacity;',
    'varying float vSeed;',
    'varying float vDepth;',
    'void main() {',
    '  vec2 d = gl_PointCoord - vec2(0.5);',
    '  float r = length(d);',
    '  if (r > 0.5) discard;',
    '  float a = smoothstep(0.5, 0.04, r);',
    '  float mistura = clamp(vSeed * 0.72 + (vDepth - 3.0) * 0.10, 0.0, 1.0);',
    '  vec3 c = mix(uColorA, uColorB, mistura);',
    '  gl_FragColor = vec4(c, a * uOpacity);',
    '}'
  ].join('\n');

  /**
   * Teste de WebGL em um canvas descartável.
   *
   * Antes o teste pedia o contexto no próprio canvas do HUD. O navegador devolve SEMPRE o
   * mesmo contexto para o mesmo canvas, então o WebGLRenderer do Three.js herdava os
   * atributos do teste (alpha desligado, antialias ligado) e o resultado era um quadro
   * opaco — no celular, o quadrado branco da captura. Além disso, cada tentativa gastava
   * um dos poucos contextos que o navegador permite.
   */
  function suportaWebGL() {
    try {
      var c = raiz.document.createElement('canvas');
      c.width = c.height = 2;
      var ctx = c.getContext('webgl2') || c.getContext('webgl') || c.getContext('experimental-webgl');
      if (!ctx) return false;
      try {
        var perca = ctx.getExtension('WEBGL_lose_context');
        if (perca) perca.loseContext(); // devolve o contexto na hora
      } catch (e) { /* extensão opcional */ }
      return true;
    } catch (e) { return false; }
  }

  function texturaBrilho() {
    var c = document.createElement('canvas');
    c.width = c.height = 128;
    var g = c.getContext('2d');
    var grd = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    grd.addColorStop(0, 'rgba(255,255,255,1)');
    grd.addColorStop(0.25, 'rgba(180,255,252,.55)');
    grd.addColorStop(0.6, 'rgba(60,220,220,.14)');
    grd.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = grd;
    g.fillRect(0, 0, 128, 128);
    return c;
  }

  /* ---------- Renderizador 3D ---------- */
  function Render3D(canvas) {
    var T = raiz.THREE;
    this.canvas = canvas;
    this.T = T;
    this.estadoAtual = 'idle';
    this.audioNivel = 0;       // valor atual do microfone (o método é nivel(v))
    this.nivelAlvo = 0;
    this.rodando = false;
    this.desejado = false;
    this.quadros = 0;
    this.ultimoFps = 0;
    this.inicioFps = 0;
    this.dprTravado = false;
    this.qualidadeBaixa = false;
    this.largura = 0;
    this.altura = 0;
    this.compacto = false;
    this.contextoPerdido = false;
    this.observadorTamanho = null;

    var dprBase = Math.min(raiz.devicePixelRatio || 1, 2);
    this.renderer = new T.WebGLRenderer({
      canvas: canvas,
      antialias: dprBase < 1.75,
      alpha: true,
      powerPreference: 'high-performance',
      stencil: false
    });
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.info.autoReset = false;
    this.cena = new T.Scene();
    this.camera = new T.PerspectiveCamera(55, 1, 0.1, 100);
    this.camera.position.set(0, 0, 5.4);

    this.grupo = new T.Group();
    this.cena.add(this.grupo);

    this.alvo = Object.assign({}, PALETAS.idle);
    this.corA = new T.Color(PALETAS.idle.prim);
    this.corB = new T.Color(PALETAS.idle.sec);
    this.corNucleo = new T.Color(PALETAS.idle.nucleo);
    this.corAlvoA = new T.Color(PALETAS.idle.prim);
    this.corAlvoB = new T.Color(PALETAS.idle.sec);
    this.corAlvoN = new T.Color(PALETAS.idle.nucleo);

    this.montar();
    this.clock = new T.Clock();
    var self = this;
    this.aoRedimensionar = function () { self.medir(); };
    raiz.addEventListener('resize', this.aoRedimensionar, false);
    raiz.addEventListener('orientationchange', this.aoRedimensionar, false);

    // Perda de contexto: no Android acontece sob pressão de memória; no PC, quando o
    // driver reinicia. Sem estes tratadores a cena ficava parada para sempre.
    this.aoPerderContexto = function (e) {
      try { if (e && e.preventDefault) e.preventDefault(); } catch (x) { /* sem evento */ }
      self.contextoPerdido = true;
      self.rodando = false;
      if (self.raf) { try { raiz.cancelAnimationFrame(self.raf); } catch (x) { /* sem raf */ } self.raf = 0; }
    };
    this.aoRecuperarContexto = function () {
      self.contextoPerdido = false;
      if (!self.desejado) return;
      self.largura = 0; self.altura = 0;
      try { self.medir(); } catch (x) { /* ainda sem tamanho */ }
      self.rodando = false;
      self.iniciar();
    };
    try {
      canvas.addEventListener('webglcontextlost', this.aoPerderContexto, false);
      canvas.addEventListener('webglcontextrestored', this.aoRecuperarContexto, false);
    } catch (e) { /* listeners opcionais */ }

    // O tamanho do HUD muda sem `resize` da janela (painel abrindo, fonte carregando).
    if (typeof raiz.ResizeObserver === 'function') {
      try {
        this.observadorTamanho = new raiz.ResizeObserver(function () { self.medir(); });
        this.observadorTamanho.observe(canvas);
      } catch (e) { this.observadorTamanho = null; }
    }
    this.medir();
  }

  Render3D.prototype.montar = function () {
    var T = this.T;
    this.compacto = (raiz.innerWidth || 400) < 640;
    var total = reduzido ? 620 : (this.compacto ? 1100 : 2100);
    this.totalParticulas = total;

    var geo = new T.BufferGeometry();
    var pos = new Float32Array(total * 3);
    var tam = new Float32Array(total);
    var seed = new Float32Array(total);
    var raioBase = 1.55;
    for (var i = 0; i < total; i++) {
      var u = Math.random() * 2 - 1;
      var theta = Math.random() * Math.PI * 2;
      var r = Math.sqrt(Math.max(0, 1 - u * u));
      var raio = raioBase * (0.82 + Math.random() * 0.34);
      pos[i * 3] = Math.cos(theta) * r * raio;
      pos[i * 3 + 1] = u * raio;
      pos[i * 3 + 2] = Math.sin(theta) * r * raio;
      tam[i] = 1.0 + Math.random() * 1.7;
      seed[i] = Math.random();
    }
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    geo.setAttribute('aSize', new T.BufferAttribute(tam, 1));
    geo.setAttribute('aSeed', new T.BufferAttribute(seed, 1));
    geo.computeBoundingSphere();

    this.uniformes = {
      uTime: { value: 0 },
      uAudio: { value: 0 },
      uEscala: { value: this.compacto ? 0.8 : 1.0 },
      uPixelRatio: { value: Math.min(raiz.devicePixelRatio || 1, 2) },
      uColorA: { value: this.corA },
      uColorB: { value: this.corB },
      uOpacity: { value: 0.78 }
    };
    var material = new T.ShaderMaterial({
      uniforms: this.uniformes,
      vertexShader: VERTEX,
      fragmentShader: FRAGMENT,
      transparent: true,
      depthWrite: false,
      blending: T.AdditiveBlending
    });
    this.particulas = new T.Points(geo, material);
    this.particulas.frustumCulled = false; // a esfera está sempre no centro; evita cálculo por quadro
    this.grupo.add(this.particulas);

    this.aneis = [];
    var raios = [2.05, 2.42, 2.78];
    for (var a = 0; a < 3; a++) {
      var rg = new T.RingGeometry(raios[a], raios[a] + (a === 1 ? 0.010 : 0.016), 160);
      var mat = new T.MeshBasicMaterial({
        transparent: true,
        opacity: 0.30 - a * 0.06,
        side: T.DoubleSide,
        depthWrite: false,
        blending: T.AdditiveBlending
      });
      // Cor compartilhada: um único Color por função, sem clone e sem copy por quadro.
      mat.color = (a === 1) ? this.corNucleo : this.corA;
      var anel = new T.Mesh(rg, mat);
      anel.rotation.set(Math.PI / 2.6 + a * 0.34, a * 0.5, a * 0.2);
      anel.matrixAutoUpdate = true;
      this.grupo.add(anel);
      this.aneis.push(anel);
    }

    var matMiolo = new T.MeshBasicMaterial({ wireframe: true, transparent: true, opacity: 0.46, depthWrite: false });
    matMiolo.color = this.corNucleo;
    this.miolo = new T.Mesh(new T.IcosahedronGeometry(0.62, 1), matMiolo);
    this.grupo.add(this.miolo);

    var matInterno = new T.MeshBasicMaterial({ transparent: true, opacity: 0.14, depthWrite: false });
    matInterno.color = this.corNucleo;
    this.interno = new T.Mesh(new T.SphereGeometry(0.46, 32, 32), matInterno);
    this.grupo.add(this.interno);

    var tex = new T.CanvasTexture(texturaBrilho());
    var matBrilho = new T.SpriteMaterial({
      map: tex, transparent: true, opacity: 0.30,
      blending: T.AdditiveBlending, depthWrite: false
    });
    matBrilho.color = this.corNucleo;
    this.brilho = new T.Sprite(matBrilho);
    this.brilho.scale.set(3.5, 3.5, 1);
    this.grupo.add(this.brilho);

    var matPonto = new T.MeshBasicMaterial({ color: 0xf2fffe, transparent: true, opacity: 0.95 });
    this.ponto = new T.Mesh(new T.SphereGeometry(0.075, 16, 16), matPonto);
    this.grupo.add(this.ponto);
  };

  Render3D.prototype.medir = function () {
    if (!this.renderer) return;
    var r = this.canvas.getBoundingClientRect ? this.canvas.getBoundingClientRect() : { width: 0, height: 0 };
    var largura = Math.max(1, Math.round(r.width || this.canvas.clientWidth || 300));
    var altura = Math.max(1, Math.round(r.height || this.canvas.clientHeight || 300));
    if (largura === this.largura && altura === this.altura) return;
    this.largura = largura;
    this.altura = altura;
    var dpr = Math.min(raiz.devicePixelRatio || 1, largura < 640 ? 1.5 : 2);
    if (this.dprTravado) dpr = 1;
    this.renderer.setPixelRatio(dpr);
    this.renderer.setSize(largura, altura, false);
    this.camera.aspect = largura / altura;
    this.camera.updateProjectionMatrix();
    // O shader precisa do MESMO pixel ratio do renderer: era o que faltava para o sprite
    // ter o mesmo tamanho relativo em telas 1x (PC) e 3x (celular).
    if (this.uniformes && this.uniformes.uPixelRatio) this.uniformes.uPixelRatio.value = dpr;
  };

  Render3D.prototype.iniciar = function () {
    if (this.rodando) return;
    this.desejado = true;
    this.rodando = true;
    this.clock.start();
    this.inicioFps = 0;
    this.quadros = 0;
    var self = this;
    var laco = function () {
      if (!self.rodando) return;
      self.raf = raiz.requestAnimationFrame(laco);
      self.quadro();
    };
    this.raf = raiz.requestAnimationFrame(laco);
  };

  Render3D.prototype.parar = function () {
    this.desejado = false;
    this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };

  /** Pausa sem perder o desejo de rodar (usada quando a tela sai de vista). */
  Render3D.prototype.pausarVisivel = function () {
    this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };

  Render3D.prototype.estado = function (nome) {
    var p = PALETAS[nome];
    if (!p) return;
    this.estadoAtual = nome;
    this.alvo = p;
    this.corAlvoA.setHex(p.prim);
    this.corAlvoB.setHex(p.sec);
    this.corAlvoN.setHex(p.nucleo);
  };

  Render3D.prototype.nivel = function (v) {
    var n = Number(v);
    if (Number.isFinite(n)) this.nivelAlvo = Math.max(0, Math.min(1, n));
  };

  Render3D.prototype.quadro = function () {
    if (!this.renderer) return;
    var dt = Math.min(0.05, this.clock.getDelta() || 0.016);
    var agora = raiz.performance ? raiz.performance.now() : Date.now();
    if (!this.inicioFps) { this.inicioFps = agora; this.quadros = 0; }
    this.quadros++;
    if (agora - this.inicioFps > 1600) {
      var fps = (this.quadros * 1000) / (agora - this.inicioFps);
      this.ultimoFps = fps;
      this.quadros = 0;
      this.inicioFps = agora;
      // Degrau único de qualidade: uma vez só, sem oscilar a cada segundo.
      if (fps < 42 && !this.qualidadeBaixa) {
        this.qualidadeBaixa = true;
        this.dprTravado = true;
        this.largura = 0;
        this.medir();
        var manter = Math.max(300, Math.floor(this.totalParticulas * 0.6));
        this.particulas.geometry.setDrawRange(0, manter);
      }
    }

    var k = 1 - Math.exp(-dt * (reduzido ? 2.2 : 5.5));
    this.audioNivel += (this.nivelAlvo - this.audioNivel) * Math.min(1, dt * 10);
    this.corA.lerp(this.corAlvoA, k);
    this.corB.lerp(this.corAlvoB, k);
    this.corNucleo.lerp(this.corAlvoN, k);

    var giro = reduzido ? this.alvo.giro * 0.35 : this.alvo.giro;
    this.grupo.rotation.y += dt * (0.16 + giro * 0.22);
    this.grupo.rotation.x = Math.sin(this.clock.elapsedTime * 0.22) * 0.10;

    var audio = this.audioNivel * (reduzido ? 0.5 : 1);
    this.uniformes.uTime.value = this.clock.elapsedTime;
    this.uniformes.uAudio.value += (audio - this.uniformes.uAudio.value) * Math.min(1, dt * 8);
    this.uniformes.uEscala.value = (this.compacto ? 0.8 : 1.0) * (1 + this.audioNivel * 0.10);
    // uColorA/uColorB apontam para corA/corB: o lerp acima já atualiza o shader.

    for (var i = 0; i < this.aneis.length; i++) {
      var anel = this.aneis[i];
      anel.rotation.z += dt * (0.10 + giro * 0.30) * (i % 2 ? -1 : 1);
      anel.rotation.x = Math.PI / 2.6 + i * 0.34 + Math.sin(this.clock.elapsedTime * 0.35 + i) * 0.12;
      anel.material.opacity = (0.22 + this.audioNivel * 0.16) * (1 - i * 0.18);
    }

    this.miolo.rotation.y -= dt * (0.35 + giro * 0.5);
    this.miolo.rotation.x += dt * 0.18;
    this.miolo.material.opacity = 0.34 + this.audioNivel * 0.26;
    this.interno.scale.setScalar(1 + this.audioNivel * 0.22 + Math.sin(this.clock.elapsedTime * 1.6) * 0.02);
    this.brilho.material.opacity = 0.24 + this.audioNivel * 0.26;
    var pulso = 1 + Math.sin(this.clock.elapsedTime * 1.8) * (reduzido ? 0 : 0.05) + this.audioNivel * 0.22;
    this.brilho.scale.set(3.5 * pulso, 3.5 * pulso, 1);
    this.ponto.scale.setScalar(1 + this.audioNivel * 0.5);

    this.camera.position.x = Math.sin(this.clock.elapsedTime * 0.13) * 0.14;
    this.camera.position.y = Math.cos(this.clock.elapsedTime * 0.17) * 0.10;
    this.camera.lookAt(0, 0, 0);

    this.renderer.render(this.cena, this.camera);
  };

  Render3D.prototype.destruir = function () {
    this.parar();
    try {
      raiz.removeEventListener('resize', this.aoRedimensionar, false);
      raiz.removeEventListener('orientationchange', this.aoRedimensionar, false);
      if (this.observadorTamanho) { this.observadorTamanho.disconnect(); this.observadorTamanho = null; }
      if (this.canvas) {
        this.canvas.removeEventListener('webglcontextlost', this.aoPerderContexto, false);
        this.canvas.removeEventListener('webglcontextrestored', this.aoRecuperarContexto, false);
      }
    } catch (e) { /* sem listeners */ }
    try {
      this.cena.traverse(function (o) {
        if (o.geometry) o.geometry.dispose();
        if (o.material) {
          if (o.material.map) o.material.map.dispose();
          o.material.dispose();
        }
      });
      this.renderer.dispose();
      this.renderer.forceContextLoss();
    } catch (e) { /* contexto já perdido */ }
  };

  /* ---------- Fallback 2D (WebGL indisponível) ---------- */
  function Render2D(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.rodando = false;
    this.desejado = false;
    this.audioNivel = 0;
    this.nivelAlvo = 0;
    this.giro = 0;
    this.estadoAtual = 'idle';
    this.paleta = PALETAS.idle;
    this.pontos = [];
    this.dpr = 1;
    for (var i = 0; i < 560; i++) {
      var u = Math.random() * 2 - 1, th = Math.random() * Math.PI * 2, r = Math.sqrt(Math.max(0, 1 - u * u));
      this.pontos.push({ x: Math.cos(th) * r, y: u, z: Math.sin(th) * r, s: Math.random() });
    }
    var self = this;
    this.aoRedimensionar = function () { self.medir(); };
    raiz.addEventListener('resize', this.aoRedimensionar, false);
    raiz.addEventListener('orientationchange', this.aoRedimensionar, false);
    this.observadorTamanho = null;
    if (typeof raiz.ResizeObserver === 'function') {
      try {
        this.observadorTamanho = new raiz.ResizeObserver(function () { self.medir(); });
        this.observadorTamanho.observe(canvas);
      } catch (e) { this.observadorTamanho = null; }
    }
    this.medir();
  };
  Render2D.prototype.medir = function () {
    var r = this.canvas.getBoundingClientRect ? this.canvas.getBoundingClientRect() : { width: 300, height: 300 };
    this.w = Math.max(1, Math.round(r.width || 300));
    this.h = Math.max(1, Math.round(r.height || 300));
    this.dpr = Math.min(raiz.devicePixelRatio || 1, 1.5);
    this.canvas.width = Math.round(this.w * this.dpr);
    this.canvas.height = Math.round(this.h * this.dpr);
  };
  Render2D.prototype.destruir = function () {
    this.parar();
    try {
      raiz.removeEventListener('resize', this.aoRedimensionar, false);
      raiz.removeEventListener('orientationchange', this.aoRedimensionar, false);
      if (this.observadorTamanho) { this.observadorTamanho.disconnect(); this.observadorTamanho = null; }
    } catch (e) { /* sem listeners */ }
  };
  Render2D.prototype.iniciar = function () {
    if (this.rodando) return;
    this.desejado = true;
    this.rodando = true;
    this.ultimo = 0;
    var self = this, laco = function (t) {
      if (!self.rodando) return;
      self.raf = raiz.requestAnimationFrame(laco);
      self.quadro(t);
    };
    this.raf = raiz.requestAnimationFrame(laco);
  };
  Render2D.prototype.parar = function () {
    this.desejado = false; this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };
  Render2D.prototype.pausarVisivel = function () {
    this.rodando = false;
    if (this.raf) { raiz.cancelAnimationFrame(this.raf); this.raf = 0; }
  };
  Render2D.prototype.estado = function (n) { if (PALETAS[n]) { this.estadoAtual = n; this.paleta = PALETAS[n]; } };
  Render2D.prototype.nivel = function (v) { if (Number.isFinite(Number(v))) this.nivelAlvo = Math.max(0, Math.min(1, Number(v))); };
  Render2D.prototype.quadro = function (t) {
    var dt = this.ultimo ? Math.min(64, t - this.ultimo) : 16;
    this.ultimo = t;
    var passo = dt / 16.667;
    this.giro += (reduzido ? 0.001 : this.paleta.giro * 0.0024 + 0.0015) * passo;
    this.audioNivel += (this.nivelAlvo - this.audioNivel) * Math.min(1, passo * 0.14);
    var ctx = this.ctx, w = this.w, h = this.h;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    var cx = w / 2, cy = h / 2, raio = Math.min(w, h) * 0.2;
    var c = this.paleta;
    var prim = 'rgba(' + ((c.prim >> 16) & 255) + ',' + ((c.prim >> 8) & 255) + ',' + (c.prim & 255);
    var nucleo = 'rgba(' + ((c.nucleo >> 16) & 255) + ',' + ((c.nucleo >> 8) & 255) + ',' + (c.nucleo & 255);
    var halo = ctx.createRadialGradient(cx, cy, raio * 0.1, cx, cy, raio * 3);
    halo.addColorStop(0, prim + ',0.2)');
    halo.addColorStop(1, prim + ',0)');
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.arc(cx, cy, raio * 3, 0, Math.PI * 2); ctx.fill();
    var cyr = Math.cos(this.giro), syr = Math.sin(this.giro), cch = Math.cos(0.32), sch = Math.sin(0.32);
    for (var i = 0; i < this.pontos.length; i++) {
      var p = this.pontos[i];
      var x1 = p.x * cyr - p.z * syr, z1 = p.x * syr + p.z * cyr;
      var y1 = p.y * cch - z1 * sch, z2 = p.y * sch + z1 * cch;
      var esc = 3.4 / (3.4 - z2);
      var alpha = 0.12 + ((z2 + 1) / 2) * 0.55;
      ctx.fillStyle = nucleo + ',' + alpha.toFixed(2) + ')';
      var t2 = (1.1 + p.s * 1.5) * esc * 0.75;
      ctx.fillRect(cx + x1 * esc * raio * 1.6 - t2 / 2, cy + y1 * esc * raio * 1.6 - t2 / 2, t2, t2);
    }
    ctx.beginPath(); ctx.arc(cx, cy, raio * 0.36 * (1 + this.audioNivel * 0.2), 0, Math.PI * 2);
    ctx.fillStyle = prim + ',0.25)'; ctx.fill();
    ctx.beginPath(); ctx.arc(cx, cy, raio * 0.06, 0, Math.PI * 2);
    ctx.fillStyle = nucleo + ',0.95)'; ctx.fill();
  };

  /* ---------- Fachada ---------- */
  var atual = null;
  var canvasAtual = null;
  var pausadoPorTela = false;
  var observador = null;

  function criar(canvas) {
    if (raiz.THREE && suportaWebGL()) {
      try { return new Render3D(canvas); }
      catch (e) {
        try { if (raiz.console) raiz.console.warn('Núcleo órbita: WebGL falhou, usando Canvas 2D.', e && e.message); } catch (x) { /* sem console */ }
        // A tentativa pode ter deixado um contexto quebrado no canvas: um clone limpo
        // garante que o desenho 2D funcione em vez de ficar em branco.
        try {
          var limpo = canvas.cloneNode(false);
          if (canvas.parentNode) canvas.parentNode.replaceChild(limpo, canvas);
          canvas = limpo;
        } catch (x) { /* segue com o canvas original */ }
      }
    }
    return new Render2D(canvas);
  }

  function pausar() {
    if (!atual) return;
    if (atual.rodando) { pausadoPorTela = true; atual.pausarVisivel(); }
  }
  function retomar() {
    if (!atual || !pausadoPorTela || !atual.desejado) return;
    pausadoPorTela = false;
    atual.iniciar();
  }
  function aoVisibilidade() {
    if (raiz.document && raiz.document.hidden) pausar();
    else retomar();
  }
  if (raiz.document && raiz.document.addEventListener) {
    raiz.document.addEventListener('visibilitychange', aoVisibilidade, false);
  }

  var api = {
    iniciar: function (canvas) {
      if (!canvas) return null;
      if (atual && canvasAtual === canvas) { atual.iniciar(); return atual; }
      api.destruir();
      canvasAtual = canvas;
      try { atual = criar(canvas); } catch (e) { atual = null; }
      if (!atual) return null;
      // O fallback 2D pode trocar o canvas por um clone limpo: guarda o que está em uso.
      canvasAtual = atual.canvas || canvas;
      // Observa a visibilidade do canvas: fora da tela, nada de renderizar.
      try {
        if (typeof raiz.IntersectionObserver === 'function') {
          if (observador) observador.disconnect();
          observador = new raiz.IntersectionObserver(function (entradas) {
            var visivel = entradas.some(function (x) { return x.isIntersecting; });
            if (visivel) retomar(); else pausar();
          }, { threshold: 0.01 });
          observador.observe(canvas);
        }
      } catch (e) { /* observador opcional */ }
      atual.iniciar();
      // Rede de segurança: se o observador não acusar visibilidade (layout tardio ou
      // navegador embutido), anima depois de 1,5 s desde que o canvas tenha tamanho.
      try {
        if (api._vigia) raiz.clearTimeout(api._vigia);
        api._vigia = raiz.setTimeout(function () {
          if (!atual || atual.rodando || !atual.desejado) return;
          if (raiz.document && raiz.document.hidden) return;
          var c = atual.canvas || canvasAtual;
          var r = c && c.getBoundingClientRect ? c.getBoundingClientRect() : { width: 0, height: 0 };
          if (r.width > 1 && r.height > 1) { pausadoPorTela = false; atual.iniciar(); }
        }, 1500);
      } catch (e) { /* sem timers */ }
      return atual;
    },
    parar: function () { if (atual) atual.parar(); },
    destruir: function () {
      try { if (api._vigia) { raiz.clearTimeout(api._vigia); api._vigia = 0; } } catch (e) { /* sem timers */ }
      try { if (observador) { observador.disconnect(); observador = null; } } catch (e) { /* já desconectado */ }
      if (atual && atual.destruir) atual.destruir(); else if (atual) atual.parar();
      atual = null; canvasAtual = null; pausadoPorTela = false;
    },
    estado: function (nome) { if (atual && typeof atual.estado === 'function') atual.estado(nome); },
    nivel: function (v) {
      // Guarda de tipo: se uma instância parcial existir, o app continua funcionando e o
      // diagnóstico registra o problema em vez de estourar um TypeError a cada quadro.
      if (atual && typeof atual.nivel === 'function') atual.nivel(v);
    },
    ativo: function () { return !!(atual && atual.rodando); },
    tipo: function () { return !atual ? null : (atual.renderer ? 'webgl' : 'canvas2d'); },
    paletas: PALETAS,
    usaThree: function () { return !!(raiz.THREE && raiz.THREE.WebGLRenderer); },
    /** Diagnóstico curto para Ajustes ▸ Diagnóstico e para o registro de erros. */
    diagnostico: function () {
      if (!atual) return { tipo: null, rodando: false, motivo: 'núcleo órbita não iniciado' };
      return {
        tipo: atual.renderer ? 'webgl' : 'canvas2d',
        rodando: !!atual.rodando,
        fps: Math.round(atual.ultimoFps || 0),
        qualidadeBaixa: !!atual.qualidadeBaixa,
        contextoPerdido: !!atual.contextoPerdido,
        particulas: atual.totalParticulas || atual.pontos.length
      };
    }
  };

  raiz.NucleoOrbita = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
