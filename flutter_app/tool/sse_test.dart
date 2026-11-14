import 'dart:io';

import 'package:jarvis_nova/core/sse.dart';

/// Teste do parser SSE em Dart puro: `dart run tool/sse_test.dart`.
void main() {
  _leituraSimples();
  _pedacoCortadoNoMeio();
  _ignoraDoneEEventos();
  _respostaSemStreaming();
  _linhaInvalidaNaoQuebra();
  stdout.writeln('OK: parser SSE — deltas, cortes, [DONE], resposta única e linha inválida');
}

void _leituraSimples() {
  final parser = SseParser();
  final textos = parser.alimentar(
    'data: {"choices":[{"delta":{"content":"Olá"}}]}\n'
    'data: {"choices":[{"delta":{"content":", senhor"}}]}\n',
  );
  assert(textos.join() == 'Olá, senhor', textos.join());
}

void _pedacoCortadoNoMeio() {
  final parser = SseParser();
  final saida = <String>[];
  saida.addAll(parser.alimentar('data: {"choices":[{"delta":{"cont'));
  assert(saida.isEmpty, 'linha incompleta não pode ser interpretada');
  saida.addAll(parser.alimentar('ent":"Jarvis"}}]}\n'));
  assert(saida.single == 'Jarvis', saida.single);
}

void _ignoraDoneEEventos() {
  final parser = SseParser();
  final textos = parser.alimentar(
    ': comentário\n'
    'event: message\n'
    'data: [DONE]\n'
    'data: {"choices":[{"delta":{"content":"fim"}}]}\n',
  );
  assert(textos.single == 'fim', textos.join());
}

void _respostaSemStreaming() {
  final parser = SseParser();
  final textos = parser.alimentar('data: {"choices":[{"message":{"content":"pronto"}}]}\n');
  assert(textos.single == 'pronto', textos.join());
}

void _linhaInvalidaNaoQuebra() {
  var erros = 0;
  final parser = SseParser(aoErro: (_) => erros++);
  final textos = parser.alimentar('data: {quebrado}\ndata: {"choices":[{"delta":{"content":"ok"}}]}\n');
  assert(erros == 1, 'linha inválida deve ser reportada');
  assert(textos.single == 'ok', textos.join());
}
