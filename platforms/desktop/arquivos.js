'use strict';
/* J.A.R.V.I.S. Nova — motor de arquivos do computador (Windows, Linux e macOS).
 *
 * Vive no processo principal do Electron, sem interface: recebe um caminho, devolve
 * dados. Nenhuma função aqui executa shell, abre aplicativo ou escreve fora da pasta
 * autorizada. O renderer nunca escolhe caminho livre — `resolver()` recusa o que sai
 * da pasta do usuário.
 *
 * O que é real e o que não é (importante para não mentir na interface):
 *  - formato identificado por ASSINATURA (bytes), não pela extensão; a extensão só
 *    desempata formatos de texto;
 *  - ZIP/Office/3MF/FCStd são lidos pela tabela central do ZIP (é o que permite dizer
 *    "DOCX com 12 parágrafos" em vez de "arquivo binário");
 *  - PDF: leio o cabeçalho e as páginas de verdade (`/Type /Page`), mas NÃO renderizo
 *    PDF — a interface avisa e oferece abrir no programa do sistema;
 *  - DWG, RVT, RFA e outros binários proprietários são recusados com explicação;
 *  - conversão só existe para os pares implementados (md→html, csv↔json, json→csv,
 *    txt→md, html→txt). O resto é recusado em vez de gerar arquivo quebrado.
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const LIMITE_TEXTO = 2 * 1024 * 1024;      // leitura de texto
const LIMITE_BINARIO = 32 * 1024 * 1024;    // leitura de binário (imagem, zip, cad)
const LIMITE_PREVIA = 120 * 1024;           // pedaço de texto devolvido à interface

const TEXTO_EXT = new Set([
  'txt', 'md', 'markdown', 'log', 'csv', 'tsv', 'json', 'jsonl', 'xml', 'svg', 'yaml', 'yml',
  'ini', 'cfg', 'conf', 'env', 'properties', 'gitignore', 'toml', 'sql', 'tex',
  'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'html', 'htm', 'css', 'scss', 'less',
  'py', 'java', 'kt', 'kts', 'c', 'h', 'cpp', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'swift',
  'sh', 'bat', 'ps1', 'gradle', 'sln', 'csproj', 'vcxproj', 'pro', 'diff', 'patch'
]);

function extensao(nome) {
  const m = String(nome || '').toLowerCase().match(/\.([a-z0-9]+)$/);
  return m ? m[1] : '';
}

function dentro(base, alvo) {
  const rel = path.relative(base, alvo);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

/* ------------------------------- ZIP interno ------------------------------- */
function eocd(buf) {
  const inicio = Math.max(0, buf.length - 66000);
  for (let i = buf.length - 22; i >= inicio; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) {
      return { total: buf.readUInt16LE(i + 10), offset: buf.readUInt32LE(i + 16) };
    }
  }
  return null;
}

function entradasZip(buf) {
  const fim = eocd(buf);
  if (!fim) return [];
  const lista = [];
  let p = fim.offset;
  for (let n = 0; n < fim.total && p + 46 <= buf.length; n++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) break;
    const metodo = buf.readUInt16LE(p + 10);
    const comprimido = buf.readUInt32LE(p + 20);
    const tamanho = buf.readUInt32LE(p + 24);
    const nomeLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const comLen = buf.readUInt16LE(p + 32);
    const local = buf.readUInt32LE(p + 42);
    const nome = buf.toString('utf8', p + 46, p + 46 + nomeLen);
    lista.push({ nome, metodo, comprimido, tamanho, local });
    p += 46 + nomeLen + extraLen + comLen;
    if (lista.length > 4000) break;
  }
  return lista;
}

function conteudoZip(buf, entrada) {
  if (!entrada) return null;
  const nomeLen = buf.readUInt16LE(entrada.local + 26);
  const extraLen = buf.readUInt16LE(entrada.local + 28);
  const inicio = entrada.local + 30 + nomeLen + extraLen;
  const dados = buf.subarray(inicio, inicio + entrada.comprimido);
  if (entrada.metodo === 0) return dados;
  if (entrada.metodo === 8) {
    try { return zlib.inflateRawSync(dados); } catch (_) { return null; }
  }
  return null;
}

function xmlTexto(buf) {
  if (!buf) return '';
  return buf.toString('utf8')
    .replace(/<w:p\b[^>]*>/g, '\n')
    .replace(/<a:p\b[^>]*>/g, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&')
    .replace(/[ \t\u00a0]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/* ------------------------------- Detecção -------------------------------- */
function detectar(buf, nome) {
  const ext = extensao(nome);
  const cabeca = buf && buf.length ? buf.subarray(0, 4096).toString('utf8') : '';
  if (!buf || !buf.length) return { formato: 'vazio', tipo: 'desconhecido', descricao: 'arquivo vazio' };

  if (buf.length > 3 && buf[0] === 0x50 && buf[1] === 0x4b && (buf[2] === 3 || buf[2] === 5)) {
    const entradas = entradasZip(buf);
    const nomes = entradas.map((e) => e.nome.toLowerCase());
    if (nomes.some((n) => n.endsWith('3d/3dmodel.model'))) return { formato: '3mf', tipo: 'cad', descricao: '3MF (modelo de impressão 3D)' };
    if (nomes.some((n) => n.endsWith('word/document.xml'))) return { formato: 'docx', tipo: 'documento', descricao: 'DOCX (Word)' };
    if (nomes.some((n) => n.endsWith('xl/workbook.xml'))) return { formato: 'xlsx', tipo: 'planilha', descricao: 'XLSX (Excel)' };
    if (nomes.some((n) => n.endsWith('ppt/presentation.xml'))) return { formato: 'pptx', tipo: 'apresentacao', descricao: 'PPTX (PowerPoint)' };
    if (nomes.some((n) => n.endsWith('document.xml')) && nomes.some((n) => n.endsWith('guidocument.xml'))) return { formato: 'fcstd', tipo: 'cad', descricao: 'FCStd (FreeCAD)' };
    if (nomes.some((n) => n.endsWith('content.xml'))) return { formato: 'odf', tipo: 'documento', descricao: 'OpenDocument' };
    if (nomes.some((n) => n.endsWith('manifest.json')) && nomes.length <= 2 && !ext) return { formato: 'zip', tipo: 'arquivo', descricao: 'ZIP' };
    return { formato: 'zip', tipo: 'arquivo', descricao: 'ZIP com ' + entradas.length + ' entrada(s)' };
  }
  if (cabeca.startsWith('%PDF-')) return { formato: 'pdf', tipo: 'documento', descricao: 'PDF ' + cabeca.slice(5, 8) };
  if (buf.length > 8 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return { formato: 'png', tipo: 'imagem', descricao: 'PNG' };
  if (buf[0] === 0xff && buf[1] === 0xd8) return { formato: 'jpg', tipo: 'imagem', descricao: 'JPEG' };
  if (cabeca.startsWith('GIF8')) return { formato: 'gif', tipo: 'imagem', descricao: 'GIF' };
  if (cabeca.startsWith('RIFF') && cabeca.slice(8, 12) === 'WEBP') return { formato: 'webp', tipo: 'imagem', descricao: 'WebP' };
  if (cabeca.startsWith('BM')) return { formato: 'bmp', tipo: 'imagem', descricao: 'BMP' };
  if (cabeca.startsWith('AC10')) return { formato: 'dwg', tipo: 'cad', descricao: 'DWG (Autodesk)' };
  if (buf[0] === 0xd0 && buf[1] === 0xcf) return { formato: 'ole', tipo: 'binario', descricao: 'documento composto OLE (RVT/RFA/DOC/XLS antigo)' };
  if (/^ISO-10303-21/.test(cabeca)) {
    if (/FILE_SCHEMA\s*\(\s*\(\s*'IFC/i.test(cabeca)) return { formato: 'ifc', tipo: 'cad', descricao: 'IFC (BIM)' };
    return { formato: 'step', tipo: 'cad', descricao: 'STEP (ISO 10303)' };
  }
  if (/\bSECTION\b/.test(cabeca) && /\bENTITIES\b|\bHEADER\b/.test(buf.toString('utf8'))) {
    if (/AutoCAD Binary DXF/i.test(cabeca)) return { formato: 'dxf-bin', tipo: 'cad', descricao: 'DXF binário' };
    return { formato: 'dxf', tipo: 'cad', descricao: 'DXF (ASCII)' };
  }
  if (buf.length >= 84) {
    const n = buf.readUInt32LE(80);
    if (n > 0 && buf.length === 84 + n * 50) return { formato: 'stl', tipo: 'cad', descricao: 'STL binário' };
  }
  if (/^\s*solid\b/i.test(cabeca) && /facet\s+normal/i.test(buf.toString('utf8', 0, Math.min(buf.length, 8192)))) {
    return { formato: 'stl', tipo: 'cad', descricao: 'STL ASCII' };
  }
  const texto = cabeca.replace(/^\uFEFF/, '').trimStart();
  if (/^[{[]/.test(texto)) {
    try {
      const json = JSON.parse(buf.toString('utf8'));
      if (json && typeof json === 'object' && /cad/i.test(String(json.formato || '')) && Array.isArray(json.objetos)) {
        return { formato: 'cad', tipo: 'cad', descricao: 'CadSimu CAD v' + (json.versao || '?') };
      }
      return { formato: 'json', tipo: 'dados', descricao: 'JSON' };
    } catch (_) {
      return { formato: TEXTO_EXT.has(ext) ? ext : 'json', tipo: 'dados', descricao: 'JSON inválido' };
    }
  }
  if (/^<\?xml|^<svg|^<!doctype html|^<html/i.test(texto)) {
    if (/^<svg/i.test(texto)) return { formato: 'svg', tipo: 'imagem', descricao: 'SVG' };
    return { formato: /^<\?xml/i.test(texto) ? 'xml' : 'html', tipo: 'texto', descricao: /html/i.test(texto.slice(0, 200)) ? 'HTML' : 'XML' };
  }
  if (TEXTO_EXT.has(ext)) {
    const tipo = ['csv', 'tsv'].includes(ext) ? 'planilha' : ['json', 'jsonl', 'yaml', 'yml', 'ini', 'cfg', 'toml'].includes(ext) ? 'dados' : 'texto';
    return { formato: ext, tipo, descricao: ext.toUpperCase() };
  }
  // Sem assinatura reconhecida: só trato como texto se for decodificável e sem bytes de controle.
  const amostra = buf.subarray(0, 4096);
  let controle = 0;
  for (const b of amostra) if (b < 9 || (b > 13 && b < 32)) controle++;
  if (controle / Math.max(1, amostra.length) < 0.02) return { formato: ext || 'txt', tipo: 'texto', descricao: 'texto sem extensão conhecida' };
  return { formato: ext || 'binario', tipo: 'binario', descricao: 'binário não reconhecido' };
}

/* ------------------------------- Leitura --------------------------------- */
function tabelaCsv(texto, limite) {
  const linhas = [];
  const sep = texto.split('\n')[0].includes(';') && !texto.split('\n')[0].includes(',') ? ';' : ',';
  let campo = '';
  let linha = [];
  let dentro = false;
  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];
    if (c === '"') {
      if (dentro && texto[i + 1] === '"') { campo += '"'; i++; }
      else dentro = !dentro;
    } else if (c === sep && !dentro) { linha.push(campo); campo = ''; }
    else if ((c === '\n' || c === '\r') && !dentro) {
      if (c === '\r' && texto[i + 1] === '\n') i++;
      linha.push(campo); campo = '';
      if (linha.length > 1 || linha[0] !== '') linhas.push(linha);
      linha = [];
      if (linhas.length >= limite) break;
    } else campo += c;
  }
  if (campo || linha.length) { linha.push(campo); linhas.push(linha); }
  const largura = linhas.reduce((m, l) => Math.max(m, l.length), 0);
  return { separador: sep, linhas: linhas.map((l) => l.slice(0, 40)), colunas: largura };
}

function paginasPdf(buf) {
  const t = buf.toString('latin1');
  const paginas = (t.match(/\/Type\s*\/Page[^s]/g) || []).length;
  const contagemDeclarada = /\/Count\s+(\d+)/.exec(t);
  const titulo = /\/Title\s*\(([^)]{0,120})\)/.exec(t);
  return {
    paginas,
    paginasDeclaradas: contagemDeclarada ? Number(contagemDeclarada[1]) : null,
    titulo: titulo ? titulo[1] : ''
  };
}

function lerPlanilhaXlsx(buf, entradas) {
  const compartilhadas = entradas.find((e) => e.nome.toLowerCase().endsWith('xl/sharedstrings.xml'));
  const strings = [];
  if (compartilhadas) {
    const xml = xmlTexto(conteudoZip(buf, compartilhadas));
    strings.push(...xml.split('\n').map((s) => s.trim()).filter(Boolean));
  }
  const planilhas = entradas.filter((e) => /^xl\/worksheets\/sheet\d+\.xml$/i.test(e.nome));
  const resumo = planilhas.map((p) => {
    const xml = (conteudoZip(buf, p) || Buffer.from('')).toString('utf8');
    const celulas = (xml.match(/<c\b[^>]*>/g) || []).length;
    return { nome: p.nome.split('/').pop(), celulas };
  });
  const livro = entradas.find((e) => e.nome.toLowerCase() === 'xl/workbook.xml');
  const nomes = livro ? ((conteudoZip(buf, livro) || Buffer.from('')).toString('utf8').match(/<sheet\b[^>]*name="([^"]+)"/g) || [])
    .map((s) => (/name="([^"]+)"/.exec(s) || [])[1]) : [];
  return { planilhas: resumo, nomes: nomes.filter(Boolean), strings: strings.length };
}

function fábrica({ raiz }) {
  if (!raiz) throw new Error('motor de arquivos precisa de uma raiz');

  function resolver(p) {
    const bruto = String(p == null ? '~' : p).trim() || '~';
    const alvo = bruto === '~' ? raiz : path.resolve(raiz, bruto.replace(/^~(?=$|[\/])/, raiz));
    if (!dentro(raiz, alvo)) throw new Error('Caminho fora da pasta do usuário.');
    return alvo;
  }

  function relativo(alvo) {
    const rel = path.relative(raiz, alvo);
    if (rel === '') return '~';
    // O separador vem do próprio Node (barra invertida no Windows, barra no Unix):
    // assim o caminho mostrado na interface é o que o usuário digita de verdade.
    return '~' + path.sep + rel.split(path.sep).join(path.sep);
  }

  function listar(caminho) {
    const alvo = resolver(caminho);
    const st = fs.statSync(alvo);
    if (!st.isDirectory()) throw new Error('Isso não é uma pasta.');
    const itens = fs.readdirSync(alvo, { withFileTypes: true })
      .filter((d) => !d.name.startsWith('.'))
      .map((d) => {
        const completo = path.join(alvo, d.name);
        let info = { nome: d.name, caminho: completo, pasta: d.isDirectory(), bytes: 0, modificado: 0, formato: '', tipo: d.isDirectory() ? 'pasta' : 'arquivo', descricao: d.isDirectory() ? 'pasta' : '' };
        try {
          const s = fs.statSync(completo);
          info.bytes = s.size;
          info.modificado = s.mtimeMs;
          if (!d.isDirectory()) {
            const fd = fs.openSync(completo, 'r');
            const cab = Buffer.alloc(Math.min(4096, s.size));
            if (cab.length) fs.readSync(fd, cab, 0, cab.length, 0);
            fs.closeSync(fd);
            const det = detectar(cab, d.name);
            info.formato = det.formato;
            info.tipo = det.tipo;
            info.descricao = det.descricao;
          }
        } catch (_) { /* item ilegível aparece com tamanho zero */ }
        return info;
      })
      .sort((a, b) => (b.pasta - a.pasta) || a.nome.localeCompare(b.nome))
      .slice(0, 500);
    return { caminho: alvo, relativo: relativo(alvo), pai: alvo === raiz ? '' : relativo(path.dirname(alvo)), itens };
  }

  function ler(caminho) {
    const alvo = resolver(caminho);
    const st = fs.statSync(alvo);
    if (st.isDirectory()) throw new Error('Isso é uma pasta: abra para ver o conteúdo.');
    if (st.size > LIMITE_BINARIO) throw new Error('Arquivo acima do limite de 32 MB para prévia neste painel.');
    const buf = fs.readFileSync(alvo);
    const det = detectar(buf, alvo);
    const base = { caminho: alvo, relativo: relativo(alvo), nome: path.basename(alvo), bytes: buf.length, modificado: st.mtimeMs, formato: det.formato, tipo: det.tipo, descricao: det.descricao };
    const limite = Math.max(1, LIMITE_PREVIA);

    if (det.tipo === 'imagem' && ['png', 'jpg', 'gif', 'webp', 'bmp'].includes(det.formato)) {
      const mime = { png: 'image/png', jpg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', bmp: 'image/bmp' }[det.formato];
      const medidas = det.formato === 'png' && buf.length > 24
        ? { largura: buf.readUInt32BE(16), altura: buf.readUInt32BE(20) } : null;
      return { ...base, imagem: 'data:' + mime + ';base64,' + buf.toString('base64'), medidas,
        resumo: det.descricao + (medidas ? ', ' + medidas.largura + '×' + medidas.altura + ' px' : '') + ', ' + Math.round(buf.length / 1024) + ' kB.' };
    }
    if (det.formato === 'svg') {
      const texto = buf.toString('utf8');
      const vb = /viewBox="([^"]+)"/.exec(texto);
      return { ...base, imagem: 'data:image/svg+xml;base64,' + buf.toString('base64'),
        resumo: 'SVG vetorial' + (vb ? ' (viewBox ' + vb[1] + ')' : '') + ', ' + texto.split('\n').length + ' linha(s).' };
    }
    if (det.formato === 'pdf') {
      const info = paginasPdf(buf);
      return { ...base, meta: info, binario: true,
        resumo: 'PDF ' + buf.toString('latin1', 5, 8) + ' com ' + (info.paginas || info.paginasDeclaradas || 0) + ' página(s)' +
          (info.titulo ? ', título "' + info.titulo + '"' : '') + '. A prévia de páginas não é renderizada aqui — use "Abrir no sistema".' };
    }
    if (det.formato === 'docx') {
      const entradas = entradasZip(buf);
      const doc = entradas.find((e) => e.nome.toLowerCase() === 'word/document.xml');
      const texto = xmlTexto(conteudoZip(buf, doc));
      return { ...base, texto: texto.slice(0, limite), editavel: false,
        resumo: 'DOCX com ' + (texto ? texto.split('\n').filter(Boolean).length + ' parágrafo(s) de texto' : 'documento sem texto legível') + '. Extraio o texto para leitura e resumo; a edição do .docx não é feita aqui.' };
    }
    if (det.formato === 'xlsx') {
      const info = lerPlanilhaXlsx(buf, entradasZip(buf));
      return { ...base, meta: info, editavel: false,
        resumo: 'XLSX com ' + (info.planilhas.length || 0) + ' planilha(s)' + (info.nomes.length ? ' (' + info.nomes.slice(0, 6).join(', ') + ')' : '') + ', ' + info.strings + ' texto(s) compartilhado(s). Leitura apenas.' };
    }
    if (det.formato === 'pptx') {
      const entradas = entradasZip(buf);
      const slides = entradas.filter((e) => /^ppt\/slides\/slide\d+\.xml$/i.test(e.nome));
      return { ...base, meta: { slides: slides.length }, editavel: false, resumo: 'PPTX com ' + slides.length + ' slide(s). Leitura apenas.' };
    }
    if (det.formato === 'fcstd') {
      const entradas = entradasZip(buf);
      return { ...base, meta: { entradas: entradas.length }, editavel: false,
        resumo: 'Documento do FreeCAD (' + entradas.length + ' partes). A árvore paramétrica exige o FreeCAD: não abro nem edito aqui.' };
    }
    if (det.formato === 'zip' || det.formato === 'odf') {
      const entradas = entradasZip(buf);
      const total = entradas.reduce((s, e) => s + e.tamanho, 0);
      return { ...base, meta: { entradas: entradas.slice(0, 200).map((e) => ({ nome: e.nome, bytes: e.tamanho })) },
        resumo: 'ZIP com ' + entradas.length + ' entrada(s), ' + Math.round(total / 1024) + ' kB descomprimidos.' };
    }
    if (det.tipo === 'cad') {
      return { ...base, binario: true, editavel: false,
        resumo: 'Arquivo CAD (' + det.descricao + '): use a aba CAD para identificar, visualizar, criar versão ou exportar.' };
    }
    if (det.tipo === 'binario') {
      return { ...base, binario: true, resumo: det.descricao + '. Não é texto: não exibo nem edito conteúdo binário.' };
    }

    const texto = buf.toString('utf8').replace(/^\uFEFF/, '');
    if (det.formato === 'csv' || det.formato === 'tsv') {
      const t = tabelaCsv(texto, 60);
      return { ...base, texto: texto.slice(0, limite), tabela: t, editavel: true,
        resumo: 'Tabela com ' + t.colunas + ' coluna(s), separador "' + t.separador + '", ' + texto.split('\n').length + ' linha(s).' };
    }
    if (det.formato === 'json' || det.formato === 'jsonl') {
      let info = 'JSON inválido: não consigo interpretar o conteúdo.';
      try {
        const dados = JSON.parse(texto);
        const chaves = Array.isArray(dados) ? ['[array de ' + dados.length + ']'] : Object.keys(dados).slice(0, 20);
        info = (Array.isArray(dados) ? 'Lista com ' + dados.length + ' item(ns)' : 'Objeto com ' + Object.keys(dados).length + ' chave(s)') + ': ' + chaves.join(', ') + '.';
      } catch (e) { info = 'JSON inválido: ' + String(e.message).slice(0, 120); }
      return { ...base, texto: texto.slice(0, limite), editavel: true, resumo: info };
    }
    return { ...base, texto: texto.slice(0, limite), editavel: det.tipo === 'texto' || det.tipo === 'dados',
      truncado: texto.length > limite,
      resumo: det.descricao + ', ' + texto.split('\n').length + ' linha(s)' + (texto.length > limite ? ' — prévia limitada a 120 kB' : '') + '.' };
  }

  function salvar({ caminho, texto, backup = true }) {
    const alvo = resolver(caminho);
    if (fs.existsSync(alvo) && fs.statSync(alvo).isDirectory()) throw new Error('O caminho é uma pasta.');
    const conteudo = String(texto == null ? '' : texto);
    if (Buffer.byteLength(conteudo, 'utf8') > 8 * 1024 * 1024) throw new Error('Conteúdo acima de 8 MB: não salvo pelo painel.');
    fs.mkdirSync(path.dirname(alvo), { recursive: true });
    let copia = '';
    if (fs.existsSync(alvo) && backup) {
      copia = alvo + '.bak-' + new Date().toISOString().replace(/[:.]/g, '-');
      fs.copyFileSync(alvo, copia);
    }
    const tmp = alvo + '.tmp-' + process.pid;
    fs.writeFileSync(tmp, conteudo, 'utf8');
    fs.renameSync(tmp, alvo);              // troca atômica: nunca deixa arquivo pela metade
    return { caminho: alvo, relativo: relativo(alvo), bytes: Buffer.byteLength(conteudo, 'utf8'), backup: copia ? relativo(copia) : '' };
  }

  function comparar(a, b) {
    const pa = resolver(a);
    const pb = resolver(b);
    const la = fs.readFileSync(pa, 'utf8').replace(/\r\n/g, '\n').split('\n');
    const lb = fs.readFileSync(pb, 'utf8').replace(/\r\n/g, '\n').split('\n');
    let ini = 0;
    while (ini < la.length && ini < lb.length && la[ini] === lb[ini]) ini++;
    let fimA = la.length - 1, fimB = lb.length - 1;
    while (fimA >= ini && fimB >= ini && la[fimA] === lb[fimB]) { fimA--; fimB--; }
    const removidas = la.slice(ini, fimA + 1);
    const adicionadas = lb.slice(ini, fimB + 1);
    const blocos = [];
    for (let i = 0; i < removidas.length; i++) blocos.push({ tipo: 'removida', linha: ini + i + 1, texto: removidas[i].slice(0, 300) });
    for (let i = 0; i < adicionadas.length; i++) blocos.push({ tipo: 'adicionada', linha: ini + i + 1, texto: adicionadas[i].slice(0, 300) });
    return {
      a: relativo(pa), b: relativo(pb), iguais: !removidas.length && !adicionadas.length,
      linhasA: la.length, linhasB: lb.length, removidas: removidas.length, adicionadas: adicionadas.length,
      inicioComum: ini, blocos: blocos.slice(0, 400),
      resumo: (!removidas.length && !adicionadas.length)
        ? 'Os dois arquivos são idênticos.'
        : 'Diferença a partir da linha ' + (ini + 1) + ': ' + removidas.length + ' linha(s) só em ' + path.basename(pa) + ' e ' + adicionadas.length + ' só em ' + path.basename(pb) + '.'
    };
  }

  function pesquisar(termo, pasta, opcoes) {
    const o = opcoes || {};
    const busca = String(termo || '').trim();
    if (busca.length < 2) throw new Error('A busca precisa de pelo menos 2 caracteres.');
    const limite = Math.max(1, Math.min(200, Number(o.limite) || 60));
    const raizBusca = resolver(pasta || '~');
    const achados = [];
    const fila = [{ dir: raizBusca, nivel: 0 }];
    let varridos = 0;
    while (fila.length && achados.length < limite && varridos < 4000) {
      const atual = fila.shift();
      let itens = [];
      try { itens = fs.readdirSync(atual.dir, { withFileTypes: true }); } catch (_) { continue; }
      for (const item of itens) {
        if (item.name.startsWith('.') || item.name === 'node_modules') continue;
        const completo = path.join(atual.dir, item.name);
        if (item.isDirectory()) {
          if (atual.nivel < (Number(o.profundidade) || 4)) fila.push({ dir: completo, nivel: atual.nivel + 1 });
          continue;
        }
        varridos++;
        let st;
        try { st = fs.statSync(completo); } catch (_) { continue; }
        if (st.size > LIMITE_TEXTO) continue;
        let texto;
        try { texto = fs.readFileSync(completo, 'utf8'); } catch (_) { continue; }
        if (texto.includes('\u0000')) continue;
        const linhas = texto.split('\n');
        for (let i = 0; i < linhas.length; i++) {
          if (linhas[i].toLowerCase().includes(busca.toLowerCase())) {
            achados.push({ caminho: relativo(completo), linha: i + 1, trecho: linhas[i].trim().slice(0, 200), formato: extensao(completo) });
            if (achados.length >= limite) break;
          }
        }
        if (achados.length >= limite) break;
      }
    }
    return { termo: busca, pasta: relativo(raizBusca), varridos, achados, resumo: achados.length + ' ocorrência(s) em ' + varridos + ' arquivo(s) lido(s).' };
  }

  function converter({ caminho, alvo, sobrescrever = false }) {
    const origem = ler(caminho);
    const destinoFormato = String(alvo || '').toLowerCase().replace(/^\./, '');
    if (!origem.texto && !origem.tabela) throw new Error('Só converto arquivos de texto/tabela; este tipo não tem conversão confiável aqui.');
    const texto = origem.texto || '';
    let saida = '';
    let nome = path.basename(origem.caminho).replace(/\.[^.]+$/, '');
    const pares = origem.formato + '→' + destinoFormato;
    if (pares === 'csv→json') {
      const t = origem.tabela || tabelaCsv(texto, 5000);
      const cab = t.linhas[0] || [];
      const corpo = t.linhas.slice(1).map((l) => {
        const obj = {};
        cab.forEach((c, i) => { obj[c || 'coluna' + (i + 1)] = l[i] == null ? '' : l[i]; });
        return obj;
      });
      saida = JSON.stringify(corpo, null, 2) + '\n';
    } else if (pares === 'json→csv') {
      let dados;
      try { dados = JSON.parse(texto); } catch (e) { throw new Error('JSON inválido: ' + e.message); }
      const linhas = Array.isArray(dados) ? dados : [dados];
      if (!linhas.length || typeof linhas[0] !== 'object') throw new Error('Só converto JSON de objetos ou lista de objetos.');
      const chaves = [...new Set(linhas.flatMap((l) => Object.keys(l || {})))].slice(0, 60);
      const esc = (v) => {
        const s = v == null ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v);
        return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
      };
      saida = [chaves.join(','), ...linhas.map((l) => chaves.map((k) => esc(l[k])).join(','))].join('\n') + '\n';
    } else if (pares === 'md→html') {
      saida = mdParaHtml(texto, nome);
    } else if (pares === 'html→txt' || pares === 'xml→txt') {
      saida = xmlTexto(Buffer.from(texto)) + '\n';
    } else if (/^txt→md$/.test(pares) || /→md$/.test(pares) && origem.tipo === 'texto') {
      saida = '# ' + nome + '\n\n' + texto;
    } else {
      throw new Error('Conversão ' + origem.formato + ' → ' + destinoFormato + ' não implementada. Disponíveis: csv→json, json→csv, md→html, html→txt, txt→md.');
    }
    const ext = destinoFormato === 'txt' ? 'txt' : destinoFormato;
    const destino = resolver(path.join(path.dirname(origem.caminho), nome + '.' + ext));
    if (!sobrescrever && fs.existsSync(destino) && destino !== origem.caminho) {
      throw new Error('Já existe ' + relativo(destino) + '. Confirme a substituição para continuar.');
    }
    const salvo = salvar({ caminho: destino, texto: saida, backup: true });
    return { ...salvo, de: origem.formato, para: destinoFormato, perdas: destinoFormato === 'html' || destinoFormato === 'txt' ? ['formatação do documento original não é reconstruída'] : [] };
  }

  function mdParaHtml(md, titulo) {
    const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const linhas = String(md).split('\n');
    const out = [];
    let lista = false;
    for (const linha of linhas) {
      const item = /^\s*[-*]\s+(.*)$/.exec(linha);
      const tit = /^(#{1,6})\s+(.*)$/.exec(linha);
      if (item) { if (!lista) { out.push('<ul>'); lista = true; } out.push('<li>' + inline(esc(item[1])) + '</li>'); continue; }
      if (lista) { out.push('</ul>'); lista = false; }
      if (tit) { out.push('<h' + tit[1].length + '>' + inline(esc(tit[2])) + '</h' + tit[1].length + '>'); continue; }
      if (!linha.trim()) { out.push(''); continue; }
      out.push('<p>' + inline(esc(linha)) + '</p>');
    }
    if (lista) out.push('</ul>');
    return '<!doctype html>\n<html lang="pt-BR"><head><meta charset="utf-8"><title>' + esc(titulo) +
      '</title><style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem;color:#111}code{background:#f4f4f5;padding:.1em .35em;border-radius:4px}</style></head><body>\n' +
      out.join('\n') + '\n</body></html>\n';
    function inline(s) {
      return s.replace(/`([^`]+)`/g, '<code>$1</code>')
        .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    }
  }

  const PASTAS_PADRAO = {
    imagens: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'],
    documentos: ['pdf', 'docx', 'odt', 'rtf', 'txt', 'md'],
    planilhas: ['xlsx', 'ods', 'csv', 'tsv'],
    cad: ['cad', 'dxf', 'dwg', 'stl', '3mf', 'step', 'stp', 'ifc', 'fcstd', 'obj'],
    codigo: ['js', 'ts', 'py', 'java', 'kt', 'c', 'cpp', 'cs', 'go', 'rs', 'html', 'css', 'json', 'xml', 'yml', 'yaml'],
    compactados: ['zip', '7z', 'rar', 'gz', 'tar'],
    audio: ['mp3', 'wav', 'ogg', 'flac', 'm4a'],
    video: ['mp4', 'mkv', 'avi', 'mov', 'webm']
  };

  /** Plano de organização: nunca move nada aqui; devolve o que FARIA. */
  function organizar({ pasta, regras, aplicar = false }) {
    const base = resolver(pasta || '~/Jarvis');
    if (!fs.existsSync(base) || !fs.statSync(base).isDirectory()) throw new Error('Pasta inexistente: ' + relativo(base));
    const mapa = regras && typeof regras === 'object' ? regras : PASTAS_PADRAO;
    const itens = fs.readdirSync(base, { withFileTypes: true }).filter((d) => d.isFile() && !d.name.startsWith('.'));
    const plano = [];
    for (const item of itens) {
      const ext = extensao(item.name);
      const destino = Object.keys(mapa).find((k) => Array.isArray(mapa[k]) && mapa[k].includes(ext));
      if (!destino) { plano.push({ arquivo: item.name, de: relativo(base), para: '', acao: 'manter' }); continue; }
      plano.push({ arquivo: item.name, de: relativo(path.join(base, item.name)), para: relativo(path.join(base, destino, item.name)), acao: 'mover', pasta: destino });
    }
    const mover = plano.filter((p) => p.acao === 'mover');
    const aviso = {
      plano, mover: mover.length, manter: plano.length - mover.length, aplicado: false,
      resumo: mover.length ? mover.length + ' arquivo(s) seriam movidos para subpastas por tipo; ' + (plano.length - mover.length) + ' ficariam onde estão.' : 'Nada a organizar: nenhum arquivo com tipo reconhecido.'
    };
    if (!aplicar) return aviso;
    if (!mover.length) return { ...aviso, aplicado: true };
    let feitos = 0;
    const erros = [];
    for (const p of mover) {
      const origem = resolver(p.de);
      const destino = resolver(p.para);
      try {
        fs.mkdirSync(path.dirname(destino), { recursive: true });
        if (fs.existsSync(destino)) { erros.push(p.arquivo + ': já existe no destino'); continue; }
        fs.renameSync(origem, destino);
        feitos++;
      } catch (e) { erros.push(p.arquivo + ': ' + e.message); }
    }
    return { ...aviso, aplicado: true, movidos: feitos, erros, resumo: feitos + ' arquivo(s) movidos' + (erros.length ? '; ' + erros.length + ' falha(s)' : '') + '.' };
  }

  function mover({ de, para }) {
    const origem = resolver(de);
    const destino = resolver(para);
    if (!fs.existsSync(origem)) throw new Error('Origem não existe: ' + relativo(origem));
    if (fs.existsSync(destino)) throw new Error('O destino já existe; nada foi sobrescrito.');
    fs.mkdirSync(path.dirname(destino), { recursive: true });
    fs.renameSync(origem, destino);
    return { de: relativo(origem), para: relativo(destino) };
  }

  function criarPasta({ pasta, nome }) {
    const base = resolver(pasta || '~');
    const limpo = String(nome || '').replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-').replace(/^\.+/, '').trim();
    if (!limpo) throw new Error('Informe o nome da pasta.');
    const alvo = path.join(base, limpo.slice(0, 80));
    if (fs.existsSync(alvo)) throw new Error('Já existe ' + relativo(alvo) + '.');
    fs.mkdirSync(alvo);
    return { caminho: relativo(alvo) };
  }

  function apagar(caminho, lixeira) {
    const alvo = resolver(caminho);
    if (alvo === raiz) throw new Error('Não apago a pasta do usuário.');
    if (typeof lixeira === 'function') lixeira(alvo);
    else throw new Error('Exclusão exige a lixeira do sistema; operação cancelada.');
    return { caminho: relativo(alvo) };
  }

  return { raiz, resolver, relativo, listar, ler, salvar, comparar, pesquisar, converter, organizar, mover, criarPasta, apagar, detectar, PASTAS_PADRAO };
}

module.exports = { criarArquivos: fábrica, criar: fábrica, detectar, entradasZip, xmlTexto, tabelaCsv, organizarPadrao: {
  imagens: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'],
  documentos: ['pdf', 'docx', 'odt', 'rtf', 'txt', 'md'],
  planilhas: ['xlsx', 'ods', 'csv', 'tsv'],
  cad: ['cad', 'dxf', 'dwg', 'stl', '3mf', 'step', 'stp', 'ifc', 'fcstd', 'obj'],
  codigo: ['js', 'ts', 'py', 'java', 'kt', 'c', 'cpp', 'cs', 'go', 'rs', 'html', 'css', 'json', 'xml', 'yml', 'yaml'],
  compactados: ['zip', '7z', 'rar', 'gz', 'tar'],
  audio: ['mp3', 'wav', 'ogg', 'flac', 'm4a'],
  video: ['mp4', 'mkv', 'avi', 'mov', 'webm']
} };
