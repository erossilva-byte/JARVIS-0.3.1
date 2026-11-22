/// Histórico do que o JARVIS executou no aparelho.
///
/// Não depende de Flutter: o modelo lê o que o Android devolveu, ordena, limita e
/// formata o horário, então pode ser testado sem emulador. O armazenamento fica no
/// aparelho (Android `SharedPreferences`), não na conversa e não na nuvem.
library;

/// De onde veio o comando executado.
enum OrigemExecucao {
  voz('voz', 'Por voz'),
  segundoPlano('segundo_plano', 'Por voz, em segundo plano'),
  digitado('digitado', 'Digitado'),
  teste('teste', 'Teste na tela de segundo plano'),
  desconhecida('desconhecida', 'Origem não informada');

  const OrigemExecucao(this.id, this.rotulo);

  /// Valor gravado pelo Android.
  final String id;

  /// Texto mostrado na tela.
  final String rotulo;

  static OrigemExecucao deId(Object? valor) {
    final limpo = valor?.toString().trim() ?? '';
    for (final origem in OrigemExecucao.values) {
      if (origem.id == limpo) return origem;
    }
    return OrigemExecucao.desconhecida;
  }
}

/// Um comando executado, com horário, o pedido e o resultado relatado pelo Android.
class RegistroExecucao {
  const RegistroExecucao({
    required this.em,
    required this.origem,
    required this.pedido,
    required this.acao,
    required this.ok,
    required this.mensagem,
  });

  /// Máximo de registros guardados; o mais antigo sai primeiro.
  static const limite = 100;

  final DateTime em;
  final OrigemExecucao origem;

  /// O que foi ouvido ou digitado.
  final String pedido;

  /// O que o interpretador decidiu executar (ex.: "abrir o app WhatsApp").
  final String acao;

  /// Verdadeiro só quando o Android confirmou o resultado.
  final bool ok;

  /// Resposta lida depois da execução.
  final String mensagem;

  /// Lê um mapa do Android. Sem horário ou sem pedido, o registro é descartado
  /// em vez de virar uma linha vazia no histórico.
  static RegistroExecucao? deMapa(Object? bruto) {
    if (bruto is! Map) return null;
    final em = bruto['em'];
    DateTime? quando;
    if (em is int && em > 0) {
      quando = DateTime.fromMillisecondsSinceEpoch(em);
    } else if (em is String) {
      final numero = int.tryParse(em);
      if (numero != null && numero > 0) {
        quando = DateTime.fromMillisecondsSinceEpoch(numero);
      }
    }
    if (quando == null) return null;
    final pedido = (bruto['pedido'] ?? '').toString().trim();
    if (pedido.isEmpty) return null;
    return RegistroExecucao(
      em: quando,
      origem: OrigemExecucao.deId(bruto['origem']),
      pedido: pedido,
      acao: (bruto['acao'] ?? '').toString().trim(),
      ok: bruto['ok'] == true,
      mensagem: (bruto['mensagem'] ?? '').toString().trim(),
    );
  }

  /// Horário no formato 24 h, com dois dígitos.
  String get hora =>
      '${em.hour.toString().padLeft(2, '0')}:${em.minute.toString().padLeft(2, '0')}';

  /// O que aconteceu, em uma palavra.
  String get resultadoRotulo => ok ? 'Executado' : 'Não executado';

  /// Linha principal: a ação decidida; se não houve, o próprio pedido.
  String get titulo => acao.isEmpty ? pedido : acao;
}

/// Converte a resposta do Android em registros ordenados, sem duplicatas e no limite.
List<RegistroExecucao> registrosDeMapa(Object? bruto) {
  if (bruto is! Iterable) return const [];
  final vistos = <String>{};
  final lista = <RegistroExecucao>[];
  for (final item in bruto) {
    final registro = RegistroExecucao.deMapa(item);
    if (registro == null) continue;
    final chave =
        '${registro.em.millisecondsSinceEpoch}|${registro.pedido}|${registro.mensagem}';
    if (!vistos.add(chave)) continue;
    lista.add(registro);
  }
  lista.sort((a, b) => b.em.compareTo(a.em));
  return lista.length > RegistroExecucao.limite
      ? lista.sublist(0, RegistroExecucao.limite)
      : lista;
}

/// "Hoje", "Ontem" ou a data; usado como cabeçalho de cada dia.
String diaRotulo(DateTime em, DateTime agora) {
  final dia = DateTime(em.year, em.month, em.day);
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final diferenca = hoje.difference(dia).inDays;
  if (diferenca == 0) return 'Hoje';
  if (diferenca == 1) return 'Ontem';
  return '${em.day.toString().padLeft(2, '0')}/'
      '${em.month.toString().padLeft(2, '0')}/${em.year}';
}

/// Resumo curto do período mostrado; vazio quando não há nada.
String resumoExecucoes(List<RegistroExecucao> registros) {
  if (registros.isEmpty) return '';
  final executados = registros.where((r) => r.ok).length;
  final falhas = registros.length - executados;
  final total = registros.length == 1
      ? '1 comando'
      : '${registros.length} comandos';
  if (falhas == 0) return '$total · todos executados';
  if (executados == 0) return '$total · nenhum executado';
  return '$total · $executados executado${executados == 1 ? '' : 's'} · '
      '$falhas não executado${falhas == 1 ? '' : 's'}';
}
