import 'package:shared_preferences/shared_preferences.dart';
import '../core/hotword_portugues.dart';

/// Quais frases acordam o JARVIS, escolhidas pela pessoa.
///
/// É preferência, não segredo: fica nas preferências do app, sem cofre. Além
/// dos identificadores, gravamos as linhas tokenizadas em
/// [chaveHotwordLinhas] porque o serviço Android, com o app fechado, não tem
/// Flutter para consultar a tabela — ele lê essa chave direto de
/// `FlutterSharedPreferences` (prefixo `flutter.`).
abstract interface class PreferenciasHotword {
  Future<Set<String>> carregar();
  Future<Set<String>> gravar(Set<String> ids);
  Future<Set<String>> restaurarPadrao();
}

const chaveHotwordAtivos = 'jarvis.hotword.ativos';
const chaveHotwordLinhas = 'jarvis.hotword.linhas';

class HotwordStore implements PreferenciasHotword {
  @override
  Future<Set<String>> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(chaveHotwordAtivos);
      if (ids == null) return HotwordPortugues.idsPadrao;
      final seguras = HotwordPortugues.seguras(ids);
      // Lista vazia significa “voltar ao conjunto dos assets” no motor; a tela
      // não deixa chegar a zero. Valor que não reconhecemos nenhum
      // identificador também cai no padrão, para nunca deixar a escuta muda.
      if (seguras.isEmpty) return HotwordPortugues.idsPadrao;
      return seguras;
    } catch (_) {
      return HotwordPortugues.idsPadrao;
    }
  }

  @override
  Future<Set<String>> gravar(Set<String> ids) async {
    final seguras = HotwordPortugues.seguras(ids);
    final prefs = await SharedPreferences.getInstance();
    final linhas = HotwordPortugues.linhas(seguras);
    await prefs.setStringList(
        chaveHotwordAtivos, seguras.toList()..sort());
    // Linhas vazias precisam apagar a chave: o motor volta ao keywords.txt dos
    // assets quando não recebe nada.
    if (linhas.isEmpty) {
      await prefs.remove(chaveHotwordLinhas);
    } else {
      await prefs.setString(chaveHotwordLinhas, linhas.join('\n'));
    }
    return seguras;
  }

  @override
  Future<Set<String>> restaurarPadrao() =>
      gravar(HotwordPortugues.idsPadrao);
}
