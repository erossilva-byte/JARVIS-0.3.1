// Testes do cadastro de pessoas (pessoas.js): persistência, busca, ambiguidade e privacidade.
const assert = require('assert');
const P = require('../pessoas.js');

function storeFalso() {
  const m = new Map();
  return {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => { m.set(k, String(v)); },
    removeItem: (k) => { m.delete(k); },
    _mapa: m
  };
}
const store = storeFalso();
let t = 1700000000000;
P.configurar({ store, relogio: () => (t += 1000) });

// ---------- 1. Nome é obrigatório; o resto é opcional ----------
assert.strictEqual(P.salvar({ nome: '   ' }).ok, false);
const ana = P.salvar({ nome: 'Ana' });
assert.ok(ana.ok, 'perfil mínimo com só o nome');
assert.strictEqual(ana.perfil.nome, 'Ana');
assert.strictEqual(P.listar().length, 1);
console.log('OK: nome obrigatório e perfil mínimo');

// ---------- 2. Campos são limpos e limitados ----------
const longo = P.salvar({ nome: 'Bruno', observacoes: '<b>' + 'x'.repeat(900) + '</b>' });
assert.ok(longo.ok);
assert.ok(longo.perfil.observacoes.length <= 800, 'limite de observações');
assert.ok(longo.perfil.observacoes.indexOf('<') < 0, 'tags removidas');
console.log('OK: campos saneados e limitados');

// ---------- 3. Edição não cria perfil novo ----------
const antes = P.listar().length;
const editado = P.salvar({ id: ana.perfil.id, nome: 'Ana', apelido: 'Aninha', preferencias: 'café sem açúcar' });
assert.ok(editado.ok);
assert.strictEqual(P.listar().length, antes, 'editar não duplica');
assert.strictEqual(P.obter(ana.perfil.id).apelido, 'Aninha');
console.log('OK: edição no mesmo perfil');

// ---------- 4. Nomes parecidos nunca são fundidos nem escolhidos sozinhos ----------
P.salvar({ nome: 'Ana Paula', apelido: 'Paulinha' });
P.salvar({ nome: 'Carlos', apelido: 'Cadu' });
const amb = P.resolver('an'); // parcial: Ana e Ana Paula, nenhum exato
assert.strictEqual(amb.tipo, 'ambiguo');
assert.strictEqual(amb.candidatos.length, 2);
assert.ok(!amb.perfil, 'ambiguidade não devolve perfil único');
assert.strictEqual(P.resolver('Ana Paula').tipo, 'exato');
assert.strictEqual(P.resolver('cadu').tipo, 'exato');
assert.strictEqual(P.resolver('zzz').tipo, 'nenhum');
console.log('OK: ambiguidade resolvida por pergunta, nunca por palpite');

// ---------- 5. Busca por nome e apelido, sem acento ----------
assert.strictEqual(P.buscar('aninha').length, 1);
assert.strictEqual(P.buscar('ANA').length, 2);
assert.strictEqual(P.buscar('carlos').length, 1);
assert.strictEqual(P.buscar('').length, P.listar().length);
const acento = P.salvar({ nome: 'José' });
assert.ok(acento.ok);
assert.strictEqual(P.buscar('jose').length, 1);
P.remover(acento.perfil.id);
console.log('OK: busca por nome/apelido ignorando acentos');

// ---------- 6. Descrição não inventa o que não foi cadastrado ----------
const desc = P.descrever(P.obter(ana.perfil.id));
assert.ok(desc.indexOf('Aninha') > 0 && desc.indexOf('café sem açúcar') > 0);
const vazio = P.descrever(P.salvar({ nome: 'Sem dados' }).perfil);
assert.ok(vazio.indexOf('Nenhuma informação além do nome') > 0, vazio);
console.log('OK: descrição só com dados cadastrados');

// ---------- 7. Contexto da IA não leva contato ----------
P.salvar({ id: P.obter(ana.perfil.id).id, nome: 'Ana', apelido: 'Aninha', contato: '+55 11 99999-0000', relacao: 'irmã' });
const ctx = P.contexto();
assert.ok(ctx.indexOf('Ana') > 0);
assert.ok(ctx.indexOf('99999') < 0, 'telefone fora do contexto da IA');
console.log('OK: contato nunca entra no contexto da IA');

// ---------- 8. Persistência: fecha e reabre (novo módulo apontando para o mesmo store) ----------
const bruto = store.getItem(P.CHAVE);
assert.ok(bruto && JSON.parse(bruto).length === P.listar().length);
console.log('OK: perfis gravados no armazenamento');

// ---------- 9. Exportar e importar sem duplicar ----------
const json = P.exportar();
const total = P.listar().length;
const imp = P.importar(json);
assert.ok(imp.ok);
assert.strictEqual(imp.importados, 0, 'reexportar não duplica');
assert.strictEqual(P.listar().length, total);
const outro = JSON.parse(json);
outro.perfis = [{ nome: 'Dora' }];
const imp2 = P.importar(JSON.stringify(outro));
assert.strictEqual(imp2.importados, 1);
assert.strictEqual(P.resolver('Dora').tipo, 'exato');
assert.strictEqual(P.importar('não é json').ok, false);
console.log('OK: exportação e importação idempotente');

// ---------- 10. Remoção e limpeza ----------
const id = P.resolver('Dora').perfil.id;
assert.ok(P.remover(id).ok);
assert.strictEqual(P.resolver('Dora').tipo, 'nenhum');
assert.ok(P.remover(id).ok === false, 'remover duas vezes falha');
assert.ok(P.limparTudo());
assert.strictEqual(P.listar().length, 0);
console.log('OK: remoção e limpeza total');

// ---------- 11. Reabrir o aplicativo mantém os perfis ----------
P.limparTudo();
P.salvar({ nome: 'João Silva', apelido: 'Jota', observacoes: 'amigo da faculdade' });
P.salvar({ nome: 'João Souza', observacoes: 'vizinho' });
delete require.cache[require.resolve('../pessoas.js')];
const Preaberto = require('../pessoas.js');
Preaberto.configurar({ store, relogio: () => t });
assert.strictEqual(Preaberto.listar().length, 2, 'perfis sobrevivem ao reinício do app');
const joao = Preaberto.resolver('João');
assert.strictEqual(joao.tipo, 'ambiguo', 'dois "João" não são escolhidos sozinhos');
assert.strictEqual(joao.candidatos.length, 2);
console.log('OK: persistência após reabrir e ambiguidade entre nomes iguais');

// ---------- 12. Editar e apagar um perfil não toca no outro ----------
const lista = Preaberto.listar();
const alvoA = lista.filter((x) => x.nome === 'João Silva')[0];
const alvoB = lista.filter((x) => x.nome === 'João Souza')[0];
const obsB = alvoB.observacoes;
Preaberto.salvar({ id: alvoA.id, nome: 'João Silva', apelido: 'Jota', observacoes: 'mudou de cidade' });
assert.strictEqual(Preaberto.obter(alvoB.id).observacoes, obsB, 'perfil vizinho intacto');
Preaberto.remover(alvoB.id);
assert.ok(Preaberto.obter(alvoA.id), 'apagar um não apaga o outro');
console.log('OK: isolamento entre perfis');

// ---------- 13. Falha de gravação é devolvida, não engolida ----------
const quebrado = {
  getItem: (k) => store.getItem(k),
  setItem: () => { throw new Error('quota cheia'); },
  removeItem: () => {}
};
delete require.cache[require.resolve('../pessoas.js')];
const Pfalha = require('../pessoas.js');
Pfalha.configurar({ store: quebrado, relogio: () => t });
const falhou = Pfalha.salvar({ nome: 'Sem espaço' });
assert.strictEqual(falhou.ok, false);
assert.ok(/gravar/i.test(falhou.erro), falhou.erro);
console.log('OK: falha de armazenamento informada');

// ---------- 14. Termo vazio não resolve ninguém ----------
delete require.cache[require.resolve('../pessoas.js')];
const P2 = require('../pessoas.js');
P2.configurar({ store, relogio: () => t });
assert.strictEqual(P2.resolver('   ').tipo, 'nenhum');
assert.ok(P2.contexto().indexOf('João Silva') > 0);
console.log('OK: termo vazio não resolve ninguém');

// ---------- 15. Contexto limitado e sem telefone/observações ----------
P2.limparTudo();
for (let i = 1; i <= 14; i++) P2.salvar({ nome: 'Pessoa ' + i, contato: '+55 11 99999-000' + i, observacoes: 'segredo ' + i });
const ctx2 = P2.contexto();
assert.strictEqual(ctx2.split('\n').length, 12, 'contexto limitado a 12 perfis');
assert.ok(ctx2.indexOf('99999') < 0, 'telefone fora do contexto');
assert.ok(ctx2.toLowerCase().indexOf('segredo') < 0, 'observações fora do contexto');
console.log('OK: contexto da IA limitado e sem dados sensíveis');

// ---------- 16. Importação ignora entradas sem nome ----------
const antesImp = P2.listar().length;
const impFinal = P2.importar(JSON.stringify({ perfis: [{ nome: '' }, { nome: 'Válida' }] }));
assert.ok(impFinal.ok);
assert.strictEqual(impFinal.importados, 1);
assert.strictEqual(P2.listar().length, antesImp + 1);
P2.limparTudo();
assert.strictEqual(P2.listar().length, 0);
console.log('OK: importação valida nomes e limpeza final');

console.log('test_pessoas: 16 grupos de verificação passaram');
