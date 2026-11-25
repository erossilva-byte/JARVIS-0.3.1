// Fichas de pessoas no PC (1.105.0): consentimento, ambiguidade e bloco seguro.
//
// Portado de `flutter_app/tool/pessoas_conversa_test.dart` e das regras de
// `core/pessoas.dart`: o teste do celular virou teste de Node sobre o mesmo
// `pessoas.js` que o aplicativo do PC carrega.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const P = require(path.join(__dirname, '..', 'pessoas.js'));

function storeFalso() {
  const mapa = new Map();
  return {
    getItem: (k) => (mapa.has(k) ? mapa.get(k) : null),
    setItem: (k, v) => { mapa.set(k, String(v)); },
    removeItem: (k) => { mapa.delete(k); }
  };
}
let t = 1700000000000;
P.configurar({ store: storeFalso(), relogio: () => (t += 1000) });
P.limparTudo();

function pessoa(nome, extra) {
  return Object.assign({
    id: nome.toLowerCase(),
    nome: nome,
    apelido: '',
    relacao: '',
    contato: '',
    preferencias: '',
    observacoes: '',
    compromissos: '',
    historico: '',
    consentimento: true
  }, extra || {});
}

const ana = pessoa('Ana', {
  apelido: 'Aninha', relacao: 'irmã', contato: '+55 11 99999-0000',
  preferencias: 'café sem açúcar', observacoes: 'segredo de família',
  compromissos: 'consulta dia 20', historico: 'almoçamos em outubro'
});
const anaPaula = pessoa('Ana Paula', { relacao: 'prima' });
const carlos = pessoa('Carlos', { apelido: 'Cadu', relacao: 'colega' });

/* ---------- 1. Só o bloco seguro entra na conversa ---------- */
{
  const r = P.blocoParaConsulta([ana, carlos], 'quem é a Ana?');
  assert.equal(r.tipo, 'detalhe', 'tipo errado: ' + r.tipo);
  assert.ok(r.bloco.indexOf('Nome: Ana') >= 0, 'nome não foi enviado');
  assert.ok(r.bloco.indexOf('Apelido: Aninha') >= 0, 'apelido não foi enviado');
  assert.ok(r.bloco.indexOf('Relação: irmã') >= 0 && r.bloco.indexOf('café sem açúcar') >= 0, 'dados autorizados ausentes');
  assert.equal(r.bloco.indexOf('99999'), -1, 'telefone vazou para a conversa');
  assert.equal(r.bloco.indexOf('segredo'), -1, 'observações vazaram para a conversa');
  assert.equal(r.bloco.indexOf('consulta dia 20'), -1, 'compromisso vazou para a conversa');
  assert.equal(r.bloco.indexOf('almoçamos'), -1, 'histórico vazou para a conversa');
  assert.ok(r.bloco.indexOf('não invente') >= 0, 'sem instrução contra invenção');
  assert.deepEqual(r.nomes, ['Ana'], 'ficha citada não registrada');
}

/* ---------- 2. Nome desconhecido: manda dizer que não encontrou ---------- */
{
  const r = P.blocoParaConsulta([ana, carlos], 'quem é a Maria?');
  assert.equal(r.tipo, 'ausente', 'ausência não sinalizada');
  assert.ok(r.bloco.indexOf('nenhuma ficha') >= 0, 'não instruiu ausência');
  assert.ok(r.bloco.indexOf('Diga que não encontrou') >= 0);
  assert.equal(r.bloco.indexOf('Ana'), -1, 'misturou pessoa não citada');
  assert.equal(r.nomes.length, 0);
}

/* ---------- 3. Ambiguidade: pergunta em vez de escolher ---------- */
{
  const r = P.blocoParaConsulta([ana, anaPaula, carlos], 'quem é Ana?');
  assert.equal(r.tipo, 'ambiguo', 'ambiguidade não sinalizada');
  assert.ok(r.bloco.indexOf('mais de uma ficha') >= 0);
  assert.ok(r.bloco.indexOf('Ana') >= 0 && r.bloco.indexOf('Ana Paula') >= 0, 'candidatos ausentes');
  assert.ok(r.bloco.indexOf('Pergunte qual') >= 0, 'não pediu desambiguação');
  assert.equal(r.nomes.length, 2);
}

/* ---------- 4. Nome completo vence o primeiro nome ---------- */
{
  const r = P.blocoParaConsulta([ana, anaPaula], 'o que você sabe sobre Ana Paula?');
  assert.equal(r.tipo, 'detalhe');
  assert.ok(r.bloco.indexOf('Nome: Ana Paula') >= 0, 'nome completo não teve prioridade');
  assert.equal(r.bloco.indexOf('Apelido: Aninha'), -1, 'trouxe a Ana errada');
}

/* ---------- 5. Apelido resolve ---------- */
{
  const r = P.blocoParaConsulta([ana, carlos], 'me fala do Cadu');
  assert.equal(r.tipo, 'detalhe');
  assert.ok(r.bloco.indexOf('Nome: Carlos') >= 0, 'apelido não resolveu');
}

/* ---------- 6. Conversa que não é sobre pessoa não recebe bloco ---------- */
{
  const r = P.blocoParaConsulta([ana], 'qual a capital da França?');
  assert.equal(r.tipo, 'nenhum');
  assert.equal(r.bloco, '', 'bloco entrou sem motivo');
}

/* ---------- 7. Sem fichas e com pergunta de pessoa: ausência explícita ---------- */
{
  const r = P.blocoParaConsulta([], 'quem é o João?');
  assert.equal(r.tipo, 'ausente');
  assert.ok(r.bloco.indexOf('nenhuma ficha') >= 0);
}

/* ---------- 8. Consentimento revogado tira a ficha da conversa ---------- */
{
  P.limparTudo();
  P.salvar({ nome: 'Carlos', apelido: 'Cadu', consentimento: true });
  const revogada = pessoa('Beatriz', { consentimento: false });
  const r = P.blocoParaConsulta([revogada], 'quem é a Beatriz?');
  assert.equal(r.tipo, 'ausente', 'ficha sem consentimento deveria ficar fora');
  assert.equal(r.bloco.indexOf('Beatriz'), -1, 'ficha revogada foi enviada');

  // E o contexto compacto também respeita a revogação.
  const contexto = P.contexto();
  assert.ok(contexto.indexOf('Carlos') >= 0, 'contexto perdeu perfil permitido');
  assert.equal(contexto.indexOf('Beatriz'), -1, 'contexto levou perfil sem consentimento');
}

/* ---------- 9. Cadastro exige consentimento e guarda a decisão ---------- */
{
  P.limparTudo();
  const sem = P.salvar({ nome: 'Sem consentimento' });
  assert.equal(sem.ok, false, 'gravou ficha sem consentimento');
  const com = P.salvar({ nome: 'Com consentimento', consentimento: true, contato: '11 90000-0000' });
  assert.equal(com.ok, true);
  assert.equal(P.obter(com.perfil.id).consentimento, true, 'consentimento não foi guardado');
  assert.equal(P.revogarConsentimento(com.perfil.id).ok, true, 'revogação falhou');
  assert.equal(P.obter(com.perfil.id).consentimento, false, 'consentimento não foi revogado');
  assert.equal(P.resolver('Com consentimento').tipo, 'exato', 'ficha revogada foi apagada');
  const ctx = P.contexto();
  assert.equal(ctx.indexOf('Com consentimento'), -1, 'perfil ainda entra no contexto depois da revogação');
}

/* ---------- 10. Ambiguidade também na resolução de nome ---------- */
{
  P.limparTudo();
  P.salvar({ nome: 'João Silva', consentimento: true });
  P.salvar({ nome: 'João Souza', consentimento: true });
  const r = P.resolver('João');
  assert.equal(r.tipo, 'ambiguo', 'dois “João” deveriam ser ambiguidade');
  assert.equal(r.candidatos.length, 2);
  assert.equal(r.perfil, undefined, 'ambiguidade não pode devolver perfil único');
}

P.limparTudo();
console.log('pessoas_conversa: bloco seguro, consentimento e ambiguidade — OK');
