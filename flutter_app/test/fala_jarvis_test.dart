import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/fala_jarvis.dart';
import 'package:jarvis_nova/services/voz_externa_service.dart';
import 'package:jarvis_nova/services/voz_jarvis.dart';

class _LocalFalso extends VozJarvis {
  _LocalFalso() : super(channel: const MethodChannel('teste/sem_canal'));

  int falas = 0;
  bool parou = false;
  String ultimoTexto = '';

  @override
  Future<bool> falar(String texto) async {
    falas++;
    ultimoTexto = texto;
    return true;
  }

  @override
  Future<void> parar() async {
    parou = true;
  }
}

class _ExternaFalsa extends VozExternaService {
  _ExternaFalsa({this.erro, this.toca = true});

  String? erro;
  bool toca;
  int gerados = 0;
  bool parou = false;
  String ultimoTexto = '';
  Uint8List? tocado;

  @override
  Future<ResultadoVozExterna> gerar(String texto) async {
    gerados++;
    ultimoTexto = texto;
    if (erro != null) return ResultadoVozExterna(erro: erro);
    return ResultadoVozExterna(audio: Uint8List.fromList([1, 2, 3]));
  }

  @override
  Future<bool> tocar(Uint8List audio) async {
    tocado = audio;
    return toca;
  }

  @override
  Future<void> parar() async {
    parou = true;
  }
}

void main() {
  setUp(VozExternaConfig.reiniciarParaTeste);
  tearDown(VozExternaConfig.reiniciarParaTeste);

  test('desligada, fala só pela voz do aparelho', () async {
    final local = _LocalFalso();
    final externa = _ExternaFalsa();
    final fala =
        FalaJarvis(local: local, externa: externa, externaPronta: () => false);

    expect(await fala.falar('olá'), isTrue);
    expect(local.falas, 1);
    expect(externa.gerados, 0);
    expect(fala.ultimoErro, isNull);
  });

  test('ligada, gera e toca pelo Fish Audio sem chamar a voz local', () async {
    final local = _LocalFalso();
    final externa = _ExternaFalsa();
    final fala =
        FalaJarvis(local: local, externa: externa, externaPronta: () => true);

    expect(await fala.falar('**olá** mundo'), isTrue);
    expect(externa.gerados, 1);
    expect(externa.ultimoTexto, 'olá mundo');
    expect(externa.tocado, isNotNull);
    expect(local.falas, 0);
    expect(fala.ultimoErro, isNull);
  });

  test('erro de chave ou rede cai para a voz local e explica', () async {
    final local = _LocalFalso();
    final externa = _ExternaFalsa(erro: 'A chave do Fish Audio foi recusada.');
    final fala =
        FalaJarvis(local: local, externa: externa, externaPronta: () => true);

    expect(await fala.falar('olá'), isTrue);
    expect(local.falas, 1);
    expect(fala.ultimoErro, contains('recusada'));
  });

  test('áudio gerado que não toca também cai para a voz local', () async {
    final local = _LocalFalso();
    final externa = _ExternaFalsa(toca: false);
    final fala =
        FalaJarvis(local: local, externa: externa, externaPronta: () => true);

    expect(await fala.falar('olá'), isTrue);
    expect(local.falas, 1);
    expect(fala.ultimoErro, contains('não conseguiu tocar'));
  });

  test('parar interrompe as duas vozes', () async {
    final local = _LocalFalso();
    final externa = _ExternaFalsa();
    final fala =
        FalaJarvis(local: local, externa: externa, externaPronta: () => true);

    await fala.parar();
    expect(externa.parou, isTrue);
    expect(local.parou, isTrue);
  });

  test('configuração só fica pronta com voz ligada e chave', () {
    expect(VozExternaConfig.pronta, isFalse);
    VozExternaConfig.definir(ativa: true, temChave: false);
    expect(VozExternaConfig.pronta, isFalse);
    VozExternaConfig.definir(ativa: true, temChave: true);
    expect(VozExternaConfig.pronta, isTrue);
    VozExternaConfig.definir(ativa: false, temChave: true);
    expect(VozExternaConfig.pronta, isFalse);
  });

  test('texto vazio não chama serviço nenhum', () async {
    final local = _LocalFalso();
    final externa = _ExternaFalsa();
    final fala =
        FalaJarvis(local: local, externa: externa, externaPronta: () => true);

    expect(await fala.falar('   '), isFalse);
    expect(local.falas, 0);
    expect(externa.gerados, 0);
  });
}
