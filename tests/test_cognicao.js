'use strict';
const assert = require('node:assert/strict');
const C = require('../cognicao.js');
let ok = 0;
function check(nome, cond) {
  assert.ok(cond, nome);
  console.log('OK: ' + nome);
  ok++;
}

check('versão do módulo', C.VERSAO === '1.0.0');
check('saudação é reconhecida', C.analisar('Bom dia, Jarvis').intencao === 'saudacao');
check('pergunta indireta é reconhecida', C.analisar('será que isso vai funcionar?').pergunta === true);
check('assunto sensível é marcado', C.analisar('minha mãe está no hospital com dor no peito').serio === true);
check('pressa é marcada', C.analisar('preciso disso agora, rápido').pressa === true);
check('informalidade é reconhecida', C.analisar('vc consegue resolver isso pra mim?').informal === true);
check('pesquisa atual é detectada', C.analisar('pesquise o preço do dólar hoje').precisaPesquisa === true);
check('cálculo é detectado', C.analisar('calcule 18% de 245').precisaCalculo === true);
check('ferramenta de arquivo é detectada', C.analisar('analise esse arquivo PDF e veja se tem problema').precisaFerramenta === true);
check('referência conversacional é detectada', C.analisar('continue aquele projeto de ontem').referencia === true);
check('ambiguidade real é detectada', C.analisar('faz isso').ambiguidade === true);
check('ambiguidade some com contexto', C.analisar('faz isso', { temContexto: true }).ambiguidade === false);
check('plano tem cinco etapas', C.analisar('explique e depois corrija o código').plano.length === 5);
check('complexidade cresce', C.analisar('explique, compare e depois teste a correção do arquivo, porque o resultado anterior falhou e preciso validar tudo novamente').complexidade >= 2);
check('prompt interno não manda mostrar o plano', /não o exiba|NÃO O EXIBA/i.test(C.promptPlano(C.analisar('analise o arquivo'))));
check('prompt compacto existe', C.promptPlano(C.analisar('bom dia'), { compacto: true }).indexOf('PLANO INTERNO') === 0);

const generica = C.verificarResposta('Como posso ajudar?', C.analisar('corrija este código'));
check('abertura genérica é reprovada', generica.ok === false && generica.problemas.indexOf('abertura_generica') >= 0);
check('revisão remove abertura genérica', C.revisarFala('Claro! O erro está na linha 4.', C.analisar('corrija'), ['abertura_generica']) === 'O erro está na linha 4.');
check('fala vazia é reprovada', C.verificarResposta('', C.analisar('oi')).problemas.indexOf('vazia') >= 0);
check('humor em assunto sensível é reprovado', C.verificarResposta('Haha, o hospital é uma piada.', C.analisar('minha mãe está no hospital')).problemas.indexOf('humor_em_assunto_sensivel') >= 0);
check('alegação sem ação é reprovada', C.verificarResposta('Já abri o arquivo e executei tudo.', C.analisar('analise o arquivo')).problemas.indexOf('alegacao_sem_execucao') >= 0);
check('fala normal passa', C.verificarResposta('O erro está na linha 4; corrija a variável e teste de novo.', C.analisar('corrija o código')).ok === true);

const hist = [
  { role: 'user', content: 'estamos no projeto Orion' },
  { role: 'assistant', content: 'Certo.' },
  { role: 'user', content: 'qual a previsão do tempo?' },
  { role: 'assistant', content: 'Vou consultar.' },
  { role: 'user', content: 'continue o projeto Orion' }
];
const sel = C.selecionarHistorico(hist, C.analisar('continue o projeto Orion'), 4);
check('histórico mantém a referência do projeto', sel.some((x) => /Orion/.test(x.content)));
// Ordem cronológica: um turno antigo trazido por relevância não pode ir para o fim da lista.
const longo = [];
for (let i = 0; i < 12; i++) longo.push({ role: i % 2 ? 'assistant' : 'user', content: i === 0 ? 'estamos no projeto Orion' : 'mensagem ' + i });
longo.push({ role: 'user', content: 'continue o projeto Orion' });
const selLongo = C.selecionarHistorico(longo, C.analisar('continue o projeto Orion'), 4);
const posicoes = selLongo.map((x) => longo.indexOf(x));
check('histórico sai em ordem cronológica', posicoes.every((p, i) => p >= 0 && (i === 0 || p > posicoes[i - 1])));
check('o turno atual continua por último', selLongo[selLongo.length - 1].content === 'continue o projeto Orion');
check('turno antigo relevante continua incluído', selLongo.indexOf(longo[0]) >= 0);
check('histórico não estoura o teto', selLongo.length <= 8);

// Repetição: o histórico guarda o JSON inteiro do modelo, então a comparação usa a fala do turno.
check('fala do turno guardado sai do JSON', C.falaDoTurno('{"fala":"Feito, senhor.","acao":null}') === 'Feito, senhor.');
check('fala em texto puro continua igual', C.falaDoTurno('Feito.') === 'Feito.');
const repetida = C.verificarResposta('O erro está na linha 4.', C.analisar('corrija o código'), { recentes: [C.falaDoTurno('{"fala":"O erro está na linha 4.","acao":null}')] });
check('repetição é detectada a partir do histórico em JSON', repetida.problemas.indexOf('repetida') >= 0);
check('diagnóstico declara ausência de rede e DOM', C.diagnostico().rede === false && C.diagnostico().dom === false);
console.log('\nCognição: ' + ok + ' verificações aprovadas.');
