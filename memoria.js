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
    { id: 'preferencias', nome: 'Preferências', icone: '✧' },
    { id: 'pesquisas', nome: 'Pesquisas', icone: '⌕' },
    { id: 'projetos', nome: 'Projetos', icone: '▤' },
    { id: 'objetivos', nome: 'Objetivos', icone: '◎' },
    { id: 'estudos', nome: 'Estudos', icone: '✎' },
    { id: 'dispositivos', nome: 'Dispositivos', icone: '⌗' },
    { id: 'contextos', nome: 'Contextos', icone: '◈' },
    { id: 'rotinas', nome: 'Rotinas', icone: '⚡' },
    { id: 'mensagens', nome: 'Conversas importantes', icone: '✉' }
  ];
  /* Um arquivo Markdown por tópico dentro do cofre do Obsidian, em `Memoria/`.
   * Nada é apagado: cada gravação reescreve só o arquivo do próprio tópico, e os
   * títulos dentro dele viram seções `##`, que o Obsidian mostra como estrutura. */
  var ARQUIVOS = {
    gostos: 'Memoria/Gostos.md',
    preferencias: 'Memoria/Preferencias.md',
    pesquisas: 'Memoria/Pesquisas.md',
    projetos: 'Memoria/Projetos.md',
    objetivos: 'Memoria/Objetivos.md',
    estudos: 'Memoria/Estudos.md',
    dispositivos: 'Memoria/Dispositivos.md',
    contextos: 'Memoria/Contextos.md',
    rotinas: 'Memoria/Rotinas.md',
    mensagens: 'Memoria/Conversas importantes.md'
  };
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
      ['projetos', /(projet|repositor|github|codigo|app|site|bug|implement|entrega|sprint|backlog)/],
      ['objetivos', /(objetivo|meta|pretendo|quero (?:chegar|concluir|aprender|montar)|plano de|ate o fim do ano)/],
      ['estudos', /(estud|curso|apostila|aula|faculdade|concurso|ler o livro|aprendi|descobri)/],
      ['dispositivos', /(celular|computador|notebook|pc|placa|arduino|impressora|roteador|hd|ssd|configuracao do)/],
      ['rotinas', /(rotina|habito|todo dia|todos os dias|acordo|treino|lembrar de fazer)/],
      ['mensagens', /(mensagem|email|e-mail|recado|whatsapp|avisar|conversa com|ligar para)/],
      ['gostos', /(gosto|odeio|nao gosto|cafe|musica|filme|comida|cor favorita|estilo visual)/],
      ['preferencias', /(preferencia|prefiro (?:que|respost|estilo|tom|seja|usar)|favorit|melhor jeito|gosto de responder|quero que voce|chame|tratamento)/],
      ['pesquisas', /(pesquis|artigo|fonte|referenc|compar|documentacao)/],
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
        meta[m[1].toLowerCase()] = m[2].replace(/^["']|["']$/g, '').trim();
      });
      var corpo = String(b.corpo || '').replace(/^\s*#\s+[^\n]*\n?/, '').trim();
      if (!corpo) { ignoradas++; return; }
      var tags = (meta.tags || '').replace(/[\[\]]/g, '').split(',')
        .map(function (t) { return t.trim(); }).filter(Boolean);
      var temaBase = meta.tema ? temaValido(meta.tema) : '';
      // Arquivo por tópico: `## Título` separa as notas. Sem seções, o arquivo inteiro
      // é uma nota só (notas comuns do Obsidian continuam funcionando).
      // O H1 já foi removido, então a primeira seção pode começar na coluna zero.
      var partes = ('\n' + corpo).split(/\n\s*##\s+/);
      var secoes = [];
      if (partes.length > 1) {
        for (var si = 1; si < partes.length; si++) {
          var linhas = partes[si].split('\n');
          var tituloSecao = String(linhas.shift() || '').trim();
          var textoSecao = linhas.join('\n').replace(/_atualizado:[^\n]*/g, '').trim();
          if (tituloSecao && textoSecao) secoes.push({ titulo: tituloSecao, texto: textoSecao });
        }
      }
      if (!secoes.length) {
        secoes.push({ titulo: meta.title || corpo.split('\n')[0].slice(0, 80), texto: corpo });
      }
      secoes.forEach(function (sec) {
        var tema = temaBase || temaPorPalavras(sec.titulo + ' ' + sec.texto);
        // Mesmo título no mesmo tópico já existe: não duplica nem sobrescreve o que o
        // usuário possa ter editado no Obsidian. Conta como repetida e segue.
        var jaExiste = carregar().some(function (n) {
          return n.tema === tema && normalizar(n.titulo) === normalizar(sec.titulo);
        });
        if (jaExiste) { repetidas++; return; }
        var r = criar({ tema: tema, titulo: sec.titulo, texto: sec.texto, tags: tags, origem: 'painel' });
        if (r.ok && r.duplicada) repetidas++;
        else if (r.ok) criadas++;
        else ignoradas++;
      });
    });
    if (!criadas && !repetidas) return { ok: false, erro: 'Nenhuma nota legível encontrada no Markdown.' };
    return { ok: true, criadas: criadas, repetidas: repetidas, ignoradas: ignoradas };
  }

  /* ---------- Tópicos: um arquivo Markdown por assunto ---------- */
  function arquivoDoTema(tema) {
    return ARQUIVOS[temaValido(tema)] || 'Memoria/Contextos.md';
  }
  /** Notas agrupadas por tópico, no formato que o Obsidian lê (frontmatter + seções). */
  function arquivosPorTopico() {
    var lista = carregar();
    return TEMAS.map(function (t) {
      var doTema = lista.filter(function (n) { return n.tema === t.id; })
        .sort(function (a, b) { return b.atualizado - a.atualizado; });
      if (!doTema.length) return null;
      var atualizado = new Date(doTema[0].atualizado).toISOString();
      var corpo = doTema.map(function (n) {
        return '## ' + n.titulo + '\n\n' +
          '_atualizado: ' + new Date(n.atualizado).toISOString() +
          (n.tags && n.tags.length ? ' · tags: ' + n.tags.join(', ') : '') +
          ' · origem: ' + n.origem + '_\n\n' + n.texto + '\n';
      }).join('\n');
      var texto = '---\n' +
        'title: "' + escaparYaml(t.nome) + '"\n' +
        'tema: ' + t.id + '\n' +
        'atualizado: ' + atualizado + '\n' +
        'notas: ' + doTema.length + '\n' +
        'origem: jarvis-nova\n' +
        '---\n\n# ' + t.nome + '\n\n' + corpo;
      return { nome: ARQUIVOS[t.id], tema: t.id, titulo: t.nome, notas: doTema.length, texto: texto };
    }).filter(Boolean);
  }
  /** Contagem por tópico para o painel (sem carregar texto). */
  function topicos() {
    var lista = carregar();
    return TEMAS.map(function (t) {
      var notas = lista.filter(function (n) { return n.tema === t.id; }).length;
      return { id: t.id, nome: t.nome, arquivo: ARQUIVOS[t.id], notas: notas };
    });
  }

  var PARADAS = ' de da do das dos e ou a o as os um uma para por com que em no na nos nas se ao aos sobre como meu minha seu sua'.split(' ');
  function termos(txt) {
    return normalizar(txt).split(' ').filter(function (t) {
      return t.length > 2 && PARADAS.indexOf(t) < 0;
    }).slice(0, 12);
  }
  /**
   * Contexto para o prompt: só as notas que têm a ver com a pergunta.
   *
   * Antes o app mandava o cofre inteiro (ou as últimas notas). Aqui cada nota é pontuada
   * por sobreposição de termos (título pesa mais que corpo, tag pesa no meio) e pelo tema
   * provável da pergunta. Se nada casar, devolve string vazia — e o prompt diz que não há
   * registro, em vez de inventar lembrança.
   */
  function contextoRelevante(pergunta, maxChars) {
    var limite = Math.max(200, Number(maxChars) || 1600);
    var lista = carregar();
    if (!lista.length) return '';
    var ts = termos(pergunta);
    if (!ts.length) return '';
    var temaProvavel = temaPorPalavras(pergunta);
    var pontuadas = lista.map(function (n) {
      var titulo = normalizar(n.titulo);
      var texto = normalizar(n.texto);
      var tags = normalizar((n.tags || []).join(' '));
      var pontos = 0;
      ts.forEach(function (t) {
        if (titulo.indexOf(t) >= 0) pontos += 4;
        if (tags.indexOf(t) >= 0) pontos += 3;
        if (texto.indexOf(t) >= 0) pontos += 1;
      });
      if (n.tema === temaProvavel) pontos += 2;
      return { nota: n, pontos: pontos };
    }).filter(function (x) { return x.pontos > 0; })
      .sort(function (a, b) { return b.pontos - a.pontos || b.nota.atualizado - a.nota.atualizado; });

    // Pergunta por assunto ("quais são minhas preferências?") raramente repete as palavras
    // da nota. Sem nenhuma pista textual, devolve as notas recentes do tópico da pergunta —
    // e só dele — em vez de mandar o cofre inteiro ou inventar lembrança.
    if (!pontuadas.length) {
      pontuadas = lista.filter(function (n) { return n.tema === temaProvavel; })
        .sort(function (a, b) { return b.atualizado - a.atualizado; })
        .slice(0, 3)
        .map(function (n) { return { nota: n, pontos: 1 }; });
    }

    var partes = [];
    var usado = 0;
    for (var i = 0; i < pontuadas.length; i++) {
      var n = pontuadas[i].nota;
      var linha = '[' + temaNome(n.tema) + '] ' + n.titulo + ': ' +
        n.texto.replace(/\s+/g, ' ').slice(0, 280);
      if (usado + linha.length > limite) break;
      partes.push(linha);
      usado += linha.length + 1;
    }
    return partes.join('\n');
  }
  /** Trechos relevantes para a interface (busca com pontuação, sem prompt). */
  function buscarRelevante(pergunta, limite) {
    var txt = contextoRelevante(pergunta, 4000);
    if (!txt) return [];
    return txt.split('\n').slice(0, Math.max(1, Number(limite) || 5));
  }

  /**
   * Registra uma informação classificando o assunto automaticamente.
   * Se já existir nota com o mesmo título no tópico, acrescenta uma linha datada em vez
   * de criar outra — mantém histórico sem duplicar.
   */
  function anexarAoTopico(texto, dados) {
    var d = dados || {};
    var limpo = limpar(texto, LIMITE_TEXTO);
    if (!limpo) return { ok: false, erro: 'Não há texto para guardar.' };
    var tema = temaValido(d.tema || temaPorPalavras(limpo));
    var titulo = limpar(d.titulo, LIMITE_TITULO) || limpo.split('\n')[0].slice(0, 60);
    var lista = carregar();
    var existente = lista.filter(function (n) {
      return n.tema === tema && normalizar(n.titulo) === normalizar(titulo);
    })[0];
    if (existente) {
      var carimbo = new Date().toLocaleDateString('pt-BR');
      var novo = (existente.texto + '\n\n' + carimbo + ': ' + limpo).slice(0, LIMITE_TEXTO);
      var r = atualizar(existente.id, { texto: novo, tags: d.tags });
      if (!r.ok) return r;
      return { ok: true, atualizada: true, nota: r.nota, tema: tema };
    }
    var c = criar({ tema: tema, titulo: titulo, texto: limpo, tags: d.tags, origem: d.origem });
    if (!c.ok) return c;
    return { ok: true, criada: true, nota: c.nota, tema: tema, duplicada: !!c.duplicada };
  }

  function arquivosDoCofre() {
    return arquivosPorTopico();
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
    arquivosPorTopico: arquivosPorTopico,
    arquivosDoCofre: arquivosDoCofre,
    topicos: topicos,
    arquivoDoTema: arquivoDoTema,
    contextoRelevante: contextoRelevante,
    buscarRelevante: buscarRelevante,
    anexarAoTopico: anexarAoTopico,
    ARQUIVOS: ARQUIVOS,
    markdown: markdown,
    importarMarkdown: importarMarkdown
  };
});
