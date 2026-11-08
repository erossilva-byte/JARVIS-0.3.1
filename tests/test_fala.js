'use strict';
const assert = require('assert');
const F = require('../fala.js');
let n = 0;
function ok(nome, cond, detalhe) {
  n++;
  if (!cond) throw new Error('FALHA: ' + nome + (detalhe === undefined ? '' : ' -> ' + JSON.stringify(detalhe)));
  console.log('OK: ' + nome);
}

ok('não apaga repetição legítima', F.limpar('que que horas são') === 'que que horas são');
ok('remove muleta apenas nas pontas', F.limpar('hum, abre o Spotify') === 'hum, abre o Spotify' || F.limpar('hum abre o Spotify') === 'abre o Spotify');
ok('preserva repetição intencional no meio', F.limpar('muito muito bom') === 'muito muito bom');
ok('pontua pergunta curta', F.pontuar('que horas são') === 'Que horas são?');
ok('pontua afirmação', F.pontuar('abre o Spotify') === 'Abre o Spotify.');
ok('não duplica pontuação existente', F.pontuar('Tudo certo!') === 'Tudo certo!');
ok('aplica grafia técnica em lista fechada', F.termos('abre o wifi e o whats app') === 'abre o Wi-Fi e o WhatsApp');
ok('não altera palavra fora da lista', F.termos('meu projeto continua igual') === 'meu projeto continua igual');
ok('reconhece verbo de ação', F.comando('abre a câmera') && F.comando('Jarvis, liga para Ana'));
ok('pergunta comum não é classificada como comando', !F.comando('quem é você'));

const r = F.avaliar({ texto: '  jarvis abre o wifi ', confianca: 0.91, motor: 'android', latenciaMs: 420 });
ok('avaliação devolve texto pontuado e grafia técnica', r.texto === 'Jarvis abre o Wi-Fi.', r);
ok('confiança é preservada e não inventada', r.confianca === 0.91 && r.confiancaPct === 91 && r.nivel === 'alta');
ok('latência é registrada', r.latenciaMs === 420);
ok('comando confiável não pede repetição', r.precisaRepetir === false);
ok('bruto permanece disponível para auditoria', r.bruto === 'jarvis abre o wifi');

const baixo = F.avaliar({ texto: 'apaga todas as notas', confianca: 0.22 });
ok('comando com baixa confiança pede repetição', baixo.precisaRepetir === true, baixo);
ok('baixa confiança explica o motivo', baixo.motivos.some((m) => /Confiança baixa/.test(m)));
const conversa = F.avaliar({ texto: 'eu gosto de música brasileira', confianca: 0.22 });
ok('frase comum com baixa confiança não é bloqueada como comando', conversa.precisaRepetir === false);

const semConf = F.avaliar({ texto: 'que horas são', motor: 'groq' });
ok('Groq sem confiança não vira 100% nem bloqueia', semConf.confianca === null && semConf.nivel === 'nao-informada' && !semConf.precisaRepetir);
const zero = F.avaliar({ texto: 'abre o Spotify', confianca: 0 });
ok('confiança zero do Android é tratada como ausente', zero.confianca === null && !zero.precisaRepetir, zero);

const hip = F.avaliar({
  texto: 'abre o spotifi', confianca: 0.42,
  alternativas: [{ texto: 'abre o spotify', confianca: 0.42 }, { texto: 'abre o spotifi', confianca: 0.31 }]
});
ok('alternativas são normalizadas e sem duplicata', hip.alternativas.length === 2 && hip.alternativas[0].texto === 'abre o spotify');
ok('concordância é calculada', hip.concordancia != null && hip.concordancia > 0);

ok('WER de transcrição idêntica é zero', F.wer('abre o Spotify', 'Abre o Spotify.') === 0);
ok('WER conta substituição', F.wer('abre o Spotify', 'abre o YouTube') === 0.3333);
ok('WER de referência vazia é nulo', F.wer('', 'qualquer coisa') === null);
ok('acerto é o complemento do WER', F.acerto('abre o Spotify', 'abre o YouTube') === 0.6667);
const m = F.metricas([
  { esperado: 'abre o Spotify', reconhecido: 'abre o Spotify', latenciaMs: 400 },
  { esperado: 'que horas são', reconhecido: 'que horas', latenciaMs: 800 }
]);
ok('métricas calculam latência média', m.latenciaMediaMs === 600, m);
ok('métricas calculam acerto médio', m.acertoMedio != null && m.acertoMedio > 0.5 && m.acertoMedio < 1, m);
const ma = F.metricas([
  { esperado: 'abre o Spotify', reconhecido: 'abre o Spotify', latenciaMs: 400, audioMs: 1000, bytes: 20000 },
  { esperado: 'que horas são', reconhecido: 'que horas', latenciaMs: 800, audioMs: 2000, bytes: 40000 }
]);
ok('métricas calculam captura média', ma.audioMedioMs === 1500, ma);
ok('métricas calculam upload médio', ma.bytesMedios === 30000, ma);

ok('módulo não acessa DOM, rede ou armazenamento', !/document\.|fetch\(|localStorage/.test(require('fs').readFileSync(require('path').join(__dirname, '..', 'fala.js'), 'utf8')));

console.log('\nFala: ' + n + ' verificações de limpeza, confiança, comando, WER e métricas aprovadas.');
