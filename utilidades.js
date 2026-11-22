/* J.A.R.V.I.S. Nova — Central de Utilidades (1.43.0)
 * Núcleo puro, sem DOM e sem rede: cálculo, conversões, saúde, finanças e aleatoriedade.
 * Tudo aqui é determinístico (exceto senha/número aleatório) para poder ser testado no Node.
 */
(function (raiz) {
  'use strict';
  const U = {};

  function numero(v) {
    if (typeof v === 'number') return v;
    const s = String(v == null ? '' : v).trim().replace(/\s/g, '').replace(/\.(?=\d{3}\b)/g, '').replace(',', '.');
    const n = Number(s);
    return Number.isFinite(n) ? n : NaN;
  }
  U.numero = numero;

  function fmt(n, casas) {
    if (!Number.isFinite(n)) return '—';
    const c = casas == null ? 2 : casas;
    const arred = Math.round(n * Math.pow(10, c)) / Math.pow(10, c);
    return arred.toLocaleString('pt-BR', { maximumFractionDigits: c });
  }
  U.formatar = fmt;

  /* ---------- Calculadora com funções (sem eval) ---------- */
  const FUNCOES = {
    raiz: Math.sqrt, sqrt: Math.sqrt, abs: Math.abs, log: Math.log10, log10: Math.log10,
    ln: Math.log, exp: Math.exp, sen: Math.sin, sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asen: Math.asin, acos: Math.acos, atan: Math.atan, piso: Math.floor, floor: Math.floor,
    teto: Math.ceil, ceil: Math.ceil, arred: Math.round, round: Math.round, pot: Math.pow,
  };
  const CONSTANTES = { pi: Math.PI, e: Math.E, tau: Math.PI * 2 };

  function tokenizar(expr) {
    const s = String(expr || '').toLowerCase().replace(/,/g, '.')
      .replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/\^/g, '^');
    const tokens = [];
    let i = 0;
    while (i < s.length) {
      const c = s[i];
      if (/\s/.test(c)) { i++; continue; }
      if (/[0-9.]/.test(c)) {
        let j = i; while (j < s.length && /[0-9.]/.test(s[j])) j++;
        const bruto = s.slice(i, j);
        if ((bruto.match(/\./g) || []).length > 1) return null;
        tokens.push({ t: 'num', v: Number(bruto) });
        i = j; continue;
      }
      if (/[a-z]/.test(c)) {
        let j = i; while (j < s.length && /[a-z0-9_]/.test(s[j])) j++;
        tokens.push({ t: 'id', v: s.slice(i, j) });
        i = j; continue;
      }
      if ('+-*/%^!(),'.includes(c)) { tokens.push({ t: c }); i++; continue; }
      return null;
    }
    return tokens;
  }

  function avaliar(expr) {
    const tokens = tokenizar(expr);
    if (!tokens || !tokens.length) return null;
    let pos = 0;
    const ver = (t) => (pos < tokens.length && tokens[pos].t === t) ? (pos++, true) : false;

    function expressao() {
      let v = termo();
      while (pos < tokens.length && (tokens[pos].t === '+' || tokens[pos].t === '-')) {
        const op = tokens[pos++].t;
        const r = termo();
        v = op === '+' ? v + r : v - r;
      }
      return v;
    }
    function termo() {
      let v = unario();
      while (pos < tokens.length && ['*', '/', '%'].includes(tokens[pos].t)) {
        const op = tokens[pos++].t;
        const r = unario();
        if ((op === '/' || op === '%') && r === 0) return NaN;
        v = op === '*' ? v * r : op === '/' ? v / r : v % r;
      }
      return v;
    }
    function unario() {
      if (ver('-')) return -unario();
      if (ver('+')) return unario();
      return potencia();
    }
    function potencia() {
      const base = posfixo();
      if (ver('^')) return Math.pow(base, unario());
      return base;
    }
    function posfixo() {
      let v = primario();
      while (ver('!')) {
        if (!Number.isInteger(v) || v < 0 || v > 170) return NaN;
        let r = 1; for (let k = 2; k <= v; k++) r *= k;
        v = r;
      }
      return v;
    }
    function primario() {
      if (ver('(')) { const v = expressao(); if (!ver(')')) return NaN; return v; }
      if (pos >= tokens.length) return NaN;
      const tk = tokens[pos];
      if (tk.t === 'num') { pos++; return tk.v; }
      if (tk.t === 'id') {
        pos++;
        const nome = tk.v;
        if (Object.prototype.hasOwnProperty.call(CONSTANTES, nome)) return CONSTANTES[nome];
        if (FUNCOES[nome]) {
          if (!ver('(')) return NaN;
          const a = expressao();
          if (!ver(')')) return NaN;
          return FUNCOES[nome](a);
        }
        return NaN;
      }
      return NaN;
    }

    const r = expressao();
    if (pos !== tokens.length || !Number.isFinite(r)) return null;
    return Math.round(r * 1e10) / 1e10;
  }
  U.avaliar = avaliar;

  /* ---------- Matemática ---------- */
  U.fatorial = (n) => {
    n = Math.floor(numero(n));
    if (!Number.isFinite(n) || n < 0 || n > 170) return null;
    let r = 1; for (let k = 2; k <= n; k++) r *= k; return r;
  };
  U.fibonacci = (n) => {
    n = Math.floor(numero(n));
    if (!Number.isFinite(n) || n < 0 || n > 78) return null;
    let a = 0, b = 1;
    for (let k = 0; k < n; k++) { const t = a + b; a = b; b = t; }
    return a;
  };
  U.fatorar = (n) => {
    n = Math.floor(Math.abs(numero(n)));
    if (!Number.isFinite(n) || n < 2 || n > 1e12) return null;
    const fatores = [];
    let resto = n;
    for (let p = 2; p * p <= resto; p++) {
      while (resto % p === 0) { fatores.push(p); resto /= p; }
    }
    if (resto > 1) fatores.push(resto);
    return fatores;
  };
  U.primos = (limite) => {
    limite = Math.floor(numero(limite));
    if (!Number.isFinite(limite) || limite < 2 || limite > 100000) return null;
    const crivo = new Array(limite + 1).fill(true);
    crivo[0] = crivo[1] = false;
    for (let p = 2; p * p <= limite; p++) if (crivo[p]) for (let m = p * p; m <= limite; m += p) crivo[m] = false;
    return crivo.map((ok, i) => ok ? i : 0).filter(Boolean);
  };
  U.mdc = (a, b) => {
    a = Math.abs(Math.floor(numero(a))); b = Math.abs(Math.floor(numero(b)));
    if (!Number.isFinite(a) || !Number.isFinite(b)) return null;
    while (b) { const t = b; b = a % b; a = t; }
    return a;
  };
  U.mmc = (a, b) => {
    const d = U.mdc(a, b); if (!d) return null;
    return Math.abs(a * b) / d;
  };
  /** Equação do 2º grau ax²+bx+c=0. Retorna raízes reais ou complexas descritas. */
  U.equacao2 = (a, b, c) => {
    a = numero(a); b = numero(b); c = numero(c);
    if (![a, b, c].every(Number.isFinite)) return null;
    if (a === 0) {
      if (b === 0) return { tipo: 'sem-equacao', raizes: [] };
      return { tipo: 'linear', raizes: [-c / b], delta: null };
    }
    const delta = b * b - 4 * a * c;
    if (delta < 0) {
      const re = -b / (2 * a), im = Math.sqrt(-delta) / (2 * a);
      return { tipo: 'complexas', delta, raizes: [], complexas: [re + ' + ' + fmt(im) + 'i', re + ' - ' + fmt(im) + 'i'] };
    }
    const r1 = (-b + Math.sqrt(delta)) / (2 * a), r2 = (-b - Math.sqrt(delta)) / (2 * a);
    return { tipo: delta === 0 ? 'unica' : 'duas', delta, raizes: delta === 0 ? [r1] : [r1, r2] };
  };
  U.estatistica = (lista) => {
    const vs = (Array.isArray(lista) ? lista : String(lista || '').split(/[;,\s]+/)).map(numero).filter(Number.isFinite);
    if (!vs.length) return null;
    const soma = vs.reduce((a, b) => a + b, 0), media = soma / vs.length;
    const ord = [...vs].sort((a, b) => a - b);
    const meio = Math.floor(ord.length / 2);
    const mediana = ord.length % 2 ? ord[meio] : (ord[meio - 1] + ord[meio]) / 2;
    const variancia = vs.reduce((a, b) => a + (b - media) * (b - media), 0) / vs.length;
    return { n: vs.length, soma, media, mediana, min: ord[0], max: ord[ord.length - 1], desvio: Math.sqrt(variancia) };
  };
  U.porcentagem = (parte, total) => {
    parte = numero(parte); total = numero(total);
    if (!Number.isFinite(parte) || !Number.isFinite(total) || total === 0) return null;
    return { valor: parte * total / 100, proporcao: parte / total };
  };
  U.regraDeTres = (a, b, c) => {
    a = numero(a); b = numero(b); c = numero(c);
    if (![a, b, c].every(Number.isFinite) || a === 0) return null;
    return b * c / a;
  };
  /** Matrizes como arrays de arrays. */
  U.matriz = {
    somar: (A, B) => (A.length === B.length && A.every((l, i) => l.length === B[i].length))
      ? A.map((l, i) => l.map((v, j) => numero(v) + numero(B[i][j]))) : null,
    multiplicar: (A, B) => {
      if (!A.length || !B.length || A[0].length !== B.length) return null;
      return A.map((linha) => B[0].map((_, j) => linha.reduce((s, v, k) => s + numero(v) * numero(B[k][j]), 0)));
    },
    determinante: (M) => {
      const n = M.length;
      if (!n || M.some((l) => l.length !== n)) return null;
      if (n === 1) return numero(M[0][0]);
      if (n === 2) return numero(M[0][0]) * numero(M[1][1]) - numero(M[0][1]) * numero(M[1][0]);
      if (n === 3) {
        const m = M.map((l) => l.map(numero));
        return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
          - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
          + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
      }
      return null;
    },
    identidade: (n) => Array.from({ length: n }, (_, i) => Array.from({ length: n }, (_, j) => i === j ? 1 : 0)),
  };

  /* ---------- Bases numéricas ---------- */
  U.base = (valor, de, para) => {
    const mapa = { bin: 2, oct: 8, dec: 10, hex: 16 };
    const d = mapa[String(de || '').toLowerCase()], p = mapa[String(para || '').toLowerCase()];
    if (!d || !p) return null;
    const s = String(valor == null ? '' : valor).trim().replace(/^0[bxo]/i, '').replace(/\s/g, '');
    if (!s || !new RegExp('^[0-9a-f]+$', 'i').test(s)) return null;
    const n = parseInt(s, d);
    if (!Number.isFinite(n)) return null;
    return n.toString(p).toUpperCase();
  };

  /* ---------- Conversões de unidade ---------- */
  const CATEGORIAS = {
    comprimento: { base: 'm', unidades: { mm: 0.001, cm: 0.01, m: 1, km: 1000, pol: 0.0254, pe: 0.3048, jarda: 0.9144, milha: 1609.344, milhanautica: 1852 } },
    massa: { base: 'g', unidades: { mg: 0.001, g: 1, kg: 1000, t: 1e6, libra: 453.59237, onca: 28.349523125 } },
    volume: { base: 'l', unidades: { ml: 0.001, l: 1, m3: 1000, xicara: 0.24, colher: 0.015, galao: 3.785411784 } },
    velocidade: { base: 'm/s', unidades: { 'm/s': 1, 'km/h': 1 / 3.6, mph: 0.44704, no: 0.514444 } },
    tempo: { base: 's', unidades: { s: 1, seg: 1, min: 60, h: 3600, hora: 3600, dia: 86400, semana: 604800 } },
    dados: { base: 'b', unidades: { b: 1, kb: 1024, mb: 1048576, gb: 1073741824, tb: 1099511627776 } },
    area: { base: 'm2', unidades: { cm2: 1e-4, m2: 1, km2: 1e6, hectare: 1e4, alqueire: 24200 } },
  };
  U.categorias = () => Object.keys(CATEGORIAS);
  U.unidades = (categoria) => {
    const c = CATEGORIAS[categoria]; if (!c) return [];
    return Object.keys(c.unidades).concat(categoria === 'temperatura' ? ['c', 'f', 'k'] : []);
  };
  const ALIAS = {
    milimetro: 'mm', centimetros: 'cm', centimetro: 'cm', metro: 'm', metros: 'm', quilometro: 'km', quilometros: 'km',
    polegada: 'pol', polegadas: 'pol', pes: 'pe', jardas: 'jarda', milhas: 'milha', 'milhas nauticas': 'milhanautica',
    grama: 'g', gramas: 'g', quilo: 'kg', quilos: 'kg', quilograma: 'kg', quilogramas: 'kg', tonelada: 't', toneladas: 't',
    libras: 'libra', oncas: 'onca', litro: 'l', litros: 'l', mililitro: 'ml', mililitros: 'ml', xicaras: 'xicara',
    colheres: 'colher', galoes: 'galao', hora: 'h', horas: 'h', horas_: 'h', minutos: 'min', segundos: 's',
    dias: 'dia', semanas: 'semana', quilometrosporhora: 'km/h', metrosporsegundo: 'm/s', nos: 'no',
    megabyte: 'mb', gigabytes: 'gb', metrosquadrados: 'm2', hectares: 'hectare',
  };
  function canonico(u) {
    let k = String(u || '').toLowerCase().trim().replace(/°/g, '').replace(/\s+/g, ' ');
    k = k.replace(/²/g, '2');
    if (ALIAS[k]) return ALIAS[k];
    return k.replace(/\s+/g, '');
  }
  U.converter = (valor, de, para) => {
    const v = numero(valor);
    if (!Number.isFinite(v)) return null;
    let a = canonico(de), b = canonico(para);
    if (/^(c|f|k|celsius|fahrenheit|kelvin)$/.test(a) && /^(c|f|k|celsius|fahrenheit|kelvin)$/.test(b)) {
      const norm = (x) => x[0] === 'c' ? 'c' : x[0] === 'f' ? 'f' : 'k';
      a = norm(a); b = norm(b);
      let c = a === 'c' ? v : a === 'f' ? (v - 32) * 5 / 9 : v - 273.15;
      const r = b === 'c' ? c : b === 'f' ? c * 9 / 5 + 32 : c + 273.15;
      return { valor: r, categoria: 'temperatura', de: a, para: b };
    }
    for (const [cat, def] of Object.entries(CATEGORIAS)) {
      if (def.unidades[a] != null && def.unidades[b] != null) {
        return { valor: v * def.unidades[a] / def.unidades[b], categoria: cat, de: a, para: b };
      }
    }
    return null;
  };

  /* ---------- Saúde ---------- */
  U.imc = (pesoKg, altura) => {
    let p = numero(pesoKg), h = numero(altura);
    if (!Number.isFinite(p) || !Number.isFinite(h) || p <= 0 || h <= 0) return null;
    if (h > 3) h = h / 100;
    const valor = p / (h * h);
    const classe = valor < 18.5 ? 'abaixo do peso' : valor < 25 ? 'peso normal'
      : valor < 30 ? 'sobrepeso' : valor < 35 ? 'obesidade grau I'
        : valor < 40 ? 'obesidade grau II' : 'obesidade grau III';
    return { valor, classe, pesoIdeal: { min: 18.5 * h * h, max: 24.9 * h * h } };
  };
  U.taxaMetabolica = (sexo, pesoKg, alturaCm, idade) => {
    const p = numero(pesoKg), a = numero(alturaCm), i = numero(idade);
    if (![p, a, i].every(Number.isFinite) || p <= 0 || a <= 0 || i <= 0) return null;
    const fem = /^f/i.test(String(sexo || ''));
    const bmr = 10 * p + 6.25 * a - 5 * i + (fem ? -161 : 5);
    return {
      bmr,
      fatores: { sedentario: 1.2, leve: 1.375, moderado: 1.55, intenso: 1.725, atleta: 1.9 },
      aguaMl: Math.round(p * 35),
    };
  };
  U.calorias = (bmr, fator) => {
    const b = numero(bmr), f = numero(fator);
    if (!Number.isFinite(b) || !Number.isFinite(f) || f <= 0) return null;
    return { manutencao: b * f, perder: b * f - 500, ganhar: b * f + 300 };
  };

  /* ---------- Finanças ---------- */
  U.jurosSimples = (capital, taxaPercentual, periodos) => {
    const c = numero(capital), t = numero(taxaPercentual), n = numero(periodos);
    if (![c, t, n].every(Number.isFinite)) return null;
    const juros = c * (t / 100) * n;
    return { juros, montante: c + juros };
  };
  U.jurosCompostos = (capital, taxaPercentual, periodos) => {
    const c = numero(capital), t = numero(taxaPercentual), n = numero(periodos);
    if (![c, t, n].every(Number.isFinite)) return null;
    const montante = c * Math.pow(1 + t / 100, n);
    return { montante, juros: montante - c };
  };
  U.parcelaPrice = (capital, taxaPercentual, parcelas) => {
    const c = numero(capital), t = numero(taxaPercentual) / 100, n = Math.floor(numero(parcelas));
    if (![c, t, n].every(Number.isFinite) || c <= 0 || n <= 0) return null;
    const parcela = t === 0 ? c / n : c * t / (1 - Math.pow(1 + t, -n));
    return { parcela, total: parcela * n, juros: parcela * n - c };
  };
  U.roi = (ganho, custo) => {
    const g = numero(ganho), c = numero(custo);
    if (!Number.isFinite(g) || !Number.isFinite(c) || c === 0) return null;
    return { percentual: (g - c) / c * 100, lucro: g - c };
  };
  U.moeda = (valor, de, para, taxas) => {
    const v = numero(valor), a = String(de || '').toUpperCase(), b = String(para || '').toUpperCase();
    if (!Number.isFinite(v) || !taxas || !taxas[a] || !taxas[b]) return null;
    return { valor: v * taxas[a] / taxas[b], taxa: taxas[a] / taxas[b], de: a, para: b };
  };

  /* ---------- Aleatoriedade segura ---------- */
  function inteiro(max) {
    try {
      if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
        const a = new Uint32Array(1); crypto.getRandomValues(a);
        return a[0] % max;
      }
    } catch (e) { /* ambiente sem crypto: usa Math.random */ }
    return Math.floor(Math.random() * max);
  }
  U.inteiro = inteiro;
  U.numeroAleatorio = (min, max) => {
    let a = Math.ceil(numero(min)), b = Math.floor(numero(max));
    if (!Number.isFinite(a) || !Number.isFinite(b)) return null;
    if (a > b) { const t = a; a = b; b = t; }
    return a + inteiro(b - a + 1);
  };
  U.embaralhar = (lista) => {
    const a = Array.isArray(lista) ? [...lista] : String(lista || '').split(',').map((s) => s.trim()).filter(Boolean);
    for (let i = a.length - 1; i > 0; i--) { const j = inteiro(i + 1); const t = a[i]; a[i] = a[j]; a[j] = t; }
    return a;
  };
  U.senha = (tamanho, opcoes) => {
    const n = Math.max(4, Math.min(128, Math.floor(numero(tamanho) || 16)));
    const o = Object.assign({ maiusculas: true, minusculas: true, numeros: true, simbolos: true }, opcoes || {});
    const grupos = [];
    if (o.minusculas) grupos.push('abcdefghijkmnopqrstuvwxyz');
    if (o.maiusculas) grupos.push('ABCDEFGHJKLMNPQRSTUVWXYZ');
    if (o.numeros) grupos.push('23456789');
    if (o.simbolos) grupos.push('!@#$%&*?+-=_');
    if (!grupos.length) return null;
    const todos = grupos.join('');
    const chars = grupos.map((g) => g[inteiro(g.length)]);
    while (chars.length < n) chars.push(todos[inteiro(todos.length)]);
    return U.embaralhar(chars).join('');
  };
  U.forcaSenha = (senha) => {
    const s = String(senha || '');
    let pontos = 0;
    if (s.length >= 8) pontos++;
    if (s.length >= 12) pontos++;
    if (s.length >= 16) pontos++;
    if (/[a-z]/.test(s) && /[A-Z]/.test(s)) pontos++;
    if (/\d/.test(s)) pontos++;
    if (/[^\w\s]/.test(s)) pontos++;
    return { pontos, nivel: pontos <= 2 ? 'fraca' : pontos <= 4 ? 'média' : 'forte' };
  };

  /* ---------- Interpretação de comandos cotidianos ---------- */
  function limpar(t) { return String(t || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase(); }
  U.interpretar = (texto) => {
    const t = limpar(texto).replace(/\s+/g, ' ').trim();
    if (!t) return null;

    let m = /^(?:quanto (?:e|sao|da|fica)|calcule|calcula|resultado de|quanto seria)\s+(.+)$/.exec(t);
    if (m) {
      const r = avaliar(m[1]);
      if (r !== null) return { tipo: 'calculo', valor: r, texto: 'Deu ' + fmt(r, 6) + '.' };
      const p = /([\d.,]+)\s*%\s*(?:de|do|da)\s*([\d.,]+)/.exec(m[1]);
      if (p) {
        const conta = U.porcentagem(p[1], p[2]);
        if (conta) return { tipo: 'porcentagem', valor: conta.valor, texto: fmt(p[1]) + '% de ' + fmt(p[2]) + ' é ' + fmt(conta.valor) + '.' };
      }
    }
    m = /([\d.,]+)\s*%\s*(?:de|do|da)\s*([\d.,]+)/.exec(t);
    if (m && /%.*(de|do|da)/.test(t)) {
      const conta = U.porcentagem(m[1], m[2]);
      if (conta) return { tipo: 'porcentagem', valor: conta.valor, texto: fmt(m[1]) + '% de ' + fmt(m[2]) + ' é ' + fmt(conta.valor) + '.' };
    }
    m = /(?:converter?|transformar?|quanto (?:e|sao))\s+([\d.,]+)\s*(?:°\s*)?([a-z\/² ]+?)\s+(?:para|em|pra)\s+(?:°\s*)?([a-z\/² ]+?)\s*$/.exec(t);
    if (m) {
      const r = U.converter(m[1], m[2], m[3]);
      if (r) return { tipo: 'conversao', valor: r.valor, texto: fmt(m[1], 4) + ' ' + r.de + ' = ' + fmt(r.valor, 4) + ' ' + r.para + '.' };
      return { tipo: 'conversao-invalida', texto: 'Não conheço essa conversão de ' + m[2].trim() + ' para ' + m[3].trim() + '.' };
    }
    m = /^imc\s+([\d.,]+)\s*(?:kg)?\s*(?:com|e|,)?\s*([\d.,]+)\s*(m|cm)?$/.exec(t);
    if (m) {
      const r = U.imc(m[1], m[2]);
      if (r) return { tipo: 'imc', valor: r.valor, texto: 'Seu IMC é ' + fmt(r.valor, 1) + ' (' + r.classe + '). Faixa saudável para essa altura: ' + fmt(r.pesoIdeal.min, 1) + ' a ' + fmt(r.pesoIdeal.max, 1) + ' kg.' };
    }
    m = /juros compostos (?:de )?([\d.,]+)\s*(?:reais|r\$)?\s*(?:a|com)\s*([\d.,]+)\s*%\s*(?:ao|por|no)?\s*(?:mes|mês|meses)?\s*(?:por|durante|em)?\s*(\d+)/.exec(t);
    if (m) {
      const r = U.jurosCompostos(m[1], m[2], m[3]);
      if (r) return { tipo: 'juros', valor: r.montante, texto: 'Montante: R$ ' + fmt(r.montante) + ' (juros de R$ ' + fmt(r.juros) + ').' };
    }
    m = /senha (?:de |com )?(\d+)(?:\s*(?:caracteres|digitos|dígitos))?/.exec(t);
    if (m) {
      const s = U.senha(m[1]);
      if (s) return { tipo: 'senha', valor: s, texto: 'Senha gerada: ' + s };
    }
    m = /(?:numero|número) aleatorio(?: entre (\d+) e (\d+))?/.exec(t);
    if (m) {
      const n = U.numeroAleatorio(m[1] || 1, m[2] || 100);
      return { tipo: 'aleatorio', valor: n, texto: 'Número sorteado: ' + n + '.' };
    }
    m = /(?:fatorial de|fatorial do) (\d+)/.exec(t);
    if (m) {
      const r = U.fatorial(m[1]);
      if (r != null) return { tipo: 'fatorial', valor: r, texto: m[1] + '! = ' + fmt(r, 0) + '.' };
    }
    m = /^(?:raiz quadrada de|raiz de) ([\d.,]+)/.exec(t);
    if (m) {
      const v = numero(m[1]);
      if (v >= 0) return { tipo: 'raiz', valor: Math.sqrt(v), texto: 'A raiz quadrada de ' + fmt(v) + ' é ' + fmt(Math.sqrt(v), 4) + '.' };
    }
    return null;
  };

  raiz.UtilidadesJarvis = U;
  if (typeof module !== 'undefined' && module.exports) module.exports = U;
})(typeof window !== 'undefined' ? window : globalThis);
