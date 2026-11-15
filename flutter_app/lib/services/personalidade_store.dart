import 'package:shared_preferences/shared_preferences.dart';

import '../core/personalidade.dart';

/// Guarda apenas o nível escolhido — não é dado sensível, então usa a preferência local simples.
class PersonalidadeStore {
  PersonalidadeStore(this._prefs);

  static const chave = 'jarvis.personalidade.v1';

  final SharedPreferences _prefs;

  static Future<PersonalidadeStore> abrir() async =>
      PersonalidadeStore(await SharedPreferences.getInstance());

  Personalidade carregar() => Personalidade(nivel: nivelHumorDe(_prefs.getString(chave)));

  /// Devolve `false` quando o sistema não conseguiu gravar; o chamador informa o usuário.
  Future<bool> salvar(Personalidade personalidade) =>
      _prefs.setString(chave, personalidade.nivel.name);
}
