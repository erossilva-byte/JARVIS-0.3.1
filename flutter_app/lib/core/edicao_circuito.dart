/// Edição do circuito que já está no simulador, pedida por texto.
///
/// O bloco 100 montava do zero. Aqui o pedido é outro: “troca o R1 por 470
/// ohms”, “muda a fonte para 24 V”, “ajusta o atraso para 5 segundos”, “fecha o
/// S1”, “simula de novo”. A conversa lê o circuito publicado em
/// [CircuitoEmUso], aplica a mudança no próprio aparelho, **refaz a simulação**
/// e responde com o antes e o depois.
///
/// Limites declarados: muda valor de peça existente, abre e fecha interruptor e
/// refaz a conta. **Não** acrescenta nem remove peça (isso muda a ligação, e
/// adivinhar onde ligar seria inventar) e não mexe em contato auxiliar. Nesses
/// casos a resposta diz o motivo, em vez de entregar um esquema diferente do
/// pedido.
library;

import 'circuito.dart';
import 'circuito_no_chat.dart';
import 'texto_ptbr.dart';

/// Uma mudança feita, já em texto curto: “R1: 1 kΩ → 470 Ω”.
class MudancaCircuito {
  const MudancaCircuito(this.rotulo, this.antes, this.depois);

  final String rotulo;
  final String antes;
  final String depois;

  @override
  String toString() => '$rotulo: $antes → $depois';
}

/// Resposta local de um pedido de edição.
class RespostaEdicao {
  const RespostaEdicao({
    required this.ok,
    required this.texto,
    required this.textoFalado,
    this.circuito,
    this.simulacao,
    this.mudancas = const [],
  });

  final bool ok;
  final String texto;
  final String textoFalado;

  /// Circuito depois da edição — só quando a simulação fechou.
  final Circuito? circuito;
  final ResultadoSimulacao? simulacao;
  final List<MudancaCircuito> mudancas;
}

/// Verbos que mudam alguma coisa já montada.
const _verbosEdicao = r'(troca|troque|trocar|muda|mude|mudar|altera|altere|'
    r'alterar|ajusta|ajuste|ajustar|aumenta|aumente|aumentar|diminui|diminua|'
    r'reduz|reduza|coloca|coloque|poe|ponha|fecha|feche|abre|abra|refaz|'
    r'refaca|mexe)';

/// Formas de mandar recalcular sem mudar nada.
const _reSimular = r'(simula|simular|recalcula|recalcular|calcula|calcular|'
    r'refaz|refaca).*(de novo|outra vez|novamente)';

/// Nomes de peça que a edição reconhece.
const _alvos = <String, TipoElemento>{
  'resistor': TipoElemento.resistor,
  'lampada': TipoElemento.lampada,
  'led': TipoElemento.lampada,
  'fonte': TipoElemento.fonte,
  'tensao': TipoElemento.fonte,
  'motor': TipoElemento.motor,
  'temporizador': TipoElemento.temporizador,
  'bobina': TipoElemento.bobina,
  'interruptor': TipoElemento.interruptor,
  'fusivel': TipoElemento.fusivel,
};

/// Este texto pede para **mudar** o circuito que já está aberto?
bool pedidoDeEdicao(String texto) {
  final normal = normalizarTexto(texto);
  if (normal.isEmpty) return false;
  // Montar do zero é do bloco 100; pergunta sobre eletrônica vai para a IA.
  if (pedidoDeCircuito(texto)) return false;
  if (RegExp(_reSimular).hasMatch(normal)) return true;
  if (!RegExp(_verbosEdicao).hasMatch(normal)) return false;
  if (RegExp(r'\b(r|f|l|kt|fu|m|sb|s)[0-9]+\b').hasMatch(normal)) return true;
  for (final nome in _alvos.keys) {
    if (normal.contains(nome)) return true;
  }
  return false;
}

/// Interpreta e aplica o pedido em [base]; `null` quando não é pedido de edição.
///
/// [base] é o circuito do simulador. Sem ele, a resposta é honesta: não há o que
/// editar. Com ele, a simulação é refeita e o veredito vem no texto.
RespostaEdicao? responderEdicaoDeCircuito(String texto, Circuito? base) {
  if (!pedidoDeEdicao(texto)) return null;
  if (base == null) {
    const aviso = 'Não tenho um circuito aberto para editar. Monte um primeiro '
        '(“monta um divisor de tensão de 12 V”) ou abra o simulador.';
    return const RespostaEdicao(
        ok: false,
        texto: aviso,
        textoFalado: 'Não tenho um circuito aberto para editar. Monte um '
            'primeiro, ou abra o simulador.');
  }

  final normal = normalizarTexto(texto);
  final rotulos = base.rotulos();

  // Pedido só de recalcular: nada muda, a conta é refeita e conferida.
  if (RegExp(_reSimular).hasMatch(normal)) {
    return _concluir(base, base, const [], rotulos);
  }

  final alvo = _acharAlvo(normal, base, rotulos);
  if (alvo is String) {
    return RespostaEdicao(
        ok: false,
        texto: alvo,
        textoFalado: alvo,
        circuito: base);
  }
  final elemento = alvo as Elemento;
  final rotulo = rotulos[elemento.id] ?? elemento.tipo.name;

  // Interruptor: abre e fecha, sem número.
  if (elemento.tipo == TipoElemento.interruptor &&
      RegExp(r'(fecha|feche|fechar|abre|abra|abrir)').hasMatch(normal) &&
      !RegExp(r'(para|por|em)\s*[0-9]').hasMatch(normal)) {
    final fechar = RegExp(r'(fecha|feche|fechar)').hasMatch(normal);
    if (elemento.fechado == fechar) {
      final estado = fechar ? 'já estava fechado' : 'já estava aberto';
      final aviso = 'O $rotulo $estado; nada mudou.';
      return RespostaEdicao(
          ok: true,
          texto: aviso,
          textoFalado: aviso,
          circuito: base,
          simulacao: base.simular());
    }
    return _concluir(base, base.atualizar(elemento.copiarCom(fechado: fechar)),
        [MudancaCircuito(rotulo, _estado(elemento.fechado), _estado(fechar))],
        rotulos);
  }

  final mudanca = _mudancaDeValor(normal, elemento, rotulo);
  if (mudanca is String) {
    return RespostaEdicao(
        ok: false, texto: mudanca, textoFalado: mudanca, circuito: base);
  }
  final par = mudanca as (Elemento, MudancaCircuito);
  return _concluir(
      base, base.atualizar(par.$1), [par.$2], rotulos);
}

/// Localiza a peça citada; devolve [Elemento] ou o motivo em texto.
Object _acharAlvo(
    String normal, Circuito circuito, Map<String, String> rotulos) {
  // Primeiro pelo rótulo: R1, L1, F1, KT1, FU1, M1, SB1, S1.
  final porRotulo =
      RegExp(r'\b(r|f|l|kt|fu|m|sb|s)[0-9]+\b').firstMatch(normal);
  if (porRotulo != null) {
    final chave = porRotulo[0]!.toUpperCase();
    for (final entrada in rotulos.entries) {
      if (entrada.value.toUpperCase() == chave) {
        return circuito.porId(entrada.key)!;
      }
    }
    return 'Não achei $chave no circuito. As peças são: '
        '${_listaDeRotulos(rotulos)}.';
  }

  for (final entrada in _alvos.entries) {
    if (!normal.contains(entrada.key)) continue;
    final achados = circuito.elementos
        .where((e) => e.tipo == entrada.value)
        .toList(growable: false);
    if (achados.isEmpty) {
      return 'O circuito não tem ${entrada.key}. As peças são: '
          '${_listaDeRotulos(rotulos)}.';
    }
    if (achados.length > 1) {
      final nomes = [
        for (final e in achados) rotulos[e.id] ?? e.id,
      ].join(', ');
      return 'Tem ${achados.length} ${_plural(entrada.key)} no circuito '
          '($nomes). '
          'Diga qual: “troca o ${nomes.split(', ').first} por …”.';
    }
    return achados.single;
  }

  return 'Diga qual peça mudar: ${_listaDeRotulos(rotulos)}.';
}

/// Valor novo da peça, com a unidade do tipo; devolve o par ou o motivo.
Object _mudancaDeValor(String normal, Elemento elemento, String rotulo) {
  // O número vem depois de “por”, “para”, “em” ou “com”; antes disso, o nome da
  // peça (R1) não pode ser lido como valor.
  final semRotulo =
      normal.replaceAll(RegExp(r'\b(r|f|l|kt|fu|m|sb|s)[0-9]+\b'), ' ');
  final trecho = _trechoDeValor(semRotulo);

  switch (elemento.tipo) {
    case TipoElemento.resistor:
    case TipoElemento.bobina:
      final ohms = _ohms(trecho);
      if (ohms == null) return _semValor(rotulo, 'um valor em ohms');
      return (
        elemento.copiarCom(valor: ohms),
        MudancaCircuito(
            rotulo, _ohmsTexto(elemento.valor), _ohmsTexto(ohms)),
      );
    case TipoElemento.fonte:
      // Na fonte, número solto já é tensão: “muda a fonte para 24”.
      final volts = _comUnidade(trecho, const ['v', 'volt', 'volts']) ??
          _numeroSolto(trecho);
      if (volts == null) return _semValor(rotulo, 'uma tensão em volts');
      final novo = _comDelta(normal, elemento.valor, volts);
      if (novo <= 0) {
        return 'A fonte não pode ficar com ${_voltsTexto(novo)}.';
      }
      return (
        elemento.copiarCom(valor: novo),
        MudancaCircuito(rotulo, _voltsTexto(elemento.valor), _voltsTexto(novo)),
      );
    case TipoElemento.lampada:
    case TipoElemento.motor:
      final watts = _comUnidade(trecho, const ['w', 'watt', 'watts']);
      final volts = _comUnidade(trecho, const ['v', 'volt', 'volts']);
      if (watts == null && volts == null) {
        return _semValor(rotulo, 'potência em watts ou tensão em volts');
      }
      var novo = elemento;
      if (watts != null) novo = novo.copiarCom(valor: watts);
      if (volts != null) novo = novo.copiarCom(tensaoNominal: volts);
      return (
        novo,
        MudancaCircuito(
            rotulo,
            '${_wattsTexto(elemento.valor)} / '
                '${_voltsTexto(elemento.tensaoNominal)}',
            '${_wattsTexto(novo.valor)} / '
                '${_voltsTexto(novo.tensaoNominal)}'),
      );
    case TipoElemento.temporizador:
      final segundos =
          _comUnidade(trecho, const ['s', 'seg', 'segundos', 'segundo']);
      if (segundos == null) {
        return _semValor(rotulo, 'um atraso em segundos');
      }
      if (segundos < 0) return 'O atraso não pode ser negativo.';
      return (
        elemento.copiarCom(atraso: segundos),
        MudancaCircuito(rotulo, '${_segundosTexto(elemento.atraso)}, atraso',
            '${_segundosTexto(segundos)}, atraso'),
      );
    case TipoElemento.fusivel:
      final amperes = _comUnidade(trecho, const ['a', 'ampere', 'amperes']);
      if (amperes == null) return _semValor(rotulo, 'uma corrente em ampères');
      return (
        elemento.copiarCom(valor: amperes),
        MudancaCircuito(
            rotulo, _amperesTexto(elemento.valor), _amperesTexto(amperes)),
      );
    case TipoElemento.interruptor:
      return 'Para o $rotulo, diga “fecha o $rotulo” ou “abre o $rotulo”.';
    default:
      return 'Não sei mudar o valor de $rotulo por texto; use o simulador.';
  }
}

String _semValor(String rotulo, String esperado) =>
    'Para mudar o $rotulo eu preciso de $esperado. Exemplo: “troca o $rotulo '
    'por 470 ohms”.';

/// Refaz a simulação, compara com o antes e monta o texto do resultado.
RespostaEdicao _concluir(Circuito antes, Circuito depois,
    List<MudancaCircuito> mudancas, Map<String, String> rotulos) {
  final anterior = antes.simular();
  final novo = depois.simular();
  if (!novo.calculado) {
    final erro = novo.erro ?? 'o sistema não fechou';
    return RespostaEdicao(
      ok: false,
      texto: 'Mudei o circuito, mas a simulação não fechou: $erro',
      textoFalado: 'Mudei o circuito, mas a simulação não fechou. $erro',
      circuito: antes,
      simulacao: anterior,
    );
  }

  final partes = <String>[];
  if (mudancas.isEmpty) {
    partes.add('Refiz a simulação sem mudar nada');
  } else {
    partes.add(
        'Refiz a simulação depois da edição: ${mudancas.join('; ')}');
  }

  final antesW = _wattsTexto(anterior.potenciaTotal);
  final depoisW = _wattsTexto(novo.potenciaTotal);
  partes.add(anterior.potenciaTotal == novo.potenciaTotal
      ? 'A potência total continua $depoisW'
      : 'A potência total foi de $antesW para $depoisW');

  // O que o elemento editado está sofrendo agora, se a peça existe e mede.
  if (mudancas.isNotEmpty) {
    final id = _idDaMudanca(depois, rotulos, mudancas.first.rotulo);
    final medida = id == null ? null : novo.medidas[id];
    if (medida != null) {
      partes.add('${mudancas.first.rotulo} ficou com '
          '${_voltsTexto(medida.tensao)} e ${_amperesTexto(medida.corrente)}');
    }
  }

  final avisos = novo.avisos
      .where((a) => a.gravidade != GravidadeAviso.info)
      .map((a) => a.texto)
      .toList(growable: false);
  if (avisos.isNotEmpty) {
    partes.add('Atenção: ${avisos.first}');
  } else if (novo.fusiveisQueimados.isNotEmpty) {
    partes.add('Atenção: um fusível queimou com essa mudança.');
  }

  final texto = '${partes.join('. ')}. Abra no simulador para ver o esquema.';
  final falado = texto
      .replaceAll(' → ', ' para ')
      .replaceAll('“', '')
      .replaceAll('”', '');
  return RespostaEdicao(
    ok: true,
    texto: texto,
    textoFalado: falado,
    circuito: depois,
    simulacao: novo,
    mudancas: mudancas,
  );
}

String? _idDaMudanca(
    Circuito circuito, Map<String, String> rotulos, String rotulo) {
  for (final entrada in rotulos.entries) {
    if (entrada.value == rotulo) return entrada.key;
  }
  return null;
}

/// Plural das peças que a edição entende, para a frase não sair macarrônica.
String _plural(String nome) => switch (nome) {
      'resistor' => 'resistores',
      'lampada' => 'lâmpadas',
      'led' => 'LEDs',
      'fonte' => 'fontes',
      'tensao' => 'fontes',
      'motor' => 'motores',
      'temporizador' => 'temporizadores',
      'bobina' => 'bobinas',
      'interruptor' => 'interruptores',
      'fusivel' => 'fusíveis',
      _ => '${nome}s',
    };

String _listaDeRotulos(Map<String, String> rotulos) =>
    rotulos.values.where((r) => r != 'fio').toSet().join(', ');

String _estado(bool fechado) => fechado ? 'fechado' : 'aberto';

/// Trecho do texto onde o valor deve estar: depois de por/para/em/com.
String _trechoDeValor(String normal) {
  final marca = RegExp(r'\b(por|para|em|com)\b').firstMatch(normal);
  if (marca == null) return normal;
  return normal.substring(marca.end);
}

/// Valor com unidade explícita (V, W, s, A), com vírgula ou ponto.
double? _comUnidade(String trecho, List<String> unidades) {
  final padrao = unidades.map(RegExp.escape).join('|');
  final m =
      RegExp('([0-9]+(?:[.,][0-9]+)?)\\s*($padrao)').firstMatch(trecho);
  if (m == null) return null;
  return double.tryParse(m[1]!.replaceAll(',', '.'));
}

/// Primeiro número do trecho, sem unidade (só na fonte).
double? _numeroSolto(String trecho) {
  final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(trecho);
  return m == null ? null : double.tryParse(m[1]!.replaceAll(',', '.'));
}

/// “aumenta … em 3 V” soma; “para 24 V” e “troca … por 24 V” fixam.
double _comDelta(String normal, double atual, double informado) {
  final delta = RegExp(r'\b(em)\b').hasMatch(normal) &&
      RegExp(r'\b(aumenta|aumente|diminui|diminua|reduz|reduza)\b')
          .hasMatch(normal);
  if (!delta) return informado;
  final diminuir =
      RegExp(r'\b(diminui|diminua|reduz|reduza)\b').hasMatch(normal);
  return diminuir ? atual - informado : atual + informado;
}

/// Ohms com os sufixos que se escreve no dia a dia: 470, 4k7, 2k2, 1M.
double? _ohms(String trecho) {
  final k = RegExp(r'([0-9]+)\s*k\s*([0-9]+)').firstMatch(trecho);
  if (k != null) {
    return (int.parse(k[1]!) + int.parse(k[2]!) / 10) * 1000;
  }
  final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*(k|m|meg|mega|ohms?|r)?')
      .firstMatch(trecho);
  if (m == null) return null;
  final numero = double.tryParse(m[1]!.replaceAll(',', '.'));
  if (numero == null) return null;
  final sufixo = m[2] ?? '';
  if (sufixo == 'k') return numero * 1000;
  if (sufixo == 'm' || sufixo == 'meg' || sufixo == 'mega') return numero * 1e6;
  return numero;
}

String _ohmsTexto(double valor) {
  if (valor >= 1e6) return '${_curto(valor / 1e6)} MΩ';
  if (valor >= 1000) return '${_curto(valor / 1000)} kΩ';
  return '${_curto(valor)} Ω';
}

String _voltsTexto(double valor) => '${_curto(valor)} V';
String _wattsTexto(double valor) => '${_curto(valor)} W';
String _segundosTexto(double valor) => '${_curto(valor)} s';
String _amperesTexto(double valor) => '${_curto(valor, casas: 3)} A';

String _curto(double valor, {int casas = 2}) {
  var texto = valor.toStringAsFixed(casas);
  if (texto.contains('.')) {
    texto = texto.replaceAll(RegExp(r'0+$'), '');
    texto = texto.replaceAll(RegExp(r'\.$'), '');
  }
  return texto.replaceAll('.', ',');
}
