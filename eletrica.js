/* J.A.R.V.I.S. Nova — Base técnica de engenharia elétrica (determinística).
 *
 * O que é: biblioteca de componentes com terminais, função, limites e símbolo IEC; tabelas de
 * referência para dimensionamento (corrente de motor, contator AC-3, faixa de térmico, cabo por
 * ampacidade e queda de tensão) e verificação independente do projeto montado pelo projetista.
 *
 * O que NÃO é: catálogo de fabricante, cálculo normativo fechado (NBR 5410) nem treinamento de
 * modelo. As tabelas são de referência didática; o projeto executivo exige catálogo e cálculo do
 * responsável técnico. Referências registradas pelo usuário ficam em memória especializada, com
 * procedência, e não alteram o modelo de IA.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.EletricaBase = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var VERSAO = '1.0';
  var CHAVE_REF = 'jv_eletrica_referencias';
  var LIMITE_REFS = 40;

  /* ---------- Componentes: terminais, função, limites e símbolo ---------- */
  var COMPONENTES = {
    contator: {
      nome: 'Contator tripolar', grupo: 'potencia', iec: 'K — bobina A1/A2, contatos 1-2/3-4/5-6, NA 13-14, NF 21-22',
      funcao: 'Manobra de carga com comando remoto; a bobina fecha os contatos de força e auxiliares.',
      terminais: { A1: 'bobina +', A2: 'bobina −', '1-2': 'contato de força (fase)', '3-4': 'contato de força', '5-6': 'contato de força', '13-14': 'auxiliar NA', '21-22': 'auxiliar NF' },
      limites: 'Corrente AC-3 ≥ corrente do motor; bobina na tensão do comando.',
      regras: ['nunca em série com o próprio NF sem selo', 'contato NA 13/14 é o selo típico'],
      categoria: 'AC-3 (motor)'
    },
    releTermico: {
      nome: 'Relé térmico', grupo: 'potencia', iec: 'F — contatos 95-96 (NF) e 97-98 (NA)',
      funcao: 'Protege o motor contra sobrecarga; atua por aquecimento e interrompe o comando.',
      terminais: { '1-2': 'fase R', '3-4': 'fase S', '5-6': 'fase T', '95-96': 'NF de falha', '97-98': 'NA de falha' },
      limites: 'Faixa de ajuste deve conter a corrente nominal (In) do motor.',
      regras: ['ajuste em 1,0 a 1,15 × In', 'não substitui disjuntor-motor contra curto'],
      categoria: 'proteção de sobrecarga'
    },
    motor3: {
      nome: 'Motor trifásico', grupo: 'carga', iec: 'M — U/V/W + PE',
      funcao: 'Converte energia elétrica em mecânica; placa traz In, fator de serviço e ligação.',
      terminais: { U: 'fase U', V: 'fase V', W: 'fase W', PE: 'terra' },
      limites: 'Corrente de partida típica 6 a 8 × In em partida direta.',
      regras: ['precisa de proteção contra curto e sobrecarga', 'sentido de rotação depende da ordem das fases']
    },
    motor6: {
      nome: 'Motor trifásico 6 pontas', grupo: 'carga', iec: 'M — U1/V1/W1 + U2/V2/W2 + PE',
      funcao: 'Permite estrela-triângulo: em estrela a tensão por bobina cai para 1/√3.',
      terminais: { U1: 'início U', V1: 'início V', W1: 'início W', U2: 'fim U', V2: 'fim V', W2: 'fim W', PE: 'terra' },
      limites: 'Estrela-triângulo exige seis pontas acessíveis e tensão de rede compatível com a ligação triângulo.',
      regras: ['nunca fechar estrela e triângulo ao mesmo tempo']
    },
    disjuntor3: {
      nome: 'Disjuntor tripolar', grupo: 'potencia', iec: 'Q — 1/2, 3/4, 5/6',
      funcao: 'Protege contra curto e sobrecarga; serve de seccionamento.',
      terminais: { '1-2': 'polo R', '3-4': 'polo S', '5-6': 'polo T' },
      limites: 'Curva C para cargas mistas; curva D para motores com partida pesada.',
      regras: ['In do disjuntor ≥ In do circuito', 'não usar como único protetor de sobrecarga do motor']
    },
    fusivel: {
      nome: 'Fusível', grupo: 'comando', iec: 'F — 1/2',
      funcao: 'Proteção rápida do circuito de comando.',
      terminais: { '1-2': 'elo fusível' },
      limites: 'Corrente conforme a carga do comando; tipo gG para comando.',
      regras: ['dimensionar pela soma das bobinas e sinaleiros']
    },
    temporizador: {
      nome: 'Temporizador', grupo: 'comando', iec: 'KT — A1/A2, NA 15-16, NF 25-26',
      funcao: 'Retarda a comutação de um comando; pode ser com retardo na energização ou na desenergização.',
      terminais: { A1: 'bobina +', A2: 'bobina −', '15-16': 'NA temporizado', '25-26': 'NF temporizado' },
      limites: 'Tempo típico de 0,1 s a 30 min; confirmar a função (on-delay/off-delay) no aparelho.',
      regras: ['o contato temporizado não substitui o selo do contator principal']
    },
    clp: {
      nome: 'CLP', grupo: 'clp', iec: 'PLC — alimentação L/N e entradas/saídas digitais',
      funcao: 'Executa a lógica por software; entradas leem sensores, saídas acionam bobinas e sinaleiros.',
      terminais: { L: 'alimentação +', N: 'alimentação −', I1: 'entrada digital 1', I2: 'entrada digital 2', I3: 'entrada digital 3', I4: 'entrada digital 4', Q1: 'saída digital 1', Q2: 'saída digital 2' },
      limites: 'Cada entrada/saída tem endereço próprio e corrente máxima; saída não alimenta motor direto.',
      regras: ['saída aciona bobina de contator, nunca a carga de força', 'entrada e saída não compartilham endereço']
    },
    autotransformador: {
      nome: 'Autotransformador de partida', grupo: 'potencia', iec: 'T — taps percentuais',
      funcao: 'Reduz a tensão na partida (tap de 50/65/80%) e comuta para rede plena.',
      terminais: { '1-2-3': 'rede', '4-5-6': 'tap para o motor' },
      limites: 'Partidas por hora limitadas pelo aquecimento; tap declarado precisa ser confirmado.',
      regras: ['contator de tap e contator de rede nunca fechados juntos']
    },
    sensor: {
      nome: 'Sensor / boia', grupo: 'comando', iec: 'B — 1/2/3 (alimentação e sinal)',
      funcao: 'Detecta nível, presença, fim de curso ou proximidade e entrega sinal à entrada.',
      terminais: { '1': '+V', '2': '0V', '3': 'sinal' },
      limites: 'PNP/NPN e tensão precisam casar com a entrada do CLP.',
      regras: ['confirmar se o contato é NA ou NF com o processo']
    },
    sinaleiro: {
      nome: 'Sinaleiro', grupo: 'comando', iec: 'H — 1/2',
      funcao: 'Indica estado (ligado, falha, regime) no painel.',
      terminais: { '1-2': 'lâmpada/LED' },
      limites: 'Tensão da lâmpada igual à do comando.',
      regras: ['sinalização de falha deve vir do NF do térmico, não do contator']
    }
  };

  /* ---------- Tabelas de referência ---------- */
  // Ampacidade (A) para cobre, isolação PVC, em eletroduto, método B1, 30 °C — referência didática.
  var AMPACIDADE = [
    { mm2: 1.5, A: 17.5 }, { mm2: 2.5, A: 24 }, { mm2: 4, A: 32 }, { mm2: 6, A: 41 },
    { mm2: 10, A: 57 }, { mm2: 16, A: 76 }, { mm2: 25, A: 101 }, { mm2: 35, A: 125 }, { mm2: 50, A: 153 }
  ];
  var CONTATORES = [6, 9, 12, 16, 18, 25, 32, 40, 50, 65, 80, 95, 115, 150, 185, 225];
  var DISJUNTORES = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250];
  var FAIXAS_TERMICO = [[0.63, 1], [1, 1.6], [1.6, 2.5], [2.5, 4], [4, 6], [5.5, 8], [7, 10], [9, 13], [12, 18], [17, 25], [23, 32], [30, 40], [37, 50], [48, 65], [60, 80], [80, 100]];
  var REFERENCIAS = [
    'Ampacidade: tabela de referência para cobre/PVC em eletroduto (método B1), 30 °C — valor didático, não substitui a NBR 5410 nem o catálogo.',
    'Contatores: série comercial AC-3 (6 A a 225 A); escolha pelo maior valor ≥ In do motor.',
    'Térmico: faixas comerciais de ajuste; a faixa escolhida precisa conter 1,0 a 1,15 × In.',
    'Disjuntor: série comercial; para motor usar curva C ou D conforme a partida.',
    'Símbolos: descrição conforme IEC 60617 (bobina, contato NA/NF, térmico, motor).',
    'Queda de tensão: limite de 4% para circuitos de força, cálculo por resistividade do cobre (0,0172 Ω·mm²/m).'
  ];

  /* ---------- Utilidades ---------- */
  function arred(n, casas) { var f = Math.pow(10, casas || 1); return Math.round(n * f) / f; }
  function acima(serie, v) { for (var i = 0; i < serie.length; i++) if (serie[i] >= v) return serie[i]; return serie[serie.length - 1]; }
  function faixaPara(ajuste) {
    for (var i = 0; i < FAIXAS_TERMICO.length; i++) {
      var f = FAIXAS_TERMICO[i];
      if (ajuste >= f[0] && ajuste <= f[1]) return { min: f[0], max: f[1] };
    }
    return null;
  }

  function correnteNominal(spec) {
    var cv = Number(spec && spec.cv);
    if (!Number.isFinite(cv) || cv <= 0) return null;
    var potencia = cv * 736;
    var tensao = Number(spec.tensaoPotencia) || 380;
    var trif = spec.trifasico !== false;
    var rendimento = 0.9, fp = 0.8;
    var i = trif ? potencia / (Math.sqrt(3) * tensao * rendimento * fp) : potencia / (tensao * rendimento * fp);
    return { A: arred(i, 1), tabela: null, fonte: 'fórmula (η 0,90 / fp 0,80)' };
  }

  /** Dimensionamento de força + comando para um motor, com memória de cálculo. */
  function dimensionar(spec, opcoes) {
    var o = opcoes || {};
    var s = spec || {};
    var dados = correnteNominal(s);
    if (!dados) return { ok: false, erro: 'Potência do motor não informada: não há como dimensionar.' };
    var In = dados.A;
    var comprimento = Number(o.comprimento) > 0 ? Number(o.comprimento) : 30;
    var fator = o.fatorServico === true ? 1.15 : 1;
    var contatorA = acima(CONTATORES, In * fator);
    var disjuntorA = acima(DISJUNTORES, In * 1.2);
    var ajusteTermico = arred(In * 1.05, 1);
    var faixa = faixaPara(ajusteTermico) || { min: ajusteTermico, max: ajusteTermico };
    var cabo = null;
    for (var i = 0; i < AMPACIDADE.length; i++) {
      var c = AMPACIDADE[i];
      if (c.A >= In * 1.25) {
        var r = 0.0172 * comprimento / c.mm2;
        var queda = s.trifasico === false
          ? (2 * In * r) / (Number(s.tensaoPotencia) || 220) * 100
          : (Math.sqrt(3) * In * r) / (Number(s.tensaoPotencia) || 380) * 100;
        if (queda <= 4) { cabo = { mm2: c.mm2, ampacidade: c.A, quedaV: arred(queda, 2) }; break; }
      }
    }
    if (!cabo) cabo = { mm2: 50, ampacidade: 153, quedaV: null, aviso: 'Nenhum cabo da tabela atende ampacidade e queda em ' + comprimento + ' m; aumente a seção ou divida o circuito.' };
    var bobinas = o.bobinas || 2;
    var correnteComando = arred(bobinas * 0.15 + 0.1, 2);
    return {
      ok: true,
      correnteA: In,
      correnteTabelaA: dados.tabela,
      potenciaW: Math.round(Number(s.cv) * 736),
      contatorA: contatorA,
      disjuntorA: disjuntorA,
      curva: In > 25 ? 'D' : 'C',
      termicoA: ajusteTermico,
      termicoFaixa: faixa,
      caboMm2: cabo.mm2,
      quedaV: cabo.quedaV,
      comprimentoM: comprimento,
      fusivelComandoA: acima([2, 4, 6, 10, 16], correnteComando * 2),
      memoria: [
        'In = P / (√3 · U · η · fp) = ' + arred(Number(s.cv) * 736, 0) + ' W / (1,732 · ' + (s.tensaoPotencia || 380) + ' · 0,90 · 0,80) = ' + In + ' A',
        'Contator AC-3 ≥ In → ' + contatorA + ' A',
        'Disjuntor motor = 1,2 × In → ' + disjuntorA + ' A, curva ' + (In > 25 ? 'D' : 'C'),
        'Térmico: ajuste 1,05 × In = ' + ajusteTermico + ' A, faixa ' + faixa.min + '–' + faixa.max + ' A',
        'Cabo: ampacidade ≥ 1,25 × In e queda ≤ 4% em ' + comprimento + ' m → ' + cabo.mm2 + ' mm²' + (cabo.quedaV != null ? ' (' + cabo.quedaV + '% de queda)' : ''),
        'Comando: fusível ' + acima([2, 4, 6, 10, 16], correnteComando * 2) + ' A para ~' + correnteComando + ' A de bobinas/sinaleiros'
      ],
      fonte: 'Tabelas de referência didática (ver REFERENCIAS); confirmar no catálogo do fabricante.'
    };
  }

  /** Verificação independente: confronta o declarado no projeto com o dimensionamento calculado. */
  function conferirDimensionamento(projeto) {
    var faltas = [], avisos = [];
    if (!projeto || !projeto.spec || !projeto.spec.cv) return { ok: true, faltas: faltas, avisos: ['Projeto sem potência declarada: dimensionamento não conferido.'] };
    var d = projeto.dimensionamento || {};
    var calc = dimensionar(projeto.spec, { comprimento: projeto.spec.comprimento });
    if (!calc.ok) return { ok: false, faltas: [{ codigo: 'sem_potencia', mensagem: calc.erro }], avisos: avisos };
    function falso(codigo, mensagem) { faltas.push({ codigo: codigo, mensagem: mensagem }); }
    if (d.correnteA && Math.abs(Number(d.correnteA) - calc.correnteA) > Math.max(0.5, calc.correnteA * 0.15)) {
      avisos.push('Corrente declarada ' + d.correnteA + ' A difere do cálculo ' + calc.correnteA + ' A: confira η e fp.');
    }
    if (d.contatorA && Number(d.contatorA) < calc.contatorA) {
      falso('contator_insuficiente', 'Contator declarado ' + d.contatorA + ' A é menor que o necessário (' + calc.contatorA + ' A para ' + calc.correnteA + ' A).');
    }
    if (d.disjuntorA && Number(d.disjuntorA) < calc.disjuntorA && Number(d.disjuntorA) < calc.correnteA) {
      falso('disjuntor_insuficiente', 'Disjuntor declarado ' + d.disjuntorA + ' A é menor que a corrente do motor (' + calc.correnteA + ' A).');
    }
    if (d.termicoA && (Number(d.termicoA) < Number(calc.termicoFaixa.min) - 0.01 || Number(d.termicoA) > Number(calc.termicoFaixa.max) + 0.01)) {
      falso('termico_fora_da_faixa', 'Ajuste térmico ' + d.termicoA + ' A está fora da faixa que contém 1,05 × In (faixa ' + calc.termicoFaixa.min + '–' + calc.termicoFaixa.max + ' A).');
    }
    if (d.caboMm2 && Number(d.caboMm2) < calc.caboMm2) {
      falso('cabo_insuficiente', 'Cabo declarado ' + d.caboMm2 + ' mm² é menor que o necessário (' + calc.caboMm2 + ' mm² para ampacidade e queda).');
    }
    return { ok: faltas.length === 0, faltas: faltas, avisos: avisos, calculo: calc };
  }

  /** Consulta técnica: devolve entradas da biblioteca que casam com o termo. */
  function consultar(termo) {
    var t = String(termo == null ? '' : termo).toLowerCase().trim();
    if (!t) return { ok: false, erro: 'Diga o componente ou assunto (ex.: contator, térmico, cabo).' };
    var chaves = Object.keys(COMPONENTES).filter(function (k) {
      var c = COMPONENTES[k];
      return k.toLowerCase().indexOf(t) >= 0 || c.nome.toLowerCase().indexOf(t) >= 0 ||
        (c.funcao || '').toLowerCase().indexOf(t) >= 0 || (c.iec || '').toLowerCase().indexOf(t) >= 0;
    });
    var tabela = null;
    if (/cabo|bitola|se[cç][aã]o|ampacidade/.test(t)) tabela = { tipo: 'ampacidade', dados: AMPACIDADE };
    else if (/contator|ac-3/.test(t)) tabela = { tipo: 'contatores', dados: CONTATORES };
    else if (/t[eé]rmico|faixa/.test(t)) tabela = { tipo: 'faixas_termico', dados: FAIXAS_TERMICO };
    else if (/disjuntor|curva/.test(t)) tabela = { tipo: 'disjuntores', dados: DISJUNTORES };
    else if (/s[ií]mbolo|iec/.test(t)) tabela = { tipo: 'simbolos', dados: Object.keys(COMPONENTES).map(function (k) { return { tipo: k, iec: COMPONENTES[k].iec }; }) };
    if (!chaves.length && !tabela) return { ok: false, erro: 'Não há entrada para "' + termo + '" na base. Posso consultar: ' + Object.keys(COMPONENTES).join(', ') + '.' };
    return {
      ok: true, termo: termo, tabela: tabela,
      entradas: chaves.map(function (k) {
        var c = COMPONENTES[k];
        return { tipo: k, nome: c.nome, funcao: c.funcao, terminais: c.terminais, limites: c.limites, iec: c.iec, regras: c.regras };
      }),
      memoria: referencias().length,
      fonte: 'Biblioteca interna (IEC 60617 para símbolos, tabelas comerciais de referência).'
    };
  }

  /* ---------- Memória especializada (referências, não treinamento) ---------- */
  var store = null;
  function usarStore(s) { store = s || null; }
  function obterStore() {
    if (store) return store;
    try { if (typeof localStorage !== 'undefined') store = localStorage; } catch (e) { store = null; }
    return store;
  }
  function referencias() {
    var s = obterStore();
    if (!s) return [];
    try {
      var l = JSON.parse(s.getItem(CHAVE_REF) || '[]');
      return Array.isArray(l) ? l.slice(0, LIMITE_REFS) : [];
    } catch (e) { return []; }
  }
  function registrarReferencia(entrada) {
    var e = entrada || {};
    var titulo = String(e.titulo || '').replace(/[<>]/g, '').trim().slice(0, 120);
    var texto = String(e.texto || '').replace(/[<>]/g, '').trim().slice(0, 4000);
    if (!titulo || !texto) return { ok: false, erro: 'Referência precisa de título e texto.' };
    var s = obterStore();
    var atual = referencias();
    var item = {
      titulo: titulo, texto: texto, fonte: String(e.fonte || 'usuário').slice(0, 120),
      tipo: String(e.tipo || 'documento').slice(0, 40), quando: Date.now(),
      confianca: e.confianca === 'verificada' ? 'verificada' : 'nao_verificada'
    };
    atual.unshift(item);
    if (!s) return { ok: false, erro: 'Sem armazenamento local para guardar a referência.' };
    try { s.setItem(CHAVE_REF, JSON.stringify(atual.slice(0, LIMITE_REFS))); } catch (err) { return { ok: false, erro: 'Não foi possível gravar a referência.' }; }
    return { ok: true, referencia: item, total: Math.min(atual.length, LIMITE_REFS), aviso: 'Isto é memória especializada consultável, não treinamento do modelo.' };
  }
  function buscarReferencias(termo) {
    var t = String(termo || '').toLowerCase().trim();
    var lista = referencias();
    var achadas = t ? lista.filter(function (r) { return (r.titulo + ' ' + r.texto + ' ' + r.fonte).toLowerCase().indexOf(t) >= 0; }) : lista;
    return { ok: true, total: achadas.length, referencias: achadas, treinamento: false };
  }
  function apagarReferencia(titulo) {
    var alvo = String(titulo || '').trim().toLowerCase();
    var lista = referencias();
    var sobrou = lista.filter(function (r) { return r.titulo.toLowerCase() !== alvo; });
    if (sobrou.length === lista.length) return { ok: false, erro: 'Referência não encontrada.' };
    var s = obterStore();
    if (!s) return { ok: false, erro: 'Sem armazenamento local.' };
    try { s.setItem(CHAVE_REF, JSON.stringify(sobrou)); } catch (e) { return { ok: false, erro: 'Não foi possível apagar.' }; }
    return { ok: true, total: sobrou.length };
  }

  /* ---------- Endereçamento de CLP ---------- */
  function enderecarClp(mapa) {
    var usados = {}, erros = [];
    Object.keys(mapa || {}).forEach(function (pino) {
      var end = String(mapa[pino] || '');
      if (!/^%[IQ][0-9]{1,3}\.[0-7]$/.test(end)) erros.push({ pino: pino, endereco: end, motivo: 'formato fora de %I0.0 / %Q0.0' });
      else if (usados[end]) erros.push({ pino: pino, endereco: end, motivo: 'duplicado com ' + usados[end] });
      else usados[end] = pino;
    });
    return { ok: erros.length === 0, erros: erros, total: Object.keys(usados).length };
  }

  return {
    VERSAO: VERSAO, COMPONENTES: COMPONENTES, REFERENCIAS: REFERENCIAS,
    AMPACIDADE: AMPACIDADE, CONTATORES: CONTATORES, DISJUNTORES: DISJUNTORES, FAIXAS_TERMICO: FAIXAS_TERMICO,
    dimensionar: dimensionar, correnteNominal: correnteNominal, conferirDimensionamento: conferirDimensionamento,
    consultar: consultar, enderecarClp: enderecarClp,
    registrarReferencia: registrarReferencia, buscarReferencias: buscarReferencias,
    apagarReferencia: apagarReferencia, referencias: referencias, usarStore: usarStore
  };
});
