import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/visao_estruturada.dart';

void main() {
  group('interpretarAnaliseVisao', () {
    test('lê JSON cercado por markdown e converte caixas normalizadas', () {
      final analise = interpretarAnaliseVisao('''
```json
{
  "summary": "Uma mesa com uma caneca.",
  "objects": [
    {"label": "caneca", "confidence": 0.91, "bbox": [0.1, 0.2, 0.3, 0.4]},
    {"label": "homem", "confidence": 1.2, "bbox": {"x": 0.5, "y": 0.5, "w": 0.2, "h": 0.2}}
  ],
  "text": ["CAFÉ", "220V"]
}
```
''');

      expect(analise.estruturada, isTrue);
      expect(analise.resumo, 'Uma mesa com uma caneca.');
      expect(analise.objetos.length, 2);
      expect(analise.objetos.first.rotulo, 'caneca');
      expect(analise.objetos.first.confianca, closeTo(0.91, 0.001));
      expect(analise.objetos.first.caixa!.x, 0.1);
      expect(analise.objetos.first.caixa!.w, 0.3);
      expect(analise.objetos[1].rotulo, 'Pessoa');
      expect(analise.objetos[1].confianca, 1.0);
      expect(analise.objetos[1].detalhe, contains('não analisa rosto'));
      expect(analise.textoLegivel, ['CAFÉ', '220V']);
    });

    test('não deixa idade ou gênero aparecerem no rótulo de uma pessoa', () {
      final analise = interpretarAnaliseVisao(
        '{"objects":[{"label":"mulher jovem","bbox":[0.1,0.1,0.2,0.2],"info":"sorrindo"}]}',
      );
      expect(analise.objetos.single.rotulo, 'Pessoa');
      expect(analise.objetos.single.detalhe, isNot(contains('sorrindo')));
      expect(analise.objetos.single.detalhe, contains('não analisa rosto'));
    });

    test('cai para texto simples quando não há JSON válido', () {
      final analise =
          interpretarAnaliseVisao('Há uma caneca branca sobre a mesa.');
      expect(analise.estruturada, isFalse);
      expect(analise.resumo, contains('caneca branca'));
      expect(analise.objetos, isEmpty);
      expect(analise.textoExibicao, contains('caneca branca'));
    });

    test('descarta caixa fora do intervalo, mas mantém o objeto sem balão', () {
      final analise = interpretarAnaliseVisao(
        '{"objects":[{"label":"mesa","bbox":[100,200,30,40]},{"label":"","bbox":[0,0,1,1]}]}',
      );
      expect(analise.objetos.length, 1);
      expect(analise.objetos.first.rotulo, 'mesa');
      expect(analise.objetos.first.caixa, isNull);
      expect(analise.estruturada, isTrue);
    });

    test('não deixa a análise vazia passar como sucesso', () {
      final analise = interpretarAnaliseVisao('{"summary":"","objects":[]}');
      expect(analise.vazia, isTrue);
      expect(analise.estruturada, isFalse);
    });
  });

  group('layoutBaloesVisao', () {
    test('um balão por objeto e nenhuma sobreposição', () {
      final objetos = List.generate(
        10,
        (i) => const ObjetoVisao(
          rotulo: 'objeto',
          caixa: CaixaVisao(x: 0.45, y: 0.45, w: 0.1, h: 0.1),
        ),
      );
      final baloes = layoutBaloesVisao(objetos, largura: 320, altura: 420);
      expect(baloes.length, 10);
      for (var i = 0; i < baloes.length; i++) {
        final a = baloes[i];
        final ax = a.x / 100 * 320 - a.largura / 2;
        final ay = a.y / 100 * 420 - a.altura / 2;
        for (var j = i + 1; j < baloes.length; j++) {
          final b = baloes[j];
          final bx = b.x / 100 * 320 - b.largura / 2;
          final by = b.y / 100 * 420 - b.altura / 2;
          final cruza = ax < bx + b.largura &&
              ax + a.largura > bx &&
              ay < by + b.altura &&
              ay + a.altura > by;
          expect(cruza, isFalse, reason: 'balão $i sobrepõe $j');
        }
      }
    });

    test('balões ficam presos dentro da imagem e a guia aponta para o centro',
        () {
      final baloes = layoutBaloesVisao(
        const [
          ObjetoVisao(
              rotulo: 'x', caixa: CaixaVisao(x: 0.2, y: 0.3, w: 0.2, h: 0.2)),
          ObjetoVisao(
              rotulo: 'y',
              caixa: CaixaVisao(x: 0.99, y: 0.99, w: 0.01, h: 0.01)),
        ],
        largura: 300,
        altura: 400,
      );
      for (final balao in baloes) {
        final x = balao.x / 100 * 300 - balao.largura / 2;
        final y = balao.y / 100 * 400 - balao.altura / 2;
        expect(x, greaterThanOrEqualTo(0));
        expect(y, greaterThanOrEqualTo(0));
        expect(x + balao.largura, lessThanOrEqualTo(300.001));
        expect(y + balao.altura, lessThanOrEqualTo(400.001));
      }
      expect(baloes.first.linha!.x2, closeTo(30, 0.1));
      expect(baloes.first.linha!.y2, closeTo(40, 0.1));
    });

    test('objeto sem caixa vai para a lista, não para a imagem', () {
      final baloes = layoutBaloesVisao(
        const [
          ObjetoVisao(rotulo: 'sem posição'),
          ObjetoVisao(
              rotulo: 'com', caixa: CaixaVisao(x: 0.1, y: 0.1, w: 0.1, h: 0.1)),
        ],
        largura: 320,
        altura: 420,
      );
      expect(baloes.first.semCaixa, isTrue);
      expect(baloes[1].semCaixa, isFalse);
    });
  });
}
