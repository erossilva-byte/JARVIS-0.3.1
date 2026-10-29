/* J.A.R.V.I.S. Nova — Cadastro de pessoas.
 *
 * Perfis locais, separados por pessoa, para o assistente contextualizar pedidos
 * autorizados ("o que eu anotei sobre a Ana?"). Nada aqui usa biometria, câmera ou
 * reconhecimento de voz para identificar alguém: a identidade é sempre o nome que o
 * usuário digitou. Perfis parecidos não são fundidos — a resolução devolve a lista
 * de candidatos e a interface pergunta qual é.
 *
 * Arquivo sem DOM: roda também em Node (tests/test_pessoas.js). O armazenamento é
 * injetável (localStorage no app, memória nos testes).
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.PessoasJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var CHAVE = 'jv_pessoas';
  var LIMITE_PERFIS = 50;
  var LIMITE_BYTES = 192 * 1024;
  var CAMPOS = {
    nome: 60,
    apelido: 40,
    relacao: 60,
    descricao: 400,
    preferencias: 400,
    observacoes: 800,
    contato: 120
  };
  var rotulo = {
    nome: 'Nome', apelido: 'Apelido', relacao: 'Relação',
    descricao: 'Descrição', preferencias: 'Preferências',
    observacoes: 'Observações', contato: 'Contato autorizado'
  };

  var deposito = null;
  var relogio = function () { return Date.now(); };

  function storePadrao() {
    try { if (typeof localStorage !== 'undefined') return localStorage; } catch (e) { /* sem localStorage */ }
    return null;
  }
  function ler() {
    var s = deposito || storePadrao();
    if (!s) return [];
    var bruto = '';
    try { bruto = s.getItem(CHAVE) || ''; } catch (e) { return []; }
    if (!bruto) return [];
    try {
      var j = JSON.parse(bruto);
      return Array.isArray(j) ? j.filter(function (p) { return p && typeof p.id === 'string'; }) : [];
    } catch (e) { return []; }
  }
  function gravar(lista) {
    var s = deposito || storePadrao();
    if (!s) return false;
    try {
      s.setItem(CHAVE, JSON.stringify(lista));
      return true;
    } catch (e) { return false; }
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
  function novoId() {
    return 'p_' + relogio().toString(36) + '_' + Math.random().toString(36).slice(2, 6);
  }

  /** Valida e limpa um perfil recebido da interface. Nome é o único campo obrigatório. */
  function preparar(dados, atual) {
    var d = dados || {};
    var p = atual ? Object.assign({}, atual) : { id: novoId(), criado: relogio() };
    Object.keys(CAMPOS).forEach(function (campo) {
      if (d[campo] === undefined && atual) return;
      p[campo] = limpar(d[campo], CAMPOS[campo]);
    });
    p.atualizado = relogio();
    return p;
  }

  function validar(p) {
    if (!p.nome) return 'Informe o nome ou uma identificação para a pessoa.';
    return '';
  }

  function listar() {
    return ler().slice().sort(function (a, b) {
      return normalizar(a.nome).localeCompare(normalizar(b.nome), 'pt-BR');
    });
  }

  function obter(id) {
    var achado = ler().filter(function (p) { return p.id === id; })[0];
    return achado || null;
  }

  function salvar(dados) {
    var lista = ler();
    var atual = dados && dados.id ? obter(dados.id) : null;
    var p = preparar(dados, atual);
    var erro = validar(p);
    if (erro) return { ok: false, erro: erro };
    if (!atual && lista.length >= LIMITE_PERFIS) {
      return { ok: false, erro: 'Limite de ' + LIMITE_PERFIS + ' perfis. Apague algum antes de criar outro.' };
    }
    // Perfil novo com o mesmo nome de um existente não é duplicado: é outro perfil
    // (pode haver dois "João"). A interface avisa, mas quem decide é o usuário.
    var proxima = atual
      ? lista.map(function (x) { return x.id === p.id ? p : x; })
      : lista.concat([p]);
    if (bytes(proxima) > LIMITE_BYTES) {
      return { ok: false, erro: 'Os perfis passaram do limite de 192 kB. Reduza observações ou apague um perfil.' };
    }
    if (!gravar(proxima)) return { ok: false, erro: 'Não foi possível gravar no armazenamento deste aparelho.' };
    return { ok: true, perfil: p };
  }

  function remover(id) {
    var lista = ler();
    var proxima = lista.filter(function (p) { return p.id !== id; });
    if (proxima.length === lista.length) return { ok: false, erro: 'Perfil não encontrado.' };
    if (!gravar(proxima)) return { ok: false, erro: 'Não foi possível gravar no armazenamento deste aparelho.' };
    return { ok: true };
  }

  function buscar(termo) {
    var t = normalizar(termo);
    if (!t) return listar();
    return listar().filter(function (p) {
      return normalizar(p.nome).indexOf(t) >= 0 || normalizar(p.apelido).indexOf(t) >= 0;
    });
  }

  /**
   * Resolve um nome dito pelo usuário:
   *  {tipo:'exato'|'unico'|'ambiguo'|'nenhum', perfil?, candidatos[]}
   * Nunca escolhe sozinho quando há mais de um parecido.
   */
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
      return normalizar(p.nome).indexOf(t) >= 0 || normalizar(p.apelido).indexOf(t) >= 0;
    });
    if (parciais.length === 1) return { tipo: 'unico', perfil: parciais[0], candidatos: parciais };
    if (parciais.length > 1) return { tipo: 'ambiguo', candidatos: parciais };
    return { tipo: 'nenhum', candidatos: [] };
  }

  /** Texto curto para a fala: nunca inventa o que não está no perfil. */
  function descrever(p) {
    if (!p) return '';
    var partes = [];
    if (p.apelido) partes.push('também conhecido como ' + p.apelido);
    if (p.relacao) partes.push(p.relacao);
    if (p.descricao) partes.push(p.descricao);
    if (p.preferencias) partes.push('preferências: ' + p.preferencias);
    if (p.observacoes) partes.push('observações: ' + p.observacoes);
    return (p.nome || 'sem nome') + (partes.length ? ' — ' + partes.join('. ') : '. Nenhuma informação além do nome.');
  }

  /** Bloco compacto para o contexto da IA: só nomes/apelidos, sem contatos. */
  function contexto() {
    var lista = listar().slice(0, 12);
    if (!lista.length) return '';
    return lista.map(function (p) {
      return '- ' + p.nome + (p.apelido ? ' (' + p.apelido + ')' : '') +
        (p.relacao ? ' · ' + p.relacao : '') +
        (p.preferencias ? ' · prefere ' + p.preferencias : '');
    }).join('\n');
  }

  function exportar() {
    return JSON.stringify({ formato: 'jarvis-pessoas-1', exportado: relogio(), perfis: listar() }, null, 2);
  }

  function importar(texto) {
    var j = null;
    try { j = JSON.parse(String(texto || '')); } catch (e) { return { ok: false, erro: 'Arquivo não é JSON válido.' }; }
    var perfis = Array.isArray(j) ? j : (j && Array.isArray(j.perfis) ? j.perfis : null);
    if (!perfis) return { ok: false, erro: 'Formato sem lista de perfis.' };
    var atuais = ler();
    var entraram = 0;
    perfis.slice(0, LIMITE_PERFIS).forEach(function (p) {
      var novo = preparar(p, null);
      novo.criado = Number(p.criado) || novo.criado;
      if (!novo.nome) return;
      // Mesmo nome + mesmo apelido: reaproveita em vez de duplicar.
      var igual = atuais.filter(function (x) {
        return normalizar(x.nome) === normalizar(novo.nome) && normalizar(x.apelido) === normalizar(novo.apelido);
      })[0];
      if (igual) return;
      atuais.push(novo);
      entraram++;
    });
    if (!gravar(atuais.slice(0, LIMITE_PERFIS))) return { ok: false, erro: 'Não foi possível gravar os perfis.' };
    return { ok: true, importados: entraram };
  }

  function limparTudo() {
    return gravar([]);
  }

  function configurar(opcoes) {
    var o = opcoes || {};
    if (o.store) deposito = o.store;
    if (typeof o.relogio === 'function') relogio = o.relogio;
  }

  return {
    CHAVE: CHAVE,
    CAMPOS: CAMPOS,
    rotulo: rotulo,
    listar: listar,
    obter: obter,
    salvar: salvar,
    remover: remover,
    buscar: buscar,
    resolver: resolver,
    descrever: descrever,
    contexto: contexto,
    exportar: exportar,
    importar: importar,
    limparTudo: limparTudo,
    configurar: configurar
  };
});
