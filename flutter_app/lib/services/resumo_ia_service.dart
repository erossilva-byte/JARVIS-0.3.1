import '../core/aparelho.dart';
import '../core/resumo_tatico.dart';
import 'provider_service.dart';

/// Resultado do resumo tático: o que a IA disse ou a triagem local.
class ResultadoResumo {
  const ResultadoResumo({
    this.resumo,
    this.erro,
    this.provedor = '',
  });

  final ResumoTatico? resumo;
  final String? erro;
  final String provedor;

  bool get ok => resumo != null && erro == null;
}

/// Pede ao provedor de IA já configurado o resumo tático das notificações.
///
/// Nada é lido da nuvem sem a chave do usuário e nada é enviado além de app,
/// título, texto e horário das notificações que o Android já entrega ao JARVIS.
class ResumoIaService {
  ResumoIaService({ProviderService? provedor})
      : _provedor =
            provedor ?? ProviderService(secrets: PlatformSecretStore());

  final ProviderService _provedor;

  Future<ResultadoResumo> resumir(
    List<NotificacaoAparelho> lista, {
    DateTime? agora,
  }) async {
    if (lista.isEmpty) {
      return const ResultadoResumo(
          erro: 'Nenhuma notificação lida ainda para resumir.');
    }
    AiProvider? escolhido;
    try {
      escolhido = await _provedor.firstConfiguredProvider();
    } catch (_) {
      return ResultadoResumo(
        erro: 'Não foi possível abrir o cofre de credenciais do aparelho.',
        resumo: triagemLocal(lista),
      );
    }
    if (escolhido == null) {
      return ResultadoResumo(
        erro: 'Nenhum provedor de IA configurado. Cadastre a chave do Groq ou '
            'de outro provedor para o resumo tático.',
        resumo: triagemLocal(lista),
      );
    }
    try {
      final bruto = await _provedor.complete(
        escolhido.id,
        mensagensResumoTatico(lista, agora: agora),
      );
      final resumo = lerResumoTatico(bruto);
      if (resumo == null) {
        return ResultadoResumo(
          erro: 'O provedor respondeu num formato que não consegui ler. '
              'A triagem local está abaixo.',
          resumo: triagemLocal(lista),
          provedor: escolhido.name,
        );
      }
      return ResultadoResumo(resumo: resumo, provedor: escolhido.name);
    } on ProviderException catch (erro) {
      return ResultadoResumo(
          erro: erro.message, resumo: triagemLocal(lista));
    } catch (_) {
      return ResultadoResumo(
        erro: 'Falha inesperada ao pedir o resumo ao provedor.',
        resumo: triagemLocal(lista),
      );
    }
  }
}

/// Triagem sem IA: urgente, ruído de grupo e o resto, com o que é local.
ResumoTatico triagemLocal(List<NotificacaoAparelho> lista) {
  final triagem = triarMensagens(lista);
  final urgentes = [
    for (final n in triagem.urgentes.take(4))
      '${n.app}: ${n.titulo.trim().isEmpty ? n.texto.trim() : n.titulo.trim()}',
  ];
  final ruido = [
    for (final n in triagem.ruido.take(6))
      '${n.app}: ${n.titulo.trim().isEmpty ? n.texto.trim() : n.titulo.trim()}',
  ];
  final resumo = triagem.urgentes.isEmpty
      ? 'Nenhuma notificação com sinal de urgência entre as lidas.'
      : '${triagem.urgentes.length} notificação(ões) com sinal de urgência. '
          'A classificação por IA depende de um provedor configurado.';
  return ResumoTatico(
    resumo: resumo,
    urgentes: urgentes,
    ruido: ruido,
    daIa: false,
  );
}
