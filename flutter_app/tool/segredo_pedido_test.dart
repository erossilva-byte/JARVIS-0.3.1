import 'package:jarvis_nova/core/segredo_pedido.dart';

void main() {
  // 1. Sequência de 4 a 8 dígitos some.
  assert(protegerPinNoPedido('1234') == textoOcultoNoPedido,
      'PIN de 4 dígitos não foi mascarado');
  assert(protegerPinNoPedido('123456') == textoOcultoNoPedido,
      'PIN de 6 dígitos não foi mascarado');
  assert(protegerPinNoPedido('12345678') == textoOcultoNoPedido,
      'PIN de 8 dígitos não foi mascarado');
  assert(
      protegerPinNoPedido('o meu pin é 4321') ==
          'o meu pin é $textoOcultoNoPedido',
      'PIN dentro da frase não foi mascarado');
  assert(
      protegerPinNoPedido('senha 1234 e confirmação 5678') ==
          'senha $textoOcultoNoPedido e confirmação $textoOcultoNoPedido',
      'duas sequências não foram mascaradas');

  // 2. O que não é PIN continua legível.
  assert(protegerPinNoPedido('que horas são') == 'que horas são',
      'texto sem dígito mudou');
  assert(protegerPinNoPedido('às 9') == 'às 9', 'um dígito foi mascarado');
  assert(protegerPinNoPedido('volume 100') == 'volume 100',
      'três dígitos foram mascarados');
  assert(protegerPinNoPedido('liga para 11999998888') == 'liga para 11999998888',
      'telefone de 11 dígitos foi mascarado');
  assert(protegerPinNoPedido('cep 12345678') != 'cep 12345678',
      'oito dígitos devem ser mascarados mesmo parecendo CEP');
  assert(protegerPinNoPedido('12 34 567') == '12 34 567',
      'dígitos separados por espaço não são PIN');

  // 3. Não estraga o resto da frase nem mascara duas vezes.
  final mascarado = protegerPinNoPedido('manda 1234 para a Ana');
  assert(mascarado == 'manda $textoOcultoNoPedido para a Ana',
      'a frase perdeu o resto: $mascarado');
  assert(protegerPinNoPedido(mascarado) == mascarado,
      'mascarar duas vezes mudou o texto');

  // 4. Casos de borda.
  assert(protegerPinNoPedido('') == '', 'texto vazio mudou');
  assert(protegerPinNoPedido('[oculto]') == '[oculto]',
      'texto já mascarado mudou');
  assert(protegerPinNoPedido('123456789') == '123456789',
      'nove dígitos não são PIN deste app');
  // Dígitos colados a letra continuam mascarados: o lado seguro é esconder,
  // não arriscar deixar um PIN escrito no histórico.
  assert(protegerPinNoPedido('12345abc') == '${textoOcultoNoPedido}abc',
      'dígitos colados em letra deveriam ser mascarados');
}
