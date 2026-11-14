/* J.A.R.V.I.S. Nova — "Por que parou?" do segundo plano (Fase 4B).
 *
 * A Fase 4B pede um botão "Por que parou?" ao lado do diagnóstico. O diagnóstico já traz os
 * fatos (permissão de microfone, notificação, bateria, serviço ativo, se o usuário quer ouvir,
 * último erro do detector); faltava transformar isso numa explicação em ordem de causa.
 *
 * Módulo puro: recebe o objeto devolvido por `diagnosticoEscuta()` e devolve a causa mais
 * provável primeiro, sem inventar nada que o objeto não contenha.
 */
(function (raiz) {
  'use strict';

  function textoErro(v) {
    var s = String(v == null ? '' : v).trim();
    return s.length > 160 ? s.slice(0, 157) + '…' : s;
  }

  /**
   * @param {object} d diagnóstico nativo (pode vir incompleto)
   * @param {number} agora ms (para calcular há quanto tempo foi o último evento)
   */
  function explicar(d, agora) {
    var x = d || {};
    var t = Number(agora) > 0 ? Number(agora) : Date.now();
    var ultimoEvento = Number(x.ultimoEvento) > 0 ? Number(x.ultimoEvento) : 0;
    var desdeUltimoEventoMs = ultimoEvento ? Math.max(0, t - ultimoEvento) : 0;

    if (x.escutando) {
      return {
        ativa: true,
        codigo: 'ativa',
        titulo: 'A escuta está ativa agora',
        detalhe: 'Detector: ' + (x.detector || 'não informado') + '.',
        causas: [],
        ultimoErro: textoErro(x.ultimoErro),
        ultimoEvento: ultimoEvento,
        desdeUltimoEventoMs: desdeUltimoEventoMs
      };
    }

    var causas = [];
    if (x.desejada === false) {
      causas.push({ codigo: 'desligada', texto: 'A escuta está desligada por escolha — o botão "Desligar escuta" encerra o serviço e nada volta sozinho.' });
    }
    if (x.pausadoManual) {
      causas.push({ codigo: 'pausado', texto: 'A escuta está pausada pelo botão Pausar da notificação — toque em Retomar para voltar.' });
    }
    if (textoErro(x.bloqueioPerfil)) {
      causas.push({ codigo: 'perfil', texto: 'Perfil de energia: ' + textoErro(x.bloqueioPerfil) });
    }
    if (textoErro(x.bloqueioBateria)) {
      causas.push({ codigo: 'bateria-baixa', texto: 'Redução para poupar bateria: ' + textoErro(x.bloqueioBateria) });
    }
    if (textoErro(x.bloqueioMicrofone)) {
      causas.push({ codigo: 'microfone-ocupado', texto: 'Outro app está usando o microfone: ' + textoErro(x.bloqueioMicrofone) });
    }
    if (Number(x.pausaFoneSegundos) > 0) {
      causas.push({ codigo: 'fone', texto: 'O fone foi desconectado e a escuta está em pausa curta; ela volta sozinha em alguns segundos.' });
    }
    if (x.mic === false) {
      causas.push({ codigo: 'microfone', texto: 'A permissão de microfone está negada. Sem ela o serviço não consegue ouvir.' });
    }
    if (x.notificacoes === false) {
      causas.push({ codigo: 'notificacoes', texto: 'As notificações estão bloqueadas. O Android encerra serviço em primeiro plano que não pode mostrar a notificação.' });
    }
    if (x.bateriaLivre === false) {
      causas.push({ codigo: 'bateria', texto: 'A otimização de bateria está ativa: o sistema pode congelar o serviço com a tela apagada.' });
    }
    if (x.servico === false) {
      causas.push({ codigo: 'servico', texto: 'O serviço em primeiro plano não está rodando neste momento.' });
    }
    if (textoErro(x.ultimoErro)) {
      causas.push({ codigo: 'erro', texto: 'Último erro registrado pelo detector: ' + textoErro(x.ultimoErro) });
    }

    var titulo = causas.length
      ? 'A escuta não está ativa: ' + causas[0].texto
      : 'A escuta não está ativa e o diagnóstico não registra o motivo.';
    var detalhe = causas.length > 1
      ? 'Também encontrei: ' + causas.slice(1).map(function (c) { return c.texto; }).join(' ')
      : (causas.length ? '' : 'Verifique permissões, bateria e o serviço; se continuar, reinicie a escuta e olhe o registro.');

    return {
      ativa: false,
      codigo: causas.length ? causas[0].codigo : 'sem-causa',
      titulo: titulo,
      detalhe: detalhe,
      causas: causas,
      ultimoErro: textoErro(x.ultimoErro),
      ultimoEvento: ultimoEvento,
      desdeUltimoEventoMs: desdeUltimoEventoMs
    };
  }

  /**
   * Linha viva do microfone para a tela: quem está usando, se a escuta está pausada por
   * isso e se o serviço está no ar. Recebe o mesmo objeto de `estadoMicrofone()`.
   */
  function microfone(d) {
    var x = d || {};
    var ocupado = textoErro(x.bloqueioMicrofone);
    if (ocupado) {
      return {
        ocupado: true,
        nivel: 'erro',
        texto: 'Microfone em uso: ' + ocupado + ' A escuta fica pausada até o outro app liberar.'
      };
    }
    if (Number(x.pausaFoneSegundos) > 0) {
      return {
        ocupado: false,
        nivel: 'aviso',
        texto: 'Fone desconectado: pausa curta de ' + Number(x.pausaFoneSegundos) + ' s antes de voltar a ouvir.'
      };
    }
    if (x.escutando) {
      return { ocupado: false, nivel: 'ok', texto: 'Microfone livre — a escuta está ativa agora.' };
    }
    if (x.servico === false) {
      return { ocupado: false, nivel: 'aviso', texto: 'Microfone livre, mas o serviço de escuta não está rodando.' };
    }
    return { ocupado: false, nivel: 'aviso', texto: 'Microfone livre; a escuta não está ativa neste momento.' };
  }

  /** Frase pronta para a tela, com tempo relativo do último evento quando existe. */
  function frase(resultado) {
    var r = resultado || {};
    var partes = [String(r.titulo || '')];
    if (r.detalhe) partes.push(String(r.detalhe));
    if (r.ultimoEvento) {
      var min = Math.round((r.desdeUltimoEventoMs || 0) / 60000);
      partes.push('Último evento há ' + (min < 1 ? 'menos de 1 minuto' : min + ' minuto(s)') + '.');
    }
    return partes.filter(Boolean).join(' ');
  }

  var api = { explicar: explicar, frase: frase, microfone: microfone };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.SegundoPlano = api;
})(typeof window !== 'undefined' ? window : null);
