import 'dart:io';

import 'package:jarvis_nova/core/fundo.dart';

void main() {
  const pronto = EstadoFundo(
    modoSemTela: true,
    podeAbrirApps: true,
    servicoAtivo: true,
    ouvindo: true,
    ultimaAcao: 'abrir app whatsapp',
    ultimoResultado: 'WhatsApp aberto.',
    ultimoOk: true,
    ponteDisponivel: true,
  );

  // 1. "Pronto" exige as três coisas: serviço, modo sem tela e autorização.
  assert(fundoPronto(pronto), 'estado completo deveria estar pronto');
  assert(!fundoPronto(pronto.copiarCom(modoSemTela: false)),
      'sem modo sem tela não pode dizer pronto');
  assert(!fundoPronto(pronto.copiarCom(podeAbrirApps: false)),
      'sem autorização de sobreposição não pode dizer pronto');
  assert(!fundoPronto(EstadoFundo.vazio), 'estado vazio não pode dizer pronto');
  assert(!EstadoFundo.vazio.ponteDisponivel, 'canal ausente deveria ser explícito');

  // 2. Pendências listam exatamente o que falta, sem inventar sucesso.
  assert(pendenciasFundo(pronto).isEmpty, 'estado completo não deveria ter pendência');
  final semNada = pendenciasFundo(
      pronto.copiarCom(modoSemTela: false, podeAbrirApps: false));
  assert(semNada.length == 2, 'duas pendências esperadas, achei ${semNada.length}');
  assert(semNada.first.contains('sem abrir a tela'), 'pendência do modo ausente');
  assert(semNada.last.contains('Exibir sobre outros apps'),
      'pendência da autorização ausente');
  final semServico = EstadoFundo.fromMap({
    'modoSemTela': true,
    'podeAbrirApps': true,
    'servicoAtivo': false,
  });
  assert(pendenciasFundo(semServico).single.contains('escuta'),
      'pendência da escuta ausente');
  assert(pendenciasFundo(EstadoFundo.vazio).isEmpty,
      'canal ausente não deve listar pendências do Android');

  // 3. Resumo diz o estado real, inclusive quando o canal não existe.
  assert(resumoFundo(EstadoFundo.vazio).contains('app Android'),
      'fora do Android precisa avisar');
  assert(resumoFundo(semServico).contains('detector não está ativo'),
      'serviço parado precisa ser dito');
  assert(resumoFundo(pronto).contains('Chame “Jarvis”'),
      'escutando precisa convidar ao comando');
  final emEspera = EstadoFundo.fromMap({
    'servicoAtivo': true,
    'modoSemTela': true,
    'podeAbrirApps': true,
  });
  assert(resumoFundo(emEspera).contains('em espera'), 'espera precisa ser dita');

  // 4. Mapa do canal é lido com tolerância e sem inventar valores.
  final lido = EstadoFundo.fromMap({
    'modoSemTela': true,
    'podeAbrirApps': false,
    'servicoAtivo': true,
    'ouvindo': true,
    'ultimaAcao': 'lanterna',
    'ultimoResultado': 'Lanterna ligada.',
    'ultimoOk': true,
    'ultimoEm': 1700000000000,
  });
  assert(lido.modoSemTela && lido.servicoAtivo && lido.ouvindo, 'flags perdidas');
  assert(!lido.podeAbrirApps, 'autorização inventada');
  assert(lido.ultimoEm != null && lido.ultimoEm!.year >= 2023, 'data da ação perdida');
  final tolerante = EstadoFundo.fromMap({});
  assert(!tolerante.modoSemTela && !tolerante.servicoAtivo, 'vazio virou ligado');
  assert(tolerante.ultimoEm == null, 'data inventada');
  assert(tolerante.ultimaAcao.isEmpty, 'ação inventada');
  assert(EstadoFundo.fromMap({'ultimoEm': 0}).ultimoEm == null,
      'zero deveria significar nunca');

  // 5. Idade da ação em linguagem simples.
  final agora = DateTime(2026, 11, 19, 12, 0);
  assert(idadeUltimaAcao(null, agora) == null, 'sem ação deveria ser nulo');
  assert(idadeUltimaAcao(agora.subtract(const Duration(seconds: 12)), agora) == 'há 12 s',
      'segundos errados');
  assert(idadeUltimaAcao(agora.subtract(const Duration(minutes: 5)), agora) == 'há 5 min',
      'minutos errados');
  assert(idadeUltimaAcao(agora.subtract(const Duration(hours: 3)), agora) == 'há 3 h',
      'horas erradas');
  assert(idadeUltimaAcao(agora.subtract(const Duration(days: 2)), agora) == 'há 2 dia(s)',
      'dias errados');
  assert(idadeUltimaAcao(agora.add(const Duration(minutes: 1)), agora) == 'agora mesmo',
      'futuro deveria virar agora mesmo');

  // 6. O copiarCom não mexe no que não foi pedido e os limites são declarados.
  final copiado = pronto.copiarCom(modoSemTela: false);
  assert(!copiado.modoSemTela && copiado.podeAbrirApps, 'cópia alterou outro campo');
  assert(copiado.ultimaAcao == pronto.ultimaAcao, 'cópia perdeu o histórico');
  assert(acoesEmSegundoPlano.length >= 4, 'poucas ações declaradas');
  assert(limitesSegundoPlano.any((l) => l.contains('Exibir sobre outros apps')),
      'limite da autorização não declarado');
  assert(limitesSegundoPlano.any((l) => l.contains('reiniciar')),
      'limite do reinício não declarado');
  assert(limitesSegundoPlano.any((l) => l.contains('offline')),
      'limite do reconhecimento offline não declarado');

  stdout.writeln(
      'OK: segundo plano — pronto, pendências, resumo, leitura tolerante, idade e limites');
}
