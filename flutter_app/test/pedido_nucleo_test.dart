import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/pedido_nucleo.dart';

void main() {
  test('ativa e desativa o núcleo pelos verbos do dia a dia', () {
    expect(pedidoNucleo('ativa o núcleo'), isTrue);
    expect(pedidoNucleo('Jarvis, abre o núcleo flutuante'), isTrue);
    expect(pedidoNucleo('mostra o núcleo'), isTrue);
    expect(pedidoNucleo('desativa o núcleo'), isFalse);
    expect(pedidoNucleo('fecha o núcleo flutuante'), isFalse);
    expect(pedidoNucleo('tira o núcleo da tela'), isFalse);
  });

  test('aceita o núcleo sem acento e em maiúsculas', () {
    expect(pedidoNucleo('ATIVAR O NUCLEO'), isTrue);
    expect(pedidoNucleo('desligar o  núcleo'), isFalse);
  });

  test('não transforma pergunta nem outro assunto em ação', () {
    expect(pedidoNucleo('como ativo o núcleo?'), isNull);
    expect(pedidoNucleo('por que o núcleo some'), isNull);
    expect(pedidoNucleo('abrir o WhatsApp'), isNull);
    expect(pedidoNucleo(''), isNull);
  });

  test('só "o núcleo" alterna, como a lanterna', () {
    expect(pedidoNucleo('núcleo'), isTrue);
    expect(pedidoNucleo('o núcleo'), isTrue);
  });
}
