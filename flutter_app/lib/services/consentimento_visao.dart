import 'package:shared_preferences/shared_preferences.dart';

/// Autorização persistente para enviar imagens à análise.
///
/// Só o booleano é guardado; nenhuma foto, pergunta ou resposta passa por aqui.
class ConsentimentoVisao {
  static const chave = 'visao_consentimento_v1';

  static Future<bool> ler() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(chave) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> salvar(bool autorizado) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(chave, autorizado);
    } catch (_) {
      // Sem armazenamento local, a escolha vale só nesta visita.
    }
  }
}
