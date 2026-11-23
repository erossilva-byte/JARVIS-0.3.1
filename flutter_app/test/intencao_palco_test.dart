import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/palco.dart';
import 'package:jarvis_nova/services/sistema_android.dart';

void main() {
  test('intenção de palco vinda do Android vira pedido', () {
    final intencao = IntencaoSistema.deMapa(
        {'acao': 'palco', 'texto': 'motor trifásico', 'tipo': 'imagem'});
    expect(intencao, isNotNull);
    expect(intencao!.abrirPalco, isTrue);
    expect(intencao.abrirConversa, isFalse);
    expect(intencao.pedidoPalco?.tipo, TipoPalco.imagem);
    expect(intencao.pedidoPalco?.consulta, 'motor trifásico');
  });

  test('cada tipo chega ao pedido certo', () {
    for (final (tipo, esperado) in [
      ('video', TipoPalco.video),
      ('noticia', TipoPalco.noticia),
    ]) {
      final intencao = IntencaoSistema.deMapa(
          {'acao': 'palco', 'texto': 'partida direta', 'tipo': tipo});
      expect(intencao!.pedidoPalco?.tipo, esperado);
    }
  });

  test('tipo ausente é inferido pelo assunto', () {
    final intencao = IntencaoSistema.deMapa(
        {'acao': 'palco', 'texto': 'mostra fotos de gato', 'tipo': ''});
    expect(intencao!.pedidoPalco?.tipo, TipoPalco.imagem);
  });

  test('intenção sem assunto não abre o palco', () {
    final intencao = IntencaoSistema.deMapa(
        {'acao': 'palco', 'texto': '  ', 'tipo': 'video'});
    expect(intencao!.abrirPalco, isFalse);
    expect(intencao.pedidoPalco, isNull);
  });

  test('compartilhar e conversa continuam como antes', () {
    final compartilhar = IntencaoSistema.deMapa(
        {'acao': 'compartilhar', 'texto': 'mostra fotos de gato'});
    expect(compartilhar!.abrirPalco, isFalse);
    expect(compartilhar.textoCompartilhado, isTrue);
    expect(compartilhar.pedidoPalco, isNull);
  });
}
