import 'dart:io';

import 'package:jarvis_nova/core/stream_buffer.dart';

/// Teste do núcleo Dart puro, executável sem Flutter: `dart run tool/stream_buffer_test.dart`.
void main() {
  _agrupaTokensNaJanela();
  _entregaNoIntervalo();
  _concluirDespejaNaHora();
  _limparZeraTudo();
  _ignoraDepoisDeConcluido();
  stdout.writeln('OK: stream buffer — agrupamento, janela, conclusão e limpeza');
}

void _agrupaTokensNaJanela() {
  final atualizacoes = <String>[];
  final agendados = <void Function()>[];
  final buffer = StreamBuffer(
    aoAtualizar: atualizacoes.add,
    agendador: (_, acao) => agendados.add(acao),
  );
  buffer.adicionar('Olá');
  buffer.adicionar(', ');
  buffer.adicionar('senhor');
  assert(atualizacoes.isEmpty, 'nada deveria ser entregue antes da janela');
  assert(agendados.length == 1, 'só a primeira adição agenda a entrega');
  agendados.removeAt(0)();
  assert(atualizacoes.length == 1, 'uma única atualização por janela');
  assert(atualizacoes.single == 'Olá, senhor', atualizacoes.single);
  assert(buffer.texto == 'Olá, senhor');
  assert(!buffer.pendente);
}

void _entregaNoIntervalo() {
  final atualizacoes = <String>[];
  final recebidos = <Duration>[];
  final buffer = StreamBuffer(
    aoAtualizar: atualizacoes.add,
    intervalo: const Duration(milliseconds: 32),
    agendador: (duracao, acao) { recebidos.add(duracao); acao(); },
  );
  buffer.adicionar('a');
  assert(recebidos.single == const Duration(milliseconds: 32), 'janela da Seção 3D');
  assert(atualizacoes.single == 'a');
}

void _concluirDespejaNaHora() {
  final atualizacoes = <String>[];
  final agendados = <void Function()>[];
  final buffer = StreamBuffer(
    aoAtualizar: atualizacoes.add,
    agendador: (_, acao) => agendados.add(acao),
  );
  buffer.adicionar('fim');
  buffer.concluir();
  assert(atualizacoes.single == 'fim', 'concluir não pode esperar a janela');
  agendados.removeAt(0)();
  assert(atualizacoes.length == 1, 'a entrega agendada vira no-op');
}

void _limparZeraTudo() {
  final atualizacoes = <String>[];
  final buffer = StreamBuffer(aoAtualizar: atualizacoes.add, agendador: (_, __) {});
  buffer.adicionar('velho');
  buffer.concluir();
  buffer.limpar();
  assert(buffer.texto.isEmpty);
  assert(atualizacoes.last.isEmpty, 'limpar avisa a interface uma vez');
  buffer.adicionar('novo');
  assert(buffer.pendente, 'depois de limpar, aceita novo streaming');
}

void _ignoraDepoisDeConcluido() {
  final atualizacoes = <String>[];
  final buffer = StreamBuffer(aoAtualizar: atualizacoes.add, agendador: (_, __) {});
  buffer.adicionar('certo');
  buffer.concluir();
  buffer.adicionar('tarde');
  assert(buffer.texto == 'certo', 'token depois do fim é ignorado');
}
