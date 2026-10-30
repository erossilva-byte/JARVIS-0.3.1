/* J.A.R.V.I.S. Nova — projeto CAD: reparo, validação, conversão e pacote para o PC.
 *
 * Roda no WebView do Android e no Node (testes) sem dependência nova: usa o mesmo
 * `cad.js` do aplicativo. O celular é ambiente de criação e preparação; o CAD de
 * verdade abre no computador.
 *
 * O que este módulo NÃO faz, e diz isso em vez de fingir:
 *  - não executa OpenSCAD, FreeCAD, CadQuery nem OCC: gera o script e valida a
 *    sintaxe, mas o render acontece no PC (ou em app externo);
 *  - não lê nem escreve DWG, IGES, 3DM, FCStd: são formatos proprietários/com kernel
 *    próprio e não existe leitor livre embutível aqui;
 *  - reparo é de DOCUMENTO e de malha (dimensão, posição, duplicata, unidade,
 *    orientação), não de sólido B-rep.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.CadProjeto = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var CAD = null;
  function nucleo() {
    if (CAD) return CAD;
    if (typeof window !== 'undefined' && window.CadNucleo) CAD = window.CadNucleo;
    else if (typeof require === 'function') CAD = require('./cad.js');
    if (!CAD) throw new Error('O núcleo CAD não está carregado.');
    return CAD;
  }

  var TIPOS = { caixa: 1, esfera: 1, cilindro: 1, cone: 1, plano: 1 };
  var ESCALA_MM = { mm: 1, cm: 10, m: 1000, pol: 25.4 };
  var UNIDADES = ['mm', 'cm', 'm', 'pol'];

  function numero(v) { return typeof v === 'number' && isFinite(v); }
  function objetos(doc) { return doc && Array.isArray(doc.objetos) ? doc.objetos : []; }
  function textoBytes(t) {
    var s = String(t == null ? '' : t);
    if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(s);
    var out = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) out[i] = s.charCodeAt(i) & 0xff;
    return out;
  }
  function slug(nome) {
    return String(nome || 'projeto').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || 'projeto';
  }
  function chaveObjeto(o) {
    return [o.tipo, JSON.stringify(o.posicao || [0, 0, 0]), JSON.stringify(o.dimensoes || []), o.raio, o.altura].join('|');
  }

  /** Problemas de documento + geometria. `critico` impede exportar; `aviso` não. */
  function problemas(doc) {
    var lista = [];
    function add(nivel, codigo, mensagem, objeto) {
      lista.push({ nivel: nivel, codigo: codigo, mensagem: mensagem, objeto: objeto || '' });
    }
    if (!doc || typeof doc !== 'object') { add('critico', 'sem-documento', 'Não há documento para analisar.'); return lista; }
    var obs = objetos(doc);
    if (!obs.length) add('critico', 'vazio', 'O projeto não tem nenhum objeto.');
    if (obs.length > nucleo().LIMITE_OBJETOS) add('critico', 'limite', 'Acima de ' + nucleo().LIMITE_OBJETOS + ' objetos.');
    if (UNIDADES.indexOf(doc.unidades) < 0) add('aviso', 'unidade', 'Unidade ausente ou desconhecida; a exportação assume milímetros.');

    var nomes = {}, chaves = {};
    obs.forEach(function (o, i) {
      var nome = (o && o.nome) || ('objeto ' + (i + 1));
      if (!o || !TIPOS[o.tipo]) { add('critico', 'tipo', 'Tipo ausente ou desconhecido em ' + nome + '.'); return; }
      if (o.posicao != null && (!Array.isArray(o.posicao) || o.posicao.length !== 3 || !o.posicao.every(numero))) {
        add('critico', 'posicao', 'Posição inválida em ' + nome + ' (esperado 3 números).');
      }
      if (o.tipo === 'caixa' || o.tipo === 'plano') {
        var n = o.tipo === 'plano' ? 2 : 3;
        var okDim = Array.isArray(o.dimensoes) && o.dimensoes.length >= n;
        if (okDim) for (var k = 0; k < n; k++) if (!(numero(o.dimensoes[k]) && o.dimensoes[k] > 0)) okDim = false;
        if (!okDim) add('critico', 'dimensoes', 'Dimensões inválidas em ' + nome + ' (todas precisam ser maiores que zero).');
      }
      if (o.tipo === 'esfera' && !(numero(o.raio) && o.raio > 0)) add('critico', 'raio', 'Raio inválido em ' + nome + '.');
      if (o.tipo === 'cilindro' || o.tipo === 'cone') {
        if (!(numero(o.raio) && o.raio > 0)) add('critico', 'raio', 'Raio inválido em ' + nome + '.');
        if (!(numero(o.altura) && o.altura > 0)) add('critico', 'altura', 'Altura inválida em ' + nome + '.');
      }
      if (nomes[nome]) add('aviso', 'nome-repetido', 'O nome "' + nome + '" aparece mais de uma vez.');
      nomes[nome] = 1;
      var k2 = chaveObjeto(o);
      if (chaves[k2]) add('aviso', 'duplicado', '"' + nome + '" repete a geometria de "' + chaves[k2] + '" (sobreposição exata).');
      else chaves[k2] = nome;
    });

    if (!lista.some(function (p) { return p.nivel === 'critico'; })) {
      try {
        var m = nucleo().malha(doc);
        var man = nucleo().manifold(m);
        var va = nucleo().volumeArea(m);
        var bb = nucleo().caixaMalha(m);
        if (!m.triangulos.length) add('critico', 'sem-faces', 'Nenhuma face foi gerada.');
        if (!man.fechada) add('aviso', 'malha-aberta', 'A malha tem ' + man.arestasAbertas + ' aresta(s) aberta(s): no STL isso vira superfície não fechada.');
        if (!(va.volume > 0)) add('critico', 'volume', 'O volume calculado é zero: o modelo não ocupa espaço.');
        var maior = Math.max(bb.tamanho[0], bb.tamanho[1], bb.tamanho[2]);
        if (maior > 100000) add('aviso', 'escala', 'Maior dimensão com ' + Math.round(maior) + ' unidades: confira a escala antes de abrir no CAD.');
        if (maior > 0 && maior < 0.01) add('aviso', 'escala', 'Modelo minúsculo (' + maior + ' unidades): provável erro de unidade.');
      } catch (e) {
        add('critico', 'malha', 'Não consegui triangular o modelo: ' + (e && e.message ? e.message : e));
      }
    }
    return lista;
  }

  /** Validação com números: é o que o relatório mostra, não só "ok". */
  function validar(doc) {
    var p = problemas(doc);
    var res = {
      ok: !p.some(function (x) { return x.nivel === 'critico'; }),
      problemas: p,
      criticos: p.filter(function (x) { return x.nivel === 'critico'; }),
      avisos: p.filter(function (x) { return x.nivel === 'aviso'; })
    };
    if (res.ok) {
      var m = nucleo().malha(doc);
      var man = nucleo().manifold(m);
      var va = nucleo().volumeArea(m);
      var bb = nucleo().caixaMalha(m);
      res.geometria = {
        triangulos: m.triangulos.length,
        vertices: m.vertices.length / 3,
        volume: Math.round(va.volume * 1000) / 1000,
        area: Math.round(va.area * 1000) / 1000,
        bbox: bb,
        fechada: man.fechada,
        arestasAbertas: man.arestasAbertas
      };
    }
    res.resumo = res.ok
      ? 'Projeto válido: ' + objetos(doc).length + ' objeto(s), ' + (res.geometria ? res.geometria.triangulos : 0) + ' triângulo(s), volume ' +
        (res.geometria ? res.geometria.volume : 0) + ' ' + (doc && doc.unidades ? doc.unidades : 'mm') + '³.' + (res.avisos.length ? ' ' + res.avisos.length + ' aviso(s).' : '')
      : 'Projeto reprovado: ' + res.criticos.length + ' problema(s) crítico(s) — ' + res.criticos.map(function (x) { return x.mensagem; }).join(' ');
    return res;
  }

  /** Reparo de documento: completa/limita campos, remove duplicata exata e revalida.
   *  Nunca devolve ok sem reabrir o texto final no parser. */
  function reparar(doc) {
    var antes = problemas(doc);
    var novo;
    try { novo = JSON.parse(JSON.stringify(doc || {})); } catch (e) { return { ok: false, erro: 'O documento não é copiável: ' + e.message, antes: antes, correcoes: [] }; }
    novo.objetos = Array.isArray(novo.objetos) ? novo.objetos : [];
    var correcoes = [];
    novo.objetos = novo.objetos.filter(function (o, i) {
      if (!o || !TIPOS[o.tipo]) { correcoes.push('Objeto ' + (i + 1) + ' removido: tipo ausente ou desconhecido.'); return false; }
      return true;
    });
    novo.objetos.forEach(function (o) {
      var nome = o.nome || 'objeto';
      if (o.posicao == null || !Array.isArray(o.posicao) || o.posicao.length !== 3 || !o.posicao.every(numero)) {
        o.posicao = [0, 0, 0];
        correcoes.push(nome + ': posição inválida trocada por [0,0,0].');
      }
      if (o.tipo === 'caixa' || o.tipo === 'plano') {
        var n = o.tipo === 'plano' ? 2 : 3;
        var padrao = o.tipo === 'plano' ? [100, 100] : [20, 20, 20];
        if (!Array.isArray(o.dimensoes)) { o.dimensoes = padrao.slice(); correcoes.push(nome + ': dimensões ausentes receberam ' + padrao.join('×') + '.'); }
        for (var k = 0; k < n; k++) {
          if (!(numero(o.dimensoes[k]) && o.dimensoes[k] > 0)) {
            o.dimensoes[k] = padrao[k];
            correcoes.push(nome + ': dimensão ' + (k + 1) + ' inválida trocada por ' + padrao[k] + '.');
          }
        }
        o.dimensoes = o.dimensoes.slice(0, n);
      }
      if (o.tipo === 'esfera' && !(numero(o.raio) && o.raio > 0)) { o.raio = 10; correcoes.push(nome + ': raio inválido trocado por 10.'); }
      if (o.tipo === 'cilindro' || o.tipo === 'cone') {
        if (!(numero(o.raio) && o.raio > 0)) { o.raio = 5; correcoes.push(nome + ': raio inválido trocado por 5.'); }
        if (!(numero(o.altura) && o.altura > 0)) { o.altura = 20; correcoes.push(nome + ': altura inválida trocada por 20.'); }
      }
    });
    if (UNIDADES.indexOf(novo.unidades) < 0) { novo.unidades = 'mm'; correcoes.push('Unidade ausente ou desconhecida: assumido milímetros.'); }
    var vistos = {}, unicos = [];
    novo.objetos.forEach(function (o) {
      var k = chaveObjeto(o);
      if (vistos[k]) correcoes.push('Duplicata de "' + vistos[k] + '" removida: ' + (o.nome || 'objeto') + '.');
      else { vistos[k] = o.nome || 'objeto'; unicos.push(o); }
    });
    novo.objetos = unicos;
    if (!novo.objetos.length) return { ok: false, erro: 'Depois do reparo não sobrou nenhum objeto válido; o original não foi alterado.', antes: antes, correcoes: correcoes, doc: doc };

    var conf = nucleo().parse(nucleo().serializar(novo));
    if (!conf.ok) return { ok: false, erro: 'O reparo produziria um arquivo inválido: ' + conf.erro, antes: antes, correcoes: correcoes, doc: doc };
    var depois = problemas(conf.doc);
    var criticos = depois.filter(function (p) { return p.nivel === 'critico'; });
    return {
      ok: criticos.length === 0,
      doc: conf.doc,
      texto: nucleo().serializar(conf.doc),
      antes: antes,
      depois: depois,
      correcoes: correcoes,
      erro: criticos.length ? criticos.map(function (p) { return p.mensagem; }).join(' ') : '',
      resumo: (correcoes.length ? correcoes.length + ' correção(ões) aplicada(s). ' : 'Nenhuma correção necessária. ') +
        (criticos.length ? 'Ainda restam ' + criticos.length + ' problema(s) crítico(s).' : 'Validado depois do reparo. ' + validar(conf.doc).resumo)
    };
  }

  /** Exporta e REABRE no leitor correspondente. A validação é do arquivo gerado,
   *  não da intenção: se o leitor recusar, `validacao.ok` é false. */
  async function converter(doc, formato) {
    var id = String(formato || '').toLowerCase().replace(/^\./, '');
    var r = nucleo().exportar(doc, id, {});
    if (!r.ok) return r;
    var dados = r.dados || r.texto;
    var lido;
    try { lido = await nucleo().analisarFormato(dados, 'arquivo.' + id); }
    catch (e) { lido = { ok: false, erro: (e && e.message) || String(e) }; }
    var detalhe = '';
    if (lido.ok) {
      if (lido.formato === 'stl') detalhe = (lido.triangulos ? lido.triangulos.length : 0) + ' triângulo(s), ' + (lido.manifold && lido.manifold.fechada ? 'malha fechada' : 'malha aberta');
      else if (lido.formato === 'dxf') detalhe = (lido.segmentos || 0) + ' segmento(s)';
      else if (lido.formato === 'step') detalhe = (lido.entidades || 0) + ' entidade(s)';
      else if (lido.formato === 'ifc') detalhe = (lido.elementos ? lido.elementos.length : 0) + ' elemento(s)';
      else if (lido.formato === 'cad') detalhe = (lido.contagem ? Object.keys(lido.contagem).length : 0) + ' tipo(s) de objeto';
      else if (lido.formato === '3mf') detalhe = (lido.triangulos || 0) + ' triângulo(s)';
    }
    return {
      ok: true, formato: id, nome: r.nome, texto: r.texto, dados: r.dados, bytes: r.bytes || (dados && dados.length) || 0,
      perdas: r.perdas || [], avisos: r.avisos || [],
      validacao: { ok: !!lido.ok, formato: lido.formato || id, detalhe: lido.ok ? detalhe : (lido.erro || 'o leitor recusou o arquivo'), erro: lido.ok ? '' : (lido.erro || '') }
    };
  }

  /** Script OpenSCAD com a escala convertida para milímetros. */
  function gerarScad(doc) {
    var fator = ESCALA_MM[doc && doc.unidades] || 1;
    var linhas = [
      '// J.A.R.V.I.S. Nova — ' + (doc && doc.nome ? doc.nome : 'modelo'),
      '// Unidades de origem: ' + (doc && doc.unidades ? doc.unidades : 'mm') + ' (convertidas para mm no render)',
      '// Edite os parâmetros e recompile no OpenSCAD (PC). O aplicativo não executa o render.',
      '',
      'escala = ' + fator + ';',
      '',
      'scale([escala, escala, escala]) {',
      '  union() {'
    ];
    objetos(doc).forEach(function (o) {
      var p = Array.isArray(o.posicao) && o.posicao.length === 3 ? o.posicao : [0, 0, 0];
      var onde = 'translate([' + p.join(', ') + ']) ';
      if (o.tipo === 'caixa') linhas.push('    ' + onde + 'cube([' + o.dimensoes[0] + ', ' + o.dimensoes[1] + ', ' + o.dimensoes[2] + '], center = true);');
      else if (o.tipo === 'plano') linhas.push('    ' + onde + 'cube([' + o.dimensoes[0] + ', ' + o.dimensoes[1] + ', 0.01], center = true);');
      else if (o.tipo === 'esfera') linhas.push('    ' + onde + 'sphere(r = ' + o.raio + ', $fn = 48);');
      else if (o.tipo === 'cilindro') linhas.push('    ' + onde + 'cylinder(h = ' + o.altura + ', r = ' + o.raio + ', center = true, $fn = 48);');
      else if (o.tipo === 'cone') linhas.push('    ' + onde + 'cylinder(h = ' + o.altura + ', r1 = ' + o.raio + ', r2 = 0, center = true, $fn = 48);');
    });
    linhas.push('  }', '}', '');
    var texto = linhas.join('\n');
    var chaves = (texto.match(/\{/g) || []).length - (texto.match(/\}/g) || []).length;
    var parenteses = (texto.match(/\(/g) || []).length - (texto.match(/\)/g) || []).length;
    var colchetes = (texto.match(/\[/g) || []).length - (texto.match(/\]/g) || []).length;
    var semPontoVirgula = linhas.filter(function (l) {
      var t = l.trim();
      return t && t.indexOf('//') !== 0 && !/[;{}]$/.test(t);
    });
    var problemasSintaxe = [];
    if (chaves !== 0) problemasSintaxe.push('chaves desbalanceadas (' + chaves + ')');
    if (parenteses !== 0) problemasSintaxe.push('parênteses desbalanceados (' + parenteses + ')');
    if (colchetes !== 0) problemasSintaxe.push('colchetes desbalanceados (' + colchetes + ')');
    if (semPontoVirgula.length) problemasSintaxe.push('linha sem terminador: ' + semPontoVirgula[0].trim().slice(0, 60));
    if (/NaN|undefined/.test(texto)) problemasSintaxe.push('valor numérico ausente no script');
    return {
      ok: problemasSintaxe.length === 0,
      texto: texto,
      bytes: textoBytes(texto).length,
      problemas: problemasSintaxe,
      aviso: 'O aplicativo gera e confere a sintaxe do script, mas NÃO executa o OpenSCAD: o render e a exportação precisam do OpenSCAD no computador.'
    };
  }

  function instrucoes(doc, gerados) {
    var linhas = [
      'J.A.R.V.I.S. Nova — pacote de projeto CAD',
      '',
      'Projeto: ' + (doc.nome || 'modelo'),
      'Unidades: ' + (doc.unidades || 'mm'),
      'Objetos: ' + objetos(doc).length,
      '',
      'Como abrir no computador:',
      '  1. Extraia o ZIP numa pasta.',
      '  2. ' + (doc.nome || 'modelo') + '.cad — abre no próprio J.A.R.V.I.S. Nova; é JSON documentado, NÃO é o .cad do CADe SIMU nem do AutoCAD.',
      '  3. .dxf — LibreCAD, QCAD, AutoCAD (importação).',
      '  4. .stl — slicers de impressão 3D (Cura, PrusaSlicer) e visualizadores.',
      '  5. .step (STEP AP203) — FreeCAD, Fusion 360, SolidWorks (sólido facetado, sem histórico paramétrico).',
      '  6. .scad — abra no OpenSCAD e compile (F6); edite os parâmetros antes.',
      '  7. RELATORIO.md — o que foi validado, o que foi estimado e o que se perde em cada formato.',
      '',
      'Formatos gerados nesta execução: ' + (gerados.length ? gerados.map(function (g) { return '.' + g.formato; }).join(', ') : 'nenhum'),
      '',
      'Limites declarados: DWG, IGES/IGS, 3DM, FCStd e o .cad do CADe SIMU não são gerados nem lidos aqui.'
    ];
    return linhas.join('\n') + '\n';
  }

  function relatorio(doc, extra) {
    var e = extra || {};
    var v = validar(doc);
    var g = v.geometria;
    var linhas = [
      '# Relatório de projeto CAD — ' + (doc.nome || 'modelo'),
      '',
      '- Gerado em: ' + new Date().toISOString(),
      '- Formato nativo: `.cad` (JSON do J.A.R.V.I.S. Nova, v1)',
      '- Unidades: ' + (doc.unidades || 'mm'),
      '- Objetos: ' + objetos(doc).length,
      '- Validação: ' + (v.ok ? 'APROVADA' : 'REPROVADA'),
      ''
    ];
    if (g) {
      linhas.push('## Geometria medida neste aparelho', '',
        '- Triângulos: ' + g.triangulos,
        '- Vértices: ' + g.vertices,
        '- Volume: ' + g.volume + ' ' + (doc.unidades || 'mm') + '³',
        '- Área: ' + g.area + ' ' + (doc.unidades || 'mm') + '²',
        '- Caixa envolvente: ' + g.bbox.tamanho.map(function (n) { return Math.round(n * 100) / 100; }).join(' × ') + ' ' + (doc.unidades || 'mm'),
        '- Malha fechada: ' + (g.fechada ? 'sim' : 'não (' + g.arestasAbertas + ' aresta(s) aberta(s))'),
        '');
    }
    linhas.push('## Problemas encontrados', '');
    if (!v.problemas.length) linhas.push('- Nenhum problema de estrutura ou geometria.');
    v.problemas.forEach(function (p) { linhas.push('- [' + p.nivel + '] ' + p.mensagem); });
    linhas.push('');
    if (e.correcoes && e.correcoes.length) {
      linhas.push('## Correções aplicadas', '');
      e.correcoes.forEach(function (c) { linhas.push('- ' + c); });
      linhas.push('');
    }
    if (e.arquivos && e.arquivos.length) {
      linhas.push('## Arquivos do pacote', '');
      e.arquivos.forEach(function (a) {
        linhas.push('- `.' + a.formato + '` — ' + a.bytes + ' bytes; validação por reabertura: ' +
          (a.validacao && a.validacao.ok ? 'OK' + (a.validacao.detalhe ? ' (' + a.validacao.detalhe + ')' : '') : 'FALHOU') +
          (a.perdas && a.perdas.length ? '; perdas: ' + a.perdas.join(' ') : ''));
      });
      linhas.push('');
    }
    if (e.scad) {
      linhas.push('## Script OpenSCAD', '', '- Sintaxe: ' + (e.scad.ok ? 'válida (chaves e terminadores conferidos)' : 'inválida: ' + e.scad.problemas.join('; ')),
        '- Execução: NÃO executado neste aparelho; compile no OpenSCAD do PC.', '');
    }
    linhas.push('## O que foi testado e o que é estimado', '',
      '- MEDIDO aqui: estrutura do `.cad`, malha, volume, área, caixa envolvente, reabertura dos formatos exportados.',
      '- ESTIMADO: abertura nos softwares do computador (AutoCAD, LibreCAD, FreeCAD, Cura). Não há esses programas neste ambiente.',
      '- NÃO SUPORTADO: DWG, IGES/IGS, 3DM, FCStd, RVT/RFA e o `.cad` proprietário do CADe SIMU.',
      '');
    return linhas.join('\n');
  }

  /** Pacote ZIP com projeto, trocas, script, relatório e instruções. */
  function pacote(doc, opcoes) {
    var o = opcoes || {};
    var CADn = nucleo();
    var base = slug(doc && doc.nome ? doc.nome : 'projeto');
    var formatos = Array.isArray(o.formatos) && o.formatos.length ? o.formatos : ['cad', 'dxf', 'stl', 'step'];
    var entradas = [], gerados = [], falhas = [];
    formatos.forEach(function (f) {
      var r = CADn.exportar(doc, f, {});
      if (!r.ok) { falhas.push('.' + f + ': ' + r.erro); return; }
      var dados = r.dados || textoBytes(r.texto);
      entradas.push({ nome: base + '.' + f, dados: dados });
      gerados.push({ formato: f, bytes: dados.length, validacao: r.validacao || null, perdas: r.perdas || [] });
    });
    var scad = gerarScad(doc);
    entradas.push({ nome: base + '.scad', dados: textoBytes(scad.texto) });
    if (!formatos.some(function (f) { return f === 'cad'; })) entradas.push({ nome: base + '.cad', dados: textoBytes(CADn.serializar(doc)) });
    var rel = relatorio(doc, { arquivos: gerados, scad: scad });
    entradas.push({ nome: 'RELATORIO.md', dados: textoBytes(rel) });
    entradas.push({ nome: 'LEIA-ME.txt', dados: textoBytes(instrucoes(doc, gerados)) });
    entradas.push({ nome: 'projeto.json', dados: textoBytes(JSON.stringify({ nome: doc.nome, unidades: doc.unidades, objetos: objetos(doc) }, null, 2)) });
    var bytes = CADn.zipStore(entradas);
    var validacao = validar(doc);
    return {
      ok: validacao.ok && gerados.length > 0,
      nome: base + '.zip',
      bytes: bytes,
      tamanho: bytes.length,
      entradas: entradas.map(function (x) { return x.nome; }),
      gerados: gerados,
      falhas: falhas,
      relatorio: rel,
      validacao: { ok: validacao.ok, resumo: validacao.resumo },
      instrucoes: instrucoes(doc, gerados)
    };
  }

  /** Cria projeto a partir de frase: várias primitivas e unidades. */
  function criarDeTexto(texto) {
    var CADn = nucleo();
    var bruto = String(texto || '');
    var unidade = /\bcm\b/i.test(bruto) ? 'cm' : /\bmetros?\b|\bm\b/i.test(bruto) ? 'm' : /\bpolegadas?\b|\bpol\b|\bin\b/i.test(bruto) ? 'pol' : 'mm';
    var nomeM = bruto.match(/(?:chamado|com o nome|de nome|nome)\s+([A-Za-zÀ-ÿ0-9 _-]{2,40})/i);
    var nome = (nomeM ? nomeM[1] : (CADn.nomeArquivo ? CADn.nomeArquivo('modelo') : 'modelo')).trim().replace(/\s+/g, '-');
    var objetos = [];
    // Cada primitiva começa em sua palavra-chave e vai até a próxima: assim "caixa ...
    // com um cilindro ..." gera DOIS objetos em vez de a primeira engolir a segunda.
    var re = /(caixa|esfera|cilindro|cone|plano)/gi;
    var marcas = [];
    var m;
    while ((m = re.exec(bruto))) marcas.push({ tipo: m[1].toLowerCase(), fim: m.index + m[1].length });
    for (var mi = 0; mi < marcas.length; mi++) {
      var tipo = marcas[mi].tipo;
      var trecho = bruto.slice(marcas[mi].fim, mi + 1 < marcas.length ? marcas[mi + 1].fim - marcas[mi + 1].tipo.length : bruto.length);
      var nums = (trecho.match(/\d+(?:[.,]\d+)?/g) || []).map(function (x) { return Number(x.replace(',', '.')); }).filter(function (n) { return n > 0; });
      var o = CADn.objetoPadrao(tipo);
      o.nome = tipo + '-' + (objetos.length + 1);
      if (tipo === 'caixa') o.dimensoes = [nums[0] || 100, nums[1] || 60, nums[2] || 20];
      else if (tipo === 'plano') o.dimensoes = [nums[0] || 100, nums[1] || 100];
      else if (tipo === 'esfera') o.raio = nums[0] || 10;
      else { o.raio = nums[0] || 5; o.altura = nums[1] || 20; }
      objetos.push(o);
    }
    if (!objetos.length) {
      var n2 = (bruto.match(/\d+(?:[.,]\d+)?/g) || []).map(function (x) { return Number(x.replace(',', '.')); }).filter(function (n) { return n > 0; });
      var padrao = CADn.objetoPadrao('caixa');
      padrao.dimensoes = [n2[0] || 100, n2[1] || 60, n2[2] || 20];
      objetos.push(padrao);
    }
    var doc = CADn.criar({ nome: nome, unidades: unidade, objetos: objetos });
    var conf = CADn.parse(CADn.serializar(doc));
    if (!conf.ok) return { ok: false, erro: conf.erro };
    return { ok: true, doc: conf.doc, texto: CADn.serializar(conf.doc), unidades: unidade, objetos: objetos.length };
  }

  /** Matriz honesta do que o celular faz e do que fica para o PC. */
  function formatos() {
    return [
      { id: 'cad', nome: '.cad do J.A.R.V.I.S.', le: true, escreve: true, android: 'cria, lê, repara, valida e exporta (JSON próprio)', pc: 'abre no próprio aplicativo; NÃO é o .cad do CADe SIMU nem do AutoCAD' },
      { id: 'dxf', nome: 'DXF R12', le: true, escreve: true, android: 'gera e lê linhas/faces', pc: 'LibreCAD, QCAD, AutoCAD (importar)' },
      { id: 'stl', nome: 'STL', le: true, escreve: true, android: 'gera (binário/ASCII), lê e valida malha', pc: 'slicers (Cura, PrusaSlicer) e visualizadores' },
      { id: '3mf', nome: '3MF', le: true, escreve: true, android: 'gera e lê (ZIP+XML)', pc: 'Cura, Bambu Studio, PrusaSlicer' },
      { id: 'step', nome: 'STEP (AP203)', le: true, escreve: true, android: 'gera sólido facetado e relê entidades', pc: 'FreeCAD, Fusion 360, SolidWorks (sem histórico paramétrico)' },
      { id: 'ifc', nome: 'IFC4', le: true, escreve: true, android: 'gera subconjunto e relê', pc: 'visualizadores BIM (BlenderBIM, BIMvision)' },
      { id: 'scad', nome: 'OpenSCAD', le: false, escreve: true, android: 'gera o script e confere a sintaxe; NÃO executa', pc: 'OpenSCAD compila no PC' },
      { id: 'obj', nome: 'OBJ', le: false, escreve: false, android: 'não implementado', pc: '—' },
      { id: 'iges', nome: 'IGES/IGS', le: false, escreve: false, android: 'não implementado', pc: '—' },
      { id: 'dwg', nome: 'DWG', le: false, escreve: false, android: 'não suportado (binário proprietário)', pc: 'AutoCAD/ODA; exporte DXF' },
      { id: '3dm', nome: '3DM (Rhino)', le: false, escreve: false, android: 'não implementado', pc: 'Rhino' },
      { id: 'fcstd', nome: 'FreeCAD', le: false, escreve: false, android: 'não suportado (precisa do FreeCAD)', pc: 'FreeCAD' },
      { id: 'cad-cadesimu', nome: '.cad do CADe SIMU', le: false, escreve: false, android: 'não suportado: formato proprietário não documentado', pc: 'CADe SIMU' }
    ];
  }

  return {
    problemas: problemas,
    validar: validar,
    reparar: reparar,
    converter: converter,
    gerarScad: gerarScad,
    relatorio: relatorio,
    pacote: pacote,
    criarDeTexto: criarDeTexto,
    formatos: formatos,
    slug: slug,
    ESCALA_MM: ESCALA_MM
  };
});
