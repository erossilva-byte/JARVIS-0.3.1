/* Regras do pareamento no painel do PC — espelho de `core/pareamento.dart`.
 *
 * Só o que a tela precisa para validar o que foi digitado e mostrar o estado.
 * A prova HMAC e a conversa HTTP ficam no processo principal
 * (`platforms/desktop/pareamento.js`), que é quem tem acesso à rede e ao disco.
 */
(() => {
  'use strict';

  const PORTA_PADRAO = 47600;

  function normalizarCodigo(valor) {
    return String(valor === null || valor === undefined ? '' : valor).replace(/\D/g, '');
  }

  function codigoUtilizavel(valor) {
    const limpo = normalizarCodigo(valor);
    return limpo.length === 6 ? limpo : '';
  }

  function formatarCodigo(codigo) {
    const limpo = normalizarCodigo(codigo);
    return limpo.length === 6 ? limpo.slice(0, 3) + ' ' + limpo.slice(3) : limpo;
  }

  function enderecoDaRedeLocal(host) {
    const h = String(host || '').trim().toLowerCase().replace(/\[|\]/g, '');
    if (!h) return false;
    if (h === 'localhost' || h === '::1') return true;
    const ipv4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(h);
    if (ipv4) {
      const p = [1, 2, 3, 4].map((i) => Number(ipv4[i]));
      if (p.some((n) => n > 255)) return false;
      if (p[0] === 127 || p[0] === 10) return true;
      if (p[0] === 192 && p[1] === 168) return true;
      if (p[0] === 172 && p[1] >= 16 && p[1] <= 31) return true;
      if (p[0] === 169 && p[1] === 254) return true;
      return false;
    }
    if (h.includes(':')) return /^(fe8|fe9|fea|feb|fc|fd)/.test(h);
    return false;
  }

  function enderecoDoCelular(bruto, portaPadrao = PORTA_PADRAO) {
    let texto = String(bruto || '').trim();
    if (!texto) return null;
    texto = texto.replace(/^https?:\/\//i, '').replace(/\/+$/, '');
    let host = texto;
    let porta = portaPadrao;
    const ipv6 = /^\[([^\]]+)\](?::(\d+))?$/.exec(texto);
    if (ipv6) {
      host = ipv6[1];
      if (ipv6[2]) porta = Number(ipv6[2]);
    } else if (/^[^:]+:\d+$/.test(texto)) {
      const partes = texto.split(':');
      host = partes[0];
      porta = Number(partes[partes.length - 1]);
    }
    if (!Number.isInteger(porta) || porta <= 0 || porta > 65535) return null;
    if (!enderecoDaRedeLocal(host)) return null;
    return { host: host, porta: porta, endereco: host + ':' + porta };
  }

  /// Valida o que o usuário digitou antes de qualquer chamada nativa.
  function validarDigitacao(ip, codigo) {
    const limpo = codigoUtilizavel(codigo);
    if (!limpo) {
      return { ok: false, erro: 'Digite os 6 dígitos que aparecem no celular.' };
    }
    const alvo = enderecoDoCelular(ip);
    if (!alvo) {
      return {
        ok: false,
        erro: 'Endereço fora da rede local. Use o IP que aparece no celular, como 192.168.0.20.'
      };
    }
    return { ok: true, ip: alvo.endereco, codigo: limpo };
  }

  /// `true` só quando o estado veio do processo principal e tem dispositivo.
  function estadoPareado(estado) {
    return Boolean(estado && estado.pareado && estado.dispositivo);
  }

  function resumoPareado(estado) {
    if (!estadoPareado(estado)) return 'Sem conexão: nenhum celular pareado ainda.';
    const endereco = estado.endereco || (estado.ip + ':' + estado.porta);
    return 'Pareado com ' + estado.dispositivo + ' · ' + endereco + '.';
  }

  /// `true` quando o celular anunciou o protocolo 2 com o recurso `comando`.
  /// Celular antigo (ou registro gravado antes do protocolo 2) dá `false`, e a
  /// tela desabilita os botões em vez de mandar comando que seria recusado.
  function podeComandar(estado) {
    if (!estadoPareado(estado)) return false;
    const protocolo = String(estado.protocolo || '');
    const recursos = Array.isArray(estado.recursos) ? estado.recursos : [];
    return protocolo === 'jarvis/2' && recursos.indexOf('comando') >= 0;
  }

  window.Pareamento = {
    PORTA_PADRAO,
    normalizarCodigo,
    codigoUtilizavel,
    formatarCodigo,
    enderecoDaRedeLocal,
    enderecoDoCelular,
    validarDigitacao,
    estadoPareado,
    resumoPareado,
    podeComandar
  };
})();
