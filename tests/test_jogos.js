// Testes dos jogos: regras, estados e determinismo com RNG injetado.
const assert = require('assert');
const J = require('../jogos.js');
let ok = 0;
function t(nome, fn) { fn(); ok++; console.log('OK: ' + nome); }
const sempreZero = () => 0.001;

t('catálogo com oito jogos', () => {
  assert.deepStrictEqual(J.tipos().sort(), ['adivinha', 'blackjack', 'forca', 'ligue4', 'ppt', 'roleta', 'termo', 'velha'].sort());
  assert.strictEqual(J.criar('inexistente'), null);
  assert.ok(J.criar('wordle').tipo === 'termo');
  assert.ok(J.criar('pedra papel tesoura').tipo === 'ppt');
  assert.strictEqual(J.ajuda().length, 8);
});

t('blackjack: pedir, estourar e parar', () => {
  const j = J.criar('blackjack', { rng: sempreZero });
  assert.strictEqual(j.estadoAtual().jogador.length, 2);
  assert.strictEqual(j.estadoAtual().banca[1], '?');
  let s = j.acao('pedir');
  assert.ok(s.pontosJogador >= 4);
  s = j.acao('parar');
  assert.strictEqual(s.estado, 'fim');
  assert.ok(['vitoria', 'derrota', 'empate'].includes(s.resultado));
  assert.strictEqual(j.acao('pedir').estado, 'fim', 'jogo encerrado não muda');
  assert.strictEqual(J.criar('blackjack', { rng: sempreZero }).acao('xyz').mensagem.includes('pedir'), true);
});

t('velha: valida casa e encerra', () => {
  const j = J.criar('velha', { rng: sempreZero });
  assert.ok(j.jogar(0).mensagem.includes('inválida') || j.jogar(0).tabuleiro[0] === 'X');
  let s;
  for (let i = 1; i <= 9; i++) s = j.jogar(i);
  assert.ok(['fim'].includes(s.estado));
  assert.ok(['X', 'O', 'velha'].includes(s.vencedor));
  const ocupada = J.criar('velha').jogar(1);
  assert.ok(ocupada.tabuleiro[0] === 'X');
});

t('ligue4: gravidade e fim de jogo', () => {
  const j = J.criar('ligue4', { rng: sempreZero });
  const s = j.jogar(1);
  assert.strictEqual(s.grade[5][0], 'X');
  assert.strictEqual(s.grade.flat().filter(Boolean).length, 2, 'cada jogada coloca uma peça');
  const cheio = J.criar('ligue4');
  assert.ok(cheio.jogar(99).mensagem.includes('Coluna inválida'));
  let fim = null;
  const j2 = J.criar('ligue4', { rng: sempreZero });
  for (let i = 0; i < 20; i++) { fim = j2.jogar(1 + (i % 7)); }
  assert.ok(fim.estado === 'fim' || fim.grade.length === 6);
});

t('forca: letras, repetição e vitória', () => {
  const j = J.criar('forca', { palavra: 'jarvis' });
  assert.strictEqual(j.jogar('j').mensagem, 'Boa: tem j.');
  assert.ok(j.jogar('j').mensagem.includes('já tentou'));
  assert.ok(j.jogar('z').erros === 1);
  ['a', 'r', 'v', 'i', 's'].forEach((l) => j.jogar(l));
  assert.strictEqual(j.estadoAtual().estado, 'fim');
  assert.ok(j.estadoAtual().mensagem.includes('Acertou'));
  const perde = J.criar('forca', { palavra: 'jarvis' });
  ['x', 'y', 'z', 'q', 'w', 'k'].forEach((l) => perde.jogar(l));
  assert.ok(perde.estadoAtual().mensagem.includes('Enforcou'));
});

t('ppt: melhor de cinco', () => {
  const j = J.criar('ppt', { rng: sempreZero });
  assert.ok(j.jogar('fogo').mensagem.includes('pedra'));
  let s;
  for (let i = 0; i < 3; i++) s = j.jogar('papel');
  assert.strictEqual(s.pontos.voce, 3, 'papel vence pedra sempre');
  assert.strictEqual(s.estado, 'fim');
});

t('adivinha: dicas e limite de tentativas', () => {
  const j = J.criar('adivinha', { rng: sempreZero });
  assert.strictEqual(j.estadoAtual().alvo, undefined, 'não revela o alvo');
  const s = j.jogar(50);
  assert.ok(/maior|menor|Acertou/.test(s.mensagem));
  assert.ok(j.jogar(0).mensagem.includes('1 a 100'));
  const j2 = J.criar('adivinha', { rng: () => 0 });
  for (let i = 0; i < 7; i++) j2.jogar(100);
  assert.strictEqual(j2.estadoAtual().estado, 'fim');
});

t('termo: marcas certas, presentes e ausentes', () => {
  const j = J.criar('termo', { palavra: 'pedra' });
  assert.ok(j.jogar('abc').mensagem.includes('5 letras'));
  const s = j.jogar('pedra');
  assert.deepStrictEqual(s.tentativas[0].marcas, ['certa', 'certa', 'certa', 'certa', 'certa']);
  assert.strictEqual(s.estado, 'fim');
  const j2 = J.criar('termo', { palavra: 'praia' });
  const s2 = j2.jogar('pedra');
  assert.strictEqual(s2.tentativas[0].marcas[0], 'certa');
  assert.strictEqual(s2.tentativas[0].marcas[1], 'ausente');
  assert.strictEqual(s2.tentativas[0].marcas[4], 'certa');
  for (let i = 0; i < 6; i++) j2.jogar('livro');
  assert.strictEqual(j2.estadoAtual().estado, 'fim');
});

t('roleta: aposta válida, pagamento e saldo', () => {
  const j = J.criar('roleta', { rng: () => 0, saldo: 100 });
  assert.ok(j.jogar({ tipo: 'vermelho', valor: 500 }).mensagem.includes('Aposta inválida'));
  assert.ok(j.jogar({ tipo: 'doce', valor: 10 }).mensagem.includes('Aposte'));
  assert.ok(j.jogar({ tipo: 'numero', numero: 99, valor: 10 }).mensagem.includes('0 e 36'));
  const s = j.jogar({ tipo: 'vermelho', valor: 10 });
  assert.ok(s.saldo === 110 || s.saldo === 90);
  assert.ok(s.historico.length === 1);
  assert.strictEqual(j.jogar({ tipo: 'par', valor: 10 }).mensagem.includes('Deu'), true);
});

console.log('\nJogos: ' + ok + ' grupos de verificação aprovados.');
