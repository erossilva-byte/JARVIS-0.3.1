/* J.A.R.V.I.S. Nova — voz e segundo plano no PC (Etapa 6).
 *
 * A Etapa 6 do roteiro do PC pede três coisas: palavra de ativação local, escuta
 * sem a janela em foco e fala com a mesma voz do celular quando configurada —
 * além de paridade de ações com a tabela do bloco 122. Este módulo guarda as
 * **regras** dessas três coisas, para que o app não decida cada uma dentro de
 * `app.js` e para que o teste possa medir sem microfone.
 *
 * O que é verdade neste computador:
 *  - não há detector de palavra de ativação em C++ como o sherpa KWS do
 *    Android. O áudio do trecho vai para a transcrição e a palavra “Jarvis” é
 *    conferida **aqui**, por `Hermes.ativacao`, antes de qualquer resposta;
 *  - por isso o PC só ouve com a janela fora de foco quando há chave de
 *    transcrição e a pessoa autorizou a escuta em segundo plano;
 *  - o canal do pareamento é **só leitura** (o celular não aceita comando do
 *    PC), então ligação, SMS, lanterna, agenda e acessibilidade continuam sendo
 *    do aparelho: aqui o assistente diz isso, em vez de fingir que fez.
 *
 * Módulo puro: roda em Node e no WebView, não toca no DOM, na rede nem no
 * microfone. `medirCpu` recebe o laço de quem chama e só mede.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.VozPc = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  /* ---------- 1. Onde cada ação vive no PC ---------- */

  var ONDE = {
    PC: 'pc',            // funciona com a janela em foco ou não
    PC_TELA: 'pc-tela',  // só com a interface aberta no painel certo
    CELULAR: 'celular',  // pertence ao aparelho; o pareamento não aceita comando
    SEM_VOZ: 'sem-voz'   // é gesto ou formulário, nunca voz
  };

  var ROTULOS = {
    pc: 'No PC, com a janela aberta ou não',
    'pc-tela': 'No PC, só com a interface aberta',
    celular: 'Só no celular pareado',
    'sem-voz': 'Só pelo painel, sem voz'
  };

  // `marcador` é conferido pelo teste em `voz_pc_test`; se o código perder o
  // caminho, o teste falha em vez de a tabela mentir.
  var TABELA = [
    { acao: 'hora e data', onde: ONDE.PC, marcador: 'hora: { risco: 0' },
    { acao: 'clima', onde: ONDE.PC, marcador: 'clima: { risco: 0' },
    { acao: 'abrir aplicativo', onde: ONDE.PC, marcador: "abrir_app: { risco: 1, disp: T" },
    { acao: 'volume do sistema', onde: ONDE.PC, marcador: 'volume_pc: async' },
    { acao: 'mídia (alternar, próxima, anterior)', onde: ONDE.PC, marcador: 'controle_midia_pc: async' },
    { acao: 'e-mail com texto pronto', onde: ONDE.PC, marcador: 'email_pc: async' },
    { acao: 'copiar texto', onde: ONDE.PC, marcador: 'copiar_texto: async' },
    { acao: 'ligar', onde: ONDE.PC, marcador: 'ligar: async ({ numero })' },
    { acao: 'WhatsApp com mensagem pronta', onde: ONDE.PC, marcador: 'whatsapp: async ({ numero, texto })' },
    { acao: 'travar a tela do PC', onde: ONDE.PC, marcador: 'bloquear_tela: async' },
    { acao: 'desligar o PC', onde: ONDE.PC, marcador: 'desligar_pc: async' },
    { acao: 'status do computador', onde: ONDE.PC, marcador: 'status_dispositivo: { risco: 0' },
    { acao: 'listar arquivos da pasta', onde: ONDE.PC, marcador: 'arquivos_listar: { risco: 0' },

    { acao: 'ficha de pessoa', onde: ONDE.PC_TELA, marcador: 'FICHAS.blocoParaConsulta' },
    { acao: 'consultar memória', onde: ONDE.PC_TELA, marcador: 'MEM_REGRAS.buscarNotas' },
    { acao: 'projetos e CAD', onde: ONDE.PC_TELA, marcador: 'PROJETISTA' },

    { acao: 'SMS', onde: ONDE.CELULAR, chave: 'sms' },
    { acao: 'lanterna', onde: ONDE.CELULAR, chave: 'lanterna' },
    { acao: 'brilho da tela', onde: ONDE.CELULAR, chave: 'brilho' },
    { acao: 'notificações', onde: ONDE.CELULAR, chave: 'notificacoes' },
    { acao: 'acessibilidade da tela', onde: ONDE.CELULAR, chave: 'acessibilidade_status' },
    { acao: 'agenda', onde: ONDE.CELULAR, chave: 'agenda' },
    { acao: 'alarme', onde: ONDE.CELULAR, chave: 'alarme' },

    { acao: 'compartilhar arquivo', onde: ONDE.SEM_VOZ, marcador: 'compartilhar' }
  ];

  function resumo() {
    var contagem = { pc: 0, 'pc-tela': 0, celular: 0, 'sem-voz': 0 };
    TABELA.forEach(function (linha) { contagem[linha.onde] = (contagem[linha.onde] || 0) + 1; });
    return contagem;
  }

  function acoesEm(onde) {
    return TABELA.filter(function (l) { return l.onde === onde; }).map(function (l) { return l.acao; });
  }

  /** O que dizer quando a ação não é deste computador. Nunca promete o que não faz. */
  function mensagemAcao(onde) {
    if (onde === ONDE.CELULAR) {
      return 'Isso é função do celular. O pareamento daqui é só de leitura — eu vejo o status, mas não mando o aparelho ligar, mandar SMS ou mexer na tela. Faça pelo celular, ' + 'e eu ajudo no que for do computador.';
    }
    if (onde === ONDE.PC_TELA) {
      return 'Isso fica no painel do computador, não no caminho de voz: abra o painel correspondente para eu fazer com você.';
    }
    if (onde === ONDE.SEM_VOZ) {
      return 'Isso é um gesto do painel, sem comando de voz.';
    }
    return '';
  }

  /* ---------- 2. Quando o PC pode ouvir ---------- */

  /**
   * Decide se a escuta pode gravar um trecho agora. A janela fora de foco é
   * permitida quando a pessoa autorizou; o resto (falando, pensando, travado,
   * em modo visita) sempre para a escuta, para não ouvir a própria voz nem
   * gravar atrás da tela de bloqueio.
   */
  function podeOuvir(opcoes) {
    var o = opcoes || {};
    if (o.desejada === false) {
      return { ouvindo: false, motivo: 'desligada', texto: 'A escuta de ativação está desligada.' };
    }
    if (o.emModoVisita) {
      return { ouvindo: false, motivo: 'visita', texto: 'No modo de visita o microfone fica fechado.' };
    }
    if (o.bloqueado) {
      return { ouvindo: false, motivo: 'travado', texto: 'A tela de bloqueio está aberta; a escuta volta depois do desbloqueio.' };
    }
    if (o.paradaAtiva) {
      return { ouvindo: false, motivo: 'parada', texto: 'Ele está esperando o comando de parada terminar.' };
    }
    if (o.ocupado) {
      return { ouvindo: false, motivo: 'ocupado', texto: 'Ele está gravando ou pensando; a escuta volta depois da resposta.' };
    }
    if (o.falando) {
      return { ouvindo: false, motivo: 'falando', texto: 'Ele não grava enquanto fala, para não ouvir a própria voz.' };
    }
    if (!o.janelaVisivel && !o.aceitaForaDeFoco) {
      return { ouvindo: false, motivo: 'sem-foco', texto: 'A escuta com a janela atrás está desligada nos ajustes.' };
    }
    return {
      ouvindo: true,
      motivo: o.janelaVisivel ? 'visivel' : 'fora-de-foco',
      texto: o.janelaVisivel
        ? 'Ouvindo com a janela aberta.'
        : 'Ouvindo com a janela atrás: a palavra é conferida aqui, no computador.'
    };
  }

  /* ---------- 3. Qual motor ouve, e o que isso custa ---------- */

  /**
   * Escolha honesta do motor: local quando existe detector no aparelho; nuvem
   * quando há chave (o áudio vai para a transcrição, a palavra é conferida
   * localmente); nada quando não há nenhum dos dois ou o modo offline está
   * ligado.
   */
  function motorDeEscuta(opcoes) {
    var o = opcoes || {};
    if (o.offline) {
      return {
        motor: 'nada',
        motivo: 'offline',
        texto: 'Modo offline ligado: este computador não tem detector de palavra local, então a escuta fica parada e o comando é digitado.'
      };
    }
    if (o.kwsLocal) {
      return {
        motor: 'local',
        motivo: 'detector-no-aparelho',
        texto: 'Palavra conferida no aparelho, sem enviar áudio.',
        enviaAudio: false
      };
    }
    if (o.chaveNuvem) {
      return {
        motor: 'nuvem',
        motivo: 'sem-detector-local',
        texto: 'Neste computador não há detector local: o trecho de áudio vai para a transcrição e a palavra “Jarvis” é conferida aqui, antes de qualquer resposta.',
        enviaAudio: true
      };
    }
    return {
      motor: 'nada',
      motivo: 'sem-chave',
      texto: 'Sem detector local e sem chave de transcrição, a escuta não começa. Cadastre a chave em Ajustes ▸ IA ou use o app do celular.',
      enviaAudio: false
    };
  }

  /* ---------- 4. A voz do PC e a do celular ---------- */

  // Mesma prosódia do celular (app.js, PERFIS_VOZ). O nome da voz muda de
  // aparelho para aparelho; o tom e a velocidade, não.
  var PERFIS = {
    padrao: { nome: 'Padrão', pitch: 0.8, rate: 1 },
    filme: { nome: 'JARVIS do filme', pitch: 0.6, rate: 0.9 },
    jarvis: { nome: 'Jarvis completo (grave, cadenciado e formal)', pitch: 0.55, rate: 0.88 },
    ultra: { nome: 'Ultra grave', pitch: 0.5, rate: 0.85 }
  };

  var NOMES_MASCULINOS = /(antonio|antônio|daniel|felipe|ricardo|marcos|joao|joão|thiago|heitor|fabio|fábio|jorge|humberto|david|guy|conrad|male|masculin)/i;
  var NOMES_FEMININOS = /(francisca|luciana|maria|helena|vitoria|vitória|ines|inês|joana|catarina|beatriz|fernanda|female|feminin)/i;

  function nomeDaVoz(v) { return String((v && (v.name || v.nome || v.id)) || '').trim(); }
  function idiomaDaVoz(v) { return String((v && (v.lang || v.idioma)) || ''); }
  function pareceMasculina(v) {
    var nome = nomeDaVoz(v);
    if (NOMES_FEMININOS.test(nome)) return false;
    return NOMES_MASCULINOS.test(nome);
  }

  function parametrosDeFala(perfil) {
    var p = PERFIS[perfil] || PERFIS.padrao;
    return { perfil: PERFIS[perfil] ? perfil : 'padrao', nome: p.nome, pitch: p.pitch, rate: p.rate };
  }

  /**
   * Escolhe a voz do PC a partir da preferência do celular. Ordem: a mesma voz,
   * se existir aqui; uma masculina em português; qualquer português; uma
   * masculina de outro idioma. Devolve o aviso quando a voz salva não existe —
   * trocar de voz em silêncio era o que incomodava.
   */
  function vozParaPC(vozes, opcoes) {
    var o = opcoes || {};
    var lista = Array.isArray(vozes) ? vozes.filter(function (v) { return v && nomeDaVoz(v); }) : [];
    var salva = String(o.salva == null ? '' : o.salva).trim();
    var fala = parametrosDeFala(o.perfil);
    var achada = salva ? lista.filter(function (v) { return nomeDaVoz(v) === salva; })[0] : null;
    if (achada) {
      return { voz: achada, nome: nomeDaVoz(achada), motivo: 'voz-salva', aviso: '', pitch: fala.pitch, rate: fala.rate };
    }
    var escolhida = null, motivo = '';
    var candidatas = [
      { teste: function (v) { return /^pt/i.test(idiomaDaVoz(v)) && pareceMasculina(v); }, motivo: 'masculina-pt' },
      { teste: function (v) { return /^pt/i.test(idiomaDaVoz(v)); }, motivo: 'portuguesa' },
      { teste: function (v) { return pareceMasculina(v); }, motivo: 'masculina-outro-idioma' },
      { teste: function (v) { return true; }, motivo: 'primeira-disponivel' }
    ];
    for (var i = 0; i < candidatas.length && !escolhida; i++) {
      escolhida = lista.filter(candidatas[i].teste)[0] || null;
      if (escolhida) motivo = candidatas[i].motivo;
    }
    if (!escolhida) {
      return {
        voz: null, nome: '', motivo: 'sem-voz', pitch: fala.pitch, rate: fala.rate,
        aviso: 'Este computador não oferece nenhuma voz ao aplicativo. A resposta continua no texto.'
      };
    }
    var aviso = '';
    if (salva && nomeDaVoz(escolhida) !== salva) {
      aviso = 'A voz “' + salva + '” escolhida no celular não existe neste computador; estou usando “' + nomeDaVoz(escolhida) + '”.';
    }
    return { voz: escolhida, nome: nomeDaVoz(escolhida), motivo: motivo, aviso: aviso, pitch: fala.pitch, rate: fala.rate };
  }

  /* ---------- 5. Medição de CPU do laço de escuta ---------- */

  /**
   * Mede o custo de CPU de um laço de quadros — o mesmo laço que roda com a
   * escuta ligada. Mede o que o processo gasta (user + system), não o microfone:
   * captura de áudio depende do driver e não é medida aqui.
   *
   * `cpuUsage` e `agora` podem ser injetados para o teste ficar determinístico.
   */
  function medirCpu(laco, opcoes) {
    var o = opcoes || {};
    var quadros = Math.max(1, Math.floor(Number(o.quadros) || 600));
    var cpuUsage = typeof o.cpuUsage === 'function'
      ? o.cpuUsage
      : (typeof process !== 'undefined' && process.cpuUsage ? function () { return process.cpuUsage(); } : null);
    var agora = typeof o.agora === 'function'
      ? o.agora
      : (typeof process !== 'undefined' && process.hrtime && process.hrtime.bigint
        ? function () { return Number(process.hrtime.bigint()) / 1e6; }
        : function () { return Date.now(); });

    var antesCpu = cpuUsage ? cpuUsage() : null;
    var antes = agora();
    for (var i = 0; i < quadros; i++) {
      if (typeof laco === 'function') laco(i, quadros);
    }
    var depois = agora();
    var depoisCpu = cpuUsage ? cpuUsage() : null;

    var paredeMs = Math.max(0, depois - antes);
    var cpuMs = antesCpu && depoisCpu
      ? Math.max(0, ((depoisCpu.user - antesCpu.user) + (depoisCpu.system - antesCpu.system)) / 1000)
      : 0;
    return {
      quadros: quadros,
      paredeMs: Math.round(paredeMs * 100) / 100,
      cpuMs: Math.round(cpuMs * 100) / 100,
      porQuadroMs: Math.round((cpuMs / quadros) * 1000) / 1000,
      porMinutoMs: Math.round((cpuMs / quadros) * 60000),
      percentual: paredeMs > 0 ? Math.round((cpuMs / paredeMs) * 1000) / 10 : 0,
      medido: Boolean(antesCpu && depoisCpu),
      metodologia: 'process.cpuUsage() do processo, sem captura de áudio'
    };
  }

  var api = {
    ONDE: ONDE,
    ROTULOS: ROTULOS,
    TABELA: TABELA,
    PERFIS: PERFIS,
    resumo: resumo,
    acoesEm: acoesEm,
    mensagemAcao: mensagemAcao,
    podeOuvir: podeOuvir,
    motorDeEscuta: motorDeEscuta,
    parametrosDeFala: parametrosDeFala,
    vozParaPC: vozParaPC,
    medirCpu: medirCpu
  };
  return api;
});
