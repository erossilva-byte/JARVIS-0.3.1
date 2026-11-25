/// Compatibilidade Android ↔ PC — protocolo `jarvis/2`.
///
/// A Etapa 3 pareou celular e PC, mas o canal só sabia ler status: o PC não
/// tinha como saber o que o celular daquela versão aceita, e nenhuma rota de
/// escrita existia. Este arquivo define o contrato que os dois lados passam a
/// falar, sem Flutter:
///
/// - **Negociação**: o celular anuncia `protocolo` e `recursos` em
///   `/jarvis/info`. Celular antigo não anuncia nada — o PC trata como
///   `jarvis/1` com o recurso `status`, e continua funcionando como antes.
/// - **Comando**: envelope `{protocolo, id, emitidoEm, acao, argumentos}` com
///   prazo de 60 s e `id` de uso único por 5 min. Ação fora da lista é recusada
///   antes de executar qualquer coisa.
///
/// O que continua fora: TLS, descoberta automática, e qualquer ação que não
/// esteja em [acoesRemotas]. A lista cresce por bloco, com teste para cada
/// ação nova — nada entra por conveniência da tela.
library;

/// Versão do protocolo que este lado fala.
const protocoloAtual = 'jarvis/2';

/// Versão assumida quando o outro lado não anuncia nada.
const protocoloLegado = 'jarvis/1';

/// Recurso de leitura: `GET /jarvis/status`.
const recursoStatus = 'status';

/// Recurso de escrita: `POST /jarvis/comando`.
const recursoComando = 'comando';

/// Folga aceita entre o relógio do PC e o do celular, em segundos.
const janelaDoComandoSegundos = 60;

/// Por quanto tempo um `id` de comando fica lembrado para não repetir.
const validadeDoNonceSegundos = 300;

/// Teto de comandos aceitos por minuto, para uma tela não virar metralhadora.
const comandosPorMinuto = 20;

/// Tamanho máximo do corpo aceito na rota de comando.
const tamanhoMaximoDoComando = 4096;

/// Ações que o celular aceita executar.
///
/// A lista de valores é o que a ação aceita em `argumentos.tela`; lista vazia
/// quer dizer “esta ação não leva argumento”. Ação nova entra aqui **e** no
/// espelho do PC (`platforms/desktop/pareamento.js`); o contrato do bloco 132
/// compara as duas listas.
const acoesRemotas = <String, List<String>>{
  'abrir_tela': ['memoria', 'pessoas', 'visao', 'historico', 'conversa'],
  'abrir_conversa': <String>[],
  'iniciar_escuta': <String>[],
};

/// Nomes legíveis das ações, para a resposta e para a tela do PC.
const nomesDasAcoes = <String, String>{
  'abrir_tela': 'abrir uma tela',
  'abrir_conversa': 'abrir a conversa',
  'iniciar_escuta': 'iniciar a escuta',
};

/// Recursos que este lado anuncia conforme o que está ligado na tela.
List<String> recursosAnunciados({required bool comando}) =>
    comando ? const [recursoStatus, recursoComando] : const [recursoStatus];

/// Bloco de negociação que entra em `/jarvis/info` e na resposta do pareamento.
Map<String, Object?> negociacao({required bool comando}) => {
      'protocolo': protocoloAtual,
      'recursos': recursosAnunciados(comando: comando),
    };

/// Lê o que o outro lado anunciou, aceitando quem não anuncia nada.
///
/// Celular da versão 1.108 e anteriores responde só `{nome, versao, desafio…}`:
/// vira `jarvis/1` com `[status]`. Recurso desconhecido é descartado, não vira
/// permissão.
({String protocolo, List<String> recursos}) lerNegociacao(Object? dados) {
  final mapa = dados is Map ? dados : const <String, Object?>{};
  final bruto = (mapa['protocolo'] ?? '').toString().trim();
  final protocolo = bruto == protocoloAtual || bruto == protocoloLegado ? bruto : protocoloLegado;
  final anunciados = mapa['recursos'];
  final recursos = <String>[];
  if (anunciados is List) {
    for (final item in anunciados) {
      final nome = item.toString().trim();
      if ((nome == recursoStatus || nome == recursoComando) && !recursos.contains(nome)) {
        recursos.add(nome);
      }
    }
  }
  if (!recursos.contains(recursoStatus)) recursos.insert(0, recursoStatus);
  if (protocolo == protocoloLegado && recursos.contains(recursoComando)) {
    // Protocolo 1 não tem rota de escrita; anunciar comando nele é ruído.
    recursos.remove(recursoComando);
  }
  return (protocolo: protocolo, recursos: recursos);
}

/// O outro lado aceita comando? Só vale com protocolo 2 **e** recurso dito.
bool aceitaComando(Object? dados) {
  final lido = lerNegociacao(dados);
  return lido.protocolo == protocoloAtual && lido.recursos.contains(recursoComando);
}

/// Comando já validado, pronto para executar.
class EnvelopeDeComando {
  EnvelopeDeComando({
    required this.id,
    required this.emitidoEm,
    required this.acao,
    this.argumentos = const <String, Object?>{},
  });

  final String id;
  final DateTime emitidoEm;
  final String acao;

  /// Argumentos já validados: `{'tela': ...}` em `abrir_tela`, vazio nas ações
  /// que não levam argumento.
  final Map<String, Object?> argumentos;

  /// Tela pedida, quando a ação é `abrir_tela`.
  String get tela => (argumentos['tela'] ?? '').toString();

  Map<String, Object?> paraMapa() => {
        'protocolo': protocoloAtual,
        'id': id,
        'emitidoEm': emitidoEm.toUtc().toIso8601String(),
        'acao': acao,
        'argumentos': argumentos,
      };
}

/// Resultado da conferência do envelope: ou executa, ou explica a recusa.
class ValidacaoDeComando {
  ValidacaoDeComando.recusado(this.erro, {this.codigoHttp = 422})
      : comando = null;

  ValidacaoDeComando.aceito(EnvelopeDeComando este)
      : comando = este,
        erro = '',
        codigoHttp = 200;

  final EnvelopeDeComando? comando;
  final String erro;
  final int codigoHttp;

  bool get ok => comando != null;
}

/// `id` precisa ser hexadecimal, 32 caracteres ou mais, e não pode repetir.
bool idDeComandoValido(Object? valor) =>
    RegExp(r'^[0-9a-f]{32,64}$').hasMatch(valor.toString().trim().toLowerCase());

/// Confere um pedido de comando inteiro antes de executar.
///
/// A ordem importa: primeiro o formato (nada executa com envelope torto), depois
/// o prazo, depois a repetição, depois a ação. Cada recusa diz o motivo em
/// português e o código HTTP correspondente.
ValidacaoDeComando validarComando(
  Object? dados, {
  required DateTime agora,
  required Set<String> idsUsados,
}) {
  final mapa = dados is Map ? dados : const <String, Object?>{};
  final protocolo = (mapa['protocolo'] ?? '').toString().trim();
  if (protocolo != protocoloAtual) {
    return ValidacaoDeComando.recusado('O PC falou um protocolo que este celular não conhece.', codigoHttp: 400);
  }
  final id = (mapa['id'] ?? '').toString().trim().toLowerCase();
  if (!idDeComandoValido(id)) {
    return ValidacaoDeComando.recusado('O comando veio sem identificador válido.', codigoHttp: 400);
  }
  final emitidoEm = DateTime.tryParse((mapa['emitidoEm'] ?? '').toString());
  if (emitidoEm == null) {
    return ValidacaoDeComando.recusado('O comando veio sem hora de emissão.', codigoHttp: 400);
  }
  final diferenca = agora.difference(emitidoEm.toUtc()).inSeconds.abs();
  if (diferenca > janelaDoComandoSegundos) {
    return ValidacaoDeComando.recusado(
      'O comando chegou fora do prazo de $janelaDoComandoSegundos s. Confira a hora dos dois aparelhos.',
      codigoHttp: 409,
    );
  }
  if (idsUsados.contains(id)) {
    return ValidacaoDeComando.recusado('Este comando já foi executado uma vez.', codigoHttp: 409);
  }
  final acao = (mapa['acao'] ?? '').toString().trim();
  final permitidos = acoesRemotas[acao];
  if (permitidos == null) {
    return ValidacaoDeComando.recusado('Ação desconhecida: $acao.', codigoHttp: 422);
  }
  final argumentos = mapa['argumentos'] is Map
      ? Map<String, Object?>.from(mapa['argumentos'] as Map)
      : const <String, Object?>{};
  if (permitidos.isEmpty) {
    // Ação sem argumento: qualquer campo aqui é pedido fora do contrato.
    if (argumentos.isNotEmpty) {
      return ValidacaoDeComando.recusado(
        'A ação “$acao” não leva argumento.',
        codigoHttp: 422,
      );
    }
    return ValidacaoDeComando.aceito(EnvelopeDeComando(
      id: id,
      emitidoEm: emitidoEm.toUtc(),
      acao: acao,
    ));
  }
  final tela = (argumentos['tela'] ?? '').toString().trim();
  if (!permitidos.contains(tela)) {
    return ValidacaoDeComando.recusado(
      'Para “$acao” este celular aceita: ${permitidos.join(', ')}.',
      codigoHttp: 422,
    );
  }
  return ValidacaoDeComando.aceito(EnvelopeDeComando(
    id: id,
    emitidoEm: emitidoEm.toUtc(),
    acao: acao,
    argumentos: {'tela': tela},
  ));
}

/// Memória curta dos `id`s e do ritmo: evita repetir comando e flood.
class RegistroDeComandos {
  RegistroDeComandos({this.intervaloMinimo = const Duration(seconds: 1)});

  /// Intervalo mínimo entre dois comandos, para a tela não piscar em rajada.
  final Duration intervaloMinimo;

  final Map<String, DateTime> _ids = <String, DateTime>{};
  final List<DateTime> _recentes = <DateTime>[];

  Set<String> get idsUsados => _ids.keys.toSet();

  void _limpar(DateTime agora) {
    _ids.removeWhere((_, quando) => agora.difference(quando).inSeconds > validadeDoNonceSegundos);
    _recentes.removeWhere((quando) => agora.difference(quando).inSeconds >= 60);
  }

  /// `true` quando o comando pode seguir; `false` quando é cedo ou é demais.
  bool podeExecutar(DateTime agora) {
    _limpar(agora);
    if (_recentes.length >= comandosPorMinuto) return false;
    final ultimo = _recentes.isEmpty ? null : _recentes.last;
    if (ultimo != null && agora.difference(ultimo) < intervaloMinimo) return false;
    return true;
  }

  void registrar(String id, DateTime agora) {
    _limpar(agora);
    _ids[id] = agora;
    _recentes.add(agora);
  }

  int get quantidadeNaUltimaHora => _recentes.length;
}
