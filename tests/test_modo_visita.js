// Modo de visita no PC (1.106.0) — porte de `tool/modo_visita_test.dart`.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const V = require(path.join(__dirname, '..', 'modo_visita.js'));

/* ---------- 1. O prompt tem nome e as proibições que dão sentido ao modo ---------- */
assert.equal(V.NOME_PROMPT, 'Modo de visita');
assert.ok(V.PROMPT.indexOf(V.NOME_PROMPT) >= 0, 'prompt sem o próprio nome');
['português do Brasil', 'Nunca mencione o dono', 'Não invente', 'não peça senhas', 'dados configurados']
  .forEach((regra) => assert.ok(V.PROMPT.indexOf(regra) >= 0, 'prompt sem a regra: ' + regra));

/* ---------- 2. Boas-vindas de app recém-instalado, sem dado do dono ---------- */
assert.ok(V.BOAS_VINDAS.indexOf('JARVIS') >= 0, 'boas-vindas sem o nome');
assert.ok(V.BOAS_VINDAS.indexOf('provedor') >= 0, 'boas-vindas não explicam a falta de provedor');
['conversa', 'memória', 'arquivo', 'ficha'].forEach((proibido) => {
  assert.equal(V.BOAS_VINDAS.toLowerCase().indexOf(proibido), -1, 'boas-vindas expõem ' + proibido);
});

/* ---------- 3. Hora e data vêm do relógio, sem rede ---------- */
{
  const quando = new Date(2026, 10, 21, 9, 5);
  const hora = V.respostaVisita('que horas são?', { agora: quando });
  assert.ok(hora.indexOf('09 horas e 05 minutos') >= 0, 'hora errada: ' + hora);
  const data = V.respostaVisita('que dia é hoje?', { agora: quando });
  assert.ok(data.indexOf('sábado') >= 0 && data.indexOf('21 de novembro de 2026') >= 0, 'data errada: ' + data);
}

/* ---------- 4. Cumprimento e identidade, sem inventar ---------- */
assert.ok(V.respostaVisita('oi').indexOf('posso ajudar') >= 0);
assert.ok(V.respostaVisita('quem é você?').indexOf('JARVIS') >= 0);

/* ---------- 5. Pergunta de conhecimento cai na falta de provedor ---------- */
{
  const culinaria = V.respostaVisita('Jarvis, me fale sobre culinária no geral');
  assert.ok(culinaria.indexOf('não tenho um provedor') >= 0, 'culinária fingiu resposta: ' + culinaria);
  const qualquer = V.respostaVisita('como está tudo Jarvis', { agora: new Date(2026, 10, 21) });
  assert.ok(qualquer.indexOf('não consigo responder') >= 0, 'pergunta livre fingiu resposta: ' + qualquer);
  assert.ok(V.respostaVisita('   ').length > 0, 'texto vazio ficou sem resposta');
}

/* ---------- 6. Nenhuma resposta entrega dado do dono nem manda abrir nada ---------- */
['como está tudo', 'me fale sobre culinária', 'qual a minha agenda', 'o que eu falei ontem']
  .forEach((pergunta) => {
    const texto = V.respostaVisita(pergunta).toLowerCase();
    ['ontem', 'agenda de', 'sua memória', 'abra o app'].forEach((proibido) => {
      assert.equal(texto.indexOf(proibido), -1, '"' + pergunta + '" respondeu "' + proibido + '": ' + texto);
    });
  });

/* ---------- 7. Ajustes do modo de visita sempre vazios ---------- */
{
  const itens = V.ajustes();
  assert.ok(itens.length >= 5, 'ajustes de visita incompletos');
  itens.forEach((item) => {
    assert.ok(item.nome && item.valor, 'item vazio');
    assert.ok(/^(Nenhum|Nenhuma|Vazia|Desligada)/.test(item.valor), item.nome + ' não está vazio: ' + item.valor);
  });
}

/* ---------- 8. Limites não escondem o que o modo faz e não faz ---------- */
{
  const limites = V.LIMITES.join(' ').toLowerCase();
  ['não apaga', 'acesso técnico', 'fechar e reabrir', 'internet', 'dois pins'].forEach((termo) => {
    const achado = termo === 'dois pins'
      ? limites.indexOf('dois pins') >= 0 || limites.indexOf('dois pin') >= 0
      : limites.indexOf(termo) >= 0;
    assert.ok(achado, 'limite sobre "' + termo + '" ausente');
  });
}

console.log('modo_visita: prompt, respostas locais, ajustes vazios e limites — OK');
