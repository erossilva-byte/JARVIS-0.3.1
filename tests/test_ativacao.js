// Comportamento do detector de ativação próprio e do roteador de motores de IA (1.13.0).
// Roda o núcleo real (hermes.js) em Node, sem DOM: é o mesmo arquivo que o APK embarca, e
// as regras daqui são espelhadas em JarvisAtivacao.java (o serviço Android). O teste da
// versão compara as duas listas de variantes para que não divirjam.
'use strict';
const path = require('node:path');
const H = require(path.join(__dirname, '..', 'hermes.js'));

let falhas = 0;
function chk(nome, cond) {
  if (cond) console.log('OK: ' + nome);
  else { falhas++; console.log('FALHA: ' + nome); }
}
const avisos = (t) => t.split(' ').length;

/* ---------- 1. Calibragem: sensibilidade vira tolerância, parcial e piso de ruído ---------- */
const c0 = H.ativacao.config(0, '');
chk('sensibilidade 0 é a mais rígida', c0.tolerancia === 0 && c0.aceitaParcial === false && c0.ruidoDb === -34);
const c44 = H.ativacao.config(44, '');
chk('a partir de 35 o resultado parcial já vale', c44.aceitaParcial === true && c44.tolerancia === 0);
const c45 = H.ativacao.config(45, '');
chk('a partir de 45 a tolerância sobe para 1 letra', c45.tolerancia === 1 && c45.ruidoDb === -40);
const c75 = H.ativacao.config(75, '');
chk('a partir de 75 aceita 2 letras e parcial mais curto', c75.tolerancia === 2 && c75.minimoParcial === 5 && c75.ruidoDb === -46);
chk('sensibilidade inválida cai no padrão de 55', H.ativacao.config('abc', '').sensibilidade === 55);
chk('sensibilidade é limitada a 100', H.ativacao.config(500, '').sensibilidade === 100);
const cExtra = H.ativacao.config(55, 'nova, jarvi ;, x');
chk('palavras extras separadas, curtas descartadas', cExtra.extras.length === 2 && cExtra.extras[0] === 'nova' && cExtra.extras[1] === 'jarvi');

/* ---------- 2. A palavra: variantes, acento e o que NÃO pode acordar ---------- */
const cfg = H.ativacao.config(55, '');
const aceita = ['jarvis', 'Jarvis', 'járvis', 'jarvi', 'javis', 'javi', 'jarviz', 'jarvys', 'jarves', 'jarvez',
  'charvis', 'charves', 'xarvis', 'garvis', 'gervis', 'jarbis', 'jorvis', 'jarvis!'];
chk('todas as variantes conhecidas acordam', aceita.every((t) => H.ativacao.casaToken(t, cfg)));
const recusa = ['jardim', 'jardineiro', 'jargão', 'graves', 'gravíssimo', 'trabalho', 'jar', 'jav', '', 'a', 'jato', 'jacaré'];
chk('palavras comuns não acordam o assistente', recusa.every((t) => !H.ativacao.casaToken(t, cfg)));
chk('a trava do "v" protege as palavras começando com "jar"', !H.ativacao.casaToken('jardim', H.ativacao.config(100, '')));
chk('palavra extra cadastrada acorda', H.ativacao.casaToken('nova', H.ativacao.config(55, 'nova')));
chk('palavra extra não vale quando não cadastrada', !H.ativacao.casaToken('nova', cfg));

/* ---------- 3. A palavra no meio da frase (inclusive separada em duas) ---------- */
chk('no começo da frase', H.ativacao.presente('jarvis, que horas são', cfg));
chk('no meio da frase', H.ativacao.presente('ei jarvis abre a câmera', cfg));
chk('o transcritor separando em duas palavras ("já vi")', H.ativacao.presente('já vi, que horas são', cfg));
chk('frase sem a palavra não acorda', !H.ativacao.presente('que horas são', cfg));
chk('frase sobre jardim não acorda', !H.ativacao.presente('meu jardim está bonito hoje', cfg));
chk('texto vazio não acorda', !H.ativacao.presente('   ', cfg));
chk('a palavra é removida antes de virar comando', H.ativacao.semPalavra('jarvis que horas são') === 'que horas são');

/* ---------- 4. Classificação da tarefa ---------- */
chk('pergunta curta é tarefa rápida', H.tarefaDe('que horas são') === 'rapida');
chk('atualidade vira pesquisa', H.tarefaDe('quais as principais notícias de hoje no brasil') === 'pesquisa');
chk('passo a passo vira raciocínio', H.tarefaDe('analise esse texto passo a passo') === 'raciocinio');
chk('texto longo vira raciocínio', H.tarefaDe('x'.repeat(500)) === 'raciocinio');
chk('conversa longa continua conversa', H.tarefaDe('me conte uma história sobre o mar, os barcos, os ventos e as estrelas do céu') === 'conversa');
chk('imagem é tarefa de visão', H.tarefaDe('qualquer coisa', { visao: true }) === 'visao');

/* ---------- 5. Roteador: qualidade, latência medida, disponibilidade e visão ---------- */
const todos = ['groq', 'cerebras', 'gemini', 'mistral'];
const rapida = H.planejarIA({ texto: 'que horas são', provedores: todos });
chk('tarefa rápida escolhe o Groq', rapida.ordem[0] === 'groq' && rapida.timeoutMs === 12000);
chk('o motivo explica a escolha', /Groq/.test(rapida.motivo) && /rapida/.test(rapida.motivo));
const raciocinio = H.planejarIA({ texto: 'analise passo a passo', provedores: todos });
chk('raciocínio escolhe o motor mais forte, não o mais rápido', raciocinio.ordem[0] === 'gemini');
chk('raciocínio usa o modelo forte de cada provedor', raciocinio.modelo.gemini === 'gemini-2.5-flash' && raciocinio.modelo.groq === 'openai/gpt-oss-120b');
chk('raciocínio deixa mais tempo para responder', raciocinio.timeoutMs === 30000);
const rapidoDemais = H.planejarIA({ texto: 'que horas são', provedores: todos, latencias: { groq: 2400, cerebras: 500 } });
chk('latência medida no aparelho muda a ordem', rapidoDemais.ordem[0] === 'cerebras' && rapidoDemais.notas.cerebras > rapidoDemais.notas.groq);
const comErros = H.planejarIA({ texto: 'que horas são', provedores: todos, erros: { groq: 5 } });
chk('histórico de falhas tira o provedor da frente', comErros.ordem[0] === 'cerebras');
const pausado = H.planejarIA({ texto: 'analise isso', provedores: todos, indisponiveis: ['gemini'] });
chk('provedor em pausa vai para o fim da fila', pausado.ordem[0] === 'cerebras' && pausado.ordem[pausado.ordem.length - 1] === 'gemini');
const visao = H.planejarIA({ tarefa: 'visao', visao: true, provedores: todos });
chk('visão só considera quem enxerga imagens', visao.ordem.length === 3 && visao.ordem.indexOf('cerebras') < 0);
chk('visão prefere o motor mais forte em imagem', visao.ordem[0] === 'gemini' && visao.modelo.gemini === 'gemini-2.5-flash');
chk('visão tem reserva com modelo de imagem', visao.modelo.groq === 'meta-llama/llama-4-scout-17b-16e-instruct');
const visaoLenta = H.planejarIA({ tarefa: 'visao', visao: true, provedores: todos, latencias: { gemini: 3000 } });
chk('visão troca de motor quando o preferido está lento', visaoLenta.ordem[0] === 'groq');
const semVisao = H.planejarIA({ tarefa: 'visao', visao: true, provedores: ['cerebras'] });
chk('sem provedor de imagem o roteador avisa em vez de tentar', semVisao.ordem.length === 0 && !!semVisao.aviso);
chk('a ordem agressiva não perde nenhum provedor', new Set(rapida.ordem).size === todos.length);

/* ---------- 6. Latência aprendida (média móvel) ---------- */
H.registrarLatencia('teste', 1000);
H.registrarLatencia('teste', 2000);
chk('latência medida entra como média móvel', H.metricas().latencias.teste === 1300);
chk('medição inválida é ignorada', H.registrarLatencia('teste', 0) === undefined && H.metricas().latencias.teste === 1300);

/* ---------- 7. Visão: saneamento da resposta do modelo ---------- */
const bruto = [
  { nome: 'Caneca', info: 'de cerâmica', caixa: [0.1, 0.2, 0.3, 0.4] },
  { nome: 'caneca', info: 'repetida' },
  { nome: '', info: 'sem nome' },
  { nome: 'Cadeira', caixa: [2, 2, 0.1, 0.1] },
  { nome: 'Mesa', caixa: ['a', 'b', 'c', 'd'] }
];
const limpos = H.visao.normalizar(bruto);
chk('objetos duplicados e sem nome saem da lista', limpos.length === 3 && limpos[0].nome === 'Caneca');
chk('caixa fora da imagem é descartada, objeto permanece', limpos[1].nome === 'Cadeira' && limpos[1].caixa === null);
chk('caixa válida é limitada à imagem', (() => {
  const r = H.visao.normalizar([{ nome: 'Prateleira', caixa: [0.9, 0.9, 0.5, 0.5] }]);
  return r[0].caixa && r[0].caixa.w <= 0.1001 && r[0].caixa.h <= 0.1001;
})());
chk('lista de objetos tem teto', H.visao.normalizar(Array.from({ length: 14 }, (_, i) => ({ nome: 'objeto ' + i }))).length === 10);
const falaVazia = H.visao.descrever([], {});
chk('sem objeto identificado a fala pede aproximação', /aproximar/.test(falaVazia));
const falaHumor = H.visao.descrever([{ nome: 'Caneca' }, { nome: 'Teclado' }], { humor: true, serio: false });
chk('a fala conta os objetos e convida ao balão', /duas/.test(falaHumor) && /balão/.test(falaHumor));
const falaSeria = H.visao.descrever([{ nome: 'Caneca' }], { humor: true, serio: true });
chk('assunto sensível desliga o humor da visão', !/não adivinho por educação/.test(falaSeria) && /balão/.test(falaSeria));

/* ---------- 8. Habilidades do núcleo continuam respondendo ---------- */
chk('saudação é habilidade própria', (H.planejar('bom dia') || {}).rota === 'hermes:saudacao');
chk('autodiagnóstico é habilidade própria', (H.planejar('verifique o sistema') || {}).rota === 'hermes:diagnostico');
chk('visão por voz é habilidade própria', (H.planejar('o que você está vendo') || {}).rota === 'hermes:visao');
chk('pergunta comum não é habilidade própria', H.planejar('quem descobriu o brasil') === null);
chk('texto vazio não é habilidade própria', H.planejar('   ') === null);

(async () => {
  /* 8.1 Briefing diário por voz */
  const registro = [];
  const cap = {
    trat: () => 'senhor',
    agora: () => new Date(2026, 0, 15, 8, 30),
    ler: (k, d) => (k === 'briefing_auto' ? '1' : d),
    gravar: (k, v) => registro.push(k + '=' + v),
    falar: async (t) => registro.push('fala:' + t),
    clima: async () => ({ temp: 24, cidade: 'São Paulo', ceu: 'céu limpo', chuvaProx: 70, max: 28, min: 18 }),
    noticias: async () => ({ fala: 'Primeira manchete de agora. Segunda manchete. Terceira que não deve ser lida.', links: [{ url: 'https://exemplo.test/a', titulo: 'a' }] }),
    registrar: () => {}
  };
  H.instalar(cap);
  const r1 = await H.despachar('bom dia');
  const falado = registro.filter((x) => x.indexOf('fala:') === 0).join(' ');
  chk('briefing diário é tratado como habilidade', r1.tratado === true && r1.habilidade === 'saudacao');
  chk('briefing fala a temperatura e as manchetes', /24 graus em São Paulo/.test(falado) && /Primeira manchete de agora/.test(falado));
  chk('briefing usa a data de hoje para não repetir', registro.some((x) => /^briefing_dia=\d{4}-\d{2}-\d{2}$/.test(x)));
  chk('briefing não lê a terceira manchete', !/Terceira/.test(falado));
  chk('briefing traz os links das notícias', (r1.resultado.links || []).length === 1);

  /* 8.2 Segunda saudação do mesmo dia é curta */
  H.instalar({ ...cap, ler: (k, d) => (k === 'briefing_auto' ? '1' : (k === 'briefing_dia' ? '2026-01-15' : d)) });
  const registro2 = [];
  H.instalar({ ...cap, ler: (k, d) => (k === 'briefing_auto' ? '1' : (k === 'briefing_dia' ? '2026-01-15' : d)), falar: async (t) => registro2.push(t), frase: () => 'Em que posso ajudar?' });
  const r2 = await H.despachar('bom dia');
  chk('a segunda saudação do dia não repete o briefing', r2.resultado.briefing === false && /Em que posso ajudar/.test(registro2.join(' ')));
  chk('a segunda saudação não consulta clima de novo', !/graus/.test(registro2.join(' ')));

  /* 8.3 Autodiagnóstico falado e visão por voz */
  const itens = [{ nome: 'Microfone', estado: 'ok' }, { nome: 'Câmera', estado: 'fail', detalhe: 'Sem permissão de câmera.' }];
  const falas3 = [];
  H.instalar({ trat: () => 'senhor', falar: async (t) => falas3.push(t), diagnosticoSistema: async () => ({ itens }), registrar: () => {} });
  const r3 = await H.despachar('faça um diagnóstico completo');
  chk('autodiagnóstico fala o resultado com as pendências', r3.tratado === true && /Câmera/.test(falas3.join(' ')) && /uma com falha/.test(falas3.join(' ')));
  const falas4 = [];
  let visaoChamada = 0;
  H.instalar({ trat: () => 'senhor', falar: async (t) => falas4.push(t), registrar: () => {}, analisarVisao: async () => { visaoChamada++; return { fala: 'Vejo uma caneca.', objetos: [{ nome: 'Caneca' }] }; } });
  const r4 = await H.despachar('o que você está vendo');
  chk('visão por voz abre a câmera e fala o resultado', r4.tratado === true && visaoChamada === 1 && /caneca/.test(falas4.join(' ')));
  chk('a habilidade de visão devolve os objetos', (r4.resultado.objetos || []).length === 1);

  /* 8.4 Rota local antes da IA e degradação para a IA quando nada resolve */
  const ordemRotas = [];
  H.instalar({ comandoLocal: async () => { ordemRotas.push('local'); return true; } });
  const r5 = await H.despachar('que horas são');
  chk('comando do aparelho é resolvido antes da IA', r5.rota === 'local' && r5.tratado === true);
  H.instalar({ comandoLocal: async () => { ordemRotas.push('local-nao'); return false; } });
  const r6 = await H.despachar('quem descobriu o brasil');
  chk('nada resolvido no aparelho vai para a IA', r6.rota === 'ia' && r6.tratado === false);
  H.instalar({ comandoLocal: async () => { throw new Error('quebrou'); }, registrar: () => {} });
  const r7 = await H.despachar('que horas são');
  chk('falha no comando local não derruba o turno', r7.rota === 'ia' && r7.tratado === false);

  /* 8.5 Habilidade que falha cai para o próximo degrau */
  const falas8 = [];
  H.instalar({
    trat: () => 'senhor', registrar: () => {}, falar: async (t) => falas8.push(t),
    analisarVisao: async () => { throw new Error('câmera indisponível'); },
    comandoLocal: async () => { falas8.push('rota local assumiu'); return true; }
  });
  const r8 = await H.despachar('o que você está vendo');
  chk('habilidade que falha não deixa o usuário sem resposta', r8.rota === 'local' && r8.tratado === true);

  /* 8.6 Métricas do núcleo continuam contando rotas */
  const m = H.metricas();
  chk('as rotas são contadas nas métricas', m.turnos > 0 && m.noAparelho > 0 && m.rotas['hermes:saudacao'] >= 1);
  chk('o relatório do núcleo sai em texto falado', /Núcleo Hermes Agent/.test(H.relatorio()));
  chk('o relatório de motores lista os quatro provedores', /Groq/.test(H.relatorioMotores()) && /Gemini/.test(H.relatorioMotores()));

  console.log(falhas ? '\n' + falhas + ' verificação(ões) falharam.' : '\nDetector de ativação próprio, roteador de motores e visão validados: ' + (falhas === 0 ? 'tudo certo.' : ''));
  process.exit(falhas ? 1 : 0);
})();
