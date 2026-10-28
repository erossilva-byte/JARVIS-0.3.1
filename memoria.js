/* J.A.R.V.I.S. Nova — Memória conectada (estilo Obsidian).
 *
 * Um cofre de notas local, organizado por tema, que o assistente usa como memória de
 * conversa: gostos, pesquisas, projetos, contextos, rotinas e mensagens. Cada nota tem
 * título, tema, tags e texto; nada é criado sem o usuário pedir (por voz ou no painel).
 *
 * Segurança e espaço:
 *  - o texto é saneado (sem tags, sem caracteres de controle) e limitado por nota;
 *  - o cofre inteiro tem teto de bytes e de notas, e o painel mostra o consumo;
 *  - apagar exige uma chamada explícita (a interface pede confirmação/PIN antes);
 *  - notas duplicadas (mesmo tema + mesmo título + mesmo texto) são reaproveitadas em
 *    vez de criadas de novo — o mesmo pedido repetido não incha o cofre.
 *
 * Este arquivo não toca no DOM: o painel e a voz ficam em app.js, e o núcleo Hermes só
 * consome contexto()/resumo(). Roda também em Node para os testes.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.MemoriaJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var CHAVE = 'jv_obsidian_vault';
  var TEMAS = [
    { id: 'gostos', nome: 'Gostos', icone: '♥' },
    { id: 'pesquisas', nome: 'Pesquisas', icone: '⌕' },
    { id: 'projetos', nome: 'Projetos', icone: '▤' },
    { id: 'contextos', nome: 'Contextos', icone: '◈' },
    { id: 'rotinas', nome: 'Rotinas', icone: '⚡' },
    { id: 'mensagens', nome: 'Mensagens', icone: '✉' }
  ];
  var LIMITE_BYTES = 512 * 1024;
  var LIMITE_NOTAS = 240;
  var LIMITE_TEXTO = 4000;
  var LIMITE_TITULO = 120;
  var LIMITE_TAGS = 8;

  var memoriaStore = null;
  function storePadrao() {
    try { if (typeof localStorage !== 'undefined') return localStorage; } catch (e) { /* sem localStorage */ }
    return null;
  }
  function lerBruto() {
    var s = memoriaStore || storePadrao();
    if (!s) return '';
    try { return s.getItem(CHAVE) || ''; } catch (e) { return ''; }
  }
  function gravarBruto(txt) {
    var s = memoriaStore || storePadrao();
    if (!s) return false;
    try { s.setItem(CHAVE, txt); return true; } catch (e) { return false; }
  }

  function bytesDe(txt) {
    var t = String(txt == null ? '' : txt);
    try { if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(t).length; } catch (e) { /* fallback */ }
    return unescape(encodeURIComponent(t)).length;
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

  function temaValido(id) {
    return TEMAS.some(function (t) { return t.id === id; }) ? id : 'contextos';
  }
  function temaNome(id) {
    var t = TEMAS.filter(function (x) { return x.id === id; })[0];
    return t ? t.nome : 'Contextos';
  }
  /** Deduz o tema pelas palavras usadas na fala, sem obrigar o usuário a dizer o tema. */
  function temaPorPalavras(txt) {
    var n = normalizar(txt);
    var mapa = [
      ['pesquisas', /(pesquis|estud|artigo|fonte|referenc|aprendi|descobri|compar)/],
      ['projetos', /(projet|repositor|github|codigo|app|site|bug|implement|entrega|prazo do projeto)/],
      ['rotinas', /(rotina|habito|todo dia|todos os dias|acordo|treino|lembrar de fazer)/],
      ['mensagens', /(mensagem|email|e-mail|recado|whatsapp|avisar|conversa com)/],
      ['gostos', /(gosto|prefiro|favorit|odeio|nao gosto|cafe|musica|filme|comida|cor favorita)/],
      ['contextos', /(contexto|sobre mim|meu trabalho|minha casa|familia|importante saber)/]
    ];
    for (var i = 0; i < mapa.length; i++) if (mapa[i][1].test(n)) return mapa[i][0];
    return 'contextos';
  }

  function normalizar(txt) {
    return String(txt == null ? '' : txt).normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function agora() { return Date.now(); }
  function novoId() {
    return 'n' + agora().toString(36) + Math.random().toString(36).slice(2, 7);
  }

  function validaNota(n) {
    return !!(n && typeof n === 'object' && typeof n.id === 'string' && n.id &&
      typeof n.texto === 'string' && n.texto.trim() && typeof n.titulo === 'string' && n.titulo.trim());
  }

  /** Lê o cofre, descartando entradas inválidas e ordenando do mais recente ao mais antigo. */
  function carregar() {
    var bruto = lerBruto();
    if (!bruto) return [];
    var lista;
    try { lista = JSON.parse(bruto); } catch (e) { return []; }
    if (!Array.isArray(lista)) return [];
    return lista.filter(validaNota).slice(0, LIMITE_NOTAS).map(function (n) {
      return {
        id: n.id,
        tema: temaValido(n.tema),
        titulo: limpar(n.titulo, LIMITE_TITULO),
        texto: limpar(n.texto, LIMITE_TEXTO),
        tags: (Array.isArray(n.tags) ? n.tags : []).map(function (t) { return limpar(t, 24); }).filter(Boolean).slice(0, LIMITE_TAGS),
        criado: Number(n.criado) || agora(),
        atualizado: Number(n.atualizado) || Number(n.criado) || agora(),
        origem: n.origem === 'voz' ? 'voz' : 'painel'
      };
    }).filter(validaNota);
  }

  function salvar(lista) {
    var corte = lista.slice(0, LIMITE_NOTAS);
    var txt = JSON.stringify(corte);
    while (bytesDe(txt) > LIMITE_BYTES && corte.length > 1) {
      corte.pop();
      txt = JSON.stringify(corte);
    }
    return gravarBruto(txt);
  }

  function listar(tema) {
    var lista = carregar();
    if (tema) lista = lista.filter(function (n) { return n.tema === temaValido(tema); });
    return lista.sort(function (a, b) { return b.atualizado - a.atualizado; });
  }

  function buscar(q) {
    var alvo = normalizar(q);
    if (!alvo) return listar();
    return listar().filter(function (n) {
      return normalizar(n.titulo + ' ' + n.texto + ' ' + n.tema + ' ' + n.tags.join(' ')).indexOf(alvo) >= 0;
    });
  }

  function criar(dados) {
    var d = dados || {};
    var tema = temaValido(d.tema);
    var texto = limpar(d.texto, LIMITE_TEXTO);
    if (!texto) return { ok: false, erro: 'A nota precisa de algum texto.' };
    var titulo = limpar(d.titulo, LIMITE_TITULO) || texto.split('\n')[0].slice(0, 60);
    var tags = (Array.isArray(d.tags) ? d.tags : String(d.tags || '').split(','))
      .map(function (t) { return limpar(t, 24); }).filter(Boolean).slice(0, LIMITE_TAGS);

    var lista = carregar();
    var assinatura = tema + '|' + normalizar(titulo) + '|' + normalizar(texto);
    for (var i = 0; i < lista.length; i++) {
      var a = lista[i].tema + '|' + normalizar(lista[i].titulo) + '|' + normalizar(lista[i].texto);
      if (a === assinatura) return { ok: true, duplicada: true, nota: lista[i] };
    }
    if (lista.length >= LIMITE_NOTAS) {
      return { ok: false, erro: 'O cofre está cheio (' + LIMITE_NOTAS + ' notas). Apague alguma nota antes de criar outra.' };
    }
    var nota = {
      id: novoId(), tema: tema, titulo: titulo, texto: texto, tags: tags,
      criado: agora(), atualizado: agora(), origem: d.origem === 'voz' ? 'voz' : 'painel'
    };
    lista.unshift(nota);
    if (!salvar(lista)) return { ok: false, erro: 'Não há espaço no armazenamento local para essa nota.' };
    return { ok: true, nota: nota };
  }

  function atualizar(id, campos) {
    var lista = carregar();
    var i = lista.findIndex(function (n) { return n.id === id; });
    if (i < 0) return { ok: false, erro: 'Nota não encontrada.' };
    var c = campos || {};
    if (c.titulo != null) lista[i].titulo = limpar(c.titulo, LIMITE_TITULO) || lista[i].titulo;
    if (c.texto != null) {
      var t = limpar(c.texto, LIMITE_TEXTO);
      if (t) lista[i].texto = t;
    }
    if (c.tema != null) lista[i].tema = temaValido(c.tema);
    if (c.tags != null) lista[i].tags = (Array.isArray(c.tags) ? c.tags : String(c.tags).split(','))
      .map(function (x) { return limpar(x, 24); }).filter(Boolean).slice(0, LIMITE_TAGS);
    lista[i].atualizado = agora();
    if (!salvar(lista)) return { ok: false, erro: 'Não foi possível gravar a alteração.' };
    return { ok: true, nota: lista[i] };
  }

  function apagar(id) {
    var lista = carregar();
    var antes = lista.length;
    lista = lista.filter(function (n) { return n.id !== id; });
    if (lista.length === antes) return { ok: false, erro: 'Nota não encontrada.' };
    if (!salvar(lista)) return { ok: false, erro: 'Não foi possível apagar agora.' };
    return { ok: true, restantes: lista.length };
  }

  function apagarTema(tema) {
    var t = temaValido(tema);
    var lista = carregar();
    var sobrou = lista.filter(function (n) { return n.tema !== t; });
    var removidas = lista.length - sobrou.length;
    if (!removidas) return { ok: true, removidas: 0 };
    if (!salvar(sobrou)) return { ok: false, erro: 'Não foi possível apagar esse tema agora.' };
    return { ok: true, removidas: removidas };
  }

  function apagarTudo() {
    if (!gravarBruto('[]')) return { ok: false, erro: 'Não foi possível limpar o cofre.' };
    return { ok: true };
  }

  /** Consumo real do cofre: notas, bytes, percentual do teto e a maior nota. */
  function espaco() {
    var lista = carregar();
    var bytes = bytesDe(JSON.stringify(lista));
    var maior = lista.reduce(function (m, n) { return Math.max(m, bytesDe(JSON.stringify(n))); }, 0);
    return {
      notas: lista.length,
      bytes: bytes,
      limiteBytes: LIMITE_BYTES,
      limiteNotas: LIMITE_NOTAS,
      percentual: Math.min(100, Math.round((bytes / LIMITE_BYTES) * 100)),
      maior: maior
    };
  }

  /** Remove as notas mais antigas do tema até caber no orçamento pedido. */
  function podar(tema, manterBytes) {
    var t = temaValido(tema);
    var orcamento = Math.max(1024, Number(manterBytes) || Math.round(LIMITE_BYTES * 0.5));
    var lista = carregar();
    var doTema = lista.filter(function (n) { return n.tema === t; })
      .sort(function (a, b) { return a.atualizado - b.atualizado; });
    var usados = bytesDe(JSON.stringify(doTema));
    var removidas = 0;
    while (usados > orcamento && doTema.length > 1) {
      var fora = doTema.shift();
      lista = lista.filter(function (n) { return n.id !== fora.id; });
      usados = bytesDe(JSON.stringify(doTema));
      removidas++;
    }
    if (!removidas) return { ok: true, removidas: 0, mantidas: doTema.length };
    if (!salvar(lista)) return { ok: false, erro: 'Não foi possível liberar espaço agora.' };
    return { ok: true, removidas: removidas, mantidas: doTema.length };
  }

  /** Contexto compacto para o prompt da IA; corta por nota e por total. */
  function contexto(maxChars, tema) {
    var limite = Math.max(200, Number(maxChars) || 1600);
    var lista = listar(tema);
    if (!lista.length) return '';
    var partes = [];
    var usado = 0;
    for (var i = 0; i < lista.length; i++) {
      var n = lista[i];
      var linha = '[' + temaNome(n.tema) + '] ' + n.titulo + ': ' + n.texto.replace(/\s+/g, ' ').slice(0, 280);
      if (usado + linha.length > limite) break;
      partes.push(linha);
      usado += linha.length + 1;
    }
    return partes.join('\n');
  }

  /** Resumo falado do estado do cofre (usado por voz e pelo painel). */
  function resumo() {
    var lista = carregar();
    if (!lista.length) return 'A memória conectada está vazia, senhor. Nada foi anotado ainda.';
    var porTema = {};
    lista.forEach(function (n) { porTema[n.tema] = (porTema[n.tema] || 0) + 1; });
    var partes = TEMAS.filter(function (t) { return porTema[t.id]; })
      .map(function (t) { return porTema[t.id] + ' em ' + t.nome.toLowerCase(); });
    var e = espaco();
    return 'Tenho ' + lista.length + (lista.length === 1 ? ' nota' : ' notas') + ': ' + partes.join(', ') +
      '. Ocupam ' + Math.max(1, Math.round(e.bytes / 1024)) + ' quilobytes, ' + e.percentual + '% do cofre.';
  }

  function exportar() {
    return JSON.stringify({ versao: 1, exportado: new Date().toISOString(), notas: carregar() }, null, 2);
  }

  function importar(txt) {
    var dados;
    try { dados = JSON.parse(String(txt || '')); } catch (e) { return { ok: false, erro: 'Arquivo de memória inválido.' }; }
    var notas = Array.isArray(dados) ? dados : (dados && Array.isArray(dados.notas) ? dados.notas : null);
    if (!notas) return { ok: false, erro: 'Arquivo de memória inválido.' };
    var criadas = 0, repetidas = 0;
    notas.slice(0, LIMITE_NOTAS).forEach(function (n) {
      if (!validaNota(n)) return;
      var r = criar({ tema: n.tema, titulo: n.titulo, texto: n.texto, tags: n.tags, origem: 'painel' });
      if (r.ok && r.duplicada) repetidas++;
      else if (r.ok) criadas++;
    });
    return { ok: true, criadas: criadas, repetidas: repetidas };
  }

  /* ---------- Ponte com o Obsidian ----------
   * O cofre do Obsidian é uma pasta de arquivos .md com frontmatter YAML. Aqui o cofre do
   * aplicativo é convertido PARA esse formato (um arquivo por nota), para o usuário levar a
   * memória a uma pasta de verdade no PC e trazê-la de volta. Regras:
   *  - nada é apagado no Obsidian: a importação só acrescenta;
   *  - o nome do arquivo é estável (título + fim do id), então a mesma nota não vira duas;
   *  - nota repetida cai em `criar()`, que já reaproveita o original em vez de duplicar.
   */
  function escaparYaml(t) {
    return String(t == null ? '' : t).replace(/\r?\n/g, ' ').replace(/"/g, '\\"').slice(0, 200);
  }
  function nomeMd(n) {
    var base = normalizar(n.titulo).replace(/\s+/g, '-').slice(0, 60) || 'nota';
    return n.tema + '/' + base + '-' + String(n.id).slice(-5) + '.md';
  }
  function notaMd(n) {
    return '---\n' +
      'title: "' + escaparYaml(n.titulo) + '"\n' +
      'tema: ' + n.tema + '\n' +
      'tags: [' + (n.tags || []).map(escaparYaml).join(', ') + ']\n' +
      'criado: ' + new Date(n.criado).toISOString() + '\n' +
      'atualizado: ' + new Date(n.atualizado).toISOString() + '\n' +
      'origem: jarvis-nova\n' +
      '---\n\n# ' + n.titulo + '\n\n' + n.texto + '\n';
  }
  function arquivosMarkdown() {
    return carregar().map(function (n) { return { nome: nomeMd(n), texto: notaMd(n) }; });
  }
  function markdown() {
    return arquivosMarkdown().map(function (a) { return a.texto; }).join('\n');
  }
  /** Lê notas vindas do Obsidian (frontmatter opcional). Devolve quantas entraram. */
  function importarMarkdown(txt) {
    var bruto = String(txt || '');
    if (!bruto.trim()) return { ok: false, erro: 'O Markdown está vazio.' };
    var blocos = [];
    var re = /---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*?)(?=\n---\s*\n|$)/g;
    var achado;
    while ((achado = re.exec(bruto))) blocos.push({ meta: achado[1], corpo: achado[2] });
    if (!blocos.length) blocos.push({ meta: '', corpo: bruto });
    var criadas = 0, repetidas = 0, ignoradas = 0;
    blocos.forEach(function (b) {
      var meta = {};
      String(b.meta || '').split('\n').forEach(function (linha) {
        var m = linha.match(/^\s*([A-Za-z_]+)\s*:\s*(.*)$/);
        if (!m) return;
        meta[m[1].toLowerCase()] = m[2].replace(/^["']|[\"']$/g, '').trim();
      });
      var corpo = String(b.corpo || '').replace(/^\s*#\s+.*\n/, '').trim();
      if (!corpo) { ignoradas++; return; }
      var titulo = meta.title || corpo.split('\n')[0].slice(0, 80);
      var tags = (meta.tags || '').replace(/[\[\]]/g, '').split(',')
        .map(function (t) { return t.trim(); }).filter(Boolean);
      var r = criar({
        tema: meta.tema || temaPorPalavras(titulo + ' ' + corpo),
        titulo: titulo, texto: corpo, tags: tags, origem: 'painel'
      });
      if (r.ok && r.duplicada) repetidas++;
      else if (r.ok) criadas++;
      else ignoradas++;
    });
    if (!criadas && !repetidas) return { ok: false, erro: 'Nenhuma nota legível encontrada no Markdown.' };
    return { ok: true, criadas: criadas, repetidas: repetidas, ignoradas: ignoradas };
  }

  return {
    CHAVE: CHAVE,
    TEMAS: TEMAS,
    LIMITE_BYTES: LIMITE_BYTES,
    LIMITE_NOTAS: LIMITE_NOTAS,
    temaValido: temaValido,
    temaNome: temaNome,
    temaPorPalavras: temaPorPalavras,
    usarStore: function (s) { memoriaStore = s || null; },
    carregar: carregar,
    listar: listar,
    buscar: buscar,
    criar: criar,
    atualizar: atualizar,
    apagar: apagar,
    apagarTema: apagarTema,
    apagarTudo: apagarTudo,
    espaco: espaco,
    podar: podar,
    contexto: contexto,
    resumo: resumo,
    exportar: exportar,
    importar: importar,
    arquivosMarkdown: arquivosMarkdown,
    markdown: markdown,
    importarMarkdown: importarMarkdown
  };
});
