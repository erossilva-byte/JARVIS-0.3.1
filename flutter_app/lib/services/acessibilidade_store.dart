import 'package:shared_preferences/shared_preferences.dart';

/// Consentimento para a automação de tela.
///
/// Desligado por padrão: mesmo com o serviço autorizado nas configurações do
/// Android, o app só lê a tela depois deste “sim” explícito. É preferência, não
/// segredo, então não passa pelo cofre de chaves.
abstract interface class ConsentimentoAcessibilidade {
  Future<bool> ativo();
  Future<void> definir(bool ativo);
}

const chaveAcessibilidadeAtiva = 'jarvis.acessibilidade.ativo';

class PreferencesAcessibilidade implements ConsentimentoAcessibilidade {
  @override
  Future<bool> ativo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(chaveAcessibilidadeAtiva) ?? false;
    } catch (_) {
      // Sem armazenamento não há consentimento registrado: a automação fica
      // desligada, mesmo que o serviço do Android esteja autorizado.
      return false;
    }
  }

  @override
  Future<void> definir(bool ativo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(chaveAcessibilidadeAtiva, ativo);
  }
}
