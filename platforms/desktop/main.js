const { app, BrowserWindow, ipcMain, shell, clipboard, safeStorage, desktopCapturer, dialog } = require('electron');
const { spawn, spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
// Motores da camada PC. São Node puro (sem Electron) para poderem ser testados fora da
// janela: `node tests/test_pc_arquivos.js` roda os mesmos arquivos que o app usa.
const ARQ = require('./arquivos.js');
const CADPC = require('./cad_pc.js');
// Este arquivo vive em platforms/desktop; o núcleo web compartilhado fica na raiz do projeto.
// Nada de caminho relativo solto: com dois níveis fixos, o pacote empacotado e o modo dev
// resolvem para os mesmos arquivos.
const RAIZ = path.resolve(__dirname, '..', '..');
const APPS = require(path.join(RAIZ, 'apps.js'));

const plat = process.platform; // win32 | darwin | linux
const chave = plat === 'win32' ? 'win' : plat === 'darwin' ? 'mac' : 'linux';

function criarJanela() {
  const win = new BrowserWindow({
    width: 1280, height: 860, minWidth: 460, minHeight: 620,
    backgroundColor: '#04070d', title: 'J.A.R.V.I.S.', autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true, nodeIntegration: false, sandbox: true
    }
  });
  win.loadFile(path.join(RAIZ, 'index.html'));
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  win.webContents.session.setPermissionRequestHandler((_wc, perm, cb) =>
    cb(['media', 'geolocation', 'display-capture'].includes(perm)));
}

function rodar(cmd, args) {
  const p = spawn(cmd, args, { detached: true, stdio: 'ignore' });
  p.on('error', () => {});
  p.unref();
}

const numeroOk = (n) => /^\+?\d{8,15}$/.test(String(n || ''));

// Cofre de chaves do desktop: cifra com a proteção de credenciais fornecida pelo SO.
// Se o Electron/OS não oferecer safeStorage, falha fechado em vez de gravar em texto puro.
const arquivoCofre = () => path.join(app.getPath('userData'), 'jarvis-secrets.json');
function lerCofreDesktop() {
  const arquivo = arquivoCofre();
  if (!fs.existsSync(arquivo)) return {};
  try {
    const bruto = JSON.parse(fs.readFileSync(arquivo, 'utf8'));
    if (!bruto || typeof bruto !== 'object' || Array.isArray(bruto)) return {};
    return bruto;
  } catch (_) { throw new Error('O cofre local está ilegível. Nenhuma chave foi substituída.'); }
}
function gravarCofreDesktop(dados) {
  const arquivo = arquivoCofre();
  const temporario = arquivo + '.tmp';
  fs.mkdirSync(path.dirname(arquivo), { recursive: true });
  fs.writeFileSync(temporario, JSON.stringify(dados), { mode: 0o600 });
  fs.renameSync(temporario, arquivo);
}
function exigirCofreDesktop() {
  if (!safeStorage || typeof safeStorage.isEncryptionAvailable !== 'function' || !safeStorage.isEncryptionAvailable()) {
    throw new Error('O armazenamento criptografado do sistema não está disponível; a chave não foi salva.');
  }
}
function guardarChaveDesktop({ nome, valor }) {
  exigirCofreDesktop();
  if (!/^(groq|cerebras|mistral|gemini)$/.test(String(nome || ''))) throw new Error('Nome de chave inválido.');
  const dados = lerCofreDesktop();
  if (!valor) delete dados[nome];
  else dados[nome] = safeStorage.encryptString(String(valor)).toString('base64');
  gravarCofreDesktop(dados);
  return true;
}
function lerChaveDesktop({ nome }) {
  exigirCofreDesktop();
  if (!/^(groq|cerebras|mistral|gemini)$/.test(String(nome || ''))) throw new Error('Nome de chave inválido.');
  const cifrado = lerCofreDesktop()[nome];
  if (!cifrado) return '';
  return safeStorage.decryptString(Buffer.from(String(cifrado), 'base64'));
}

// Só estas ações existem. O renderer NUNCA envia comandos de shell.
const acoes = {
  abrir_app: async ({ app: chaveApp }) => {
    const entrada = APPS[chaveApp];
    const alvo = entrada && entrada[chave];
    if (!alvo) throw new Error('App não cadastrado neste sistema');
    if (/^[a-z][a-z0-9+.-]+:/i.test(alvo)) return shell.openExternal(alvo);
    rodar(alvo, []);
  },
  ligar: async ({ numero }) => {
    if (!numeroOk(numero)) throw new Error('Número inválido');
    return shell.openExternal('tel:' + numero);
  },
  whatsapp: async ({ numero, texto }) => {
    if (!numeroOk(numero)) throw new Error('Número inválido');
    const t = String(texto || '').slice(0, 1000);
    return shell.openExternal(`https://wa.me/${numero.replace('+', '')}?text=${encodeURIComponent(t)}`);
  },
  bloquear_tela: async () => {
    if (plat === 'win32') rodar('rundll32.exe', ['user32.dll,LockWorkStation']);
    else if (plat === 'darwin') rodar('pmset', ['displaysleepnow']);
    else rodar('loginctl', ['lock-session']);
  },
  desligar_pc: async () => {
    if (plat === 'win32') rodar('shutdown', ['/s', '/t', '30']);
    else rodar('shutdown', ['-h', '+1']);
  },
  cancelar_desligamento: async () => {
    if (plat === 'win32') rodar('shutdown', ['/a']);
    else rodar('shutdown', ['-c']);
  },
  ler_area_transferencia: async () => clipboard.readText().slice(0, 4000),
  copiar_texto: async ({ texto }) => clipboard.writeText(String(texto || '').slice(0, 10000)),
  guardar_chave_segura: async (dados) => guardarChaveDesktop(dados || {}),
  ler_chave_segura: async (dados) => ({ valor: lerChaveDesktop(dados || {}) })
};


// ---------- Computador: arquivos e estado, com limites explícitos ----------
// O renderer também NÃO escolhe caminho arbitrário: tudo é resolvido dentro da pasta do
// usuário (app.getPath('home')). Fora dela, a ação falha. Nada aqui executa shell livre.
function dentroDaCasa(p) {
  const casa = app.getPath('home');
  const bruto = String(p == null ? '~' : p).trim() || '~';
  const alvo = bruto === '~' ? casa : path.resolve(casa, bruto.replace(/^~(?=$|[\\/])/, casa));
  const rel = path.relative(casa, alvo);
  if (rel.startsWith('..') || path.isAbsolute(rel)) throw new Error('Caminho fora da pasta do usuário.');
  return alvo;
}
function nomeSeguro(nome) {
  const limpo = String(nome || 'nota.txt').replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-').trim().slice(0, 120);
  return limpo || 'nota.txt';
}
function gb(n) { return Math.round((Number(n) || 0) / 1024 / 1024 / 1024 * 10) / 10; }

const acoesPC = {
  status_pc: async () => {
    const cpus = os.cpus() || [];
    let idle = 0, total = 0;
    cpus.forEach((c) => {
      const t = c.times || {};
      idle += Number(t.idle) || 0;
      total += (Number(t.user) || 0) + (Number(t.nice) || 0) + (Number(t.sys) || 0) + (Number(t.idle) || 0) + (Number(t.irq) || 0);
    });
    let discoLivre = 0, discoTotal = 0;
    try {
      const st = fs.statfsSync(app.getPath('home'));
      discoLivre = st.bavail * st.bsize;
      discoTotal = st.blocks * st.bsize;
    } catch (e) { /* sistema sem statfs */ }
    const horas = Math.floor(os.uptime() / 3600);
    return {
      cpu: total ? Math.max(0, Math.min(100, Math.round(100 - (idle / total) * 100))) : 0,
      ramLivre: os.freemem(),
      ramTotal: os.totalmem(),
      discoLivre: discoLivre,
      discoTotal: discoTotal,
      aparelho: os.type() + ' ' + os.release() + ' · ' + os.arch(),
      uptime: horas >= 24 ? Math.floor(horas / 24) + ' dia(s) e ' + (horas % 24) + ' h' : horas + ' h',
      carregado: Date.now()
    };
  },
  /* Ações antigas do painel: continuam existindo para não quebrar chamadas, mas agora
   * delegam ao motor de arquivos. Antes elas cortavam texto em 200 kB sem avisar —
   * isso era perda silenciosa de dados. */
  listar_arquivos: async ({ caminho }) => {
    const r = PC_ARQ().listar(caminho);
    return { caminho: r.caminho, itens: r.itens.map((i) => i.nome + (i.pasta ? '/' : '')) };
  },
  ler_arquivo: async ({ caminho }) => {
    const r = PC_ARQ().ler(caminho);
    if (r.binario) throw new Error(r.descricao + ': não leio este formato como texto. Use a prévia do painel.');
    return { caminho: r.caminho, texto: r.texto || '', bytes: r.bytes, hash: r.hash, truncado: !!r.truncado, resumo: r.resumo };
  },
  criar_arquivo: async ({ nome, texto, pasta }) => {
    const base = dentroDaCasa(pasta || '~/Jarvis');
    const alvo = path.join(base, nomeSeguro(nome));
    if (!dentroDaCasa(alvo)) throw new Error('Caminho fora da pasta do usuário.');
    const rel = path.relative(app.getPath('home'), alvo).split(path.sep).join('/');
    const salvo = PC_ARQ().salvar({ caminho: '~/' + rel, texto: String(texto == null ? '' : texto) });
    return { caminho: salvo.caminho, bytes: salvo.bytes, hash: salvo.hash };
  },
  apagar_arquivo: async ({ caminho }) => {
    const alvo = dentroDaCasa(caminho);
    // Lixeira do sistema, não exclusão definitiva: dá para recuperar.
    await shell.trashItem(alvo);
    return { caminho: alvo, lixeira: true };
  },
  abrir_pasta: async ({ caminho }) => {
    const alvo = dentroDaCasa(caminho);
    const erro = await shell.openPath(alvo);
    if (erro) throw new Error(erro);
    return { caminho: alvo };
  },
  pesquisar_web: async ({ consulta }) => {
    const q = String(consulta || '').slice(0, 300);
    if (!q.trim()) throw new Error('Consulta vazia.');
    return shell.openExternal('https://www.google.com/search?q=' + encodeURIComponent(q));
  }
};
Object.assign(acoes, acoesPC);

// ---------- Obsidian, captura de tela e exportação de arquivos (só desktop) ----------
// O renderer pede "sincronize estas notas nesta pasta" e nada além disso: nome de arquivo é
// validado aqui (sem caminho absoluto, sem ".."), a pasta tem de existir, e o app só escreve
// dentro dela. Nada é apagado no cofre do usuário.
function resolverCofre(caminho) {
  const bruto = String(caminho || '').trim();
  if (!bruto) throw new Error('Informe a pasta do cofre do Obsidian.');
  const alvo = dentroDaCasa(bruto);
  if (!fs.existsSync(alvo)) throw new Error('Essa pasta não existe: ' + alvo);
  if (!fs.statSync(alvo).isDirectory()) throw new Error('O caminho não é uma pasta.');
  return alvo;
}
function pastaJarvis(cofre) {
  const alvo = path.join(cofre, 'Jarvis Nova');
  fs.mkdirSync(alvo, { recursive: true });
  return alvo;
}
function notasMd(base, limite) {
  const achados = [];
  const fila = [{ dir: base, nivel: 0 }];
  while (fila.length && achados.length < limite) {
    const atual = fila.shift();
    let itens = [];
    try { itens = fs.readdirSync(atual.dir, { withFileTypes: true }); } catch (e) { continue; }
    for (let i = 0; i < itens.length && achados.length < limite; i++) {
      const item = itens[i];
      if (item.name.startsWith('.')) continue;
      const completo = path.join(atual.dir, item.name);
      if (item.isDirectory() && atual.nivel < 3) fila.push({ dir: completo, nivel: atual.nivel + 1 });
      else if (/\.md$/i.test(item.name)) achados.push(completo);
    }
  }
  return achados;
}
function nomeNotaSeguro(nome) {
  const limpo = String(nome || 'nota.md').replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-').replace(/\.{2,}/g, '.').replace(/^[.\-\s]+/, '');
  if (!/\.md$/i.test(limpo)) throw new Error('A nota precisa terminar em .md.');
  return limpo.slice(0, 140);
}

const acoesExtras = {
  vault_status: async ({ caminho }) => {
    const cofre = resolverCofre(caminho);
    const arquivos = notasMd(cofre, 400);
    return { caminho: cofre, arquivos: arquivos.length, pasta: path.join(cofre, 'Jarvis Nova') };
  },
  vault_sync: async ({ caminho, notas }) => {
    const cofre = resolverCofre(caminho);
    const destino = pastaJarvis(cofre);
    const lista = Array.isArray(notas) ? notas.slice(0, 400) : [];
    if (!lista.length) throw new Error('Nada para sincronizar: o cofre de memória está vazio.');
    let gravadas = 0, iguais = 0, bytes = 0;
    lista.forEach((n) => {
      const relativo = String((n && n.nome) || '').split('/').filter((p) => p && p !== '.' && p !== '..');
      const nome = nomeNotaSeguro(relativo.pop() || 'nota.md');
      const sub = path.join(destino, ...relativo.map((p) => String(p).replace(/[\\:*?"<>|]/g, '-').slice(0, 40)));
      if (!dentroDaCasa(sub)) return;
      fs.mkdirSync(sub, { recursive: true });
      const alvo = path.join(sub, nome);
      const texto = String((n && n.texto) || '').slice(0, 20000);
      let atual = null;
      try { atual = fs.readFileSync(alvo, 'utf8'); } catch (e) { atual = null; }
      if (atual === texto) { iguais++; return; }
      // Nota existente ganha cópia antes de ser reescrita: a sincronização nunca
      // destrói a versão anterior sem deixar como voltar.
      if (atual != null) {
        const copia = alvo + '.bak-' + new Date().toISOString().replace(/[:.]/g, '-');
        try { fs.copyFileSync(alvo, copia); } catch (e) { throw new Error('Não consegui copiar ' + nome + ' antes de gravar: ' + e.message); }
      }
      const temporario = alvo + '.tmp-' + process.pid + '-' + Date.now().toString(36);
      try {
        fs.writeFileSync(temporario, texto, 'utf8');
        fs.renameSync(temporario, alvo);
      } catch (e) {
        try { fs.unlinkSync(temporario); } catch (_) { /* já não existe */ }
        throw e;
      }
      gravadas++; bytes += Buffer.byteLength(texto, 'utf8');
    });
    return { caminho: destino, gravadas, iguais, bytes, aviso: 'notas existentes são copiadas para .bak-* antes de qualquer reescrita' };
  },
  vault_ler: async ({ caminho, limite }) => {
    const cofre = resolverCofre(caminho);
    const pasta = path.join(cofre, 'Jarvis Nova');
    const base = fs.existsSync(pasta) ? pasta : cofre;
    const arquivos = notasMd(base, Math.max(1, Math.min(200, Number(limite) || 100)));
    const partes = [];
    let bytes = 0;
    for (const arquivo of arquivos) {
      if (bytes > 400 * 1024) break;
      try {
        const texto = fs.readFileSync(arquivo, 'utf8');
        partes.push(texto);
        bytes += Buffer.byteLength(texto, 'utf8');
      } catch (e) { /* arquivo sumiu no meio: segue */ }
    }
    return { arquivos: partes.length, texto: partes.join('\n'), bytes };
  },
  capturar_tela: async () => {
    const fontes = await desktopCapturer.getSources({ types: ['screen'], thumbnailSize: { width: 1280, height: 800 } });
    if (!fontes || !fontes.length) throw new Error('Nenhuma tela disponível para captura.');
    const imagem = fontes[0].thumbnail.toDataURL('image/jpeg', 80);
    return { imagem, telas: fontes.length, nome: fontes[0].name || 'tela' };
  },
  salvar_arquivo: async ({ nome, texto, base64 }) => {
    const base = dentroDaCasa('~/Jarvis');
    fs.mkdirSync(base, { recursive: true });
    const alvo = path.join(base, nomeSeguro(nome));
    if (!dentroDaCasa(alvo)) throw new Error('Caminho fora da pasta do usuário.');
    const rel = path.relative(app.getPath('home'), alvo).split(path.sep).join('/');
    if (base64) {
      const bruto = Buffer.from(String(base64), 'base64');
      if (!bruto.length) throw new Error('O conteúdo em base64 está vazio ou inválido.');
      if (bruto.length > 20 * 1024 * 1024) throw new Error('Arquivo acima do limite de 20 MB.');
      const salvo = PC_ARQ().salvarBinario({ caminho: '~/' + rel, dados: bruto });
      return { caminho: salvo.caminho, bytes: salvo.bytes, hash: salvo.hash };
    }
    const salvo = PC_ARQ().salvar({ caminho: '~/' + rel, texto: String(texto == null ? '' : texto) });
    return { caminho: salvo.caminho, bytes: salvo.bytes, hash: salvo.hash };
  }
};
Object.assign(acoes, acoesExtras);

// ---------- Cofre do Obsidian no PC ----------
// A pasta é escolhida pelo usuário no diálogo nativo e fica autorizada neste processo.
// O renderer não escolhe caminho arbitrário: só usa a pasta autorizada e só grava em
// Memoria/. Nada é apagado, e notas fora de Memoria/ nunca são tocadas.
const arquivoCofreDesktop = () => path.join(app.getPath('userData'), 'jarvis-cofre.json');
let cofreAutorizado = '';
try {
  if (fs.existsSync(arquivoCofreDesktop())) {
    const bruto = JSON.parse(fs.readFileSync(arquivoCofreDesktop(), 'utf8'));
    if (bruto && typeof bruto.caminho === 'string') cofreAutorizado = bruto.caminho;
  }
} catch (_) { cofreAutorizado = ''; }

function gravarCofreAutorizado(caminho) {
  cofreAutorizado = caminho;
  try { fs.writeFileSync(arquivoCofreDesktop(), JSON.stringify({ caminho }), { mode: 0o600 }); } catch (_) { /* sem persistência */ }
}
function exigirCofre() {
  if (!cofreAutorizado) throw new Error('Nenhuma pasta de cofre escolhida no computador.');
  if (!fs.existsSync(cofreAutorizado) || !fs.statSync(cofreAutorizado).isDirectory()) {
    throw new Error('A pasta do cofre não existe mais: ' + cofreAutorizado);
  }
  return cofreAutorizado;
}
function dentroDoCofre(relativo) {
  const cofre = exigirCofre();
  const partes = String(relativo || '').split('/').filter((p) => p && p !== '.' && p !== '..');
  const alvo = path.join(cofre, ...partes);
  const rel = path.relative(cofre, alvo);
  if (rel.startsWith('..') || path.isAbsolute(rel)) throw new Error('Caminho fora do cofre.');
  return alvo;
}
function listarMd(base, limite) {
  const achados = [];
  const fila = [{ dir: base, nivel: 0, prefixo: '' }];
  while (fila.length && achados.length < limite) {
    const atual = fila.shift();
    let itens = [];
    try { itens = fs.readdirSync(atual.dir, { withFileTypes: true }); } catch (_) { continue; }
    for (const item of itens) {
      if (item.name.startsWith('.')) continue;
      if (item.isDirectory() && atual.nivel < 3) {
        fila.push({ dir: path.join(atual.dir, item.name), nivel: atual.nivel + 1, prefixo: atual.prefixo + item.name + '/' });
      } else if (/\.md$/i.test(item.name)) {
        achados.push(atual.prefixo + item.name);
      }
      if (achados.length >= limite) break;
    }
  }
  return achados;
}

Object.assign(acoes, {
  escolher_cofre: async () => {
    const r = await dialog.showOpenDialog({ properties: ['openDirectory'], title: 'Escolha a pasta do cofre do Obsidian' });
    if (r.canceled || !r.filePaths || !r.filePaths.length) throw new Error('Seleção de pasta cancelada.');
    const caminho = r.filePaths[0];
    if (!fs.statSync(caminho).isDirectory()) throw new Error('O caminho escolhido não é uma pasta.');
    gravarCofreAutorizado(caminho);
    return { caminho, nome: path.basename(caminho) };
  },
  cofre_status: async ({ caminho }) => {
    if (caminho && String(caminho).trim() && String(caminho).trim() !== cofreAutorizado) {
      const escolhido = String(caminho).trim();
      if (!fs.existsSync(escolhido) || !fs.statSync(escolhido).isDirectory()) {
        throw new Error('Essa pasta não existe: ' + escolhido);
      }
      gravarCofreAutorizado(escolhido);
    }
    const cofre = exigirCofre();
    let podeLer = true, podeEscrever = true;
    try { fs.accessSync(cofre, fs.constants.R_OK); } catch (_) { podeLer = false; }
    try { fs.accessSync(cofre, fs.constants.W_OK); } catch (_) { podeEscrever = false; }
    const pastas = fs.readdirSync(cofre, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).slice(0, 50);
    return {
      conectado: podeLer, caminho: cofre, nome: path.basename(cofre),
      podeLer, podeEscrever, arquivos: listarMd(cofre, 500).length,
      pastaMemoria: fs.existsSync(path.join(cofre, 'Memoria')), pastas
    };
  },
  cofre_listar: async () => ({ arquivos: listarMd(exigirCofre(), 200) }),
  cofre_ler: async ({ arquivo }) => {
    const alvo = dentroDoCofre(arquivo);
    const st = fs.statSync(alvo);
    if (!st.isFile()) throw new Error('Isso não é um arquivo.');
    if (st.size > 1024 * 1024) throw new Error('Arquivo grande demais para leitura (limite de 1 MB).');
    return { caminho: arquivo, texto: fs.readFileSync(alvo, 'utf8') };
  },
  cofre_escrever: async ({ arquivo, texto }) => {
    const rel = String(arquivo || '');
    if (!/^Memoria\//.test(rel)) throw new Error('Só escrevo em Memoria/ para não mexer nas suas notas.');
    const alvo = dentroDoCofre(rel);
    fs.mkdirSync(path.dirname(alvo), { recursive: true });
    const conteudo = String(texto == null ? '' : texto).slice(0, 512 * 1024);
    fs.writeFileSync(alvo, conteudo, 'utf8');
    return { ok: true, caminho: rel, bytes: Buffer.byteLength(conteudo, 'utf8') };
  },
  esquecer_cofre: async () => {
    cofreAutorizado = '';
    try { fs.unlinkSync(arquivoCofreDesktop()); } catch (_) { /* já não existia */ }
    return true;
  }
});

// ---------- Camada PC: arquivos, CAD, tarefas e diagnóstico ----------
// Tudo abaixo trabalha dentro da pasta do usuário (app.getPath('home')). O renderer manda
// caminho relativo e confirma operações destrutivas; nenhuma ação aceita comando de shell.
const PC_ARQ = () => ARQ.criarArquivos({ raiz: app.getPath('home') });
const PC_CAD = () => CADPC.criarCad({ raiz: app.getPath('home') });

const falhasRecentes = [];
function anotarFalha(acao, erro) {
  falhasRecentes.unshift({ acao: String(acao || '?'), erro: String(erro && erro.message ? erro.message : erro).slice(0, 300), quando: Date.now() });
  if (falhasRecentes.length > 40) falhasRecentes.pop();
}

// Tarefas com várias etapas: cada passo é uma ação JÁ permitida da lista branca.
// Não existe "executar comando": o pior que um passo faz é mexer em arquivo com as
// mesmas travas de uma ação isolada, e o relatório diz o que falhou.
const ACOES_DE_TAREFA = new Set([
  'arq_listar', 'arq_pesquisar', 'arq_organizar', 'arq_converter', 'arq_criar_pasta',
  'cad_identificar', 'cad_abrir', 'cad_criar', 'cad_exportar'
]);
let cancelarTarefaAtual = false;

function comandoExiste(nomes) {
  const lista = Array.isArray(nomes) ? nomes : [nomes];
  for (const nome of lista) {
    try {
      const r = plat === 'win32'
        ? spawnSync('where', [nome], { stdio: 'ignore', timeout: 2500 })
        : spawnSync('sh', ['-c', 'command -v ' + String(nome).replace(/[^A-Za-z0-9_.-]/g, '')], { stdio: 'ignore', timeout: 2500 });
      if (r && r.status === 0) return true;
    } catch (_) { /* comando ausente */ }
  }
  return false;
}

const acoesPC2 = {
  arq_listar: ({ caminho }) => PC_ARQ().listar(caminho),
  arq_ler: ({ caminho }) => PC_ARQ().ler(caminho),
  arq_salvar: ({ caminho, texto, backup }) => PC_ARQ().salvar({ caminho, texto, backup: backup !== false }),
  arq_comparar: ({ a, b }) => PC_ARQ().comparar(a, b),
  arq_pesquisar: ({ termo, pasta, limite }) => PC_ARQ().pesquisar(termo, pasta, { limite: limite }),
  arq_converter: ({ caminho, alvo, sobrescrever }) => PC_ARQ().converter({ caminho: caminho, alvo: alvo, sobrescrever: !!sobrescrever }),
  arq_organizar: ({ pasta, aplicar }) => PC_ARQ().organizar({ pasta: pasta, aplicar: !!aplicar }),
  arq_mover: ({ de, para }) => PC_ARQ().mover({ de: de, para: para }),
  arq_criar_pasta: ({ pasta, nome }) => PC_ARQ().criarPasta({ pasta: pasta, nome: nome }),
  arq_apagar: async ({ caminho }) => PC_ARQ().apagar(caminho, (alvo) => shell.trashItem(alvo)),
  arq_abrir: async ({ caminho }) => {
    const alvo = PC_ARQ().resolver(caminho);
    const erro = await shell.openPath(alvo);
    if (erro) throw new Error(erro);
    return { ok: true, caminho: alvo };
  },
  arq_verificar: ({ caminho }) => PC_ARQ().verificar(caminho),
  arq_compactar: ({ destino, arquivos }) => PC_ARQ().compactar({ destino: destino, arquivos: arquivos }),
  arq_limpar_temporarios: ({ pasta, horas }) => PC_ARQ().limparTemporarios(pasta, horas),
  cad_identificar: ({ caminho }) => PC_CAD().identificar(caminho),
  cad_abrir: ({ caminho }) => PC_CAD().abrir(caminho),
  cad_criar: (dados) => PC_CAD().criar(dados || {}),
  cad_modificar: (dados) => PC_CAD().modificar(dados || {}),
  cad_exportar: (dados) => PC_CAD().exportar(dados || {}),
  cad_formatos: () => PC_CAD().formatos(),
  tarefas_executar: async ({ passos, titulo }) => {
    const lista = Array.isArray(passos) ? passos.slice(0, 40) : [];
    if (!lista.length) throw new Error('A tarefa não tem passos.');
    for (const p of lista) {
      if (!p || !ACOES_DE_TAREFA.has(p.acao)) throw new Error('Passo não permitido em tarefa: ' + (p && p.acao ? p.acao : '?'));
    }
    cancelarTarefaAtual = false;
    const inicio = Date.now();
    const relatorio = [];
    let falhou = false;
    for (let i = 0; i < lista.length; i++) {
      const passo = lista[i];
      if (cancelarTarefaAtual) { relatorio.push({ passo: i + 1, acao: passo.acao, ok: false, erro: 'cancelado pelo usuário' }); break; }
      try {
        const r = await acoes[passo.acao](passo.args || {});
        relatorio.push({ passo: i + 1, acao: passo.acao, ok: true, resultado: resumirResultado(passo.acao, r) });
      } catch (e) {
        falhou = true;
        anotarFalha('tarefa:' + passo.acao, e);
        relatorio.push({ passo: i + 1, acao: passo.acao, ok: false, erro: String(e && e.message ? e.message : e) });
        break; // não sigo depois de erro: o relatório precisa ser confiável
      }
    }
    const ok = relatorio.filter((r) => r.ok).length;
    return {
      titulo: String(titulo || 'Tarefa').slice(0, 80), passos: lista.length, concluidos: ok,
      cancelada: cancelarTarefaAtual, falhou, segundos: Math.round((Date.now() - inicio) / 1000),
      relatorio,
      resumo: (falhou || cancelarTarefaAtual ? 'Interrompida: ' : 'Concluída: ') + ok + ' de ' + lista.length + ' passo(s).'
    };
  },
  tarefas_cancelar: async () => { cancelarTarefaAtual = true; return { ok: true }; },
  diag_pc: async () => {
    const pkg = require(path.join(RAIZ, 'package.json'));
    const itens = [];
    const item = (grupo, nome, estado, detalhe, impacto, acao) => itens.push({ grupo, nome, estado, detalhe, impacto: impacto || '', acao: acao || '' });
    item('Aplicativo', 'Versão instalada', 'ok', 'J.A.R.V.I.S. Nova ' + (pkg.version || '?') + ' · Electron ' + process.versions.electron + ' · Chromium ' + process.versions.chrome, '', '');
    const mem = os.totalmem(), livre = os.freemem();
    const ramOk = livre / mem > 0.12;
    item('Sistema', 'Memória e processador', ramOk ? 'ok' : 'aviso', os.cpus().length + ' núcleo(s) · ' + Math.round(livre / 1073741824 * 10) / 10 + ' de ' + Math.round(mem / 1073741824 * 10) / 10 + ' GB livres', ramOk ? '' : 'com pouca memória livre o modelo local pode não carregar', '');
    let disco = null;
    try {
      const st = fs.statfsSync(app.getPath('home'));
      disco = { livre: st.bavail * st.bsize, total: st.blocks * st.bsize };
    } catch (_) { /* sem statfs */ }
    item('Sistema', 'Espaço em disco', !disco ? 'nao_verificado' : (disco.livre > 2 * 1073741824 ? 'ok' : 'aviso'),
      disco ? Math.round(disco.livre / 1073741824 * 10) / 10 + ' de ' + Math.round(disco.total / 1073741824 * 10) / 10 + ' GB livres na pasta do usuário' : 'o sistema não expôs o espaço livre',
      disco && disco.livre <= 2 * 1073741824 ? 'modelos .task grandes podem não caber' : '', '');
    let chaves = [];
    try { chaves = Object.keys(lerCofreDesktop()).filter((k) => /^(groq|cerebras|mistral|gemini)$/.test(k)); } catch (_) { chaves = []; }
    item('IA', 'Provedores com chave no cofre do SO', chaves.length ? 'ok' : 'nao_configurado',
      chaves.length ? chaves.join(', ') : 'nenhuma chave salva neste computador', '', 'Ajustes ▸ IA Core');
    item('IA', 'Modelo local (.task)', chaves.length || cofreAutorizado ? 'nao_verificado' : 'nao_configurado',
      'o carregamento do .task depende do MediaPipe, que só existe no Android; no PC o núcleo usa provedor externo configurado',
      'sem provedor configurado, o chat offline não responde', 'Ajustes ▸ IA Core');
    let cofre = { estado: 'nao_configurado', detalhe: 'nenhuma pasta de cofre escolhida' };
    try {
      const cofre2 = exigirCofre();
      const arquivos = listarMd(cofre2, 500).length;
      let escrita = true;
      try { fs.accessSync(cofre2, fs.constants.W_OK); } catch (_) { escrita = false; }
      cofre = { estado: escrita ? 'ok' : 'aviso', detalhe: cofre2 + ' · ' + arquivos + ' nota(s) .md' + (escrita ? '' : ' · somente leitura') };
    } catch (e) { cofre = { estado: 'nao_configurado', detalhe: String(e.message) }; }
    item('Memória', 'Cofre do Obsidian', cofre.estado, cofre.detalhe, cofre.estado === 'ok' ? '' : 'a memória por tópicos não grava nem lê notas', 'Ajustes ▸ Memória');
    item('Arquivos', 'Motor de arquivos', 'ok', 'detecção por assinatura, prévia por formato, gravação atômica com backup .bak', '', 'Painel ▸ Computador ▸ Arquivos');
    const ferramentas = {
      FreeCAD: comandoExiste(['FreeCAD', 'freecad', 'freecadcmd']),
      LibreCAD: comandoExiste(['LibreCAD', 'librecad']),
      Inkscape: comandoExiste(['inkscape']),
      LibreOffice: comandoExiste(['soffice', 'libreoffice'])
    };
    const ausentes = Object.keys(ferramentas).filter((k) => !ferramentas[k]);
    item('CAD', 'Ferramentas externas', ausentes.length ? 'aviso' : 'ok',
      Object.keys(ferramentas).map((k) => k + ': ' + (ferramentas[k] ? 'instalado' : 'ausente')).join(' · '),
      'FCStd e DWG dependem de software externo; DXF/STL/3MF/STEP/IFC são tratados pelo próprio app', 'Painel ▸ Computador ▸ CAD');
    item('CAD', 'Formatos do núcleo', 'ok', require(path.join(RAIZ, 'cad.js')).FORMATOS.length + ' formato(s) na matriz, com validação por reabertura na exportação', '', 'Painel ▸ Computador ▸ CAD');
    item('Diário', 'Falhas recentes', falhasRecentes.length ? 'aviso' : 'ok', falhasRecentes.length ? falhasRecentes.slice(0, 5).map((f) => f.acao + ': ' + f.erro).join(' | ') : 'nenhuma falha desde que o app abriu', '', '');
    return {
      itens, gerado: Date.now(),
      resumo: itens.filter((i) => i.estado === 'erro').length + ' erro(s), ' + itens.filter((i) => i.estado === 'aviso').length + ' aviso(s) em ' + itens.length + ' verificação(ões).'
    };
  }
};
function resumirResultado(acao, r) {
  if (!r || typeof r !== 'object') return '';
  if (r.resumo) return String(r.resumo).slice(0, 200);
  if (r.arquivo) return path.basename(r.arquivo);
  if (r.itens) return r.itens.length + ' item(ns)';
  if (r.achados) return r.achados.length + ' achado(s)';
  if (typeof r.movidos === 'number') return r.movidos + ' movido(s)';
  return '';
}
Object.assign(acoes, acoesPC2);

ipcMain.handle('jarvis:run', async (_e, nome, args) => {
  if (!Object.prototype.hasOwnProperty.call(acoes, nome)) {
    anotarFalha(nome, 'ação desconhecida');
    throw new Error('Ação desconhecida');
  }
  try {
    return (await acoes[nome](args || {})) ?? true;
  } catch (e) {
    anotarFalha(nome, e);
    throw e;
  }
});

app.whenReady().then(criarJanela);
app.on('window-all-closed', () => app.quit());
