import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/palco.dart';

/// Guarda as regras do palco no próprio aparelho.
///
/// São preferências de exibição, não segredos, então vão para
/// `SharedPreferences`. Regra corrompida ou ausente volta ao padrão; falha de
/// gravação vira aviso na tela, nunca um "salvo" inventado.
class PalcoRegrasStore {
  PalcoRegrasStore(this._prefs);

  static const chave = 'jarvis.palco.regras.v1';
  static const limiteBytes = 4096;

  final SharedPreferences _prefs;

  static Future<PalcoRegrasStore> abrir() async =>
      PalcoRegrasStore(await SharedPreferences.getInstance());

  RegrasPalco carregar() {
    try {
      final texto = _prefs.getString(chave);
      if (texto == null || texto.isEmpty) return RegrasPalco.padrao;
      return RegrasPalco.deJson(texto);
    } catch (_) {
      return RegrasPalco.padrao;
    }
  }

  Future<bool> salvar(RegrasPalco regras) async {
    final payload = jsonEncode(regras.paraJson());
    if (utf8.encode(payload).length > limiteBytes) {
      return false;
    }
    try {
      return await _prefs.setString(chave, payload);
    } catch (_) {
      return false;
    }
  }

  Future<bool> voltarAoPadrao() => salvar(RegrasPalco.padrao);
}
