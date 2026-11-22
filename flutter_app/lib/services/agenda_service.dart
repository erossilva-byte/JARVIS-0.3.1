import 'package:flutter/services.dart';

/// Agendamento real no Android (`AlarmManager` via canal do aparelho).
///
/// Devolve `false` quando o canal não existe ou o Android recusou: a tela mostra
/// que a tarefa foi salva, mas o aviso não foi agendado. Nada aqui inventa
/// sucesso.
class AgendaService {
  AgendaService({MethodChannel? canal})
      : _canal = canal ?? const MethodChannel('com.jarvis.nova/aparelho');

  final MethodChannel _canal;

  Future<bool> agendar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime quando,
    bool repetirDiario = false,
  }) async {
    try {
      final dados = await _canal.invokeMapMethod<Object?, Object?>(
        'agendarLembrete',
        {
          'id': id,
          'titulo': titulo,
          'texto': texto,
          'quando': quando.millisecondsSinceEpoch,
          'repetirDiario': repetirDiario,
        },
      );
      return dados?['ok'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> cancelar(int id) async {
    try {
      final dados = await _canal.invokeMapMethod<Object?, Object?>(
          'cancelarLembrete', {'id': id});
      return dados?['ok'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
