/// Circuito em uso: o que está aberto no simulador agora.
///
/// O bloco 100 levou o circuito por prompt até a conversa, mas cada pedido
/// montava do zero. Para **editar** o que já está na tela, a conversa precisa
/// saber qual é esse circuito. O simulador publica aqui cada esquema que abre ou
/// muda; a conversa lê na hora de interpretar o pedido.
///
/// É um único ponto, de propósito: sem banco, sem arquivo e sem rede. Fecha o
/// app e some — igual ao simulador, que também não guarda sozinho.
library;

import 'circuito.dart';

class CircuitoEmUso {
  CircuitoEmUso._();

  static Circuito? _atual;

  /// O esquema que o simulador está mostrando (ou o último que mostrou).
  static Circuito? get atual => _atual;

  /// Publica o esquema; `null` esquece o anterior.
  static void definir(Circuito? circuito) => _atual = circuito;

  /// Esquece o circuito (usado pelos testes e ao limpar o simulador).
  static void limpar() => _atual = null;
}
