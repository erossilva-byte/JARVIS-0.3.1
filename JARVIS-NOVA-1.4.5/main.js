const { app, BrowserWindow, ipcMain, shell, clipboard, safeStorage } = require('electron');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const APPS = require('./apps.js');

const plat = process.platform; // win32 | darwin | linux
const chave = plat === 'win32' ? 'win' : plat === 'darwin' ? 'mac' : 'linux';

function criarJanela() {
  const win = new BrowserWindow({
    width: 1100, height: 780, minWidth: 420, minHeight: 600,
    backgroundColor: '#04070d', title: 'J.A.R.V.I.S.', autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true, nodeIntegration: false, sandbox: true
    }
  });
  win.loadFile(path.join(__dirname, 'index.html'));
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  win.webContents.session.setPermissionRequestHandler((_wc, perm, cb) =>
    cb(['media', 'geolocation'].includes(perm)));
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
  if (!/^(groq|cerebras|mistral|gemini|picovoice)$/.test(String(nome || ''))) throw new Error('Nome de chave inválido.');
  const dados = lerCofreDesktop();
  if (!valor) delete dados[nome];
  else dados[nome] = safeStorage.encryptString(String(valor)).toString('base64');
  gravarCofreDesktop(dados);
  return true;
}
function lerChaveDesktop({ nome }) {
  exigirCofreDesktop();
  if (!/^(groq|cerebras|mistral|gemini|picovoice)$/.test(String(nome || ''))) throw new Error('Nome de chave inválido.');
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

ipcMain.handle('jarvis:run', async (_e, nome, args) => {
  if (!Object.prototype.hasOwnProperty.call(acoes, nome)) throw new Error('Ação desconhecida');
  return (await acoes[nome](args || {})) ?? true;
});

app.whenReady().then(criarJanela);
app.on('window-all-closed', () => app.quit());
