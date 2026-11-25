// Regras da Etapa 6 do PC: paridade de ações, escuta sem a janela em foco,
// escolha de motor e da voz, e a medição de CPU do laço de escuta.
//
// O teste olha o código de verdade: cada linha da tabela aponta para um
// marcador que precisa existir em `app.js`/`platforms/desktop/main.js`; as
// ações do celular precisam continuar declaradas só para o Android. Se alguém
// implementar uma delas no PC, a tabela tem que mudar junto.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const V = require(path.join(__dirname, '..', 'voz_pc.js'));

let falhas = 0;
function chk(nome, cond, detalhe) {
  if (cond) console.log('OK: ' + nome);
  else { falhas++; console.log('FALHA: ' + nome + (detalhe ? ' — ' + detalhe : '')); }
}

const raiz = path.join(__dirname, '..');
const app = fs.readFileSync(path.join(raiz, 'app.js'), 'utf8');
const main = fs.readFileSync(path.join(raiz, 'platforms', 'desktop', 'main.js'), 'utf8');

/* ---------- 1. Tabela de paridade ---------- */
const soma = V.resumo();
chk('a tabela cobre as quatro categorias',
  soma.pc > 0 && soma['pc-tela'] > 0 && soma.celular > 0 && soma['sem-voz'] > 0,
  JSON.stringify(soma));
chk('nenhuma ação repetida na tabela',
  new Set(V.TABELA.map((l) => l.acao)).size === V.TABELA.length);
chk('toda linha tem categoria conhecida',
  V.TABELA.every((l) => Object.values(V.ONDE).includes(l.onde)));

for (const linha of V.TABELA) {
  if (linha.onde === V.ONDE.CELULAR) {
    const re = new RegExp(linha.chave + ": \\{ risco: \\d+, disp: \\['android'\\]");
    chk('celular: ' + linha.acao + ' continua só no Android', re.test(app));
    continue;
  }
  const onde = linha.marcador && app.includes(linha.marcador) ? 'app'
    : linha.marcador && main.includes(linha.marcador) ? 'main' : '';
  chk((linha.onde === V.ONDE.PC ? 'PC: ' : linha.onde + ': ') + linha.acao +
    ' tem caminho real', Boolean(onde), 'marcador ausente: ' + linha.marcador);
}

chk('a soma das categorias é o tamanho da tabela',
  Object.values(soma).reduce((a, b) => a + b, 0) === V.TABELA.length);
chk('mensagem ao celular não promete comando remoto',
  /só de leitura/.test(V.mensagemAcao(V.ONDE.CELULAR)) &&
  !/vou ligar|vou mandar/.test(V.mensagemAcao(V.ONDE.CELULAR)));
chk('mensagem de painel manda abrir o painel',
  /painel/.test(V.mensagemAcao(V.ONDE.PC_TELA)));
chk('ação do PC não gera desculpa', V.mensagemAcao(V.ONDE.PC) === '');

/* ---------- 2. Quando ouvir ---------- */
const base = { janelaVisivel: true, aceitaForaDeFoco: true };
chk('janela aberta ouve', V.podeOuvir(base).ouvindo === true);
const fora = V.podeOuvir({ janelaVisivel: false, aceitaForaDeFoco: true });
chk('janela atrás ouve quando autorizado', fora.ouvindo === true && fora.motivo === 'fora-de-foco');
chk('janela atrás não ouve sem autorização',
  V.podeOuvir({ janelaVisivel: false, aceitaForaDeFoco: false }).ouvindo === false);
chk('escuta desligada não ouve', V.podeOuvir(Object.assign({}, base, { desejada: false })).motivo === 'desligada');
chk('tela de bloqueio não ouve', V.podeOuvir(Object.assign({}, base, { bloqueado: true })).motivo === 'travado');
chk('modo de visita não ouve', V.podeOuvir(Object.assign({}, base, { emModoVisita: true })).motivo === 'visita');
chk('gravando/pensando não ouve', V.podeOuvir(Object.assign({}, base, { ocupado: true })).motivo === 'ocupado');
chk('falando não ouve a própria voz', V.podeOuvir(Object.assign({}, base, { falando: true })).motivo === 'falando');
chk('comando de parada em curso não ouve', V.podeOuvir(Object.assign({}, base, { paradaAtiva: true })).motivo === 'parada');
chk('toda decisão traz um texto para a tela',
  ['desligada', 'visita', 'travado', 'parada', 'ocupado', 'falando', 'sem-foco'].every((motivo) => {
    const d = V.podeOuvir(Object.assign({}, base, {
      desejada: motivo === 'desligada' ? false : true,
      emModoVisita: motivo === 'visita',
      bloqueado: motivo === 'travado',
      paradaAtiva: motivo === 'parada',
      ocupado: motivo === 'ocupado',
      falando: motivo === 'falando',
      janelaVisivel: motivo !== 'sem-foco',
      aceitaForaDeFoco: motivo !== 'sem-foco'
    }));
    return d.ouvindo === false && typeof d.texto === 'string' && d.texto.length > 10;
  }));

/* ---------- 3. Motor de escuta ---------- */
chk('detector local tem prioridade',
  V.motorDeEscuta({ kwsLocal: true, chaveNuvem: true }).motor === 'local');
chk('sem detector local, a nuvem assume e o texto avisa',
  V.motorDeEscuta({ chaveNuvem: true }).motor === 'nuvem' &&
  /vai para a transcrição/.test(V.motorDeEscuta({ chaveNuvem: true }).texto));
chk('nuvem declara que envia áudio', V.motorDeEscuta({ chaveNuvem: true }).enviaAudio === true);
chk('local declara que não envia áudio', V.motorDeEscuta({ kwsLocal: true }).enviaAudio === false);
chk('offline desliga mesmo com chave',
  V.motorDeEscuta({ chaveNuvem: true, offline: true }).motor === 'nada');
chk('sem chave e sem detector não começa', V.motorDeEscuta({}).motivo === 'sem-chave');
chk('modo offline no app bloqueia a escuta de ativação',
  /Não consegui iniciar a ativação por voz|transcrição/.test(app));

/* ---------- 4. Voz: mesma prosódia, melhor voz disponível ---------- */
const vozes = [
  { name: 'Microsoft Francisca', lang: 'pt-BR' },
  { name: 'Microsoft Daniel', lang: 'pt-BR' },
  { name: 'Google US English', lang: 'en-US' }
];
chk('prosódia é a mesma do celular',
  V.parametrosDeFala('filme').pitch === 0.6 && V.parametrosDeFala('filme').rate === 0.9);
chk('perfil desconhecido cai no padrão', V.parametrosDeFala('qualquer').perfil === 'padrao');
chk('voz salva é mantida quando existe',
  V.vozParaPC(vozes, { salva: 'Microsoft Francisca' }).motivo === 'voz-salva');
const trocada = V.vozParaPC(vozes, { salva: 'Luciana' });
chk('voz do celular ausente escolhe masculina em português',
  trocada.nome === 'Microsoft Daniel' && trocada.motivo === 'masculina-pt');
chk('troca de voz é avisada, não silenciosa',
  /não existe neste computador/.test(trocada.aviso) && /Microsoft Daniel/.test(trocada.aviso));
chk('voz salva presente não gera aviso', V.vozParaPC(vozes, { salva: 'Microsoft Daniel' }).aviso === '');
chk('sem português, ainda escolhe uma masculina',
  V.vozParaPC([{ name: 'Microsoft David', lang: 'en-US' }], {}).motivo === 'masculina-outro-idioma');
chk('voz sem gênero no nome cai na primeira disponível',
  V.vozParaPC([{ name: 'Google US English', lang: 'en-US' }], {}).motivo === 'primeira-disponivel');
chk('lista vazia devolve sem voz e explica',
  V.vozParaPC([], {}).voz === null && /nenhuma voz/.test(V.vozParaPC([], {}).aviso));
chk('a prosódia acompanha a voz escolhida',
  V.vozParaPC(vozes, { perfil: 'ultra' }).pitch === 0.5);

/* ---------- 5. Medição de CPU ---------- */
const falsa = (function () {
  let n = 0;
  return () => { n += 4000; return { user: n, system: 0 }; };
})();
let relogio = 0;
const medidaFalsa = V.medirCpu(() => {}, {
  quadros: 100,
  cpuUsage: falsa,
  agora: () => { relogio += 10; return relogio; }
});
chk('medição converte microssegundos em ms',
  medidaFalsa.cpuMs === 4 && medidaFalsa.porQuadroMs === 0.04,
  JSON.stringify(medidaFalsa));
chk('medição calcula o custo por minuto', medidaFalsa.porMinutoMs === 2400);
chk('medição calcula o percentual de um núcleo', medidaFalsa.percentual === 40);
chk('medição marca quando foi realmente medida', medidaFalsa.medido === true);

const real = V.medirCpu((i) => { const a = Math.sin(i / 7); return a * a; }, { quadros: 5000 });
chk('mede de verdade neste processo',
  real.medido === true && isFinite(real.cpuMs) && real.quadros === 5000,
  JSON.stringify(real));
chk('a medição não inclui captura de áudio',
  /sem captura de áudio/.test(real.metodologia));

if (falhas) {
  console.log('\n' + falhas + ' falha(s) na voz do PC.');
  process.exit(1);
}
console.log('\nvoz_pc: ' + V.TABELA.length + ' ações na tabela, escuta em segundo plano, voz e CPU — OK');
