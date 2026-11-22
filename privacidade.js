/* J.A.R.V.I.S. Nova — auditoria de privacidade da ativação (Fase 4B).
 *
 * O detector é local; o que a tela pode provar com número é o tráfego do próprio app desde
 * que o serviço iniciou (contador do Android) e o fato de o áudio não sair antes da palavra.
 * Este módulo transforma isso em texto — inclusive quando o contador não está disponível,
 * caso em que assume que não sabe em vez de dizer "zero".
 */
(function (raiz) {
  'use strict';

  function formatarBytes(n) {
    var v = Number(n);
    if (!isFinite(v) || v < 0) return '—';
    if (v < 1024) return v + ' B';
    if (v < 1024 * 1024) return (v / 1024).toFixed(1).replace('.', ',') + ' KB';
    return (v / (1024 * 1024)).toFixed(1).replace('.', ',') + ' MB';
  }

  /**
   * @param {object} e { redeBytesDesdeInicio, escutando }
   */
  function resumo(e) {
    var x = e || {};
    var bytes = Number(x.redeBytesDesdeInicio);
    var partes = [];

    if (!isFinite(bytes) || bytes < 0) {
      partes.push('Tráfego de rede: o Android não informou o contador nesta versão — não dá para afirmar zero por aqui.');
    } else if (bytes === 0) {
      partes.push('Nenhum byte de rede saiu do app desde que o serviço iniciou.');
    } else {
      partes.push('Saíram ' + formatarBytes(bytes) + ' do app desde que o serviço iniciou; é o tráfego total do app, não prova sozinho o que era.');
    }

    partes.push('A ativação é local (sherpa-onnx): o microfone é usado só para detectar a palavra e o áudio não é enviado antes dela.');
    if (x.escutando) partes.push('A escuta está ativa agora e nenhuma captura virou envio.');
    return partes.join(' ');
  }

  var api = { resumo: resumo, formatarBytes: formatarBytes };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.Privacidade = api;
})(typeof window !== 'undefined' ? window : null);
