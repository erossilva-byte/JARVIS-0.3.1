/* J.A.R.V.I.S. Nova — arquivos do núcleo, com suporte a .cad do CadSimu.
 *
 * Não havia CadSimu nem parser `.cad` no projeto (procurei por "CadSimu" e ".cad" em
 * todos os módulos). Para não inventar um dialeto incompatível com um simulador que eu não
 * consigo ver, o formato abaixo é **documentado, versionado e tolerante**, e o ponto de
 * troca é único (`FORMATO`/`TIPOS`): se o CadSimu usar outro layout, basta apontar o parser
 * para ele sem mexer no aplicativo.
 *
 * Formato "CADSIMU CAD" (UTF-8, JSON):
 * {
 *   "formato": "CadSimu CAD",
 *   "versao": 1,
 *   "nome": "peça-1",
 *   "unidades": "mm",
 *   "objetos": [
 *     { "tipo": "caixa", "nome": "base", "posicao": [0,0,0], "dimensoes": [100,60,20], "cor": "#22d3ee" },
 *     { "tipo": "esfera", "nome": "esfera", "posicao": [0,0,40], "raio": 10 },
 *     { "tipo": "cilindro", "nome": "pino", "posicao": [0,0,20], "raio": 4, "altura": 30 }
 *   ]
 * }
 *
 * Regras do parser:
 *  - JSON inválido, objeto ausente, número inválido ou tipo desconhecido devolvem
 *    { ok:false, erro } com o índice e o campo do problema — nunca uma exceção;
 *  - tolera `formato` ausente (aviso) e versões anteriores; recusa versão futura;
 *  - aceita primitivas caixa/esfera/cilindro/cone/plano; no máximo 500 objetos;
 *  - tudo é sanitizado e limitado, inclusive nome de arquivo.
 *
 * Também guarda os `.cad` criados no aparelho (registro local com teto de 40 arquivos e
 * 256 kB), para listar, analisar, baixar e apagar sem depender de permissão de
 * armazenamento externo.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.CadNucleo = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var FORMATO = 'CadSimu CAD';
  var VERSAO = 1;
  var UNIDADES = ['mm', 'cm', 'm', 'pol'];
  var LIMITE_OBJETOS = 500;
  var LIMITE_ARQUIVOS = 40;
  var LIMITE_BYTES = 256 * 1024;
  var CHAVE = 'jv_cad_arquivos';

  var TIPOS = {
    caixa: { campos: ['dimensoes'], ajuda: 'dimensoes [largura, altura, profundidade]' },
    esfera: { campos: ['raio'], ajuda: 'raio' },
    cilindro: { campos: ['raio', 'altura'], ajuda: 'raio e altura' },
    cone: { campos: ['raio', 'altura'], ajuda: 'raio e altura' },
    plano: { campos: ['dimensoes'], ajuda: 'dimensoes [largura, profundidade]' }
  };

  var store = null;
  function obterStore() {
    if (store) return store;
    try { if (typeof localStorage !== 'undefined') store = localStorage; } catch (e) { store = null; }
    return store;
  }

  function limpar(txt, max) {
    return String(txt == null ? '' : txt)
      .replace(/[\u0000-\u001f\u007f]/g, ' ')
      .replace(/[<>]/g, '')
      .trim()
      .slice(0, max);
  }

  function bytesDe(txt) {
    var t = String(txt == null ? '' : txt);
    try { if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(t).length; } catch (e) { /* fallback */ }
    return unescape(encodeURIComponent(t)).length;
  }

  function numeroValido(n) {
    return typeof n === 'number' && Number.isFinite(n) && Math.abs(n) <= 1000000;
  }

  function vetor(v, tamanho) {
    return Array.isArray(v) && v.length === tamanho && v.every(numeroValido);
  }

  function nomeArquivo(nome) {
    var base = limpar(nome, 80).replace(/\.cad$/i, '').replace(/[\\/:*?"<>|]+/g, '-')
      .replace(/\.{2,}/g, '-').replace(/^[.\-\s]+/, '').replace(/\s+/g, '-');
    if (!base) base = 'modelo';
    return base + '.cad';
  }

  function slug(nome) { return nomeArquivo(nome); }

  /* ---------- Criar / serializar ---------- */
  function objetoPadrao(tipo) {
    var t = TIPOS[tipo] ? tipo : 'caixa';
    if (t === 'esfera') return { tipo: 'esfera', nome: 'esfera', posicao: [0, 0, 0], raio: 10 };
    if (t === 'cilindro') return { tipo: 'cilindro', nome: 'cilindro', posicao: [0, 0, 0], raio: 5, altura: 20 };
    if (t === 'cone') return { tipo: 'cone', nome: 'cone', posicao: [0, 0, 0], raio: 5, altura: 20 };
    if (t === 'plano') return { tipo: 'plano', nome: 'plano', posicao: [0, 0, 0], dimensoes: [100, 100] };
    return { tipo: 'caixa', nome: 'caixa', posicao: [0, 0, 0], dimensoes: [20, 20, 20] };
  }

  function criar(especificacao) {
    var e = especificacao || {};
    var unidades = UNIDADES.indexOf(e.unidades) >= 0 ? e.unidades : 'mm';
    var objetos = Array.isArray(e.objetos) && e.objetos.length ? e.objetos : [objetoPadrao(e.tipo)];
    return {
      formato: FORMATO,
      versao: VERSAO,
      nome: limpar(e.nome, 80) || 'modelo',
      unidades: unidades,
      criado: new Date().toISOString(),
      objetos: objetos
    };
  }

  function serializar(doc) {
    var d = doc || criar({});
    return JSON.stringify(d, null, 2) + '\n';
  }

  /* ---------- Analisar / validar ---------- */
  function erro(msg) { return { ok: false, erro: msg }; }

  function validarObjeto(o, i) {
    if (!o || typeof o !== 'object' || Array.isArray(o)) return 'Objeto ' + (i + 1) + ': precisa ser um objeto.';
    var tipo = String(o.tipo || '').toLowerCase();
    if (!TIPOS[tipo]) {
      return 'Objeto ' + (i + 1) + ': tipo "' + (o.tipo || '?') + '" não existe. Use ' + Object.keys(TIPOS).join(', ') + '.';
    }
    if (o.posicao != null && !vetor(o.posicao, 3)) return 'Objeto ' + (i + 1) + ': "posicao" precisa ter 3 números finitos.';
    if (o.cor != null && !/^#[0-9a-f]{3,8}$/i.test(String(o.cor))) return 'Objeto ' + (i + 1) + ': "cor" precisa ser hexadecimal (#rrggbb).';
    if (tipo === 'caixa' || tipo === 'plano') {
      var n = tipo === 'plano' ? 2 : 3;
      if (!vetor(o.dimensoes, n) || o.dimensoes.some(function (x) { return x <= 0; })) {
        return 'Objeto ' + (i + 1) + ': "' + tipo + '" precisa de dimensoes com ' + n + ' números maiores que zero.';
      }
    }
    if (tipo === 'esfera') {
      if (!numeroValido(o.raio) || o.raio <= 0) return 'Objeto ' + (i + 1) + ': "esfera" precisa de raio maior que zero.';
    }
    if (tipo === 'cilindro' || tipo === 'cone') {
      if (!numeroValido(o.raio) || o.raio <= 0) return 'Objeto ' + (i + 1) + ': "' + tipo + '" precisa de raio maior que zero.';
      if (!numeroValido(o.altura) || o.altura <= 0) return 'Objeto ' + (i + 1) + ': "' + tipo + '" precisa de altura maior que zero.';
    }
    return '';
  }

  function parse(texto) {
    if (typeof texto !== 'string' || !texto.trim()) return erro('Arquivo vazio: cole o conteúdo de um .cad do CadSimu.');
    var bruto;
    try { bruto = JSON.parse(texto); }
    catch (e) {
      var detalhe = String(e && e.message ? e.message : e);
      return erro('JSON inválido no .cad: ' + detalhe.slice(0, 120) + '. Verifique vírgulas e chaves.');
    }
    if (!bruto || typeof bruto !== 'object' || Array.isArray(bruto)) return erro('O .cad precisa ser um objeto JSON com "formato", "versao" e "objetos".');
    var avisos = [];
    if (bruto.formato && String(bruto.formato).toLowerCase() !== FORMATO.toLowerCase()) {
      return erro('Formato desconhecido ("' + limpar(bruto.formato, 40) + '"). Este arquivo não é do CadSimu.');
    }
    if (!bruto.formato) avisos.push('sem o campo "formato"; assumindo ' + FORMATO);
    var versao = Number(bruto.versao);
    if (bruto.versao != null && (!Number.isFinite(versao) || versao > VERSAO)) {
      return erro('Versão ' + limpar(bruto.versao, 12) + ' do .cad é mais nova que a suportada (' + VERSAO + '). Atualize o aplicativo.');
    }
    if (!Array.isArray(bruto.objetos) || !bruto.objetos.length) return erro('O .cad não tem "objetos": nada para o CadSimu desenhar.');
    if (bruto.objetos.length > LIMITE_OBJETOS) return erro('O .cad tem ' + bruto.objetos.length + ' objetos; o limite é ' + LIMITE_OBJETOS + '.');
    for (var i = 0; i < bruto.objetos.length; i++) {
      var problema = validarObjeto(bruto.objetos[i], i);
      if (problema) return erro(problema);
      var o = bruto.objetos[i];
      if (!o.posicao) o.posicao = [0, 0, 0];
      o.tipo = String(o.tipo).toLowerCase();
      o.nome = limpar(o.nome || (o.tipo + ' ' + (i + 1)), 60);
    }
    if (bruto.unidades && UNIDADES.indexOf(String(bruto.unidades)) < 0) {
      avisos.push('unidade "' + limpar(bruto.unidades, 10) + '" não reconhecida; usando mm');
      bruto.unidades = 'mm';
    }
    if (!bruto.unidades) bruto.unidades = 'mm';
    var doc = {
      formato: FORMATO,
      versao: Number.isFinite(versao) && versao > 0 ? versao : VERSAO,
      nome: limpar(bruto.nome, 80) || 'modelo',
      unidades: bruto.unidades,
      objetos: bruto.objetos
    };
    return { ok: true, doc: doc, avisos: avisos };
  }

  function caixaEnvolvente(doc) {
    var min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
    function acumular(p, dx, dy, dz) {
      var pos = p || [0, 0, 0];
      for (var k = 0; k < 3; k++) {
        var meio = [dx, dy, dz][k] / 2;
        min[k] = Math.min(min[k], pos[k] - meio);
        max[k] = Math.max(max[k], pos[k] + meio);
      }
    }
    doc.objetos.forEach(function (o) {
      if (o.tipo === 'caixa') acumular(o.posicao, o.dimensoes[0], o.dimensoes[1], o.dimensoes[2]);
      else if (o.tipo === 'esfera') acumular(o.posicao, o.raio * 2, o.raio * 2, o.raio * 2);
      else if (o.tipo === 'cilindro' || o.tipo === 'cone') acumular(o.posicao, o.raio * 2, o.altura, o.raio * 2);
      else acumular(o.posicao, o.dimensoes[0], 0, o.dimensoes[1]);
    });
    return { min: min, max: max, tamanho: [max[0] - min[0], max[1] - min[1], max[2] - min[2]] };
  }

  function formatar(n) {
    var v = Math.round(Number(n) * 100) / 100;
    return String(v).replace('.', ',');
  }

  function analisar(texto) {
    var r = parse(texto);
    if (!r.ok) return r;
    var doc = r.doc;
    var contagem = {};
    doc.objetos.forEach(function (o) { contagem[o.tipo] = (contagem[o.tipo] || 0) + 1; });
    var partes = Object.keys(contagem).map(function (t) { return contagem[t] + ' ' + t + (contagem[t] > 1 ? 's' : ''); });
    var caixa = caixaEnvolvente(doc);
    var resumo = 'Arquivo ' + slug(doc.nome) + ': ' + doc.objetos.length + (doc.objetos.length === 1 ? ' objeto' : ' objetos') +
      ' (' + partes.join(', ') + '), unidades ' + doc.unidades + ', caixa envolvente ' +
      formatar(caixa.tamanho[0]) + ' × ' + formatar(caixa.tamanho[1]) + ' × ' + formatar(caixa.tamanho[2]) + ' ' + doc.unidades + '.';
    return {
      ok: true, doc: doc, avisos: r.avisos, contagem: contagem, caixa: caixa,
      resumo: resumo + (r.avisos.length ? ' Avisos: ' + r.avisos.join('; ') + '.' : '')
    };
  }

  /* ---------- Arquivo .cad no aparelho ---------- */
  function lerLista() {
    var s = obterStore();
    if (!s) return [];
    var bruto;
    try { bruto = JSON.parse(s.getItem(CHAVE) || '[]'); } catch (e) { return []; }
    if (!Array.isArray(bruto)) return [];
    return bruto.filter(function (a) { return a && typeof a.nome === 'string' && typeof a.texto === 'string'; })
      .slice(0, LIMITE_ARQUIVOS);
  }
  function gravarLista(lista) {
    var s = obterStore();
    if (!s) return false;
    try { s.setItem(CHAVE, JSON.stringify(lista.slice(0, LIMITE_ARQUIVOS))); return true; }
    catch (e) { return false; }
  }

  function salvar(nome, conteudo) {
    var texto = typeof conteudo === 'string' ? conteudo : serializar(conteudo);
    var r = parse(texto);
    if (!r.ok) return r;
    var lista = lerLista().filter(function (a) { return a.nome !== slug(nome); });
    var bytes = bytesDe(texto);
    if (bytes > LIMITE_BYTES) return erro('O arquivo tem ' + Math.round(bytes / 1024) + ' kB; o limite é ' + Math.round(LIMITE_BYTES / 1024) + ' kB.');
    lista.unshift({ nome: slug(nome), texto: texto, bytes: bytes, criado: Date.now(), atualizado: Date.now() });
    if (!gravarLista(lista)) return erro('Sem espaço no armazenamento local para este arquivo.');
    return { ok: true, nome: slug(nome), bytes: bytes, doc: r.doc };
  }

  function listar() {
    return lerLista().map(function (a) {
      return { nome: a.nome, bytes: a.bytes || bytesDe(a.texto), criado: a.criado || 0, atualizado: a.atualizado || a.criado || 0 };
    }).sort(function (a, b) { return b.atualizado - a.atualizado; });
  }

  function ler(nome) {
    var alvo = lerLista().filter(function (a) { return a.nome === slug(nome); })[0];
    if (!alvo) return erro('Arquivo "' + limpar(nome, 60) + '" não encontrado.');
    return { ok: true, nome: alvo.nome, texto: alvo.texto, bytes: alvo.bytes || bytesDe(alvo.texto) };
  }

  function apagar(nome) {
    var alvo = slug(nome);
    var lista = lerLista();
    var sobrou = lista.filter(function (a) { return a.nome !== alvo; });
    if (sobrou.length === lista.length) return erro('Arquivo "' + alvo + '" não encontrado.');
    if (!gravarLista(sobrou)) return erro('Não foi possível apagar agora.');
    return { ok: true, restantes: sobrou.length };
  }

  function apagarTudo() {
    if (!gravarLista([])) return erro('Não foi possível limpar os arquivos agora.');
    return { ok: true };
  }

  function espaco() {
    var lista = lerLista();
    var bytes = lista.reduce(function (s, a) { return s + (a.bytes || bytesDe(a.texto)); }, 0);
    return {
      arquivos: lista.length, bytes: bytes, limiteBytes: LIMITE_BYTES, limiteArquivos: LIMITE_ARQUIVOS,
      percentual: Math.min(100, Math.round((bytes / LIMITE_BYTES) * 100))
    };
  }

  function exemplo(nome) {
    var doc = criar({ nome: nome || 'exemplo', unidades: 'mm' });
    doc.objetos = [
      { tipo: 'caixa', nome: 'base', posicao: [0, 0, 0], dimensoes: [100, 60, 10], cor: '#22d3ee' },
      { tipo: 'cilindro', nome: 'pino', posicao: [0, 0, 20], raio: 6, altura: 30, cor: '#60a5fa' },
      { tipo: 'esfera', nome: 'ponta', posicao: [0, 0, 40], raio: 8, cor: '#34d399' }
    ];
    return doc;
  }

  return {
    FORMATO: FORMATO,
    VERSAO: VERSAO,
    UNIDADES: UNIDADES,
    TIPOS: TIPOS,
    LIMITE_OBJETOS: LIMITE_OBJETOS,
    LIMITE_ARQUIVOS: LIMITE_ARQUIVOS,
    LIMITE_BYTES: LIMITE_BYTES,
    usarStore: function (s) { store = s || null; },
    nomeArquivo: nomeArquivo,
    objetoPadrao: objetoPadrao,
    criar: criar,
    serializar: serializar,
    parse: parse,
    analisar: analisar,
    caixaEnvolvente: caixaEnvolvente,
    exemplo: exemplo,
    salvar: salvar,
    listar: listar,
    ler: ler,
    apagar: apagar,
    apagarTudo: apagarTudo,
    espaco: espaco
  };
});
