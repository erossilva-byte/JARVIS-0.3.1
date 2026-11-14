import 'dart:convert';
import 'dart:io';

import 'package:jarvis_nova/core/conversa.dart';

/// Teste do modelo de conversa em Dart puro: `dart run tool/conversa_test.dart`.
void main() {
  _tituloAutomatico();
  _idaEVoltaJson();
  _descartaLixo();
  _fixadaSobrevive();
  stdout.writeln('OK: conversa — título, JSON, dados inválidos e fixação');
}

void _tituloAutomatico() {
  final conversa = Conversa.nova(id: 'a', agora: DateTime(2026, 11, 14));
  assert(conversa.titulo == Conversa.tituloPadrao);
  conversa.adicionar(const MensagemConversa(autor: 'user', texto: 'Lembra que o motor é 220 V?'));
  assert(conversa.titulo == 'Lembra que o motor é 220 V?', conversa.titulo);
  final longo = Conversa.tituloDe('preciso de um resumo bem longo sobre o projeto elétrico inteiro da casa nova');
  assert(longo.endsWith('…'), longo);
  assert(longo.length <= 49, '${longo.length}');
}

void _idaEVoltaJson() {
  final conversa = Conversa.nova(id: 'b', agora: DateTime.utc(2026, 11, 14, 10));
  conversa.adicionar(MensagemConversa(
    autor: 'assistant',
    texto: 'Certo, senhor.',
    fontes: const ['Memoria/Preferencias.md'],
  ));
  final texto = jsonEncode(conversa.paraJson());
  final lido = Conversa.deJson(jsonDecode(texto));
  assert(lido != null);
  final voltou = lido!;
  assert(voltou.mensagens.length == 1);
  assert(voltou.mensagens.single.fontes.single == 'Memoria/Preferencias.md');
  assert(voltou.criadaEm.isAtSameMomentAs(conversa.criadaEm));
}

void _descartaLixo() {
  assert(Conversa.deJson(null) == null);
  assert(Conversa.deJson({'id': ''}) == null);
  assert(Conversa.deJson({'id': 'x'}) == null, 'sem data não entra');
  final parcial = Conversa.deJson({
    'id': 'x',
    'criadaEm': '2026-11-14T10:00:00Z',
    'mensagens': [
      {'autor': 'user', 'texto': 'oi'},
      {'autor': 'sistema', 'texto': 'ignorar'},
      {'autor': 'assistant'},
      'lixo',
    ],
  });
  assert(parcial != null);
  assert(parcial!.mensagens.length == 1, 'só a mensagem válida fica');
}

void _fixadaSobrevive() {
  final conversa = Conversa.nova(id: 'c', agora: DateTime(2026, 11, 14))..fixada = true;
  final voltou = Conversa.deJson(jsonDecode(jsonEncode(conversa.paraJson())));
  assert(voltou!.fixada);
}
