// Testes do núcleo de utilidades: cálculo, conversões, saúde, finanças e aleatoriedade.
const assert = require('assert');
const U = require('../utilidades.js');
let ok = 0;
function t(nome, fn) { fn(); ok++; console.log('OK: ' + nome); }

t('cálculo respeita precedência e funções', () => {
  assert.strictEqual(U.avaliar('2+3*4'), 14);
  assert.strictEqual(U.avaliar('(2+3)*4'), 20);
  assert.strictEqual(U.avaliar('2^10'), 1024);
  assert.strictEqual(U.avaliar('5!'), 120);
  assert.strictEqual(U.avaliar('raiz(16)+1'), 5);
  assert.strictEqual(U.avaliar('-3+10'), 7);
  assert.ok(Math.abs(U.avaliar('pi') - Math.PI) < 1e-9);
  assert.strictEqual(U.avaliar('1/0'), null);
  assert.strictEqual(U.avaliar('2+'), null);
  assert.strictEqual(U.avaliar('alert(1)'), null, 'não executa código');
});

t('matemática básica', () => {
  assert.strictEqual(U.fatorial(5), 120);
  assert.strictEqual(U.fibonacci(10), 55);
  assert.deepStrictEqual(U.fatorar(360), [2, 2, 2, 3, 3, 5]);
  assert.strictEqual(U.mdc(12, 18), 6);
  assert.strictEqual(U.mmc(4, 6), 12);
  const eq = U.equacao2(1, -5, 6);
  assert.deepStrictEqual(eq.raizes.sort((a, b) => a - b), [2, 3]);
  assert.strictEqual(U.equacao2(1, 0, 1).tipo, 'complexas');
  assert.strictEqual(U.primos(10).join(','), '2,3,5,7');
});

t('estatística e porcentagem', () => {
  const e = U.estatistica([2, 4, 4, 4, 5, 5, 7, 9]);
  assert.strictEqual(e.media, 5);
  assert.strictEqual(e.mediana, 4.5);
  assert.strictEqual(e.max, 9);
  assert.strictEqual(U.porcentagem(20, 250).valor, 50);
  assert.strictEqual(U.regraDeTres(2, 10, 4), 20);
});

t('matrizes', () => {
  assert.deepStrictEqual(U.matriz.somar([[1, 2]], [[3, 4]]), [[4, 6]]);
  assert.deepStrictEqual(U.matriz.multiplicar([[1, 2], [3, 4]], [[2, 0], [1, 2]]), [[4, 4], [10, 8]]);
  assert.strictEqual(U.matriz.determinante([[1, 2], [3, 4]]), -2);
  assert.strictEqual(U.matriz.determinante([[6, 1, 1], [4, -2, 5], [2, 8, 7]]), -306);
  assert.deepStrictEqual(U.matriz.identidade(2), [[1, 0], [0, 1]]);
});

t('bases numéricas', () => {
  assert.strictEqual(U.base('255', 'dec', 'hex'), 'FF');
  assert.strictEqual(U.base('1010', 'bin', 'dec'), '10');
  assert.strictEqual(U.base('ff', 'hex', 'bin'), '11111111');
  assert.strictEqual(U.base('x', 'dec', 'hex'), null);
});

t('conversões de unidade e temperatura', () => {
  assert.ok(Math.abs(U.converter(10, 'km', 'milha').valor - 6.21371) < 1e-4);
  assert.strictEqual(U.converter(1, 'kg', 'g').valor, 1000);
  assert.strictEqual(U.converter(100, 'c', 'f').valor, 212);
  assert.strictEqual(U.converter(0, 'c', 'k').valor, 273.15);
  assert.strictEqual(U.converter(1, 'gb', 'mb').valor, 1024);
  assert.strictEqual(U.converter(60, 'min', 'h').valor, 1);
  assert.strictEqual(U.converter(1, 'litro', 'ml').valor, 1000);
  assert.strictEqual(U.converter(10, 'kg', 'km'), null);
});

t('saúde', () => {
  const imc = U.imc(80, 1.8);
  assert.ok(Math.abs(imc.valor - 24.691) < 0.01);
  assert.strictEqual(imc.classe, 'peso normal');
  assert.strictEqual(U.imc(80, 180).valor, imc.valor, 'aceita altura em cm');
  assert.strictEqual(U.imc(120, 1.6).classe, 'obesidade grau III');
  assert.strictEqual(U.taxaMetabolica('m', 80, 180, 30).bmr, 1780);
  assert.strictEqual(U.taxaMetabolica('f', 60, 165, 30).bmr, 1320.25);
  assert.deepStrictEqual(Object.keys(U.calorias(1780, 1.55)).sort(), ['ganhar', 'manutencao', 'perder']);
  assert.strictEqual(U.calorias(1780, 1.55).manutencao, 2759);
});

t('finanças', () => {
  assert.strictEqual(U.jurosSimples(1000, 1, 12).montante, 1120);
  const jc = U.jurosCompostos(1000, 1, 12);
  assert.ok(Math.abs(jc.montante - 1126.825) < 0.01);
  const p = U.parcelaPrice(1000, 1, 10);
  assert.ok(Math.abs(p.parcela - 105.582) < 0.01);
  assert.strictEqual(U.roi(150, 100).percentual, 50);
  assert.strictEqual(U.moeda(10, 'USD', 'BRL', { USD: 5, BRL: 1 }).valor, 50);
});

t('aleatoriedade segura e senhas', () => {
  for (let i = 0; i < 50; i++) { const n = U.numeroAleatorio(1, 6); assert.ok(n >= 1 && n <= 6); }
  const s = U.senha(20);
  assert.strictEqual(s.length, 20);
  assert.ok(/[a-z]/.test(s) && /[A-Z]/.test(s) && /\d/.test(s), 'mistura classes por padrão');
  assert.strictEqual(U.senha(10, { simbolos: false, maiusculas: false }).length, 10);
  assert.strictEqual(U.forcaSenha('abc').nivel, 'fraca');
  assert.strictEqual(U.forcaSenha('A9!kLm2#Qw7Pz4Rt').nivel, 'forte');
  const lista = U.embaralhar([1, 2, 3, 4]);
  assert.strictEqual(lista.length, 4);
  assert.deepStrictEqual([...lista].sort(), [1, 2, 3, 4]);
});

t('interpretação de comandos cotidianos', () => {
  assert.strictEqual(U.interpretar('quanto é 2+2').valor, 4);
  assert.strictEqual(U.interpretar('quanto é 20% de 250').valor, 50);
  assert.strictEqual(U.interpretar('converter 10 km para milhas').tipo, 'conversao');
  assert.ok(/IMC é/.test(U.interpretar('imc 80 kg 1,80 m').texto));
  assert.ok(/Montante/.test(U.interpretar('juros compostos de 1000 a 1% por 12 meses').texto));
  assert.strictEqual(U.interpretar('senha de 16').valor.length, 16);
  assert.ok(U.interpretar('número aleatório entre 1 e 10').valor >= 1);
  assert.strictEqual(U.interpretar('fatorial de 5').valor, 120);
  assert.strictEqual(U.interpretar('raiz quadrada de 81').valor, 9);
  assert.strictEqual(U.interpretar('nada a ver'), null);
});

console.log('\nUtilidades: ' + ok + ' grupos de verificação aprovados.');
