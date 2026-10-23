// Teste de comportamento (não apenas "a string existe") das rotas de mídia/Spotify,
// dos perfis de voz e do sinal do HUD. Extrai os blocos reais de app.js e executa
// cada comando com stubs mínimos, comparando o que o app realmente chamaria.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const app = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const norm = (s) => String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();

function bloco(inicio, fim, rotulo) {
  const i = app.indexOf(inicio);
  const f = app.indexOf(fim, i + 1);
  if (i < 0 || f < 0) throw new Error('não localizei o bloco ' + rotulo);
  return app.slice(i, f);
}

/* ---------- 1. Comandos locais de mídia, Spotify e voz ---------- */
const fonteComandos = bloco('  if (/^(?:pausar|pausa|pause|pare|para|parar)', '  // Volume: direção', 'de comandos de mídia');
const executar = new Function('n', 'ACOES', 'rapido', 'falar', 'aplicarPerfilVoz', 'store', '$',
  'return (async () => {\n' + fonteComandos + '\n  return false;\n})();');

const chamadas = [];
const falado = [];
const ACOES = {
  controle_midia: { run: async (a) => { chamadas.push(['midia', a.comando]); return { info: 'Pausei Spotify.' }; } },
  spotify: { run: async (a) => { chamadas.push(['spotify', a.busca || a.tipo]); return { info: 'Abri o Spotify.' }; } },
  musica_tocando: { run: async () => { chamadas.push(['tocando']); return { info: 'Tocando X no Spotify.' }; } }
};
const store = { dados: {}, get(k, d) { return k in this.dados ? this.dados[k] : d; }, set(k, v) { this.dados[k] = v; } };
const $ = () => null;
const perfilAplicado = [];
const aplicarPerfilVoz = (nome) => { perfilAplicado.push(nome); return { nome }; };
const falar = async (t) => { falado.push(t); };

async function comando(texto) {
  chamadas.length = 0; falado.length = 0; perfilAplicado.length = 0;
  const tratado = await executar(norm(texto), ACOES, () => {}, falar, aplicarPerfilVoz, store, $);
  return { tratado, chamadas: chamadas.slice(), falado: falado.slice(), perfis: perfilAplicado.slice() };
}

(async () => {
  const ok = [];
  const chk = (nome, cond) => ok.push([nome, !!cond]);

  let r = await comando('toca Bohemian Rhapsody no Spotify');
  chk('“toca … no Spotify” abre a busca com o termo', r.tratado && r.chamadas[0][0] === 'spotify' && r.chamadas[0][1] === 'bohemian rhapsody');

  r = await comando('toque uma música da Anitta no spotify');
  chk('“toque uma música de X no Spotify” tira o artigo', r.tratado && r.chamadas[0][1] === 'anitta');

  r = await comando('toca evidências');
  chk('“toca <música>” sem “no Spotify” também busca', r.tratado && r.chamadas[0][0] === 'spotify' && r.chamadas[0][1] === 'evidencias');

  r = await comando('toca a música');
  chk('“toca a música” não vira busca (é retomar)', !r.tratado);

  r = await comando('pausa a música');
  chk('pausar mídia envia o comando pausar', r.chamadas[0][0] === 'midia' && r.chamadas[0][1] === 'pausar');

  r = await comando('para a música');
  chk('“para a música” também pausa', r.chamadas[0][0] === 'midia' && r.chamadas[0][1] === 'pausar');

  r = await comando('continua a música');
  chk('continuar mídia envia continuar', r.chamadas[0][0] === 'midia' && r.chamadas[0][1] === 'continuar');

  r = await comando('próxima música');
  chk('próxima faixa', r.chamadas[0][0] === 'midia' && r.chamadas[0][1] === 'proxima');

  r = await comando('volta a música');
  chk('voltar faixa usa o comando anterior', r.chamadas[0][0] === 'midia' && r.chamadas[0][1] === 'anterior');

  r = await comando('o que está tocando');
  chk('“o que está tocando” consulta o player', r.chamadas[0][0] === 'tocando' && /Tocando/.test(r.falado[0]));

  r = await comando('abre minhas curtidas no Spotify');
  chk('curtidas viram o atalho do Spotify', r.chamadas[0][0] === 'spotify' && r.chamadas[0][1] === 'curtidas');

  r = await comando('voz do filme');
  chk('“voz do filme” aplica o perfil do filme', r.perfis[0] === 'filme');

  r = await comando('usar voz ultra grave');
  chk('“voz ultra grave” aplica o perfil ultra', r.perfis[0] === 'ultra');

  r = await comando('voz normal');
  chk('“voz normal” volta ao padrão', r.perfis[0] === 'padrao');

  r = await comando('liga o sinal do hud');
  chk('“liga o sinal do HUD” grava a preferência', r.tratado && store.dados.voz_chime === '1');

  r = await comando('desliga o sinal do hud');
  chk('“desliga o sinal do HUD” desliga', r.tratado && store.dados.voz_chime === '0');

  r = await comando('qual a previsão do tempo');
  chk('pergunta comum não é capturada por engano', !r.tratado);

  /* ---------- 2. Perfis de voz (fonte real) ---------- */
  const fontePerfis = bloco('const PERFIS_VOZ = {', 'let chimeCtx', 'de perfis de voz');
  const sliders = { pitch: { value: '' }, rate: { value: '' } };
  const seletor = { value: '' };
  const documentStub = {
    querySelector: () => null,
    getElementById: (id) => ({ 'c-pitch': sliders.pitch, 'c-rate': sliders.rate, 'c-voz-perfil': seletor }[id] || null)
  };
  const ctx = {
    store,
    document: documentStub,
    $: (sel) => ({ '#c-pitch': sliders.pitch, '#c-rate': sliders.rate, '#c-voz-perfil': seletor }[sel] || null),
    atualizarValoresVoz: () => {}
  };
  vm.createContext(ctx);
  vm.runInContext(fontePerfis + '\nthis.PERFIS_VOZ = PERFIS_VOZ; this.aplicarPerfilVoz = aplicarPerfilVoz; this.perfilVozAtual = perfilVozAtual;', ctx);
  ctx.aplicarPerfilVoz('filme');
  chk('perfil do filme usa tom mais grave e fala mais lenta', sliders.pitch.value === '0.6' && sliders.rate.value === '0.9');
  chk('perfil do filme é persistido nos ajustes', store.dados.voz_perfil === 'filme' && store.dados.pitch === '0.6');
  chk('o seletor acompanha o perfil aplicado', seletor.value === 'filme');
  ctx.aplicarPerfilVoz('ultra');
  chk('perfil ultra é ainda mais grave', sliders.pitch.value === '0.5' && sliders.rate.value === '0.85');
  ctx.aplicarPerfilVoz('qualquer coisa');
  chk('perfil desconhecido volta ao padrão', sliders.pitch.value === '0.8' && seletor.value === 'padrao');

  /* ---------- 3. Texto do "o que está tocando" ---------- */
  const fonteMidia = bloco('function descreverMidia(r) {', 'function animarFala', 'de descreverMidia');
  const ctxMidia = { console };
  vm.createContext(ctxMidia);
  vm.runInContext(fonteMidia + '\nthis.descreverMidia = descreverMidia;', ctxMidia);
  const d = ctxMidia.descreverMidia;
  chk('descreve faixa e app', d({ permitido: true, tocando: true, app: 'Spotify', titulo: 'Evidências', artista: 'Chitãozinho' }) === 'Tocando Evidências — Chitãozinho no Spotify.');
  chk('descreve player pausado', /pausado em/.test(d({ permitido: true, tocando: false, app: 'Spotify', titulo: 'X', artista: 'Y' })));
  chk('sem permissão pede acesso às notificações', /Ajustes/.test(d({ permitido: false, tocando: false })));
  chk('sem faixa informada ainda responde', d({ permitido: true, tocando: true, app: 'YouTube Music' }) === 'O YouTube Music está tocando.');

  /* ---------- 4. Ligações com o código nativo ---------- */
  const read = (f) => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');
  const util = read('JarvisUtilPlugin.java');
  const servico = read('JarvisService.java');
  const prefs = read('JarvisPrefs.java');
  const plugin = read('JarvisBackgroundPlugin.java');
  const html = read('index.html');
  chk('plugin usa a sessão de mídia do Android', /getActiveSessions\(/.test(util) && /MediaSessionManager/.test(util));
  chk('plugin expõe tocarNoSpotify e midiaAtual', /public void tocarNoSpotify/.test(util) && /public void midiaAtual/.test(util));
  chk('plugin cai para teclas de mídia quando não há sessão', /enviarTeclaMidia\(/.test(util) && /KEYCODE_MEDIA_NEXT/.test(util));
  chk('serviço respeita o motor escolhido', /JarvisPrefs\.motor\(/.test(servico) && /"\s*porcupine\s*"\.equals\(motor\)/.test(servico.replace(/\s+/g, ' ')));
  chk('preferência do motor é persistida e validada', /static String motor\(Context c\)/.test(prefs) && /static void motor\(Context c, String v\)/.test(prefs));
  chk('plugin aceita motor no startWake', /getString\("motor"/.test(plugin));
  chk('interface tem seletor de motor, perfil e sinal', /id="c-wake-motor"/.test(html) && /id="c-voz-perfil"/.test(html) && /id="c-voz-chime"/.test(html));
  chk('interface envia o motor escolhido ao serviço', /motor: store\.get\('wake_motor'/.test(app));

  const falhas = ok.filter(([, v]) => !v);
  ok.forEach(([nome, v]) => console.log((v ? 'OK: ' : 'FALHOU: ') + nome));
  if (falhas.length) {
    console.error(falhas.length + ' verificação(ões) falharam.');
    process.exit(1);
  }
  console.log(ok.length + ' verificações de mídia, Spotify e voz aprovadas.');
})();
