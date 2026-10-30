/* J.A.R.V.I.S. Nova — Desenvolvimento de Arquivos.
 *
 * Motor sem DOM, usado pela aba Desenvolvimento e pelos testes em Node.
 * O que é real (e o que não é):
 *  - DOCX, XLSX e ZIP são pacotes ZIP de verdade, com CRC32 e XML OOXML mínimo válido;
 *  - PDF tem objetos, stream de texto e tabela xref calculada byte a byte;
 *  - CSV/JSON/HTML/CSS/JS/Python/Java/Kotlin são texto UTF-8, sem inventar extensão;
 *  - a análise é estática e determinística: aponta o que encontrou, com arquivo e linha;
 *  - nenhuma análise executa o código recebido.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.ArquivosDev = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var LIMITE_TEXTO = 2 * 1024 * 1024;
  var LIMITE_ENTRADAS_ZIP = 400;
  var LIMITE_ENTRADA_ZIP = 4 * 1024 * 1024;

  var FORMATOS = [
    { id: 'txt', rotulo: 'Texto', ext: 'txt', mime: 'text/plain;charset=utf-8' },
    { id: 'md', rotulo: 'Markdown', ext: 'md', mime: 'text/markdown;charset=utf-8' },
    { id: 'json', rotulo: 'JSON', ext: 'json', mime: 'application/json;charset=utf-8' },
    { id: 'csv', rotulo: 'CSV', ext: 'csv', mime: 'text/csv;charset=utf-8' },
    { id: 'html', rotulo: 'HTML', ext: 'html', mime: 'text/html;charset=utf-8' },
    { id: 'css', rotulo: 'CSS', ext: 'css', mime: 'text/css;charset=utf-8' },
    { id: 'js', rotulo: 'JavaScript', ext: 'js', mime: 'text/javascript;charset=utf-8' },
    { id: 'py', rotulo: 'Python', ext: 'py', mime: 'text/x-python;charset=utf-8' },
    { id: 'java', rotulo: 'Java', ext: 'java', mime: 'text/x-java;charset=utf-8' },
    { id: 'kotlin', rotulo: 'Kotlin', ext: 'kt', mime: 'text/x-kotlin;charset=utf-8' },
    { id: 'pdf', rotulo: 'PDF', ext: 'pdf', mime: 'application/pdf' },
    { id: 'docx', rotulo: 'Word (DOCX)', ext: 'docx', mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' },
    { id: 'xlsx', rotulo: 'Planilha (XLSX)', ext: 'xlsx', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' },
    { id: 'zip', rotulo: 'Projeto (ZIP)', ext: 'zip', mime: 'application/zip' }
  ];

  var IDIOMAS = {
    js: 'JavaScript', mjs: 'JavaScript', cjs: 'JavaScript', jsx: 'JavaScript', ts: 'TypeScript', tsx: 'TypeScript',
    html: 'HTML', htm: 'HTML', css: 'CSS', scss: 'CSS', less: 'CSS',
    json: 'JSON', jsonl: 'JSON', xml: 'XML', svg: 'XML', yml: 'YAML', yaml: 'YAML',
    md: 'Markdown', markdown: 'Markdown', txt: 'Texto', log: 'Texto',
    py: 'Python', java: 'Java', kt: 'Kotlin', kts: 'Kotlin', c: 'C', h: 'C', cpp: 'C++',
    cs: 'C#', go: 'Go', rs: 'Rust', rb: 'Ruby', php: 'PHP', sh: 'Shell', bat: 'Batch', ps1: 'PowerShell',
    sql: 'SQL', csv: 'CSV', tsv: 'CSV', gradle: 'Gradle'
  };

  var CODIGO = { js: 1, mjs: 1, cjs: 1, jsx: 1, ts: 1, tsx: 1, css: 1, scss: 1, java: 1, kt: 1, kts: 1, c: 1, h: 1, cpp: 1, cs: 1, go: 1, rs: 1, php: 1 };

  function bytesDeTexto(s) {
    if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(String(s));
    return Uint8Array.from(Buffer.from(String(s), 'utf8'));
  }
  function textoDeBytes(b) {
    if (typeof TextDecoder !== 'undefined') return new TextDecoder('utf-8').decode(b);
    return Buffer.from(b).toString('utf8');
  }
  function u32(n) { return [n >>> 0 & 255, (n >>> 8) & 255, (n >>> 16) & 255, (n >>> 24) & 255]; }
  function u16(n) { return [n & 255, (n >>> 8) & 255]; }

  var TABELA_CRC = (function () {
    var t = new Uint32Array(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      t[i] = c >>> 0;
    }
    return t;
  })();
  function crc32(b) {
    var c = 0xFFFFFFFF;
    for (var i = 0; i < b.length; i++) c = TABELA_CRC[(c ^ b[i]) & 255] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }

  /* Impressão digital para duplicatas e histórico. Não é hash criptográfico:
     serve para comparar arquivos no aparelho, não para assinatura. */
  function impressao(texto) {
    var a = 0x811c9dc5, b = 0x1000193;
    var s = String(texto || '');
    for (var i = 0; i < s.length; i++) {
      var c = s.charCodeAt(i);
      a ^= c; a = (a * 0x01000193) >>> 0;
      b ^= (c + i) & 255; b = (b * 0x85ebca6b) >>> 0;
    }
    return ('00000000' + a.toString(16)).slice(-8) + ('00000000' + b.toString(16)).slice(-8);
  }

  function nomeSeguro(nome, ext) {
    var base = String(nome || 'arquivo').replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-').replace(/\s+/g, ' ').trim();
    if (!base) base = 'arquivo';
    if (base.length > 80) base = base.slice(0, 80);
    var temExt = /\.[a-z0-9]{1,8}$/i.test(base);
    if (ext && !temExt) base += '.' + ext;
    return base;
  }

  function extensao(nome) {
    var m = String(nome || '').toLowerCase().match(/\.([a-z0-9]+)$/);
    return m ? m[1] : '';
  }
  function detectar(nome, texto) {
    var ext = extensao(nome);
    if (IDIOMAS[ext]) return IDIOMAS[ext];
    var t = String(texto || '').trim();
    if (/^[[{]/.test(t)) { try { JSON.parse(t); return 'JSON'; } catch (e) { /* segue */ } }
    if (/^<!doctype html|<html[\s>]/i.test(t)) return 'HTML';
    if (/^<%?|^<\?xml/.test(t)) return 'XML';
    if (/^\s*(def|class)\s+\w+|^\s*import\s+\w+/m.test(t)) return 'Python';
    if (/^\s*(function|const|let|var|import|export)\b/m.test(t)) return 'JavaScript';
    return 'Texto';
  }

  /* ---------------- ZIP ---------------- */
  function zip(entradas) {
    var partes = [], central = [], offset = 0;
    var data = [0, 0, 0, 0]; // 1980-01-01, determinístico para o hash do pacote
    entradas.forEach(function (e) {
      var nome = bytesDeTexto(String(e.nome || 'arquivo.txt').replace(/^\/+/, ''));
      var dados = e.bytes instanceof Uint8Array ? e.bytes : bytesDeTexto(e.texto || '');
      var crc = crc32(dados);
      var local = [].concat([0x50, 0x4b, 0x03, 0x04], u16(20), u16(0x0800), u16(0), u16(0), u16(0),
        u32(crc), u32(dados.length), u32(dados.length), u16(nome.length), u16(0));
      partes.push(Uint8Array.from(local), nome, dados);
      central.push({ nome: nome, crc: crc, tam: dados.length, off: offset });
      offset += local.length + nome.length + dados.length;
    });
    var cdInicio = offset;
    central.forEach(function (c) {
      var h = [].concat([0x50, 0x4b, 0x01, 0x02], u16(20), u16(20), u16(0x0800), u16(0), u16(0), u16(0),
        u32(c.crc), u32(c.tam), u32(c.tam), u16(c.nome.length), u16(0), u16(0), u16(0), u16(0), u32(0), u32(c.off));
      partes.push(Uint8Array.from(h), c.nome);
      offset += h.length + c.nome.length;
    });
    var fim = [].concat([0x50, 0x4b, 0x05, 0x06], u16(0), u16(0), u16(central.length), u16(central.length),
      u32(offset - cdInicio), u32(cdInicio), u16(0));
    partes.push(Uint8Array.from(fim));
    var total = partes.reduce(function (n, p) { return n + p.length; }, 0);
    var saida = new Uint8Array(total), pos = 0;
    partes.forEach(function (p) { saida.set(p, pos); pos += p.length; });
    return saida;
  }

  function acharEOCD(b) {
    for (var i = b.length - 22; i >= Math.max(0, b.length - 65558); i--) {
      if (b[i] === 0x50 && b[i + 1] === 0x4b && b[i + 2] === 0x05 && b[i + 3] === 0x06) return i;
    }
    return -1;
  }

  /* Lê um ZIP real. `inflate` recebe (dadosComprimidos, metodo) e devolve Uint8Array;
     no navegador é montado com DecompressionStream('deflate-raw'), no Node com zlib. */
  async function descompactar(bytes, inflate) {
    var b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    var eocd = acharEOCD(b);
    if (eocd < 0) throw new Error('Isto não é um ZIP válido (assinatura final ausente).');
    var total = b[eocd + 10] | (b[eocd + 11] << 8);
    var cdOff = (b[eocd + 16] | (b[eocd + 17] << 8) | (b[eocd + 18] << 16) | (b[eocd + 19] << 24)) >>> 0;
    var p = cdOff, saida = [];
    for (var n = 0; n < total && n < LIMITE_ENTRADAS_ZIP; n++) {
      if (b[p] !== 0x50 || b[p + 1] !== 0x4b || b[p + 2] !== 0x01 || b[p + 3] !== 0x02) break;
      var metodo = b[p + 10] | (b[p + 11] << 8);
      var comp = (b[p + 20] | (b[p + 21] << 8) | (b[p + 22] << 16) | (b[p + 23] << 24)) >>> 0;
      var tamN = b[p + 28] | (b[p + 29] << 8);
      var extraN = b[p + 30] | (b[p + 31] << 8);
      var comentN = b[p + 32] | (b[p + 33] << 8);
      var offLocal = (b[p + 42] | (b[p + 43] << 8) | (b[p + 44] << 16) | (b[p + 45] << 24)) >>> 0;
      var nome = textoDeBytes(b.slice(p + 46, p + 46 + tamN));
      var lN = b[offLocal + 26] | (b[offLocal + 27] << 8);
      var lE = b[offLocal + 28] | (b[offLocal + 29] << 8);
      var inicio = offLocal + 30 + lN + lE;
      var dados = b.slice(inicio, inicio + comp);
      if (nome.slice(-1) !== '/') {
        if (metodo === 8 && inflate) dados = await inflate(dados, metodo);
        else if (metodo !== 0) throw new Error('O ZIP usa compressão que este aparelho não abriu: ' + nome);
        if (dados.length > LIMITE_ENTRADA_ZIP) throw new Error('Entrada grande demais no ZIP: ' + nome);
        saida.push({ nome: nome, bytes: dados, metodo: metodo });
      }
      p += 46 + tamN + extraN + comentN;
    }
    return saida;
  }

  /* ---------------- Análise ---------------- */
  function ehTexto(nome, texto) {
    var ext = extensao(nome);
    return Boolean(IDIOMAS[ext]) || /\s/.test(String(texto || '').slice(0, 200));
  }

  function linhaDe(texto, indice) {
    return String(texto).slice(0, indice).split('\n').length;
  }

  var REGRAS = [
    { id: 'segredo', gravidade: 'erro', re: /(api[_-]?key|secret|senha|password|token)\s*[:=]\s*['"][^'"\s]{8,}['"]/gi,
      msg: 'Possível segredo escrito no arquivo: tire a chave do código e use variável de ambiente.' },
    { id: 'chave-privada', gravidade: 'erro', re: /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g,
      msg: 'Chave privada dentro do arquivo. Remova e revogue a chave.' },
    { id: 'eval', gravidade: 'aviso', re: /\beval\s*\(/g, msg: 'eval() executa texto como código; evite com entrada de usuário.' },
    { id: 'innerhtml', gravidade: 'aviso', re: /\.innerHTML\s*=/g, msg: 'innerHTML com dado externo abre XSS; prefira textContent.' },
    { id: 'http', gravidade: 'aviso', re: /http:\/\//g, msg: 'URL sem TLS (http://). Prefira https://.' },
    { id: 'conflito', gravidade: 'erro', re: /^(?:<<<<<<<|=======|>>>>>>>)(?: .*)?$/gm, msg: 'Marcador de conflito de merge deixado no arquivo.' },
    { id: 'todo', gravidade: 'info', re: /\b(TODO|FIXME)\b/g, msg: 'Pendência marcada no código.' }
  ];

  function checarJson(nome, texto, problemas) {
    try { JSON.parse(texto); } catch (e) {
      var m = /position (\d+)/.exec(e.message || '');
      problemas.push({ arquivo: nome, linha: m ? linhaDe(texto, Number(m[1])) : 1, gravidade: 'erro', regra: 'json', mensagem: 'JSON inválido: ' + e.message });
    }
  }

  function checarEquilibrio(nome, texto, problemas) {
    var abre = 0, fecha = 0, i, c, estado = 0, aspas = '"';
    for (i = 0; i < texto.length; i++) {
      c = texto[i];
      if (estado === 0) {
        if (c === '/' && texto[i + 1] === '/') { estado = 1; i++; continue; }
        if (c === '/' && texto[i + 1] === '*') { estado = 2; i++; continue; }
        if (c === '"' || c === "'" || c === '`') { estado = 3; aspas = c; continue; }
        if (c === '{' || c === '[' || c === '(') abre++;
        if (c === '}' || c === ']' || c === ')') fecha++;
      } else if (estado === 1) { if (c === '\n') estado = 0; }
      else if (estado === 2) { if (c === '*' && texto[i + 1] === '/') { estado = 0; i++; } }
      else if (estado === 3) { if (c === '\\') { i++; continue; } if (c === aspas) estado = 0; }
    }
    if (abre !== fecha && Math.abs(abre - fecha) > 1) {
      problemas.push({ arquivo: nome, linha: null, gravidade: 'aviso', regra: 'equilibrio',
        mensagem: 'Símbolos desbalanceados: ' + abre + ' aberturas e ' + fecha + ' fechamentos (pode ser só uma string).' });
    }
  }

  function checarImportacoes(nome, texto, nomes, problemas) {
    var ext = extensao(nome), faltando = [];
    var re = ext === 'py' ? /^\s*from\s+\.(\w+)\s+import|^\s*import\s+(\w+)/gm : /(?:from\s+|import\s*\(?\s*)['"](\.[^'"]+)['"]/g;
    var m;
    while ((m = re.exec(texto))) {
      var alvo = (m[1] || m[2] || '').replace(/^\.\//, '').replace(/^\./, '');
      if (!alvo || /^[a-z]+\./.test(alvo)) continue;
      var base = alvo.split('/').pop();
      var variantes = [alvo, alvo + '.js', alvo + '.ts', alvo + '.jsx', alvo + '.py', alvo + '/index.js', base, base + '.js', base + '.ts', base + '.py'];
      if (!variantes.some(function (v) { return nomes[v]; })) faltando.push(alvo);
    }
    faltando.slice(0, 6).forEach(function (f) {
      problemas.push({ arquivo: nome, linha: null, gravidade: 'erro', regra: 'importacao',
        mensagem: 'Importação relativa não encontrada no conjunto: ' + f });
    });
  }

  function analisar(lista) {
    var arquivos = [], problemas = [], nomes = {};
    lista.forEach(function (a) {
      nomes[a.nome] = true;
      nomes[a.nome.split('/').pop()] = true;
    });
    var vistos = {};
    lista.forEach(function (a) {
      var texto = String(a.texto == null ? '' : a.texto);
      var fp = impressao(texto);
      var linhas = texto ? texto.split('\n').length : 0;
      arquivos.push({ nome: a.nome, lingua: detectar(a.nome, texto), bytes: bytesDeTexto(texto).length, linhas: linhas, fp: fp });
      if (vistos[fp]) problemas.push({ arquivo: a.nome, linha: null, gravidade: 'aviso', regra: 'duplicado',
        mensagem: 'Conteúdo idêntico a ' + vistos[fp] + '.' });
      else vistos[fp] = a.nome;
      if (!texto.trim()) {
        problemas.push({ arquivo: a.nome, linha: null, gravidade: 'aviso', regra: 'vazio', mensagem: 'Arquivo vazio.' });
        return;
      }
      if (texto.charCodeAt(0) === 0xFEFF) problemas.push({ arquivo: a.nome, linha: 1, gravidade: 'info', regra: 'bom', mensagem: 'BOM no início do arquivo; remova para evitar caracteres estranhos.' });
      if (/\r\n/.test(texto) && /(^|[^\r])\n/.test(texto)) problemas.push({ arquivo: a.nome, linha: null, gravidade: 'info', regra: 'eol', mensagem: 'Fins de linha misturados (CRLF e LF).' });
      var ext = extensao(a.nome);
      if (ext === 'json' || ext === 'jsonl') checarJson(a.nome, texto, problemas);
      REGRAS.forEach(function (r) {
        var m, achados = 0;
        r.re.lastIndex = 0;
        while ((m = r.re.exec(texto)) && achados < 20) {
          achados++;
          problemas.push({ arquivo: a.nome, linha: linhaDe(texto, m.index), gravidade: r.gravidade, regra: r.id, mensagem: r.msg });
        }
      });
      if (CODIGO[ext]) {
        checarEquilibrio(a.nome, texto, problemas);
        checarImportacoes(a.nome, texto, nomes, problemas);
      }
      if (ext === 'py' && /^\t/m.test(texto) && /^ +/m.test(texto)) {
        problemas.push({ arquivo: a.nome, linha: null, gravidade: 'erro', regra: 'indentacao', mensagem: 'Mistura de tabs e espaços na indentação do Python.' });
      }
      if (ext === 'html' && !/<\/html>/i.test(texto)) {
        problemas.push({ arquivo: a.nome, linha: null, gravidade: 'aviso', regra: 'html', mensagem: 'HTML sem </html>: documento possivelmente incompleto.' });
      }
    });
    var porGravidade = { erro: 0, aviso: 0, info: 0 };
    problemas.forEach(function (p) { porGravidade[p.gravidade] = (porGravidade[p.gravidade] || 0) + 1; });
    return { arquivos: arquivos, problemas: problemas, resumo: { arquivos: lista.length, erros: porGravidade.erro, avisos: porGravidade.aviso, infos: porGravidade.info } };
  }

  /* ---------------- Correções seguras ---------------- */
  function corrigir(texto, acao) {
    var t = String(texto == null ? '' : texto), antes = t;
    if (acao === 'bom') t = t.replace(/^\uFEFF/, '');
    else if (acao === 'eol') t = t.replace(/\r\n?/g, '\n');
    else if (acao === 'espacos') t = t.replace(/[ \t]+$/gm, '').replace(/\n{3,}/g, '\n\n').replace(/\s*$/, '\n');
    else if (acao === 'json') {
      var j;
      try { j = JSON.parse(t); } catch (e) { return { texto: antes, alterado: false, erro: 'JSON inválido: ' + e.message }; }
      t = JSON.stringify(j, null, 2) + '\n';
    } else return { texto: antes, alterado: false, erro: 'Correção desconhecida: ' + acao };
    return { texto: t, alterado: t !== antes };
  }

  /* ---------------- Formatos reais ---------------- */
  function xmlEscape(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function pdf(conteudo) {
    var linhas = [];
    String(conteudo || '').split('\n').forEach(function (linha) {
      var resto = linha;
      while (resto.length > 88) { linhas.push(resto.slice(0, 88)); resto = resto.slice(88); }
      linhas.push(resto);
    });
    if (!linhas.length) linhas = [''];
    var porPagina = 46, paginas = [];
    for (var i = 0; i < linhas.length; i += porPagina) paginas.push(linhas.slice(i, i + porPagina));
    var objetos = [];
    var idsPaginas = paginas.map(function (_, i) { return 4 + i * 2; });
    objetos[1] = '<< /Type /Catalog /Pages 2 0 R >>';
    objetos[2] = '<< /Type /Pages /Kids [' + idsPaginas.map(function (id) { return id + ' 0 R'; }).join(' ') + '] /Count ' + paginas.length + ' >>';
    objetos[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>';
    paginas.forEach(function (linhasPag, i) {
      var idPag = 4 + i * 2, idConteudo = idPag + 1;
      var cmd = 'BT /F1 11 Tf 60 790 Td 14 TL\n';
      linhasPag.forEach(function (l) { cmd += '(' + String(l).replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)') + ') Tj T*\n'; });
      cmd += 'ET';
      objetos[idPag] = '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents ' + idConteudo + ' 0 R >>';
      objetos[idConteudo] = '<< /Length ' + cmd.length + ' >>\nstream\n' + cmd + '\nendstream';
    });
    var partes = ['%PDF-1.4\n%\u00e2\u00e3\u00cf\u00d3\n'], offsets = [0];
    var pos = partes[0].length;
    for (var n = 1; n < objetos.length; n++) {
      offsets[n] = pos;
      var bloco = n + ' 0 obj\n' + objetos[n] + '\nendobj\n';
      partes.push(bloco);
      pos += bloco.length;
    }
    var xref = 'xref\n0 ' + objetos.length + '\n0000000000 65535 f \n';
    for (var k = 1; k < objetos.length; k++) xref += ('0000000000' + offsets[k]).slice(-10) + ' 00000 n \n';
    var trailer = 'trailer\n<< /Size ' + objetos.length + ' /Root 1 0 R >>\nstartxref\n' + pos + '\n%%EOF\n';
    var bruto = partes.join('') + xref + trailer;
    var bytes = new Uint8Array(bruto.length);
    for (var q = 0; q < bruto.length; q++) {
      var cp = bruto.charCodeAt(q);
      bytes[q] = cp <= 255 ? cp : 63;
    }
    return bytes;
  }

  function docx(conteudo) {
    var paras = String(conteudo || '').split('\n').map(function (l) {
      return '<w:p><w:r><w:t xml:space="preserve">' + xmlEscape(l) + '</w:t></w:r></w:p>';
    }).join('');
    return zip([
      { nome: '[Content_Types].xml', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>' },
      { nome: '_rels/.rels', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>' },
      { nome: 'word/document.xml', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + paras + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:body></w:document>' }
    ]);
  }

  function celulasXlsx(conteudo) {
    return String(conteudo || '').split('\n').filter(function (l) { return l.length; }).map(function (l) {
      var sep = l.indexOf(';') >= 0 ? ';' : (l.indexOf('\t') >= 0 ? '\t' : ',');
      return l.split(sep).map(function (c) { return c.trim().replace(/^"|"$/g, ''); });
    });
  }

  function xlsx(conteudo, nomeAba) {
    var linhas = celulasXlsx(conteudo);
    var sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' +
      linhas.map(function (linha, r) {
        return '<row r="' + (r + 1) + '">' + linha.map(function (c, i) {
          var col = String.fromCharCode(65 + (i % 26)) + (i >= 26 ? Math.floor(i / 26) : '') + (r + 1);
          return '<c r="' + col + '" t="inlineStr"><is><t>' + xmlEscape(c) + '</t></is></c>';
        }).join('') + '</row>';
      }).join('') + '</sheetData></worksheet>';
    return zip([
      { nome: '[Content_Types].xml', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>' },
      { nome: '_rels/.rels', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>' },
      { nome: 'xl/workbook.xml', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="' + xmlEscape(nomeAba || 'Planilha') + '" sheetId="1" r:id="rId1"/></sheets></workbook>' },
      { nome: 'xl/_rels/workbook.xml.rels', texto: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>' },
      { nome: 'xl/worksheets/sheet1.xml', texto: sheet }
    ]);
  }

  function csvDeJson(texto) {
    var dados;
    try { dados = JSON.parse(texto); } catch (e) { return null; }
    var lista = Array.isArray(dados) ? dados : [dados];
    if (!lista.length || typeof lista[0] !== 'object') return null;
    var cols = [];
    lista.forEach(function (o) { Object.keys(o || {}).forEach(function (k) { if (cols.indexOf(k) < 0) cols.push(k); }); });
    function cel(v) {
      var s = v == null ? '' : (typeof v === 'object' ? JSON.stringify(v) : String(v));
      return /[",;\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
    }
    return cols.map(cel).join(';') + '\n' + lista.map(function (o) { return cols.map(function (c) { return cel(o[c]); }).join(';'); }).join('\n') + '\n';
  }

  function criar(formato, nome, conteudo, extras) {
    var f = FORMATOS.filter(function (x) { return x.id === formato || x.ext === formato; })[0];
    if (!f) throw new Error('Formato não suportado: ' + formato);
    var texto = String(conteudo == null ? '' : conteudo);
    var nomeFinal = nomeSeguro(nome || ('arquivo.' + f.ext), f.ext);
    var bytes;
    if (f.id === 'pdf') bytes = pdf(texto);
    else if (f.id === 'docx') bytes = docx(texto);
    else if (f.id === 'xlsx') bytes = xlsx(texto, (extras && extras.aba) || 'Planilha');
    else if (f.id === 'zip') {
      var entradas = (extras && extras.entradas) || [{ nome: nomeFinal.replace(/\.zip$/i, '.txt'), texto: texto }];
      bytes = zip(entradas);
    } else if (f.id === 'json') {
      try { JSON.parse(texto); } catch (e) { throw new Error('JSON inválido: ' + e.message); }
      bytes = bytesDeTexto(texto.replace(/\s*$/, '') + '\n');
    } else if (f.id === 'csv' && /^[[{]/.test(texto.trim())) {
      var conv = csvDeJson(texto);
      if (conv) { texto = conv; }
      bytes = bytesDeTexto(texto);
    } else bytes = bytesDeTexto(texto);
    return { nome: nomeFinal, formato: f.id, mime: f.mime, bytes: bytes, texto: (f.id === 'pdf' || f.id === 'docx' || f.id === 'xlsx' || f.id === 'zip') ? '' : texto };
  }

  /* ---------------- Linguagem natural ---------------- */
  function instrucao(texto, arquivos) {
    var t = String(texto || '').toLowerCase();
    var nomes = (arquivos || []).map(function (a) { return a.nome; });
    var alvo = null;
    if (/todos os arquivos|todo o projeto|projeto inteiro/.test(t)) alvo = 'todos';
    else nomes.forEach(function (n) { if (t.indexOf(n.toLowerCase()) >= 0) alvo = n; });
    var formato = null;
    FORMATOS.forEach(function (f) {
      if (t.indexOf(f.id) >= 0 || t.indexOf(f.rotulo.toLowerCase()) >= 0) formato = f.id;
    });
    var nome = null;
    var m = /(?:chamad[oa]|nome(?:e)?|arquivo)\s+["“']?([\w .\-]{1,60})["”']?/.exec(String(texto || ''));
    if (m) nome = m[1].trim();
    var acao = 'analisar';
    if (/\b(crie|criar|gere|gerar|monte|montar)\b/.test(t)) acao = 'criar';
    else if (/\b(corrij\w*|corrig\w*|formate|formatar|arrume|otimiz\w*|limpe)\b/.test(t)) acao = 'corrigir';
    else if (/\b(zip|compacte|compactar|pacote)\b/.test(t)) acao = 'zip';
    else if (/\b(analis|verifique|revise|audite|encontre)\b/.test(t)) acao = 'analisar';
    return { acao: acao, alvo: alvo, formato: formato, nome: nome };
  }

  function formatos() { return FORMATOS.slice(); }
  function mime(nome) {
    var f = FORMATOS.filter(function (x) { return x.ext === extensao(nome); })[0];
    return f ? f.mime : 'application/octet-stream';
  }

  return {
    LIMITE_TEXTO: LIMITE_TEXTO,
    formatos: formatos, mime: mime, detectar: detectar, extensao: extensao,
    impressao: impressao, nomeSeguro: nomeSeguro,
    criar: criar, analisar: analisar, corrigir: corrigir, instrucao: instrucao,
    zip: zip, descompactar: descompactar, bytesDeTexto: bytesDeTexto, textoDeBytes: textoDeBytes,
    csvDeJson: csvDeJson
  };
});
