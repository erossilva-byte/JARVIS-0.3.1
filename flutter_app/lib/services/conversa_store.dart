import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/conversa.dart';
import '../core/segredo_pedido.dart';

/// Guarda conversas e o rascunho no armazenamento local da plataforma.
///
/// O formato é JSON versionado na chave; lista corrompida é tratada como vazia em vez de
/// derrubar a tela. Fixadas aparecem primeiro; depois, pela atualização mais recente.
class ConversaStore {
  ConversaStore(this._prefs);

  static const chaveConversas = 'jarvis.conversas.v1';
  static const chaveRascunho = 'jarvis.rascunho.v1';

  /// Conversa aberta nesta sessão do app.
  ///
  /// Fica só na memória de propósito: sair da conversa e voltar continua nela,
  /// mas fechar e abrir o JARVIS começa outra. O que fica para trás já está
  /// salvo no histórico. Em memória também evita esperar o disco para o
  /// primeiro comando da sessão entrar logo na conversa certa.
  static Conversa? conversaAberta;

  /// Só para teste: cada caso começa com a sessão limpa.
  static void reiniciarSessaoParaTeste() {
    conversaAberta = null;
  }

  final SharedPreferences _prefs;

  static Future<ConversaStore> abrir() async =>
      ConversaStore(await SharedPreferences.getInstance());

  List<Conversa> listar() {
    final bruto = _prefs.getString(chaveConversas);
    if (bruto == null || bruto.isEmpty) {
      return [];
    }
    try {
      final dados = jsonDecode(bruto);
      if (dados is! List) {
        return [];
      }
      return dados.map(Conversa.deJson).whereType<Conversa>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Conversa salva com este [id]; nulo quando ela não existe mais.
  Conversa? buscar(String id) {
    for (final conversa in listar()) {
      if (conversa.id == id) return conversa;
    }
    return null;
  }

  List<Conversa> ordenadas() {
    final lista = listar();
    lista.sort((a, b) {
      if (a.fixada != b.fixada) {
        return a.fixada ? -1 : 1;
      }
      return b.atualizadaEm.compareTo(a.atualizadaEm);
    });
    return lista;
  }

  Future<void> salvar(Conversa conversa) async {
    final lista = listar();
    final indice = lista.indexWhere((c) => c.id == conversa.id);
    if (indice >= 0) {
      lista[indice] = conversa;
    } else {
      lista.insert(0, conversa);
    }
    await _gravar(lista);
  }

  Future<void> apagar(String id) async {
    final lista = listar()..removeWhere((c) => c.id == id);
    await _gravar(lista);
  }

  Future<void> alternarFixada(String id) async {
    final lista = listar();
    for (final conversa in lista) {
      if (conversa.id == id) {
        conversa.fixada = !conversa.fixada;
      }
    }
    await _gravar(lista);
  }

  String get rascunho => _prefs.getString(chaveRascunho) ?? '';

  Future<void> salvarRascunho(String texto) async {
    if (texto.trim().isEmpty) {
      await _prefs.remove(chaveRascunho);
      return;
    }
    await _prefs.setString(chaveRascunho, protegerPinNoPedido(texto));
  }

  Future<void> limparRascunho() => _prefs.remove(chaveRascunho);

  /// Grava o histórico sem nenhum PIN ditado na conversa.
  ///
  /// A máscara é aplicada só na cópia que vai para o disco: a conversa aberta
  /// na tela continua com o texto como foi dito (aqui e em `salvar`), então
  /// nada muda durante a sessão. Ao reabrir, o que aparece é `[oculto]`.
  Future<void> _gravar(List<Conversa> lista) => _prefs.setString(chaveConversas,
      jsonEncode(lista.map(_paraJsonArmazenado).toList()));

  /// JSON da conversa como fica no aparelho: título e mensagens mascarados.
  static Map<String, Object?> _paraJsonArmazenado(Conversa conversa) => {
        ...conversa.paraJson(),
        'titulo': protegerPinNoPedido(conversa.titulo),
        'mensagens': [
          for (final mensagem in conversa.mensagens)
            {
              ...mensagem.paraJson(),
              'texto': protegerPinNoPedido(mensagem.texto),
            },
        ],
      };
}
