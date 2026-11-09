/* J.A.R.V.I.S. Nova — Contexto visual da sessão (puro, testável em Node).
 *
 * O que faz: guarda o que foi analisado na sessão, resolve perguntas de acompanhamento
 * ("ele é bom para corrida?", "e quanto custa?"), separa procedência do que é afirmado
 * (confirmado / loja / estimado), monta consultas de pesquisa, compara objetos e liga
 * componentes técnicos à base elétrica (`eletrica.js`).
 *
 * O que NÃO faz: não chama rede, não lê imagem, não inventa marca/modelo. Identificação
 * sem evidência (logo, etiqueta, texto legível) vira hipótese com confiança declarada.
 * Texto lido na imagem é dado, nunca instrução.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.VisaoContexto = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var VERSAO = '1.0';
  var LIMITE_PERGUNTAS = 30;
  var LIMITE_OBJETOS = 24;

  var CONFIANCA = { CONFIRMADO: 'confirmado', LOJA: 'loja', ESTIMADO: 'estimado' };

  function limpar(txt, max) {
    return String(txt == null ? '' : txt).replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/[<>]/g, '').replace(/\s+/g, ' ').trim().slice(0, max || 160);
  }

  function novoContexto() {
    return { versao: VERSAO, objetos: [], atual: -1, perguntas: [], comparacoes: [], analises: 0, salvo: false, textoLegivel: '', ocrDescartado: [] };
  }

  /** Texto vindo de OCR/imagem: é dado, não comando. Remove tentativas de instrução. */
  function limparTextoOcr(texto) {
    var bruto = String(texto == null ? '' : texto);
    var descartado = [];
    var linhas = bruto.split(/\r?\n/).map(function (l) { return l.trim(); }).filter(Boolean);
    var mantidas = [];
    linhas.forEach(function (l) {
      var baixa = l.toLowerCase();
      if (/^(system|assistant|user)\s*:|ignore (as|todas|as instruções)|ignore as instruções|desconsidere (as|todas)|execute|rm -rf|curl\s|https?:\/\/\S+\s*$/.test(baixa)) {
        descartado.push(limpar(l, 80));
        return;
      }
      mantidas.push(l);
    });
    return { texto: limpar(mantidas.join(' '), 2000), descartado: descartado, tratado_como: 'dado' };
  }

  function objetoBasico(o, indice) {
    var nome = limpar(o && (o.nome || o.tipo || o.classe), 80);
    return {
      indice: indice,
      nome: nome || ('objeto ' + (indice + 1)),
      categoria: limpar(o && o.categoria, 40),
      marca: o && o.marca ? limpar(o.marca, 40) : '',
      modelo: o && o.modelo ? limpar(o.modelo, 60) : '',
      confianca: o && o.confianca === CONFIANCA.CONFIRMADO ? CONFIANCA.CONFIRMADO : (o && o.confianca === CONFIANCA.LOJA ? CONFIANCA.LOJA : CONFIANCA.ESTIMADO),
      evidencia: Array.isArray(o && o.evidencia) ? o.evidencia.map(function (e) { return limpar(e, 60); }).slice(0, 6) : [],
      atributos: {},
      consultas: [],
      tecnico: null
    };
  }

  /** Registra uma análise do modelo no contexto da sessão. Sem evidência, marca e modelo caem. */
  function registrar(ctx, analise) {
    var c = ctx || novoContexto();
    var a = analise || {};
    var lista = Array.isArray(a.objetos) ? a.objetos.slice(0, LIMITE_OBJETOS) : [];
    c.objetos = lista.map(function (o, i) { return objetoBasico(o, i); });
    var ocr = limparTextoOcr(Array.isArray(a.textoLegivel) ? a.textoLegivel.join('\n') : (a.textoLegivel || ''));
    c.textoLegivel = ocr.texto;
    c.ocrDescartado = ocr.descartado;
    var evid = [];
    c.objetos.forEach(function (o) { evid = evid.concat(o.evidencia); });
    if (c.textoLegivel) evid.push(c.textoLegivel);
    var temEvidencia = evid.join(' ').trim().length >= 3;
    c.objetos.forEach(function (o) {
      if (!temEvidencia) { o.marca = ''; o.modelo = ''; o.confianca = CONFIANCA.ESTIMADO; }
      o.consultas = consultas(o, 'identificacao');
    });
    c.atual = c.objetos.length ? 0 : -1;
    c.analises = (c.analises || 0) + 1;
    c.salvo = false;
    return { contexto: c, objetoAtual: c.atual >= 0 ? c.objetos[c.atual] : null, evidenciaSuficiente: temEvidencia };
  }

  function selecionar(ctx, indice) {
    var c = ctx || novoContexto();
    var i = Number(indice);
    if (!Number.isInteger(i) || i < 0 || i >= c.objetos.length) return { ok: false, erro: 'Objeto ' + (i + 1) + ' não existe nesta análise.' };
    c.atual = i;
    return { ok: true, objeto: c.objetos[i] };
  }

  function atual(ctx) {
    var c = ctx || novoContexto();
    return c.atual >= 0 && c.objetos[c.atual] ? c.objetos[c.atual] : null;
  }

  var PRONOMES = /^(ele|ela|isso|esse|essa|este|esta|dele|dela|nele|nela|o produto|o aparelho|o equipamento|a pe[cç]a|o item|o objeto)\b/;
  var INTENCOES = [
    { id: 'texto', rx: /\b(o que (?:est[aá] )?escrito|o que diz|leia|texto leg[ií]vel|transcreva|transcrever|ler a etiqueta|ler a placa|escrito na|c[oó]digo da etiqueta)\b/ },
    { id: 'marca', rx: /\b(marca|fabricante|quem fabrica)\b/ },
    { id: 'modelo', rx: /\b(modelo|vers[aã]o|linha)\b/ },
    { id: 'material', rx: /\b(material|feito de|fabricado com|composi[cç][aã]o)\b/ },
    { id: 'preco', rx: /\b(quanto custa|pre[cç]o|valor|quanto sai|mais barato)\b/ },
    { id: 'onde', rx: /\b(onde (posso )?comprar|loja|fornecedor|dispon[ií]vel)\b/ },
    { id: 'uso', rx: /\b(para que serve|serve para|finalidade|indica[cç][aã]o|bom para|funciona para)\b/ },
    { id: 'especificacoes', rx: /\b(especifica[cç][oõ]es|ficha t[eé]cnica|datasheet|tens[aã]o|corrente|pot[eê]ncia)\b/ },
    { id: 'compativel', rx: /\b(compat[ií]vel|serve no|funciona com|encaixa|ligar (n)?o)\b/ },
    { id: 'comparar', rx: /\b(diferen[cç]a|comparar|melhor|versus|\bvs\b|qual dos dois)\b/ },
    { id: 'tecnico', rx: /\b(componente|contator|disjuntor|motor|rele|rel[eé]|clp|sensor|circuito|placa|resistor|capacitor|transistor)\b/ },
    { id: 'identificar', rx: /\b(que (t[eê]nis|objeto|produto|pe[cç]a|equipamento|marca|modelo)|o que (e|eh) (isso|esse|essa)|identifique|reconhe[cç]a)\b/ }
  ];

  /** Classifica a pergunta e diz se ela depende do objeto atual. */
  function intencaoPergunta(texto) {
    var t = String(texto == null ? '' : texto).toLowerCase().replace(/\s+/g, ' ').trim();
    if (!t) return { ok: false, erro: 'Pergunta vazia.' };
    var intent = null;
    for (var i = 0; i < INTENCOES.length; i++) if (INTENCOES[i].rx.test(t)) { intent = INTENCOES[i].id; break; }
    var dêitico = PRONOMES.test(t) || /\b(ele|ela|dele|dela|desse|dessa|disso)\b/.test(t);
    var curta = t.split(' ').length <= 6;
    return { ok: true, intencao: intent || (curta || dêitico ? 'continuacao' : 'geral'), usaContexto: dêitico || curta || intent !== null, texto: t };
  }

  /** Resolve "ele/essa/quanto custa" para o objeto atual da sessão. */
  function resolver(ctx, texto) {
    var c = ctx || novoContexto();
    var ip = intencaoPergunta(texto);
    if (!ip.ok) return { ok: false, erro: ip.erro };
    var obj = atual(c);
    if (!obj && ip.intencao === 'texto' && c.textoLegivel) {
      return { ok: true, objeto: null, intencao: 'texto', textoLegivel: c.textoLegivel, rotulo: 'usando o texto reconhecido na imagem atual' };
    }
    if (!obj) return { ok: false, erro: 'Ainda não há objeto ou texto analisado nesta sessão: mostre uma imagem primeiro.', intencao: ip.intencao };
    if (!ip.usaContexto && ip.intencao === 'geral') return { ok: true, objeto: null, intencao: 'geral', independente: true };
    return {
      ok: true, objeto: obj, intencao: ip.intencao, textoLegivel: c.textoLegivel || '',
      rotulo: 'usando o objeto atual: ' + obj.nome + (obj.marca ? ' (' + obj.marca + ')' : ''),
      precisaRepetir: !obj.marca && !obj.modelo && c.objetos.length > 1 && ip.intencao === 'identificar'
    };
  }

  function consultas(objeto, intent) {
    var o = objeto || {};
    var base = [o.marca, o.modelo, o.nome].filter(Boolean).join(' ').trim() || o.nome || '';
    if (!base) return [];
    var mapa = {
      identificacao: [''],
      marca: ['marca fabricante'],
      modelo: ['modelo especificações'],
      material: ['material de fabricação'],
      preco: ['preço onde comprar'],
      onde: ['onde comprar loja'],
      uso: ['para que serve indicação de uso'],
      especificacoes: ['ficha técnica datasheet'],
      compativel: ['compatibilidade aplicação'],
      comparar: ['comparar modelos diferenças'],
      tecnico: ['datasheet manual ligação']
    };
    return (mapa[intent] || ['']).map(function (s) { return limpar((base + ' ' + s).trim(), 120); });
  }

  /** Rótulo de procedência: nada visual vira "confirmado" sem documento. */
  function rotular(campo, valor, fonte) {
    var f = String(fonte || '').toLowerCase();
    var confianca = /fabricante|manual|datasheet|documenta|etiqueta|catálogo|norma/.test(f) ? CONFIANCA.CONFIRMADO
      : /loja|marketplace|anúncio|anuncio|venda/.test(f) ? CONFIANCA.LOJA : CONFIANCA.ESTIMADO;
    return { campo: limpar(campo, 40), valor: limpar(valor, 200), confianca: confianca, fonte: limpar(fonte, 160), aviso: confianca === CONFIANCA.ESTIMADO ? 'estimado visualmente' : '' };
  }

  function resumoConfianca(ctx) {
    var c = ctx || novoContexto();
    var contagem = { confirmado: 0, loja: 0, estimado: 0 };
    c.objetos.forEach(function (o) { contagem[o.confianca] = (contagem[o.confianca] || 0) + 1; });
    return contagem;
  }

  /** Comparação determinística entre dois objetos do contexto (sem opinião do modelo). */
  function comparar(ctx, a, b) {
    var c = ctx || novoContexto();
    var oa = typeof a === 'number' ? c.objetos[a] : c.objetos.filter(function (o) { return o.nome === a; })[0];
    var ob = typeof b === 'number' ? c.objetos[b] : c.objetos.filter(function (o) { return o.nome === b; })[0];
    if (!oa || !ob) return { ok: false, erro: 'Escolha dois objetos desta análise para comparar.' };
    var chaves = Object.keys(oa.atributos || {}).concat(Object.keys(ob.atributos || {}));
    var linhas = [];
    chaves.forEach(function (k) {
      if (chaves.indexOf(k) !== chaves.lastIndexOf(k) && linhas.some(function (l) { return l.campo === k; })) return;
      var va = oa.atributos[k], vb = ob.atributos[k];
      if (va !== vb) linhas.push({ campo: k, a: va == null ? '—' : va, b: vb == null ? '—' : vb });
    });
    return {
      ok: true, a: oa.nome, b: ob.nome, diferencas: linhas,
      resumo: linhas.length
        ? oa.nome + ' × ' + ob.nome + ': ' + linhas.map(function (l) { return l.campo + ' (' + l.a + ' / ' + l.b + ')'; }).join('; ') + '.'
        : oa.nome + ' e ' + ob.nome + ' não têm atributos diferentes registrados; sem dados, não há conclusão.'
    };
  }

  /** Liga o objeto a um componente da base elétrica, quando for técnico. */
  function tecnico(objeto, base) {
    var B = base || (typeof window !== 'undefined' ? window.EletricaBase : null);
    if (!B || !B.consultar) return { ok: false, motivo: 'Base elétrica não carregada.' };
    var nome = String((objeto && (objeto.nome || objeto.categoria)) || '').toLowerCase();
    var mapa = [
      [/contator/, 'contator'], [/disjuntor/, 'disjuntor3'], [/t[eé]rmico|rele|rel[eé]/, 'releTermico'],
      [/motor/, 'motor3'], [/clp|\bplc\b/, 'clp'], [/temporizador/, 'temporizador'],
      [/autotransformador|transformador/, 'autotransformador'], [/sensor|boia/, 'sensor'], [/sinaleiro|l[aâ]mpada/, 'sinaleiro']
    ];
    var tipo = null;
    for (var i = 0; i < mapa.length; i++) if (mapa[i][0].test(nome)) { tipo = mapa[i][1]; break; }
    if (!tipo) return { ok: false, motivo: 'O objeto não foi reconhecido como componente da base elétrica.' };
    var consulta = B.consultar(tipo);
    return {
      ok: consulta.ok, tipo: tipo, entradas: consulta.entradas || [],
      relacao: 'Pode ser usado no Projetista elétrico como ' + tipo + (consulta.entradas && consulta.entradas[0] ? ' (' + consulta.entradas[0].nome + ')' : '') + '.',
      fonte: consulta.fonte
    };
  }

  /** Resposta montada com procedência; nunca afirma marca/modelo sem evidência. */
  function montarResposta(ctx, intent, dados) {
    var c = ctx || novoContexto();
    var o = atual(c);
    var d = dados || {};
    if (!o) return { texto: 'Mostre uma imagem primeiro; depois eu respondo sobre o que está nela.', fontes: [], confianca: CONFIANCA.ESTIMADO };
    var partes = [];
    var fontes = Array.isArray(d.fontes) ? d.fontes.map(function (f) { return limpar(f, 160); }) : [];
    if (intent === 'identificar') {
      partes.push('Parece ' + (o.categoria || o.nome) + (o.marca ? ' da marca ' + o.marca : '') + (o.modelo ? ', modelo ' + o.modelo : '') + '.');
      if (!o.marca) partes.push('Não consigo confirmar marca ou modelo com esta imagem; uma foto do logotipo, da etiqueta ou do solado ajudaria.');
      if (o.confianca !== CONFIANCA.CONFIRMADO) partes.push('Identificação ' + o.confianca + ': ' + (o.evidencia.length ? 'indícios visuais (' + o.evidencia.join(', ') + ')' : 'sem evidência legível') + '.');
    } else if (intent === 'compativel') {
      partes.push('Para dizer se ' + o.nome + ' é compatível, preciso do modelo e da tensão; o que vejo não confirma esses dados.');
    } else {
      partes.push('Sobre ' + o.nome + (o.marca ? ' (' + o.marca + ')' : '') + ':');
    }
    if (d.resposta) partes.push(limpar(d.resposta, 900));
    if (d.estimado) partes.push('Estimativa visual: ' + limpar(d.estimado, 300));
    if (fontes.length) partes.push('Fontes: ' + fontes.join(' · '));
    return { texto: partes.join(' '), fontes: fontes, confianca: o.confianca, objeto: o.nome };
  }

  function descreverContexto(ctx) {
    var c = ctx || novoContexto();
    if (!c.objetos.length && !c.textoLegivel) return 'Sessão visual sem objetos ou texto reconhecido.';
    var o = atual(c);
    return c.objetos.length + ' objeto(s) nesta análise; atual: ' + (o ? o.nome + (o.marca ? ' (' + o.marca + ')' : '') : 'nenhum') +
      (c.textoLegivel ? '; texto OCR disponível' : '') + '; perguntas: ' + c.perguntas.length + '; análises: ' + c.analises + '.';
  }

  /** Privacidade: nada é salvo sem pedido explícito do usuário. */
  function podeSalvar(ctx) {
    var c = ctx || novoContexto();
    if (!c.objetos.length) return { ok: false, motivo: 'Não há análise para salvar.' };
    return { ok: true, precisaConsentimento: true, dados: 'apenas texto e atributos, sem a imagem' };
  }

  function registrarPergunta(ctx, texto, intencao) {
    var c = ctx || novoContexto();
    c.perguntas.push({ texto: limpar(texto, 200), intencao: intencao || 'geral', quando: Date.now() });
    if (c.perguntas.length > LIMITE_PERGUNTAS) c.perguntas = c.perguntas.slice(-LIMITE_PERGUNTAS);
    return c;
  }

  return {
    VERSAO: VERSAO, CONFIANCA: CONFIANCA,
    novoContexto: novoContexto, registrar: registrar, selecionar: selecionar, atual: atual,
    intencaoPergunta: intencaoPergunta, resolver: resolver, consultas: consultas,
    rotular: rotular, resumoConfianca: resumoConfianca, comparar: comparar, tecnico: tecnico,
    montarResposta: montarResposta, descreverContexto: descreverContexto,
    limparTextoOcr: limparTextoOcr, podeSalvar: podeSalvar, registrarPergunta: registrarPergunta
  };
});
