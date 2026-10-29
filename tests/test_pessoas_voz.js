// Executa a função real de consulta por voz extraída do app.js, com dependências simuladas.
// Prova que a regex aceita as frases previstas, pergunta quando há ambiguidade e devolve
// null para assuntos gerais (deixando a IA responder).
const assert = require('assert');
const fs = require('fs');

const fonte = fs.readFileSync(__dirname + '/../app.js', 'utf8');
const inicio = fonte.indexOf('function responderPessoaPorVoz');
assert.ok(inicio > 0, 'função de voz encontrada no app.js');
const fim = fonte.indexOf('\n}\n', inicio) + 3;
const trecho = fonte.slice(inicio, fim);

const perfis = [
  { nome: 'Ana', apelido: 'Aninha', relacao: 'irmã', preferencias: 'café sem açúcar' },
  { nome: 'Ana Paula', apelido: '', relacao: 'colega', preferencias: '' },
  { nome: 'Carlos', apelido: 'Cadu', relacao: 'amigo', preferencias: '' }
];
const PESSOAS = {
  resolver(termo) {
    const n = normalizar(termo);
    const exatos = perfis.filter((p) => normalizar(p.nome) === n || (p.apelido && normalizar(p.apelido) === n));
    if (exatos.length === 1) return { tipo: 'exato', perfil: exatos[0], candidatos: exatos };
    if (exatos.length > 1) return { tipo: 'ambiguo', candidatos: exatos };
    const parciais = perfis.filter((p) => normalizar(p.nome).indexOf(n) >= 0 || normalizar(p.apelido).indexOf(n) >= 0);
    if (parciais.length === 1) return { tipo: 'unico', perfil: parciais[0], candidatos: parciais };
    if (parciais.length > 1) return { tipo: 'ambiguo', candidatos: parciais };
    return { tipo: 'nenhum', candidatos: [] };
  },
  descrever(p) { return p.nome + (p.relacao ? ' — ' + p.relacao : ''); }
};
function normalizar(txt) {
  return String(txt == null ? '' : txt).normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
}
const chamadas = [];
const fn = new Function('PESSOAS', 'norm', 'trat', 'registrar',
  trecho + '\nreturn responderPessoaPorVoz;')(PESSOAS, normalizar, () => 'senhor', (t) => chamadas.push(t));

// 1. Nome exato
const r1 = fn('quem é a Ana?');
assert.ok(r1 && r1.fala.indexOf('Ana') === 0, 'perfil exato respondido');
assert.strictEqual(chamadas.length, 1);

// 2. Prefixo "Jarvis" e "o que você sabe sobre"
assert.ok(fn('Jarvis, o que você sabe sobre o Cadu'));
assert.ok(fn('Jarvis quem é o Carlos'));

// 3. Ambiguidade pergunta, não escolhe
const r3 = fn('quem é an');
assert.ok(r3 && r3.candidatos && r3.candidatos.length === 2, 'ambiguidade devolve candidatos');
assert.ok(/Qual deles/.test(r3.fala));

// 4. Assunto geral passa para a IA (sem perfil)
assert.strictEqual(fn('quem é o presidente do Brasil'), null);
assert.strictEqual(fn('o que você sabe sobre física quântica'), null);

// 5. Frases que não são consulta
assert.strictEqual(fn('abre o Spotify'), null);
assert.strictEqual(fn(''), null);
assert.strictEqual(fn('quem é'), null);

console.log('test_pessoas_voz: 5 grupos de verificação passaram');
