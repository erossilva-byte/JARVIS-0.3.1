const assert = require('assert');
const S = require('../seguranca.js');

let ok = 0;
function grupo(nome, fn) { fn(); ok++; console.log('OK: ' + nome); }

grupo('configuração normalizada com limites seguros', () => {
  const c = S.normalizar({ modo: 'inventado', timeoutSeg: 1, maxTentativas: 99, esperaMaxSeg: 9999 });
  assert.strictEqual(c.modo, 'pin');
  assert.strictEqual(c.timeoutSeg, 15);
  assert.strictEqual(c.maxTentativas, 10);
  assert.strictEqual(c.esperaMaxSeg, 300);
  assert.strictEqual(S.normalizar({}).modo, 'pin');
});

grupo('modos exigem as etapas certas', () => {
  assert.deepStrictEqual(S.etapas('bio+nfc'), ['bio', 'nfc']);
  assert.deepStrictEqual(S.etapas('nfc+pin'), ['nfc', 'pin']);
  assert.deepStrictEqual(S.etapas('pin'), ['pin']);
  assert.strictEqual(S.rotulo('bio|nfc'), 'Biometria ou NFC');
});

grupo('duas etapas só liberam com as duas provas', () => {
  assert.strictEqual(S.avaliarProvas('bio+nfc', { bio: true }).ok, false);
  assert.deepStrictEqual(S.avaliarProvas('bio+nfc', { bio: true }).faltam, ['nfc']);
  assert.strictEqual(S.avaliarProvas('bio+nfc', { bio: true, nfc: true }).ok, true);
  assert.strictEqual(S.avaliarProvas('nfc+pin', { nfc: true }).ok, false);
});

grupo('"ou" aceita qualquer alternativa', () => {
  assert.strictEqual(S.avaliarProvas('bio|nfc', { nfc: true }).ok, true);
  assert.strictEqual(S.avaliarProvas('bio|nfc', { bio: true }).ok, true);
  assert.strictEqual(S.avaliarProvas('bio|nfc', {}).ok, false);
});

grupo('PIN ou biometria/NFC libera por qualquer fator disponível', () => {
  assert.deepStrictEqual(S.etapas('pin|bio'), ['pin', 'bio']);
  assert.deepStrictEqual(S.etapas('pin|nfc'), ['pin', 'nfc']);
  assert.deepStrictEqual(S.etapas('pin|bio|nfc'), ['pin', 'bio', 'nfc']);
  assert.strictEqual(S.avaliarProvas('pin|bio', { pin: true }).ok, true);
  assert.strictEqual(S.avaliarProvas('pin|bio', { bio: true }).ok, true);
  assert.strictEqual(S.avaliarProvas('pin|bio', {}).ok, false);
  assert.deepStrictEqual(S.avaliarProvas('pin|bio', {}).faltam, ['pin ou bio']);
  assert.strictEqual(S.avaliarProvas('pin|nfc', { nfc: true }).ok, true);
  assert.strictEqual(S.avaliarProvas('pin|bio|nfc', { nfc: true }).ok, true);
  assert.strictEqual(S.modoViavel('pin|bio', { bio: false }).ok, true);
  assert.strictEqual(S.modoViavel('pin|nfc', { nfc: false }).ok, true);
  assert.strictEqual(S.modoViavel('bio|nfc', { bio: false, nfc: true }).ok, true);
  assert.strictEqual(S.modoViavel('bio|nfc', { bio: false, nfc: false }).ok, false);
  assert.strictEqual(S.normalizar({ modo: 'pin+bio' }).modo, 'bio+pin');
  assert.strictEqual(S.normalizar({ modo: 'pin+nfc' }).modo, 'nfc+pin');
});

grupo('leitura de tag normaliza UID e sinaliza clonagem', () => {
  const simples = S.tagDeLeitura({ uid: '04:a2:33:1f', tech: ['NfcA'] }, { uidHash: 'abc123' });
  assert.strictEqual(simples.ok, true);
  assert.strictEqual(simples.tag.uidHash, 'ABC123');
  assert.strictEqual(simples.tag.ult4, '331F');
  assert.ok(/clonada/.test(simples.aviso));
  const iso = S.tagDeLeitura({ uid: '04AABBCC', tech: ['IsoDep'] }, { uidHash: 'ff' });
  assert.strictEqual(iso.tag.criptografica, true);
  assert.ok(/ISO-DEP/.test(iso.aviso));
  assert.strictEqual(S.tagDeLeitura({ uid: '' }).ok, false);
});

grupo('tag desconhecida, desativada e bloqueada são recusadas', () => {
  const tags = S.normalizar({ tags: [
    { id: 'a', nome: 'Chave', uidHash: 'AA11', ativa: true },
    { id: 'b', nome: 'Velha', uidHash: 'BB22', ativa: false },
    { id: 'c', nome: 'Perdida', uidHash: 'CC33', bloqueada: true }
  ] }).tags;
  assert.strictEqual(S.acharTag(tags, 'AA11').ok, true);
  assert.ok(/desconhecida/i.test(S.acharTag(tags, 'ZZ99').motivo));
  assert.ok(/desativada/i.test(S.acharTag(tags, 'BB22').motivo));
  assert.ok(/bloqueada/i.test(S.acharTag(tags, 'CC33').motivo));
});

grupo('tentativas crescem com teto e param no limite', () => {
  assert.strictEqual(S.tentativa(1, 5, 30).esperaSeg, 1);
  assert.strictEqual(S.tentativa(2, 5, 30).esperaSeg, 2);
  assert.strictEqual(S.tentativa(6, 5, 30).esperaSeg, 30);
  assert.strictEqual(S.tentativa(5, 5, 30).bloqueado, true);
  assert.ok(/Limite de 5/.test(S.tentativa(5, 5, 30).aviso));
});

grupo('histórico nunca guarda PIN nem UID bruto', () => {
  const e = S.evento({ metodo: 'nfc', resultado: 'negado', detalhe: 'UID 04AABBCCDD recusado; pin 483920' }, 1000);
  assert.strictEqual(e.t, 1000);
  assert.ok(!/04AABBCCDD/.test(e.detalhe));
  assert.ok(!/483920/.test(e.detalhe));
  assert.strictEqual(S.evento({ metodo: 'pin', resultado: 'ok' }).detalhe, 'acesso liberado');
  assert.strictEqual(S.evento({ metodo: 'x', resultado: 'outro' }).resultado, 'negado');
});

grupo('histórico mantém ordem e limite', () => {
  let l = [];
  for (let i = 0; i < 70; i++) l = S.historico(l, S.evento({ metodo: 'pin', resultado: 'ok' }, i), 60);
  assert.strictEqual(l.length, 60);
  assert.strictEqual(l[0].t, 69);
});

grupo('disponibilidade não esconde limitações', () => {
  const semNada = S.disponibilidade({});
  assert.strictEqual(semNada.bio, false);
  assert.ok(semNada.avisos.length >= 2);
  const soDigital = S.disponibilidade({ biometria: true, rosto: false, nfc: true });
  assert.ok(soDigital.avisos.some((a) => /facial/.test(a)));
  const rostoSemBio = S.disponibilidade({ rosto: true, biometria: false });
  assert.ok(rostoSemBio.avisos.some((a) => /hardware facial/.test(a)));
});

grupo('modo inviável é recusado com motivo', () => {
  assert.strictEqual(S.modoViavel('bio', { bio: false }).ok, false);
  assert.ok(/biometria/.test(S.modoViavel('bio', { bio: false }).motivo));
  assert.strictEqual(S.modoViavel('nfc', { nfc: false }).ok, false);
  assert.strictEqual(S.modoViavel('pin', {}).ok, true);
});

grupo('tags duplicadas são descartadas e UID exibido é mascarado', () => {
  const c = S.normalizar({ tags: [{ uidHash: 'AA' }, { uidHash: 'AA' }] });
  assert.strictEqual(c.tags.length, 1);
  assert.strictEqual(S.mascararUid('04AABBCCDD'), '•••• CCDD');
  assert.strictEqual(S.mascararUid(''), '—');
});

console.log('\nSegurança: ' + ok + ' grupos de verificação aprovados.');
