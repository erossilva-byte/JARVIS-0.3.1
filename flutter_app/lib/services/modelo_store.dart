import 'package:shared_preferences/shared_preferences.dart';

/// Modelo escolhido pelo usuário para um provedor.
///
/// É preferência, não segredo: guarda só o identificador do modelo (por
/// exemplo `openai/gpt-oss-20b`), nunca a chave. Sem escolha, o app usa o
/// modelo padrão que vem no código.
abstract interface class ModeloStore {
  Future<String?> ler(String providerId);
  Future<void> gravar(String providerId, String? modelo);
}

String chaveModeloDe(String providerId) => 'jarvis.ai.modelo.$providerId';

class PreferencesModeloStore implements ModeloStore {
  @override
  Future<String?> ler(String providerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final valor = prefs.getString(chaveModeloDe(providerId));
      return valor == null || valor.trim().isEmpty ? null : valor.trim();
    } catch (_) {
      // Sem preferências não há escolha registrada: o padrão continua valendo.
      return null;
    }
  }

  @override
  Future<void> gravar(String providerId, String? modelo) async {
    final prefs = await SharedPreferences.getInstance();
    if (modelo == null || modelo.trim().isEmpty) {
      await prefs.remove(chaveModeloDe(providerId));
    } else {
      await prefs.setString(chaveModeloDe(providerId), modelo.trim());
    }
  }
}
