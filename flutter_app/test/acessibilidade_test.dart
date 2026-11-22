import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/acessibilidade.dart';
import 'package:jarvis_nova/services/acessibilidade_service.dart';
import 'package:jarvis_nova/services/acessibilidade_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsentimentoFalso implements ConsentimentoAcessibilidade {
  ConsentimentoFalso(this.valor);
  bool valor;

  @override
  Future<bool> ativo() async => valor;

  @override
  Future<void> definir(bool novo) async {
    valor = novo;
  }
}

class CanalFalso {
  CanalFalso(this.respostas);
  final Map<String, Map<Object?, Object?>?> respostas;
  final chamadas = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<Map<Object?, Object?>?> chamar(
      String metodo, Map<String, Object?> args) async {
    chamadas.add(metodo);
    argumentos.add(args);
    return respostas[metodo];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('interpretador de tela', () {
    test('ler a tela em frases diretas', () {
      for (final frase in [
        'ler a tela',
        'Leia a tela',
        'o que está na tela',
        'quais botões na tela',
      ]) {
        expect(InterpretadorTela.interpretar(frase), isA<LerTela>(),
            reason: frase);
      }
    });

    test('tocar guarda o texto do botão como foi dito', () {
      final comando = InterpretadorTela.interpretar('tocar em "Enviar"');
      expect(comando, isA<TocarNaTela>());
      expect((comando as TocarNaTela).alvo, 'Enviar');
      expect(InterpretadorTela.interpretar('clicar em Cancelar'),
          isA<TocarNaTela>());
    });

    test('rolar reconhece a direção', () {
      final cima = InterpretadorTela.interpretar('rolar para cima');
      final baixo = InterpretadorTela.interpretar('rolar a tela para baixo');
      expect((cima as RolarTela).paraCima, isTrue);
      expect((baixo as RolarTela).paraCima, isFalse);
    });

    test('parar a automação', () {
      expect(InterpretadorTela.interpretar('parar a automação de tela'),
          isA<PararAutomacao>());
    });

    test('pergunta e conversa não viram ação', () {
      for (final frase in [
        'como tocar violão',
        'por que a tela apagou',
        'toque de recolher às 22h',
        'tocar no botão',
        'oi jarvis',
      ]) {
        expect(InterpretadorTela.interpretar(frase), isNull, reason: frase);
      }
    });
  });

  test('resumo da tela encurta, remove repetido e diz o pacote', () {
    const elementos = [
      ElementoDeTela(texto: 'Enviar', pacote: 'com.whatsapp', clicavel: true),
      ElementoDeTela(texto: 'Enviar', pacote: 'com.whatsapp'),
      ElementoDeTela(texto: 'Mensagem', pacote: 'com.whatsapp'),
    ];
    final resumo =
        resumoDaTela(pacote: 'com.whatsapp', elementos: elementos);
    expect(resumo, contains('3 elementos'));
    expect(resumo, contains('em com.whatsapp'));
    expect('Enviar'.allMatches(resumo).length, 1);

    final vazio = resumoDaTela(pacote: '', elementos: const []);
    expect(vazio, contains('Não encontrei texto legível'));

    final limitado = resumoDaTela(
        pacote: 'x', elementos: elementos, limitado: true, limiteDeNos: 120);
    expect(limitado, contains('limite de 120'));
  });

  test('consentimento fica nas preferências, desligado por padrão', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesAcessibilidade();
    expect(await store.ativo(), isFalse);
    await store.definir(true);
    expect(await store.ativo(), isTrue);
    expect(chaveAcessibilidadeAtiva, 'jarvis.acessibilidade.ativo');
  });

  test('desligado por padrão: nenhuma chamada chega ao Android', () async {
    final canal = CanalFalso({
      'status': {'ligado': true, 'pacote': 'com.whatsapp'},
    });
    final servico = AcessibilidadeService(
        chamada: canal.chamar, consentimento: ConsentimentoFalso(false));

    final estado = await servico.status();
    expect(estado.servicoLigado, isTrue);
    expect(estado.consentimento, isFalse);
    expect(estado.pronto, isFalse);

    final resultado = await servico.executar(const LerTela());
    expect(resultado.ok, isFalse);
    expect(resultado.mensagem, contains('desligada'));
    // Só o status foi consultado; ler/tocar nunca saíram.
    expect(canal.chamadas, ['status']);
  });

  test('ler devolve os elementos e o resumo do que apareceu', () async {
    final canal = CanalFalso({
      'ler': {
        'ok': true,
        'pacote': 'com.whatsapp',
        'nos': [
          {'texto': 'Enviar', 'pacote': 'com.whatsapp', 'clicavel': true},
          {'texto': 'campo de texto', 'campo': true},
        ],
      },
    });
    final servico = AcessibilidadeService(
        chamada: canal.chamar, consentimento: ConsentimentoFalso(true));

    final resultado = await servico.executar(const LerTela());
    expect(resultado.ok, isTrue);
    expect(resultado.elementos, hasLength(2));
    expect(resultado.mensagem, contains('com.whatsapp'));
    expect(canal.chamadas, ['ler']);
  });

  test('tocar e rolar levam o pedido certo para o Android', () async {
    final canal = CanalFalso({
      'tocar': {'ok': true, 'mensagem': 'Toquei em "Enviar".'},
      'rolar': {'ok': true, 'mensagem': 'Rolei a tela para cima.'},
    });
    final servico = AcessibilidadeService(
        chamada: canal.chamar, consentimento: ConsentimentoFalso(true));

    final toque = await servico.executar(const TocarNaTela('Enviar'));
    expect(toque.ok, isTrue);
    expect(canal.argumentos.first['texto'], 'Enviar');
    expect(canal.argumentos.first['ocorrencia'], 0);

    final rolagem = await servico.executar(const RolarTela(paraCima: true));
    expect(rolagem.ok, isTrue);
    expect(canal.argumentos.last['paraCima'], isTrue);
  });

  test('sem a ponte Android a recusa é explícita', () async {
    final servico = AcessibilidadeService(
      chamada: (_, __) async => throw MissingPluginException('sem canal'),
      consentimento: ConsentimentoFalso(true),
    );
    final resultado = await servico.executar(const LerTela());
    expect(resultado.ok, isFalse);
    expect(resultado.mensagem, contains('ponte nativa'));
  });
}
