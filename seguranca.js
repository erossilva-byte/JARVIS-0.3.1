/* Núcleo da tela de bloqueio — decisões puras, sem DOM, sem rede e sem guardar segredo.
 *
 * Aqui vive o que pode ser testado em Node: modos de autenticação (PIN, biometria, NFC,
 * combinações e alternativas), política de tentativas, normalização de tags e histórico sem
 * credenciais. O app só executa; a prova de identidade continua sendo do Android.
 */
(function (raiz) {
  'use strict';

  var MODOS = {
    pin: { etapas: ['pin'], rotulo: 'Somente PIN' },
    bio: { etapas: ['bio'], rotulo: 'Biometria forte do Android' },
    nfc: { etapas: ['nfc'], rotulo: 'Tag NFC' },
    'bio|nfc': { etapas: ['bio', 'nfc'], alternativas: ['bio', 'nfc'], rotulo: 'Biometria ou NFC' },
    'pin|bio': { etapas: ['pin', 'bio'], alternativas: ['pin', 'bio'], rotulo: 'PIN ou biometria' },
    'pin|nfc': { etapas: ['pin', 'nfc'], alternativas: ['pin', 'nfc'], rotulo: 'PIN ou NFC' },
    'pin|bio|nfc': { etapas: ['pin', 'bio', 'nfc'], alternativas: ['pin', 'bio', 'nfc'], rotulo: 'PIN, biometria ou NFC' },
    'bio+nfc': { etapas: ['bio', 'nfc'], rotulo: 'Biometria + NFC (duas etapas)' },
    'bio+pin': { etapas: ['bio', 'pin'], rotulo: 'Biometria + PIN' },
    'nfc+pin': { etapas: ['nfc', 'pin'], rotulo: 'NFC + PIN' }
  };

  function modoCanonico(modo) {
    var m = String(modo == null ? '' : modo).replace(/\s+/g, '').toLowerCase();
    var aliases = {
      'pin+bio': 'bio+pin',
      'pin+nfc': 'nfc+pin',
      'bio|pin': 'pin|bio',
      'nfc|pin': 'pin|nfc',
      'bio|pin|nfc': 'pin|bio|nfc',
      'bio|nfc|pin': 'pin|bio|nfc',
      'nfc|bio|pin': 'pin|bio|nfc',
      'nfc|pin|bio': 'pin|bio|nfc'
    };
    return aliases[m] || m;
  }

  var PADRAO = {
    modo: 'pin',
    timeoutSeg: 120,
    maxTentativas: 5,
    esperaMaxSeg: 30,
    nfcAtivo: true,
    bioAtivo: true,
    tags: []
  };

  function inteiro(v, min, max, reserva) {
    var n = Number(v);
    if (!isFinite(n)) return reserva;
    n = Math.round(n);
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  function texto(v, max) {
    return String(v == null ? '' : v).replace(/[\u0000-\u001f]/g, ' ').trim().slice(0, max || 40);
  }

  function hex(v) { return String(v == null ? '' : v).replace(/[^0-9a-fA-F]/g, '').toUpperCase(); }

  function normalizarTag(t) {
    var o = t && typeof t === 'object' ? t : {};
    var uidHash = hex(o.uidHash).slice(0, 64);
    if (!uidHash) return null;
    return {
      id: texto(o.id, 24) || uidHash.slice(0, 8),
      nome: texto(o.nome, 40) || 'Tag sem nome',
      uidHash: uidHash,
      ult4: hex(o.ult4).slice(-4),
      ativa: o.ativa !== false,
      bloqueada: o.bloqueada === true,
      criptografica: o.criptografica === true,
      ultimoUso: Number(o.ultimoUso) || 0,
      criadaEm: Number(o.criadaEm) || 0
    };
  }

  function normalizar(bruto) {
    var o = bruto && typeof bruto === 'object' ? bruto : {};
    var cfg = {
      modo: MODOS[modoCanonico(o.modo)] ? modoCanonico(o.modo) : PADRAO.modo,
      timeoutSeg: inteiro(o.timeoutSeg, 15, 3600, PADRAO.timeoutSeg),
      maxTentativas: inteiro(o.maxTentativas, 3, 10, PADRAO.maxTentativas),
      esperaMaxSeg: inteiro(o.esperaMaxSeg, 5, 300, PADRAO.esperaMaxSeg),
      nfcAtivo: o.nfcAtivo !== false,
      bioAtivo: o.bioAtivo !== false,
      tags: []
    };
    var vistos = {};
    (Array.isArray(o.tags) ? o.tags : []).slice(0, 20).forEach(function (t) {
      var n = normalizarTag(t);
      if (!n || vistos[n.uidHash]) return;
      vistos[n.uidHash] = 1;
      cfg.tags.push(n);
    });
    return cfg;
  }

  function etapas(modo) {
    var m = MODOS[modoCanonico(modo)] || MODOS.pin;
    return m.etapas.slice();
  }

  function rotulo(modo) { return (MODOS[modoCanonico(modo)] || MODOS.pin).rotulo; }

  /** Uma prova satisfaz o modo quando cobre todas as etapas exigidas. */
  function avaliarProvas(modo, provas) {
    var p = provas || {};
    var m = MODOS[modoCanonico(modo)] || MODOS.pin;
    var exigidas = m.etapas.slice();
    if (m.alternativas && m.alternativas.length) {
      var alguma = m.alternativas.filter(function (e) { return p[e] === true; });
      if (alguma.length) return { ok: true, faltam: [], etapas: exigidas, alternativa: alguma[0] };
      return { ok: false, faltam: [m.alternativas.join(' ou ')], etapas: exigidas, alternativa: '' };
    }
    var faltam = exigidas.filter(function (e) { return p[e] !== true; });
    return { ok: faltam.length === 0, faltam: faltam, etapas: exigidas };
  }

  function tagDeLeitura(leitura, extras) {
    var o = leitura && typeof leitura === 'object' ? leitura : {};
    var uid = hex(o.uid);
    if (uid.length < 4) return { ok: false, motivo: 'A leitura não trouxe um identificador utilizável. Aproxime a tag de novo.' };
    var tech = Array.isArray(o.tech) ? o.tech.map(function (t) { return texto(t, 60); }) : [];
    var iso = tech.some(function (t) { return /IsoDep/i.test(t); });
    return {
      ok: true,
      tag: normalizarTag({
        id: uid.slice(0, 8),
        nome: extras && extras.nome,
        uidHash: extras && extras.uidHash,
        ult4: uid.slice(-4),
        criptografica: !!(o.criptografica || iso),
        criadaEm: Date.now()
      }),
      uid: uid,
      aviso: (o.criptografica || iso)
        ? 'A tag responde ao padrão ISO-DEP (família DESFire). Só uma autenticação criptográfica da própria tag impede clonagem; aqui o UID ainda é o critério.'
        : 'Tag de UID simples: pode ser clonada por quem tiver acesso físico. Use como conveniência, não como prova forte de identidade.'
    };
  }

  function mascararUid(uid) {
    var h = hex(uid);
    if (!h) return '—';
    return '•••• ' + h.slice(-4);
  }

  function acharTag(tags, uidHash) {
    var alvo = hex(uidHash);
    var lista = Array.isArray(tags) ? tags : [];
    for (var i = 0; i < lista.length; i++) {
      if (hex(lista[i].uidHash) === alvo) {
        if (lista[i].bloqueada) return { ok: false, tag: lista[i], motivo: 'Tag bloqueada nas configurações.' };
        if (!lista[i].ativa) return { ok: false, tag: lista[i], motivo: 'Tag desativada nas configurações.' };
        return { ok: true, tag: lista[i], motivo: 'Tag autorizada.' };
      }
    }
    return { ok: false, tag: null, motivo: 'Tag desconhecida. Nada foi liberado.' };
  }

  function tentativa(nAtual, maxTentativas, esperaMaxSeg) {
    var n = Math.max(1, Math.round(Number(nAtual) || 1));
    var max = inteiro(maxTentativas, 3, 10, PADRAO.maxTentativas);
    var teto = inteiro(esperaMaxSeg, 5, 300, PADRAO.esperaMaxSeg);
    var espera = Math.min(teto, Math.round(0.5 * Math.pow(2, Math.min(n, 6))));
    return {
      n: n,
      esperaSeg: espera,
      bloqueado: n >= max,
      aviso: n >= max
        ? 'Limite de ' + max + ' tentativas atingido. Use o PIN/código de recuperação; o app não apaga seus dados.'
        : 'Tente de novo em ' + espera + ' s.'
    };
  }

  function disponibilidade(d) {
    var o = d && typeof d === 'object' ? d : {};
    var rosto = o.rosto === true;
    var bio = o.biometria === true;
    var nfc = o.nfc === true;
    var digital = o.digital === true;
    var avisos = [];
    if (!bio) avisos.push(texto(o.motivo, 160) || 'Biometria forte indisponível; use PIN ou NFC.');
    if (bio && !rosto && digital) avisos.push('Biometria forte disponível por impressão digital. O Android decide qual sensor será usado pelo BiometricPrompt.');
    else if (bio && !rosto) avisos.push('O aparelho tem biometria forte, mas não informa hardware facial ou digital separadamente; o Android escolhe o sensor disponível.');
    if (rosto && !bio) avisos.push('Há hardware facial, mas nenhuma biometria forte cadastrada/liberada para autenticação.');
    if (!nfc) avisos.push('NFC ausente ou desligado neste aparelho.');
    return { bio: bio, rosto: rosto, digital: digital, nfc: nfc, pin: true, avisos: avisos };
  }

  /** Modo pedido é utilizável? Nunca esconde a limitação: devolve o motivo. */
  function modoViavel(modo, disp) {
    var d = disp || {};
    var chave = modoCanonico(modo);
    var m = MODOS[chave] ? MODOS[chave] : MODOS.pin;
    if (m.alternativas && m.alternativas.length) {
      var viaveis = m.alternativas.filter(function (fator) {
        return fator === 'pin' || d[fator] === true;
      });
      if (viaveis.length) return { ok: true, motivo: '', alternativas: viaveis };
      var precisaBio = m.alternativas.indexOf('bio') >= 0;
      var precisaNfc = m.alternativas.indexOf('nfc') >= 0;
      var motivo = [];
      if (precisaBio) motivo.push('biometria forte indisponível');
      if (precisaNfc) motivo.push('NFC ausente/desligado');
      return { ok: false, motivo: 'Nenhuma alternativa está disponível: ' + motivo.join(' e ') + '.' };
    }
    var precisaBio = m.etapas.indexOf('bio') >= 0;
    var precisaNfc = m.etapas.indexOf('nfc') >= 0;
    if (precisaBio && !d.bio) return { ok: false, motivo: 'Este aparelho não tem biometria forte disponível para o modo escolhido.' };
    if (precisaNfc && !d.nfc) return { ok: false, motivo: 'O NFC está ausente ou desligado; ative nas configurações do Android.' };
    return { ok: true, motivo: '' };
  }

  function evento(e, agora) {
    var o = e && typeof e === 'object' ? e : {};
    var limpar = function (t) {
      return texto(t, 120)
        .replace(/\b[0-9A-F]{8,}\b/g, '••••')
        .replace(/\b\d{4,}\b/g, '••••');
    };
    return {
      t: Number(o.t) || Number(agora) || Date.now(),
      metodo: texto(o.metodo, 16) || 'pin',
      resultado: o.resultado === 'ok' ? 'ok' : 'negado',
      detalhe: limpar(o.detalhe) || (o.resultado === 'ok' ? 'acesso liberado' : 'acesso negado')
    };
  }

  function historico(lista, novo, limite) {
    var l = Array.isArray(lista) ? lista.slice(0, limite || 60) : [];
    l.unshift(novo);
    return l.slice(0, limite || 60);
  }

  function resumo(cfg, disp) {
    var c = normalizar(cfg);
    var partes = ['Modo: ' + rotulo(c.modo)];
    partes.push('bloqueia após ' + c.timeoutSeg + ' s');
    partes.push(c.maxTentativas + ' tentativas antes do limite');
    if (c.tags.length) partes.push(c.tags.length + ' tag(s) cadastrada(s)');
    var viavel = modoViavel(c.modo, disp || { bio: true, nfc: true });
    if (!viavel.ok) partes.push('indisponível agora: ' + viavel.motivo);
    return partes.join(' · ');
  }

  var api = {
    MODOS: MODOS,
    PADRAO: PADRAO,
    normalizar: normalizar,
    normalizarTag: normalizarTag,
    etapas: etapas,
    rotulo: rotulo,
    avaliarProvas: avaliarProvas,
    tagDeLeitura: tagDeLeitura,
    mascararUid: mascararUid,
    acharTag: acharTag,
    tentativa: tentativa,
    disponibilidade: disponibilidade,
    modoViavel: modoViavel,
    evento: evento,
    historico: historico,
    resumo: resumo
  };

  raiz.SegurancaNucleo = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
