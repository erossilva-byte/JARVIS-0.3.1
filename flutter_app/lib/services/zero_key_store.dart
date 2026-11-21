import 'package:shared_preferences/shared_preferences.dart';

/// Consentimento para o provedor sem chave (Zero-Key).
///
/// Desligado por padrão: sem este “sim” explícito, o app nunca fala com o
/// serviço público anônimo — a conversa só sai do aparelho com uma chave do
/// usuário. É uma preferência, não um segredo: não passa pelo cofre de chaves.
abstract interface class ZeroKeyStore {
  Future<bool> ativo();
  Future<void> definir(bool ativo);
}

const chaveZeroKeyAtiva = 'jarvis.zerokey.ativo';

class PreferencesZeroKey implements ZeroKeyStore {
  @override
  Future<bool> ativo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(chaveZeroKeyAtiva) ?? false;
    } catch (_) {
      // Sem armazenamento de preferências não há consentimento registrado:
      // o provedor sem chave fica desligado.
      return false;
    }
  }

  @override
  Future<void> definir(bool ativo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(chaveZeroKeyAtiva, ativo);
  }
}
