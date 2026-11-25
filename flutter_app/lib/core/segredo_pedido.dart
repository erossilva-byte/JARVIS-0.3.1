/// PIN dito em voz alta não entra no histórico de execuções.
///
/// O histórico guarda o texto do pedido para explicar o que foi feito. Se
/// alguém ditar um PIN (4 a 8 dígitos, como no bloqueio do app), ele ficaria
/// escrito ali. Esta regra troca qualquer sequência isolada de 4 a 8 dígitos
/// por `[oculto]` antes de o pedido sair da memória.
///
/// O que fica de fora: sequências de 3 dígitos ou menos (hora, “às 9”) e de 9
/// dígitos ou mais (telefone, CEP, número de documento) — nenhuma delas cabe num
/// PIN deste app, e apagá-las só tiraria a explicação do comando. Um ano de 4
/// dígitos (“2026”) também é mascarado: é o preço de uma regra simples e
/// previsível.
///
/// O Android tem a mesma regra em `android/JarvisSegredo.kt`, e ela é aplicada
/// de novo na gravação (`JarvisFundo.anotar`) para cobrir o serviço de segundo
/// plano, que não passa pelo Dart.
library;

/// Texto que substitui a sequência de dígitos.
const textoOcultoNoPedido = '[oculto]';

/// 4 a 8 dígitos isolados: nem colados a outro dígito, à esquerda ou à direita.
final _sequenciaDePin = RegExp(r'(?<!\d)\d{4,8}(?!\d)');

/// Devolve o pedido sem nenhum PIN ditado.
String protegerPinNoPedido(String texto) =>
    texto.replaceAll(_sequenciaDePin, textoOcultoNoPedido);
