/// Lógica ladder didática do sandbox CADeSIMU.
///
/// Um CLP executa o programa em ciclos: lê as entradas, resolve cada degrau
/// (contatos em série e em paralelo) e escreve as saídas; repete até estabilizar
/// ou até o limite de ciclos. Aqui isso é **análise lógica**, não simulação
/// elétrica: não há tensão, corrente nem tempo real. O resultado é o mesmo que
/// um CLP real daria para a mesma lógica, com as entradas informadas.
library;

/// Contato de um degrau: entrada ou saída (contato de selo) e se é NF.
class ContatoLadder {
  const ContatoLadder(this.nome, {this.normalmenteFechado = false});

  final String nome;
  final bool normalmenteFechado;

  bool fechado(Map<String, bool> entradas, Map<String, bool> saidas) {
    final valor = entradas[nome] ?? saidas[nome] ?? false;
    return normalmenteFechado ? !valor : valor;
  }
}

/// Um degrau: uma ou mais linhas em paralelo; cada linha é uma série de
/// contatos. Se qualquer linha conduz, a bobina de [saida] é energizada.
class DegrauLadder {
  const DegrauLadder({required this.saida, required this.linhas});

  final String saida;
  final List<List<ContatoLadder>> linhas;

  bool conduz(Map<String, bool> entradas, Map<String, bool> saidas) {
    for (final linha in linhas) {
      var fechada = true;
      for (final contato in linha) {
        if (!contato.fechado(entradas, saidas)) {
          fechada = false;
          break;
        }
      }
      if (fechada) return true;
    }
    return false;
  }
}

class ResultadoClp {
  const ResultadoClp({
    required this.saidas,
    required this.ciclos,
    required this.estabilizou,
  });

  final Map<String, bool> saidas;
  final int ciclos;
  final bool estabilizou;
}

class Clp {
  Clp(this.degraus, {this.limiteDeCiclos = 20});

  final List<DegrauLadder> degraus;
  final int limiteDeCiclos;

  /// Executa o programa até as saídas pararem de mudar (ou até o limite).
  ///
  /// [saidasIniciais] são as saídas retidas do ciclo anterior — é isso que
  /// mantém um selo ligado entre uma leitura e a seguinte, como no CLP real.
  ResultadoClp executar(Map<String, bool> entradas,
      {Map<String, bool> saidasIniciais = const {}}) {
    var saidas = <String, bool>{
      for (final d in degraus) d.saida: saidasIniciais[d.saida] ?? false,
    };
    var ciclos = 0;
    var estabilizou = false;
    while (ciclos < limiteDeCiclos) {
      ciclos++;
      // Cada ciclo lê as saídas do ciclo anterior: é assim que o contato de
      // selo (Q1 em paralelo com a partida) se mantém. Degraus com a mesma
      // saída funcionam como OU, na ordem do programa.
      final proximas = <String, bool>{
        for (final degrau in degraus)
          degrau.saida: degrau.conduz(entradas, saidas),
      };
      final igual = proximas.length == saidas.length &&
          proximas.entries.every((e) => saidas[e.key] == e.value);
      saidas = proximas;
      if (igual) {
        estabilizou = true;
        break;
      }
    }
    return ResultadoClp(
      saidas: Map.unmodifiable(saidas),
      ciclos: ciclos,
      estabilizou: estabilizou,
    );
  }
}

/// Programa de exemplo: partida direta com selo.
///
/// I1 (partida, NA) em paralelo com Q1 (selo) e em série com I2 (parada, NF)
/// energizam Q1. Q1 só cai quando I2 é acionada — a mesma lógica do contator.
Clp clpPartidaComSelo() => Clp([
      DegrauLadder(saida: 'Q1', linhas: [
        [const ContatoLadder('I1'), const ContatoLadder('I2', normalmenteFechado: true)],
        [const ContatoLadder('Q1'), const ContatoLadder('I2', normalmenteFechado: true)],
      ]),
    ]);

/// Programa de exemplo: duas botoeiras ligam e desligam uma saída com selo,
/// mostrando que o CLP mantém o estado sem contato físico de potência.
Clp clpLigaDesliga() => Clp([
      DegrauLadder(saida: 'Q1', linhas: [
        [const ContatoLadder('I1')],
        [const ContatoLadder('Q1')],
      ]),
      DegrauLadder(saida: 'Q2', linhas: [
        [const ContatoLadder('Q1'), const ContatoLadder('I2', normalmenteFechado: true)],
      ]),
    ]);

/// Lista os nomes de entrada citados pelo programa, na ordem em que aparecem.
List<String> entradasDoClp(Clp clp) {
  final nomes = <String>[];
  final saidas = clp.degraus.map((d) => d.saida).toSet();
  for (final degrau in clp.degraus) {
    for (final linha in degrau.linhas) {
      for (final contato in linha) {
        if (!saidas.contains(contato.nome) && !nomes.contains(contato.nome)) {
          nomes.add(contato.nome);
        }
      }
    }
  }
  return nomes;
}
