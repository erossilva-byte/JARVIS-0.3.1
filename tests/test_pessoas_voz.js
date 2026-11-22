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
const salvos = [];
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
  descrever(p) { return p.nome + (p.relacao ? ' — ' + p.relacao : ''); },
  interpretarCadastroVoz(frase) {
    if (!/cadastre (?:meu amigo )?marcelo/i.test(frase)) return null;
    const peso = String(frase).match(/peso\s*(?:de|é|e)?\s*(\d{1,3}(?:[,.]\d{1,2})?)\s*kg/i);
    const altura = String(frase).match(/altura\s*(?:de|é|e)?\s*(\d{1,3}(?:[,.]\d{1,2})?)\s*(cm|m)/i);
    const idade = String(frase).match(/idade\s*(?:de|é|e)?\s*(\d{1,3})/i);
    const dados = { nome: 'Marcelo', relacao: 'amigo' };
    if (idade) { dados.idadeBase = idade[1]; dados.idadeEm = '2026-11-09'; }
    if (peso) dados.pesoKg = peso[1].replace(',', '.');
    if (altura) dados.alturaCm = String(Math.round(Number(altura[1].replace(',', '.')) * (altura[2] === 'm' ? 100 : 1)));
    return { ok: true, dados, idadeAproximada: !!idade };
  },
  salvar(dados) {
    salvos.push(dados);
    const atual = dados.id ? perfis.find((p) => p.id === dados.id) : null;
    const perfil = atual ? Object.assign(atual, dados) : Object.assign({ id: 'novo-' + salvos.length }, dados);
    if (!atual) perfis.push(perfil);
    return { ok: true, perfil };
  },
  idadeDetalhada() { return { anos: 27, meses: 0, aproximada: true }; }
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
const criado = fn('cadastre meu amigo Marcelo, idade 27 anos, peso 72,5 kg e altura 1,78 m');
assert.ok(criado && /Cadastrei Marcelo/.test(criado.fala), 'cadastro por voz confirma a pessoa');
assert.strictEqual(salvos.length, 1, 'salva uma ficha');
assert.strictEqual(salvos[0].pesoKg, '72.5');
assert.strictEqual(salvos[0].alturaCm, '178');

// Repetir o cadastro com o mesmo nome exato atualiza a ficha, sem duplicar.
const atualizado = fn('cadastre meu amigo Marcelo, idade 28 anos, peso 74 kg e altura 1,80 m');
assert.ok(atualizado && /Cadastrei Marcelo/.test(atualizado.fala));
assert.strictEqual(salvos[1].id, 'novo-1', 'usa o ID do perfil existente');
assert.strictEqual(perfis.filter((p) => p.nome === 'Marcelo').length, 1, 'não duplica pessoa');
assert.strictEqual(perfis.find((p) => p.id === 'novo-1').pesoKg, '74');

// Nome ambíguo não deve gravar nem escolher um perfil automaticamente.
perfis.push({ id: 'marcelo-2', nome: 'Marcelo', relacao: 'colega' });
const antesAmbiguidade = salvos.length;
const ambiguo = fn('cadastre Marcelo, idade 29 anos');
assert.ok(ambiguo && /mais de uma pessoa/i.test(ambiguo.fala));
assert.strictEqual(salvos.length, antesAmbiguidade, 'não altera quando há homônimos');

console.log('test_pessoas_voz: consulta, cadastro, atualização e ambiguidade passaram');
