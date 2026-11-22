import 'package:flutter/services.dart';

import '../core/circuito_em_uso.dart';
import '../core/circuito_no_chat.dart';
import '../core/edicao_circuito.dart';
import '../core/habilidades.dart';
import '../core/pergunta_livre.dart';
import '../core/personalidade.dart';
import 'habilidades_service.dart';
import 'personalidade_store.dart';
import 'provider_service.dart';

/// Ponte que responde perguntas livres vindas do serviço de segundo plano.
///
/// O detector de palavra escuta com o app fechado e entrega a frase aqui: o
/// mesmo provedor de IA da conversa responde e o serviço fala a resposta. Se o
/// motor do Flutter não estiver de pé (app encerrado pelo Android), o Kotlin
/// recebe `null` e diz isso em voz alta, em vez de afirmar que a função não
/// existe.
class PonteIaFundo {
  PonteIaFundo._();

  static const canal = MethodChannel('com.jarvis.nova/fundo_ia');

  static bool _ligada = false;
  static ProviderService? _servico;

  /// Liga o atendimento das perguntas. Chamado uma vez na abertura do app.
  static void ligar({ProviderService? servico}) {
    if (_ligada) return;
    _ligada = true;
    _servico = servico ?? ProviderService(secrets: PlatformSecretStore());
    canal.setMethodCallHandler(_atender);
  }

  /// Só para teste: desfaz a ligação para um novo caso poder registrar a sua.
  static void desligarParaTeste() {
    _ligada = false;
    _servico = null;
    canal.setMethodCallHandler(null);
  }

  static Future<Object?> _atender(MethodCall call) async {
    if (call.method != 'responderPergunta') {
      throw MissingPluginException('Método não tratado: ${call.method}');
    }
    final argumentos = call.arguments;
    final texto = argumentos is Map
        ? (argumentos['texto']?.toString() ?? '').trim()
        : '';
    if (texto.isEmpty) {
      throw PlatformException(
          code: 'pedido_vazio', message: 'A pergunta chegou vazia.');
    }
    return responderPergunta(texto);
  }

  /// Resposta curta e falável para [texto]; lança quando não há provedor.
  static Future<String> responderPergunta(String texto,
      {ProviderService? servico}) async {
    final provedor = servico ?? _servico;
    if (provedor == null) {
      throw PlatformException(
          code: 'ponte_desligada', message: 'A ponte de IA não foi iniciada.');
    }
    // Circuito por prompt: responde no aparelho, sem chave e sem rede.
    final circuito = responderPedidoDeCircuito(texto);
    if (circuito != null) return circuito.textoFalado;
    // Edição do circuito aberto: vale quando o mesmo motor já o tem na memória.
    final edicao = responderEdicaoDeCircuito(texto, CircuitoEmUso.atual);
    if (edicao != null) return edicao.textoFalado;
    final escolhido = await provedor.firstConfiguredProvider();
    if (escolhido == null) {
      throw PlatformException(
          code: 'sem_provedor',
          message: 'Nenhum provedor de IA está configurado. Cadastre uma chave '
              'ou ative o Zero-Key em Provedores de IA.');
    }
    var personalidade = const Personalidade();
    try {
      personalidade = (await PersonalidadeStore.abrir()).carregar();
    } catch (_) {
      // Preferência indisponível não impede responder; fica o padrão.
    }
    final estilo =
        estiloDoTurno(personalidade, texto, recentes: const [], semente: 0);
    // Habilidades do aparelho: só as que casam com a pergunta entram no pedido.
    var bloco = '';
    try {
      final carregadas = await const HabilidadesService().carregar();
      bloco = blocoHabilidades(habilidadesQueCasam(carregadas.habilidades, texto));
    } catch (_) {
      bloco = '';
    }
    final resposta = await provedor.complete(
      escolhido.id,
      mensagensPerguntaLivre(texto,
          personalidade: estilo.prompt, habilidades: bloco),
    );
    return respostaFalada(resposta);
  }
}
