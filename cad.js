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

  /* ================= Intercâmbio CAD: malha, DXF, STL, 3MF, STEP e IFC =================
   * O `.cad` do CadSimu é a linguagem do aplicativo; os formatos abaixo são o que o mundo
   * externo entende. Todos partem da MESMA malha (`malha()`), então dois caminhos não podem
   * divergir. Regras de projeto:
   *  - nada de biblioteca externa, download ou serviço: JavaScript puro, roda em Node e no
   *    WebView (o teste roda a mesma implementação nos dois);
   *  - cada escritor devolve também a validação por REABERTURA (o arquivo é lido de volta
   *    pelo leitor correspondente) e a lista de perdas da conversão;
   *  - formato que não dá para ler/gerar de verdade (DWG, RVT, RFA, FCStd) é recusado com
   *    explicação, em vez de produzir um arquivo que o software de destino não abre.
   */

  var SEGMENTOS = 24;

  function seno(i, n) { return Math.sin((i / n) * Math.PI * 2); }
  function cosseno(i, n) { return Math.cos((i / n) * Math.PI * 2); }
  function posicao(o) { return Array.isArray(o.posicao) && o.posicao.length === 3 ? o.posicao : [0, 0, 0]; }

  /** Triangula o documento inteiro. Devolve vértices achatados e triângulos por índice. */
  function malha(doc, opcoes) {
    var o = opcoes || {};
    var seg = Math.max(6, Math.min(64, Number(o.segmentos) || SEGMENTOS));
    var vertices = [];
    var triangulos = [];
    function juntar(pontos, faces) {
      // Orientação: o volume assinado diz se as faces apontam para fora. Se estiverem
      // invertidas, troco b/c — sem isso o STL sai "do avesso" e o slicer recusa.
      var assinado = 0;
      for (var t = 0; t < faces.length; t++) {
        var A = faces[t][0] * 3, B = faces[t][1] * 3, C = faces[t][2] * 3;
        assinado += (pontos[A] * (pontos[B + 1] * pontos[C + 2] - pontos[B + 2] * pontos[C + 1]) -
          pontos[A + 1] * (pontos[B] * pontos[C + 2] - pontos[B + 2] * pontos[C]) +
          pontos[A + 2] * (pontos[B] * pontos[C + 1] - pontos[B + 1] * pontos[C])) / 6;
      }
      var lista = assinado < 0 ? faces.map(function (x) { return [x[0], x[2], x[1]]; }) : faces;
      var total = pontos.length / 3;
      var base = vertices.length / 3;
      for (var i = 0; i < pontos.length; i++) vertices.push(pontos[i]);
      for (var j = 0; j < lista.length; j++) {
        var t3 = lista[j];
        // Índice fora da lista significaria coordenada NaN no arquivo exportado.
        if (!(t3[0] < total && t3[1] < total && t3[2] < total)) continue;
        triangulos.push([base + t3[0], base + t3[1], base + t3[2]]);
      }
    }
    (doc && doc.objetos ? doc.objetos : []).forEach(function (obj) {
      var p = posicao(obj);
      if (obj.tipo === 'caixa' || obj.tipo === 'plano') {
        var dx = obj.dimensoes[0] / 2;
        var dz = obj.tipo === 'plano' ? 0 : obj.dimensoes[2] / 2;
        var dy = obj.tipo === 'plano' ? obj.dimensoes[1] / 2 : obj.dimensoes[1] / 2;
        if (obj.tipo === 'plano') {
          // Plano deitado no XY da posição: duas faces (frente e verso não importam para STL).
          juntar([
            p[0] - dx, p[1] - dy, p[2],
            p[0] + dx, p[1] - dy, p[2],
            p[0] + dx, p[1] + dy, p[2],
            p[0] - dx, p[1] + dy, p[2]
          ], [[0, 1, 2], [0, 2, 3]]);
          return;
        }
        juntar([
          p[0] - dx, p[1] - dy, p[2] - dz, p[0] + dx, p[1] - dy, p[2] - dz,
          p[0] + dx, p[1] + dy, p[2] - dz, p[0] - dx, p[1] + dy, p[2] - dz,
          p[0] - dx, p[1] - dy, p[2] + dz, p[0] + dx, p[1] - dy, p[2] + dz,
          p[0] + dx, p[1] + dy, p[2] + dz, p[0] - dx, p[1] + dy, p[2] + dz
        ], [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4],
          [1, 2, 6], [1, 6, 5], [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7]]);
        return;
      }
      if (obj.tipo === 'esfera') {
        var raio = obj.raio;
        var aneis = Math.max(4, Math.round(seg / 2));
        var pontos = [];
        var faces = [];
        // Pólo superior, anéis intermediários e pólo inferior.
        for (var a = 0; a <= aneis; a++) {
          var fi = (a / aneis) * Math.PI;
          var z = Math.cos(fi) * raio;
          var r = Math.sin(fi) * raio;
          for (var b = 0; b < seg; b++) {
            pontos.push(p[0] + r * cosseno(b, seg), p[1] + r * seno(b, seg), p[2] + z);
          }
        }
        for (var a2 = 0; a2 < aneis; a2++) {
          for (var b2 = 0; b2 < seg; b2++) {
            var i0 = a2 * seg + b2;
            var i1 = a2 * seg + (b2 + 1) % seg;
            var i2 = (a2 + 1) * seg + b2;
            var i3 = (a2 + 1) * seg + (b2 + 1) % seg;
            faces.push([i0, i2, i1], [i1, i2, i3]);
          }
        }
        juntar(pontos, faces);
        return;
      }
      // Cilindro e cone: base e topo centrados na posição, eixo em Z.
      var alt = obj.altura / 2;
      var rBase = obj.raio;
      var rTopo = obj.tipo === 'cone' ? 0 : obj.raio;
      var v = [];
      for (var k = 0; k < seg; k++) v.push(p[0] + rBase * cosseno(k, seg), p[1] + rBase * seno(k, seg), p[2] - alt);
      var inicioTopo = v.length / 3;
      if (rTopo > 0) {
        for (var k2 = 0; k2 < seg; k2++) v.push(p[0] + rTopo * cosseno(k2, seg), p[1] + rTopo * seno(k2, seg), p[2] + alt);
      } else {
        v.push(p[0], p[1], p[2] + alt);   // ápice do cone: um vértice, não um anel de zeros
      }
      var centroBase = v.length / 3;
      v.push(p[0], p[1], p[2] - alt);
      var centroTopo = rTopo > 0 ? v.length / 3 : inicioTopo;
      if (rTopo > 0) v.push(p[0], p[1], p[2] + alt);
      var f = [];
      for (var k3 = 0; k3 < seg; k3++) {
        var a3 = k3;
        var b3 = (k3 + 1) % seg;
        var c3 = inicioTopo + k3;
        var d3 = inicioTopo + ((k3 + 1) % seg);
        if (rTopo > 0) f.push([a3, b3, c3], [b3, d3, c3]);
        else f.push([a3, b3, inicioTopo]);   // o ápice é um só vértice para todas as fatias
        f.push([centroBase, b3, a3]);
        if (rTopo > 0) f.push([centroTopo, c3, d3]);
      }
      juntar(v, f);
    });
    return limparMalha({ vertices: vertices, triangulos: triangulos, segmentos: seg });
  }

  /** Funde vértices coincidentes (pólos da esfera, ápice do cone) e descarta faces degeneradas.
   *  Sem isso a malha da esfera e do cone teria arestas repetidas e o STL não fecharia. */
  function limparMalha(m) {
    var mapa = {};
    var novos = [];
    var mapaIdx = [];
    for (var i = 0; i < m.vertices.length; i += 3) {
      var k = Math.round(m.vertices[i] * 1e6) + ',' + Math.round(m.vertices[i + 1] * 1e6) + ',' + Math.round(m.vertices[i + 2] * 1e6);
      var idx = mapa[k];
      if (idx === undefined) {
        idx = novos.length / 3;
        mapa[k] = idx;
        novos.push(m.vertices[i], m.vertices[i + 1], m.vertices[i + 2]);
      }
      mapaIdx[i / 3] = idx;
    }
    var tris = [];
    m.triangulos.forEach(function (t) {
      var a = mapaIdx[t[0]], b = mapaIdx[t[1]], c = mapaIdx[t[2]];
      if (a === undefined || b === undefined || c === undefined) return;
      if (a === b || b === c || a === c) return;
      tris.push([a, b, c]);
    });
    return { vertices: novos, triangulos: tris, segmentos: m.segmentos };
  }

  function nVertices(m) { return m.vertices.length / 3; }
  function vertice(m, i) { return [m.vertices[i * 3], m.vertices[i * 3 + 1], m.vertices[i * 3 + 2]]; }

  function caixaMalha(m) {
    var min = [Infinity, Infinity, Infinity];
    var max = [-Infinity, -Infinity, -Infinity];
    for (var i = 0; i < m.vertices.length; i += 3) {
      for (var k = 0; k < 3; k++) {
        var v = m.vertices[i + k];
        if (v < min[k]) min[k] = v;
        if (v > max[k]) max[k] = v;
      }
    }
    if (!Number.isFinite(min[0])) return { min: [0, 0, 0], max: [0, 0, 0], tamanho: [0, 0, 0] };
    return { min: min, max: max, tamanho: [max[0] - min[0], max[1] - min[1], max[2] - min[2]] };
  }

  /** Volume por soma de tetraedros assinados (divergence theorem) e área das faces. */
  function volumeArea(m) {
    var volume = 0, area = 0;
    m.triangulos.forEach(function (t) {
      var a = vertice(m, t[0]), b = vertice(m, t[1]), c = vertice(m, t[2]);
      volume += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6;
      var ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
      var vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
      var cx = uy * vz - uz * vy, cy = uz * vx - ux * vz, cz = ux * vy - uy * vx;
      area += Math.sqrt(cx * cx + cy * cy + cz * cz) / 2;
    });
    return { volume: Math.abs(volume), area: area };
  }

  /** Malha fechada: toda aresta compartilhada por exatamente dois triângulos. */
  function manifold(m) {
    var mapa = {};
    function chave(a, b) {
      var p = vertice(m, a), q = vertice(m, b);
      var r = function (n) { return Math.round(n * 1000) / 1000; };
      var ka = r(p[0]) + ',' + r(p[1]) + ',' + r(p[2]);
      var kb = r(q[0]) + ',' + r(q[1]) + ',' + r(q[2]);
      return ka < kb ? ka + '|' + kb : kb + '|' + ka;
    }
    m.triangulos.forEach(function (t) {
      [[t[0], t[1]], [t[1], t[2]], [t[2], t[0]]].forEach(function (e) {
        var k = chave(e[0], e[1]);
        mapa[k] = (mapa[k] || 0) + 1;
      });
    });
    var abertas = 0;
    Object.keys(mapa).forEach(function (k) { if (mapa[k] !== 2) abertas++; });
    return { fechada: abertas === 0, arestasAbertas: abertas };
  }

  function textoBytes(txt) {
    var t = String(txt == null ? '' : txt);
    if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(t);
    var saida = new Uint8Array(t.length);
    for (var i = 0; i < t.length; i++) saida[i] = t.charCodeAt(i) & 0xff;
    return saida;
  }
  function bytesTexto(bytes) {
    if (typeof TextDecoder !== 'undefined') return new TextDecoder('utf-8').decode(bytes);
    var s = '';
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return s;
  }
  function paraBytes(d) {
    if (d instanceof Uint8Array) return d;
    if (typeof ArrayBuffer !== 'undefined' && d instanceof ArrayBuffer) return new Uint8Array(d);
    if (Array.isArray(d)) return new Uint8Array(d);
    if (typeof d === 'string') return textoBytes(d);
    return null;
  }
  function texto(d) {
    if (typeof d === 'string') return d;
    var b = paraBytes(d);
    return b ? bytesTexto(b) : '';
  }

  /* ---------- DXF: desenho técnico 2D + faces 3D (ASCII R12) ---------- */
  function numDxf(n) {
    var v = Math.round(Number(n) * 1e6) / 1e6;
    return String(Number.isFinite(v) ? v : 0);
  }

  function paraDxf(doc, opcoes) {
    var m = malha(doc, opcoes);
    if (!m.triangulos.length) return erro('Nada para desenhar em DXF.');
    var L = [];
    function g(codigo, valor) { L.push(String(codigo), String(valor)); }
    var cx = caixaMalha(m);
    g(0, 'SECTION'); g(2, 'HEADER');
    g(9, '$ACADVER'); g(1, 'AC1009');
    g(9, '$INSUNITS'); g(70, doc.unidades === 'm' ? 6 : doc.unidades === 'cm' ? 5 : doc.unidades === 'pol' ? 1 : 4);
    g(9, '$EXTMIN'); g(10, numDxf(cx.min[0])); g(20, numDxf(cx.min[1])); g(30, numDxf(cx.min[2]));
    g(9, '$EXTMAX'); g(10, numDxf(cx.max[0])); g(20, numDxf(cx.max[1])); g(30, numDxf(cx.max[2]));
    g(0, 'ENDSEC');
    // Tabela de camadas: cada objeto ganha a sua, com cor estável.
    g(0, 'SECTION'); g(2, 'TABLES');
    g(0, 'TABLE'); g(2, 'LAYER'); g(70, String(doc.objetos.length + 1));
    g(0, 'LAYER'); g(2, '0'); g(70, '0'); g(62, '7'); g(6, 'CONTINUOUS');
    doc.objetos.forEach(function (obj, i) {
      g(0, 'LAYER'); g(2, camada(obj, i)); g(70, '0'); g(62, String(1 + (i % 6))); g(6, 'CONTINUOUS');
    });
    g(0, 'ENDTAB'); g(0, 'ENDSEC');
    g(0, 'SECTION'); g(2, 'ENTITIES');
    // Vista em planta, em linhas, para quem abre o DXF em 2D.
    g(0, 'POLYLINE'); g(8, 'CONTORNO'); g(66, '1'); g(70, '1'); g(10, '0'); g(20, '0'); g(30, '0');
    [[cx.min[0], cx.min[1]], [cx.max[0], cx.min[1]], [cx.max[0], cx.max[1]], [cx.min[0], cx.max[1]]].forEach(function (pt) {
      g(0, 'VERTEX'); g(8, 'CONTORNO'); g(10, numDxf(pt[0])); g(20, numDxf(pt[1])); g(30, '0');
    });
    g(0, 'SEQEND'); g(8, 'CONTORNO');
    // Faces 3D: o desenho real do sólido.
    m.triangulos.forEach(function (t) {
      g(0, '3DFACE'); g(8, 'JARVIS-3D'); g(62, '5');
      for (var k = 0; k < 4; k++) {
        var idx = t[Math.min(k, 2)];
        g(10 + k, numDxf(m.vertices[idx * 3]));
        g(20 + k, numDxf(m.vertices[idx * 3 + 1]));
        g(30 + k, numDxf(m.vertices[idx * 3 + 2]));
      }
      g(70, '0');
    });
    g(0, 'ENDSEC'); g(0, 'EOF');
    var saida = L.join('\n') + '\n';
    var volta = lerDxf(saida);
    return {
      ok: true,
      formato: 'dxf',
      nome: nomeComExtensao(doc.nome, '.dxf'),
      texto: saida,
      bytes: bytesDe(saida),
      avisos: doc.unidades === 'pol' ? ['polegadas declaradas no cabeçalho ($INSUNITS = 1)'] : [],
      perdas: ['sem sólidos paramétricos: o DXF leva a malha facetada, não a árvore de features'],
      validacao: volta.ok ? { ok: true, entidades: volta.contagem, caixa: volta.caixa } : { ok: false, erro: volta.erro }
    };
  }

  function camada(obj, i) { return limpar((obj.nome || obj.tipo) + '-' + (i + 1), 40).replace(/[^A-Za-z0-9_-]+/g, '-'); }
  function nomeComExtensao(nome, ext) {
    return limpar(nome, 80).replace(/\.[a-z0-9]+$/i, '').replace(/[\\/:*?"<>|]+/g, '-').replace(/\s+/g, '-').replace(/^[-.]+/, '') + ext;
  }

  function lerDxf(entrada) {
    var t = texto(entrada);
    if (!t.trim()) return erro('DXF vazio.');
    if (t.indexOf('SECTION') < 0) return erro('Isto não parece um DXF: falta a seção SECTION.');
    var linhas = t.replace(/\r\n?/g, '\n').split('\n');
    var pares = [];
    for (var i = 0; i + 1 < linhas.length; i += 2) {
      var codigo = parseInt(String(linhas[i]).trim(), 10);
      if (!Number.isFinite(codigo)) { i -= 1; continue; }
      pares.push([codigo, linhas[i + 1]]);
    }
    var contagem = {};
    var camadas = {};
    var min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
    var atual = null;
    var coords = [];
    function acumular() {
      for (var k = 0; k + 2 < coords.length; k += 3) {
        for (var a = 0; a < 3; a++) {
          var v = coords[k + a];
          if (!Number.isFinite(v)) continue;
          if (v < min[a]) min[a] = v;
          if (v > max[a]) max[a] = v;
        }
      }
    }
    pares.forEach(function (p) {
      var c = p[0], v = String(p[1]).trim();
      if (c === 0) {
        if (atual) { contagem[atual] = (contagem[atual] || 0) + 1; acumular(); }
        atual = v; coords = [];
        return;
      }
      if (c === 8 && atual && atual !== 'SECTION' && atual !== 'TABLE') camadas[v] = (camadas[v] || 0) + 1;
      if (c >= 10 && c <= 18) coords.push(Number(v));
      else if (c >= 20 && c <= 28) coords.push(Number(v));
      else if (c >= 30 && c <= 38) coords.push(Number(v));
      else if (c === 40 && atual === 'CIRCLE') coords.push(Number(v));
    });
    if (atual) { contagem[atual] = (contagem[atual] || 0) + 1; acumular(); }
    var total = Object.keys(contagem).reduce(function (s, k) { return s + contagem[k]; }, 0);
    if (!total) return erro('O DXF não tem entidades: nada para analisar.');
    var tamanho = Number.isFinite(min[0])
      ? [max[0] - min[0], max[1] - min[1], max[2] - min[2]]
      : [0, 0, 0];
    var ordem = Object.keys(contagem).sort(function (a, b) { return contagem[b] - contagem[a]; }).slice(0, 6);
    return {
      ok: true,
      formato: 'dxf',
      contagem: contagem,
      camadas: Object.keys(camadas),
      caixa: { min: min.map(function (v) { return Number.isFinite(v) ? v : 0; }), max: max.map(function (v) { return Number.isFinite(v) ? v : 0; }), tamanho: tamanho },
      resumo: 'DXF com ' + total + ' entidade(s): ' + ordem.map(function (k) { return k + ' ' + contagem[k]; }).join(', ') +
        '. Camadas: ' + (Object.keys(camadas).length ? Object.keys(camadas).slice(0, 8).join(', ') : 'nenhuma') +
        '. Extensão ' + formatar(tamanho[0]) + ' × ' + formatar(tamanho[1]) + ' × ' + formatar(tamanho[2]) + '.'
    };
  }

  /* ---------- STL: malha de impressão 3D, binário e ASCII ---------- */
  function paraStlAscii(doc, opcoes) {
    var m = malha(doc, opcoes);
    if (!m.triangulos.length) return erro('Nada para exportar em STL.');
    var L = ['solid ' + (limpar(doc.nome, 60) || 'jarvis')];
    m.triangulos.forEach(function (t) {
      var a = vertice(m, t[0]), b = vertice(m, t[1]), c = vertice(m, t[2]);
      var ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
      var vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
      var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      var mod = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1;
      L.push('  facet normal ' + (nx / mod).toFixed(6) + ' ' + (ny / mod).toFixed(6) + ' ' + (nz / mod).toFixed(6));
      L.push('    outer loop');
      [a, b, c].forEach(function (p) {
        L.push('      vertex ' + p[0].toFixed(6) + ' ' + p[1].toFixed(6) + ' ' + p[2].toFixed(6));
      });
      L.push('    endloop');
      L.push('  endfacet');
    });
    L.push('endsolid');
    var saida = L.join('\n') + '\n';
    var volta = lerStl(saida);
    var va = volumeArea(m);
    return {
      ok: true, formato: 'stl', binario: false,
      nome: nomeComExtensao(doc.nome, '.stl'),
      texto: saida, bytes: bytesDe(saida),
      triangulos: m.triangulos.length, volume: va.volume, area: va.area,
      avisos: [],
      perdas: ['STL não guarda unidades, camadas nem nomes de objetos; a unidade fica no documento, não no arquivo'],
      validacao: volta.ok ? { ok: true, triangulos: volta.triangulos.length, fechada: volta.manifold.fechada } : { ok: false, erro: volta.erro }
    };
  }

  function paraStlBinario(doc, opcoes) {
    var m = malha(doc, opcoes);
    if (!m.triangulos.length) return erro('Nada para exportar em STL.');
    var total = m.triangulos.length;
    var buffer = new ArrayBuffer(84 + total * 50);
    var dv = new DataView(buffer);
    var cabecalho = textoBytes('J.A.R.V.I.S. Nova · ' + (limpar(doc.nome, 40) || 'modelo'));
    var cab = new Uint8Array(buffer, 0, 80);
    cab.set(cabecalho.slice(0, 80));
    dv.setUint32(80, total, true);
    var off = 84;
    m.triangulos.forEach(function (t) {
      var a = vertice(m, t[0]), b = vertice(m, t[1]), c = vertice(m, t[2]);
      var ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
      var vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
      var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      var mod = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1;
      dv.setFloat32(off, nx / mod, true); dv.setFloat32(off + 4, ny / mod, true); dv.setFloat32(off + 8, nz / mod, true);
      var o2 = off + 12;
      [a, b, c].forEach(function (p) {
        dv.setFloat32(o2, p[0], true); dv.setFloat32(o2 + 4, p[1], true); dv.setFloat32(o2 + 8, p[2], true);
        o2 += 12;
      });
      dv.setUint16(off + 48, 0, true);
      off += 50;
    });
    var bytes = new Uint8Array(buffer);
    var volta = lerStl(bytes);
    var va = volumeArea(m);
    return {
      ok: true, formato: 'stl', binario: true,
      nome: nomeComExtensao(doc.nome, '.stl'),
      dados: bytes, bytes: bytes.length,
      triangulos: total, volume: va.volume, area: va.area,
      avisos: [],
      perdas: ['STL não guarda unidades nem nomes de objetos'],
      validacao: volta.ok ? { ok: true, triangulos: volta.triangulos.length, fechada: volta.manifold.fechada } : { ok: false, erro: volta.erro }
    };
  }

  function lerStl(entrada) {
    var bytes = paraBytes(entrada);
    if (!bytes || !bytes.length) return erro('STL vazio.');
    var dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    var binario = false;
    if (bytes.length >= 84) {
      var n = dv.getUint32(80, true);
      if (n > 0 && bytes.length === 84 + n * 50) binario = true;
    }
    var vertices = [];
    var triangulos = [];
    if (binario) {
      var total = dv.getUint32(80, true);
      if (total > 2000000) return erro('STL com ' + total + ' triângulos: acima do limite de 2 milhões.');
      for (var i = 0; i < total; i++) {
        var base = 84 + i * 50 + 12;
        var ids = [];
        for (var k = 0; k < 3; k++) {
          ids.push(vertices.length / 3);
          vertices.push(dv.getFloat32(base + k * 12, true), dv.getFloat32(base + k * 12 + 4, true), dv.getFloat32(base + k * 12 + 8, true));
        }
        triangulos.push(ids);
      }
    } else {
      var t = bytesTexto(bytes);
      if (t.toLowerCase().indexOf('facet') < 0) return erro('Isto não parece um STL: não há "facet" nem cabeçalho binário válido.');
      var achados = t.match(/vertex\s+(-?[\d.eE+]+)\s+(-?[\d.eE+]+)\s+(-?[\d.eE+]+)/g) || [];
      if (!achados.length) return erro('STL sem vértices legíveis.');
      if (achados.length % 3 !== 0) return erro('STL com ' + achados.length + ' vértices: não é múltiplo de 3.');
      for (var j = 0; j < achados.length; j += 3) {
        var ids2 = [];
        for (var k2 = 0; k2 < 3; k2++) {
          var nums = achados[j + k2].replace('vertex', '').trim().split(/\s+/).map(Number);
          if (nums.some(function (v) { return !Number.isFinite(v); })) return erro('Coordenada inválida no STL (vértice ' + (j + k2 + 1) + ').');
          ids2.push(vertices.length / 3);
          vertices.push(nums[0], nums[1], nums[2]);
        }
        triangulos.push(ids2);
      }
    }
    var m = { vertices: vertices, triangulos: triangulos };
    var cx = caixaMalha(m);
    var va = volumeArea(m);
    var mf = manifold(m);
    return {
      ok: true, formato: 'stl', binario: binario,
      triangulos: triangulos, vertices: vertices.length / 3,
      caixa: cx, volume: va.volume, area: va.area, manifold: mf,
      resumo: 'STL ' + (binario ? 'binário' : 'ASCII') + ': ' + triangulos.length + ' triângulo(s), ' +
        (vertices.length / 3) + ' vértices, extensão ' + formatar(cx.tamanho[0]) + ' × ' + formatar(cx.tamanho[1]) +
        ' × ' + formatar(cx.tamanho[2]) + ', volume ' + formatar(va.volume) + ', ' +
        (mf.fechada ? 'malha fechada (pronta para fatiar)' : 'malha com ' + mf.arestasAbertas + ' aresta(s) aberta(s)') + '.'
    };
  }

  /* ---------- 3MF: ZIP + XML (padrão de impressão 3D moderno) ---------- */
  var TABELA_CRC = (function () {
    var t = new Uint32Array(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      t[n] = c >>> 0;
    }
    return t;
  })();
  function crc32(bytes) {
    var c = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) c = TABELA_CRC[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }
  /** ZIP sem compressão (método 0): válido e legível por qualquer slicer ou leitor de 3MF. */
  function zipStore(arquivos) {
    var locais = [];
    var centrais = [];
    var deslocamento = 0;
    arquivos.forEach(function (a) {
      var nome = textoBytes(a.nome);
      var dados = a.dados;
      var crc = crc32(dados);
      var cab = new Uint8Array(30 + nome.length);
      var dv = new DataView(cab.buffer);
      dv.setUint32(0, 0x04034b50, true);
      dv.setUint16(4, 20, true);
      dv.setUint16(6, 0x0800, true);
      dv.setUint16(8, 0, true);
      dv.setUint32(14, crc, true);
      dv.setUint32(18, dados.length, true);
      dv.setUint32(22, dados.length, true);
      dv.setUint16(26, nome.length, true);
      cab.set(nome, 30);
      locais.push(cab, dados);
      var cd = new Uint8Array(46 + nome.length);
      var dv2 = new DataView(cd.buffer);
      dv2.setUint32(0, 0x02014b50, true);
      dv2.setUint16(4, 20, true);
      dv2.setUint16(6, 20, true);
      dv2.setUint16(8, 0x0800, true);
      dv2.setUint32(16, crc, true);
      dv2.setUint32(20, dados.length, true);
      dv2.setUint32(24, dados.length, true);
      dv2.setUint16(28, nome.length, true);
      dv2.setUint32(42, deslocamento, true);
      cd.set(nome, 46);
      centrais.push(cd);
      deslocamento += cab.length + dados.length;
    });
    var tamanhoCentral = centrais.reduce(function (s, c) { return s + c.length; }, 0);
    var eocd = new Uint8Array(22);
    var dv3 = new DataView(eocd.buffer);
    dv3.setUint32(0, 0x06054b50, true);
    dv3.setUint16(8, arquivos.length, true);
    dv3.setUint16(10, arquivos.length, true);
    dv3.setUint32(12, tamanhoCentral, true);
    dv3.setUint32(16, deslocamento, true);
    var total = deslocamento + tamanhoCentral + 22;
    var saida = new Uint8Array(total);
    var pos = 0;
    locais.concat(centrais, [eocd]).forEach(function (parte) { saida.set(parte, pos); pos += parte.length; });
    return saida;
  }

  function lerZip(bytes) {
    var dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    var eocd = -1;
    for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65558; i--) {
      if (dv.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) return erro('3MF inválido: não achei o índice do ZIP (EOCD).');
    var total = dv.getUint16(eocd + 10, true);
    var inicio = dv.getUint32(eocd + 16, true);
    if (total > 2000) return erro('ZIP com ' + total + ' arquivos: acima do limite.');
    var itens = [];
    var p = inicio;
    for (var k = 0; k < total; k++) {
      if (p + 46 > bytes.length || dv.getUint32(p, true) !== 0x02014b50) break;
      var metodo = dv.getUint16(p + 10, true);
      var tam = dv.getUint32(p + 20, true);
      var nomeTam = dv.getUint16(p + 28, true);
      var extraTam = dv.getUint16(p + 30, true);
      var comentTam = dv.getUint16(p + 32, true);
      var offset = dv.getUint32(p + 42, true);
      var nome = bytesTexto(bytes.subarray(p + 46, p + 46 + nomeTam));
      itens.push({ nome: nome, metodo: metodo, tamanho: tam, offset: offset });
      p += 46 + nomeTam + extraTam + comentTam;
    }
    return { ok: true, itens: itens, bytes: bytes, dv: dv };
  }

  function dadosZip(item, zip) {
    var dv = zip.dv;
    var cabNome = dv.getUint16(item.offset + 26, true);
    var cabExtra = dv.getUint16(item.offset + 28, true);
    var inicio = item.offset + 30 + cabNome + cabExtra;
    return zip.bytes.subarray(inicio, inicio + item.tamanho);
  }

  async function inflar(dados) {
    if (typeof DecompressionStream === 'function') {
      try {
        var ds = new DecompressionStream('deflate-raw');
        var buffer = await new Response(new Blob([dados]).stream().pipeThrough(ds)).arrayBuffer();
        return new Uint8Array(buffer);
      } catch (e) { throw new Error('não consegui descompactar (deflate-raw): ' + ((e && e.message) || e)); }
    }
    throw new Error('este ambiente não descompacta ZIP com deflate; peça um 3MF sem compressão');
  }

  function escaparXml(t) {
    return String(t == null ? '' : t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function para3mf(doc, opcoes) {
    var m = malha(doc, opcoes);
    if (!m.triangulos.length) return erro('Nada para exportar em 3MF.');
    var unidade = doc.unidades === 'm' ? 'meter' : doc.unidades === 'cm' ? 'centimeter' : doc.unidades === 'pol' ? 'inch' : 'millimeter';
    var v = [];
    for (var i = 0; i < m.vertices.length; i += 3) {
      v.push('          <vertex x="' + numDxf(m.vertices[i]) + '" y="' + numDxf(m.vertices[i + 1]) + '" z="' + numDxf(m.vertices[i + 2]) + '"/>');
    }
    var t = m.triangulos.map(function (f) {
      return '          <triangle v1="' + f[0] + '" v2="' + f[1] + '" v3="' + f[2] + '"/>';
    });
    var modelo = '<?xml version="1.0" encoding="UTF-8"?>\n' +
      '<model unit="' + unidade + '" xml:lang="pt-BR" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">\n' +
      '  <metadata name="Title">' + escaparXml(doc.nome) + '</metadata>\n' +
      '  <metadata name="Application">J.A.R.V.I.S. Nova</metadata>\n' +
      '  <resources>\n' +
      '    <object id="1" type="model" name="' + escaparXml(doc.nome) + '">\n' +
      '      <mesh>\n        <vertices>\n' + v.join('\n') + '\n        </vertices>\n' +
      '        <triangles>\n' + t.join('\n') + '\n        </triangles>\n      </mesh>\n' +
      '    </object>\n  </resources>\n  <build>\n    <item objectid="1"/>\n  </build>\n</model>\n';
    var contentTypes = '<?xml version="1.0" encoding="UTF-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n' +
      '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n' +
      '  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n</Types>\n';
    var rels = '<?xml version="1.0" encoding="UTF-8"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n' +
      '  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n</Relationships>\n';
    var arquivos = [
      { nome: '[Content_Types].xml', dados: textoBytes(contentTypes) },
      { nome: '_rels/.rels', dados: textoBytes(rels) },
      { nome: '3D/3dmodel.model', dados: textoBytes(modelo) }
    ];
    var dados = zipStore(arquivos);
    return {
      ok: true, formato: '3mf',
      nome: nomeComExtensao(doc.nome, '.3mf'),
      dados: dados, bytes: dados.length,
      triangulos: m.triangulos.length,
      avisos: ['ZIP sem compressão: abre em qualquer slicer, com arquivo um pouco maior que o usual'],
      perdas: ['3MF aceita materiais e cores por face; aqui vai só a geometria e o nome'],
      validacao: { ok: true, triangulos: m.triangulos.length }
    };
  }

  async function ler3mf(entrada) {
    var bytes = paraBytes(entrada);
    if (!bytes || !bytes.length) return erro('3MF vazio.');
    if (bytes[0] !== 0x50 || bytes[1] !== 0x4b) return erro('Isto não é um 3MF: falta a assinatura ZIP (PK).');
    var zip = lerZip(bytes);
    if (!zip.ok) return zip;
    var alvo = zip.itens.filter(function (x) { return /\.model$/i.test(x.nome); })[0];
    if (!alvo) return erro('3MF sem arquivo .model: pacote incompleto.');
    var cru = dadosZip(alvo, zip);
    var xml;
    if (alvo.metodo === 0) xml = bytesTexto(cru);
    else if (alvo.metodo === 8) {
      try { xml = bytesTexto(await inflar(cru)); }
      catch (e) { return erro('3MF comprimido que este ambiente não descompacta: ' + ((e && e.message) || e)); }
    } else return erro('3MF com método de compressão ' + alvo.metodo + ', não suportado.');
    if (xml.indexOf('3dmanufacturing') < 0 && xml.indexOf('<model') < 0) return erro('O .model do 3MF não tem a marcação esperada.');
    var vertices = (xml.match(/<vertex\s/g) || []).length;
    var triangulos = (xml.match(/<triangle\s/g) || []).length;
    var unidadeM = xml.match(/unit="([a-z]+)"/i);
    var coords = [];
    var re = /<vertex\s+x="([-\d.eE+]+)"\s+y="([-\d.eE+]+)"\s+z="([-\d.eE+]+)"/g;
    var achado;
    while ((achado = re.exec(xml)) && coords.length < 300000) {
      coords.push(Number(achado[1]), Number(achado[2]), Number(achado[3]));
    }
    var m = { vertices: coords, triangulos: [] };
    var cx = caixaMalha(m);
    return {
      ok: true, formato: '3mf', vertices: vertices, triangulos: triangulos,
      unidade: unidadeM ? unidadeM[1] : 'millimeter', caixa: cx,
      resumo: '3MF com ' + triangulos + ' triângulo(s) e ' + vertices + ' vértice(s), unidade ' +
        (unidadeM ? unidadeM[1] : 'não declarada') + ', extensão ' + formatar(cx.tamanho[0]) + ' × ' +
        formatar(cx.tamanho[1]) + ' × ' + formatar(cx.tamanho[2]) + '.'
    };
  }

  /* ---------- STEP: ISO 10303-21 com faces planas (AP203/AP214) ---------- */
  function stf(n) {
    var v = Number(n);
    if (!Number.isFinite(v)) v = 0;
    var r = Math.round(v * 1e6) / 1e6;
    return Math.abs(r % 1) < 1e-9 ? r.toFixed(1) : String(r);
  }
  function guidIfc(semente) {
    var alfabeto = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$';
    var h = 2166136261;
    var s = String(semente);
    for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = (h * 16777619) >>> 0; }
    var saida = '';
    for (var k = 0; k < 22; k++) { h = (h * 1103515245 + 12345) >>> 0; saida += alfabeto[h % 64]; }
    return saida;
  }

  function paraStep(doc, opcoes) {
    var o = opcoes || {};
    var m = malha(doc, o);
    if (!m.triangulos.length) return erro('Nada para exportar em STEP.');
    var limite = Number(o.limiteTriangulos) || 6000;
    if (m.triangulos.length > limite) {
      return erro('STEP com ' + m.triangulos.length + ' triângulos passa do limite de ' + limite + '. Reduza os segmentos ou exporte STL/3MF.');
    }
    var L = [];
    var n = 0;
    function ent(corpo) { n++; L.push('#' + n + '=' + corpo + ';'); return n; }
    ent("APPLICATION_CONTEXT('core data for automotive mechanical design processes')");
    ent("APPLICATION_PROTOCOL_DEFINITION('international standard','automotive_design',2000,#1)");
    var ctxProduto = ent("PRODUCT_CONTEXT('',#1,'mechanical')");
    var produto = ent("PRODUCT('" + escaparStep(doc.nome) + "','" + escaparStep(doc.nome) + "','',(#" + ctxProduto + '))');
    var formacao = ent("PRODUCT_DEFINITION_FORMATION('','',#" + produto + ')');
    var ctxDef = ent("PRODUCT_DEFINITION_CONTEXT('part definition',#1,'design')");
    var definicao = ent("PRODUCT_DEFINITION('design','',#" + formacao + ',#' + ctxDef + ')');
    var formaProduto = ent("PRODUCT_DEFINITION_SHAPE('','',#" + definicao + ')');
    var mm = ent('(LENGTH_UNIT()NAMED_UNIT(*)SI_UNIT(.MILLI.,.METRE.))');
    var rad = ent('(NAMED_UNIT(*)PLANE_ANGLE_UNIT()SI_UNIT($,.RADIAN.))');
    var sr = ent('(NAMED_UNIT(*)SI_UNIT($,.STERADIAN.)SOLID_ANGLE_UNIT())');
    var incerteza = ent("UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(1.E-07),#" + mm + ",'distance_accuracy_value','')");
    var ctxGeo = ent('(GEOMETRIC_REPRESENTATION_CONTEXT(3)GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#' + incerteza +
      '))GLOBAL_UNIT_ASSIGNED_CONTEXT((#' + mm + ',#' + rad + ',#' + sr + '))REPRESENTATION_CONTEXT(\'\',\'\'))');
    var origem = ent("CARTESIAN_POINT('',(0.,0.,0.))");
    var dz = ent("DIRECTION('',(0.,0.,1.))");
    var dx = ent("DIRECTION('',(1.,0.,0.))");
    var eixo = ent("AXIS2_PLACEMENT_3D('',#" + origem + ',#' + dz + ',#' + dx + ')');
    var faces = [];
    m.triangulos.forEach(function (t) {
      var a = vertice(m, t[0]), b = vertice(m, t[1]), c = vertice(m, t[2]);
      var pa = ent("CARTESIAN_POINT('',(" + stf(a[0]) + ',' + stf(a[1]) + ',' + stf(a[2]) + '))');
      var pb = ent("CARTESIAN_POINT('',(" + stf(b[0]) + ',' + stf(b[1]) + ',' + stf(b[2]) + '))');
      var pc = ent("CARTESIAN_POINT('',(" + stf(c[0]) + ',' + stf(c[1]) + ',' + stf(c[2]) + '))');
      var laco = ent("POLY_LOOP('',(#" + pa + ',#' + pb + ',#' + pc + '))');
      var limiteFace = ent("FACE_OUTER_BOUND('',#" + laco + ',.T.)');
      var ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
      var vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
      var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      var mod = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1;
      var normal = ent("DIRECTION('',(" + stf(nx / mod) + ',' + stf(ny / mod) + ',' + stf(nz / mod) + '))');
      var ref = Math.abs(nx / mod) < 0.9 ? [1, 0, 0] : [0, 1, 0];
      var refDir = ent("DIRECTION('',(" + stf(ref[0]) + ',' + stf(ref[1]) + ',' + stf(ref[2]) + '))');
      var colocacao = ent("AXIS2_PLACEMENT_3D('',#" + pa + ',#' + normal + ',#' + refDir + ')');
      var plano = ent("PLANE('',#" + colocacao + ')');
      faces.push(ent("ADVANCED_FACE('',(#" + limiteFace + '),#' + plano + ',.T.)'));
    });
    var casca = ent("CLOSED_SHELL('',(" + faces.map(function (f) { return '#' + f; }).join(',') + '))');
    var solido = ent("MANIFOLD_SOLID_BREP('" + escaparStep(doc.nome) + "',#" + casca + ')');
    var repr = ent("ADVANCED_BREP_SHAPE_REPRESENTATION('',(#" + solido + ',#' + eixo + '),#' + ctxGeo + ')');
    ent('SHAPE_DEFINITION_REPRESENTATION(#' + formaProduto + ',#' + repr + ')');
    var agora = new Date();
    var carimbo = agora.getUTCFullYear() + '-' + String(agora.getUTCMonth() + 1).padStart(2, '0') + '-' +
      String(agora.getUTCDate()).padStart(2, '0') + 'T' + String(agora.getUTCHours()).padStart(2, '0') + ':' +
      String(agora.getUTCMinutes()).padStart(2, '0') + ':' + String(agora.getUTCSeconds()).padStart(2, '0');
    var saida = 'ISO-10303-21;\nHEADER;\n' +
      "FILE_DESCRIPTION(('J.A.R.V.I.S. Nova faceted solid'),'2;1');\n" +
      "FILE_NAME('" + escaparStep(nomeComExtensao(doc.nome, '.step')) + "','" + carimbo + "',('J.A.R.V.I.S. Nova'),(''),'','J.A.R.V.I.S. Nova','');\n" +
      "FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));\nENDSEC;\nDATA;\n" + L.join('\n') + '\nENDSEC;\nEND-ISO-10303-21;\n';
    var volta = lerStep(saida);
    var va = volumeArea(m);
    return {
      ok: true, formato: 'step',
      nome: nomeComExtensao(doc.nome, '.step'),
      texto: saida, bytes: bytesDe(saida),
      triangulos: m.triangulos.length, entidades: n, volume: va.volume, area: va.area,
      avisos: ['faces planas trianguladas: é um sólido facetado, não um B-rep com arcos e planos ideais'],
      perdas: ['sem histórico paramétrico (features), tolerâncias, materiais ou cores'],
      validacao: volta.ok ? { ok: volta.referenciasQuebradas === 0, entidades: volta.entidades, referenciasQuebradas: volta.referenciasQuebradas } : { ok: false, erro: volta.erro }
    };
  }
  function escaparStep(t) { return String(t == null ? '' : t).replace(/'/g, "''").replace(/[\r\n]+/g, ' ').slice(0, 120); }

  function lerStep(entrada) {
    var t = texto(entrada);
    if (t.indexOf('ISO-10303-21') < 0) return erro('Isto não é STEP: falta o cabeçalho ISO-10303-21.');
    var dataInicio = t.indexOf('DATA;');
    if (dataInicio < 0) return erro('STEP sem seção DATA.');
    var corpo = t.slice(dataInicio + 5, t.indexOf('ENDSEC;', dataInicio));
    var linhas = corpo.split(';');
    var definidos = {};
    var entidades = 0;
    var tipos = {};
    linhas.forEach(function (linha) {
      var m = linha.match(/#(\d+)\s*=\s*([A-Z_0-9(]+)/);
      if (!m) return;
      definidos[m[1]] = true;
      entidades++;
      var tipo = m[2].replace(/\($/, '');
      tipos[tipo] = (tipos[tipo] || 0) + 1;
    });
    var quebradas = 0;
    var re = /#(\d+)/g;
    var achado;
    while ((achado = re.exec(corpo))) {
      if (!definidos[achado[1]]) quebradas++;
    }
    var pontos = [];
    var rePonto = /CARTESIAN_POINT\('',\(([-\d.eE+]+),([-\d.eE+]+),([-\d.eE+]+)\)\)/g;
    while ((achado = rePonto.exec(corpo)) && pontos.length < 300000) {
      pontos.push(Number(achado[1]), Number(achado[2]), Number(achado[3]));
    }
    var cx = caixaMalha({ vertices: pontos, triangulos: [] });
    var faces = (tipos.ADVANCED_FACE || 0) + (tipos.FACE || 0);
    return {
      ok: true, formato: 'step', entidades: entidades, tipos: tipos, referenciasQuebradas: quebradas,
      caixa: cx, faces: faces,
      resumo: 'STEP com ' + entidades + ' entidade(s), ' + faces + ' face(s) e ' + pontos.length / 3 +
        ' ponto(s). Entre pontos de inserção: ' + formatar(cx.tamanho[0]) + ' × ' + formatar(cx.tamanho[1]) + ' × ' +
        formatar(cx.tamanho[2]) + '. ' + (quebradas ? quebradas + ' referência(s) sem definição.' : 'Todas as referências resolvem.')
    };
  }

  /* ---------- IFC: modelo BIM (IFC4, subconjunto de transferência) ---------- */
  function paraIfc(doc, opcoes) {
    var m = malha(doc, opcoes);
    if (!m.triangulos.length) return erro('Nada para exportar em IFC.');
    if (doc.objetos.length > 200) return erro('IFC com ' + doc.objetos.length + ' elementos passa do limite de 200 neste exportador.');
    var L = [];
    var n = 0;
    function ent(c) { n++; L.push('#' + n + '=' + c + ';'); return n; }
    var carimbo = Math.floor(Date.now() / 1000);
    var pessoa = ent("IFCPERSON($,'Jarvis','Nova',$,$,$,$,$)");
    var org = ent("IFCORGANIZATION($,'J.A.R.V.I.S. Nova',$,$,$)");
    var pessoaOrg = ent('IFCPERSONANDORGANIZATION(#' + pessoa + ',#' + org + ',$)');
    var app = ent("IFCAPPLICATION(#" + org + ",'1.19.0','J.A.R.V.I.S. Nova','JARNOVA')");
    var historico = ent('IFCOWNERHISTORY(#' + pessoaOrg + ',#' + app + ',$,.ADDED.,$,$,$,' + carimbo + ')');
    var p0 = ent('IFCCARTESIANPOINT((0.,0.,0.))');
    var dZ = ent('IFCDIRECTION((0.,0.,1.))');
    var dX = ent('IFCDIRECTION((1.,0.,0.))');
    var eixo = ent('IFCAXIS2PLACEMENT3D(#' + p0 + ',#' + dZ + ',#' + dX + ')');
    var local0 = ent('IFCLOCALPLACEMENT($,#' + eixo + ')');
    var uCompr = ent('IFCSIUNIT(*,.LENGTHUNIT.,.MILLI.,.METRE.)');
    var uArea = ent('IFCSIUNIT(*,.AREAUNIT.,$,.SQUARE_METRE.)');
    var uVol = ent('IFCSIUNIT(*,.VOLUMEUNIT.,$,.CUBIC_METRE.)');
    var uAng = ent('IFCSIUNIT(*,.PLANEANGLEUNIT.,$,.RADIAN.)');
    var unidades = ent('IFCUNITASSIGNMENT((#' + uCompr + ',#' + uArea + ',#' + uVol + ',#' + uAng + '))');
    var projeto = ent("IFCPROJECT('" + guidIfc('projeto' + doc.nome) + "',$,'" + escaparStep(doc.nome) + "',$,$,$,$,(#" + unidades + '),#' + local0 + ')');
    var sitio = ent("IFCSITE('" + guidIfc('sitio' + doc.nome) + "',$,'Terreno',$,$,#" + local0 + ',$,$,.ELEMENT.,$,$,$,$,$)');
    var edificio = ent("IFCBUILDING('" + guidIfc('edificio' + doc.nome) + "',$,'" + escaparStep(doc.nome) + "',$,$,#" + local0 + ',$,$,.ELEMENT.,$,$,$)');
    var pavimento = ent("IFCBUILDINGSTOREY('" + guidIfc('pavimento' + doc.nome) + "',$,'Nivel 0',$,$,#" + local0 + ',$,$,.ELEMENT.,0.)');
    var ctxGeo = ent('IFCGEOMETRICREPRESENTATIONCONTEXT($,\'Model\',3,1.E-05,#' + eixo + ',$)');
    ent('IFCRELAGGREGATES(\'' + guidIfc('ag1' + doc.nome) + '\',$,$,$,#' + projeto + ',(#' + sitio + '))');
    ent('IFCRELAGGREGATES(\'' + guidIfc('ag2' + doc.nome) + '\',$,$,$,#' + sitio + ',(#' + edificio + '))');
    ent('IFCRELAGGREGATES(\'' + guidIfc('ag3' + doc.nome) + '\',$,$,$,#' + edificio + ',(#' + pavimento + '))');
    var elementos = [];
    var avisos = [];
    var perdidos = [];
    doc.objetos.forEach(function (obj, i) {
      var p = posicao(obj);
      var altura = obj.tipo === 'esfera' ? obj.raio * 2 : obj.tipo === 'plano' ? 1 : obj.altura;
      var largura = obj.tipo === 'esfera' ? obj.raio * 2 : obj.tipo === 'caixa' ? obj.dimensoes[0] : obj.raio * 2;
      var prof = obj.tipo === 'caixa' || obj.tipo === 'plano' ? obj.dimensoes[1] : obj.raio * 2;
      if (obj.tipo === 'esfera') avisos.push('esfera "' + obj.nome + '" virou cilindro de mesmo diâmetro (IFC não tem esfera primitiva)');
      if (obj.tipo === 'plano') avisos.push('plano "' + obj.nome + '" virou laje de 1 mm');
      var base = ent('IFCCARTESIANPOINT((' + stf(p[0]) + ',' + stf(p[1]) + ',' + stf(p[2] - altura / 2) + '))');
      var local = ent('IFCLOCALPLACEMENT(#' + local0 + ',#' + ent('IFCAXIS2PLACEMENT3D(#' + base + ',#' + dZ + ',#' + dX + ')') + ')');
      var pt2 = ent('IFCCARTESIANPOINT((0.,0.))');
      var ax2 = ent('IFCAXIS2PLACEMENT2D(#' + pt2 + ',$)');
      var perfil = obj.tipo === 'cilindro' || obj.tipo === 'cone' || obj.tipo === 'esfera'
        ? ent('IFCCIRCLEPROFILEDEF(.AREA.,$,#' + ax2 + ',' + stf(largura / 2) + ')')
        : ent('IFCRECTANGLEPROFILEDEF(.AREA.,$,#' + ax2 + ',' + stf(largura) + ',' + stf(prof) + ')');
      var solido = ent('IFCEXTRUDEDAREASOLID(#' + perfil + ',#' + eixo + ',#' + dZ + ',' + stf(altura) + ')');
      var repr = ent('IFCSHAPEREPRESENTATION(#' + ctxGeo + ",'Body','SweptSolid',(#" + solido + '))');
      var forma = ent('IFCPRODUCTDEFINITIONSHAPE($,$,(#' + repr + '))');
      elementos.push(ent("IFCBUILDINGELEMENTPROXY('" + guidIfc('el' + i + obj.nome) + "',$,'" + escaparStep(obj.nome) + "',$,$,#" + local + ',#' + forma + ',$,.NOTDEFINED.)'));
    });
    ent('IFCRELCONTAINEDINSPATIALSTRUCTURE(\'' + guidIfc('cont' + doc.nome) + '\',$,$,$,(' +
      elementos.map(function (e) { return '#' + e; }).join(',') + '),#' + pavimento + ')');
    perdidos.push('sem propriedades (IfcPropertySet), materiais ou classificações');
    var saida = 'ISO-10303-21;\nHEADER;\n' +
      "FILE_DESCRIPTION(('ViewDefinition [CoordinationView]'),'2;1');\n" +
      "FILE_NAME('" + escaparStep(nomeComExtensao(doc.nome, '.ifc')) + "','" + new Date().toISOString().slice(0, 19) + "',(''),(''),'','J.A.R.V.I.S. Nova','');\n" +
      "FILE_SCHEMA(('IFC4'));\nENDSEC;\nDATA;\n" + L.join('\n') + '\nENDSEC;\nEND-ISO-10303-21;\n';
    var volta = lerIfc(saida);
    return {
      ok: true, formato: 'ifc',
      nome: nomeComExtensao(doc.nome, '.ifc'),
      texto: saida, bytes: bytesDe(saida),
      entidades: n, elementos: elementos.length,
      avisos: avisos,
      perdas: perdidos,
      validacao: volta.ok ? { ok: volta.entidades === n, entidades: volta.entidades } : { ok: false, erro: volta.erro }
    };
  }

  function lerIfc(entrada) {
    var t = texto(entrada);
    if (t.indexOf('ISO-10303-21') < 0) return erro('Isto não é IFC: falta o cabeçalho ISO-10303-21.');
    var esquema = t.match(/FILE_SCHEMA\s*\(\(\s*'([^']+)'/);
    if (!esquema || !/^IFC/i.test(esquema[1] || '')) return erro('O arquivo é STEP, mas não é IFC (FILE_SCHEMA "' + (esquema ? esquema[1] : '?') + '").');
    var tipos = {};
    var re = /#\d+\s*=\s*IFC([A-Z0-9]+)\s*\(/g;
    var achado;
    var total = 0;
    while ((achado = re.exec(t))) { tipos[achado[1]] = (tipos[achado[1]] || 0) + 1; total++; }
    if (!total) return erro('IFC sem entidades IFC no bloco DATA.');
    var nomes = [];
    var reNome = /IFCBUILDINGELEMENTPROXY\('[^']*',\$,'([^']*)'/g;
    while ((achado = reNome.exec(t)) && nomes.length < 200) nomes.push(achado[1]);
    var pontos = [];
    var rePt = /IFCCARTESIANPOINT\(\(([-\d.eE+]+),([-\d.eE+]+),([-\d.eE+]+)\)\)/g;
    while ((achado = rePt.exec(t)) && pontos.length < 300000) pontos.push(Number(achado[1]), Number(achado[2]), Number(achado[3]));
    var cx = caixaMalha({ vertices: pontos, triangulos: [] });
    return {
      ok: true, formato: 'ifc', esquema: esquema[1], entidades: total, tipos: tipos, elementos: nomes,
      caixa: cx,
      resumo: 'IFC (' + esquema[1] + ') com ' + total + ' entidade(s) e ' + nomes.length + ' elemento(s): ' +
        (nomes.slice(0, 5).join(', ') || 'nenhum') + (nomes.length > 5 ? '…' : '') + '. Pontos de inserção: ' +
        formatar(cx.tamanho[0]) + ' × ' + formatar(cx.tamanho[1]) + ' × ' + formatar(cx.tamanho[2]) + '.'
    };
  }

  /* ---------- Exportação e análise por formato ---------- */
  var FORMATOS = [
    { id: 'cad', nome: '.cad (CadSimu)', tipo: '3D', le: true, escreve: true, edita: true, converte: true, obs: 'formato nativo do aplicativo (JSON documentado, v1)' },
    { id: 'dxf', nome: 'DXF R12', tipo: '2D/3D', le: true, escreve: true, edita: false, converte: true, obs: 'faces 3D + planta em linhas; edição fica no software CAD' },
    { id: 'stl', nome: 'STL (binário e ASCII)', tipo: '3D', le: true, escreve: true, edita: false, converte: true, obs: 'malha para impressão 3D; sem unidades no arquivo' },
    { id: '3mf', nome: '3MF', tipo: '3D', le: true, escreve: true, edita: false, converte: true, obs: 'ZIP+XML; escrita sem compressão, leitura aceita deflate' },
    { id: 'step', nome: 'STEP (AP203)', tipo: '3D', le: true, escreve: true, edita: false, converte: true, obs: 'sólido facetado; exportação experimental, sem histórico paramétrico' },
    { id: 'ifc', nome: 'IFC4', tipo: 'BIM', le: true, escreve: true, edita: false, converte: true, obs: 'subconjunto de transferência: projeto, pavimento e elementos extrudados' },
    { id: 'dwg', nome: 'DWG', tipo: '2D/3D', le: false, escreve: false, edita: false, converte: false, obs: 'binário proprietário da Autodesk: exige biblioteca licenciada (ODA/RealDWG), que não existe aqui' },
    { id: 'rvt', nome: 'Revit (RVT)', tipo: 'BIM', le: false, escreve: false, edita: false, converte: false, obs: 'formato proprietário do Revit, sem leitor livre' },
    { id: 'rfa', nome: 'Revit Family (RFA)', tipo: 'BIM', le: false, escreve: false, edita: false, converte: false, obs: 'formato proprietário do Revit, sem leitor livre' },
    { id: 'fcstd', nome: 'FreeCAD (FCStd)', tipo: '3D', le: false, escreve: false, edita: false, converte: false, obs: 'documento do FreeCAD com árvore paramétrica; precisaria do FreeCAD instalado para gerar/abrir' }
  ];

  function formatoValido(id) {
    var alvo = String(id || '').toLowerCase().replace(/^\./, '');
    var f = FORMATOS.filter(function (x) { return x.id === alvo; })[0];
    if (!f) return null;
    return f.escreve ? f : null;
  }

  /** Exporta para o formato pedido e valida por reabertura. Nunca lança. */
  function exportar(doc, formato, opcoes) {
    var id = String(formato || '').toLowerCase().replace(/^\./, '');
    var f = FORMATOS.filter(function (x) { return x.id === id; })[0];
    if (!f) return erro('Formato "' + limpar(formato, 20) + '" não é conhecido. Disponíveis: ' + FORMATOS.filter(function (x) { return x.escreve; }).map(function (x) { return '.' + x.id; }).join(', ') + '.');
    if (!f.escreve) return erro(f.nome + ' não é gerado aqui: ' + f.obs + '.');
    if (id === 'cad') {
      var txt = serializar(doc);
      var r = parse(txt);
      return { ok: true, formato: 'cad', nome: slug(doc.nome), texto: txt, bytes: bytesDe(txt), avisos: [], perdas: [], validacao: { ok: r.ok } };
    }
    if (id === 'dxf') return paraDxf(doc, opcoes);
    if (id === 'stl') return (opcoes && opcoes.ascii) ? paraStlAscii(doc, opcoes) : paraStlBinario(doc, opcoes);
    if (id === '3mf') return para3mf(doc, opcoes);
    if (id === 'step') return paraStep(doc, opcoes);
    if (id === 'ifc') return paraIfc(doc, opcoes);
    return erro('Formato sem exportador implementado.');
  }

  /** Descobre o formato pelo conteúdo e analisa. STL/3MF podem vir em bytes. */
  async function analisarFormato(conteudo, dica) {
    var nome = String(dica || '').toLowerCase();
    var bytes = paraBytes(conteudo);
    var t = bytes ? bytesTexto(bytes) : '';
    if (bytes && bytes.length > 1 && bytes[0] === 0x50 && bytes[1] === 0x4b) return ler3mf(bytes);
    var cabeca = t.slice(0, 400);
    if (/ISO-10303-21/.test(cabeca)) {
      return /FILE_SCHEMA\s*\(\(\s*'IFC/i.test(t) ? lerIfc(t) : lerStep(t);
    }
    if (/\n?SECTION/.test(t) || /AC1009|AC1015|AC1032/.test(cabeca)) return lerDxf(t);
    if (/\.stl$/.test(nome) || /\bsolid\b[\s\S]*facet/.test(t) || (bytes && bytes.length >= 84 && bytes.length === 84 + (bytes[84] | (bytes[85] << 8) | (bytes[86] << 16) | (bytes[87] << 24)) * 50)) {
      return lerStl(bytes);
    }
    if (/^\s*\{/.test(t)) return analisar(t);
    return erro('Não reconheci o formato. Aceito: .cad, DXF, STL, 3MF, STEP e IFC.');
  }

  function extensaoFormato(nome) {
    var m = String(nome || '').toLowerCase().match(/\.([a-z0-9]+)$/);
    return m ? m[1] : '';
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
    malha: malha,
    caixaMalha: caixaMalha,
    volumeArea: volumeArea,
    manifold: manifold,
    FORMATOS: FORMATOS,
    formatoValido: formatoValido,
    exportar: exportar,
    analisarFormato: analisarFormato,
    extensaoFormato: extensaoFormato,
    paraDxf: paraDxf,
    lerDxf: lerDxf,
    paraStlBinario: paraStlBinario,
    paraStlAscii: paraStlAscii,
    lerStl: lerStl,
    para3mf: para3mf,
    ler3mf: ler3mf,
    paraStep: paraStep,
    lerStep: lerStep,
    paraIfc: paraIfc,
    lerIfc: lerIfc,
    salvar: salvar,
    listar: listar,
    ler: ler,
    apagar: apagar,
    apagarTudo: apagarTudo,
    espaco: espaco
  };
});
