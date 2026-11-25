/* J.A.R.V.I.S. Nova — atualização assinada do PC (Etapa 7).
 *
 * A Etapa 7 pede instalador assinado, atualização com verificação de assinatura
 * e versão/changelog no app. Este módulo é a parte que pode ser provada sem PC
 * físico: as **regras** de aceitar ou recusar um pacote de atualização.
 *
 * Decisões:
 *  - a assinatura é Ed25519 sobre o JSON canônico do manifesto (chaves em
 *    ordem, sem espaços). Ela cobre versão, arquivo, tamanho, hash e canal —
 *    mudar qualquer campo invalida a assinatura;
 *  - além da assinatura, o hash SHA-256 e o tamanho do arquivo precisam bater
 *    com o que está no disco: assinatura válida de outro arquivo não passa;
 *  - versão igual ou mais velha é recusada (sem downgrade silencioso), e existe
 *    uma versão mínima para saltos grandes;
 *  - a chave privada nunca fica no app: ele só tem a pública, embutida no
 *    processo principal. Quem assina é a ferramenta `tools/assinar_atualizacao.js`
 *    com a chave guardada fora do repositório;
 *  - falha fecha: sem cripto, sem chave pública, sem assinatura ou sem hash
 *    calculado, o resultado é recusa com motivo — nunca "talvez".
 *
 * Roda no processo principal (Node) e nos testes. No navegador comum não há
 * `node:crypto` síncrono, e aí a verificação devolve `sem-cripto` em vez de
 * fingir que verificou.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.AtualizacaoPc = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var APP = 'jarvis-nova-pc';
  var CANAIS = ['estavel', 'beta'];

  function cripto() {
    try {
      if (typeof require === 'function') return require('node:crypto');
    } catch (e) { /* navegador */ }
    return null;
  }

  /* ---------- JSON canônico e versões ---------- */

  /** JSON com chaves em ordem e sem espaços: é o que a assinatura cobre. */
  function canonico(valor) {
    if (valor === null || typeof valor !== 'object') return JSON.stringify(valor);
    if (Array.isArray(valor)) return '[' + valor.map(canonico).join(',') + ']';
    var chaves = Object.keys(valor).sort();
    return '{' + chaves.map(function (k) {
      return JSON.stringify(k) + ':' + canonico(valor[k]);
    }).join(',') + '}';
  }

  function versaoValida(v) {
    return typeof v === 'string' && /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(v.trim());
  }

  function pedacos(v) {
    return String(v || '').trim().split(/[-+]/)[0].split('.').map(function (n) { return Number(n) || 0; });
  }

  /** -1, 0 ou 1. Só a parte numérica decide; sufixo não vira "maior". */
  function compararVersoes(a, b) {
    var pa = pedacos(a), pb = pedacos(b);
    for (var i = 0; i < 3; i++) {
      if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) > (pb[i] || 0) ? 1 : -1;
    }
    return 0;
  }

  /* ---------- Manifesto ---------- */

  var CAMPOS = ['app', 'canal', 'versao', 'arquivo', 'tamanho', 'sha256', 'data'];

  function validarManifesto(m) {
    var erros = [];
    if (!m || typeof m !== 'object') return { ok: false, erros: ['manifesto ausente'] };
    CAMPOS.forEach(function (campo) {
      if (m[campo] === undefined || m[campo] === null || m[campo] === '') erros.push('campo ' + campo + ' ausente');
    });
    if (m.app && m.app !== APP) erros.push('manifesto é de outro aplicativo: ' + m.app);
    if (m.canal && CANAIS.indexOf(m.canal) < 0) erros.push('canal desconhecido: ' + m.canal);
    if (m.versao && !versaoValida(m.versao)) erros.push('versão inválida: ' + m.versao);
    if (m.arquivo && !/\.exe$/i.test(String(m.arquivo))) erros.push('o pacote precisa ser um .exe do Windows');
    if (m.tamanho !== undefined && !(Number(m.tamanho) > 0)) erros.push('tamanho inválido');
    if (m.sha256 !== undefined && !/^[0-9a-f]{64}$/i.test(String(m.sha256))) erros.push('sha256 inválido');
    if (m.data !== undefined && isNaN(Date.parse(String(m.data)))) erros.push('data inválida');
    if (m.notas !== undefined && !Array.isArray(m.notas)) erros.push('notas precisam ser uma lista');
    return { ok: erros.length === 0, erros: erros };
  }

  /* ---------- Assinatura ---------- */

  function assinar(manifesto, chavePrivadaPem) {
    var c = cripto();
    if (!c) throw new Error('Sem node:crypto: a assinatura só é feita no processo de release.');
    var dados = Buffer.from(canonico(manifesto), 'utf8');
    return c.sign(null, dados, chavePrivadaPem).toString('base64');
  }

  function verificarAssinatura(manifesto, assinaturaB64, chavePublicaPem) {
    var c = cripto();
    if (!c) return { ok: false, motivo: 'sem-cripto', texto: 'Este ambiente não tem criptografia síncrona; a atualização não pode ser conferida aqui.' };
    if (!chavePublicaPem) return { ok: false, motivo: 'sem-chave', texto: 'Nenhuma chave pública de atualização está instalada; recusando por segurança.' };
    if (!assinaturaB64) return { ok: false, motivo: 'sem-assinatura', texto: 'O pacote de atualização não veio com assinatura; recusando.' };
    var dados = Buffer.from(canonico(manifesto), 'utf8');
    var sig;
    try { sig = Buffer.from(String(assinaturaB64), 'base64'); } catch (e) { sig = null; }
    if (!sig || !sig.length) return { ok: false, motivo: 'assinatura-invalida', texto: 'A assinatura do pacote não é base64 válido; recusando.' };
    var ok = false;
    try { ok = c.verify(null, dados, chavePublicaPem, sig); } catch (e) { ok = false; }
    return ok
      ? { ok: true, motivo: 'assinatura-ok', texto: 'Assinatura do pacote confere com a chave oficial.' }
      : { ok: false, motivo: 'assinatura-invalida', texto: 'A assinatura não confere: o pacote foi alterado ou não é oficial. Recusando.' };
  }

  /* ---------- Decisão completa ---------- */

  /**
   * Decide se o pacote pode ser aplicado. `sha256Arquivo` e `tamanhoArquivo`
   * vêm de quem leu o arquivo do disco; sem eles a decisão é recusa, porque
   * assinatura sem arquivo conferido não prova nada sobre o que será instalado.
   */
  function verificarAtualizacao(opcoes) {
    var o = opcoes || {};
    var m = o.manifesto;
    var valido = validarManifesto(m);
    if (!valido.ok) {
      return {
        ok: false, motivo: 'manifesto', texto: 'Manifesto de atualização inválido: ' + valido.erros.join('; ') + '.',
        erros: valido.erros
      };
    }
    var sig = verificarAssinatura(m, o.assinatura, o.chavePublica);
    if (!sig.ok) return { ok: false, motivo: sig.motivo, texto: sig.texto };

    if (!o.sha256Arquivo) {
      return { ok: false, motivo: 'sem-arquivo', texto: 'O arquivo da atualização não foi lido; não dá para confirmar o hash. Recusando.' };
    }
    if (String(o.sha256Arquivo).toLowerCase() !== String(m.sha256).toLowerCase()) {
      return { ok: false, motivo: 'hash', texto: 'O hash do arquivo não bate com o manifesto: o pacote está corrompido ou foi trocado. Recusando.' };
    }
    if (o.tamanhoArquivo !== undefined && Number(o.tamanhoArquivo) !== Number(m.tamanho)) {
      return { ok: false, motivo: 'tamanho', texto: 'O tamanho do arquivo difere do manifesto (' + o.tamanhoArquivo + ' bytes × ' + m.tamanho + '). Recusando.' };
    }

    var atual = String(o.versaoInstalada || '');
    if (!versaoValida(atual)) {
      return { ok: false, motivo: 'versao-instalada', texto: 'Não consegui ler a versão instalada; recusando a atualização.' };
    }
    var cmp = compararVersoes(m.versao, atual);
    if (cmp <= 0) {
      return {
        ok: false, motivo: cmp === 0 ? 'mesma-versao' : 'mais-antiga',
        texto: cmp === 0
          ? 'O pacote é a mesma versão já instalada (' + atual + '); nada a fazer.'
          : 'O pacote é mais antigo que o instalado (' + m.versao + ' × ' + atual + '); recusando rebaixamento.'
      };
    }
    if (m.minima && compararVersoes(atual, m.minima) < 0) {
      return {
        ok: false, motivo: 'versao-minima',
        texto: 'Esta atualização exige pelo menos a ' + m.minima + '; instale a intermediária primeiro.'
      };
    }
    if (o.aceitaCanal && m.canal !== o.aceitaCanal) {
      return { ok: false, motivo: 'canal', texto: 'O pacote é do canal ' + m.canal + ' e você está no ' + o.aceitaCanal + '.' };
    }
    return {
      ok: true, motivo: 'ok', versao: m.versao, canal: m.canal,
      notas: Array.isArray(m.notas) ? m.notas.slice(0, 12) : [],
      arquivo: m.arquivo, tamanho: Number(m.tamanho),
      texto: 'Atualização ' + m.versao + ' verificada: assinatura e hash conferem. Pronta para instalar.'
    };
  }

  /**
   * Passos de aplicação e de reversão. A reversão não é automática: o instalador
   * NSIS do Windows não tem desinstalação por linha de comando confiável em toda
   * versão, então o plano guarda o instalador anterior e o passo manual.
   */
  function planoDeAtualizacao(resultado, opcoes) {
    var o = opcoes || {};
    if (!resultado || !resultado.ok) {
      return { aplicar: [], reverter: [], motivo: 'sem-pacote-verificado' };
    }
    var anterior = String(o.instaladorAnterior || 'instalador da versão ' + (o.versaoInstalada || 'atual'));
    return {
      aplicar: [
        'Fechar o J.A.R.V.I.S. Nova antes de rodar o instalador.',
        'Rodar ' + resultado.arquivo + ' (a assinatura do pacote já foi conferida).',
        'Na primeira abertura, conferir a versão em Ajustes ▸ Sobre: precisa mostrar ' + resultado.versao + '.',
        'Testar uma conversa curta e a escuta de ativação antes de considerar concluída.'
      ],
      reverter: [
        'Desinstalar pela lista de programas do Windows mantendo a pasta de dados do usuário.',
        'Rodar ' + anterior + ' para voltar à versão anterior.',
        'Conferir em Ajustes ▸ Sobre se a versão voltou e avisar no relatório se algum dado mudou.'
      ],
      arquivoAnterior: anterior
    };
  }

  /* ---------- Notas da versão no app ---------- */

  /**
   * Extrai do CHANGELOG o bloco da versão instalada, para o app mostrar o que
   * mudou sem precisar de internet. Devolve `ok:false` quando a versão não está
   * no arquivo — e o app diz isso em vez de mostrar notas de outra versão.
   */
  function notasDaVersao(texto, versao) {
    var alvo = String(versao || '').trim();
    if (!alvo || !texto) return { ok: false, versao: alvo, titulo: '', notas: [] };
    var linhas = String(texto).split(/\r?\n/);
    var inicio = -1;
    for (var i = 0; i < linhas.length; i++) {
      var m = /^##\s+(\d+\.\d+\.\d+)/.exec(linhas[i].trim());
      if (m && m[1] === alvo) { inicio = i; break; }
    }
    if (inicio < 0) return { ok: false, versao: alvo, titulo: '', notas: [] };
    var titulo = linhas[inicio].replace(/^##\s+/, '').trim();
    var notas = [];
    for (var j = inicio + 1; j < linhas.length; j++) {
      if (/^##\s+/.test(linhas[j])) break;
      var t = linhas[j].trim();
      if (!t || /^###/.test(t)) continue;
      if (t.charAt(0) === '-' || t.charAt(0) === '*') t = t.slice(1).trim();
      // O CHANGELOG usa negrito e crase; na tela do app isso viraria asterisco solto.
      if (t) notas.push(t.replace(/\*\*|`/g, '').replace(/\s+/g, ' '));
    }
    return { ok: true, versao: alvo, titulo: titulo, notas: notas.slice(0, 20) };
  }

  var api = {
    APP: APP,
    CANAIS: CANAIS,
    canonico: canonico,
    versaoValida: versaoValida,
    compararVersoes: compararVersoes,
    validarManifesto: validarManifesto,
    assinar: assinar,
    verificarAssinatura: verificarAssinatura,
    verificarAtualizacao: verificarAtualizacao,
    planoDeAtualizacao: planoDeAtualizacao,
    notasDaVersao: notasDaVersao,
    temCripto: function () { return Boolean(cripto()); }
  };
  return api;
});
