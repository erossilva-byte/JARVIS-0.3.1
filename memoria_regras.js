/* J.A.R.V.I.S. Nova — Regras da memória no PC, iguais às do celular.
 *
 * Este arquivo é o porte para JavaScript de três regras que só existiam no
 * Flutter (`core/memoria_busca.dart`, `core/memoria.dart` e `core/memoria_sync.dart`):
 *
 *  - busca com pontuação e motivo, sem fingir compreensão (embedding lexical
 *    determinístico, sinônimos fechados e corte relativo);
 *  - contexto para a IA com orçamento de caracteres, que nunca manda o cofre
 *    inteiro e devolve quais notas foram usadas (para citar a fonte);
 *  - Markdown de ida e volta no mesmo formato do celular (frontmatter com
 *    `id`, `titulo`, `tema`, `tags`, `importancia`, `criada`, `atualizada`) e o
 *    plano de sincronização com a pasta escolhida, que nunca apaga nada.
 *
 * Sem DOM e sem `fs`: roda no aplicativo (renderer) e em Node nos testes. Quem
 * lê e grava a pasta de verdade é `platforms/desktop/memoria_pasta.js`.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.MemoriaRegras = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var DIMENSOES = 128;
  var LIMITE_MARKDOWN_BYTES = 200 * 1024;

  var SEM_ACENTO = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n'
  };

  var VAZIAS = ('a o as os um uma de da do das dos em no na nos nas por para com que e ou se ' +
    'ao aos ja foi ser sua seu mais como mas nao meu minha ele ela isso este esta').split(' ');

  /* Sinônimos fechados: não é tesauro, só evita que a mesma ideia escrita com
   * outra palavra comum escape da busca. Mesmo mapa do celular. */
  var GRUPOS = {
    programa: 'software', codigo: 'software', aplicativo: 'software', app: 'software',
    casa: 'moradia', residencia: 'moradia', apartamento: 'moradia',
    carro: 'veiculo', automovel: 'veiculo', moto: 'veiculo',
    trabalho: 'servico', emprego: 'servico',
    remedio: 'medicamento', medicamentos: 'medicamento',
    treino: 'exercicio', academia: 'exercicio',
    filho: 'familia', filha: 'familia', esposa: 'familia', marido: 'familia'
  };

  var NOMES_TEMA = {
    contextos: 'Contextos',
    pessoas: 'Pessoas',
    projetos: 'Projetos',
    preferencias: 'Preferências',
    aprendizados: 'Aprendizados',
    rotinas: 'Rotinas',
    gostos: 'Gostos',
    pesquisas: 'Pesquisas',
    objetivos: 'Objetivos',
    estudos: 'Estudos',
    dispositivos: 'Dispositivos',
    mensagens: 'Conversas importantes'
  };

  function temaNome(id) {
    return NOMES_TEMA[id] || 'Contextos';
  }

  function normalizar(texto) {
    var bruto = String(texto == null ? '' : texto).toLowerCase();
    var saida = [];
    for (var i = 0; i < bruto.length; i++) {
      var caractere = bruto.charAt(i);
      var trocado = SEM_ACENTO[caractere] || caractere;
      saida.push(/[a-z0-9]/.test(trocado) ? trocado : ' ');
    }
    return saida.join('').split(/\s+/).filter(function (t) { return t.length > 0; }).join(' ');
  }

  function termosDe(texto) {
    var base = normalizar(texto).split(' ').filter(function (t) {
      return t.length > 2 && VAZIAS.indexOf(t) < 0;
    });
    var vistos = Object.create(null);
    var saida = [];
    base.forEach(function (termo) {
      var canonico = GRUPOS[termo] || termo;
      if (!vistos[canonico]) { vistos[canonico] = true; saida.push(canonico); }
    });
    return saida.sort();
  }

  function fnv1a(texto) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < texto.length; i++) {
      hash ^= texto.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    return hash >>> 0;
  }

  function embedding(texto) {
    var vetor = new Float64Array(DIMENSOES);
    termosDe(texto).forEach(function (termo) {
      vetor[fnv1a(termo) % DIMENSOES] += 1;
      var marcado = '^' + termo + '$';
      for (var i = 0; i + 3 <= marcado.length; i++) {
        vetor[fnv1a(marcado.slice(i, i + 3)) % DIMENSOES] += 0.5;
      }
    });
    var norma = 0;
    for (var j = 0; j < vetor.length; j++) norma += vetor[j] * vetor[j];
    norma = Math.sqrt(norma);
    if (norma > 0) for (var k = 0; k < vetor.length; k++) vetor[k] /= norma;
    return vetor;
  }

  function cosseno(a, b) {
    if (!a || !b || a.length !== b.length) return 0;
    var soma = 0;
    for (var i = 0; i < a.length; i++) soma += a[i] * b[i];
    return Math.max(-1, Math.min(1, soma));
  }

  function quandoDaNota(nota) {
    var valor = nota && (nota.atualizadaEm != null ? nota.atualizadaEm : nota.atualizado);
    if (valor instanceof Date) return valor.getTime();
    var numero = Number(valor);
    if (isFinite(numero) && numero > 0) return numero;
    var lido = Date.parse(String(valor || ''));
    return isFinite(lido) ? lido : Date.now();
  }

  function textoDaNota(nota) {
    return String((nota && nota.texto) || '');
  }

  function tagsDaNota(nota) {
    return Array.isArray(nota && nota.tags) ? nota.tags : [];
  }

  function _literal(nota, termos, encontrados) {
    if (!termos.length) return 0;
    var titulo = normalizar(nota.titulo);
    var tags = normalizar(tagsDaNota(nota).join(' '));
    var corpo = normalizar(textoDaNota(nota));
    var pontos = 0;
    termos.forEach(function (termo) {
      if (titulo.indexOf(termo) >= 0) { pontos += 1; encontrados.titulo = true; }
      else if (tags.indexOf(termo) >= 0) { pontos += 0.6; encontrados.tag = true; }
      else if (corpo.indexOf(termo) >= 0) { pontos += 0.25; encontrados.texto = true; }
    });
    return Math.max(0, Math.min(1, pontos / termos.length));
  }

  function _recencia(atualizada, agora) {
    var dias = (agora - atualizada) / 86400000;
    if (dias <= 0) return 1;
    return Math.max(0, Math.min(1, 1 - dias / 30));
  }

  function _motivo(encontrados, nota, agora, similaridade, aceitaPorSimilaridade) {
    var partes = [];
    if (encontrados.titulo) partes.push('título contém o termo');
    if (encontrados.tag) partes.push('tag correspondente');
    if (encontrados.texto) partes.push('texto contém o termo');
    if (aceitaPorSimilaridade) partes.push('termos parecidos');
    if (Number(nota.importancia) >= 2) partes.push('marcada como importante');
    if (agora - quandoDaNota(nota) <= 3 * 86400000) partes.push('atualizada há pouco');
    if (Number(nota.usos) > 0) partes.push('já usada ' + Number(nota.usos) + 'x');
    return partes.length ? partes.join(' · ') : 'nota recente';
  }

  /** Ordena as notas por relevância, com o motivo explícito de cada resultado. */
  function buscarNotas(notas, consulta, opcoes) {
    var o = opcoes || {};
    var limite = Math.max(1, Math.min(50, Number(o.limite) || 8));
    var agora = o.agora == null ? Date.now() : Number(o.agora);
    var lista = Array.isArray(notas) ? notas : [];
    var termos = termosDe(consulta);
    if (!termos.length) {
      return lista.slice(0, limite).map(function (nota) {
        return { nota: nota, pontuacao: 1, cosseno: 1, motivo: 'lista, sem consulta' };
      });
    }
    var alvo = embedding(consulta);
    var resultados = [];
    lista.forEach(function (nota) {
      var vetor = embedding(nota.titulo + ' ' + tagsDaNota(nota).join(' ') + ' ' + textoDaNota(nota));
      var similaridade = cosseno(alvo, vetor);
      var encontrados = {};
      var literal = _literal(nota, termos, encontrados);
      // Sem nenhuma palavra em comum, só entra quem tem similaridade de fato
      // alta; abaixo disso é colisão do embedding, não relação.
      if (literal === 0 && similaridade < 0.35) return;
      var recente = _recencia(quandoDaNota(nota), agora);
      var uso = Math.max(0, Math.min(1, (Number(nota.usos) || 0) / 10));
      var pontuacao = (0.50 * similaridade) + (0.28 * literal) +
        (0.07 * (Number(nota.importancia) || 0) / 3) + (0.10 * recente) + (0.05 * uso);
      resultados.push({
        nota: nota,
        pontuacao: pontuacao,
        cosseno: similaridade,
        motivo: _motivo(encontrados, nota, agora, similaridade, literal === 0 && similaridade >= 0.35)
      });
    });
    resultados.sort(function (a, b) {
      return b.pontuacao - a.pontuacao || quandoDaNota(b.nota) - quandoDaNota(a.nota);
    });
    if (!resultados.length) return [];
    var melhor = resultados[0].pontuacao;
    return resultados.filter(function (r) {
      return r.pontuacao >= melhor * 0.5 || r.cosseno >= 0.35;
    }).slice(0, limite);
  }

  function trechoDaNota(nota, limite) {
    var limpo = textoDaNota(nota).replace(/\s+/g, ' ').trim();
    var max = Math.max(20, Number(limite) || 120);
    return limpo.length <= max ? limpo : limpo.slice(0, max) + '…';
  }

  /**
   * Monta o bloco de contexto com orçamento de caracteres.
   *
   * Sem resultado relevante devolve vazio: nada de mandar o cofre inteiro nem
   * "notas recentes" que não têm relação com a pergunta.
   */
  function contextoRelevante(notas, consulta, opcoes) {
    var o = opcoes || {};
    var orcamento = Math.max(200, Number(o.orcamento) || 1800);
    var limite = Math.max(1, Math.min(12, Number(o.limite) || 3));
    var lista = Array.isArray(notas) ? notas : [];
    if (!String(consulta == null ? '' : consulta).trim() || !lista.length) {
      return { texto: '', usados: [], caracteres: 0 };
    }
    var achados = buscarNotas(lista, consulta, { limite: limite, agora: o.agora });
    if (!achados.length) return { texto: '', usados: [], caracteres: 0 };
    var partes = [];
    var usados = [];
    var total = 0;
    achados.forEach(function (achado) {
      var nota = achado.nota;
      var tema = temaNome(nota.tema);
      var corpo = textoDaNota(nota).trim().replace(/\n{3,}/g, '\n\n');
      var trecho = corpo.length > 500 ? corpo.slice(0, 500) + '…' : corpo;
      var bloco = '### ' + nota.titulo + ' (' + tema + ')\n' + trecho;
      if (total + bloco.length > orcamento && usados.length) return;
      if (bloco.length > orcamento) {
        partes.push('### ' + nota.titulo + ' (' + tema + ')\n' + trecho.slice(0, Math.max(0, orcamento - 60)) + '…');
        usados.push(nota);
        total = orcamento;
        return;
      }
      partes.push(bloco);
      usados.push(nota);
      total += bloco.length + 2;
    });
    var texto = partes.join('\n\n');
    return { texto: texto, usados: usados, caracteres: texto.length };
  }

  /** Citação pronta para mostrar de onde veio a resposta. */
  function citacoes(usados) {
    return (Array.isArray(usados) ? usados : []).map(function (nota) {
      var referencia = nota.titulo + ' — ' + temaNome(nota.tema);
      return {
        id: nota.id,
        titulo: nota.titulo,
        tema: temaNome(nota.tema),
        caminho: nota.caminho || '',
        referencia: referencia
      };
    });
  }

  function linhaCitacoes(usados) {
    var lista = citacoes(usados);
    if (!lista.length) return '';
    return 'Fonte' + (lista.length === 1 ? '' : 's') + ': ' +
      lista.map(function (c) { return c.referencia + (c.caminho ? ' · ' + c.caminho : ''); }).join('; ');
  }

  /* ---------- Markdown: mesmo formato do celular ---------- */

  function limparValor(valor) {
    return String(valor == null ? '' : valor).replace(/\r?\n/g, ' ').trim();
  }

  /** Lê frontmatter opcional. Só o primeiro bloco conta; `---` no corpo fica. */
  function lerMarkdown(bruto, opcoes) {
    var o = opcoes || {};
    var linhas = String(bruto == null ? '' : bruto).replace(/\r\n/g, '\n').split('\n');
    var extras = {};
    var inicioCorpo = 0;
    if (linhas.length && linhas[0].trim() === '---') {
      var fim = -1;
      for (var i = 1; i < linhas.length; i++) {
        if (linhas[i].trim() === '---') { fim = i; break; }
      }
      if (fim > 0) {
        for (var j = 1; j < fim; j++) {
          var separador = linhas[j].indexOf(':');
          if (separador <= 0) continue;
          var chave = linhas[j].slice(0, separador).trim();
          var valor = linhas[j].slice(separador + 1).trim();
          if (valor.charAt(0) === '[' && valor.charAt(valor.length - 1) === ']') {
            valor = valor.slice(1, -1);
          }
          if (chave) extras[chave] = valor;
        }
        inicioCorpo = fim + 1;
      }
    }
    var corpo = linhas.slice(inicioCorpo).join('\n');
    var titulo = extras.titulo || extras.title || extras.nome || '';
    if (!String(titulo).trim()) {
      var cabecalho = corpo.split('\n').filter(function (linha) {
        return linha.trim().indexOf('# ') === 0;
      })[0] || '';
      if (cabecalho) titulo = cabecalho.trim().slice(2).trim();
    }
    if (!String(titulo).trim()) titulo = o.tituloReserva || 'Sem título';
    return { titulo: String(titulo).trim(), texto: corpo.trim(), extras: extras };
  }

  function escreverMarkdown(nota) {
    function data(valor) {
      var ms = quandoDaNota({ atualizadaEm: valor });
      return new Date(ms).toISOString();
    }
    var id = String(nota.id || '');
    var titulo = limparValor(nota.titulo);
    var tema = String(nota.tema || 'contextos');
    var tags = tagsDaNota(nota);
    var importancia = Math.max(0, Math.min(3, Math.round(Number(nota.importancia) || 0)));
    var conhecidas = { id: 1, titulo: 1, title: 1, nome: 1, tema: 1, tags: 1, importancia: 1, criada: 1, atualizada: 1 };
    var linhas = [
      '---',
      'id: ' + id,
      'titulo: ' + titulo,
      'tema: ' + tema,
      'tags: [' + tags.join(', ') + ']',
      'importancia: ' + importancia,
      'criada: ' + data(nota.criadaEm != null ? nota.criadaEm : nota.criado),
      'atualizada: ' + data(nota.atualizadaEm != null ? nota.atualizadaEm : nota.atualizado)
    ];
    var extras = nota.extras || {};
    Object.keys(extras).forEach(function (chave) {
      if (conhecidas[chave]) return;
      linhas.push(chave + ': ' + limparValor(extras[chave]));
    });
    linhas.push('---');
    return linhas.join('\n') + '\n\n' + String(nota.texto || '').trim() + '\n';
  }

  /** Hash estável de conteúdo: dois FNV-1a de 32 bits, igual ao do celular. */
  function hashConteudo(texto) {
    var a = 0x811c9dc5;
    var b = 0x9e3779b9;
    var entrada = String(texto == null ? '' : texto);
    for (var i = 0; i < entrada.length; i++) {
      var unidade = entrada.charCodeAt(i);
      a = Math.imul(a ^ unidade, 0x01000193) >>> 0;
      b = Math.imul(b ^ ((unidade + 0x9e37) & 0xffff), 0x85ebca6b) >>> 0;
    }
    return ('00000000' + a.toString(16)).slice(-8) + ('00000000' + b.toString(16)).slice(-8);
  }

  function chaveTitulo(titulo) {
    return String(titulo || '').trim().toLowerCase();
  }

  function normalizarCaminho(caminho) {
    return String(caminho == null ? '' : caminho).replace(/\\/g, '/').split('/')
      .filter(function (parte) { return parte.length > 0; }).join('/');
  }

  function nomeSemExtensao(caminho) {
    var nome = normalizarCaminho(caminho).split('/').pop() || '';
    return nome.toLowerCase().slice(-3) === '.md' ? nome.slice(0, -3) : nome;
  }

  /** Nome de arquivo seguro para uma nota nova: sem acento, sem espaço. */
  function caminhoParaTitulo(titulo) {
    var base = normalizar(titulo).replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    return (base || 'nota') + '.md';
  }

  function tagsDeExtras(extras) {
    return String((extras && extras.tags) || '').replace(/[\[\]]/g, '').split(',')
      .map(function (t) { return t.trim(); }).filter(Boolean);
  }

  /** Importação simples de arquivos Markdown (mesmo critério do celular). */
  function importarMarkdowns(arquivos, existentes, opcoes) {
    var o = opcoes || {};
    var quando = o.agora == null ? Date.now() : Number(o.agora);
    var porTitulo = Object.create(null);
    (Array.isArray(existentes) ? existentes : []).forEach(function (nota) {
      var chave = chaveTitulo(nota.titulo);
      if (!porTitulo[chave]) porTitulo[chave] = nota;
    });
    var adicionadas = [];
    var repetidas = 0;
    var conflitos = [];
    var sequencia = 0;
    (Array.isArray(arquivos) ? arquivos : []).forEach(function (arquivo) {
      var lido = lerMarkdown(arquivo.conteudo, {
        tituloReserva: String(arquivo.nome || '').replace(/\.md$/i, '')
      });
      var chave = chaveTitulo(lido.titulo);
      var existente = porTitulo[chave];
      if (existente) {
        if (String(existente.texto || '').trim() === lido.texto.trim()) repetidas++;
        else conflitos.push(lido.titulo);
        return;
      }
      var extras = {};
      Object.keys(lido.extras).forEach(function (k) {
        if (['id', 'titulo', 'title', 'nome', 'tema', 'tags', 'importancia'].indexOf(k) < 0) extras[k] = lido.extras[k];
      });
      var nota = {
        id: 'md-' + String(quando.toString(36)) + '-' + (sequencia++),
        titulo: lido.titulo,
        texto: lido.texto,
        tema: lido.extras.tema || 'contextos',
        tags: tagsDeExtras(lido.extras),
        importancia: Math.max(0, Math.min(3, parseInt(lido.extras.importancia, 10) || 1)),
        criadaEm: quando,
        atualizadaEm: quando,
        usos: 0,
        extras: extras
      };
      adicionadas.push(nota);
      porTitulo[chave] = nota;
    });
    return { adicionadas: adicionadas, repetidas: repetidas, conflitos: conflitos };
  }

  /* ---------- Sincronização com a pasta escolhida ---------- */

  function copiarNota(nota, campos) {
    var saida = {};
    Object.keys(nota).forEach(function (k) { saida[k] = nota[k]; });
    Object.keys(campos || {}).forEach(function (k) { saida[k] = campos[k]; });
    return saida;
  }

  function notaDeRemoto(remoto, agora) {
    var caminho = normalizarCaminho(remoto.caminho);
    var lido = lerMarkdown(remoto.conteudo, { tituloReserva: nomeSemExtensao(caminho) });
    var extras = {};
    Object.keys(lido.extras).forEach(function (k) {
      if (['id', 'titulo', 'title', 'nome', 'tema', 'tags', 'importancia'].indexOf(k) < 0) extras[k] = lido.extras[k];
    });
    return {
      id: 'md-' + hashConteudo(caminho + '|' + hashConteudo(lido.texto.trim())),
      titulo: lido.titulo,
      texto: lido.texto,
      tema: lido.extras.tema || 'contextos',
      tags: tagsDeExtras(lido.extras),
      importancia: Math.max(0, Math.min(3, parseInt(lido.extras.importancia, 10) || 1)),
      criadaEm: agora,
      atualizadaEm: agora,
      usos: 0,
      caminho: caminho,
      hashSincronizado: hashConteudo(lido.texto.trim()),
      extras: extras
    };
  }

  /**
   * Decide o que fazer para conciliar cofre local e pasta, sem apagar nada.
   *
   * Regras (as mesmas do celular):
   *  - conteúdo igual: nada a fazer (no máximo adotar caminho/hash);
   *  - só no local: envia como arquivo novo; se já existe arquivo de mesmo
   *    nome com conteúdo diferente, vira conflito;
   *  - só na pasta: importa como nota nova; se já existe nota local de mesmo
   *    título, conflito;
   *  - nos dois: quem mudou desde o último hash é enviado/recebido; se as duas
   *    mudaram (ou nunca sincronizaram e diferem), conflito, sem sobrescrever;
   *  - nota local cujo arquivo sumiu: registrada como ausente, nada é apagado.
   */
  function planejarSincronizacao(locais, remotos, opcoes) {
    var o = opcoes || {};
    var quando = o.agora == null ? Date.now() : Number(o.agora);
    var plano = {
      envios: [], recebidas: [], marcar: [], conflitos: [],
      ausentesNaPasta: [], caminhosDuplicados: [], iguais: 0
    };
    var porCaminho = Object.create(null);
    (Array.isArray(remotos) ? remotos : []).forEach(function (remoto) {
      var caminho = normalizarCaminho(remoto.caminho);
      if (porCaminho[caminho]) { plano.caminhosDuplicados.push(caminho); return; }
      porCaminho[caminho] = {
        caminho: caminho,
        conteudo: String(remoto.conteudo || ''),
        corpo: lerMarkdown(remoto.conteudo, { tituloReserva: nomeSemExtensao(caminho) }).texto.trim()
      };
    });
    plano.caminhosDuplicados.forEach(function (c) { /* já reportado */ });

    var usados = Object.create(null);
    // O caminho gerado pelo título é sempre minúsculo; a pasta pode ter
    // “Motor.md”. Este índice deixa os dois se encontrarem sem tratar arquivos
    // diferentes como iguais.
    var porCaminhoMinusculo = Object.create(null);
    Object.keys(porCaminho).forEach(function (caminho) {
      var chave = caminho.toLowerCase();
      if (!porCaminhoMinusculo[chave]) porCaminhoMinusculo[chave] = caminho;
    });
    var locaisPorTitulo = Object.create(null);
    (Array.isArray(locais) ? locais : []).forEach(function (nota) {
      var chave = chaveTitulo(nota.titulo);
      if (!locaisPorTitulo[chave]) locaisPorTitulo[chave] = nota;
    });

    (Array.isArray(locais) ? locais : []).forEach(function (nota) {
      var hashLocal = hashConteudo(String(nota.texto || '').trim());
      var caminhoDaNota = nota.caminho ? normalizarCaminho(nota.caminho) : null;

      if (caminhoDaNota) {
        var remoto = porCaminho[caminhoDaNota];
        if (!remoto) {
          plano.ausentesNaPasta.push(nota);
          return;
        }
        usados[caminhoDaNota] = true;
        if (hashLocal === hashConteudo(remoto.corpo)) {
          plano.iguais++;
          if (nota.hashSincronizado !== hashConteudo(remoto.corpo)) plano.marcar.push(nota);
          return;
        }
        var base = nota.hashSincronizado || null;
        if (base && base === hashLocal) {
          var lido = lerMarkdown(remoto.conteudo, { tituloReserva: nomeSemExtensao(caminhoDaNota) });
          plano.recebidas.push({
            caminho: caminhoDaNota,
            nota: copiarNota(nota, {
              titulo: lido.titulo,
              texto: remoto.corpo,
              atualizadaEm: quando,
              caminho: caminhoDaNota,
              hashSincronizado: hashConteudo(remoto.corpo)
            })
          });
          return;
        }
        if (base && base === hashConteudo(remoto.corpo)) {
          plano.envios.push({
            nota: nota, caminho: caminhoDaNota,
            conteudo: escreverMarkdown(nota), novo: false
          });
          return;
        }
        plano.conflitos.push({
          local: nota,
          remoto: remoto,
          motivo: base
            ? 'as duas cópias mudaram desde a última sincronização'
            : 'as cópias nunca foram sincronizadas e o texto é diferente'
        });
        return;
      }

      // Nota local ainda sem caminho: destino pelo título.
      var alvo = caminhoParaTitulo(nota.titulo);
      var encontrado = porCaminho[alvo];
      if (!encontrado) {
        var real = porCaminhoMinusculo[alvo.toLowerCase()];
        if (real) { alvo = real; encontrado = porCaminho[real]; }
      }
      if (encontrado) {
        usados[alvo] = true;
        if (hashConteudo(encontrado.corpo) === hashLocal) {
          plano.iguais++;
          plano.marcar.push(nota);
        } else {
          plano.conflitos.push({
            local: nota, remoto: encontrado,
            motivo: 'já existe arquivo com esse nome e conteúdo diferente'
          });
        }
        return;
      }
      plano.envios.push({
        nota: nota, caminho: alvo,
        conteudo: escreverMarkdown(nota), novo: true
      });
    });

    Object.keys(porCaminho).forEach(function (caminho) {
      if (usados[caminho]) return;
      var remoto = porCaminho[caminho];
      var lido = lerMarkdown(remoto.conteudo, { tituloReserva: nomeSemExtensao(caminho) });
      var mesmoTitulo = locaisPorTitulo[chaveTitulo(lido.titulo)];
      if (mesmoTitulo && !mesmoTitulo.caminho) {
        plano.conflitos.push({
          local: mesmoTitulo,
          remoto: remoto,
          motivo: 'nota local com o mesmo título veio de outro caminho'
        });
        return;
      }
      plano.recebidas.push({ caminho: caminho, nota: notaDeRemoto(remoto, quando) });
    });

    return plano;
  }

  function resumoPlano(plano) {
    if (!plano) return 'nada a sincronizar';
    var partes = [
      plano.envios.length + ' enviada(s)',
      plano.recebidas.length + ' recebida(s)',
      plano.iguais + ' já igual(is)'
    ];
    if (plano.marcar.length) partes.push(plano.marcar.length + ' caminho(s) adotado(s)');
    if (plano.conflitos.length) partes.push(plano.conflitos.length + ' conflito(s) preservado(s)');
    if (plano.ausentesNaPasta.length) partes.push(plano.ausentesNaPasta.length + ' nota(s) só neste PC');
    if (plano.caminhosDuplicados.length) partes.push(plano.caminhosDuplicados.length + ' arquivo(s) repetido(s) na pasta');
    return partes.join(', ');
  }

  return {
    LIMITE_MARKDOWN_BYTES: LIMITE_MARKDOWN_BYTES,
    normalizar: normalizar,
    termosDe: termosDe,
    embedding: embedding,
    cosseno: cosseno,
    temaNome: temaNome,
    buscarNotas: buscarNotas,
    trechoDaNota: trechoDaNota,
    contextoRelevante: contextoRelevante,
    citacoes: citacoes,
    linhaCitacoes: linhaCitacoes,
    lerMarkdown: lerMarkdown,
    escreverMarkdown: escreverMarkdown,
    hashConteudo: hashConteudo,
    chaveTitulo: chaveTitulo,
    caminhoParaTitulo: caminhoParaTitulo,
    normalizarCaminho: normalizarCaminho,
    nomeSemExtensao: nomeSemExtensao,
    importarMarkdowns: importarMarkdowns,
    planejarSincronizacao: planejarSincronizacao,
    resumoPlano: resumoPlano
  };
});
