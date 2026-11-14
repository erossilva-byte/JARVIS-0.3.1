/* J.A.R.V.I.S. Nova — manutenção periódica do segundo plano (Fase 4B).
 *
 * O WorkManager roda a manutenção no Android; este módulo só transforma o estado que o
 * serviço devolve em uma frase honesta para o diagnóstico. Se nunca rodou, diz isso; se
 * não está agendada, avisa em vez de fingir que está tudo certo.
 */
(function (raiz) {
  'use strict';

  function descrever(estado, agora) {
    var e = estado || {};
    var t = Number(agora) > 0 ? Number(agora) : Date.now();
    var ultima = Number(e.ultimaManutencao) > 0 ? Number(e.ultimaManutencao) : 0;
    var partes = [];

    if (!ultima) {
      partes.push('A verificação automática do segundo plano ainda não rodou.');
    } else {
      var ms = Math.max(0, t - ultima);
      var min = Math.floor(ms / 60000);
      var quando;
      if (min < 1) quando = 'agora há pouco';
      else if (min < 60) quando = 'há ' + min + ' minuto' + (min === 1 ? '' : 's');
      else {
        var horas = Math.floor(min / 60);
        if (horas < 24) quando = 'há ' + horas + ' hora' + (horas === 1 ? '' : 's');
        else {
          var dias = Math.floor(horas / 24);
          quando = 'há ' + dias + ' dia' + (dias === 1 ? '' : 's');
        }
      }
      partes.push('Última verificação automática ' + quando + '.');
    }

    if (e.manutencaoAgendada) {
      partes.push('A próxima é agendada pelo Android, a cada 6 horas, sem rodar com bateria baixa.');
    } else {
      partes.push('A manutenção periódica não está agendada: abra a escuta uma vez para o Android reagendar.');
    }
    return partes.join(' ');
  }

  var api = { descrever: descrever };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.Manutencao = api;
})(typeof window !== 'undefined' ? window : null);
