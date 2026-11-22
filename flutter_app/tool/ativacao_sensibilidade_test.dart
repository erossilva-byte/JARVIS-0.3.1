import 'dart:io';

import 'package:jarvis_nova/core/ativacao_sensibilidade.dart';

void main() {
  // 1. Padrão igual ao serviço Android: quem nunca mexeu continua em 75%.
  assert(AtivacaoSensibilidade.padrao == 75, 'padrão diferente do serviço');

  // 2. Faixa: nada passa de 0–100, nem por valor negativo.
  assert(AtivacaoSensibilidade.segura(-30) == 0, 'negativo não foi limitado');
  assert(AtivacaoSensibilidade.segura(240) == 100, 'acima de 100 não limitado');
  assert(AtivacaoSensibilidade.segura(60) == 60, 'valor válido foi alterado');

  // 3. Passo do controle: 5 em 5, e o arredondamento fica dentro da faixa.
  assert(AtivacaoSensibilidade.comPasso(73) == 75, 'passo arredondou errado');
  assert(AtivacaoSensibilidade.comPasso(72) == 70, 'passo arredondou errado');
  assert(AtivacaoSensibilidade.comPasso(1000) == 100, 'passo estourou a faixa');
  assert(AtivacaoSensibilidade.comPasso(-10) == 0, 'passo furou o piso');

  // 4. Mais sensibilidade = limiar menor (acorda mais fácil). Estes números
  // precisam bater com JarvisKwsEngine.limiarPara no Android.
  assert(AtivacaoSensibilidade.limiar(0) == 0.50, 'limiar mínimo errado');
  assert(AtivacaoSensibilidade.limiar(20) == 0.42, 'limiar baixo errado');
  assert(AtivacaoSensibilidade.limiar(45) == 0.33, 'limiar médio errado');
  assert(AtivacaoSensibilidade.limiar(75) == 0.25, 'limiar alto errado');
  assert(AtivacaoSensibilidade.limiar(90) == 0.20, 'limiar máximo errado');
  var anterior = 1.0;
  for (var v = 0; v <= 100; v += 5) {
    final atual = AtivacaoSensibilidade.limiar(v);
    assert(atual <= anterior, 'limiar subiu ao aumentar a sensibilidade');
    anterior = atual;
  }

  // 5. Pontuação das palavras-chave acompanha o limiar.
  assert(AtivacaoSensibilidade.pontuacaoPalavra(10) == 1.5, 'pontuação base');
  assert(AtivacaoSensibilidade.pontuacaoPalavra(75) == 1.8, 'pontuação alta');
  assert(AtivacaoSensibilidade.pontuacaoPalavra(95) == 2.0, 'pontuação máxima');

  // 6. Rótulos curtos e descrição sempre presente, sem prometer acerto.
  assert(AtivacaoSensibilidade.rotulo(0) == 'Mínima', 'rótulo mínimo');
  assert(AtivacaoSensibilidade.rotulo(30) == 'Baixa', 'rótulo baixa');
  assert(AtivacaoSensibilidade.rotulo(50) == 'Média', 'rótulo média');
  assert(AtivacaoSensibilidade.rotulo(75) == 'Alta', 'rótulo alta');
  assert(AtivacaoSensibilidade.rotulo(100) == 'Máxima', 'rótulo máxima');
  for (var v = 0; v <= 100; v += 5) {
    assert(AtivacaoSensibilidade.descricao(v).isNotEmpty,
        'descrição vazia em $v');
    assert(!AtivacaoSensibilidade.descricao(v).toLowerCase().contains('garant'),
        'descrição prometeu acerto em $v');
  }

  // 7. Resumo mostra rótulo e limiar juntos.
  assert(AtivacaoSensibilidade.resumo(75).startsWith('Alta · limiar 0.25'),
      'resumo errado: ${AtivacaoSensibilidade.resumo(75)}');

  stdout.writeln(
      'OK: sensibilidade da ativação — faixa, passo, limiar, rótulos e resumo.');
}
