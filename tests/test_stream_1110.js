// Comportamento do streaming da IA e do humor por contexto (1.11.0).
// Extrai os blocos reais do app.js e executa com stubs: um provedor simulado que manda
// SSE em pedaços arbitrários (inclusive cortando linhas no meio) mostra quando a fala
// começa e o que acontece quando o provedor não coopera.
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const app = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');

function bloco(inicio, fim, rotulo) {
  const i = app.indexOf(inicio);
  const f = app.indexOf(fim, i + 1);
  if (i < 0 || f < 0) throw new Error('não localizei o bloco ' + rotulo);
  return app.slice(i, f);
}

/* ---------- Extração dos blocos reais ---------- */
// O tom do turno mora no núcleo Hermes (1.12.0) e é consumido por tomDoTurno/fraseApp do
// app.js: o teste carrega o núcleo de verdade e injeta nele, em vez de simular as regras.
const Hermes = require(path.join(__dirname, '..', 'hermes.js'));
const fonteTom = bloco('let perguntaAtual = ', 'function promptSistema() {', 'de tom do turno');
const fonteStream = bloco("const usaStream =", 'async function tentarModelo(p, key, m) {', 'de streaming');

const criarTom = new Function('norm', 'store', 'trat', 'Hermes',
  fonteTom + '\nreturn { tomDoTurno, fraseApp, setPergunta: (t) => { perguntaAtual = t; } };');

const criarStream = new Function('fetch', 'store', 'ctrlRede', 'corpoChat', 'CHAVES', 'modelosDe',
  'ESTRATEGIAS', 'abortar', 'falar', 'registrar',
  fonteStream + '\nreturn { usaStream, extrairFalaParcial, lerStreamIA, tentarStream };');

/* ---------- Stubs ---------- */
const store = { d: {}, get(k, v) { return k in this.d ? this.d[k] : v; }, set(k, v) { this.d[k] = v; } };
const norm = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
const tom = criarTom(norm, store, () => 'senhor', Hermes);

// Provedor simulado: SSE repartido em pedaços de 7 bytes (corta linhas no meio) e
// contador de leituras, para provar que a fala começou antes do fim do corpo.
function respostaSSE(pedacosConteudo, status) {
  status = status || 200;
  const sse = (obj) => 'data: ' + JSON.stringify(obj) + '\n\n';
  const texto = pedacosConteudo.map((c) => sse({ choices: [{ delta: { content: c } }] })).join('') + 'data: [DONE]\n\n';
  const bruto = Buffer.from(texto, 'utf8');
  const pedacos = [];
  for (let i = 0; i < bruto.length; i += 7) pedacos.push(bruto.subarray(i, i + 7));
  const estado = { k: 0, total: pedacos.length };
  return {
    ok: status < 400,
    status,
    estado,
    body: { getReader: () => ({ read: async () => (estado.k < pedacos.length ? { value: pedacos[estado.k++], done: false } : { value: undefined, done: true }) }) },
    text: async () => 'erro simulado do provedor'
  };
}

const ok = [];
const chk = (nome, cond) => { ok.push([nome, !!cond]); };

(async () => {
  /* ---------- 1. extração da fala em JSON incompleto ---------- */
  const E = criarStream(() => { throw new Error('não deveria chamar a rede'); }, store, new AbortController(),
    () => ({}), { groq: 'chave' }, (p) => p.modelos, [{ json: true, rz: true }], false, async () => {}, () => {});

  chk('extrai a fala de um JSON ainda aberto', E.extrairFalaParcial('{"fala":"Bom dia, senhor"') === 'Bom dia, senhor');
  chk('respeita escapes dentro da fala', E.extrairFalaParcial('{"fala":"Diga \\"algo\\" para mim"') === 'Diga "algo" para mim');
  chk('ainda sem fala devolve null', E.extrairFalaParcial('{"resposta') === null);

  /* ---------- 2. leitura do SSE em pedaços ---------- */
  const corpo = '{"fala":"Segundos de resposta menores, senhor.","acao":null}';
  const meio = Math.floor(corpo.length / 2);
  const eventos = [];
  const S2 = criarStream(async () => respostaSSE([corpo.slice(0, meio), corpo.slice(meio)]), store,
    new AbortController(), () => ({}), { groq: 'chave' }, (p) => p.modelos, [{ json: true, rz: true }], false, async () => {}, () => {});
  const r2 = await S2.lerStreamIA({ url: 'https://x' }, 'chave', 'm', { json: true, rz: true }, (ac) => eventos.push('parcial:' + ac.length));
  chk('streaming lê o corpo inteiro mesmo cortado em pedaços', r2.ok && r2.raw === corpo);
  chk('a fala parcial é repassada mais de uma vez', eventos.filter((e) => e.indexOf('parcial:') === 0).length > 1);

  /* ---------- 3. provedor que não coopera ---------- */
  const S3 = criarStream(async () => ({ ok: false, status: 400, text: async () => 'stream não suportado' }),
    store, new AbortController(), () => ({}), { groq: 'chave' }, (p) => p.modelos, [{ json: true, rz: true }], false, async () => {}, () => {});
  const r3 = await S3.lerStreamIA({ url: 'https://x' }, 'chave', 'm', { json: true, rz: true }, null);
  chk('HTTP 400 do streaming vira fallback, não exceção', !r3.ok && r3.status === 400);

  /* ---------- 4. tentarStream: liga/desliga e fala antecipada ---------- */
  let chamadas = 0, faladoEm = -1;
  let resposta4 = null;
  const fetchContador = async () => { chamadas++; resposta4 = respostaSSE(['{"fala":"Pronto, senhor, seguimos."']); return resposta4; };
  const faladas = [];
  // A fala antecipada sai pela função "falar" (o app inteiro fala por ela); o terceiro
  // argumento de tentarStream só habilita o recurso.
  const S4 = criarStream(fetchContador, store, new AbortController(), () => ({}), { groq: 'chave' },
    (p) => p.modelos, [{ json: true, rz: true }], false,
    (t) => { faladas.push(t); faladoEm = resposta4 ? resposta4.estado.k : -1; },
    () => {});

  store.set('resposta_stream', '0');
  const desligado = await S4.tentarStream({ url: 'https://x', id: 'groq', modelos: ['m'] }, 'pergunta', async () => {});
  chk('streaming desligado na configuração não faz chamada', desligado === null && chamadas === 0);

  store.set('resposta_stream', '1');
  const ligado = await S4.tentarStream({ url: 'https://x', id: 'groq', modelos: ['m'] }, 'pergunta', async () => {});
  chk('streaming ligado devolve a resposta completa', ligado && ligado.ok && ligado.raw === '{"fala":"Pronto, senhor, seguimos."');
  chk('a fala foi dita UMA vez, sem repetição', faladas.length === 1);
  chk('a fala começou ANTES do fim do corpo (k < total)', faladoEm > 0 && faladoEm < resposta4.estado.total);
  chk('a promessa da fala antecipada é devolvida para o turno esperar', !!ligado.jaFalou && typeof ligado.jaFalou.then === 'function');
  await ligado.jaFalou;

  // Modelo aposentado passa para o seguinte; qualquer outra falha devolve null.
  const ordem = [];
  const fetchModelos = async (url, opts) => {
    const modelo = JSON.parse(opts.body).model;
    ordem.push(modelo);
    return modelo === 'antigo' ? { ok: false, status: 404, text: async () => 'model_not_found' } : respostaSSE(['{"fala":"ok"}']);
  };
  const S5 = criarStream(fetchModelos, store, new AbortController(), (modelo) => ({ model: modelo }), { groq: 'chave' },
    () => ['antigo', 'novo'], [{ json: true, rz: true }], false, async () => {}, () => {});
  const r5 = await S5.tentarStream({ url: 'https://x', id: 'groq', modelos: ['m'] }, 'pergunta', null);
  chk('modelo aposentado passa para o seguinte', r5 && r5.ok && r5.modelo === 'novo' && ordem.join(',') === 'antigo,novo');

  const S6 = criarStream(async () => ({ ok: false, status: 429, text: async () => 'limite' }),
    store, new AbortController(), () => ({}), { groq: 'chave' }, (p) => p.modelos, [{ json: true, rz: true }], false, async () => {}, () => {});
  chk('falha normal do streaming devolve null (caminho normal assume)', await S6.tentarStream({ url: 'https://x', id: 'groq', modelos: ['m'] }, 'p', null) === null);

  // Corpo sem leitor de stream: nada de exceção, só fallback.
  const S7 = criarStream(async () => ({ ok: true, status: 200 }), store, new AbortController(), () => ({}),
    { groq: 'chave' }, (p) => p.modelos, [{ json: true, rz: true }], false, async () => {}, () => {});
  chk('resposta sem corpo legível também cai no caminho normal', await S7.tentarStream({ url: 'https://x', id: 'groq', modelos: ['m'] }, 'p', null) === null);

  /* ---------- 5. tom do turno ---------- */
  chk('urgência marca o turno como sensível', tom.tomDoTurno('isso é urgente, socorro').serio === true);
  chk('saúde e segurança também contam', tom.tomDoTurno('minha mãe está com febre grave').serio === true);
  chk('pedido corrido marca pressa', tom.tomDoTurno('resuma isso rapido por favor').pressa === true);
  chk('conversa comum não é marcada', tom.tomDoTurno('me conta uma curiosidade sobre marcianos').serio === false);

  /* ---------- 6. frases próprias: humor controlado e variação ---------- */
  tom.setPergunta('abre o que não existe');
  store.set('humor', '0');
  const secas = new Set([0, 1, 2, 3].map(() => tom.fraseApp('acaoIndisponivel')));
  chk('com humor no mínimo só sai a frase seca', secas.size === 1 && /não está disponível/.test([...secas][0]));

  store.set('humor', '80');
  const duas = [tom.fraseApp('acaoIndisponivel'), tom.fraseApp('acaoIndisponivel')];
  chk('com humor alto a frase varia em vez de repetir', duas[0] !== duas[1]);
  chk('a frase com humor continua respeitosa', duas.every((t) => /senhor/.test(t) && !/[Pp]lha|idiota|burro/.test(t)));

  tom.setPergunta('isso é urgente, preciso de ajuda agora');
  const emSensivel = new Set([0, 1, 2].map(() => tom.fraseApp('acaoIndisponivel')));
  chk('em assunto sensível o humor some, mesmo no máximo', emSensivel.size === 1 && /não está disponível/.test([...emSensivel][0]));

  tom.setPergunta('me resuma isso rapido');
  const comPressa = new Set([0, 1, 2].map(() => tom.fraseApp('acaoIndisponivel')));
  chk('com pressa a resposta também vai direto ao ponto', comPressa.size === 1);

  tom.setPergunta('normal');
  store.set('humor', '40');
  chk('fraseApp não inventa texto para chave desconhecida', tom.fraseApp('naoExiste') === '');

  /* ---------- 7. memória de recusa do streaming ---------- */
  let tentativas = 0;
  const S8 = criarStream(async () => { tentativas++; return { ok: false, status: 400, text: async () => 'formato' }; },
    store, new AbortController(), () => ({}), { groq: 'chave' }, (p) => p.modelos, [{ json: true, rz: true }], false, async () => {}, () => {});
  const p8 = { url: 'https://x', id: 'groq', modelos: ['m'] };
  chk('recusa de formato devolve null na primeira vez', (await S8.tentarStream(p8, 'p', null)) === null && tentativas === 1);
  chk('na pergunta seguinte o provedor nem é tentado de novo', (await S8.tentarStream(p8, 'p', null)) === null && tentativas === 1);

  /* ---------- 7. integração com o prompt e com o app ---------- */
  const srcPrompt = bloco('function promptSistema() {', '// Degraus de compatibilidade', 'de promptSistema');
  chk('o prompt recebe o contexto do turno', /\$\{tomTurno\}/.test(srcPrompt) && /CONTEXTO DO TURNO/.test(srcPrompt));
  chk('o prompt ainda lê o nível de humor salvo', /const humor = Math\.max\(0, Math\.min\(100, Number\(store\.get\('humor', '40'\)\)\)\)/.test(app));
  chk('a piada respeita assunto sensível', /tomDoTurno\(perguntaAtual\)\.serio/.test(app));
  chk('o caminho normal continua existindo como fallback', /let r = await tentarProvedor\(p\);/.test(app) && /await chamar\(texto, contaminado, \(f\) => falar\(f, false\)\)/.test(app));
  chk('o gravador não promete ficar pendurado', /return new Promise\(\(resolve, reject\) => \{/.test(bloco('function gravar() {', 'function dicaWhisper', 'de gravar')) && /catch \(e\) \{ falhar\(e\); \}/.test(app));

  const falhas = ok.filter(([, v]) => !v);
  for (const [nome, v] of ok) console.log((v ? 'OK: ' : 'FALHA: ') + nome);
  if (falhas.length) { console.log('\n' + falhas.length + ' verificação(ões) falharam.'); process.exit(1); }
  console.log('\n' + ok.length + ' verificações de streaming/humor aprovadas.');
})().catch((e) => { console.error('Erro no teste:', e); process.exit(1); });
