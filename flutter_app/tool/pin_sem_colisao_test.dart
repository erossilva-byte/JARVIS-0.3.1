import 'package:jarvis_nova/core/aparelho.dart';
import 'package:jarvis_nova/core/nome_contato.dart';
import 'package:jarvis_nova/core/pedido_apelido.dart';
import 'package:jarvis_nova/core/segredo_pedido.dart';

void main() {
  // 1. Apelido com número é ensinado e guardado inteiro.
  final comNumero = pedidoApelido('chama o Murilo de Murilo 2');
  assert(comNumero != null, 'não reconheceu o pedido de apelido');
  final apelido = comNumero!;
  assert(apelido.apelido == 'Murilo 2',
      'o apelido perdeu o número: ${apelido.apelido}');
  assert(apelido.nome == 'Murilo', 'o nome saiu errado: ${apelido.nome}');
  assert(apelido.fraseFalada.contains('Murilo 2'),
      'a confirmação falada perdeu o número');

  final comAno = pedidoApelido('o apelido do Murilo é Murilo 2026');
  assert(comAno != null && comAno.apelido == 'Murilo 2026',
      'apelido com quatro dígitos não foi guardado inteiro');

  // 2. O nome com número continua resolvendo o contato certo.
  const contatos = [
    ContatoAparelho(nome: 'Murilo'),
    ContatoAparelho(nome: 'Murilo 2'),
  ];
  assert(normalizarNomeContato('Murilo 2') == 'murilo 2',
      'a normalização comeu o número do apelido');
  final escolha = escolherContato('Murilo 2', contatos);
  assert(escolha.contato?.nome == 'Murilo 2',
      'o apelido com número não achou o contato: ${escolha.contato?.nome}');

  // 3. Comando com número no corpo da mensagem chega inteiro ao envio.
  final pedido = interpretarMensagem(
      'manda mensagem para o Murilo no WhatsApp dizendo que o código é 4321');
  assert(pedido != null, 'não reconheceu o pedido de mensagem');
  final mensagem = pedido!;
  assert(mensagem.texto == 'o código é 4321',
      'o número sumiu do texto da mensagem: "${mensagem.texto}"');
  assert(mensagem.destino == 'Murilo',
      'o destino saiu errado: "${mensagem.destino}"');

  final codigoCurto = interpretarMensagem(
      'envia no WhatsApp para o Murilo dizendo que a senha é 1234');
  assert(codigoCurto != null && codigoCurto.texto == 'a senha é 1234',
      'PIN de quatro dígitos foi alterado antes do envio');

  // 4. A máscara só age na cópia gravada; o pedido original não muda.
  assert(protegerPinNoPedido(mensagem.texto) ==
          'o código é $textoOcultoNoPedido',
      'a máscara não protegeu a cópia do histórico');
  assert(mensagem.texto == 'o código é 4321',
      'a máscara alterou o pedido em memória, quebrando o envio');

  // 5. Apelido curto com número de um dígito não é máscara de PIN.
  assert(protegerPinNoPedido('Murilo 2') == 'Murilo 2',
      'apelido com um dígito foi mascarado');
  assert(protegerPinNoPedido('Murilo 2026') == 'Murilo $textoOcultoNoPedido',
      'quatro dígitos deveriam ser mascarados só na cópia');
}
