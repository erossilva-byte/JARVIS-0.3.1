import 'package:flutter/services.dart';

/// Estado do núcleo flutuante, como o Android o descreve.
class NucleoEstado {
  const NucleoEstado({
    required this.ativo,
    required this.tamanho,
    required this.intervalo,
    required this.permissao,
    this.motivo = '',
  });

  final bool ativo;

  /// Lado do núcleo em dp (72 a 160).
  final int tamanho;

  /// Intervalo do teletransporte em milissegundos.
  final int intervalo;

  /// “Exibir sobre outros apps” está autorizado?
  final bool permissao;

  /// `sem_permissao`, `falhou` ou vazio.
  final String motivo;

  static NucleoEstado deMapa(Object? dados) {
    if (dados is! Map) {
      return const NucleoEstado(
          ativo: false,
          tamanho: 112,
          intervalo: 7000,
          permissao: false,
          motivo: 'sem_resposta');
    }
    int inteiro(String chave, int padrao) {
      final valor = dados[chave];
      return valor is int ? valor : padrao;
    }

    return NucleoEstado(
      ativo: dados['ativo'] == true,
      tamanho: inteiro('tamanho', 112),
      intervalo: inteiro('intervalo', 7000),
      permissao: dados['permissao'] == true,
      motivo: dados['motivo']?.toString() ?? '',
    );
  }
}

/// Liga e desliga o núcleo flutuante; a janela em si é do lado Android.
class NucleoControle {
  NucleoControle._();

  static const canal = MethodChannel('com.jarvis.nova/nucleo');

  static Future<NucleoEstado> estado() async =>
      NucleoEstado.deMapa(await canal.invokeMethod<Object?>('estado'));

  static Future<NucleoEstado> iniciar({
    int tamanho = 112,
    int intervalo = 7000,
  }) async =>
      NucleoEstado.deMapa(await canal.invokeMethod<Object?>('iniciar', {
        'tamanho': tamanho,
        'intervalo': intervalo,
      }));

  static Future<NucleoEstado> parar() async =>
      NucleoEstado.deMapa(await canal.invokeMethod<Object?>('parar'));

  static Future<bool> teleportar() async =>
      await canal.invokeMethod<bool>('teleportar') ?? false;

  static Future<void> abrirAjusteSobreposicao() =>
      canal.invokeMethod<void>('abrirAjusteSobreposicao');
}
