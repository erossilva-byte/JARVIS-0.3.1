import 'dart:async';

import 'package:flutter/services.dart';

import '../core/circuito_em_uso.dart';
import '../core/circuito_no_chat.dart';
import '../core/edicao_circuito.dart';
import '../core/especialidades.dart';
import '../core/habilidades.dart';
import '../core/pergunta_livre.dart';
import '../core/personalidade.dart';
import 'executor_app.dart';
import 'habilidades_service.dart';
import 'personalidade_store.dart';
import 'provider_service.dart';
import 'voz_externa_service.dart';

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

  /// Prazo da voz externa no segundo plano, antes de a voz do aparelho falar.
  static const prazoVozExternaFundo = Duration(milliseconds: 3000);

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
    if (call.method == 'falarResposta') {
      final argumentos = call.arguments;
      final texto = argumentos is Map
          ? (argumentos['texto']?.toString() ?? '').trim()
          : '';
      return falarComVozExterna(texto);
    }
    if (call.method != 'responderPergunta') {
      throw MissingPluginException('Método não tratado: ${call.method}');
    }
    final argumentos = call.arguments;
    final texto =
        argumentos is Map ? (argumentos['texto']?.toString() ?? '').trim() : '';
    if (texto.isEmpty) {
      throw PlatformException(
          code: 'pedido_vazio', message: 'A pergunta chegou vazia.');
    }
    return responderPergunta(texto);
  }

  /// Fala pelo Fish Audio a resposta do segundo plano.
  ///
  /// O serviço de palavra de ativação não tem a chave no lado Android: quem
  /// guarda a chave é o cofre do Flutter. Por isso o MP3 é gerado aqui e tocado
  /// pelo canal de voz do serviço. `false` devolve a fala para a voz do
  /// aparelho — nunca deixa o JARVIS mudo.
  static Future<bool> falarComVozExterna(String texto) async {
    final limpo = texto.trim();
    if (limpo.isEmpty || !VozExternaConfig.pronta) return false;
    try {
      final servico = VozExternaService();
      // Com o app fechado ninguém vê o texto aparecer: a nuvem tem pouco tempo
      // para entregar o áudio antes de a voz do aparelho assumir a resposta.
      final resultado = await servico
          .gerar(limpo)
          .timeout(prazoVozExternaFundo,
              onTimeout: () => const ResultadoVozExterna(
                  erro: 'A voz externa passou do prazo em segundo plano.'));
      if (!resultado.ok) return false;
      return await servico.tocar(resultado.audio!);
    } catch (_) {
      return false;
    }
  }

  /// Enquanto a resposta não chega, avisa o serviço de que o pedido está vivo.
  ///
  /// Sem isso o prazo do segundo plano vencia durante uma resposta legítima e
  /// o usuário ouvia "o provedor demorou demais" mesmo com a IA respondendo.
  static Timer? _batida;

  static void _iniciarBatida() {
    _pararBatida();
    _batida = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(
          canal.invokeMethod<void>('progresso').catchError((Object _) => null));
    });
  }

  static void _pararBatida() {
    _batida?.cancel();
    _batida = null;
  }

  /// Resposta curta e falável para [texto]; lança quando não há provedor.
  static Future<String> responderPergunta(String texto,
      {ProviderService? servico}) async {
    _iniciarBatida();
    try {
      return await _responder(texto, servico: servico);
    } finally {
      _pararBatida();
    }
  }

  static Future<String> _responder(String texto,
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
    // Ação no app pedida de viva voz (ficha de pessoa): executa antes de
    // gastar provedor. A confirmação de consentimento vem na fala seguinte,
    // enquanto este motor está de pé.
    final acao = await ExecutorApp.executar(texto);
    if (acao != null) return acao.mensagemFalada;
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
      bloco =
          blocoHabilidades(habilidadesQueCasam(carregadas.habilidades, texto));
    } catch (_) {
      bloco = '';
    }
    final resposta = await provedor.complete(
      escolhido.id,
      mensagensPerguntaLivre(texto,
          personalidade: estilo.prompt,
          habilidades: bloco,
          // A mesma especialização da conversa vale na voz de fundo.
          especialidade: blocoDaEspecialidade(especialidadeDe(texto))),
    );
    return respostaFalada(resposta);
  }
}
