import 'package:shared_preferences/shared_preferences.dart';

import '../core/localizacao.dart';
import 'aparelho_service.dart';

/// Última localização conhecida do aparelho, guardada no próprio celular.
///
/// O JARVIS usa isto para falar a temperatura do lugar certo sem pedir o GPS a
/// cada pergunta. A leitura só acontece quando já existe permissão; este
/// serviço nunca abre o pedido de permissão sozinho (quem pede é a tela do
/// aparelho, com o usuário vendo). Nada é enviado para lugar nenhum.
class LocalizacaoService {
  LocalizacaoService({AparelhoService? aparelho, DateTime Function()? relogio})
      : _aparelho = aparelho ?? AparelhoService(),
        _agora = relogio ?? DateTime.now;

  final AparelhoService _aparelho;
  final DateTime Function() _agora;

  static const _chaveLat = 'jarvis.local.latitude';
  static const _chaveLon = 'jarvis.local.longitude';
  static const _chaveEndereco = 'jarvis.local.endereco';
  static const _chaveQuando = 'jarvis.local.quando';

  /// Quanto tempo a posição guardada ainda vale para o clima.
  static const validade = Duration(minutes: 20);

  /// Última posição guardada, se ainda estiver dentro da validade.
  Future<LocalizacaoAparelho?> ultima({bool exigirValidade = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_chaveLat);
      final lon = prefs.getDouble(_chaveLon);
      final quando = prefs.getInt(_chaveQuando) ?? 0;
      if (lat == null || lon == null) return null;
      final idade = _agora().millisecondsSinceEpoch - quando;
      if (exigirValidade && idade > validade.inMilliseconds) return null;
      return LocalizacaoAparelho(
        ok: true,
        mensagem: '',
        latitude: lat,
        longitude: lon,
        endereco: prefs.getString(_chaveEndereco) ?? '',
        fonte: 'ultima_conhecida',
        idadeMs: idade < 0 ? 0 : idade,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lê o aparelho (só com permissão já concedida) e guarda a posição nova.
  ///
  /// Devolve a última posição conhecida quando a leitura falha, para o clima
  /// ainda poder usar o lugar aproximado. Sem permissão, devolve `null` sem
  /// incomodar o usuário.
  Future<LocalizacaoAparelho?> atualizar({bool forcar = false}) async {
    final guardada = await ultima();
    if (guardada != null && !forcar) return guardada;
    try {
      final estado = await _aparelho.estadoLocalizacao();
      if (!estado.permissao || !estado.algumProvedor) {
        return await ultima(exigirValidade: false);
      }
      final local = await _aparelho.localizacao();
      if (!local.valida) return await ultima(exigirValidade: false);
      await _guardar(local);
      return local;
    } catch (_) {
      return await ultima(exigirValidade: false);
    }
  }

  Future<void> _guardar(LocalizacaoAparelho local) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_chaveLat, local.latitude!);
      await prefs.setDouble(_chaveLon, local.longitude!);
      await prefs.setString(_chaveEndereco, local.endereco);
      await prefs.setInt(
          _chaveQuando, _agora().millisecondsSinceEpoch);
    } catch (_) {
      // Sem preferências a posição vale só para esta sessão; nada quebra.
    }
  }
}
