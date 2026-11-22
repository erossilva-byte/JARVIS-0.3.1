/// Ferramentas de engenharia do sandbox CADeSIMU.
///
/// Reúne o que a Fase 10 pede além da simulação elétrica:
/// - diagnóstico de ligações e verificação de continuidade;
/// - lista de materiais;
/// - formato de arquivo `.circ` próprio, documentado e versionado;
/// - dimensionamento didático de condutor e disjuntor (NBR 5410).
///
/// Limites declarados: o dimensionamento usa tabelas resumidas de cobre,
/// instalação B1, dois condutores carregados, tensão 127/220 V e queda máxima
/// de 4%. Não substitui projeto elétrico assinado por responsável técnico.
library;

import 'dart:convert';

import 'circuito.dart';

enum TipoDiagnostico {
  semFonte,
  semCarga,
  curto,
  foraDaMalha,
  contatoOrfao,
  temporizadorSemContato,
  contatoSemTemporizador,
  releSemContato,
  informacao,
}

class Diagnostico {
  const Diagnostico(this.tipo, this.texto, this.gravidade);

  final TipoDiagnostico tipo;
  final String texto;
  final GravidadeAviso gravidade;
}

/// Verifica o que dá para afirmar sobre o esquema **sem** simular: presença de
/// fonte e carga, curto por caminho de contatos fechados, elementos ilhados e
/// contatos apontando para donos que não existem.
///
/// Isto é análise de ligação, não validação elétrica completa. A simulação
/// numérica continua sendo a prova de tensão e corrente.
List<Diagnostico> diagnosticarCircuito(Circuito circuito) {
  final saida = <Diagnostico>[];
  final elementos = circuito.elementos;
  final fontes = elementos.where((e) => e.tipo == TipoElemento.fonte).toList();
  if (fontes.isEmpty) {
    saida.add(const Diagnostico(TipoDiagnostico.semFonte,
        'Não há fonte no circuito: nada será energizado.', GravidadeAviso.erro));
  }
  final cargas = elementos
      .where((e) =>
          e.tipo == TipoElemento.lampada ||
          e.tipo == TipoElemento.motor ||
          e.tipo == TipoElemento.resistor ||
          e.tipo == TipoElemento.bobina)
      .toList();
  if (cargas.isEmpty) {
    saida.add(const Diagnostico(TipoDiagnostico.semCarga,
        'Não há carga (lâmpada, motor, resistor ou bobina).', GravidadeAviso.atencao));
  }

  // Elementos que não compartilham nó com ninguém ficam fora da malha.
  final nosUsados = <int, int>{};
  for (final e in elementos) {
    nosUsados[e.a] = (nosUsados[e.a] ?? 0) + 1;
    nosUsados[e.b] = (nosUsados[e.b] ?? 0) + 1;
  }
  for (final e in elementos) {
    final grauA = nosUsados[e.a] ?? 0;
    final grauB = nosUsados[e.b] ?? 0;
    if (grauA <= 1 || grauB <= 1) {
      saida.add(Diagnostico(
        TipoDiagnostico.foraDaMalha,
        '${circuito.rotulos()[e.id] ?? e.tipo.name} está solto: um dos terminais '
        'não se liga a nenhum outro elemento.',
        GravidadeAviso.atencao,
      ));
    }
  }

  for (final e in elementos) {
    final dono = e.contatoDe;
    if (dono != null && circuito.porId(dono) == null) {
      saida.add(Diagnostico(
        TipoDiagnostico.contatoOrfao,
        'O contato ${circuito.rotulos()[e.id] ?? e.id} aponta para um comando '
        'que não existe mais no circuito.',
        GravidadeAviso.erro,
      ));
    }
  }
  for (final t in elementos.where((e) => e.tipo == TipoElemento.temporizador)) {
    if (circuito.contatosDe(t.id).isEmpty) {
      saida.add(Diagnostico(
        TipoDiagnostico.temporizadorSemContato,
        'O temporizador ${circuito.rotulos()[t.id] ?? t.id} não tem contato '
        '67/68: o atraso não comanda nada.',
        GravidadeAviso.atencao,
      ));
    }
  }
  for (final c in circuito.contatosTemporizados) {
    final dono = c.contatoDe == null ? null : circuito.porId(c.contatoDe!);
    if (dono == null || dono.tipo != TipoElemento.temporizador) {
      saida.add(Diagnostico(
        TipoDiagnostico.contatoSemTemporizador,
        'O contato ${circuito.rotulos()[c.id] ?? c.id} não está ligado a um '
        'temporizador válido.',
        GravidadeAviso.erro,
      ));
    }
  }
  for (final r in elementos.where((e) => e.tipo == TipoElemento.releTermico)) {
    final temContato =
        elementos.any((e) => e.tipo == TipoElemento.contatoRele && e.contatoDe == r.id);
    if (!temContato) {
      saida.add(Diagnostico(
        TipoDiagnostico.releSemContato,
        'O relé térmico ${circuito.rotulos()[r.id] ?? r.id} não tem contato '
        '95/96 ligado: o desarme não interrompe o comando.',
        GravidadeAviso.atencao,
      ));
    }
  }

  for (final fonte in fontes) {
    if (haContinuidade(circuito, fonte.a, fonte.b)) {
      saida.add(Diagnostico(
        TipoDiagnostico.curto,
        'Curto entre os terminais de ${circuito.rotulos()[fonte.id] ?? fonte.id}: '
        'há caminho só de fios e contatos fechados. Vai queimar o fusível ou a fonte.',
        GravidadeAviso.erro,
      ));
    }
  }

  if (saida.isEmpty) {
    saida.add(const Diagnostico(TipoDiagnostico.informacao,
        'Nenhum problema de ligação encontrado: fonte, carga e contatos coerentes.',
        GravidadeAviso.info));
  }
  return saida;
}

/// Existe caminho entre os nós [a] e [b] passando só por elementos de
/// resistência desprezível (fio, contato fechado, botoeira apertada)?
///
/// Cargas e fontes não contam como caminho: a pergunta é de continuidade
/// galvânica, a mesma que um multímetro em modo de teste responderia.
bool haContinuidade(Circuito circuito, int a, int b) {
  final fila = <int>[a];
  final vistos = <int>{a};
  while (fila.isNotEmpty) {
    final atual = fila.removeAt(0);
    for (final e in circuito.elementos) {
      // A fonte não é caminho: o teste é entre os terminais dela.
      if (e.tipo == TipoElemento.fonte || e.resistencia > 0.001 || !e.ativa) {
        continue;
      }
      int? vizinho;
      if (e.a == atual) vizinho = e.b;
      if (e.b == atual) vizinho = e.a;
      if (vizinho == null) continue;
      if (vizinho == b) return true;
      if (vistos.add(vizinho)) fila.add(vizinho);
    }
  }
  return false;
}

/// Lista de materiais em texto, com quantidade e especificação de cada tipo.
String listaDeMateriais(Circuito circuito) {
  final rotulos = circuito.rotulos();
  final grupos = <String, List<String>>{};
  for (final e in circuito.elementos) {
    final nome = switch (e.tipo) {
      TipoElemento.fonte => 'Fonte ${formatarNumero(e.valor)} V',
      TipoElemento.resistor => 'Resistor ${formatarNumero(e.valor)} Ω',
      TipoElemento.lampada =>
        'Lâmpada ${formatarNumero(e.valor)} W / ${formatarNumero(e.tensaoNominal, casas: 0)} V',
      TipoElemento.interruptor => 'Interruptor',
      TipoElemento.botoeira => e.sensor
          ? 'Sensor ${e.normalmenteFechado ? "NF" : "NA"}'
          : 'Botoeira ${e.normalmenteFechado ? "NF" : "NA"}',
      TipoElemento.bobina =>
        'Bobina de contator ${formatarNumero(e.tensaoNominal, casas: 0)} V',
      TipoElemento.contatoSelo => 'Contato auxiliar NA (selo)',
      TipoElemento.contatoNf => 'Contato auxiliar NF (intertravamento)',
      TipoElemento.contatoPotencia => 'Contato de potência do contator',
      TipoElemento.motor =>
        'Motor ${formatarNumero(e.valor)} W / ${formatarNumero(e.tensaoNominal, casas: 0)} V',
      TipoElemento.releTermico => 'Relé térmico ${formatarNumero(e.valor)} A',
      TipoElemento.contatoRele => 'Contato NF do relé térmico (95/96)',
      TipoElemento.temporizador =>
        'Temporizador ${formatarNumero(e.atraso)} s',
      TipoElemento.contatoTemporizado => 'Contato temporizado NA (67/68)',
      TipoElemento.contatoTemporizadoNf => 'Contato temporizado NF (67/68)',
      TipoElemento.fusivel => 'Fusível ${formatarNumero(e.valor)} A',
      TipoElemento.fio => 'Fio de ligação',
    };
    grupos.putIfAbsent(nome, () => []).add(rotulos[e.id] ?? e.id);
  }
  final linhas = <String>['Lista de materiais — ${circuito.colunas}×${circuito.linhas}'];
  final chaves = grupos.keys.toList()..sort();
  for (final chave in chaves) {
    final itens = grupos[chave]!;
    linhas.add('${itens.length}× $chave — ${itens.join(', ')}');
  }
  linhas.add('Total: ${circuito.elementos.length} elementos');
  return linhas.join('\n');
}

/// Identificador e versão do formato de arquivo próprio do simulador.
///
/// O formato é JSON com especificação aberta neste arquivo; não é o `.cad` do
/// CADeSIMU. Importar `.cad` continua sendo só leitura (ver cadesimu). Exportar
/// para um formato que não se conhece seria inventar dados.
const String formatoCircuito = 'jarvis.circ';
const int versaoFormatoCircuito = 1;

Map<String, Object?> circuitoParaJson(Circuito circuito) => {
      'formato': formatoCircuito,
      'versao': versaoFormatoCircuito,
      'colunas': circuito.colunas,
      'linhas': circuito.linhas,
      'elementos': [
        for (final e in circuito.elementos)
          {
            'id': e.id,
            'tipo': e.tipo.name,
            'a': e.a,
            'b': e.b,
            'valor': e.valor,
            'tensaoNominal': e.tensaoNominal,
            'fechado': e.fechado,
            'queimado': e.queimado,
            'pressionada': e.pressionada,
            'normalmenteFechado': e.normalmenteFechado,
            if (e.contatoDe != null) 'contatoDe': e.contatoDe,
            'desarmado': e.desarmado,
            'atraso': e.atraso,
            'atrasoQueda': e.atrasoQueda,
            'sensor': e.sensor,
          },
      ],
    };

String circuitoParaTexto(Circuito circuito) =>
    const JsonEncoder.withIndent('  ').convert(circuitoParaJson(circuito));

/// Lê o formato `.circ`. Qualquer problema vira [FormatException] com uma
/// mensagem que o usuário entende — nunca um circuito meio carregado.
Circuito circuitoDeTexto(String texto) {
  Object? bruto;
  try {
    bruto = jsonDecode(texto);
  } on FormatException {
    throw const FormatException('O texto não é um JSON válido.');
  }
  if (bruto is! Map) {
    throw const FormatException('O arquivo não tem um objeto na raiz.');
  }
  if (bruto['formato'] != formatoCircuito) {
    throw const FormatException('Este arquivo não é um circuito .circ do Jarvis.');
  }
  final versao = bruto['versao'];
  if (versao is! int || versao > versaoFormatoCircuito) {
    throw const FormatException(
        'Versão de formato mais nova do que este app entende.');
  }
  final colunas = bruto['colunas'];
  final linhas = bruto['linhas'];
  if (colunas is! int || linhas is! int || colunas < 2 || linhas < 2) {
    throw const FormatException('Grade inválida no arquivo.');
  }
  final lista = bruto['elementos'];
  if (lista is! List) {
    throw const FormatException('O arquivo não traz a lista de elementos.');
  }
  final elementos = <Elemento>[];
  for (final item in lista) {
    if (item is! Map) {
      throw const FormatException('Elemento inválido no arquivo.');
    }
    TipoElemento? tipo;
    for (final candidato in TipoElemento.values) {
      if (candidato.name == item['tipo']) tipo = candidato;
    }
    if (tipo == null) {
      throw FormatException('Tipo de elemento desconhecido: ${item['tipo']}.');
    }
    final a = item['a'];
    final b = item['b'];
    if (a is! int || b is! int || a < 0 || b < 0) {
      throw const FormatException('Nó inválido em um elemento.');
    }
    if (a >= colunas * linhas || b >= colunas * linhas) {
      throw const FormatException('Elemento fora da grade declarada.');
    }
    elementos.add(Elemento(
      id: chaveTrecho(a, b),
      tipo: tipo,
      a: a,
      b: b,
      valor: _numero(item['valor']) ?? 0,
      tensaoNominal: _numero(item['tensaoNominal']) ?? 12,
      fechado: item['fechado'] != false,
      queimado: item['queimado'] == true,
      pressionada: item['pressionada'] == true,
      normalmenteFechado: item['normalmenteFechado'] == true,
      contatoDe: item['contatoDe'] is String ? item['contatoDe'] as String : null,
      desarmado: item['desarmado'] == true,
      atraso: _numero(item['atraso']) ?? 0,
      atrasoQueda: _numero(item['atrasoQueda']) ?? 0,
      sensor: item['sensor'] == true,
    ));
  }
  final circuito = Circuito(colunas: colunas, linhas: linhas, elementos: elementos);
  // Dois elementos no mesmo trecho tornariam a grade ambígua.
  if (circuito.elementos.map((e) => e.id).toSet().length != elementos.length) {
    throw const FormatException('Há dois elementos no mesmo trecho da grade.');
  }
  return circuito;
}

double? _numero(Object? valor) => switch (valor) {
      num n => n.toDouble(),
      String s => double.tryParse(s.replaceAll(',', '.')),
      _ => null,
    };

/// Resultado do dimensionamento de um trecho.
class Dimensionamento {
  const Dimensionamento({
    required this.correnteProjeto,
    required this.correnteNominal,
    required this.disjuntor,
    required this.secaoMm2,
    required this.quedaVolts,
    required this.quedaPercentual,
    required this.aprovado,
    required this.observacoes,
  });

  final double correnteProjeto;
  final double correnteNominal;
  final double disjuntor;
  final double secaoMm2;
  final double quedaVolts;
  final double quedaPercentual;
  final bool aprovado;
  final List<String> observacoes;
}

/// Ampacidade resumida (ABNT NBR 5410, cobre, método B1, 2 condutores
/// carregados, 30 °C), em ampères por seção em mm².
final Map<double, double> ampacidadeCobreB1 = {
  1.5: 15.5,
  2.5: 21,
  4: 28,
  6: 36,
  10: 50,
  16: 68,
  25: 89,
  35: 110,
  50: 134,
  70: 171,
  95: 207,
};

/// Correntes nominais padronizadas de disjuntor residencial/motor.
const List<double> disjuntoresPadrao = [
  6, 10, 13, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125
];

double secaoParaAmpacidade(double corrente) {
  for (final entrada in ampacidadeCobreB1.entries) {
    if (entrada.value >= corrente) return entrada.key;
  }
  return ampacidadeCobreB1.keys.last;
}

double disjuntorPara(double corrente) {
  for (final valor in disjuntoresPadrao) {
    if (valor >= corrente) return valor;
  }
  return disjuntoresPadrao.last;
}

/// Queda de tensão em volts num trecho de ida e volta (dois condutores).
double quedaDeTensao({
  required double corrente,
  required double comprimentoM,
  required double secaoMm2,
  double resistividade = 0.0172,
}) {
  if (secaoMm2 <= 0) return double.infinity;
  return 2 * resistividade * comprimentoM / secaoMm2 * corrente;
}

/// Dimensiona condutor e disjuntor de uma carga resistiva ou de iluminação.
///
/// [fatorSeguranca] de 1,25 cobre a partida de motores e a reserva de uso;
/// [fatorPotencia] converte potência ativa em corrente aparente.
Dimensionamento dimensionarCarga({
  required double potenciaW,
  required double tensaoV,
  required double comprimentoM,
  double fatorPotencia = 1,
  double fatorSeguranca = 1.25,
  double quedaMaximaPercentual = 4,
}) {
  if (potenciaW <= 0 || tensaoV <= 0 || comprimentoM < 0) {
    throw ArgumentError('Potência, tensão e comprimento precisam ser positivos.');
  }
  final fp = fatorPotencia.clamp(0.5, 1.0);
  final correnteNominal = potenciaW / (tensaoV * fp);
  final correnteProjeto = correnteNominal * fatorSeguranca;
  final secao = secaoParaAmpacidade(correnteProjeto);
  final disjuntor = disjuntorPara(correnteProjeto);
  final queda = quedaDeTensao(
      corrente: correnteProjeto, comprimentoM: comprimentoM, secaoMm2: secao);
  final quedaPct = queda / tensaoV * 100;
  final observacoes = <String>[
    'Corrente nominal da carga: ${formatarNumero(correnteNominal, casas: 2)} A.',
    'Corrente de projeto com fator ${formatarNumero(fatorSeguranca, casas: 2)}: '
        '${formatarNumero(correnteProjeto, casas: 2)} A.',
    'Seção mínima por ampacidade (B1): ${formatarNumero(secao)} mm².',
    'Disjuntor padrão: ${formatarNumero(disjuntor, casas: 0)} A.',
    'Queda de tensão no trecho de ${formatarNumero(comprimentoM)} m: '
        '${formatarNumero(queda, casas: 2)} V '
        '(${formatarNumero(quedaPct, casas: 2)}%).',
  ];
  if (quedaPct > quedaMaximaPercentual) {
    observacoes.add(
        'Acima do limite de ${formatarNumero(quedaMaximaPercentual)}%: aumente a seção '
        'ou reduza a distância.');
  }
  if (disjuntor < correnteNominal) {
    observacoes.add('O disjuntor ficou abaixo da corrente nominal: revise a carga.');
  }
  return Dimensionamento(
    correnteProjeto: correnteProjeto,
    correnteNominal: correnteNominal,
    disjuntor: disjuntor,
    secaoMm2: secao,
    quedaVolts: queda,
    quedaPercentual: quedaPct,
    aprovado: quedaPct <= quedaMaximaPercentual && disjuntor >= correnteNominal,
    observacoes: observacoes,
  );
}

/// Dimensiona a alimentação de um motor de indução: corrente nominal pela
/// potência, fator de serviço de 1,25 no condutor e menção à corrente de
/// partida (cerca de 6× a nominal) para a escolha da curva do disjuntor.
Dimensionamento dimensionarMotor({
  required double potenciaW,
  required double tensaoV,
  required double comprimentoM,
  double fatorPotencia = 0.8,
  double rendimento = 0.85,
}) {
  if (rendimento <= 0 || rendimento > 1) {
    throw ArgumentError('Rendimento precisa ficar entre 0 e 1.');
  }
  final resultado = dimensionarCarga(
    potenciaW: potenciaW / rendimento,
    tensaoV: tensaoV,
    comprimentoM: comprimentoM,
    fatorPotencia: fatorPotencia,
  );
  return Dimensionamento(
    correnteProjeto: resultado.correnteProjeto,
    correnteNominal: resultado.correnteNominal,
    disjuntor: resultado.disjuntor,
    secaoMm2: resultado.secaoMm2,
    quedaVolts: resultado.quedaVolts,
    quedaPercentual: resultado.quedaPercentual,
    aprovado: resultado.aprovado,
    observacoes: [
      ...resultado.observacoes,
      'Corrente de partida estimada: '
          '${formatarNumero(resultado.correnteNominal * 6, casas: 2)} A (6× a nominal).',
      'Use disjuntor curva C ou D e relé térmico ajustado na corrente nominal.',
    ],
  );
}
