import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/hotword_portugues.dart';

/// A tabela em português só vale se os tokens existirem no modelo que vai no
/// APK. Aqui o tokens.txt real é lido e cada linha é conferida token a token:
/// uma linha com token inventado faria o KeywordSpotter falhar na criação.
void main() {
  final tokens = File('android/app/src/main/assets/kws/tokens.txt');
  final vocabulario = tokens.existsSync()
      ? tokens
          .readAsLinesSync()
          .map((linha) => linha.trim().split(RegExp(r'\s+')).first)
          .where((token) => token.isNotEmpty)
          .toSet()
      : <String>{};

  test('o tokens.txt do APK está presente para a conferência', () {
    expect(tokens.existsSync(), isTrue,
        reason: 'sem o tokens.txt do modelo não há como validar as frases');
    expect(vocabulario.length, greaterThan(100));
  });

  test('toda frase usa apenas tokens que existem no modelo', () {
    for (final variante in HotwordPortugues.variantes) {
      for (final token in variante.tokens.split(' ')) {
        expect(vocabulario, contains(token),
            reason: 'token $token da frase ${variante.frase} não existe no modelo');
      }
    }
  });

  test('os tokens reconstroem a frase escrita, letra por letra', () {
    // O modelo não tem acentos: “Olá” chega como OLA. A conferência tira o
    // acento da escrita para comparar só as letras que o detector conhece.
    String semAcento(String texto) => texto
        .toUpperCase()
        .replaceAll(RegExp('[ÁÀÂÃÄ]'), 'A')
        .replaceAll(RegExp('[ÉÈÊË]'), 'E')
        .replaceAll(RegExp('[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp('[ÓÒÔÕÖ]'), 'O')
        .replaceAll(RegExp('[ÚÙÛÜ]'), 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[^A-Z]'), '');
    for (final variante in HotwordPortugues.variantes) {
      expect(HotwordPortugues.letras(variante.tokens),
          semAcento(variante.frase),
          reason: 'tokens de ${variante.frase} não formam a palavra');
    }
  });

  test('a tabela não repete identificador nem linha tokenizada', () {
    final ids = <String>{};
    final linhas = <String>{};
    for (final variante in HotwordPortugues.variantes) {
      expect(ids.add(variante.id), isTrue,
          reason: 'identificador repetido: ${variante.id}');
      expect(linhas.add(variante.tokens), isTrue,
          reason: 'linha repetida: ${variante.tokens}');
      expect(HotwordPortugues.grupos.containsKey(variante.grupo), isTrue,
          reason: 'grupo desconhecido em ${variante.frase}');
    }
  });

  test('o padrão continua sendo só o conjunto que já existia', () {
    final padrao = HotwordPortugues.idsPadrao;
    expect(padrao.length, 11);
    expect(padrao, contains('jarvis'));
    expect(padrao, contains('charles'));
    // As frases com tratamento são escolha da pessoa, não padrão.
    expect(padrao.contains('ei-jarvis'), isFalse);
    expect(padrao.contains('ola-jarvis'), isFalse);
  });

  test('as frases em português existem e são de duas palavras', () {
    for (final id in ['ei-jarvis', 'oi-jarvis', 'alo-jarvis', 'ola-jarvis']) {
      final variante = HotwordPortugues.porId(id);
      expect(variante, isNotNull, reason: 'frase $id ausente');
      expect(variante!.frase.split(' ').length, 2);
      expect(variante.padrao, isFalse);
    }
  });

  test('linhas seguem a ordem da tabela e não repetem token', () {
    final linhas = HotwordPortugues.linhas({'jarvis', 'ei-jarvis'});
    expect(linhas, ['▁JA R VI S', '▁E I ▁JA R VI S']);
  });

  test('identificador desconhecido é descartado e o limite é respeitado', () {
    expect(HotwordPortugues.seguras(['jarvis', 'nao-existe']), {'jarvis'});
    final todas =
        HotwordPortugues.variantes.map((variante) => variante.id).toList();
    expect(HotwordPortugues.seguras(todas).length,
        HotwordPortugues.variantes.length);
    expect(HotwordPortugues.seguras([...todas, 'extra']).length,
        HotwordPortugues.variantes.length);
  });

  test('o detector devolvido em tokens vira o nome legível', () {
    expect(HotwordPortugues.nomeAmigavel('▁JA R VI S'), 'Jarvis');
    expect(HotwordPortugues.nomeAmigavel('Jarvis'), 'Jarvis');
    expect(HotwordPortugues.nomeAmigavel('▁E I ▁JA R VI S'), 'Ei Jarvis');
    expect(HotwordPortugues.nomeAmigavel('▁O LA ▁JA R VI S'), 'Olá Jarvis');
    expect(HotwordPortugues.nomeAmigavel('  '), '');
  });

  test('resumo lista as frases ligadas', () {
    expect(HotwordPortugues.resumo({'jarvis'}), 'Jarvis');
    expect(HotwordPortugues.resumo(<String>{}), 'nenhuma frase ligada');
  });
}
