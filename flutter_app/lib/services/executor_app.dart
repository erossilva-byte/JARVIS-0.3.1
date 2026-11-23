import '../core/memoria_busca.dart' show normalizar;
import '../core/pedido_ficha.dart';
import '../core/pessoas.dart';
import 'pessoas_store.dart';

/// Resultado de uma ação de app pedida por texto ou voz.
class AcaoApp {
  const AcaoApp({
    required this.ok,
    required this.mensagem,
    required this.mensagemFalada,
    required this.acao,
    this.aguardandoConfirmacao = false,
  });

  final bool ok;
  final String mensagem;

  /// Versão curta para o alto-falante, sem markdown.
  final String mensagemFalada;
  final String acao;

  /// A ficha foi entendida, mas ainda falta o consentimento.
  final bool aguardandoConfirmacao;
}

/// Executa pedidos que mexem nos dados do app, sem provedor de IA.
///
/// Hoje faz a ficha de uma pessoa: entende os dados, pergunta uma vez pelo
/// consentimento e grava no mesmo armazenamento seguro da tela de Pessoas.
/// Quem chama pode ser a conversa (texto ou voz no app) ou a ponte do segundo
/// plano, então a mesma regra vale nos dois caminhos.
class ExecutorApp {
  ExecutorApp._();

  static PedidoFicha? _pendente;

  /// Ficha entendida e ainda não confirmada (só memória, nunca gravada).
  static PedidoFicha? get pendente => _pendente;

  /// Esquece a ficha pendente; usado pelos testes e ao trocar de assunto.
  static void esquecerPendente() => _pendente = null;

  /// Executa o pedido; `null` quando o texto não é uma ação do app.
  static Future<AcaoApp?> executar(
    String texto, {
    PessoasStore? fichas,
    DateTime Function()? agora,
  }) async {
    final pedido = pedidoDeFicha(texto);
    if (pedido != null) {
      _pendente = pedido;
      return AcaoApp(
        ok: true,
        aguardandoConfirmacao: true,
        acao: 'ficha aguardando confirmação',
        mensagem: 'Entendi a ficha de ${pedido.resumo}. Ela só é guardada com '
            'consentimento: confirme que você tem o consentimento de '
            '${pedido.nome} e diga “confirmo”. Nada foi salvo ainda.',
        mensagemFalada: 'Entendi a ficha de ${pedido.nome}. Confirme que você '
            'tem o consentimento e diga confirmo para guardar.',
      );
    }
    final atual = _pendente;
    if (atual == null) return null;
    if (cancelamentoDeFicha(texto)) {
      _pendente = null;
      return const AcaoApp(
        ok: true,
        acao: 'ficha cancelada',
        mensagem: 'Ficha cancelada. Nada foi guardado.',
        mensagemFalada: 'Ficha cancelada. Nada foi guardado.',
      );
    }
    if (!confirmacaoDeFicha(texto)) return null;
    _pendente = null;
    return _salvar(atual, fichas, agora);
  }

  static Future<AcaoApp> _salvar(
    PedidoFicha pedido,
    PessoasStore? fichas,
    DateTime Function()? agora,
  ) async {
    try {
      final store = fichas ?? await PessoasStore.abrir();
      final lista = await store.listar();
      final existente = lista
          .where((p) => normalizar(p.nome) == normalizar(pedido.nome))
          .firstOrNull;
      final quando = (agora ?? DateTime.now)();
      final ficha = Pessoa(
        id: existente?.id ?? '',
        nome: pedido.nome,
        apelido: pedido.apelido.isNotEmpty
            ? pedido.apelido
            : (existente?.apelido ?? ''),
        relacao: pedido.relacao.isNotEmpty
            ? pedido.relacao
            : (existente?.relacao ?? ''),
        contatos: existente?.contatos ?? '',
        preferencias: existente?.preferencias ?? '',
        observacoes: pedido.observacoes.isNotEmpty
            ? pedido.observacoes
            : (existente?.observacoes ?? ''),
        compromissos: existente?.compromissos ?? '',
        historico: existente?.historico ?? '',
        consentimento: true,
        criadaEm: existente?.criadaEm ?? quando,
        atualizadaEm: quando,
      );
      final resultado = await store.salvar(ficha);
      if (!resultado.ok) {
        return AcaoApp(
          ok: false,
          acao: 'ficha recusada',
          mensagem: 'Não guardei a ficha de ${pedido.nome}: ${resultado.erro}',
          mensagemFalada:
              'Não guardei a ficha de ${pedido.nome}. ${resultado.erro}',
        );
      }
      return AcaoApp(
        ok: true,
        acao: existente == null ? 'ficha criada' : 'ficha atualizada',
        mensagem: 'Ficha de ${pedido.resumo} guardada no aparelho.',
        mensagemFalada: 'Ficha de ${pedido.nome} guardada.',
      );
    } catch (_) {
      return AcaoApp(
        ok: false,
        acao: 'ficha indisponível',
        mensagem: 'Não consegui abrir o armazenamento seguro das fichas neste '
            'aparelho. Nada foi guardado.',
        mensagemFalada: 'Não consegui abrir as fichas neste aparelho. Nada foi '
            'guardado.',
      );
    }
  }
}
