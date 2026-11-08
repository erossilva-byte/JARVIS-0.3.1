/* J.A.R.V.I.S. Nova — Núcleo Operacional (JarvisOS).
 *
 * Este arquivo não toca no DOM. Ele reúne o que os agentes precisam para trabalhar
 * de forma auditável: catálogo de ferramentas, níveis de permissão, confirmação
 * independente do modelo, evento/trace de cada chamada, checkpoint de tarefas e
 * ferramentas locais que não dependem de nuvem.
 *
 * Regra de ouro: uma ferramenta só é "ok" quando a própria função devolve um
 * resultado concreto. O núcleo nunca inventa sucesso, nunca executa ferramenta de
 * escrita/execução sem confirmação e nunca grava valores de argumentos nos traces.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisSistema = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const VERSAO = '1.0.0';
  const NIVEIS = ['leitura', 'escrita', 'execucao'];
  const LIMITE_TRACES = 120;
  const LIMITE_TAREFAS = 30;
  const LIMITE_TEXTO = 12000;
  const agora = () => Date.now();
  const iso = (ms) => new Date(Number.isFinite(Number(ms)) ? Number(ms) : Date.now()).toISOString();
  const semAcento = (t) => String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const norm = (t) => semAcento(t).toLowerCase().replace(/[^a-z0-9: ]+/g, ' ').replace(/\s+/g, ' ').trim();
  const limitar = (t, n) => String(t == null ? '' : t).replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '').slice(0, n);
  const clone = (x) => { try { return JSON.parse(JSON.stringify(x)); } catch (e) { return null; } };
  function uid(prefixo) {
    const p = prefixo || 'id';
    try {
      if (globalThis.crypto && typeof globalThis.crypto.randomUUID === 'function') return p + '_' + globalThis.crypto.randomUUID();
    } catch (e) { /* usa fallback */ }
    return p + '_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
  }
  function numero(v, padrao) {
    if (typeof v === 'number' && Number.isFinite(v)) return v;
    const s = String(v == null ? '' : v).replace(/\s/g, '').replace(',', '.');
    const n = Number(s);
    return Number.isFinite(n) ? n : padrao;
  }
  function formatarNumero(n) {
    try { return new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 8 }).format(n); }
    catch (e) { return String(n); }
  }

  /* ---------- Armazenamento tolerante ---------- */
  function adaptarArmazenamento(base) {
    if (base && typeof base.ler === 'function' && typeof base.gravar === 'function') return base;
    if (base && typeof base.get === 'function' && typeof base.set === 'function') {
      return {
        ler: (k) => { try { return base.get(k, ''); } catch (e) { return ''; } },
        gravar: (k, v) => { try { base.set(k, v); return true; } catch (e) { return false; } }
      };
    }
    if (base && typeof base.getItem === 'function' && typeof base.setItem === 'function') {
      return {
        ler: (k) => { try { return base.getItem(k) || ''; } catch (e) { return ''; } },
        gravar: (k, v) => { try { base.setItem(k, v); return true; } catch (e) { return false; } }
      };
    }
    const mem = Object.create(null);
    return {
      ler: (k) => mem[k] || '',
      gravar: (k, v) => { mem[k] = String(v); return true; }
    };
  }

  /* ---------- Expressões matemáticas seguras ---------- */
  function tokenizar(expr) {
    const s = String(expr || '').replace(/[×xX]/g, '*').replace(/[÷]/g, '/').replace(/π/g, 'pi').replace(/√/g, 'sqrt');
    const out = [];
    let i = 0;
    while (i < s.length) {
      const c = s[i];
      if (/\s/.test(c)) { i++; continue; }
      if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(s[i + 1] || ''))) {
        let bruto = '';
        while (i < s.length && /[0-9.,]/.test(s[i])) bruto += s[i++];
        // Aceita 1.234,56 (pt-BR) e 1,234.56 (en-US); heurística simples e previsível.
        if (bruto.indexOf(',') >= 0 && bruto.indexOf('.') >= 0) {
          if (bruto.lastIndexOf(',') > bruto.lastIndexOf('.')) bruto = bruto.replace(/\./g, '').replace(',', '.');
          else bruto = bruto.replace(/,/g, '');
        } else if (bruto.indexOf(',') >= 0) bruto = bruto.replace(',', '.');
        const n = Number(bruto);
        if (!Number.isFinite(n)) throw new Error('Número inválido: ' + bruto);
        out.push({ t: 'num', v: n });
        continue;
      }
      if (/[a-zA-Z_]/.test(c)) {
        let nome = '';
        while (i < s.length && /[a-zA-Z_]/.test(s[i])) nome += s[i++];
        out.push({ t: 'id', v: nome.toLowerCase() });
        continue;
      }
      if ('+-*/^%(),'.indexOf(c) >= 0) { out.push({ t: c }); i++; continue; }
      throw new Error('Caractere não permitido: ' + c);
    }
    if (out.length > 220) throw new Error('Expressão grande demais.');
    return out;
  }

  function avaliarExpressao(expressao) {
    let s = limitar(expressao, 320).trim();
    if (!s) throw new Error('Expressão vazia.');
    // "20% de 300" é uma pergunta comum em português e não uma operação de módulo.
    s = s.replace(/(\d+(?:[.,]\d+)?)\s*%\s*(?:de|do|da)\s*/gi, '($1/100)*');
    const tk = tokenizar(s);
    let pos = 0;
    const olhar = () => tk[pos];
    const comer = (tipo) => (tk[pos] && tk[pos].t === tipo ? tk[pos++] : null);
    const funcoes = {
      sqrt: Math.sqrt, raiz: Math.sqrt, abs: Math.abs, sin: Math.sin, sen: Math.sin,
      cos: Math.cos, tan: Math.tan, log: Math.log10, ln: Math.log, exp: Math.exp,
      floor: Math.floor, ceil: Math.ceil, round: Math.round
    };
    function primario() {
      const a = olhar();
      if (!a) throw new Error('Expressão incompleta.');
      if (a.t === 'num') { pos++; return a.v; }
      if (a.t === 'id') {
        pos++;
        if (a.v === 'pi') return Math.PI;
        if (a.v === 'e') return Math.E;
        const f = funcoes[a.v];
        if (!f) throw new Error('Função não permitida: ' + a.v);
        if (!comer('(')) throw new Error('Falta abrir parêntese depois de ' + a.v);
        const v = soma();
        if (!comer(')')) throw new Error('Falta fechar parêntese.');
        return f(v);
      }
      if (a.t === '(') { pos++; const v = soma(); if (!comer(')')) throw new Error('Falta fechar parêntese.'); return v; }
      if (a.t === '-') { pos++; return -primario(); }
      if (a.t === '+') { pos++; return primario(); }
      throw new Error('Token inesperado.');
    }
    function potencia() {
      let base = primario();
      if (comer('^')) base = Math.pow(base, potencia());
      return base;
    }
    function produto() {
      let v = potencia();
      for (;;) {
        if (comer('*')) v *= potencia();
        else if (comer('/')) { const d = potencia(); if (d === 0) throw new Error('Divisão por zero.'); v /= d; }
        else if (comer('%')) { const d = potencia(); if (d === 0) throw new Error('Módulo por zero.'); v %= d; }
        else return v;
      }
    }
    function soma() {
      let v = produto();
      for (;;) {
        if (comer('+')) v += produto();
        else if (comer('-')) v -= produto();
        else return v;
      }
    }
    const valor = soma();
    if (pos !== tk.length) throw new Error('Sobrou parte da expressão.');
    if (!Number.isFinite(valor)) throw new Error('O resultado não é um número finito.');
    if (Math.abs(valor) > 1e15) throw new Error('Resultado grande demais.');
    return valor;
  }

  /* ---------- Unidades ---------- */
  const UNIDADES = {
    mm: { tipo: 'comprimento', f: 0.001, nome: 'milímetros' }, cm: { tipo: 'comprimento', f: 0.01, nome: 'centímetros' },
    m: { tipo: 'comprimento', f: 1, nome: 'metros' }, km: { tipo: 'comprimento', f: 1000, nome: 'quilômetros' },
    in: { tipo: 'comprimento', f: 0.0254, nome: 'polegadas' }, ft: { tipo: 'comprimento', f: 0.3048, nome: 'pés' },
    yd: { tipo: 'comprimento', f: 0.9144, nome: 'jardas' }, mi: { tipo: 'comprimento', f: 1609.344, nome: 'milhas' },
    g: { tipo: 'massa', f: 0.001, nome: 'gramas' }, kg: { tipo: 'massa', f: 1, nome: 'quilos' },
    t: { tipo: 'massa', f: 1000, nome: 'toneladas' }, lb: { tipo: 'massa', f: 0.45359237, nome: 'libras' },
    oz: { tipo: 'massa', f: 0.028349523125, nome: 'onças' },
    ml: { tipo: 'volume', f: 0.001, nome: 'mililitros' }, l: { tipo: 'volume', f: 1, nome: 'litros' },
    gal: { tipo: 'volume', f: 3.785411784, nome: 'galões' },
    s: { tipo: 'tempo', f: 1, nome: 'segundos' }, min: { tipo: 'tempo', f: 60, nome: 'minutos' },
    h: { tipo: 'tempo', f: 3600, nome: 'horas' }, d: { tipo: 'tempo', f: 86400, nome: 'dias' },
    c: { tipo: 'temperatura', nome: 'graus Celsius' }, f: { tipo: 'temperatura', nome: 'graus Fahrenheit' },
    k: { tipo: 'temperatura', nome: 'Kelvin' },
    b: { tipo: 'dados', f: 1, nome: 'bytes' }, kb: { tipo: 'dados', f: 1024, nome: 'kibibytes' },
    mb: { tipo: 'dados', f: 1048576, nome: 'mebibytes' }, gb: { tipo: 'dados', f: 1073741824, nome: 'gibibytes' },
    tb: { tipo: 'dados', f: 1099511627776, nome: 'tebibytes' },
    kmh: { tipo: 'velocidade', f: 1, nome: 'km/h' }, ms: { tipo: 'velocidade', f: 3.6, nome: 'm/s' },
    mph: { tipo: 'velocidade', f: 1.609344, nome: 'mph' }
  };
  const ALIASES = {
    milimetro: 'mm', milimetros: 'mm', centimetro: 'cm', centimetros: 'cm', metro: 'm', metros: 'm',
    quilometro: 'km', quilometros: 'km', polegada: 'in', polegadas: 'in', pe: 'ft', pes: 'ft',
    jarda: 'yd', jardas: 'yd', milha: 'mi', milhas: 'mi', grama: 'g', gramas: 'g', quilo: 'kg',
    quilos: 'kg', quilograma: 'kg', quilogramas: 'kg', tonelada: 't', toneladas: 't', libra: 'lb',
    libras: 'lb', onca: 'oz', onças: 'oz', oncas: 'oz', mililitro: 'ml', mililitros: 'ml',
    litro: 'l', litros: 'l', galao: 'gal', galoes: 'gal', segundo: 's', segundos: 's',
    minuto: 'min', minutos: 'min', hora: 'h', horas: 'h', dia: 'd', dias: 'd', byte: 'b',
    bytes: 'b', kilobyte: 'kb', kilobytes: 'kb', megabyte: 'mb', megabytes: 'mb',
    gigabyte: 'gb', gigabytes: 'gb', terabyte: 'tb', terabytes: 'tb', celsius: 'c',
    fahrenheit: 'f', kelvin: 'k', 'km h': 'kmh', 'km/h': 'kmh', 'm s': 'ms', 'm/s': 'ms', mph: 'mph'
  };
  function unidade(u) {
    const k = norm(u).replace(/graus?/g, '').trim();
    return ALIASES[k] || (UNIDADES[k] ? k : '');
  }
  function converter(args) {
    const valor = numero(args && args.valor, NaN);
    const de = unidade(args && args.de), para = unidade(args && args.para);
    if (!Number.isFinite(valor)) throw new Error('Informe o valor numérico.');
    if (!de || !para) throw new Error('Unidade não reconhecida. Use, por exemplo, km, milhas, kg, libras, litros, GB, Celsius.');
    const temp = (u) => ['c', 'f', 'k'].indexOf(u) >= 0;
    if (temp(de) !== temp(para)) throw new Error('Temperatura só converte entre Celsius, Fahrenheit e Kelvin.');
    let r;
    if (temp(de)) {
      const c = de === 'c' ? valor : de === 'f' ? (valor - 32) * 5 / 9 : valor - 273.15;
      r = para === 'c' ? c : para === 'f' ? c * 9 / 5 + 32 : c + 273.15;
    } else {
      if (UNIDADES[de].tipo !== UNIDADES[para].tipo) throw new Error('As unidades são de grandezas diferentes.');
      r = valor * UNIDADES[de].f / UNIDADES[para].f;
    }
    return { valor: r, de, para, fala: formatarNumero(valor) + ' ' + (UNIDADES[de] ? UNIDADES[de].nome : de) + ' equivalem a ' + formatarNumero(r) + ' ' + (UNIDADES[para] ? UNIDADES[para].nome : para) + '.' };
  }

  /* ---------- Ferramentas locais ---------- */
  /** Sorteio uniforme com rejeição: `% 256` sozinho favorece os primeiros itens. */
  function inteiroSeguro(max) {
    const c = globalThis.crypto;
    if (!c || typeof c.getRandomValues !== 'function') throw new Error('Este ambiente não oferece gerador criptográfico seguro.');
    if (!Number.isInteger(max) || max < 1 || max > 256) throw new Error('Faixa de sorteio inválida.');
    const limite = Math.floor(256 / max) * max;
    const b = new Uint8Array(1);
    do { c.getRandomValues(b); } while (b[0] >= limite);
    return b[0] % max;
  }
  function gerarSenha(args) {
    const tamanho = Math.max(8, Math.min(128, Math.round(numero(args && args.tamanho, 20))));
    const simbolos = !(args && args.simbolos === false);
    const minus = 'abcdefghijkmnopqrstuvwxyz', mais = 'ABCDEFGHJKLMNPQRSTUVWXYZ', nums = '23456789';
    const sim = '!@#$%&*+-=?';
    const grupos = [minus, mais, nums].concat(simbolos ? [sim] : []);
    const todos = grupos.join('');
    const letras = [];
    for (let i = 0; i < grupos.length; i++) letras.push(grupos[i][inteiroSeguro(grupos[i].length)]);
    for (let i = grupos.length; i < tamanho; i++) letras.push(todos[inteiroSeguro(todos.length)]);
    for (let i = letras.length - 1; i > 0; i--) {
      const j = inteiroSeguro(i + 1);
      const t = letras[i]; letras[i] = letras[j]; letras[j] = t;
    }
    return { senha: letras.join(''), tamanho, simbolos, fala: 'Gerei uma senha de ' + tamanho + ' caracteres. Ela não foi salva nem enviada a nenhum serviço.' };
  }

  function estatisticasTexto(args) {
    const texto = limitar(args && args.texto, LIMITE_TEXTO);
    if (!texto.trim()) throw new Error('O texto está vazio.');
    const palavras = (texto.match(/[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*/gu) || []).length;
    const linhas = texto.split(/\r?\n/).length;
    const minutos = Math.max(0.1, palavras / 200);
    return { caracteres: texto.length, palavras, linhas, minutos: Math.round(minutos * 10) / 10, fala: 'O texto tem ' + texto.length + ' caracteres, ' + palavras + ' palavras e ' + linhas + (linhas === 1 ? ' linha' : ' linhas') + '. Leitura estimada: ' + Math.max(1, Math.ceil(minutos)) + ' minuto(s).' };
  }

  function formatarJson(args) {
    const texto = limitar(args && args.texto, LIMITE_TEXTO);
    try {
      const obj = JSON.parse(texto);
      const espacos = Math.max(0, Math.min(8, Math.round(numero(args && args.espacos, 2))));
      return { texto: JSON.stringify(obj, null, espacos), fala: 'JSON válido e formatado.' };
    } catch (e) {
      throw new Error('JSON inválido: ' + String(e && e.message || e).slice(0, 180));
    }
  }

  async function hashTexto(args) {
    const texto = limitar(args && args.texto, LIMITE_TEXTO);
    if (!globalThis.crypto || !globalThis.crypto.subtle || typeof TextEncoder !== 'function') throw new Error('SHA-256 indisponível neste ambiente.');
    const buf = await globalThis.crypto.subtle.digest('SHA-256', new TextEncoder().encode(texto));
    const hex = Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
    return { sha256: hex, bytes: new TextEncoder().encode(texto).length, fala: 'SHA-256: ' + hex + '.' };
  }

  function calcularData(args) {
    const dias = Math.max(-36500, Math.min(36500, Math.round(numero(args && args.dias, 0))));
    const base = args && args.data ? new Date(String(args.data)) : new Date();
    if (!Number.isFinite(base.getTime())) throw new Error('Data base inválida. Use AAAA-MM-DD.');
    const d = new Date(base.getTime() + dias * 86400000);
    return { iso: d.toISOString(), data: d.toLocaleDateString('pt-BR'), fala: (dias >= 0 ? 'Daqui a ' : 'Há ') + Math.abs(dias) + ' dia(s): ' + d.toLocaleDateString('pt-BR') + '.' };
  }

  function criarNucleo(opcoes) {
    const o = opcoes || {};
    const arm = adaptarArmazenamento(o.armazenamento);
    const confirmar = typeof o.confirmar === 'function' ? o.confirmar : async () => false;
    const observar = typeof o.registrar === 'function' ? o.registrar : null;
    const timeoutPadrao = Math.max(1000, Math.min(60000, numero(o.timeoutMs, 15000)));
    const ferramentas = new Map();
    const agentes = new Map();
    const ouvintes = Object.create(null);
    const emExecucao = new Set();
    const pausasSolicitadas = new Set();
    let traces = carregar('sistema:traces', []);
    let tarefas = carregar('sistema:tarefas', []);
    if (!Array.isArray(traces)) traces = [];
    if (!Array.isArray(tarefas)) tarefas = [];
    traces = traces.slice(-LIMITE_TRACES);
    tarefas = tarefas.slice(-LIMITE_TAREFAS);

    function carregar(k, padrao) {
      try { const bruto = arm.ler(k); return bruto ? JSON.parse(bruto) : clone(padrao); }
      catch (e) { return clone(padrao); }
    }
    function salvar(k, v) { try { arm.gravar(k, JSON.stringify(v)); return true; } catch (e) { return false; } }
    function emitir(ev, dados) {
      const lista = ouvintes[ev] || [];
      lista.slice().forEach((fn) => { try { fn(dados); } catch (e) { /* um ouvinte não derruba o núcleo */ } });
    }
    function ao(ev, fn) {
      if (typeof ev !== 'string' || typeof fn !== 'function') return () => false;
      (ouvintes[ev] || (ouvintes[ev] = [])).push(fn);
      return () => { const l = ouvintes[ev] || []; const i = l.indexOf(fn); if (i >= 0) l.splice(i, 1); };
    }
    function persistirTraces() { traces = traces.slice(-LIMITE_TRACES); salvar('sistema:traces', traces); }
    function traco(evento, dados) {
      const item = Object.assign({ id: uid('tr'), em: iso(), evento }, dados || {});
      traces.push(item); persistirTraces(); emitir('trace', item);
      if (observar) { try { observar('sistema', evento + (item.ferramenta ? ': ' + item.ferramenta : '') + ' · ' + (item.ok === false ? 'falhou' : 'ok')); } catch (e) { /* registro externo opcional */ } }
      return item;
    }
    function persistirTarefas() { tarefas = tarefas.slice(-LIMITE_TAREFAS); salvar('sistema:tarefas', tarefas); }
    function publicaFerramenta(d) {
      return { id: d.id, nome: d.nome, descricao: d.descricao, dominio: d.dominio || 'geral', nivel: d.nivel || 'leitura', risco: Number(d.risco) || 0, argumentos: clone(d.argumentos || {}) || {} };
    }
    function registrarFerramenta(def) {
      if (!def || typeof def !== 'object') throw new Error('Definição de ferramenta inválida.');
      const id = String(def.id || '').trim();
      if (!/^[a-z][a-z0-9_]{1,39}$/.test(id)) throw new Error('id de ferramenta inválido: ' + id);
      if (ferramentas.has(id)) throw new Error('Ferramenta duplicada: ' + id);
      if (typeof def.executar !== 'function') throw new Error('Ferramenta sem função executar: ' + id);
      if (NIVEIS.indexOf(def.nivel || 'leitura') < 0) throw new Error('Nível inválido: ' + def.nivel);
      const risco = Math.max(0, Math.min(3, Math.round(numero(def.risco, 0))));
      const d = Object.assign({}, def, { id, nivel: def.nivel || 'leitura', risco, nome: limitar(def.nome || id, 80), descricao: limitar(def.descricao || '', 240), dominio: limitar(def.dominio || 'geral', 40) });
      ferramentas.set(id, d);
      emitir('ferramenta:registrada', publicaFerramenta(d));
      return publicaFerramenta(d);
    }
    function registrarAgente(def) {
      if (!def || typeof def !== 'object') throw new Error('Definição de agente inválida.');
      const id = String(def.id || '').trim();
      if (!/^[a-z][a-z0-9_]{1,39}$/.test(id)) throw new Error('id de agente inválido: ' + id);
      if (agentes.has(id)) throw new Error('Agente duplicado: ' + id);
      const lista = Array.isArray(def.ferramentas) ? def.ferramentas.map(String).slice(0, 40) : [];
      const d = { id, nome: limitar(def.nome || id, 80), dominio: limitar(def.dominio || 'geral', 40), descricao: limitar(def.descricao || '', 240), ferramentas: lista };
      agentes.set(id, d); emitir('agente:registrado', d); return clone(d);
    }
    function descobrir(fonte) {
      let n = 0;
      const itens = Array.isArray(fonte) ? fonte : (fonte && typeof fonte === 'object' ? Object.keys(fonte).map((k) => fonte[k]) : []);
      for (const item of itens) { try { registrarFerramenta(item); n++; } catch (e) { /* item incompatível é ignorado, não derruba o catálogo */ } }
      return n;
    }
    function listarFerramentas() { return Array.from(ferramentas.values()).map(publicaFerramenta); }
    function listarAgentes() { return Array.from(agentes.values()).map(clone); }
    function podeExecutar(id, ctx) {
      const d = ferramentas.get(id);
      if (!d) return { ok: false, codigo: 'NAO_ENCONTRADA', erro: 'Ferramenta não encontrada: ' + id };
      if (ctx && ctx.ferramentasPermitidas && ctx.ferramentasPermitidas.indexOf(id) < 0) return { ok: false, codigo: 'SEM_PERMISSAO', erro: 'Ferramenta fora do escopo autorizado.' };
      return { ok: true, def: d };
    }
    function validarArgs(def, args) {
      const a = args && typeof args === 'object' && !Array.isArray(args) ? args : {};
      const schema = def.argumentos || {};
      const saida = {};
      for (const k of Object.keys(schema)) {
        const regra = schema[k] || {};
        const bruto = a[k];
        if (bruto == null || bruto === '') {
          if (regra.obrigatorio) throw new Error('Falta o argumento "' + k + '".');
          if (regra.padrao !== undefined) saida[k] = clone(regra.padrao);
          continue;
        }
        if (regra.tipo === 'numero') {
          const n = numero(bruto, NaN); if (!Number.isFinite(n)) throw new Error('"' + k + '" precisa ser número.');
          if (regra.min != null && n < regra.min) throw new Error('"' + k + '" abaixo do mínimo.');
          if (regra.max != null && n > regra.max) throw new Error('"' + k + '" acima do máximo.');
          saida[k] = n;
        } else if (regra.tipo === 'inteiro') {
          const n = Math.round(numero(bruto, NaN)); if (!Number.isFinite(n)) throw new Error('"' + k + '" precisa ser inteiro.');
          if (regra.min != null && n < regra.min) throw new Error('"' + k + '" abaixo do mínimo.');
          if (regra.max != null && n > regra.max) throw new Error('"' + k + '" acima do máximo.');
          saida[k] = n;
        } else if (regra.tipo === 'booleano') {
          saida[k] = bruto === true || bruto === 'true' || bruto === 1 || bruto === '1';
        } else if (regra.tipo === 'lista') {
          if (!Array.isArray(bruto)) throw new Error('"' + k + '" precisa ser lista.');
          saida[k] = bruto.slice(0, regra.maxItens || 20).map((x) => limitar(x, regra.maxItem || 200));
        } else {
          saida[k] = limitar(bruto, regra.max || 4000);
          if (regra.opcoes && regra.opcoes.indexOf(saida[k]) < 0) throw new Error('"' + k + '" fora das opções permitidas.');
        }
      }
      // Argumentos desconhecidos não entram: evita que um modelo injete campos internos.
      return saida;
    }
    async function executar(id, args, ctx) {
      const c = ctx || {};
      const permitido = podeExecutar(id, c);
      if (!permitido.ok) return { ok: false, codigo: permitido.codigo, erro: permitido.erro, ferramenta: id };
      const def = permitido.def;
      let dados;
      try { dados = validarArgs(def, args); }
      catch (e) { return { ok: false, codigo: 'ARGUMENTO_INVALIDO', erro: String(e.message || e), ferramenta: id }; }
      const inicio = agora();
      const traceId = uid('tr');
      const baseTrace = { traceId, ferramenta: id, agente: c.agente || '', origem: c.origem || 'sistema', nivel: def.nivel, risco: def.risco, argsNomes: Object.keys(dados), inicio: iso(inicio) };
      traco('ferramenta:inicio', baseTrace);
      emitir('ferramenta:inicio', { id, argsNomes: Object.keys(dados) });
      // Um despachante interno (ex.: etapa de plano) pode delegar a confirmação à ação
      // real que ele chama. Sem esta exceção, o usuário confirmaria duas vezes a mesma
      // etapa. O flag não ignora a confirmação da ferramenta chamada.
      const exige = def.semConfirmacaoPropria !== true && (def.risco >= 2 || def.nivel !== 'leitura');
      if (exige) {
        let ok = false;
        try { ok = await confirmar('Executar ' + (def.nome || id) + (Object.keys(dados).length ? ' com ' + Object.keys(dados).join(', ') : '') + '?', def.risco >= 3); }
        catch (e) { ok = false; }
        if (!ok) {
          const r = { ok: false, codigo: 'CANCELADO', erro: 'Execução não autorizada.', ferramenta: id, traceId, duracaoMs: agora() - inicio };
          traco('ferramenta:fim', Object.assign({}, baseTrace, { ok: false, codigo: r.codigo, duracaoMs: r.duracaoMs }));
          return r;
        }
      }
      const prazo = Math.max(1000, Math.min(60000, numero(c.timeoutMs, timeoutPadrao)));
      let timer;
      try {
        const exec = Promise.resolve().then(() => def.executar(dados, { agora, origem: c.origem || 'sistema', confirmar, traco }));
        const limite = new Promise((_, rej) => { timer = setTimeout(() => rej(new Error('Tempo esgotado após ' + prazo + ' ms.')), prazo); });
        const resultado = await Promise.race([exec, limite]);
        if (resultado === undefined) throw new Error('A ferramenta não devolveu confirmação.');
        const r = { ok: true, ferramenta: id, resultado, traceId, duracaoMs: agora() - inicio };
        traco('ferramenta:fim', Object.assign({}, baseTrace, { ok: true, duracaoMs: r.duracaoMs, resultadoTipo: typeof resultado }));
        emitir('ferramenta:fim', { id, ok: true, traceId, duracaoMs: r.duracaoMs });
        return r;
      } catch (e) {
        const r = { ok: false, codigo: /Tempo esgotado/.test(String(e && e.message)) ? 'TEMPO' : 'FALHOU', erro: String((e && e.message) || e).slice(0, 300), ferramenta: id, traceId, duracaoMs: agora() - inicio };
        traco('ferramenta:fim', Object.assign({}, baseTrace, { ok: false, codigo: r.codigo, duracaoMs: r.duracaoMs }));
        emitir('ferramenta:fim', { id, ok: false, traceId, duracaoMs: r.duracaoMs });
        return r;
      } finally { if (timer) clearTimeout(timer); }
    }

    /* ---------- Detecção de injeção e texto não confiável ---------- */
    const PADROES_INJECAO = [
      /ignore\s+(?:todas?\s+)?(?:as\s+)?(?:instru[cç][oõ]es|regras)\s+(?:anteriores|acima)/i,
      /ignore\s+(?:all\s+)?(?:previous|prior)\s+instructions/i,
      /desconsidere\s+(?:as\s+)?(?:instru[cç][oõ]es|regras)/i,
      /(?:revele|mostre|imprima)\s+(?:o\s+)?(?:prompt|system\s*prompt|chave|token|senha)/i,
      /you\s+are\s+now\s+(?:a|an|the)\s+/i,
      /(?:execute|rode|run)\s+(?:este|esse|o)\s+(?:c[oó]digo|script|comando)/i,
      /rm\s+-rf\s+\//i,
      /(?:curl|wget)[^\n]{0,80}\|\s*(?:sh|bash)/i,
      /<\/?(?:system|assistant|tool|instruction)[^>]*>/i,
      /\[\[(?:system|instruction|prompt)\]\]/i
    ];
    function detectarInjecao(texto) {
      const t = limitar(texto, 8000);
      const motivos = [];
      for (const rx of PADROES_INJECAO) if (rx.test(t)) motivos.push(rx.source.slice(0, 60));
      return { suspeito: motivos.length > 0, motivos, risco: Math.min(3, motivos.length) };
    }
    function sanitizarNaoConfiavel(texto, max) {
      return limitar(String(texto == null ? '' : texto).replace(/<\/?(?:script|iframe|object|embed)[^>]*>/gi, ''), max || 4000);
    }

    /* ---------- Tarefas persistentes ---------- */
    function criarTarefa(objetivo, passos) {
      const obj = limitar(objetivo, 240).trim();
      if (!obj) throw new Error('Objetivo vazio.');
      if (!Array.isArray(passos) || !passos.length) throw new Error('A tarefa precisa de pelo menos uma etapa.');
      if (passos.length > 12) throw new Error('Máximo de 12 etapas por tarefa.');
      const ps = passos.map((p, i) => {
        const idF = String((p && (p.ferramenta || p.id)) || '').trim();
        if (!ferramentas.has(idF)) throw new Error('Etapa ' + (i + 1) + ' usa ferramenta desconhecida: ' + idF);
        return { id: i + 1, ferramenta: idF, args: clone((p && p.args) || {}) || {}, estado: 'pendente', resultado: '', em: '' };
      });
      const t = { id: uid('tarefa'), objetivo: obj, criadaEm: iso(), atualizadaEm: iso(), estado: 'pendente', passos: ps };
      tarefas.push(t); persistirTarefas(); emitir('tarefa:criada', clone(t));
      return clone(t);
    }
    function listarTarefas() { return tarefas.map(clone); }
    function obterTarefa(id) { const t = tarefas.find((x) => x.id === id); return t ? clone(t) : null; }
    function cancelarTarefa(id) {
      const t = tarefas.find((x) => x.id === id); if (!t) return false;
      // A trava só pode ser liberada no finally da execução em voo: removê-la aqui
      // permitiria um novo execute antes de a ação atual terminar.
      pausasSolicitadas.delete(id); t.estado = 'cancelada'; t.atualizadaEm = iso(); persistirTarefas(); emitir('tarefa:cancelada', { id }); return true;
    }
    /** Pede pausa entre etapas. Durante uma ferramenta em curso, não interrompe o efeito
     *  já iniciado: apenas impede que a próxima etapa comece. */
    function pausarTarefa(id) {
      const t = tarefas.find((x) => x.id === id);
      if (!t || ['cancelada', 'concluida', 'falhou'].indexOf(t.estado) >= 0) return false;
      if (emExecucao.has(id)) {
        pausasSolicitadas.add(id);
        emitir('tarefa:pausa', { id, solicitada: true });
        return true;
      }
      t.estado = 'pausada'; t.atualizadaEm = iso(); persistirTarefas();
      emitir('tarefa:pausa', { id, solicitada: false });
      return true;
    }
    function cancelarTodas() { tarefas.forEach((t) => { if (['pendente', 'executando', 'pausada'].indexOf(t.estado) >= 0) { t.estado = 'cancelada'; t.atualizadaEm = iso(); } }); pausasSolicitadas.clear(); persistirTarefas(); emitir('tarefa:cancelada', { todas: true }); return true; }
    function limparTarefas() { tarefas = []; emExecucao.clear(); pausasSolicitadas.clear(); persistirTarefas(); return true; }
    async function executarTarefa(id, ctx) {
      const c = ctx || {};
      const t = tarefas.find((x) => x.id === id);
      if (!t) return { ok: false, codigo: 'NAO_ENCONTRADA', erro: 'Tarefa não encontrada.' };
      if (emExecucao.has(id)) return { ok: false, codigo: 'EM_EXECUCAO', erro: 'Essa tarefa já está em execução.' };
      if (t.estado === 'cancelada') return { ok: false, codigo: 'CANCELADA', erro: 'Tarefa cancelada.' };
      // Um novo execute é um pedido explícito de retomada: limpa a pausa anterior.
      pausasSolicitadas.delete(id);
      emExecucao.add(id); t.estado = 'executando'; t.atualizadaEm = iso(); persistirTarefas(); emitir('tarefa:inicio', { id });
      try {
        for (const p of t.passos) {
          if (t.estado === 'cancelada') return { ok: false, codigo: 'CANCELADA', tarefa: clone(t) };
          if (pausasSolicitadas.has(id)) {
            pausasSolicitadas.delete(id);
            t.estado = 'pausada'; t.atualizadaEm = iso(); persistirTarefas(); emitir('tarefa:pausa', { id, entreEtapas: true });
            return { ok: false, codigo: 'PAUSADA', erro: 'Tarefa pausada entre etapas. Retome quando quiser; a etapa já concluída não será repetida.', tarefa: clone(t) };
          }
          if (p.estado === 'ok') continue;
          if (p.estado === 'incerto') {
            if (!c.permitirIncerto) {
              t.estado = 'pausada'; t.atualizadaEm = iso(); persistirTarefas();
              return { ok: false, codigo: 'PAUSADA', erro: 'Etapa sem confirmação; autorize explicitamente para continuar.', tarefa: clone(t) };
            }
            // Autorizar uma etapa incerta não é reexecutá-la: o efeito pode já ter ocorrido.
            // Marca como aceita e segue para a próxima, sem duplicar chamada/mensagem.
            p.estado = 'ok';
            p.resultado = limitar(String(p.resultado || 'efeito incerto') + ' (incerto, autorizado sem repetir)', 300);
            p.em = iso(); t.incerto = (t.incerto || 0) + 1; t.atualizadaEm = iso();
            persistirTarefas(); emitir('tarefa:passo', { id, passo: p.id, estado: p.estado });
            continue;
          }
          const r = await executar(p.ferramenta, p.args, Object.assign({}, c, { agente: c.agente || 'tarefa', origem: c.origem || 'tarefa' }));
          // Cancelar durante a etapa não pode ser sobrescrito pelo resultado que chega
          // depois. O efeito pode ter ocorrido, então a etapa fica incerta; a tarefa
          // permanece cancelada e o finally libera a trava.
          if (t.estado === 'cancelada') {
            p.estado = 'incerto';
            p.resultado = 'cancelada durante a execução; o efeito pode ter ocorrido';
            p.em = iso();
            t.atualizadaEm = iso(); persistirTarefas();
            emitir('tarefa:passo', { id, passo: p.id, estado: p.estado });
            return { ok: false, codigo: 'CANCELADA', erro: 'Tarefa cancelada durante a etapa; o efeito pode ter ocorrido.', tarefa: clone(t) };
          }
          if (!r.ok) {
            p.estado = r.codigo === 'CANCELADO' || r.codigo === 'CONFIRMACAO_NECESSARIA' ? 'incerto' : 'falhou';
            p.resultado = r.erro || r.codigo; p.em = iso();
            t.estado = p.estado === 'incerto' ? 'pausada' : 'falhou'; t.atualizadaEm = iso(); persistirTarefas();
            return { ok: false, codigo: r.codigo, erro: r.erro, tarefa: clone(t) };
          }
          const incerto = !!(r.resultado && r.resultado.incerto);
          if (incerto && !c.permitirIncerto) {
            p.estado = 'incerto'; p.resultado = limitar((r.resultado && (r.resultado.fala || r.resultado.info || r.resultado.resumo)) || 'efeito não confirmado', 300); p.em = iso();
            t.estado = 'pausada'; t.atualizadaEm = iso(); persistirTarefas(); emitir('tarefa:passo', { id, passo: p.id, estado: p.estado });
            return { ok: false, codigo: 'PAUSADA', erro: 'Etapa sem confirmação de efeito; autorize explicitamente para continuar.', tarefa: clone(t) };
          }
          p.estado = 'ok'; p.resultado = limitar((r.resultado && (r.resultado.fala || r.resultado.info || r.resultado.resumo)) || 'concluída', 300) + (incerto ? ' (incerto, autorizado)' : ''); p.em = iso();
          if (incerto) t.incerto = (t.incerto || 0) + 1;
          t.atualizadaEm = iso(); persistirTarefas(); emitir('tarefa:passo', { id, passo: p.id, estado: p.estado });
        }
        if (t.estado === 'cancelada') {
          return { ok: false, codigo: 'CANCELADA', erro: 'Tarefa cancelada antes da conclusão.', tarefa: clone(t) };
        }
        t.estado = 'concluida'; t.atualizadaEm = iso(); persistirTarefas(); emitir('tarefa:fim', { id, estado: t.estado });
        return { ok: true, tarefa: clone(t) };
      } finally { emExecucao.delete(id); }
    }

    function status() {
      return {
        versao: VERSAO, ferramentas: ferramentas.size, agentes: agentes.size,
        tarefas: tarefas.length, tarefasPendentes: tarefas.filter((t) => ['pendente', 'executando', 'pausada'].indexOf(t.estado) >= 0).length,
        traces: traces.length, niveis: NIVEIS.slice()
      };
    }
    function diagnostico() {
      const itens = [];
      itens.push({ nome: 'Catálogo de ferramentas', ok: ferramentas.size > 0, detalhe: ferramentas.size + ' ferramenta(s)' });
      itens.push({ nome: 'Armazenamento de checkpoints', ok: salvar('sistema:teste', { em: iso() }) && !!carregar('sistema:teste', null), detalhe: 'gravação e leitura' });
      itens.push({ nome: 'Criptografia do navegador', ok: !!(globalThis.crypto && globalThis.crypto.getRandomValues), detalhe: globalThis.crypto && globalThis.crypto.subtle ? 'Web Crypto disponível' : 'Web Crypto parcial' });
      itens.push({ nome: 'Tarefas', ok: tarefas.length <= LIMITE_TAREFAS, detalhe: tarefas.length + ' de ' + LIMITE_TAREFAS });
      return { ok: itens.every((x) => x.ok), itens };
    }

    /* Ferramentas embutidas. Não usam DOM, rede ou chaves. */
    registrarFerramenta({
      id: 'calc', nome: 'Calculadora avançada', dominio: 'ferramentas', nivel: 'leitura',
      descricao: 'Avalia expressões aritméticas com parênteses, potência, funções e porcentagem. Não executa código.',
      argumentos: { expressao: { tipo: 'texto', obrigatorio: true, max: 320 } },
      executar: (a) => { const v = avaliarExpressao(a.expressao); return { valor: v, fala: 'O resultado é ' + formatarNumero(v) + '.', info: formatarNumero(v) }; }
    });
    registrarFerramenta({
      id: 'converter', nome: 'Conversor de unidades', dominio: 'ferramentas', nivel: 'leitura',
      descricao: 'Converte comprimento, massa, volume, tempo, dados, velocidade e temperatura.',
      argumentos: { valor: { tipo: 'numero', obrigatorio: true }, de: { tipo: 'texto', obrigatorio: true, max: 30 }, para: { tipo: 'texto', obrigatorio: true, max: 30 } },
      executar: (a) => converter(a)
    });
    registrarFerramenta({
      id: 'senha', nome: 'Gerador de senha', dominio: 'seguranca', nivel: 'leitura', risco: 0,
      descricao: 'Gera senha criptograficamente aleatória no próprio aparelho; não salva nem envia.',
      argumentos: { tamanho: { tipo: 'inteiro', min: 8, max: 128, padrao: 20 }, simbolos: { tipo: 'booleano', padrao: true } },
      executar: (a) => gerarSenha(a)
    });
    registrarFerramenta({
      id: 'texto_estatisticas', nome: 'Estatísticas de texto', dominio: 'ferramentas', nivel: 'leitura',
      descricao: 'Conta caracteres, palavras, linhas e estima tempo de leitura.',
      argumentos: { texto: { tipo: 'texto', obrigatorio: true, max: LIMITE_TEXTO } }, executar: (a) => estatisticasTexto(a)
    });
    registrarFerramenta({
      id: 'json_formatar', nome: 'Formatador JSON', dominio: 'ferramentas', nivel: 'leitura',
      descricao: 'Valida e formata JSON, devolvendo erro claro quando inválido.',
      argumentos: { texto: { tipo: 'texto', obrigatorio: true, max: LIMITE_TEXTO }, espacos: { tipo: 'inteiro', min: 0, max: 8, padrao: 2 } }, executar: (a) => formatarJson(a)
    });
    registrarFerramenta({
      id: 'hash', nome: 'Hash SHA-256', dominio: 'seguranca', nivel: 'leitura',
      descricao: 'Calcula SHA-256 de um texto localmente.',
      argumentos: { texto: { tipo: 'texto', obrigatorio: true, max: LIMITE_TEXTO } }, executar: (a) => hashTexto(a)
    });
    registrarFerramenta({
      id: 'data_calcular', nome: 'Cálculo de data', dominio: 'ferramentas', nivel: 'leitura',
      descricao: 'Soma ou subtrai dias de uma data, com padrão hoje.',
      argumentos: { dias: { tipo: 'inteiro', min: -36500, max: 36500, obrigatorio: true }, data: { tipo: 'texto', max: 40 } }, executar: (a) => calcularData(a)
    });
    registrarFerramenta({
      id: 'sistema_status', nome: 'Status do sistema operacional', dominio: 'sistema', nivel: 'leitura',
      descricao: 'Mostra quantas ferramentas, agentes, tarefas e traces existem.', argumentos: {},
      executar: () => { const s = status(); return { status: s, fala: 'Núcleo operacional ' + s.versao + ': ' + s.ferramentas + ' ferramentas, ' + s.agentes + ' agentes, ' + s.tarefasPendentes + ' tarefa(s) pendente(s), ' + s.traces + ' trace(s).' }; }
    });

    /* Interpretação local de comandos de ferramenta. Retorna null quando não é o caso. */
    function interpretar(texto) {
      const original = String(texto || '').replace(/^(?:jarvis|jarves|jervis|gervis|garvis|charvis|jarbis|jarvez|jarvs|jarvi)\b[\s,]*/i, '').trim();
      const n = norm(original);
      if (!n) return null;
      if (/^(?:status|estado) (?:do )?(?:sistema operacional|jarvis os|nucleo operacional)$/.test(n) || /^(?:diagnostico) (?:do )?(?:sistema operacional|jarvis os)$/.test(n)) return { ferramenta: 'sistema_status', args: {} };
      if (/^(?:liste|listar|mostre|mostrar) (?:as )?ferramentas(?: do sistema)?$/.test(n)) return { ferramenta: 'sistema_status', args: {}, listar: true };
      let m = /^(?:calcule|calcula|calcular|quanto (?:e|vale|da|dá)|resolva)\s+(.+)$/i.exec(original);
      if (!m) m = /^([\d\s.,()+\-*/^%√π]+)$/i.exec(original);
      if (m) {
        const expr = String(m[1] || '').replace(/\?+$/, '').trim();
        if (/\d/.test(expr)) {
          try { const v = avaliarExpressao(expr); return { ferramenta: 'calc', args: { expressao: expr }, previa: v }; }
          catch (e) { return null; }
        }
      }
      m = /^(?:converta|converter|quanto (?:e|sao|são))\s+([\d.,]+)\s*([a-zA-ZÀ-ÿ/ ]+?)\s+(?:em|para)\s+([a-zA-ZÀ-ÿ/ ]+)$/i.exec(original);
      if (m) {
        const de = unidade(m[2]), para = unidade(m[3]);
        if (de && para) return { ferramenta: 'converter', args: { valor: numero(m[1], NaN), de, para } };
      }
      m = /^(?:gere|gerar|crie|criar)\s+(?:uma\s+)?senha(?:\s+(?:de|com)\s+(\d{1,3})\s*(?:caracteres|letras)?)?$/i.exec(original);
      if (m) return { ferramenta: 'senha', args: { tamanho: m[1] ? Number(m[1]) : 20 } };
      m = /^(?:que dia|qual data)\s+(?:sera|é|e)\s+(?:daqui a|em)\s+(\d{1,4})\s+dias?$/i.exec(original);
      if (m) return { ferramenta: 'data_calcular', args: { dias: Number(m[1]) } };
      if (/^(?:parar|cancele|cancelar) (?:as )?(?:tarefas|tudo)$/.test(n)) return { ferramenta: null, acao: 'cancelar_tarefas' };
      return null;
    }

    return {
      VERSAO, registrarFerramenta, registrarAgente, descobrir, listarFerramentas, listarAgentes,
      executar, interpretar, detectarInjecao, sanitizarNaoConfiavel, avaliarExpressao, converter,
      criarTarefa, executarTarefa, listarTarefas, obterTarefa, pausarTarefa, cancelarTarefa, cancelarTodas,
      limparTarefas, status, diagnostico, ao,
      traces: () => traces.map(clone),
      limparTraces: () => { traces = []; persistirTraces(); return true; },
      exportarTraces: () => JSON.stringify(traces.map(clone), null, 2),
      config: () => ({ limiteTraces: LIMITE_TRACES, limiteTarefas: LIMITE_TAREFAS, timeoutMs: timeoutPadrao })
    };
  }

  return { VERSAO, criarNucleo, avaliarExpressao, converter, detectarInjecao: (texto) => {
    const x = criarNucleo({ armazenamento: { ler: () => '', gravar: () => true } });
    return x.detectarInjecao(texto);
  }, unidade };
});
