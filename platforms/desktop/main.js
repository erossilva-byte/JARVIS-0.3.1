const { app, BrowserWindow, ipcMain, shell, clipboard, safeStorage, desktopCapturer } = require('electron');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
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
  listar_arquivos: async ({ caminho }) => {
    const alvo = dentroDaCasa(caminho);
    const itens = fs.readdirSync(alvo, { withFileTypes: true })
      .filter((d) => !d.name.startsWith('.'))
      .sort((a, b) => (b.isDirectory() - a.isDirectory()) || a.name.localeCompare(b.name))
      .slice(0, 200)
      .map((d) => d.name + (d.isDirectory() ? '/' : ''));
    return { caminho: alvo, itens };
  },
  ler_arquivo: async ({ caminho }) => {
    const alvo = dentroDaCasa(caminho);
    const st = fs.statSync(alvo);
    if (!st.isFile()) throw new Error('Isso não é um arquivo.');
    if (st.size > 200 * 1024) throw new Error('Arquivo grande demais para leitura (limite de 200 kB).');
    return { caminho: alvo, texto: fs.readFileSync(alvo, 'utf8').slice(0, 200000) };
  },
  criar_arquivo: async ({ nome, texto, pasta }) => {
    const base = dentroDaCasa(pasta || '~/Jarvis');
    fs.mkdirSync(base, { recursive: true });
    const alvo = path.join(base, nomeSeguro(nome));
    if (!dentroDaCasa(alvo)) throw new Error('Caminho fora da pasta do usuário.');
    fs.writeFileSync(alvo, String(texto == null ? '' : texto).slice(0, 200000), 'utf8');
    return { caminho: alvo };
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
  const limpo = String(nome || 'nota.md').replace(/[\\:*?"<>|\u0000-\u001f]/g, '-').replace(/\.{2,}/g, '.').replace(/^[.\-\s]+/, '');
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
      fs.writeFileSync(alvo, texto, 'utf8');
      gravadas++; bytes += Buffer.byteLength(texto, 'utf8');
    });
    return { caminho: destino, gravadas, iguais, bytes };
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
    if (base64) {
      const bruto = Buffer.from(String(base64), 'base64');
      if (bruto.length > 20 * 1024 * 1024) throw new Error('Arquivo acima do limite de 20 MB.');
      fs.writeFileSync(alvo, bruto);
      return { caminho: alvo, bytes: bruto.length };
    }
    const conteudo = String(texto == null ? '' : texto);
    fs.writeFileSync(alvo, conteudo.slice(0, 8 * 1024 * 1024), 'utf8');
    return { caminho: alvo, bytes: Buffer.byteLength(conteudo, 'utf8') };
  }
};
Object.assign(acoes, acoesExtras);

ipcMain.handle('jarvis:run', async (_e, nome, args) => {
  if (!Object.prototype.hasOwnProperty.call(acoes, nome)) throw new Error('Ação desconhecida');
  return (await acoes[nome](args || {})) ?? true;
});

app.whenReady().then(criarJanela);
app.on('window-all-closed', () => app.quit());
