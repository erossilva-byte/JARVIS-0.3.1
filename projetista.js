/* J.A.R.V.I.S. Nova — Projetista elétrico (regras determinísticas).
 *
 * O que este módulo é: um projetista de circuitos de comando e potência que interpreta um
 * pedido em português, monta o projeto (componentes, pinos, redes, fios numerados, sequência
 * de operação), verifica o resultado por regras elétricas estruturais, corrige o que ele
 * mesmo identificou e entrega o relatório técnico.
 *
 * O que este módulo NÃO é, e o aplicativo diz isso ao usuário:
 *  - não abre nem gera o `.cad` nativo do CADeSIMU (formato proprietário, sem especificação
 *    pública; verificado em 2026-11: a extensão `.cad` do CADe SIMU é própria do produto);
 *  - não simula eletricidade: a verificação é de continuidade e de regras (curto, terminal
 *    solto, bobina sem alimentação, falta de proteção/intertravamento), não de tensão e corrente
 *    ao longo do tempo;
 *  - não substitui cálculo normativo (NBR 5410): o dimensionamento é estimativa didática.
 *
 * Formato de arquivo (documentado aqui, versionado e verificado na reabertura):
 * {
 *   "formato": "ProjetistaEletrico CAD", "versao": 1,
 *   "titulo": "...", "tipo": "partida_direta|reversao|estrela_triangulo|compensadora|comando|iluminacao|clp|generico",
 *   "pedido": "...", "spec": { ... },
 *   "redes": { "energia": ["L1","L2","L3"], "retorno": ["N","PE"], "fases": ["L1","L2","L3"] },
 *   "componentes": [ { "id":"K1", "tipo":"contator", "funcao":"...", "papeis": {...},
 *                      "tensao": 24, "x": 120, "y": 60, "pinos": { "A1":"K1A", "A2":"0V" } } ],
 *   "sequencia": ["..."], "rungs": [ { "saida":"%Q0.0", "logica":"..." } ]
 * }
 * Cada componente tem pinos nomeados e cada pino aponta para o nome da rede (fio) em que está.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.ProjetistaEletrico = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var FORMATO = 'ProjetistaEletrico CAD';
  var VERSAO = 1;
  var CHAVE_STORE = 'jv_projetos_eletricos';
  var LIMITE_ARQUIVOS = 30;
  var LIMITE_BYTES = 512 * 1024;

  /* ---------- Biblioteca de componentes (pinos e o que conduz) ---------- */
  var TIPOS = {
    disjuntor3: { nome: 'Disjuntor tripolar', grupo: 'potencia', pinos: ['1', '2', '3', '4', '5', '6'], conducao: [['1', '2'], ['3', '4'], ['5', '6']], protege: true },
    disjuntor3p: { nome: 'Disjuntor tripolar (motor)', grupo: 'potencia', pinos: ['1', '2', '3', '4', '5', '6'], conducao: [['1', '2'], ['3', '4'], ['5', '6']], protege: true },
    disjuntor: { nome: 'Disjuntor bipolar', grupo: 'potencia', pinos: ['1', '2', '3', '4'], conducao: [['1', '2'], ['3', '4']], protege: true },
    fusivel: { nome: 'Fusível', grupo: 'comando', pinos: ['1', '2'], conducao: [['1', '2']], protege: true },
    contator: {
      nome: 'Contator', grupo: 'potencia',
      pinos: ['A1', 'A2', '1', '2', '3', '4', '5', '6', '13', '14', '21', '22'],
      obrigatorios: ['A1', 'A2'],
      conducao: [['1', '2'], ['3', '4'], ['5', '6'], ['13', '14'], ['21', '22']],
      bobina: ['A1', 'A2'], na: [['13', '14']], nf: [['21', '22']]
    },
    releTermico: { nome: 'Relé térmico', grupo: 'potencia', pinos: ['1', '2', '3', '4', '5', '6'], conducao: [['1', '2'], ['3', '4'], ['5', '6']], protege: true },
    motor3: { nome: 'Motor trifásico', grupo: 'potencia', pinos: ['U', 'V', 'W', 'PE'], obrigatorios: ['U', 'V', 'W'], carga: true },
    motor6: { nome: 'Motor trifásico (6 pontas)', grupo: 'potencia', pinos: ['U1', 'V1', 'W1', 'U2', 'V2', 'W2', 'PE'], obrigatorios: ['U1', 'V1', 'W1', 'U2', 'V2', 'W2'], carga: true },
    motor1: { nome: 'Motor monofásico', grupo: 'potencia', pinos: ['F', 'N', 'PE'], obrigatorios: ['F', 'N'], carga: true },
    bomba: { nome: 'Bomba', grupo: 'potencia', pinos: ['U', 'V', 'W', 'PE'], obrigatorios: ['U', 'V', 'W'], carga: true },
    botoeira: { nome: 'Botoeira', grupo: 'comando', pinos: ['1', '2'], conducao: [['1', '2']] },
    contatoNA: { nome: 'Contato NA', grupo: 'comando', pinos: ['13', '14'], conducao: [['13', '14']], na: [['13', '14']] },
    contatoNF: { nome: 'Contato NF', grupo: 'comando', pinos: ['21', '22'], conducao: [['21', '22']], nf: [['21', '22']] },
    sinaleiro: { nome: 'Sinaleiro', grupo: 'comando', pinos: ['1', '2'], carga: true },
    temporizador: { nome: 'Temporizador', grupo: 'comando', pinos: ['A1', 'A2', '15', '16', '25', '26'], obrigatorios: ['A1', 'A2', '15', '16'], conducao: [['15', '16'], ['25', '26']], bobina: ['A1', 'A2'] },
    transformador: { nome: 'Transformador de comando', grupo: 'comando', pinos: ['1', '2', '3', '4'], obrigatorios: ['1', '2', '3', '4'] },
    fonte: { nome: 'Fonte de comando', grupo: 'comando', pinos: ['L', 'N', '+', '0'], obrigatorios: ['L', 'N', '+', '0'] },
    sensor: { nome: 'Sensor', grupo: 'comando', pinos: ['1', '2', '3'], obrigatorios: ['1', '2', '3'] },
    interruptor: { nome: 'Interruptor', grupo: 'comando', pinos: ['1', '2'], conducao: [['1', '2']] },
    lampada: { nome: 'Lâmpada', grupo: 'comando', pinos: ['1', '2'], carga: true },
    clp: { nome: 'CLP', grupo: 'clp', pinos: ['L', 'N', 'I1', 'I2', 'I3', 'I4', 'Q1', 'Q2'], obrigatorios: ['L', 'N', 'I1', 'Q1'] },
    autotransformador: { nome: 'Autotransformador', grupo: 'potencia', pinos: ['1', '2', '3', '4', '5', '6'], obrigatorios: ['1', '2', '3', '4', '5', '6'] }
  };

  var EXEMPLOS = [
    'Crie uma partida direta para um motor trifásico de 5 CV, com proteção, botão de emergência, liga/desliga e sinalização.',
    'Crie um circuito de reversão de motor trifásico com dois contatores e intertravamento elétrico e mecânico.',
    'Desenvolva uma partida estrela-triângulo automática com temporizador de 8 segundos.',
    'Crie uma partida compensadora para motor trifásico de 15 CV.',
    'Crie um sistema de controle de nível de água usando CLP, sensores e bomba.',
    'Monte um comando liga/desliga com selo e sinaleiro em 24 V.'
  ];

  /* ---------- Utilidades ---------- */
  function limpar(txt, max) {
    return String(txt == null ? '' : txt).replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/[<>]/g, '').trim().slice(0, max || 200);
  }
  function numero(v, padrao) {
    var n = Number(v);
    return Number.isFinite(n) ? n : padrao;
  }
  function slug(nome) {
    var b = limpar(nome, 80).replace(/\.projeto\.json$/i, '').replace(/[\\/:*?"<>|]+/g, '-').replace(/\s+/g, '-').replace(/^[-.]+/, '');
    return (b || 'projeto') + '.projeto.json';
  }
  function clonar(o) { return JSON.parse(JSON.stringify(o)); }
  function conjunto(lista) {
    var s = {};
    (lista || []).forEach(function (n) { if (n) s[String(n)] = true; });
    return s;
  }
  function bytesDe(txt) {
    var t = String(txt == null ? '' : txt);
    try { if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(t).length; } catch (e) { /* fallback */ }
    return unescape(encodeURIComponent(t)).length;
  }
  function redeUnica(projeto, base) {
    var usadas = {};
    projeto.componentes.forEach(function (c) {
      Object.keys(c.pinos || {}).forEach(function (p) { usadas[c.pinos[p]] = true; });
    });
    var nome = base;
    var i = 2;
    while (usadas[nome]) { nome = base + '_' + i; i++; }
    return nome;
  }

  /* ---------- Interpretação do pedido ---------- */
  function interpretar(texto) {
    var bruto = String(texto == null ? '' : texto);
    var t = bruto.toLowerCase();
    if (!t.trim()) return { ok: false, erro: 'Descreva o circuito: tipo, motor, tensão e o que deve acontecer.' };
    var pendencias = [];
    var decisoes = [];

    var tipo = 'generico';
    if (/revers/.test(t)) tipo = 'reversao';
    else if (/estrela/.test(t) && /tri/.test(t)) tipo = 'estrela_triangulo';
    else if (/compensadora/.test(t)) tipo = 'compensadora';
    else if ((/dois motores|segundo motor|motor\s*2\b|acionamentos sequenciais/.test(t))
      && (/depois|ap[oó]s|temporiz|segundos?|s\b/.test(t))) tipo = 'sequencia';
    else if (/partida\s+direta/.test(t)) tipo = 'partida_direta';
    else if (/\bclp\b|\bplc\b/.test(t) || /n[ií]vel/.test(t)) tipo = 'clp';
    else if (/ilumina|l[aâ]mpada|lumin[aá]ria|poste/.test(t)) tipo = 'iluminacao';
    else if (/comando|liga|desliga|botoeira|selo|sinaleiro/.test(t)) tipo = 'comando';

    var cv = null;
    var mCv = t.match(/(\d+(?:[.,]\d+)?)\s*(?:cv|hp)\b/);
    if (mCv) cv = Number(mCv[1].replace(',', '.'));
    var mKw = t.match(/(\d+(?:[.,]\d+)?)\s*kw\b/);
    if (cv == null && mKw) cv = Math.round((Number(mKw[1].replace(',', '.')) / 0.736) * 10) / 10;

    var trifasico = !/monof[aá]sico|1\s*fase|fase\s*\+\s*neutro|uma\s*fase/.test(t);
    var tensaoPotencia = /440\s*v/.test(t) ? 440 : /380\s*v/.test(t) ? 380 : /220\s*v/.test(t) ? 220 : (trifasico ? 380 : 220);
    var tensaoComando = /24\s*v|24v\b/.test(t) ? 24 : 220;
    var emergencia = !/sem\s+(?:bot[aã]o\s+de\s+)?emerg/.test(t);
    var sinalizacao = /sinaliza|sinaleiro|l[aâ]mpada|led|sirene/.test(t) || tipo === 'partida_direta';
    var temporizador = null;
    var mT = t.match(/(\d+(?:[.,]\d+)?)\s*(?:s\b|seg\b|segundos?\b)/);
    if (mT) temporizador = Number(mT[1].replace(',', '.'));

    if (/partida_direta|reversao|estrela_triangulo|compensadora/.test(tipo)) {
      if (cv == null) {
        cv = 5;
        pendencias.push('Potência do motor não informada: assumindo 5 CV até você confirmar.');
      }
      decisoes.push('Comando em ' + tensaoComando + ' V e potência em ' + tensaoPotencia + ' V' + (trifasico ? ' trifásico' : ' monofásico') + '.');
    }
    if (tipo === 'estrela_triangulo' && temporizador == null) {
      temporizador = 8;
      decisoes.push('Sem tempo informado: temporizador em 8 s (ajustável no projeto).');
    }
    if (tipo === 'compensadora' && temporizador == null) {
      temporizador = 6;
      decisoes.push('Sem tempo de comutação informado: 6 s entre tap e rede.');
    }
    if (tipo === 'sequencia' && temporizador == null) {
      temporizador = 5;
      decisoes.push('Sem tempo informado: o segundo motor entra 5 s depois do primeiro.');
    }
    if (tipo === 'clp') {
      tensaoComando = 24;
      decisoes.push('CLP com 24 Vcc, 3 entradas digitais e 1 saída para a bomba.');
      if (!/n[ií]vel|boia|sensor/.test(t)) pendencias.push('Que sensores o CLP deve ler? Assumindo duas boias (nível baixo e alto) e um botão manual.');
    }
    if (tipo === 'generico') decisoes.push('Pedido sem topologia reconhecida: montando comando liga/desliga com selo e proteção.');

    var spec = {
      tipo: tipo, cv: cv, trifasico: trifasico, tensaoPotencia: tensaoPotencia, tensaoComando: tensaoComando,
      emergencia: emergencia, sinalizacao: sinalizacao, temporizador: temporizador,
      clp: tipo === 'clp', motores: (tipo === 'sequencia' || /dois motores|segundo motor/.test(t)) ? 2 : 1,
      descricao: limpar(bruto, 400)
    };
    return { ok: true, spec: spec, pendencias: pendencias, decisoes: decisoes };
  }

  /* ---------- Montagem ---------- */
  function novoProjeto(pedido, spec) {
    return {
      formato: FORMATO, versao: VERSAO,
      titulo: '', tipo: spec.tipo, pedido: limpar(pedido, 400), spec: spec,
      redes: { energia: [], retorno: [], fases: [] },
      componentes: [], sequencia: [], rungs: [], avisos: [], decisoes: [],
      intertravamentos: [], dimensionamento: {}
    };
  }

  function montador(p) {
    var coluna = { potencia: 0, comando: 0, clp: 0 };
    return function (id, tipo, funcao, pinos, extra) {
      var def = TIPOS[tipo];
      if (!def) throw new Error('Componente "' + id + '": tipo desconhecido ' + tipo);
      var grupo = def.grupo;
      var i = coluna[grupo]++;
      var x = grupo === 'potencia' ? 470 : grupo === 'clp' ? 300 : 110;
      var c = { id: id, tipo: tipo, funcao: funcao || def.nome, pinos: pinos || {}, x: x, y: 40 + i * 58 };
      if (extra) {
        Object.keys(extra).forEach(function (k) { c[k] = extra[k]; });
      }
      p.componentes.push(c);
      return c;
    };
  }

  function baseEletrica() {
    try { return (typeof window !== 'undefined' && window.EletricaBase) || null; } catch (e) { return null; }
  }

  function dimensionar(spec) {
    var B = baseEletrica();
    if (B && B.dimensionar) {
      var d = B.dimensionar(spec || {});
      if (d && d.ok !== false && d.correnteA) return d;
    }
    return dimensionarInterno(spec);
  }

  function dimensionarInterno(spec) {
    if (!spec.cv) return {};
    var potencia = spec.cv * 736;
    var tensao = spec.trifasico ? spec.tensaoPotencia : spec.tensaoPotencia;
    var corrente = spec.trifasico ? potencia / (Math.sqrt(3) * tensao * 0.8 * 0.9) : potencia / (tensao * 0.8 * 0.9);
    var serie = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200];
    function acima(v) { for (var i = 0; i < serie.length; i++) if (serie[i] >= v) return serie[i]; return serie[serie.length - 1]; }
    return {
      potenciaW: Math.round(potencia),
      correnteA: Math.round(corrente * 10) / 10,
      disjuntorA: acima(corrente * 1.15),
      contatorA: acima(corrente),
      termicoA: Math.round(corrente * 1.15 * 10) / 10,
      nota: 'Estimativa didática (fp 0,8 / rendimento 0,9). Dimensionamento final exige cálculo normativo e catálogo do fabricante.'
    };
  }

  function comandoBase(p, add, opcoes) {
    var cmd24 = opcoes.tensaoComando === 24;
    add('F1', 'fusivel', 'Fusível do circuito de comando', { 1: 'R1', 2: 'R1C' }, { papel: 'protecao_comando' });
    if (cmd24) add('T1', 'transformador', 'Transformador de comando → 24 V', { 1: 'R1C', 2: 'N', 3: '24V', 4: '0V' }, { papel: 'fonte_comando' });
    return { fase: cmd24 ? '24V' : 'R1C', retorno: cmd24 ? '0V' : 'N' };
  }

  /** As redes de energia/retorno saem dos próprios pinos: nada de lista decorativa. */
  function definirRedes(p) {
    var usadas = {};
    p.componentes.forEach(function (c) {
      Object.keys(c.pinos || {}).forEach(function (k) { usadas[c.pinos[k]] = true; });
    });
    p.redes = {
      energia: ['L1', 'L2', 'L3', '24V', 'R1C'].filter(function (r) { return usadas[r]; }),
      retorno: ['N', '0V', 'PE', 'RN'].filter(function (r) { return usadas[r]; }),
      fases: ['L1', 'L2', 'L3'].filter(function (r) { return usadas[r]; })
    };
    return p;
  }

  function partidaDireta(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    var cmd = comandoBase(p, add, spec);
    p.dimensionamento = dimensionar(spec);
    p.titulo = 'Partida direta de motor ' + (spec.trifasico ? 'trifásico' : 'monofásico') + ' com comando em ' + spec.tensaoComando + ' V';
    if (spec.trifasico) {
      add('Q1', 'disjuntor3', 'Proteção geral tripolar', { 1: 'L1', 2: 'R1', 3: 'L2', 4: 'R2', 5: 'L3', 6: 'R3' }, { papel: 'protecao' });
      add('K1', 'contator', 'Contator principal', { 1: 'R1', 2: 'S1', 3: 'R2', 4: 'S2', 5: 'R3', 6: 'S3', A1: 'K1A', A2: cmd.retorno, 13: 'CI', 14: 'K1A' }, { papel: 'principal', tensao: spec.tensaoComando });
      add('F2', 'releTermico', 'Relé térmico (sobrecarga)', { 1: 'S1', 2: 'T1', 3: 'S2', 4: 'T2', 5: 'S3', 6: 'T3' }, { papel: 'protecao' });
      add('M1', 'motor3', 'Motor trifásico ' + (spec.cv || '?') + ' CV', { U: 'T1', V: 'T2', W: 'T3', PE: 'PE' }, { papel: 'carga' });
    } else {
      add('Q1', 'disjuntor', 'Proteção geral bipolar (fase e neutro)', { 1: 'L1', 2: 'R1', 3: 'N', 4: 'RN' }, { papel: 'protecao' });
      add('K1', 'contator', 'Contator principal', { 1: 'R1', 2: 'S1', 3: 'RN', 4: 'SN', A1: 'K1A', A2: cmd.retorno, 13: 'CI', 14: 'K1A' }, { papel: 'principal', tensao: spec.tensaoComando });
      add('F2', 'releTermico', 'Relé térmico (sobrecarga)', { 1: 'S1', 2: 'T1', 3: 'SN', 4: 'TN' }, { papel: 'protecao' });
      add('M1', 'motor1', 'Motor monofásico ' + (spec.cv || '?') + ' CV', { F: 'T1', N: 'TN', PE: 'PE' }, { papel: 'carga' });
    }
    if (spec.emergencia) add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: cmd.fase, 2: 'SL' }, { papel: 'emergencia' });
    add('S2', 'botoeira', 'Botoeira desliga (NF)', { 1: spec.emergencia ? 'SL' : cmd.fase, 2: 'CI' }, { papel: 'desliga' });
    add('S1', 'botoeira', 'Botoeira liga (NA)', { 1: 'CI', 2: 'K1A' }, { papel: 'liga' });
    if (spec.sinalizacao) add('H1', 'sinaleiro', 'Sinaleiro: motor ligado', { 1: 'K1A', 2: cmd.retorno }, { papel: 'sinalizacao' });
    p.sequencia = [
      'Pressione S1 (liga): a bobina de K1 é energizada e o contato de selo 13/14 mantém K1 após soltar o botão.',
      'K1 fecha os contatos de força e o motor M1 parte em regime pleno; o térmico F2 protege contra sobrecarga.',
      'Pressione S2 (desliga) ou S0 (emergência): o circuito de comando abre e K1 cai, parando o motor.',
      'Se F2 atuar por sobrecarga, o comando é interrompido e o motor não religa até o rearme.'
    ];
    return definirRedes(p);
  }

  function reversao(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    var cmd = comandoBase(p, add, spec);
    p.dimensionamento = dimensionar(spec);
    p.titulo = 'Reversão de motor trifásico com dois contatores e intertravamento duplo';
    add('Q1', 'disjuntor3', 'Proteção geral tripolar', { 1: 'L1', 2: 'R1', 3: 'L2', 4: 'R2', 5: 'L3', 6: 'R3' }, { papel: 'protecao' });
    // K1: R1,R2,R3. K2: R1,R3,R2 (duas fases trocadas).
    add('K1', 'contator', 'Contator sentido horário', { 1: 'R1', 2: 'U1', 3: 'R2', 4: 'U2', 5: 'R3', 6: 'U3', A1: 'K1A', A2: cmd.retorno, 13: 'C2B', 14: 'K1A', 21: 'CI', 22: 'C1B' }, { papel: 'principal', tensao: spec.tensaoComando });
    add('K2', 'contator', 'Contator sentido anti-horário', { 1: 'R1', 2: 'U1', 3: 'R3', 4: 'U2', 5: 'R2', 6: 'U3', A1: 'K2A', A2: cmd.retorno, 13: 'C1B', 14: 'K2A', 21: 'CI', 22: 'C2B' }, { papel: 'reverso', tensao: spec.tensaoComando });
    add('F2', 'releTermico', 'Relé térmico (sobrecarga)', { 1: 'U1', 2: 'V1', 3: 'U2', 4: 'V2', 5: 'U3', 6: 'V3' }, { papel: 'protecao' });
    add('M1', 'motor3', 'Motor trifásico ' + (spec.cv || '?') + ' CV', { U: 'V1', V: 'V2', W: 'V3', PE: 'PE' }, { papel: 'carga' });
    if (spec.emergencia) add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: cmd.fase, 2: 'SL' }, { papel: 'emergencia' });
    add('S2', 'botoeira', 'Botoeira desliga (NF)', { 1: spec.emergencia ? 'SL' : cmd.fase, 2: 'CI' }, { papel: 'desliga' });
    add('S1', 'botoeira', 'Botoeira horário (NA)', { 1: 'C2B', 2: 'K1A' }, { papel: 'liga' });
    add('S3', 'botoeira', 'Botoeira anti-horário (NA)', { 1: 'C1B', 2: 'K2A' }, { papel: 'liga' });
    if (spec.sinalizacao) {
      add('H1', 'sinaleiro', 'Sinaleiro: horário', { 1: 'K1A', 2: cmd.retorno }, { papel: 'sinalizacao' });
      add('H2', 'sinaleiro', 'Sinaleiro: anti-horário', { 1: 'K2A', 2: cmd.retorno }, { papel: 'sinalizacao' });
    }
    p.intertravamentos = [['K1', 'K2']];
    p.sequencia = [
      'S1 energiza K1 apenas com o NF de K2 fechado; o selo 13/14 de K1 mantém o comando.',
      'S3 energiza K2 apenas com o NF de K1 fechado; assim os dois contatores não podem fechar juntos.',
      'O intertravamento elétrico (NF cruzado) é o primeiro; o mecânico é o bloqueio entre contatores no painel.',
      'S2 ou S0 desliga o sentido ativo; para inverter é preciso parar e acionar o outro botão.'
    ];
    p.avisos.push('Intertravamento mecânico é físico (bloqueio entre contatores) e não é representável só no arquivo.');
    return definirRedes(p);
  }

  function estrelaTriangulo(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    var cmd = comandoBase(p, add, spec);
    var tempo = spec.temporizador || 8;
    p.dimensionamento = dimensionar(spec);
    p.titulo = 'Partida estrela-triângulo automática (' + tempo + ' s) com três contatores';
    add('Q1', 'disjuntor3', 'Proteção geral tripolar', { 1: 'L1', 2: 'R1', 3: 'L2', 4: 'R2', 5: 'L3', 6: 'R3' }, { papel: 'protecao' });
    add('K1', 'contator', 'Contator principal', { 1: 'R1', 2: 'S1', 3: 'R2', 4: 'S2', 5: 'R3', 6: 'S3', A1: 'K1A', A2: cmd.retorno, 13: 'CI', 14: 'K1A' }, { papel: 'principal', tensao: spec.tensaoComando });
    add('F2', 'releTermico', 'Relé térmico (sobrecarga)', { 1: 'S1', 2: 'T1', 3: 'S2', 4: 'T2', 5: 'S3', 6: 'T3' }, { papel: 'protecao' });
    add('M1', 'motor6', 'Motor trifásico ' + (spec.cv || '?') + ' CV, 6 pontas', { U1: 'T1', V1: 'T2', W1: 'T3', U2: 'T4', V2: 'T5', W2: 'T6', PE: 'PE' }, { papel: 'carga' });
    // KY fecha T4/T5/T6 entre si (estrela); KD liga T4/T5/T6 às fases (triângulo).
    add('KY', 'contator', 'Contator estrela (fecha U2/V2/W2)', { 1: 'T4', 2: 'EST', 3: 'T5', 4: 'EST', 5: 'T6', 6: 'EST', A1: 'KYA', A2: cmd.retorno, 21: 'CI', 22: 'KYF' }, { papel: 'estrela', tensao: spec.tensaoComando });
    add('KD', 'contator', 'Contator triângulo', { 1: 'T4', 2: 'R1', 3: 'T5', 4: 'R2', 5: 'T6', 6: 'R3', A1: 'KDA', A2: cmd.retorno, 21: 'CI', 22: 'KDF' }, { papel: 'triangulo', tensao: spec.tensaoComando });
    add('KT', 'temporizador', 'Temporizador estrela→triângulo (' + tempo + ' s)', { A1: 'K1A', A2: cmd.retorno, 15: 'KDF', 16: 'KYA', 25: 'KYF', 26: 'KDA' }, { papel: 'temporizador', tensao: spec.tensaoComando, tempo: tempo });
    if (spec.emergencia) add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: cmd.fase, 2: 'SL' }, { papel: 'emergencia' });
    add('S2', 'botoeira', 'Botoeira desliga (NF)', { 1: spec.emergencia ? 'SL' : cmd.fase, 2: 'CI' }, { papel: 'desliga' });
    add('S1', 'botoeira', 'Botoeira liga (NA)', { 1: 'CI', 2: 'K1A' }, { papel: 'liga' });
    if (spec.sinalizacao) {
      add('H1', 'sinaleiro', 'Sinaleiro: motor em estrela', { 1: 'KYA', 2: cmd.retorno }, { papel: 'sinalizacao' });
      add('H2', 'sinaleiro', 'Sinaleiro: motor em triângulo', { 1: 'KDA', 2: cmd.retorno }, { papel: 'sinalizacao' });
    }
    p.intertravamentos = [['KY', 'KD']];
    p.sequencia = [
      'S1 energiza K1 (principal) e, pelo NF de KD, também KY: o motor parte em estrela, com corrente reduzida.',
      'O selo de K1 mantém o comando e o temporizador KT conta ' + tempo + ' s.',
      'Ao fim do tempo, KT abre o caminho de KY e, pelo NF de KY, energiza KD: o motor passa a triângulo.',
      'S2 ou S0 desliga tudo; KY e KD não podem fechar juntos (NF cruzado).'
    ];
    return definirRedes(p);
  }

  function sequenciaMotores(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    var cmd = comandoBase(p, add, spec);
    var tempo = spec.temporizador || 5;
    p.dimensionamento = dimensionar(spec);
    p.titulo = 'Dois motores em sequência: M2 entra ' + tempo + ' s depois de M1';
    add('Q1', 'disjuntor3', 'Proteção geral tripolar', { 1: 'L1', 2: 'R1', 3: 'L2', 4: 'R2', 5: 'L3', 6: 'R3' }, { papel: 'protecao' });
    add('Q2', 'disjuntor3', 'Disjuntor tripolar do motor 2', { 1: 'R1', 2: 'R4', 3: 'R2', 4: 'R5', 5: 'R3', 6: 'R6' }, { papel: 'protecao' });
    add('K1', 'contator', 'Contator do motor 1', { 1: 'R1', 2: 'S1', 3: 'R2', 4: 'S2', 5: 'R3', 6: 'S3', A1: 'K1A', A2: cmd.retorno, 13: 'CI', 14: 'K1A' }, { papel: 'principal', tensao: spec.tensaoComando });
    add('F2', 'releTermico', 'Relé térmico do motor 1', { 1: 'S1', 2: 'T1', 3: 'S2', 4: 'T2', 5: 'S3', 6: 'T3' }, { papel: 'protecao' });
    add('M1', 'motor3', 'Motor 1 — ' + (spec.cv || '?') + ' CV', { U: 'T1', V: 'T2', W: 'T3', PE: 'PE' }, { papel: 'carga' });
    add('K2', 'contator', 'Contator do motor 2', { 1: 'R4', 2: 'S4', 3: 'R5', 4: 'S5', 5: 'R6', 6: 'S6', A1: 'KT2', A2: cmd.retorno, 13: 'K2S', 14: 'KT2' }, { papel: 'secundario', tensao: spec.tensaoComando });
    add('F3', 'releTermico', 'Relé térmico do motor 2', { 1: 'S4', 2: 'T4', 3: 'S5', 4: 'T5', 5: 'S6', 6: 'T6' }, { papel: 'protecao' });
    add('M2', 'motor3', 'Motor 2 — ' + (spec.cv || '?') + ' CV', { U: 'T4', V: 'T5', W: 'T6', PE: 'PE' }, { papel: 'carga' });
    add('KT', 'temporizador', 'Temporizador do motor 2 (' + tempo + ' s)', { A1: 'K1A', A2: cmd.retorno, 15: 'K1A', 16: 'KT2' }, { papel: 'temporizador', tensao: spec.tensaoComando, tempo: tempo });
    if (spec.emergencia) add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: cmd.fase, 2: 'SL' }, { papel: 'emergencia' });
    add('S2', 'botoeira', 'Botoeira desliga (NF)', { 1: spec.emergencia ? 'SL' : cmd.fase, 2: 'CI' }, { papel: 'desliga' });
    add('S1', 'botoeira', 'Botoeira liga (NA)', { 1: 'CI', 2: 'K1A' }, { papel: 'liga' });
    if (spec.sinalizacao) {
      add('H1', 'sinaleiro', 'Sinaleiro: motor 1 ligado', { 1: 'K1A', 2: cmd.retorno }, { papel: 'sinalizacao' });
      add('H2', 'sinaleiro', 'Sinaleiro: motor 2 ligado', { 1: 'K2S', 2: cmd.retorno }, { papel: 'sinalizacao' });
    }
    p.sequencia = [
      'S1 energiza K1; o selo 13/14 mantém o motor 1 ligado depois de soltar o botão.',
      'Com K1 fechado, o temporizador KT conta ' + tempo + ' s; o contato 15/16 só fecha no fim do tempo.',
      'Ao fim do tempo, KT energiza K2: o motor 2 parte com o motor 1 já em regime, como pedido.',
      'S2 ou S0 desliga os dois motores; cada motor tem disjuntor, térmico e contator próprios.'
    ];
    p.avisos.push('A partida do motor 2 depende de K1 e do temporizador; se K1 cair, KT zera e o motor 2 para.');
    return definirRedes(p);
  }

  function compensadora(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    var cmd = comandoBase(p, add, spec);
    var tempo = spec.temporizador || 6;
    p.dimensionamento = dimensionar(spec);
    p.titulo = 'Partida compensadora (autotransformador) com comutação em ' + tempo + ' s';
    add('Q1', 'disjuntor3', 'Proteção geral tripolar', { 1: 'L1', 2: 'R1', 3: 'L2', 4: 'R2', 5: 'L3', 6: 'R3' }, { papel: 'protecao' });
    add('AT1', 'autotransformador', 'Autotransformador de partida (tap 65%)', { 1: 'R1', 2: 'R2', 3: 'R3', 4: 'P1', 5: 'P2', 6: 'P3' }, { papel: 'autotransformador' });
    add('K1', 'contator', 'Contator de linha', { 1: 'R1', 2: 'S1', 3: 'R2', 4: 'S2', 5: 'R3', 6: 'S3', A1: 'K1A', A2: cmd.retorno, 13: 'CI', 14: 'K1A' }, { papel: 'principal', tensao: spec.tensaoComando });
    add('KTAP', 'contator', 'Contator do tap (partida reduzida)', { 1: 'P1', 2: 'T1', 3: 'P2', 4: 'T2', 5: 'P3', 6: 'T3', A1: 'TAPA', A2: cmd.retorno, 21: 'KD1', 22: 'KDA' }, { papel: 'tap', tensao: spec.tensaoComando });
    add('KD', 'contator', 'Contator de regime pleno', { 1: 'R1', 2: 'T1', 3: 'R2', 4: 'T2', 5: 'R3', 6: 'T3', A1: 'KDA', A2: cmd.retorno, 21: 'KT1', 22: 'TAPA' }, { papel: 'regime', tensao: spec.tensaoComando });
    add('F2', 'releTermico', 'Relé térmico (sobrecarga)', { 1: 'T1', 2: 'U1', 3: 'T2', 4: 'U2', 5: 'T3', 6: 'U3' }, { papel: 'protecao' });
    add('M1', 'motor3', 'Motor trifásico ' + (spec.cv || '?') + ' CV', { U: 'U1', V: 'U2', W: 'U3', PE: 'PE' }, { papel: 'carga' });
    add('KT', 'temporizador', 'Temporizador tap→rede (' + tempo + ' s)', { A1: 'K1A', A2: cmd.retorno, 15: 'K1A', 16: 'KT1', 25: 'K1A', 26: 'KD1' }, { papel: 'temporizador', tensao: spec.tensaoComando, tempo: tempo });
    if (spec.emergencia) add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: cmd.fase, 2: 'SL' }, { papel: 'emergencia' });
    add('S2', 'botoeira', 'Botoeira desliga (NF)', { 1: spec.emergencia ? 'SL' : cmd.fase, 2: 'CI' }, { papel: 'desliga' });
    add('S1', 'botoeira', 'Botoeira liga (NA)', { 1: 'CI', 2: 'K1A' }, { papel: 'liga' });
    p.intertravamentos = [['KTAP', 'KD']];
    p.sequencia = [
      'S1 energiza K1 (linha) e, pelo NF de KD, KTAP: o motor parte pelo tap do autotransformador.',
      'O temporizador KT conta ' + tempo + ' s com o motor ainda no tap.',
      'Ao fim do tempo, KT desliga KTAP e, pelo NF de KTAP, energiza KD: o motor recebe tensão plena.',
      'KD e KTAP têm NF cruzado: nunca ficam fechados ao mesmo tempo.'
    ];
    p.avisos.push('O tap do autotransformador é declarado como 65%; confirme no equipamento antes de executar.');
    return definirRedes(p);
  }

  function comandoSimples(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    var cmd24 = spec.tensaoComando === 24;
    var fase = cmd24 ? '24V' : 'R1C';
    var ret = cmd24 ? '0V' : 'N';
    p.titulo = 'Comando liga/desliga com selo e sinalização em ' + spec.tensaoComando + ' V';
    add('F1', 'fusivel', 'Fusível do comando', { 1: 'L1', 2: 'R1C' }, { papel: 'protecao_comando' });
    if (cmd24) add('T1', 'transformador', 'Transformador de comando → 24 V', { 1: 'R1C', 2: 'N', 3: '24V', 4: '0V' }, { papel: 'fonte_comando' });
    add('K1', 'contator', 'Contator do circuito', { A1: 'K1A', A2: ret, 13: 'CI', 14: 'K1A' }, { papel: 'principal', tensao: spec.tensaoComando });
    if (spec.emergencia) add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: fase, 2: 'SL' }, { papel: 'emergencia' });
    add('S2', 'botoeira', 'Botoeira desliga (NF)', { 1: spec.emergencia ? 'SL' : fase, 2: 'CI' }, { papel: 'desliga' });
    add('S1', 'botoeira', 'Botoeira liga (NA)', { 1: 'CI', 2: 'K1A' }, { papel: 'liga' });
    if (spec.sinalizacao) add('H1', 'sinaleiro', 'Sinaleiro: ligado', { 1: 'K1A', 2: ret }, { papel: 'sinalizacao' });
    p.sequencia = [
      'S1 energiza K1; o contato 13/14 sela o comando quando o botão é solto.',
      'S2 (ou S0) interrompe a alimentação da bobina e K1 cai.',
      'K1 pode comandar carga, contator maior ou aviso remoto pelos contatos auxiliares.'
    ];
    return definirRedes(p);
  }

  function iluminacao(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    p.titulo = 'Circuito de iluminação com proteção e interruptor';
    add('Q1', 'disjuntor', 'Disjuntor bipolar do circuito', { 1: 'L1', 2: 'R1', 3: 'N', 4: 'RN' }, { papel: 'protecao' });
    add('S4', 'interruptor', 'Interruptor simples', { 1: 'R1', 2: 'LMP' }, { papel: 'comando' });
    add('L1', 'lampada', 'Lâmpada / luminária', { 1: 'LMP', 2: 'RN' }, { papel: 'carga', x: 470, y: 98 });
    if (/sensor|presen/.test(String(pedido).toLowerCase())) {
      add('S5', 'sensor', 'Sensor de presença', { 1: 'R1', 2: 'RN', 3: 'LMP' }, { papel: 'sensor' });
      p.avisos.push('Sensor de presença precisa de fase, neutro e retorno para a carga; confirme o modelo (3 fios).');
    }
    p.sequencia = [
      'O disjuntor Q1 protege fase e neutro do circuito.',
      'O interruptor S4 leva fase à lâmpada; o neutro retorna pelo mesmo circuito.',
      'Com sensor de presença, o acionamento é automático e o interruptor pode ser dispensado.'
    ];
    return definirRedes(p);
  }

  function clpNivel(pedido, spec) {
    var p = novoProjeto(pedido, spec);
    var add = montador(p);
    p.titulo = 'Controle de nível de água com CLP: boias, bomba e sinalização';
    add('Q1', 'disjuntor', 'Disjuntor bipolar da alimentação 24 V', { 1: 'L1', 2: 'R1', 3: 'N', 4: 'RN' }, { papel: 'protecao' });
    add('G1', 'fonte', 'Fonte 24 Vcc', { L: 'R1', N: 'RN', '+': '24V', 0: '0V' }, { papel: 'fonte' });
    add('PLC1', 'clp', 'CLP (3 entradas digitais, 1 saída)', {
      L: '24V', N: '0V', I1: 'NB', I2: 'NA', I3: 'BM', I4: '0V', Q1: 'BK'
    }, {
      papel: 'controlador',
      enderecos: { I1: '%I0.0', I2: '%I0.1', I3: '%I0.2', I4: '%I0.3', Q1: '%Q0.0' }
    });
    add('B1', 'sensor', 'Boia de nível baixo (fecha com tanque baixo)', { 1: '24V', 2: '0V', 3: 'NB' }, { papel: 'sensor' });
    add('B2', 'sensor', 'Boia de nível alto (abre com tanque cheio)', { 1: '24V', 2: '0V', 3: 'NA' }, { papel: 'sensor' });
    add('S1', 'botoeira', 'Botoeira manual da bomba (NA)', { 1: '24V', 2: 'BM' }, { papel: 'liga' });
    add('S0', 'botoeira', 'Botoeira de emergência (NF)', { 1: 'BK', 2: 'BK1' }, { papel: 'emergencia' });
    add('K1', 'contator', 'Contator da bomba', { A1: 'BK1', A2: '0V' }, { papel: 'principal', tensao: 24 });
    add('Q2', 'disjuntor3', 'Disjuntor tripolar da bomba', { 1: 'L1', 2: 'BP1', 3: 'L2', 4: 'BP2', 5: 'L3', 6: 'BP3' }, { papel: 'protecao' });
    add('F3', 'releTermico', 'Relé térmico da bomba', { 1: 'BP1', 2: 'BM1', 3: 'BP2', 4: 'BM2', 5: 'BP3', 6: 'BM3' }, { papel: 'protecao' });
    add('M1', 'bomba', 'Bomba ' + (spec.cv || '1') + ' CV', { U: 'BM1', V: 'BM2', W: 'BM3', PE: 'PE' }, { papel: 'carga' });
    if (spec.sinalizacao) add('H1', 'sinaleiro', 'Sinaleiro de falha / tanque cheio', { 1: 'BK1', 2: '0V' }, { papel: 'sinalizacao' });
    p.rungs = [
      { saida: '%Q0.0', logica: '(%I0.0 OU %I0.2 OU %Q0.0) E NAO %I0.1', descricao: 'Liga a bomba com nível baixo ou botão manual e mantém por selo; desliga com nível alto.' }
    ];
    p.sequencia = [
      'Com o tanque baixo, a boia B1 fecha %I0.0 e o CLP liga a saída %Q0.0 (contator K1).',
      'O selo em %Q0.0 mantém a bomba ligada mesmo depois que a boia de mínimo abre.',
      'Quando a boia de nível alto B2 fecha %I0.1, a lógica desliga a saída e a bomba para.',
      'A botoeira S1 permite acionamento manual, respeitando o desligamento por nível alto.'
    ];
    p.avisos.push('A lógica ladder é entregue como lista de expressões verificáveis; o CLP real precisa de endereçamento e símbolos do fabricante.');
    p.avisos.push('A potência da bomba (L1/L2/L3) precisa de disjuntor e térmico próprios: este projeto cobre o comando.');
    return definirRedes(p);
  }

  function projetar(entrada, opcoes) {
    var o = opcoes || {};
    var spec;
    var pedido;
    if (entrada && typeof entrada === 'object') {
      spec = entrada.spec || entrada;
      pedido = entrada.pedido || spec.descricao || '';
    } else {
      var inter = interpretar(entrada);
      if (!inter.ok) return { ok: false, erro: inter.erro };
      spec = inter.spec;
      pedido = String(entrada);
    }
    if (!spec || !spec.tipo) return { ok: false, erro: 'Especificação sem tipo de circuito.' };
    spec = clonar(spec);
    spec.tensaoComando = numero(spec.tensaoComando, 220);
    spec.tensaoPotencia = numero(spec.tensaoPotencia, spec.trifasico === false ? 220 : 380);
    spec.trifasico = spec.trifasico !== false;
    spec.emergencia = spec.emergencia !== false;
    var p;
    switch (spec.tipo) {
      case 'partida_direta': p = partidaDireta(pedido, spec); break;
      case 'reversao': p = reversao(pedido, spec); break;
      case 'estrela_triangulo': p = estrelaTriangulo(pedido, spec); break;
      case 'compensadora': p = compensadora(pedido, spec); break;
      case 'sequencia': p = sequenciaMotores(pedido, spec); break;
      case 'iluminacao': p = iluminacao(pedido, spec); break;
      case 'clp': p = clpNivel(pedido, spec); break;
      default: p = comandoSimples(pedido, spec); break;
    }
    p.decisoes = (o.decisoes || []).slice();
    if (spec.tipo !== 'partida_direta' || spec.tensaoComando !== 24) { /* nada */ }
    return { ok: true, projeto: p };
  }

  /* ---------- Índice e continuidade ---------- */
  function indice(projeto, ignorar) {
    var idx = { comp: {}, rede: {}, porRede: {}, condutor: {} };
    var fora = conjunto(ignorar || []);
    (projeto.componentes || []).forEach(function (c) {
      idx.comp[c.id] = c;
      Object.keys(c.pinos || {}).forEach(function (pin) {
        var chave = c.id + '.' + pin;
        var rede = String(c.pinos[pin] || '');
        idx.rede[chave] = rede;
        if (!idx.porRede[rede]) idx.porRede[rede] = [];
        idx.porRede[rede].push(chave);
      });
      var def = TIPOS[c.tipo] || {};
      if (fora[c.id]) return;
      (def.conducao || []).forEach(function (par) {
        var a = c.id + '.' + par[0];
        var b = c.id + '.' + par[1];
        if (!idx.condutor[a]) idx.condutor[a] = [];
        if (!idx.condutor[b]) idx.condutor[b] = [];
        idx.condutor[a].push(b);
        idx.condutor[b].push(a);
      });
    });
    return idx;
  }

  /** Caminho pelos fios e contatos (não atravessa bobina, carga, fonte nem transformador). */
  function caminho(idx, inicio, alvos) {
    if (idx.rede[inicio] == null) return null;
    var fila = [inicio];
    var pai = {};
    var visto = {};
    visto[inicio] = true;
    pai[inicio] = null;
    if (alvos[idx.rede[inicio]]) return [inicio];
    while (fila.length) {
      var atual = fila.shift();
      var viz = (idx.porRede[idx.rede[atual]] || []).concat(idx.condutor[atual] || []);
      for (var i = 0; i < viz.length; i++) {
        var v = viz[i];
        if (v === atual || visto[v]) continue;
        visto[v] = true;
        pai[v] = atual;
        if (alvos[idx.rede[v]]) {
          var trilha = [v];
          var anterior = pai[v];
          while (anterior) { trilha.push(anterior); anterior = pai[anterior]; }
          return trilha.reverse();
        }
        fila.push(v);
      }
    }
    return null;
  }

  /* ---------- Verificação ---------- */
  function validar(projeto) {
    var erros = [], avisos = [];
    function erro(codigo, mensagem, componente) {
      erros.push({ codigo: codigo, mensagem: mensagem, componente: componente || '', corrigivel: ['falta_intertravamento', 'falta_emergencia', 'falta_protecao', 'tensao_bobina'].indexOf(codigo) >= 0 });
    }
    if (!projeto || !Array.isArray(projeto.componentes) || !projeto.componentes.length) {
      return { ok: false, erros: [{ codigo: 'vazio', mensagem: 'Projeto sem componentes.', corrigivel: false }], avisos: [], verificacao: { componentes: 0, fios: 0, regras: 0 } };
    }
    var idx = indice(projeto);
    var energia = conjunto((projeto.redes && projeto.redes.energia) || []);
    projeto.componentes.forEach(function (c) {
      if (c.tipo !== 'clp') return;
      Object.keys(c.pinos || {}).forEach(function (p) {
        if (/^Q/.test(p) && c.pinos[p]) energia[c.pinos[p]] = true;
      });
    });
    var retorno = conjunto((projeto.redes && projeto.redes.retorno) || []);
    var retornoTotal = {};
    Object.keys(retorno).forEach(function (k) { retornoTotal[k] = true; });
    Object.keys(energia).forEach(function (k) { });

    projeto.componentes.forEach(function (c) {
      var def = TIPOS[c.tipo];
      if (!def) { erro('tipo', 'Componente ' + c.id + ' tem tipo desconhecido "' + c.tipo + '".', c.id); return; }
      var pins = c.pinos || {};
      (def.obrigatorios || def.pinos).forEach(function (pin) {
        if (!pins[pin]) erro('terminal_solto', 'Componente ' + c.id + ' (' + def.nome + '): terminal ' + pin + ' sem ligação.', c.id);
      });
      (def.conducao || []).forEach(function (par) {
        if (pins[par[0]] && pins[par[1]] && pins[par[0]] === pins[par[1]]) {
          erro('curto', 'Componente ' + c.id + ': ' + par[0] + ' e ' + par[1] + ' estão na mesma rede "' + pins[par[0]] + '" (curto).', c.id);
        }
      });
      if (c.tensao != null && projeto.spec && projeto.spec.tensaoComando != null && Number(c.tensao) !== Number(projeto.spec.tensaoComando)) {
        erro('tensao_bobina', 'Bobina de ' + c.id + ' é ' + c.tensao + ' V e o comando é ' + projeto.spec.tensaoComando + ' V.', c.id);
      }
      if (def.bobina && pins[def.bobina[0]] && pins[def.bobina[1]]) {
        var positivo = caminho(idx, c.id + '.' + def.bobina[0], energia);
        var negativo = caminho(idx, c.id + '.' + def.bobina[1], retornoTotal);
        if (!positivo) erro('bobina_sem_alimentacao', 'Bobina de ' + c.id + ' não alcança a alimentação do comando (nada fecha o circuito até ' + Object.keys(energia).join('/') + ').', c.id);
        if (!negativo) erro('bobina_sem_alimentacao', 'Bobina de ' + c.id + ' não fecha o retorno (' + Object.keys(retornoTotal).join('/') + ').', c.id);
        if (positivo && projeto.spec && projeto.spec.emergencia) {
          var temEmergencia = positivo.some(function (chave) {
            var outro = idx.comp[chave.split('.')[0]];
            return outro && outro.papel === 'emergencia';
          });
          if (!temEmergencia) erro('falta_emergencia', 'A bobina de ' + c.id + ' pode ser energizada sem passar pela botoeira de emergência.', c.id);
        }
      }
    });

    if (projeto.spec && projeto.spec.emergencia) {
      var temBotao = projeto.componentes.some(function (c) { return c.papel === 'emergencia'; });
      if (!temBotao) erro('falta_emergencia', 'O projeto não tem botoeira de emergência no comando.');
    }

    projeto.componentes.forEach(function (c) {
      var def = TIPOS[c.tipo];
      if (!def || !def.carga || !/motor|bomba/.test(c.tipo)) return;
      var pinos = Object.keys(c.pinos || {}).filter(function (p) { return p !== 'PE' && c.pinos[p]; });
      if (!pinos.length) return;
      var cam = caminho(idx, c.id + '.' + pinos[0], energia);
      if (!cam) {
        erro('motor_sem_alimentacao', 'Carga ' + c.id + ' não alcança a alimentação.', c.id);
        return;
      }
      // O disjuntor geral sozinho não cobre sobrecarga: a carga precisa de térmico (ou disjuntor-motor).
      var protegido = cam.some(function (chave) {
        var outro = idx.comp[chave.split('.')[0]];
        return outro && (outro.tipo === 'releTermico' || outro.tipo === 'disjuntor3p');
      });
      if (!protegido) erro('falta_protecao', 'Carga ' + c.id + ' não tem disjuntor nem relé térmico no caminho de alimentação.', c.id);
    });

    (projeto.intertravamentos || []).forEach(function (par) {
      par.forEach(function (id) {
        var outro = par[0] === id ? par[1] : par[0];
        var c = idx.comp[id];
        var o = idx.comp[outro];
        if (!c || !o) return;
        var defOutro = TIPOS[o.tipo] || {};
        var nf = (defOutro.nf || []).map(function (p) { return outro + '.' + p[0]; });
        var cam = caminho(idx, id + '.A1', energia);
        if (!cam) return;
        var passa = cam.some(function (chave) { return nf.indexOf(chave) >= 0; });
        if (!passa) erro('falta_intertravamento', 'Contator ' + id + ' pode ser energizado com ' + outro + ' fechado: falta o contato NF de ' + outro + ' em série com a bobina de ' + id + '.', id);
      });
    });

    if (projeto.spec && projeto.spec.cv) {
      var EB = baseEletrica();
      if (EB && EB.conferirDimensionamento) {
        var cd = EB.conferirDimensionamento(projeto);
        (cd.faltas || []).forEach(function (f) { erro('dimensionamento_' + f.codigo, f.mensagem); });
        (cd.avisos || []).forEach(function (t) { avisos.push(t); });
      }
    }

    if (projeto.tipo === 'estrela_triangulo' || projeto.tipo === 'compensadora') {
      if (!projeto.componentes.some(function (c) { return c.tipo === 'temporizador'; })) {
        erro('sem_temporizador', 'A comutação automática precisa de temporizador, e o projeto não tem nenhum.');
      }
    }

    if (projeto.tipo === 'clp' || projeto.componentes.some(function (c) { return c.tipo === 'clp'; })) {
      var enderecos = {};
      projeto.componentes.forEach(function (c) {
        Object.keys(c.enderecos || {}).forEach(function (pino) {
          var end = c.enderecos[pino];
          if (enderecos[end]) erro('clp_endereco_duplicado', 'Endereço ' + end + ' usado por ' + enderecos[end] + ' e por ' + c.id + '.' + pino + '.', c.id);
          enderecos[end] = c.id + '.' + pino;
          if (!/^%[IQ][0-9]{1,3}\.[0-7]$/.test(end)) erro('clp_endereco_invalido', 'Endereço "' + end + '" de ' + c.id + '.' + pino + ' não segue o formato %I0.0 / %Q0.0.', c.id);
        });
      });
      var clp = projeto.componentes.filter(function (c) { return c.tipo === 'clp'; })[0];
      if (clp) {
        var saidas = Object.keys(clp.pinos || {}).filter(function (p) { return /^Q/.test(p) && clp.pinos[p]; });
        saidas.forEach(function (p) {
          var consumidores = (idx.porRede[clp.pinos[p]] || []).filter(function (chave) { return chave.indexOf(clp.id + '.') !== 0; });
          var temCarga = consumidores.some(function (chave) {
            var outro = idx.comp[chave.split('.')[0]];
            return outro && (TIPOS[outro.tipo] || {}).carga;
          });
          var temBobina = consumidores.some(function (chave) {
            var outro = idx.comp[chave.split('.')[0]];
            return outro && (TIPOS[outro.tipo] || {}).bobina;
          });
          if (!temCarga && !temBobina) avisos.push('Saída ' + p + ' do CLP (' + clp.pinos[p] + ') não aciona carga nem bobina declarada.');
        });
      }
    }

    var fases = (projeto.redes && projeto.redes.fases) || [];
    var intertravados = [];
    (projeto.intertravamentos || []).forEach(function (par) { intertravados = intertravados.concat(par); });
    var idxFases = indice(projeto, intertravados);
    for (var i = 0; i < fases.length; i++) {
      for (var j = i + 1; j < fases.length; j++) {
        var alvo = {};
        alvo[fases[j]] = true;
        var inicio = (idxFases.porRede[fases[i]] || [])[0];
        if (inicio && caminho(idxFases, inicio, alvo)) {
          erro('curto_entre_fases', 'Existe caminho fechado entre ' + fases[i] + ' e ' + fases[j] + ': curto entre fases.');
        }
      }
    }

    var usados = {};
    Object.keys(idx.porRede).forEach(function (rede) { usados[rede] = (idx.porRede[rede] || []).length; });
    ['L1', 'L2', 'L3', '24V', 'R1C'].forEach(function (r) {
      if (usados[r] === 1) avisos.push('Rede ' + r + ' tem só um ponto ligado: provável fio solto.');
    });

    var regras = 8 + ((projeto.intertravamentos || []).length * 2);
    return {
      ok: erros.length === 0,
      erros: erros,
      avisos: avisos,
      verificacao: {
        componentes: projeto.componentes.length,
        pinos: Object.keys(idx.rede).length,
        fios: fios(projeto).length,
        regras: regras,
        continuidade: true,
        eletrica: false,
        simulacao: false,
        cadesimu: false
      }
    };
  }

  /* ---------- Correção estrutural ---------- */
  function acharOutro(projeto, id) {
    var pares = projeto.intertravamentos || [];
    for (var i = 0; i < pares.length; i++) {
      if (pares[i][0] === id) return pares[i][1];
      if (pares[i][1] === id) return pares[i][0];
    }
    return null;
  }

  function aplicarIntertravamento(projeto, id) {
    var outroId = acharOutro(projeto, id);
    if (!outroId) return false;
    var c = projeto.componentes.filter(function (x) { return x.id === id; })[0];
    var o = projeto.componentes.filter(function (x) { return x.id === outroId; })[0];
    if (!c || !o || !c.pinos.A1) return false;
    var def = TIPOS[o.tipo] || {};
    var nf = def.nf && def.nf[0];
    if (!nf) return false;
    if (o.pinos[nf[0]] || o.pinos[nf[1]]) return false;
    var original = c.pinos.A1;
    var novo = redeUnica(projeto, original + '_NF');
    c.pinos.A1 = novo;
    o.pinos[nf[0]] = original;
    o.pinos[nf[1]] = novo;
    return true;
  }

  function aplicarEmergencia(projeto) {
    if (projeto.componentes.some(function (c) { return c.papel === 'emergencia'; })) return false;
    var desliga = projeto.componentes.filter(function (c) { return c.papel === 'desliga'; })[0];
    if (!desliga || !desliga.pinos['1']) return false;
    var alimentacao = desliga.pinos['1'];
    var novo = redeUnica(projeto, 'EMG');
    desliga.pinos['1'] = novo;
    projeto.componentes.push({
      id: 'S0', tipo: 'botoeira', funcao: 'Botoeira de emergência (NF)', papel: 'emergencia',
      pinos: { 1: alimentacao, 2: novo }, x: 110, y: 460
    });
    return true;
  }

  function aplicarProtecao(projeto, motorId) {
    var motor = projeto.componentes.filter(function (c) { return c.id === motorId; })[0];
    if (!motor) return false;
    if (projeto.componentes.some(function (c) { return c.tipo === 'releTermico'; })) return false;
    var fases = Object.keys(motor.pinos || {}).filter(function (p) { return p !== 'PE'; });
    if (fases.length < 2) return false;
    var pinos = {};
    var i = 1;
    fases.forEach(function (p) {
      var antigo = motor.pinos[p];
      var novo = redeUnica(projeto, antigo + 'T');
      pinos[String(i)] = antigo;
      pinos[String(i + 1)] = novo;
      motor.pinos[p] = novo;
      i += 2;
    });
    projeto.componentes.push({
      id: 'F2', tipo: 'releTermico', funcao: 'Relé térmico (sobrecarga)', papel: 'protecao',
      pinos: pinos, x: 470, y: 300
    });
    return true;
  }

  function corrigir(projeto) {
    if (!projeto || !Array.isArray(projeto.componentes)) return { ok: false, erro: 'Projeto inválido.' };
    var atual = clonar(projeto);
    var correcoes = [];
    for (var volta = 0; volta < 5; volta++) {
      var v = validar(atual);
      if (v.ok) break;
      var mudou = false;
      v.erros.forEach(function (e) {
        if (e.codigo === 'falta_intertravamento' && aplicarIntertravamento(atual, e.componente)) {
          correcoes.push('Contato NF de segurança em série com a bobina de ' + e.componente + '.');
          mudou = true;
        } else if (e.codigo === 'falta_emergencia' && aplicarEmergencia(atual)) {
          correcoes.push('Botoeira de emergência NF inserida no comando.');
          mudou = true;
        } else if (e.codigo === 'falta_protecao' && aplicarProtecao(atual, e.componente)) {
          correcoes.push('Relé térmico inserido no circuito de força da carga ' + e.componente + '.');
          mudou = true;
        } else if (e.codigo === 'tensao_bobina') {
          atual.componentes.forEach(function (c) {
            if (c.id === e.componente) c.tensao = atual.spec.tensaoComando;
          });
          correcoes.push('Tensão da bobina de ' + e.componente + ' ajustada para ' + atual.spec.tensaoComando + ' V.');
          mudou = true;
        }
      });
      if (!mudou) break;
    }
    var final = validar(atual);
    atual.avisos = (atual.avisos || []).concat(final.avisos.slice(0, 3));
    return { ok: final.ok, projeto: atual, correcoes: correcoes, validacao: final };
  }

  /* ---------- Fios, relatório e ladder ---------- */
  function fios(projeto) {
    var ordem = [], vistos = {};
    function push(n) { if (n && !vistos[n]) { vistos[n] = true; ordem.push(String(n)); } }
    ['L1', 'L2', 'L3', 'N', 'PE', '24V', '0V'].forEach(push);
    (projeto.componentes || []).forEach(function (c) {
      Object.keys(c.pinos || {}).forEach(function (p) { push(c.pinos[p]); });
    });
    return ordem.map(function (n, i) { return { numero: i + 1, rede: n }; });
  }

  function resumoComponentes(projeto) {
    return (projeto.componentes || []).map(function (c) {
      return { id: c.id, tipo: (TIPOS[c.tipo] || {}).nome || c.tipo, funcao: c.funcao, tensao: c.tensao };
    });
  }

  function relatorio(projeto) {
    var v = validar(projeto);
    var linhas = [];
    linhas.push('RELATÓRIO TÉCNICO — ' + (projeto.titulo || projeto.tipo));
    linhas.push('Pedido: ' + limpar(projeto.pedido, 200));
    linhas.push('');
    linhas.push('1. DADOS DE PROJETO');
    var spec = projeto.spec || {};
    if (spec.cv) linhas.push('   Motor: ' + spec.cv + ' CV · ' + (spec.trifasico ? 'trifásico' : 'monofásico') + ' · ' + spec.tensaoPotencia + ' V');
    linhas.push('   Comando: ' + (spec.tensaoComando || '?') + ' V');
    if (spec.temporizador) linhas.push('   Temporização: ' + spec.temporizador + ' s');
    linhas.push('   Emergência: ' + (spec.emergencia ? 'sim' : 'não') + ' · Sinalização: ' + (spec.sinalizacao ? 'sim' : 'não'));
    var d = projeto.dimensionamento || {};
    if (d.correnteA) linhas.push('   Estimativa: ' + d.correnteA + ' A · disjuntor ' + d.disjuntorA + ' A · contator ' + d.contatorA + ' A · térmico ' + d.termicoA + ' A');
    linhas.push('');
    linhas.push('2. COMPONENTES (' + projeto.componentes.length + ')');
    projeto.componentes.forEach(function (c) {
      var def = TIPOS[c.tipo] || {};
      linhas.push('   ' + c.id + ' — ' + (def.nome || c.tipo) + (c.tensao ? ' · bobina ' + c.tensao + ' V' : '') + ' — ' + c.funcao);
      var pinos = Object.keys(c.pinos || {}).map(function (p) { return p + ':' + c.pinos[p]; }).join(' ');
      linhas.push('        pinos ' + pinos);
      if (c.enderecos) linhas.push('        endereços ' + Object.keys(c.enderecos).map(function (k) { return k + '=' + c.enderecos[k]; }).join(' '));
    });
    linhas.push('');
    linhas.push('3. FIOS NUMERADOS (' + fios(projeto).length + ')');
    linhas.push('   ' + fios(projeto).map(function (f) { return f.numero + '-' + f.rede; }).join(' · '));
    linhas.push('');
    if (projeto.sequencia && projeto.sequencia.length) {
      linhas.push('4. SEQUÊNCIA DE OPERAÇÃO');
      projeto.sequencia.forEach(function (s, i) { linhas.push('   ' + (i + 1) + '. ' + s); });
      linhas.push('');
    }
    if (projeto.rungs && projeto.rungs.length) {
      linhas.push('5. LÓGICA DO CLP');
      projeto.rungs.forEach(function (r, i) { linhas.push('   RUNG ' + (i + 1) + ': ' + r.saida + ' := ' + r.logica + '   // ' + r.descricao); });
      linhas.push('');
    }
    linhas.push('6. VERIFICAÇÃO');
    linhas.push('   Estrutural: ' + v.verificacao.componentes + ' componentes, ' + v.verificacao.pinos + ' pinos, ' + v.verificacao.regras + ' regras aplicadas.');
    linhas.push('   Resultado: ' + (v.ok ? 'aprovado' : v.erros.length + ' erro(s)'));
    v.erros.forEach(function (e) { linhas.push('     ERRO [' + e.codigo + '] ' + e.mensagem); });
    v.avisos.forEach(function (a) { linhas.push('     AVISO ' + a); });
    linhas.push('   Elétrica: não executada (o aplicativo não calcula tensão, corrente nem transitórios).');
    linhas.push('   Simulação funcional: não executada.');
    linhas.push('   CADeSIMU: não aberto — o formato nativo do CADe SIMU é proprietário e este projeto usa o formato documentado ProjetistaEletrico CAD v1.');
    linhas.push('');
    linhas.push('7. LIMITAÇÕES DECLARADAS');
    linhas.push('   - A verificação é de continuidade e de regras, não de simulação elétrica.');
    linhas.push('   - O dimensionamento é estimativa didática; o projeto executivo exige cálculo normativo (NBR 5410) e catálogo do fabricante.');
    linhas.push('   - Intertravamento mecânico e ajustes de campo não são representáveis no arquivo.');
    return linhas.join('\n') + '\n';
  }

  function ladder(projeto) {
    var rungs = projeto.rungs || [];
    if (!rungs.length) return 'Este projeto não tem lógica de CLP: o ladder só existe para projetos com CLP.\n';
    var linhas = ['LISTA LADDER (texto) — ' + (projeto.titulo || 'projeto'), ''];
    rungs.forEach(function (r, i) {
      linhas.push('RUNG ' + (i + 1) + '  ' + r.saida);
      linhas.push('   |--- ' + r.logica.replace(/ E /g, ' --- ').replace(/ OU /g, ' ---+--- ') + ' ---( ' + r.saida + ' )');
      linhas.push('   // ' + r.descricao);
      linhas.push('');
    });
    var clp = projeto.componentes.filter(function (c) { return c.tipo === 'clp'; })[0];
    if (clp && clp.enderecos) {
      linhas.push('TABELA DE ENTRADAS/SAÍDAS');
      Object.keys(clp.enderecos).forEach(function (p) { linhas.push('   ' + clp.enderecos[p] + '  ' + p); });
      linhas.push('');
    }
    linhas.push('ST equivalente:');
    rungs.forEach(function (r) {
      linhas.push('   ' + r.saida + ' := ' + r.logica
        .replace(/%I(\d+)\.(\d)/g, 'IN($1,$2)').replace(/%Q(\d+)\.(\d)/g, 'OUT($1,$2)')
        .replace(/ E /g, ' AND ').replace(/ OU /g, ' OR ').replace(/NAO /g, 'NOT ') + ';');
    });
    linhas.push('');
    linhas.push('A lista é texto verificado pelo motor de regras; não é o arquivo nativo de um CLP específico.');
    return linhas.join('\n') + '\n';
  }

  /* ---------- Arquivo ---------- */
  function serializar(projeto) {
    return JSON.stringify(projeto, null, 2) + '\n';
  }

  function parse(texto) {
    var bruto;
    try { bruto = JSON.parse(String(texto || '')); } catch (e) { return { ok: false, erro: 'JSON inválido: ' + String(e && e.message || e).slice(0, 120) }; }
    if (!bruto || typeof bruto !== 'object' || Array.isArray(bruto)) return { ok: false, erro: 'O projeto precisa ser um objeto JSON.' };
    if (String(bruto.formato || '') !== FORMATO) return { ok: false, erro: 'Formato desconhecido: esperado "' + FORMATO + '".' };
    if (Number(bruto.versao) > VERSAO) return { ok: false, erro: 'Versão ' + bruto.versao + ' é mais nova que a suportada (' + VERSAO + ').' };
    if (!Array.isArray(bruto.componentes) || !bruto.componentes.length) return { ok: false, erro: 'O projeto não tem componentes.' };
    if (bruto.componentes.length > 400) return { ok: false, erro: 'Projeto com mais de 400 componentes.' };
    var doc = bruto;
    doc.spec = doc.spec || { tipo: doc.tipo || 'generico', tensaoComando: 220, emergencia: true };
    doc.redes = doc.redes || { energia: [], retorno: [], fases: [] };
    return { ok: true, projeto: doc, validacao: validar(doc) };
  }

  /* ---------- Arquivo local ---------- */
  var store = null;
  function obterStore() {
    if (store) return store;
    try { if (typeof localStorage !== 'undefined') store = localStorage; } catch (e) { store = null; }
    return store;
  }
  function usarStore(s) { store = s || null; }
  function lerLista() {
    var s = obterStore();
    if (!s) return [];
    var bruto;
    try { bruto = JSON.parse(s.getItem(CHAVE_STORE) || '[]'); } catch (e) { return []; }
    if (!Array.isArray(bruto)) return [];
    return bruto.filter(function (a) {
      return a && a.nome && (typeof a.texto === 'string' || (Array.isArray(a.versoes) && a.versoes.length));
    }).slice(0, LIMITE_ARQUIVOS);
  }
  function gravarLista(lista) {
    var s = obterStore();
    if (!s) return false;
    try { s.setItem(CHAVE_STORE, JSON.stringify(lista.slice(0, LIMITE_ARQUIVOS))); return true; } catch (e) { return false; }
  }
  /** Versão atual primeiro, depois as anteriores (mais recente antes). */
  function versoesDe(entrada) {
    if (!entrada) return [];
    var lista = Array.isArray(entrada.versoes) ? entrada.versoes.slice() : [];
    if (typeof entrada.texto === 'string') {
      lista.unshift({ texto: entrada.texto, bytes: entrada.bytes, atualizado: entrada.atualizado });
    }
    return lista.filter(function (v) { return v && typeof v.texto === 'string'; });
  }
  function entradaDe(nome) {
    return lerLista().filter(function (a) { return a.nome === slug(nome); })[0] || null;
  }

  function salvar(nome, projeto) {
    var texto = typeof projeto === 'string' ? projeto : serializar(projeto);
    var r = parse(texto);
    if (!r.ok) return r;
    var bytes = bytesDe(texto);
    if (bytes > LIMITE_BYTES) return { ok: false, erro: 'Projeto acima de 512 kB.' };
    var arq = slug(nome || r.projeto.titulo || r.projeto.tipo);
    var lista = lerLista();
    var anterior = lista.filter(function (a) { return a.nome === arq; })[0];
    var antigas = versoesDe(anterior).slice(0, 5);
    var restante = lista.filter(function (a) { return a.nome !== arq; });
    restante.unshift({
      nome: arq, texto: texto, bytes: bytes, atualizado: Date.now(), versoes: antigas
    });
    if (!gravarLista(restante)) return { ok: false, erro: 'Sem espaço local para salvar o projeto.' };
    return {
      ok: true, nome: arq, bytes: bytes, substituiu: !!anterior, versoes: antigas.length,
      projeto: r.projeto, validacao: r.validacao
    };
  }

  function listar() {
    return lerLista().map(function (a) {
      return {
        nome: a.nome, bytes: a.bytes || bytesDe(a.texto), atualizado: a.atualizado || 0,
        versoes: versoesDe(a).length
      };
    }).sort(function (a, b) { return b.atualizado - a.atualizado; });
  }

  function ler(nome) {
    var alvo = entradaDe(nome);
    if (!alvo) return { ok: false, erro: 'Projeto "' + limpar(nome, 60) + '" não encontrado.' };
    return parse(alvo.texto);
  }

  function apagar(nome) {
    var alvo = slug(nome);
    var lista = lerLista();
    var sobrou = lista.filter(function (a) { return a.nome !== alvo; });
    if (sobrou.length === lista.length) return { ok: false, erro: 'Projeto não encontrado.' };
    return gravarLista(sobrou) ? { ok: true } : { ok: false, erro: 'Não foi possível apagar agora.' };
  }

  /** Lista o histórico (a versão atual é a índice 0). */
  function versoes(nome) {
    var entrada = entradaDe(nome);
    if (!entrada) return { ok: false, erro: 'Projeto "' + limpar(nome, 60) + '" não encontrado.' };
    var lista = versoesDe(entrada);
    return {
      ok: true, nome: entrada.nome,
      versoes: lista.map(function (v, i) {
        var p = null;
        try { p = JSON.parse(v.texto); } catch (e) { p = null; }
        return {
          indice: i,
          bytes: v.bytes || bytesDe(v.texto),
          atualizado: v.atualizado || 0,
          resumo: p && p.titulo ? p.titulo : (p ? 'projeto ' + (p.tipo || '') : 'versão ' + (i + 1)),
          componentes: p && Array.isArray(p.componentes) ? p.componentes.length : 0
        };
      })
    };
  }

  function lerVersao(nome, indice) {
    var entrada = entradaDe(nome);
    if (!entrada) return { ok: false, erro: 'Projeto "' + limpar(nome, 60) + '" não encontrado.' };
    var lista = versoesDe(entrada);
    var i = Math.max(0, Math.min(lista.length - 1, Number(indice) || 0));
    if (!lista[i]) return { ok: false, erro: 'Versão ' + (indice + 1) + ' não existe.' };
    return parse(lista[i].texto);
  }

  function restaurar(nome, indice) {
    var r = lerVersao(nome, indice);
    if (!r.ok) return r;
    var s = salvar(nome, r.projeto);
    if (!s.ok) return s;
    return {
      ok: true, projeto: r.projeto, nome: s.nome, bytes: s.bytes, versoes: s.versoes,
      validacao: s.validacao, restaurada: Number(indice) || 0
    };
  }

  /* ---------- Comparação estrutural ---------- */
  function comparar(a, b) {
    if (!a || !b || !Array.isArray(a.componentes) || !Array.isArray(b.componentes)) {
      return { ok: false, erro: 'Dois projetos são necessários para comparar.' };
    }
    var mapa = function (p) {
      var m = {};
      p.componentes.forEach(function (c) { m[c.id] = c; });
      return m;
    };
    var ma = mapa(a), mb = mapa(b);
    var adicionados = Object.keys(mb).filter(function (id) { return !ma[id]; });
    var removidos = Object.keys(ma).filter(function (id) { return !mb[id]; });
    var alterados = [];
    Object.keys(ma).forEach(function (id) {
      if (!mb[id]) return;
      var campos = [];
      ['tipo', 'funcao', 'tensao'].forEach(function (k) {
        if (String(ma[id][k] == null ? '' : ma[id][k]) !== String(mb[id][k] == null ? '' : mb[id][k])) campos.push(k);
      });
      var pa = ma[id].pinos || {}, pb = mb[id].pinos || {};
      var chaves = Object.keys(pa).concat(Object.keys(pb));
      chaves.forEach(function (p) {
        if (pa[p] !== pb[p] && campos.indexOf('pino ' + p) < 0) campos.push('pino ' + p);
      });
      if (campos.length) alterados.push({ id: id, campos: campos });
    });
    var redes = function (p) {
      var s = {};
      p.componentes.forEach(function (c) {
        Object.keys(c.pinos || {}).forEach(function (k) { s[c.pinos[k]] = true; });
      });
      return s;
    };
    var ra = redes(a), rb = redes(b);
    var novasRedes = Object.keys(rb).filter(function (r) { return !ra[r]; });
    var redesRemovidas = Object.keys(ra).filter(function (r) { return !rb[r]; });
    var va = validar(a), vb = validar(b);

    var linhas = [];
    linhas.push('COMPARAÇÃO DE PROJETOS (estrutural)');
    linhas.push('  A: ' + (a.titulo || a.tipo) + ' · ' + a.componentes.length + ' componentes · ' + va.erros.length + ' erro(s)');
    linhas.push('  B: ' + (b.titulo || b.tipo) + ' · ' + b.componentes.length + ' componentes · ' + vb.erros.length + ' erro(s)');
    linhas.push('');
    linhas.push('Componentes adicionados: ' + (adicionados.length ? adicionados.join(', ') : 'nenhum'));
    linhas.push('Componentes removidos: ' + (removidos.length ? removidos.join(', ') : 'nenhum'));
    linhas.push('Componentes alterados: ' + (alterados.length ? alterados.map(function (x) { return x.id + ' (' + x.campos.join(', ') + ')'; }).join('; ') : 'nenhum'));
    linhas.push('Redes novas: ' + (novasRedes.length ? novasRedes.join(', ') : 'nenhuma'));
    linhas.push('Redes removidas: ' + (redesRemovidas.length ? redesRemovidas.join(', ') : 'nenhuma'));
    if (va.erros.length || vb.erros.length) linhas.push('Atenção: um dos projetos tem erro estrutural; a comparação não valida funcionamento.');
    linhas.push('Isto é diferença de estrutura, não simulação elétrica.');

    return {
      ok: true, adicionados: adicionados, removidos: removidos, alterados: alterados,
      novasRedes: novasRedes, redesRemovidas: redesRemovidas,
      validacaoA: va, validacaoB: vb, resumo: linhas.join('\n')
    };
  }

  /* ---------- Modificação de projeto existente ---------- */
  function modificar(projeto, pedido) {
    if (!projeto || !Array.isArray(projeto.componentes) || !projeto.componentes.length) {
      return { ok: false, erro: 'Crie ou abra um projeto antes de modificar.' };
    }
    var texto = String(pedido == null ? '' : pedido).trim();
    if (!texto) return { ok: false, erro: 'Escreva a modificação desejada.' };
    var t = texto.toLowerCase();
    var original = clonar(projeto);
    var atual = clonar(projeto);
    var mudancas = [];
    var spec = atual.spec || { tipo: atual.tipo, tensaoComando: 220, emergencia: true };

    function reconstruir(tipo, rotulo) {
      var nova = clonar(spec);
      nova.tipo = tipo;
      var r = projetar({ spec: nova, pedido: atual.pedido || texto });
      if (!r.ok) return false;
      r.projeto.pedido = atual.pedido || texto;
      atual = r.projeto;
      mudancas.push(rotulo);
      return true;
    }

    if (/revers/.test(t)) {
      if (!reconstruir('reversao', 'Projeto reconstruído como reversão de motor, mantendo potência, tensões e emergência do original.')) {
        return { ok: false, erro: 'Não consegui reconstruir como reversão com esta especificação.' };
      }
    } else if (/estrela/.test(t) && /tri/.test(t)) {
      if (!reconstruir('estrela_triangulo', 'Projeto reconstruído como estrela-triângulo automática.')) {
        return { ok: false, erro: 'Não consegui reconstruir como estrela-triângulo com esta especificação.' };
      }
    } else if (/compensadora/.test(t)) {
      if (!reconstruir('compensadora', 'Projeto reconstruído como partida compensadora.')) {
        return { ok: false, erro: 'Não consegui reconstruir como compensadora com esta especificação.' };
      }
    } else if (/partida\s+direta/.test(t)) {
      if (!reconstruir('partida_direta', 'Projeto reconstruído como partida direta.')) {
        return { ok: false, erro: 'Não consegui reconstruir como partida direta com esta especificação.' };
      }
    } else if (/tens[aã]o|comando/.test(t) && t.match(/(24|220|380)\s*v/)) {
      var valor = Number(t.match(/(24|220|380)\s*v/)[1]);
      var novaSpec = clonar(spec);
      novaSpec.tensaoComando = valor;
      var rv = projetar({ spec: novaSpec, pedido: atual.pedido || texto });
      if (!rv.ok) return { ok: false, erro: rv.erro };
      atual = rv.projeto;
      mudancas.push('Comando reconstruído em ' + valor + ' V (bobinas, fonte e proteção do comando refeitas).');
    } else if (/temporizador|retard/.test(t)) {
      var seg = t.match(/(\d+(?:[.,]\d+)?)\s*(?:s\b|seg)/);
      var segundos = seg ? Number(seg[1].replace(',', '.')) : 10;
      var principal = atual.componentes.filter(function (c) { return c.papel === 'principal' && c.pinos && c.pinos.A1; })[0];
      var ret = ((atual.redes && atual.redes.retorno) || [])[0];
      if (!principal) return { ok: false, erro: 'Este projeto não tem contator principal com bobina para o temporizador comandar.' };
      if (!ret) return { ok: false, erro: 'O projeto não tem rede de retorno definida.' };
      var idT = 'KT';
      var nT = 2;
      while (atual.componentes.some(function (c) { return c.id === idT; })) { idT = 'KT' + nT; nT++; }
      var idH = 'H' + (atual.componentes.filter(function (c) { return c.tipo === 'sinaleiro'; }).length + 1);
      var redeLamp = redeUnica(atual, idT + '_LAMP');
      atual.componentes.push({
        id: idT, tipo: 'temporizador', funcao: 'Temporizador de ' + segundos + ' s (sinalização retardada)',
        papel: 'temporizador', tensao: spec.tensaoComando, tempo: segundos,
        pinos: { A1: principal.pinos.A1, A2: ret, 15: principal.pinos.A1, 16: redeLamp },
        x: 110, y: 470
      });
      atual.componentes.push({
        id: idH, tipo: 'sinaleiro', funcao: 'Sinaleiro após ' + segundos + ' s',
        papel: 'sinalizacao', pinos: { 1: redeLamp, 2: ret }, x: 300, y: 470
      });
      mudancas.push('Temporizador ' + idT + ' de ' + segundos + ' s inserido, comandando o sinaleiro ' + idH + ' depois do tempo.');
    } else if (/remover|apagar|excluir/.test(t)) {
      var alvo = (t.match(/\b(?:remover|apagar|excluir)\s+([a-z]{1,4}\d{1,3})\b/) || [])[1];
      if (!alvo) return { ok: false, erro: 'Diga qual componente remover, por exemplo: "remover H1".' };
      var id = alvo.toUpperCase();
      var achado = atual.componentes.filter(function (c) { return c.id === id; })[0];
      if (!achado) return { ok: false, erro: 'O componente ' + id + ' não existe no projeto.' };
      atual.componentes = atual.componentes.filter(function (c) { return c.id !== id; });
      atual.intertravamentos = (atual.intertravamentos || []).filter(function (par) { return par.indexOf(id) < 0; });
      mudancas.push('Componente ' + id + ' removido com os pinos e as ligações dele.');
    } else if (/prote[cç]/.test(t)) {
      var carga = atual.componentes.filter(function (c) { return TIPOS[c.tipo] && TIPOS[c.tipo].carga; })[0];
      if (!carga) return { ok: false, erro: 'O projeto não tem carga (motor/bomba) para proteger.' };
      if (!aplicarProtecao(atual, carga.id)) return { ok: false, erro: 'A carga ' + carga.id + ' já tem proteção declarada.' };
      mudancas.push('Relé térmico inserido no circuito de força de ' + carga.id + '.');
    } else {
      return {
        ok: false,
        erro: 'Não entendi a modificação. Exemplos: "adicionar temporizador de 10 segundos", "remover H1", "adicionar proteção", "converter para reversão", "comando em 24 V".'
      };
    }

    var v = validar(atual);
    return {
      ok: true, projeto: atual, mudancas: mudancas, validacao: v,
      diferenca: comparar(original, atual),
      original: original,
      aviso: v.ok ? '' : 'A modificação deixou ' + v.erros.length + ' erro(s) de verificação estrutural.'
    };
  }

  /** Segunda análise, independente de validar(): confronta estrutura montada com o objetivo pedido. */
  function conferirObjetivo(projeto) {
    var atendidos = [], faltas = [];
    if (!projeto || !Array.isArray(projeto.componentes)) return { ok: false, atendidos: [], faltas: ['Projeto ausente.'] };
    var spec = projeto.spec || {};
    var comps = projeto.componentes;
    var cargas = comps.filter(function (c) { return TIPOS[c.tipo] && TIPOS[c.tipo].carga; });
    var temporizadores = comps.filter(function (c) { return c.tipo === 'temporizador'; });
    var termicos = comps.filter(function (c) { return c.tipo === 'releTermico'; });
    function exigir(cond, rotulo) { if (cond) atendidos.push(rotulo); else faltas.push(rotulo); }
    exigir(comps.length > 0, 'tem componentes');
    if (spec.emergencia) exigir(comps.some(function (c) { return c.papel === 'emergencia'; }), 'tem botoeira de emergência pedida');
    if (spec.sinalizacao) exigir(comps.some(function (c) { return c.tipo === 'sinaleiro'; }), 'tem sinalização pedida');
    var tipo = projeto.tipo || spec.tipo;
    if (tipo === 'sequencia') {
      exigir(cargas.length >= 2, 'tem dois acionamentos de motor');
      exigir(temporizadores.length >= 1, 'tem temporizador para o segundo motor');
      exigir(temporizadores.some(function (t) { return Number(t.tempo) === Number(spec.temporizador); }),
        'temporizador com o tempo pedido (' + spec.temporizador + ' s)');
      exigir(termicos.length >= cargas.length, 'cada motor tem proteção térmica própria');
      var k2 = comps.filter(function (c) { return c.papel === 'secundario'; })[0];
      exigir(!!k2, 'o segundo motor é comandado por contator próprio');
      if (k2) {
        var alimentaK2 = Object.keys(k2.pinos || {}).some(function (p) { return k2.pinos[p] === 'KT2'; });
        exigir(alimentaK2, 'a bobina do segundo contator vem do contato temporizado');
      }
    } else if (tipo === 'reversao') {
      exigir(comps.filter(function (c) { return c.tipo === 'contator'; }).length >= 2, 'tem dois contatores de sentido');
      exigir(comps.some(function (c) { return c.papel === 'reverso'; }), 'tem contator de sentido inverso');
      exigir((projeto.intertravamentos || []).length >= 1, 'tem intertravamento declarado');
    } else if (tipo === 'estrela_triangulo') {
      exigir(comps.some(function (c) { return c.tipo === 'motor6'; }), 'motor com seis pontas');
      exigir(comps.filter(function (c) { return c.tipo === 'contator'; }).length >= 3, 'três contatores (principal, estrela, triângulo)');
      exigir(temporizadores.length >= 1, 'tem temporizador de comutação');
    } else if (tipo === 'compensadora') {
      exigir(comps.some(function (c) { return c.tipo === 'autotransformador'; }), 'tem autotransformador de partida');
      exigir(temporizadores.length >= 1, 'tem temporizador de comutação');
      exigir((projeto.intertravamentos || []).length >= 1, 'tem intertravamento tap/rede');
    } else if (tipo === 'clp') {
      exigir(comps.some(function (c) { return c.tipo === 'clp'; }), 'tem CLP');
      exigir((projeto.rungs || []).length >= 1, 'tem lógica ladder verificável');
    } else if (tipo === 'partida_direta') {
      exigir(cargas.length >= 1, 'tem motor');
      exigir(comps.some(function (c) { return c.tipo === 'contator'; }), 'tem contator de manobra');
      exigir(termicos.length >= 1, 'tem proteção térmica');
    }
    return { ok: faltas.length === 0, atendidos: atendidos, faltas: faltas, tipo: tipo };
  }

  /** Exporta em texto estruturado (NETLIST v1) — base para reconstruir e revisar sem imagem. */
  function exportarNetlist(projeto) {
    var linhas = ['# ProjetistaEletrico NETLIST v1', '# tipo ' + (projeto.tipo || 'generico'), '# titulo ' + (projeto.titulo || '')];
    var redes = projeto.redes || {};
    ['energia', 'retorno', 'fases'].forEach(function (g) {
      if ((redes[g] || []).length) linhas.push('REDE ' + g + ' ' + redes[g].join(' '));
    });
    (projeto.componentes || []).forEach(function (c) {
      linhas.push('COMP ' + c.id + ' ' + c.tipo + ' ' + String(c.funcao || '').replace(/\s+/g, ' ').slice(0, 80));
      Object.keys(c.pinos || {}).forEach(function (k) { linhas.push('PINO ' + c.id + ' ' + k + ' ' + c.pinos[k]); });
    });
    return linhas.join('\n') + '\n';
  }

  /** Reconstrói o projeto a partir da NETLIST v1 (texto). Imagem/foto exige visão por IA. */
  function importarDiagramaTexto(texto) {
    var linhas = String(texto || '').split(/\r?\n/);
    if (!/^#\s*ProjetistaEletrico NETLIST v1/.test(linhas[0] || '')) {
      return { ok: false, erro: 'Cabeçalho ausente: a primeira linha deve ser "# ProjetistaEletrico NETLIST v1".' };
    }
    var comps = {}, ordem = [], redes = { energia: [], retorno: [], fases: [] };
    for (var i = 1; i < linhas.length; i++) {
      var l = linhas[i].trim();
      if (!l || l.charAt(0) === '#') continue;
      var partes = l.split(/\s+/);
      if (partes[0] === 'REDE' && partes[1] && redes[partes[1]]) redes[partes[1]] = partes.slice(2);
      else if (partes[0] === 'COMP' && partes[1] && partes[2]) {
        var id = partes[1].toUpperCase();
        if (!TIPOS[partes[2]]) return { ok: false, erro: 'Tipo desconhecido na linha ' + (i + 1) + ': ' + partes[2] };
        comps[id] = { id: id, tipo: partes[2], funcao: partes.slice(3).join(' ') || TIPOS[partes[2]].nome, pinos: {} };
        ordem.push(id);
      } else if (partes[0] === 'PINO' && partes[1] && partes[2] && partes[3]) {
        var c = comps[partes[1].toUpperCase()];
        if (!c) return { ok: false, erro: 'PINO antes do COMP na linha ' + (i + 1) + '.' };
        c.pinos[partes[2]] = partes[3];
      } else {
        return { ok: false, erro: 'Linha ' + (i + 1) + ' fora do formato (COMP/PINO/REDE).' };
      }
    }
    if (!ordem.length) return { ok: false, erro: 'A netlist não tem componentes.' };
    var projeto = {
      formato: FORMATO, versao: VERSAO, titulo: 'Importado de netlist', tipo: 'generico',
      pedido: 'Importado de diagrama em texto', spec: { tipo: 'generico', tensaoComando: 220, emergencia: true },
      redes: redes, componentes: ordem.map(function (k) { return comps[k]; }),
      sequencia: [], rungs: [], avisos: ['Projeto reconstruído de netlist: confira visualmente as ligações antes de usar.'], decisoes: [], intertravamentos: [], dimensionamento: {}
    };
    return { ok: true, projeto: projeto, validacao: validar(projeto) };
  }

  return {
    FORMATO: FORMATO, VERSAO: VERSAO, TIPOS: TIPOS, EXEMPLOS: EXEMPLOS,
    interpretar: interpretar, projetar: projetar, validar: validar, corrigir: corrigir,
    modificar: modificar, comparar: comparar, conferirObjetivo: conferirObjetivo,
    exportarNetlist: exportarNetlist, importarDiagramaTexto: importarDiagramaTexto,
    relatorio: relatorio, ladder: ladder, fios: fios, resumoComponentes: resumoComponentes,
    serializar: serializar, parse: parse, dimensionar: dimensionar,
    salvar: salvar, listar: listar, ler: ler, apagar: apagar,
    versoes: versoes, lerVersao: lerVersao, restaurar: restaurar, usarStore: usarStore
  };
});
