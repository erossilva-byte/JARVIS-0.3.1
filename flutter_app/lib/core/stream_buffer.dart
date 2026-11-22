import 'dart:async';

/// Agrupa tokens do streaming da IA antes de reconstruir a interface.
///
/// A Seção 3D exige atualizar a tela em intervalos de 16 a 50 ms, em vez de a cada token: um
/// provedor pode emitir centenas de fragmentos por segundo, e reconstruir a conversa a cada um
/// derruba os quadros. O buffer acumula o que chega e entrega o texto completo no máximo uma vez
/// por intervalo.
///
/// O agendador é injetável para o teste controlar o tempo sem esperar de verdade.
class StreamBuffer {
  StreamBuffer({
    required this.aoAtualizar,
    this.intervalo = const Duration(milliseconds: 32),
    void Function(Duration, void Function())? agendador,
  }) : _agendar = agendador ?? ((duracao, acao) => Timer(duracao, acao));

  /// Recebe o texto acumulado (não o token isolado) a cada atualização.
  final void Function(String texto) aoAtualizar;

  /// Janela mínima entre duas atualizações da interface.
  final Duration intervalo;

  final void Function(Duration, void Function()) _agendar;
  final StringBuffer _pendente = StringBuffer();

  String _visivel = '';
  bool _agendado = false;
  bool _concluido = false;

  /// Texto já entregue à interface.
  String get texto => _visivel;

  /// Há token recebido e ainda não entregue.
  bool get pendente => _pendente.isNotEmpty;

  /// Recebe um fragmento do provedor. O primeiro fragmento agenda a entrega; os seguintes só
  /// acumulam até a janela abrir.
  void adicionar(String fragmento) {
    if (_concluido || fragmento.isEmpty) {
      return;
    }
    _pendente.write(fragmento);
    if (_agendado) {
      return;
    }
    _agendado = true;
    _agendar(intervalo, _entregar);
  }

  /// Encerra o streaming: entrega o que sobrou na hora, sem esperar a janela.
  void concluir() {
    _concluido = true;
    _entregar();
  }

  /// Descarta o que estava pendente e zera o texto (nova geração, conversa trocada).
  void limpar() {
    _pendente.clear();
    _visivel = '';
    _concluido = false;
    _agendado = false;
    aoAtualizar(_visivel);
  }

  void _entregar() {
    _agendado = false;
    if (_pendente.isEmpty) {
      return;
    }
    _visivel += _pendente.toString();
    _pendente.clear();
    aoAtualizar(_visivel);
  }
}
