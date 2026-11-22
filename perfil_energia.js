/* J.A.R.V.I.S. Nova — perfis de energia da escuta (Fase 4B).
 *
 * Quem manda no serviço é o Java: o perfil escolhido é gravado em JarvisPrefs e o
 * JarvisService não inicia o detector quando o perfil não permite. Este módulo cuida do
 * lado da tela: monta o pedido a partir dos campos, recusa horário inválido antes de
 * chamar o Android e descreve o estado que o serviço devolveu.
 */
(function (raiz) {
  'use strict';

  var PERFIS = [
    { id: 'sempre', rotulo: 'Sempre ouvindo', dica: 'O detector fica ligado enquanto você permitir, com a tela apagada ou não.' },
    { id: 'carregando', rotulo: 'Somente carregando', dica: 'A escuta só roda com o carregador conectado; na bateria ela fica parada.' },
    { id: 'horario', rotulo: 'Horários definidos', dica: 'A escuta roda apenas dentro da janela escolhida. Fora dela, o detector não inicia.' },
    { id: 'desligado', rotulo: 'Desligado', dica: 'O serviço não abre o microfone. É diferente de desligar a escuta: o perfil pode ser trocado a qualquer momento.' }
  ];

  /** Limites de bateria oferecidos na tela (%). */
  var LIMITES_BATERIA = [10, 15, 20];

  /** Limite válido ou o padrão de 15%. */
  function normalizarLimite(v) {
    var n = Number(v);
    for (var i = 0; i < LIMITES_BATERIA.length; i++) if (LIMITES_BATERIA[i] === n) return n;
    return 15;
  }

  function rotulo(perfil) {
    for (var i = 0; i < PERFIS.length; i++) if (PERFIS[i].id === perfil) return PERFIS[i].rotulo;
    return 'Sempre ouvindo';
  }

  function normalizarPerfil(v) {
    var p = String(v == null ? '' : v).trim().toLowerCase();
    for (var i = 0; i < PERFIS.length; i++) if (PERFIS[i].id === p) return p;
    return 'sempre';
  }

  /** "07:30" → 450; devolve null quando o texto não é uma hora válida. */
  function minutosDeHora(txt) {
    var m = /^\s*(\d{1,2}):(\d{2})\s*$/.exec(String(txt == null ? '' : txt));
    if (!m) return null;
    var h = Number(m[1]), min = Number(m[2]);
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
  }

  /** 450 → "07:30". Valores fora da faixa são presos entre 00:00 e 23:59. */
  function horaDeMinutos(min) {
    var n = Math.round(Number(min));
    if (!isFinite(n)) n = 0;
    n = Math.max(0, Math.min(1439, n));
    var h = Math.floor(n / 60), m = n % 60;
    return (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m;
  }

  /**
   * Valida e monta o pedido para o Android. Só manda horários quando o perfil é
   * "horario"; nos outros, as horas guardadas continuam valendo para quando voltar.
   */
  function montarPedido(entrada) {
    var x = entrada || {};
    var perfil = normalizarPerfil(x.perfil);
    var limite = (x.limite == null || String(x.limite).trim() === '') ? null : normalizarLimite(x.limite);
    if (perfil !== 'horario') {
      var somente = { perfil: perfil };
      if (limite != null) somente.limiteBateria = limite;
      return { ok: true, args: somente };
    }
    var inicio = minutosDeHora(x.inicio);
    var fim = minutosDeHora(x.fim);
    if (inicio == null || fim == null) {
      return { ok: false, erro: 'Use horários no formato HH:MM (por exemplo 07:00 e 23:00).' };
    }
    if (inicio === fim) {
      return { ok: false, erro: 'Início e fim iguais não definem uma janela. Use horários diferentes (a janela pode atravessar a meia-noite).' };
    }
    var pedido = { perfil: perfil, inicio: inicio, fim: fim };
    if (limite != null) pedido.limiteBateria = limite;
    return { ok: true, args: pedido };
  }

  /** Texto do estado devolvido por estadoEnergia()/definirPerfilEnergia(). */
  function resumo(estado) {
    var e = estado || {};
    if (!e.perfil) return 'O serviço não informou o perfil de energia.';
    var partes = ['Perfil: ' + rotulo(e.perfil) + '.'];
    if (e.limiteBateria != null) partes.push('Limite de redução: ' + normalizarLimite(e.limiteBateria) + '% de bateria.');
    if (e.perfil === 'horario') {
      partes.push('Janela ' + horaDeMinutos(e.horarioInicio) + '–' + horaDeMinutos(e.horarioFim) + '.');
    }
    if (e.pausadoManual) {
      partes.push('Escuta pausada por você: o botão Retomar da notificação volta a ouvir.');
    }
    if (e.bloqueioBateria) {
      partes.push('Redução para poupar bateria: ' + e.bloqueioBateria + ' A escuta volta sozinha ao carregar ou sair da economia.');
    } else if (!e.pausadoManual && e.bloqueio) {
      partes.push('Agora: ' + e.bloqueio);
    } else if (!e.pausadoManual) {
      partes.push('A escuta pode rodar agora.');
    }
    return partes.join(' ');
  }

  var api = {
    PERFIS: PERFIS,
    rotulo: rotulo,
    normalizarPerfil: normalizarPerfil,
    LIMITES_BATERIA: LIMITES_BATERIA,
    normalizarLimite: normalizarLimite,
    minutosDeHora: minutosDeHora,
    horaDeMinutos: horaDeMinutos,
    montarPedido: montarPedido,
    resumo: resumo
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.PerfilEnergia = api;
})(typeof window !== 'undefined' ? window : null);
