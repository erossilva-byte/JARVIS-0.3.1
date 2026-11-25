import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/pedido_abrir.dart';
import '../pages.dart';
import '../provider_settings_page.dart';
import '../services/acessibilidade_page.dart';
import '../services/aparelho_page.dart';
import '../services/arquivos_page.dart';
import '../services/atualizacao_page.dart';
import '../services/avatar_page.dart';
import '../services/backups_page.dart';
import '../services/cadesimu_page.dart';
import '../services/circuito_page.dart';
import '../services/comandos_android_page.dart';
import '../services/conversa_store.dart';
import '../services/dispositivo_page.dart';
import '../services/gestos_page.dart';
import '../services/habilidades_page.dart';
import '../services/hermes_page.dart';
import '../services/historico_page.dart';
import '../services/historico_voz_page.dart';
import '../services/kws_settings_page.dart';
import '../services/mapa_voz_page.dart';
import '../services/memoria_page.dart';
import '../services/memoria_store.dart';
import '../services/modelos_locais_page.dart';
import '../services/palco_page.dart';
import '../services/palco_regras_page.dart';
import '../services/palco_regras_store.dart';
import '../services/personalidade_page.dart';
import '../services/personalidade_store.dart';
import '../services/pessoas_page.dart';
import '../services/pessoas_store.dart';
import '../services/programacao_page.dart';
import '../services/projetista_page.dart';
import '../services/segundo_plano_page.dart';
import '../services/seguranca_page.dart';
import '../services/tarefas_page.dart';
import '../services/timbre_page.dart';
import '../services/visao_page.dart';
import '../services/voice_conversation_page.dart';
import '../services/voz_externa_page.dart';
import '../services/voz_tela_cheia_page.dart';
import '../ui_common.dart';

/// Resultado de abrir uma tela do app por voz ou por pedido do Android.
class ResultadoAbrir {
  const ResultadoAbrir({
    required this.ok,
    required this.mensagem,
    required this.acao,
  });

  final bool ok;
  final String mensagem;
  final String acao;
}

/// Abre as telas do próprio JARVIS a partir do texto falado ou de um `Intent`.
///
/// A mesma porta serve a três caminhos: a conversa (texto ou voz no app), o
/// serviço de segundo plano (que abre o app já na tela pedida) e o histórico.
/// Telas que dependem de cofre são abertas só depois de o cofre responder; se
/// ele não existir neste aparelho, a resposta diz isso em vez de abrir uma tela
/// vazia.
class AbrirTela {
  AbrirTela._();

  /// Navegador do app inteiro: a tela aberta por voz fica por cima de qualquer
  /// uma que esteja visível, sem precisar do contexto de quem falou.
  static final GlobalKey<NavigatorState> navegador =
      GlobalKey<NavigatorState>();

  /// Abre [tela] e devolve o que foi feito, em texto falável.
  static Future<ResultadoAbrir> abrir(TelaJarvis tela,
      {String assunto = ''}) async {
    final acao = 'abrir ${tela.rotulo}';
    final destino = navegador.currentState;
    if (destino == null) {
      return ResultadoAbrir(
        ok: false,
        acao: acao,
        mensagem: 'Abra o JARVIS para eu mostrar ${tela.rotulo}.',
      );
    }
    try {
      final pagina = await _pagina(tela);
      if (pagina == null) {
        return ResultadoAbrir(
          ok: false,
          acao: acao,
          mensagem: 'Não consegui preparar ${tela.rotulo} neste aparelho.',
        );
      }
      unawaited(destino.push(MaterialPageRoute<void>(builder: (_) => pagina)));
      return ResultadoAbrir(
        ok: true,
        acao: acao,
        mensagem: 'Abrindo ${tela.rotulo}.',
      );
    } catch (erro) {
      return ResultadoAbrir(
        ok: false,
        acao: acao,
        mensagem: 'Não consegui abrir ${tela.rotulo}: '
            '${erro.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Monta a tela pedida; `null` quando ela não pode ser aberta aqui.
  static Future<Widget?> _pagina(TelaJarvis tela) async {
    switch (tela) {
      case TelaJarvis.visao:
        return const VisaoPage();
      case TelaJarvis.palco:
        return const PalcoPage();
      case TelaJarvis.memoria:
        return MemoriaPage(store: await MemoriaStore.abrir());
      case TelaJarvis.pessoas:
        return PessoasPage(store: await PessoasStore.abrir());
      case TelaJarvis.tarefas:
        return const TarefasPage();
      case TelaJarvis.programacao:
        return const ProgramacaoPage();
      case TelaJarvis.arquivos:
        return const ArquivosPage();
      case TelaJarvis.cadesimu:
        return const CadesimuPage();
      case TelaJarvis.circuito:
        return const CircuitoPage();
      case TelaJarvis.projetista:
        return const ProjetistaPage();
      case TelaJarvis.seguranca:
        return const SegurancaPage();
      case TelaJarvis.personalizacao:
        return PersonalidadePage(store: await PersonalidadeStore.abrir());
      case TelaJarvis.configuracoes:
        return SettingsPage(controller: jarvisKwsController);
      case TelaJarvis.habilidades:
        return const HabilidadesPage();
      case TelaJarvis.gestos:
        return const GestosPage();
      case TelaJarvis.timbre:
        return const TimbrePage();
      case TelaJarvis.vozExterna:
        return const VozExternaPage();
      case TelaJarvis.provedores:
        return const ProviderSettingsPage();
      case TelaJarvis.historico:
        return HistoricoPage(store: await ConversaStore.abrir());
      case TelaJarvis.historicoVoz:
        return const HistoricoVozPage();
      case TelaJarvis.backups:
        return BackupsPage(store: await MemoriaStore.abrir());
      case TelaJarvis.regrasPalco:
        return PalcoRegrasPage(
            regras: (await PalcoRegrasStore.abrir()).carregar());
      case TelaJarvis.ativacao:
        return KwsSettingsPage(controller: jarvisKwsController);
      case TelaJarvis.mapaVoz:
        return const MapaVozPage();
      case TelaJarvis.aparelho:
        return const AparelhoPage();
      case TelaJarvis.comandos:
        return const ComandosAndroidPage();
      case TelaJarvis.acessibilidade:
        return const AcessibilidadePage();
      case TelaJarvis.dispositivo:
        return const DispositivoPage();
      case TelaJarvis.segundoPlano:
        return const SegundoPlanoPage();
      case TelaJarvis.atualizacoes:
        return const AtualizacaoPage();
      case TelaJarvis.avatar:
        return const AvatarPage();
      case TelaJarvis.hermes:
        return const HermesPage();
      case TelaJarvis.agentes:
        return const AgentesPage();
      case TelaJarvis.modelosLocais:
        return const ModelosLocaisPage();
      case TelaJarvis.conversa:
        return const VoiceConversationPage(initialCommand: '');
      case TelaJarvis.voz:
        return VozTelaCheiaPage(controller: jarvisKwsController);
    }
  }
}
