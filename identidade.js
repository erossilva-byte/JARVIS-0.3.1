/* J.A.R.V.I.S. Nova — identificação de pessoas.
 *
 * Núcleo puro (sem DOM), usado pela aba Identificação de Pessoas, pelo prompt da IA
 * e pela voz. Cada pessoa tem um perfil próprio; a voz é comparada por vetor de
 * características gerado pelo voz_motor.js (nunca pelo áudio bruto).
 *
 * O que este módulo garante:
 *  - nome é o único campo obrigatório; nada é inventado ou preenchido por suposição;
 *  - consentimento explícito e separado para voz e para referência visual;
 *  - vetores de voz e descritor visual só entram com qualidade aceita e consentimento;
 *  - identificação open-set com limiar e margem: desconhecido e dúvida nunca viram
 *    uma pessoa cadastrada por chute;
 *  - histórico de alterações sem guardar biometria nem contato;
 *  - biometria cifrada em repouso (AES-GCM) com chave local. Isso protege contra
 *    leitura casual do armazenamento/backup, não contra um aparelho comprometido —
 *    não existe aqui Keystore/cofre de hardware.
 *
 * O reconhecimento facial é OPCIONAL e não é biometria facial: usa um hash visual
 * (dHash) da foto de referência e devolve sempre "indício visual", nunca identidade.
 */

(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.IdentidadeJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var CHAVE = 'jv_identidade';
  var CHAVE_BIO = 'jv_identidade_bio';
  var CHAVE_CHAVE = 'jv_identidade_chave';
  var CHAVE_CFG = 'jv_identidade_cfg';
  var LIMITE_PERFIS = 80;
  var LIMITE_BYTES = 1024 * 1024;
  var LIMITE_AMOSTRAS = 8;
  var LIMITE_HISTORICO = 40;
  var FOTO_MAX_BYTES = 220 * 1024;

  var ESTADOS = {
    IDENTIFICADO: 'identificado',
    NAO_IDENTIFICADO: 'nao-identificado',
    INCONCLUSIVO: 'inconclusivo',
    DESATIVADO: 'desativado',
    SEM_PERFIL: 'sem-perfil'
  };

  var CAMPOS = {
    nome: 60, apelido: 40, nascimento: 10, alturaCm: 3, profissao: 60,
    relacao: 60, telefone: 24, email: 90, endereco: 120, cidade: 60,
    descricao: 500, preferencias: 500, interesses: 500, observacoes: 900,
    contexto: 500
  };
  var ROTULO = {
    nome: 'Nome', apelido: 'Apelido', nascimento: 'Nascimento', alturaCm: 'Altura',
    profissao: 'Profissão', relacao: 'Relação', telefone: 'Telefone', email: 'E-mail',
    endereco: 'Endereço', cidade: 'Cidade', descricao: 'Descrição',
    preferencias: 'Preferências', interesses: 'Interesses',
    observacoes: 'Observações', contexto: 'Contexto de relacionamento'
  };

  var PADRAO = {
    voz: true, rosto: false, limiar: 0.78, margem: 0.07,
    falaMin: 1.5, snrMin: 10, rostoLimiar: 0.88, contexto: true, confirmar: true
  };
  var LIMITES = {
    limiar: [0.68, 0.92], margem: [0.04, 0.15], falaMin: [1, 5],
    snrMin: [6, 30], rostoLimiar: [0.84, 0.96]
  };

  var deposito = null;
  var relogio = function () { return Date.now(); };
  var motor = null;
  var webcrypto = null;
  var bio = Object.create(null);
  var bioCarregada = false;
  var bioCifrada = true;

  function storePadrao() {
    try { if (typeof localStorage !== 'undefined') return localStorage; } catch (e) { /* sem localStorage */ }
    return null;
  }
  function store() { return deposito || storePadrao(); }
  function lerCru(chave) {
    var s = store();
    if (!s) return '';
    try { return s.getItem(chave) || ''; } catch (e) { return ''; }
  }
  function gravarCru(chave, valor) {
    var s = store();
    if (!s) return false;
    try { s.setItem(chave, valor); return true; } catch (e) { return false; }
  }

  function limpar(txt, max) {
    return String(txt == null ? '' : txt)
      .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, ' ')
      .replace(/[<>]/g, '')
      .replace(/[ \t]+/g, ' ')
      .replace(/\n{3,}/g, '\n\n')
      .trim()
      .slice(0, max);
  }
  function normalizar(txt) {
    return String(txt == null ? '' : txt).normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function bytes(lista) {
    var t = JSON.stringify(lista || []);
    try { if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(t).length; } catch (e) { /* fallback */ }
    return unescape(encodeURIComponent(t)).length;
  }
  function clonar(obj) { return JSON.parse(JSON.stringify(obj)); }
  function agoraISO() { return new Date(relogio()).toISOString(); }
  function novoId() {
    return 'id_' + relogio().toString(36) + '_' + Math.random().toString(36).slice(2, 7);
  }

  function perfis() {
    var bruto = lerCru(CHAVE);
    if (!bruto) return [];
    try {
      var j = JSON.parse(bruto);
      return Array.isArray(j) ? j.filter(function (p) { return p && typeof p.id === 'string'; }) : [];
    } catch (e) { return []; }
  }
  function gravarPerfis(lista) {
    var limpos = lista.map(function (p) { var c = Object.assign({}, p); delete c.vozes; return c; });
    if (bytes(limpos) > LIMITE_BYTES) return false;
    return gravarCru(CHAVE, JSON.stringify(limpos));
  }
  function indexar(lista) {
    var mapa = Object.create(null);
    lista.forEach(function (p) { mapa[p.id] = p; });
    return mapa;
  }

  /* ---------------- configuração ---------------- */
  function config() {
    var cfg = Object.assign({}, PADRAO);
    var bruto = lerCru(CHAVE_CFG);
    if (bruto) {
      try {
        var j = JSON.parse(bruto);
        if (j && typeof j === 'object') Object.keys(PADRAO).forEach(function (k) {
          if (j[k] !== undefined) cfg[k] = j[k];
        });
      } catch (e) { /* usa padrão */ }
    }
    return limitarConfig(cfg);
  }
  function limitarConfig(cfg) {
    var c = Object.assign({}, PADRAO, cfg || {});
    Object.keys(LIMITES).forEach(function (k) {
      var faixa = LIMITES[k];
      var n = Number(c[k]);
      if (!isFinite(n)) n = PADRAO[k];
      c[k] = Math.max(faixa[0], Math.min(faixa[1], n));
    });
    c.voz = c.voz !== false;
    c.rosto = c.rosto === true;
    c.contexto = c.contexto !== false;
    c.confirmar = c.confirmar !== false;
    return c;
  }
  function salvarConfig(patch) {
    var c = limitarConfig(Object.assign({}, config(), patch || {}));
    gravarCru(CHAVE_CFG, JSON.stringify(c));
    return c;
  }

  /* ---------------- criptografia da biometria ---------------- */
  function b64DeBytes(bytesArray) {
    var s = '';
    for (var i = 0; i < bytesArray.length; i++) s += String.fromCharCode(bytesArray[i]);
    if (typeof btoa === 'function') return btoa(s);
    return Buffer.from(bytesArray).toString('base64');
  }
  function bytesDeB64(txt) {
    var s = String(txt || '');
    if (typeof atob === 'function') {
      var bruto = atob(s), out = new Uint8Array(bruto.length);
      for (var i = 0; i < bruto.length; i++) out[i] = bruto.charCodeAt(i);
      return out;
    }
    return new Uint8Array(Buffer.from(s, 'base64'));
  }
  function chaveBytes() {
    var salva = lerCru(CHAVE_CHAVE);
    if (salva) {
      try { var b = bytesDeB64(salva); if (b.length === 32) return b; } catch (e) { /* gera nova */ }
    }
    var nova = new Uint8Array(32);
    if (webcrypto && webcrypto.getRandomValues) webcrypto.getRandomValues(nova);
    else for (var i = 0; i < 32; i++) nova[i] = Math.floor(Math.random() * 256);
    gravarCru(CHAVE_CHAVE, b64DeBytes(nova));
    return nova;
  }
  async function cifrar(texto) {
    if (!webcrypto || !webcrypto.subtle) throw new Error('WebCrypto indisponível');
    var key = await webcrypto.subtle.importKey('raw', chaveBytes(), 'AES-GCM', false, ['encrypt']);
    var iv = new Uint8Array(12);
    webcrypto.getRandomValues(iv);
    var ct = await webcrypto.subtle.encrypt({ name: 'AES-GCM', iv: iv }, key, new TextEncoder().encode(texto));
    return { cifrado: true, iv: b64DeBytes(iv), dados: b64DeBytes(new Uint8Array(ct)) };
  }
  async function decifrar(pacote) {
    if (!webcrypto || !webcrypto.subtle) throw new Error('WebCrypto indisponível');
    var key = await webcrypto.subtle.importKey('raw', chaveBytes(), 'AES-GCM', false, ['decrypt']);
    var claro = await webcrypto.subtle.decrypt(
      { name: 'AES-GCM', iv: bytesDeB64(pacote.iv) }, key, bytesDeB64(pacote.dados));
    return new TextDecoder().decode(claro);
  }
  async function carregarBio() {
    bio = Object.create(null);
    bossem: {
      var bruto = lerCru(CHAVE_BIO);
      if (!bruto) { bioCarregada = true; return { ok: true, vazio: true, cifrado: bioCifrada }; }
      try {
        var j = JSON.parse(bruto);
        if (j && j.cifrado) {
          var texto = await decifrar(j);
          var dados = JSON.parse(texto);
          if (dados && typeof dados === 'object') bio = dados;
          bioCifrada = true;
        } else {
          bio = (j && j.dados && typeof j.dados === 'object') ? j.dados : {};
          bioCifrada = false;
        }
      } catch (e) {
        bio = Object.create(null);
        return { ok: false, erro: 'Não foi possível decifrar as referências biométricas. O perfil de voz precisa ser cadastrado de novo.', detalhe: String((e && e.message) || e) };
      }
    }
    bioCarregada = true;
    return { ok: true, cifrado: bioCifrada };
  }
  async function persistirBio() {
    var texto = JSON.stringify(bio);
    if (webcrypto && webcrypto.subtle) {
      var pacote = await cifrar(texto);
      bioCifrada = true;
      return gravarCru(CHAVE_BIO, JSON.stringify(pacote));
    }
    bioCifrada = false;
    return gravarCru(CHAVE_BIO, JSON.stringify({ cifrado: false, dados: bio }));
  }
  async function iniciar() {
    var r = await carregarBio();
    try { motor = motor || (typeof VozMotor !== 'undefined' ? VozMotor : (typeof require === 'function' ? require('./voz_motor.js') : null)); } catch (e) { motor = motor || null; }
    return r;
  }
  async function garantirBio() { if (!bioCarregada) await carregarBio(); }

  /* ---------------- perfil ---------------- */
  function dataValida(txt) {
    var s = String(txt || '');
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
    if (!m) return false;
    var d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
    return d.getUTCFullYear() === Number(m[1]) && d.getUTCMonth() === Number(m[2]) - 1 &&
      d.getUTCDate() === Number(m[3]) && d.getTime() <= relogio();
  }
  function idade(nascimento) {
    if (!dataValida(nascimento)) return null;
    var n = String(nascimento).split('-').map(Number);
    var h = new Date(relogio());
    var anos = h.getFullYear() - n[0];
    var md = (h.getMonth() + 1) - n[1];
    if (md < 0 || (md === 0 && h.getDate() < n[2])) anos--;
    return anos >= 0 && anos < 130 ? anos : null;
  }
  function camposPersonalizados(lista) {
    if (!Array.isArray(lista)) return [];
    return lista.slice(0, 12).map(function (c) {
      return {
        rotulo: limpar(c && c.rotulo, 40),
        valor: limpar(c && c.valor, 240)
      };
    }).filter(function (c) { return c.rotulo && c.valor; });
  }

  function preparar(dados, atual) {
    var d = dados || {};
    var p = atual ? clonar(atual) : {
      id: novoId(), criado: relogio(), historico: [],
      foto: '', vozes: [], rosto: null,
      consentimento: { voz: { ok: false }, rosto: { ok: false } }
    };
    var antes = {};
    Object.keys(CAMPOS).forEach(function (campo) {
      if (d[campo] === undefined && atual) return;
      var valor = campo === 'alturaCm'
        ? (String(d[campo] == null ? '' : d[campo]).replace(/[^0-9]/g, '').slice(0, 3))
        : limpar(d[campo], CAMPOS[campo]);
      if (campo === 'nascimento' && valor && !dataValida(valor)) valor = '';
      antes[campo] = p[campo] || '';
      p[campo] = valor;
    });
    if (d.campos !== undefined) {
      var novos = camposPersonalizados(d.campos);
      antes.campos = JSON.stringify(p.campos || []);
      p.campos = novos;
    }
    if (atual) {
      Object.keys(antes).forEach(function (campo) {
        var depois = campo === 'campos' ? JSON.stringify(p.campos || []) : (p[campo] || '');
        if (String(antes[campo]) !== String(depois)) registrar(p, campo, antes[campo], depois);
      });
    }
    p.atualizado = relogio();
    return p;
  }
  function registrar(p, campo, de, para) {
    if (!p.historico) p.historico = [];
    var resumo = function (v) {
      var s = String(v == null ? '' : v);
      if (campo === 'campos') return s.length > 80 ? 'campos personalizados alterados' : s;
      return s.length > 80 ? s.slice(0, 77) + '…' : s;
    };
    p.historico.unshift({ em: relogio(), campo: campo, de: resumo(de), para: resumo(para) });
    p.historico = p.historico.slice(0, LIMITE_HISTORICO);
  }
  function validar(p) {
    if (!p.nome) return 'Informe o nome ou uma identificação para a pessoa.';
    if (p.nascimento && !dataValida(p.nascimento)) return 'Data de nascimento inválida (use AAAA-MM-DD).';
    if (p.alturaCm) {
      var a = Number(p.alturaCm);
      if (!(a >= 30 && a <= 250)) return 'Altura deve ficar entre 30 cm e 250 cm.';
    }
    if (p.email && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(p.email)) return 'E-mail inválido.';
    return '';
  }

  function listar() {
    return perfis().slice().sort(function (a, b) {
      return normalizar(a.nome).localeCompare(normalizar(b.nome), 'pt-BR');
    });
  }
  function obter(id) { return perfis().filter(function (p) { return p.id === id; })[0] || null; }
  function salvar(dados) {
    var lista = perfis();
    var atual = dados && dados.id ? obter(dados.id) : null;
    if (dados && dados.id && !atual) return { ok: false, erro: 'Perfil não encontrado.' };
    var p = preparar(dados, atual);
    var erro = validar(p);
    if (erro) return { ok: false, erro: erro };
    if (!atual && lista.length >= LIMITE_PERFIS) {
      return { ok: false, erro: 'Limite de ' + LIMITE_PERFIS + ' perfis. Apague algum antes de criar outro.' };
    }
    var proxima = atual
      ? lista.map(function (x) { return x.id === p.id ? p : x; })
      : lista.concat([p]);
    if (!gravarPerfis(proxima)) return { ok: false, erro: 'Não foi possível gravar os perfis neste aparelho (limite de 1 MB).' };
    return { ok: true, perfil: p };
  }
  function remover(id) {
    var lista = perfis();
    var proxima = lista.filter(function (p) { return p.id !== id; });
    if (proxima.length === lista.length) return { ok: false, erro: 'Perfil não encontrado.' };
    return removerEmCadeia(id, proxima);
  }
  async function removerEmCadeia(id, proxima) {
    if (!gravarPerfis(proxima)) return { ok: false, erro: 'Não foi possível gravar os perfis.' };
    await garantirBio();
    if (bio[id]) {
      delete bio[id];
      try { await persistirBio(); } catch (e) { /* o perfil já foi apagado; biometria órfã é limpa no próximo cadastro */ }
    }
    return { ok: true };
  }
  function buscar(termo) {
    var t = normalizar(termo);
    if (!t) return listar();
    return listar().filter(function (p) {
      return normalizar(p.nome).indexOf(t) >= 0 || normalizar(p.apelido).indexOf(t) >= 0 ||
        normalizar(p.profissao).indexOf(t) >= 0 || normalizar(p.relacao).indexOf(t) >= 0;
    });
  }
  function resolver(termo) {
    var t = normalizar(termo);
    if (!t) return { tipo: 'nenhum', candidatos: [] };
    var todos = listar();
    var exatos = todos.filter(function (p) {
      return normalizar(p.nome) === t || (p.apelido && normalizar(p.apelido) === t);
    });
    if (exatos.length === 1) return { tipo: 'exato', perfil: exatos[0], candidatos: exatos };
    if (exatos.length > 1) return { tipo: 'ambiguo', candidatos: exatos };
    var parciais = todos.filter(function (p) {
      return normalizar(p.nome).indexOf(t) >= 0 || (p.apelido && normalizar(p.apelido).indexOf(t) >= 0);
    });
    if (parciais.length === 1) return { tipo: 'unico', perfil: parciais[0], candidatos: parciais };
    if (parciais.length > 1) return { tipo: 'ambiguo', candidatos: parciais };
    return { tipo: 'nenhum', candidatos: [] };
  }

  function descrever(p) {
    if (!p) return '';
    var partes = [];
    var anos = idade(p.nascimento);
    if (anos != null) partes.push(anos + ' anos');
    if (p.apelido) partes.push('também conhecido como ' + p.apelido);
    if (p.relacao) partes.push(p.relacao);
    if (p.profissao) partes.push(p.profissao);
    if (p.cidade) partes.push('mora em ' + p.cidade);
    if (p.descricao) partes.push(p.descricao);
    if (p.preferencias) partes.push('preferências: ' + p.preferencias);
    if (p.interesses) partes.push('interesses: ' + p.interesses);
    if (p.observacoes) partes.push('observações: ' + p.observacoes);
    if (p.contexto) partes.push('contexto: ' + p.contexto);
    (p.campos || []).forEach(function (c) { partes.push(c.rotulo + ': ' + c.valor); });
    return (p.nome || 'sem nome') + (partes.length ? ' — ' + partes.join('. ') : '. Nenhuma informação além do nome.');
  }
  function contexto() {
    var lista = listar().slice(0, 12);
    if (!lista.length) return '';
    return lista.map(function (p) {
      var bits = [];
      if (p.apelido) bits.push('(' + p.apelido + ')');
      if (p.relacao) bits.push(p.relacao);
      if (p.profissao) bits.push(p.profissao);
      if (p.cidade) bits.push(p.cidade);
      if (p.preferencias) bits.push('prefere ' + p.preferencias);
      var linha = '- ' + p.nome + (bits.length ? ' · ' + bits.join(' · ') : '');
      if (p.descricao) linha += ' · ' + p.descricao;
      if (p.observacoes) linha += ' · ' + p.observacoes;
      return linha.slice(0, 260);
    }).join('\n');
  }
  function resumo() {
    var lista = listar();
    var comVoz = lista.filter(function (p) { return p.vozPronta; }).length;
    var comRosto = lista.filter(function (p) { return !!p.rosto; }).length;
    return { total: lista.length, comVoz: comVoz, comRosto: comRosto };
  }

  /* ---------------- foto e referência visual ---------------- */
  function definirFoto(id, dataUrl) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    if (!dataUrl) return removerFoto(id);
    var s = String(dataUrl);
    if (!/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(s)) {
      return { ok: false, erro: 'Formato de imagem não aceito. Use JPEG, PNG ou WebP.' };
    }
    var aprox = Math.ceil((s.length - s.indexOf(',') - 1) * 3 / 4);
    if (aprox > FOTO_MAX_BYTES) return { ok: false, erro: 'Foto acima de 220 kB. Reduza o recorte antes de salvar.' };
    p.foto = s;
    p.atualizado = relogio();
    registrar(p, 'foto', '', 'atualizada');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Não foi possível gravar a foto.' };
    }
    return { ok: true, perfil: p };
  }
  function removerFoto(id) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    p.foto = '';
    p.rosto = null;
    p.consentimento = p.consentimento || {};
    p.consentimento.rosto = { ok: false };
    p.atualizado = relogio();
    registrar(p, 'foto', 'removida', '');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Não foi possível remover a foto.' };
    }
    return { ok: true, perfil: p };
  }
  function consentir(id, tipo, texto) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    if (tipo !== 'voz' && tipo !== 'rosto') return { ok: false, erro: 'Tipo de consentimento desconhecido.' };
    p.consentimento = p.consentimento || {};
    p.consentimento[tipo] = {
      ok: true, em: relogio(),
      finalidade: limpar(texto || (tipo === 'voz'
        ? 'Comparar a minha voz com este perfil neste aparelho'
        : 'Comparar a minha fotografia com este perfil neste aparelho'), 160)
    };
    registrar(p, 'consentimento-' + tipo, '', 'autorizado');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Não foi possível gravar o consentimento.' };
    }
    return { ok: true, perfil: p };
  }
  function revogarConsentimento(id, tipo) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    p.consentimento = p.consentimento || {};
    p.consentimento[tipo] = { ok: false };
    if (tipo === 'voz') { delete bio[p.id]; p.vozPronta = false; p.amostras = 0; }
    if (tipo === 'rosto') p.rosto = null;
    registrar(p, 'consentimento-' + tipo, 'autorizado', 'revogado');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Não foi possível revogar o consentimento.' };
    }
    persistirBio().catch(function () {});
    return { ok: true, perfil: p };
  }
  function definirRosto(id, descritor) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    if (!p.consentimento || !p.consentimento.rosto || !p.consentimento.rosto.ok) {
      return { ok: false, erro: 'É preciso autorizar a referência visual antes de criá-la.' };
    }
    var d = descritor || {};
    if (!/^[0-9a-f]{16}$/.test(String(d.dhash || ''))) return { ok: false, erro: 'Descritor visual inválido.' };
    p.rosto = { dhash: String(d.dhash), aspecto: Number(d.aspecto) || 1, criado: relogio() };
    p.atualizado = relogio();
    registrar(p, 'rosto', '', 'referência visual criada');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Não foi possível gravar a referência visual.' };
    }
    return { ok: true, perfil: p };
  }
  function removerRosto(id) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    p.rosto = null;
    p.atualizado = relogio();
    registrar(p, 'rosto', 'referência visual', '');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Não foi possível remover a referência visual.' };
    }
    return { ok: true, perfil: p };
  }

  /* ---------------- voz ---------------- */
  function avaliarQualidade(analise) {
    var cfg = config();
    var q = (analise && analise.qualidade) || null;
    var problemas = [];
    if (!q) problemas.push('Sem análise de qualidade desta amostra.');
    else {
      problemas = (q.problemas || []).slice();
      if (Number(q.falaSeg) < cfg.falaMin) problemas.push('Fale por pelo menos ' + cfg.falaMin.toFixed(1) + ' s.');
      if (Number(q.snrDb) < cfg.snrMin) problemas.push('Relação sinal/ruído abaixo de ' + cfg.snrMin + ' dB.');
      if (Number(q.clipping) > 3) problemas.push('Áudio saturado; afaste-se do microfone.');
    }
    return { ok: problemas.length === 0, problemas: problemas };
  }
  async function adicionarVoz(id, analise) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    if (!p.consentimento || !p.consentimento.voz || !p.consentimento.voz.ok) {
      return { ok: false, erro: 'A pessoa precisa autorizar o cadastro da voz neste aparelho.' };
    }
    if (!analise || !Array.isArray(analise.v) || !analise.v.length) {
      return { ok: false, erro: 'A amostra não trouxe um vetor de voz válido.' };
    }
    var esperado = motor && motor.DIM ? motor.DIM : 59;
    if (analise.v.length !== esperado) {
      return { ok: false, erro: 'Vetor de ' + analise.v.length + ' dimensões; o motor espera ' + esperado + '.' };
    }
    var qual = avaliarQualidade(analise);
    if (!qual.ok) return { ok: false, erro: 'Amostra recusada: ' + qual.problemas.join(' '), qualidade: qual };
    await garantirBio();
    var lista = bio[p.id] || [];
    if (lista.length >= LIMITE_AMOSTRAS) return { ok: false, erro: 'Limite de ' + LIMITE_AMOSTRAS + ' amostras por pessoa. Apague uma antes de adicionar outra.' };
    lista.push({
      v: analise.v.map(function (x) { return +Number(x).toFixed(6); }),
      dim: analise.v.length, versao: analise.versao || (motor && motor.VERSAO) || 0,
      qualidade: {
        falaSeg: +(analise.qualidade.falaSeg || 0), snrDb: +(analise.qualidade.snrDb || 0),
        clipping: +(analise.qualidade.clipping || 0), pitchHz: +((analise.metricas || {}).pitchHz || 0)
      },
      criado: relogio()
    });
    bio[p.id] = lista;
    try { if (!(await persistirBio())) return { ok: false, erro: 'Não foi possível gravar a biometria.' }; }
    catch (e) { return { ok: false, erro: 'Falha ao cifrar/gravar a biometria: ' + ((e && e.message) || e) }; }
    p.amostras = lista.length;
    p.vozPronta = lista.length >= 3;
    p.atualizado = relogio();
    registrar(p, 'voz', String(lista.length - 1), String(lista.length) + ' amostra(s)');
    if (!gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }))) {
      return { ok: false, erro: 'Biometria gravada, mas o perfil não pôde ser atualizado.' };
    }
    return { ok: true, amostras: lista.length, pronta: p.vozPronta, cifrado: bioCifrada };
  }
  async function removerVoz(id, indice) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    await garantirBio();
    var lista = bio[id] || [];
    if (indice == null) lista = [];
    else if (indice >= 0 && indice < lista.length) lista.splice(indice, 1);
    else return { ok: false, erro: 'Amostra não encontrada.' };
    if (lista.length) bio[id] = lista; else delete bio[id];
    try { if (!(await persistirBio())) return { ok: false, erro: 'Não foi possível gravar a biometria.' }; }
    catch (e) { return { ok: false, erro: 'Falha ao gravar a biometria: ' + ((e && e.message) || e) }; }
    p.amostras = lista.length;
    p.vozPronta = lista.length >= 3;
    p.atualizado = relogio();
    registrar(p, 'voz', 'amostra removida', String(lista.length) + ' amostra(s)');
    gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }));
    return { ok: true, amostras: lista.length };
  }
  async function removerBiometria(id) {
    var p = obter(id);
    if (!p) return { ok: false, erro: 'Perfil não encontrado.' };
    await garantirBio();
    delete bio[id];
    try { await persistirBio(); } catch (e) { return { ok: false, erro: 'Não foi possível apagar a biometria.' }; }
    p.vozPronta = false; p.amostras = 0; p.rosto = null;
    p.consentimento = p.consentimento || {};
    p.consentimento.voz = { ok: false };
    p.consentimento.rosto = { ok: false };
    p.atualizado = relogio();
    registrar(p, 'biometria', 'voz e referência visual', 'apagadas');
    gravarPerfis(perfis().map(function (x) { return x.id === p.id ? p : x; }));
    return { ok: true };
  }
  function perfisVoz() {
    var saida = [];
    listar().forEach(function (p) {
      var lista = bio[p.id];
      if (!p.consentimento || !p.consentimento.voz || !p.consentimento.voz.ok) return;
      if (!Array.isArray(lista) || !lista.length) return;
      var dim = lista[0].v.length;
      var media = new Array(dim).fill(0);
      lista.forEach(function (a) { a.v.forEach(function (x, i) { media[i] += x / lista.length; }); });
      var melhor = lista.slice().sort(function (a, b) {
        return ((b.qualidade || {}).snrDb || 0) - ((a.qualidade || {}).snrDb || 0);
      })[0] || {};
      saida.push({
        id: p.id, nome: p.nome, apelido: p.apelido || '',
        v: media.map(function (x) { return +x.toFixed(6); }),
        samples: lista.length, qualidade: melhor.qualidade || {}, criado: p.criado
      });
    });
    return saida;
  }
  function avaliarAmostra(analise, cfg) {
    var c = cfg || config();
    var problemas = [];
    var q = analise && analise.qualidade;
    if (!q) return { ok: false, problemas: ['Áudio insuficiente para análise.'] };
    if (!q.ok) problemas = problemas.concat(q.problemas || ['Qualidade insuficiente.']);
    if (Number(q.falaSeg) < c.falaMin) problemas.push('Fale por pelo menos ' + c.falaMin.toFixed(1) + ' s.');
    if (Number(q.snrDb) < c.snrMin) problemas.push('Ruído alto (SNR ' + Number(q.snrDb).toFixed(0) + ' dB); aproxime-se do microfone.');
    if (Number(q.clipping) > 3) problemas.push('Áudio saturado; reduza o volume ou afaste-se.');
    return { ok: problemas.length === 0, problemas: problemas };
  }
  async function identificar(analise) {
    var cfg = config();
    if (!cfg.voz) return { estado: ESTADOS.DESATIVADO, motivos: ['O reconhecimento de voz está desligado nos ajustes.'] };
    await garantirBio();
    var qualidade = avaliarAmostra(analise, cfg);
    if (!qualidade.ok) {
      return { estado: ESTADOS.INCONCLUSIVO, confianca: 0, motivos: qualidade.problemas };
    }
    var lista = perfisVoz();
    if (!lista.length) return { estado: ESTADOS.SEM_PERFIL, motivos: ['Nenhuma pessoa tem perfil de voz autorizado neste aparelho.'] };
    var m = motor;
    if (!m) return { estado: ESTADOS.INCONCLUSIVO, motivos: ['O motor de voz não carregou.'] };
    var r = m.identificar(lista, analise, { limiar: cfg.limiar, margem: cfg.margem });
    var base = {
      similaridade: Number(r.similaridade) || 0,
      confianca: Math.round((Number(r.similaridade) || 0) * 100),
      margem: r.margem == null ? null : r.margem,
      candidatos: (r.candidatos || []).slice(0, 4).map(function (c) {
        return { id: c.id, nome: c.nome, similaridade: +Number(c.sim || 0).toFixed(3) };
      }),
      motivos: r.motivos || []
    };
    if (r.estado === 'compativel') {
      var p = obter(r.id);
      if (!p) return Object.assign({ estado: ESTADOS.NAO_IDENTIFICADO, pessoa: null }, base);
      return Object.assign({ estado: ESTADOS.IDENTIFICADO, pessoa: p }, base);
    }
    if (r.estado === 'diferente') return Object.assign({ estado: ESTADOS.NAO_IDENTIFICADO, pessoa: null }, base);
    return Object.assign({ estado: ESTADOS.INCONCLUSIVO, pessoa: null }, base);
  }

  function distanciaHamming(a, b) {
    if (!/^[0-9a-f]{16}$/.test(a) || !/^[0-9a-f]{16}$/.test(b)) return 64;
    var d = 0;
    for (var i = 0; i < 16; i++) {
      var x = parseInt(a[i], 16) ^ parseInt(b[i], 16);
      d += (x & 1) + ((x >> 1) & 1) + ((x >> 2) & 1) + ((x >> 3) & 1);
    }
    return d;
  }
  function compararRosto(descritor) {
    var cfg = config();
    if (!cfg.rosto) return { estado: ESTADOS.DESATIVADO, provaDeIdentidade: false, motivos: ['A referência visual está desligada nos ajustes.'] };
    if (!descritor || !/^[0-9a-f]{16}$/.test(String(descritor.dhash || ''))) {
      return { estado: ESTADOS.INCONCLUSIVO, provaDeIdentidade: false, motivos: ['Descritor visual inválido.'] };
    }
    var refs = listar().filter(function (p) {
      return p.rosto && p.consentimento && p.consentimento.rosto && p.consentimento.rosto.ok;
    });
    if (!refs.length) return { estado: ESTADOS.SEM_PERFIL, provaDeIdentidade: false, motivos: ['Nenhuma referência visual autorizada.'] };
    var scores = refs.map(function (p) {
      var dist = distanciaHamming(descritor.dhash, p.rosto.dhash);
      return { id: p.id, nome: p.nome, sim: 1 - dist / 64, distancia: dist };
    }).sort(function (a, b) { return b.sim - a.sim; });
    var melhor = scores[0], segundo = scores[1];
    var base = {
      provaDeIdentidade: false,
      aviso: 'Semelhança de imagem, não reconhecimento facial biométrico. Confirme a identidade antes de usar qualquer dado.',
      confianca: Math.round(melhor.sim * 100), candidatos: scores.slice(0, 3)
    };
    if (melhor.sim < cfg.rostoLimiar || (segundo && melhor.sim - segundo.sim < cfg.margem)) {
      return Object.assign({ estado: ESTADOS.INCONCLUSIVO, pessoa: null, motivos: [segundo && melhor.sim - segundo.sim < cfg.margem ? 'Duas referências ficaram próximas.' : 'Semelhança abaixo do limite.'] }, base);
    }
    return Object.assign({ estado: ESTADOS.IDENTIFICADO, pessoa: obter(melhor.id), motivos: [] }, base);
  }

  function historico(id) {
    var p = obter(id);
    return (p && Array.isArray(p.historico)) ? p.historico.slice() : [];
  }

  /* ---------------- exportação e migração ---------------- */
  function exportar(opcoes) {
    var o = opcoes || {};
    var lista = listar().map(function (p) {
      var c = clonar(p);
      if (!o.fotos) c.foto = '';
      if (!o.biometria) { delete c.vozes; delete c.rosto; }
      return c;
    });
    return JSON.stringify({
      formato: 'jarvis-identidade-2', exportado: relogio(),
      incluiBiometria: !!o.biometria, incluiFotos: !!o.fotos, perfis: lista
    }, null, 2);
  }
  function importar(texto) {
    var j = null;
    try { j = JSON.parse(String(texto || '')); } catch (e) { return { ok: false, erro: 'Arquivo não é JSON válido.' }; }
    var perfisEntrada = Array.isArray(j) ? j : (j && Array.isArray(j.perfis) ? j.perfis : null);
    if (!perfisEntrada) return { ok: false, erro: 'Formato sem lista de perfis.' };
    var atuais = perfis();
    var entraram = 0, ignorados = 0;
    perfisEntrada.slice(0, LIMITE_PERFIS).forEach(function (bruto) {
      var novo = preparar(bruto, null);
      novo.id = novoId();
      novo.criado = Number(bruto.criado) || novo.criado;
      novo.historico = [];
      if (!novo.nome) { ignorados++; return; }
      var igual = atuais.filter(function (x) {
        return normalizar(x.nome) === normalizar(novo.nome) &&
          normalizar(x.apelido || '') === normalizar(novo.apelido || '');
      })[0];
      if (igual) { ignorados++; return; }
      atuais.push(novo);
      entraram++;
    });
    if (!gravarPerfis(atuais.slice(0, LIMITE_PERFIS))) return { ok: false, erro: 'Não foi possível gravar os perfis.' };
    return { ok: true, importados: entraram, ignorados: ignorados };
  }
  function migrarDe(listaAntiga) {
    if (!Array.isArray(listaAntiga) || !listaAntiga.length) return { ok: true, migrados: 0 };
    var atuais = perfis();
    var migrados = 0;
    listaAntiga.forEach(function (velho) {
      if (!velho || !velho.nome) return;
      var ja = atuais.filter(function (p) {
        return normalizar(p.nome) === normalizar(velho.nome) &&
          normalizar(p.apelido || '') === normalizar(velho.apelido || '');
      })[0];
      if (ja) return;
      var p = preparar({
        nome: velho.nome, apelido: velho.apelido, relacao: velho.relacao,
        descricao: velho.descricao, preferencias: velho.preferencias,
        observacoes: velho.observacoes
      }, null);
      p.id = typeof velho.id === 'string' && !atuais.some(function (x) { return x.id === velho.id; }) ? velho.id : novoId();
      p.criado = Number(velho.criado) || p.criado;
      p.migrado = true;
      p.historico = [{ em: relogio(), campo: 'origem', de: '', para: 'migrado do cadastro anterior' }];
      atuais.push(p);
      migrados++;
    });
    if (migrados) gravarPerfis(atuais.slice(0, LIMITE_PERFIS));
    return { ok: true, migrados: migrados };
  }
  function limparTudo() {
    bio = Object.create(null);
    bioCarregada = true;
    bioCifrada = true;
    try { gravarCru(CHAVE_BIO, ''); } catch (e) { /* ok */ }
    return gravarCru(CHAVE, '[]');
  }

  function configurar(opcoes) {
    var o = opcoes || {};
    if (o.store) deposito = o.store;
    if (typeof o.relogio === 'function') relogio = o.relogio;
    if (o.motor) motor = o.motor;
    if (o.crypto) webcrypto = o.crypto;
    if (!webcrypto) {
      try { webcrypto = (typeof globalThis !== 'undefined' && globalThis.crypto) ? globalThis.crypto : null; } catch (e) { webcrypto = null; }
    }
    bio = Object.create(null);
    bioCarregada = false;
  }

  var api = {
    CHAVE: CHAVE, CHAVE_BIO: CHAVE_BIO, CHAVE_CFG: CHAVE_CFG,
    LIMITE_PERFIS: LIMITE_PERFIS, LIMITE_AMOSTRAS: LIMITE_AMOSTRAS,
    FOTO_MAX_BYTES: FOTO_MAX_BYTES, CAMPOS: CAMPOS, ROTULO: ROTULO,
    PADRAO: PADRAO, LIMITES: LIMITES, ESTADOS: ESTADOS,
    configurar: configurar, iniciar: iniciar, config: config, salvarConfig: salvarConfig,
    listar: listar, obter: obter, salvar: salvar, remover: remover, buscar: buscar,
    resolver: resolver, descrever: descrever, contexto: contexto, resumo: resumo,
    idade: idade, dataValida: dataValida, consentir: consentir,
    revogarConsentimento: revogarConsentimento,
    definirFoto: definirFoto, removerFoto: removerFoto,
    definirRosto: definirRosto, removerRosto: removerRosto,
    adicionarVoz: adicionarVoz, removerVoz: removerVoz, removerBiometria: removerBiometria,
    perfisVoz: perfisVoz, identificar: identificar, avaliarAmostra: avaliarAmostra,
    compararRosto: compararRosto, historico: historico,
    exportar: exportar, importar: importar, migrarDe: migrarDe, limparTudo: limparTudo,
    perfilVozPronto: function (id) { var p = obter(id); return !!(p && p.vozPronta); },
    biometriaCifrada: function () { return bioCifrada; }
  };
  return api;
});
