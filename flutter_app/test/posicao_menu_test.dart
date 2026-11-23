import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/nucleo/posicao_menu.dart';

const _folga = 8;
const _topo = 24;
const _base = 48;
const _tela = 1080;

PosicaoMenuNucleo _calcular({
  required int x,
  required int y,
  int lado = 112,
  int larguraMenu = 206,
  int alturaMenu = 300,
  int largura = _tela,
  int altura = 1920,
  int topo = _topo,
  int base = _base,
}) =>
    PosicaoMenuNucleo.calcular(
      nucleoX: x,
      nucleoY: y,
      nucleoLado: lado,
      menuLargura: larguraMenu,
      menuAltura: alturaMenu,
      telaLargura: largura,
      telaAltura: altura,
      topo: topo,
      base: base,
      folga: _folga,
    );

void main() {
  test('com espaço, o menu fica à direita do núcleo', () {
    final posicao = _calcular(x: 100, y: 400);
    expect(posicao.aDireita, isTrue);
    expect(posicao.x, 100 + 112 + _folga);
    expect(posicao.y, 400 + 56 - 150);
  });

  test('sem espaço à direita, o menu vai para a esquerda', () {
    final posicao = _calcular(x: _tela - 130, y: 400);
    expect(posicao.aDireita, isFalse);
    expect(posicao.x, _tela - 130 - 206 - _folga);
  });

  test('canto superior esquerdo respeita a barra de status', () {
    final posicao = _calcular(x: 0, y: 0);
    expect(posicao.aDireita, isTrue);
    expect(posicao.x, 112 + _folga);
    expect(posicao.y, _topo + _folga);
  });

  test('canto inferior direito não sai da tela', () {
    final posicao = _calcular(x: _tela - 120, y: 1920 - 160);
    expect(posicao.aDireita, isFalse);
    expect(posicao.x, _tela - 120 - 206 - _folga);
    expect(posicao.y, 1920 - _base - 300 - _folga);
  });

  test('menu maior que a tela fica na posição mínima, sem negativo', () {
    final posicao = _calcular(
        x: 0,
        y: 0,
        larguraMenu: 2000,
        alturaMenu: 3000,
        largura: 800,
        altura: 600);
    expect(posicao.x, _folga);
    expect(posicao.y, _topo + _folga);
  });

  test('acompanhar o arrasto move o menu junto com o núcleo', () {
    final antes = _calcular(x: 100, y: 400);
    final depois = _calcular(x: 300, y: 700);
    expect(depois.x - antes.x, 200);
    expect(depois.y - antes.y, 300);
  });
}
