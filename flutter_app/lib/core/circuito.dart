/// Simulador de circuitos DC resistivos, calculado no próprio aparelho.
///
/// O circuito é montado numa grade: cada trecho entre dois nós vizinhos é um
/// elemento de dois terminais (fonte, resistor, lâmpada, interruptor, fusível
/// ou fio). A solução usa análise nodal modificada (MNA) com eliminação de
/// Gauss e pivoteamento parcial, em Dart puro, sem dependência externa e sem
/// enviar o circuito a nenhum provedor.
///
/// Limites declarados: corrente contínua, elementos lineares, fontes ideais e
/// **comando por contator** (bobina, contato de selo e botoeira), resolvido por
/// iteração até o comando estabilizar. Não há corrente alternada, indutores,
/// capacitores, motores, temporizadores nem CLP. Isto é simulação numérica de
/// verdade — não é análise lógica nem o CADeSIMU.
library;

enum TipoElemento {
  fonte,
  resistor,
  lampada,
  interruptor,
  fusivel,
  fio,

  /// Botoeira de comando: NA (fecha ao apertar) ou NF (abre ao apertar).
  botoeira,

  /// Bobina de contator: carga resistiva que puxa acima de 70% da nominal e
  /// solta abaixo de 50%.
  bobina,

  /// Contato auxiliar de selo (NA), comandado pela bobina indicada em
  /// [Elemento.contatoDe].
  contatoSelo,

  /// Contato auxiliar NF do contator (21-22): fechado enquanto a bobina está
  /// desligada e aberto quando ela liga. É o que faz o intertravamento.
  contatoNf,

  /// Contato principal de potência do contator (1-2): fecha com a bobina.
  contatoPotencia,

  /// Motor de corrente contínua, tratado como carga com tensão e potência
  /// nominais.
  motor,

  /// Relé de sobrecarga (térmico): fica em série com a carga, desarma quando a
  /// corrente passa do ajuste e só volta com rearme.
  releTermico,

  /// Contato NF do relé térmico (95-96): aberto enquanto o relé está desarmado.
  contatoRele,

  /// Temporizador (bobina KT) com atraso em segundos: o relógio é avançado em
  /// passos pela tela, porque a simulação é instantânea.
  temporizador,

  /// Contato do temporizador (67-68): fecha quando o atraso se completa.
  contatoTemporizado,

  /// Contato NF do temporizador (67-68 NF): fica fechado enquanto o atraso não
  /// se completa e abre quando o tempo acaba.
  contatoTemporizadoNf,
}

enum GravidadeAviso { info, atencao, erro }

/// Chave normalizada de um trecho da grade: sempre do nó menor para o maior.
String chaveTrecho(int a, int b) => a <= b ? '${a}_$b' : '${b}_$a';

class Elemento {
  const Elemento({
    required this.id,
    required this.tipo,
    required this.a,
    required this.b,
    this.valor = 0,
    this.tensaoNominal = 12,
    this.fechado = true,
    this.queimado = false,
    this.pressionada = false,
    this.normalmenteFechado = false,
    this.contatoDe,
    this.desarmado = false,
    this.atraso = 0,
    this.atrasoQueda = 0,
    this.sensor = false,
  });

  /// Chave do trecho ocupado (ver [chaveTrecho]).
  final String id;
  final TipoElemento tipo;
  final int a;
  final int b;

  /// Fonte: tensão em volts. Resistor e bobina: ohms. Lâmpada: potência
  /// nominal em watts. Fusível: corrente de ruptura em ampères.
  final double valor;

  /// Tensão nominal da lâmpada ou tensão de bobina do contator, em volts.
  final double tensaoNominal;
  final bool fechado;
  final bool queimado;

  /// Botoeira apertada (o estado do contato vem de [normalmenteFechado]).
  final bool pressionada;

  /// Botoeira NF: fica fechada em repouso e abre quando apertada.
  final bool normalmenteFechado;

  /// Bobina ou relé que comanda este contato (id do trecho do dono).
  final String? contatoDe;

  /// Relé térmico desarmado: ele fica assim até o rearme.
  final bool desarmado;

  /// Atraso do temporizador em segundos (na subida, contando energizado).
  final double atraso;

  /// Retardo na queda, em segundos: quanto o contato demora a voltar depois que
  /// o temporizador perde energia. Zero abre (ou fecha) na hora.
  final double atrasoQueda;

  /// Sensor (fim de curso, presença) em vez de botoeira: o contato tem o mesmo
  /// modelo elétrico, mas fica acionado até o sensor voltar ao repouso — quem
  /// aperta é a máquina, não o dedo. Só muda o rótulo e a tela.
  final bool sensor;

  /// O elemento conduz agora? Contatos auxiliares dependem das bobinas ligadas,
  /// o contato do relé depende do desarme e o do temporizador do relógio.
  bool ativaEm(
    Set<String> bobinasLigadas, {
    Set<String> relesDesarmados = const {},
    Set<String> contatosTemporizados = const {},
  }) {
    switch (tipo) {
      case TipoElemento.contatoTemporizado:
        return contatosTemporizados.contains(id);
      case TipoElemento.contatoTemporizadoNf:
        return !contatosTemporizados.contains(id);
      case TipoElemento.temporizador:
        return true;
      case TipoElemento.contatoRele:
        return contatoDe == null || !relesDesarmados.contains(contatoDe);
      case TipoElemento.releTermico:
        return true;
      case TipoElemento.interruptor:
        return fechado;
      case TipoElemento.fusivel:
        return !queimado;
      case TipoElemento.botoeira:
        return normalmenteFechado ? !pressionada : pressionada;
      case TipoElemento.contatoSelo:
        return contatoDe != null && bobinasLigadas.contains(contatoDe);
      case TipoElemento.contatoNf:
        return contatoDe == null || !bobinasLigadas.contains(contatoDe);
      case TipoElemento.contatoPotencia:
        return contatoDe != null && bobinasLigadas.contains(contatoDe);
      case TipoElemento.motor:
      case TipoElemento.bobina:
      case TipoElemento.resistor:
      case TipoElemento.lampada:
      case TipoElemento.fonte:
      case TipoElemento.fio:
        return true;
    }
  }

  /// Estado sem nenhum contator ligado — só para leitura rápida do desenho.
  bool get ativa => ativaEm(const {});

  double get resistencia {
    switch (tipo) {
      // Contatos e fios do esquema são ideais: 1 µΩ, só para o sistema ter
      // solução numérica. A corrente de um curto fica enorme de propósito.
      case TipoElemento.fio:
      case TipoElemento.interruptor:
      case TipoElemento.fusivel:
      case TipoElemento.botoeira:
      case TipoElemento.contatoSelo:
      case TipoElemento.contatoNf:
      case TipoElemento.contatoPotencia:
      case TipoElemento.contatoRele:
      case TipoElemento.releTermico:
      case TipoElemento.contatoTemporizado:
      case TipoElemento.contatoTemporizadoNf:
        return 0.000001;
      case TipoElemento.resistor:
      case TipoElemento.bobina:
      case TipoElemento.temporizador:
        return valor.clamp(0.001, 1e9);
      case TipoElemento.lampada:
      case TipoElemento.motor:
        final potencia = valor <= 0 ? 0.001 : valor;
        final tensao = tensaoNominal <= 0 ? 1.0 : tensaoNominal;
        return tensao * tensao / potencia;
      case TipoElemento.fonte:
        return 0.0;
    }
  }

  Elemento copiarCom({
    TipoElemento? tipo,
    double? valor,
    double? tensaoNominal,
    bool? fechado,
    bool? queimado,
    bool? pressionada,
    bool? normalmenteFechado,
    String? contatoDe,
    bool? desarmado,
    double? atraso,
    double? atrasoQueda,
    bool? sensor,
    int? a,
    int? b,
  }) {
    final novoA = a ?? this.a;
    final novoB = b ?? this.b;
    return Elemento(
      id: chaveTrecho(novoA, novoB),
      tipo: tipo ?? this.tipo,
      a: novoA,
      b: novoB,
      valor: valor ?? this.valor,
      tensaoNominal: tensaoNominal ?? this.tensaoNominal,
      fechado: fechado ?? this.fechado,
      queimado: queimado ?? this.queimado,
      pressionada: pressionada ?? this.pressionada,
      normalmenteFechado: normalmenteFechado ?? this.normalmenteFechado,
      contatoDe: contatoDe ?? this.contatoDe,
      desarmado: desarmado ?? this.desarmado,
      atraso: atraso ?? this.atraso,
      atrasoQueda: atrasoQueda ?? this.atrasoQueda,
      sensor: sensor ?? this.sensor,
    );
  }
}

class AvisoCircuito {
  const AvisoCircuito(this.texto, this.gravidade);
  final String texto;
  final GravidadeAviso gravidade;
}

class Medida {
  const Medida({
    required this.id,
    required this.tensao,
    required this.corrente,
    required this.potencia,
  });

  final String id;

  /// Tensão entre os terminais, positiva do nó [Elemento.a] para [Elemento.b].
  final double tensao;

  /// Corrente no sentido a→b; nas fontes, positiva quando ela entrega energia.
  final double corrente;
  final double potencia;
}

class ResultadoSimulacao {
  const ResultadoSimulacao({
    required this.calculado,
    this.erro,
    this.tensoes = const {},
    this.medidas = const {},
    this.avisos = const [],
    this.fusiveisQueimados = const {},
    this.potenciaTotal = 0,
    this.bobinasLigadas = const {},
    this.relesDesarmados = const {},
    this.temporizadoresAtivos = const {},
  });

  const ResultadoSimulacao.falha(String motivo)
      : calculado = false,
        erro = motivo,
        tensoes = const {},
        medidas = const {},
        avisos = const [],
        fusiveisQueimados = const {},
        potenciaTotal = 0,
        bobinasLigadas = const {},
        relesDesarmados = const {},
        temporizadoresAtivos = const {};

  final bool calculado;
  final String? erro;
  final Map<int, double> tensoes;
  final Map<String, Medida> medidas;
  final List<AvisoCircuito> avisos;

  /// Trechos de fusível que romperam nesta simulação.
  final Set<String> fusiveisQueimados;
  final double potenciaTotal;

  /// Bobinas de contator que ficaram ligadas ao fim do cálculo. É este estado
  /// que precisa voltar na próxima simulação para o selo se manter fechado.
  final Set<String> bobinasLigadas;

  /// Relés térmicos que desarmaram nesta simulação.
  final Set<String> relesDesarmados;

  /// Temporizadores energizados neste instante (o relógio deles corre).
  final Set<String> temporizadoresAtivos;

  bool get curto => avisos.any((a) =>
      a.gravidade == GravidadeAviso.erro && a.texto.startsWith('Curto'));

  bool get temLampadaAcesa => medidas.entries.any((m) => m.value.potencia > 0);
}

class Circuito {
  Circuito({
    this.colunas = 6,
    this.linhas = 4,
    List<Elemento> elementos = const [],
  }) : elementos = List.unmodifiable(elementos);

  final int colunas;
  final int linhas;
  final List<Elemento> elementos;

  int no(int x, int y) => y * colunas + x;

  Elemento? em(int a, int b) {
    final id = chaveTrecho(a, b);
    for (final e in elementos) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Atraso efetivo de um contato 67/68: o próprio, quando ajustado; senão o
  /// atraso base do temporizador que o comanda.
  double atrasoDoContato(Elemento contato) {
    if (contato.atraso > 0) return contato.atraso;
    final dono = contato.contatoDe == null ? null : porId(contato.contatoDe!);
    return dono != null && dono.tipo == TipoElemento.temporizador
        ? dono.atraso
        : 0;
  }

  /// Retardo na queda efetivo de um contato: o próprio, quando ajustado;
  /// senão o retardo base do temporizador que o comanda.
  double atrasoQuedaDoContato(Elemento contato) {
    if (contato.atrasoQueda > 0) return contato.atrasoQueda;
    final dono = contato.contatoDe == null ? null : porId(contato.contatoDe!);
    return dono != null && dono.tipo == TipoElemento.temporizador
        ? dono.atrasoQueda
        : 0;
  }

  /// Contatos 67/68 (NA e NF) que apontam para este temporizador.
  Iterable<Elemento> contatosDe(String temporizadorId) => elementos.where((e) =>
      (e.tipo == TipoElemento.contatoTemporizado ||
          e.tipo == TipoElemento.contatoTemporizadoNf) &&
      e.contatoDe == temporizadorId);

  /// Todos os contatos 67/68 do circuito, com ou sem temporizador válido.
  Iterable<Elemento> get contatosTemporizados => elementos.where((e) =>
      e.tipo == TipoElemento.contatoTemporizado ||
      e.tipo == TipoElemento.contatoTemporizadoNf);

  /// Relógio próprio de um contato: o contador dele quando informado; sem ele,
  /// cai no relógio do temporizador (compatibilidade com circuitos antigos).
  double relogioDoContato(Elemento contato, Map<String, double> temposContato,
      Map<String, double> tempos) {
    final proprio = temposContato[contato.id];
    if (proprio != null) return proprio;
    final dono = contato.contatoDe == null ? null : porId(contato.contatoDe!);
    return dono == null ? 0 : (tempos[dono.id] ?? 0);
  }

  /// Relógio de queda próprio de um contato, com a mesma compatibilidade.
  double relogioQuedaDoContato(
      Elemento contato,
      Map<String, double> temposQuedaContato,
      Map<String, double> temposQueda) {
    final proprio = temposQuedaContato[contato.id];
    if (proprio != null) return proprio;
    final dono = contato.contatoDe == null ? null : porId(contato.contatoDe!);
    return dono == null ? 0 : (temposQueda[dono.id] ?? 0);
  }

  Elemento? porId(String id) {
    for (final e in elementos) {
      if (e.id == id) return e;
    }
    return null;
  }

  Circuito adicionar(Elemento elemento) {
    final outros =
        elementos.where((e) => e.id != elemento.id).toList(growable: true);
    outros.add(elemento);
    outros.sort((x, y) => x.id.compareTo(y.id));
    return Circuito(colunas: colunas, linhas: linhas, elementos: outros);
  }

  Circuito removerEm(int a, int b) => Circuito(
        colunas: colunas,
        linhas: linhas,
        elementos: elementos.where((e) => e.id != chaveTrecho(a, b)).toList(),
      );

  Circuito atualizar(Elemento elemento) => adicionar(elemento);

  Circuito marcarQueimados(Set<String> ids) => Circuito(
        colunas: colunas,
        linhas: linhas,
        elementos: [
          for (final e in elementos)
            ids.contains(e.id) ? e.copiarCom(queimado: true) : e,
        ],
      );

  Circuito desarmar(Set<String> ids) => Circuito(
        colunas: colunas,
        linhas: linhas,
        elementos: [
          for (final e in elementos)
            ids.contains(e.id) ? e.copiarCom(desarmado: true) : e,
        ],
      );

  /// Rearma todos os relés térmicos. Não religa o motor: a partida precisa
  /// ser apertada de novo, como no painel real.
  Circuito rearmarReles() => Circuito(
        colunas: colunas,
        linhas: linhas,
        elementos: [
          for (final e in elementos)
            e.tipo == TipoElemento.releTermico
                ? e.copiarCom(desarmado: false)
                : e,
        ],
      );

  Circuito trocarFusiveis() => Circuito(
        colunas: colunas,
        linhas: linhas,
        elementos: [
          for (final e in elementos)
            e.tipo == TipoElemento.fusivel ? e.copiarCom(queimado: false) : e,
        ],
      );

  Circuito limpar() => Circuito(colunas: colunas, linhas: linhas);

  /// Nomes curtos estáveis por tipo: F1, R1, L1, S1, FU1, SB1, K1 e K1-13/14.
  Map<String, String> rotulos() {
    final contagem = <TipoElemento, int>{};
    final mapa = <String, String>{};
    for (final e in elementos) {
      final n = (contagem[e.tipo] ?? 0) + 1;
      contagem[e.tipo] = n;
      mapa[e.id] = switch (e.tipo) {
        TipoElemento.fonte => 'F$n',
        TipoElemento.resistor => 'R$n',
        TipoElemento.lampada => 'L$n',
        TipoElemento.interruptor => 'S$n',
        TipoElemento.fusivel => 'FU$n',
        TipoElemento.fio => 'fio',
        // Sensor e botoeira dividem o modelo elétrico; o rótulo diferencia.
        TipoElemento.botoeira => e.sensor ? 'S$n' : 'SB$n',
        TipoElemento.bobina => 'K$n',
        // Os contatos auxiliares levam o nome da bobina que os comanda.
        TipoElemento.contatoSelo => 'selo',
        TipoElemento.contatoNf => 'intertravamento',
        TipoElemento.contatoPotencia => 'potência',
        TipoElemento.motor => 'M$n',
        TipoElemento.releTermico => 'FT$n',
        TipoElemento.contatoRele => 'rele',
        TipoElemento.temporizador => 'KT$n',
        TipoElemento.contatoTemporizado => 'temporizador',
        TipoElemento.contatoTemporizadoNf => 'temporizador NF',
      };
    }
    // Vários contatos do mesmo temporizador recebem um número no rótulo.
    final usosTemporizador = <String, int>{};
    for (final e in elementos) {
      if (e.tipo != TipoElemento.contatoTemporizado &&
          e.tipo != TipoElemento.contatoTemporizadoNf) {
        continue;
      }
      final chave = '${e.contatoDe}|${e.tipo.name}';
      usosTemporizador[chave] = (usosTemporizador[chave] ?? 0) + 1;
    }
    final vistosTemporizador = <String, int>{};
    for (final e in elementos) {
      final auxiliar = e.tipo == TipoElemento.contatoSelo ||
          e.tipo == TipoElemento.contatoNf ||
          e.tipo == TipoElemento.contatoPotencia ||
          e.tipo == TipoElemento.contatoRele ||
          e.tipo == TipoElemento.contatoTemporizado ||
          e.tipo == TipoElemento.contatoTemporizadoNf;
      if (!auxiliar) continue;
      final dono = e.contatoDe == null ? null : mapa[e.contatoDe];
      if (dono == null) {
        mapa[e.id] = switch (e.tipo) {
          TipoElemento.contatoSelo => 'selo',
          TipoElemento.contatoNf => 'intertravamento',
          TipoElemento.contatoRele => '95/96',
          TipoElemento.contatoTemporizado => '67/68',
          TipoElemento.contatoTemporizadoNf => '67/68 NF',
          _ => 'potência',
        };
      } else {
        var rotulo = switch (e.tipo) {
          TipoElemento.contatoSelo => '$dono-13/14',
          TipoElemento.contatoNf => '$dono-21/22',
          TipoElemento.contatoRele => '$dono-95/96',
          TipoElemento.contatoTemporizado => '$dono-67/68',
          TipoElemento.contatoTemporizadoNf => '$dono-67/68 NF',
          _ => '$dono-1/2',
        };
        if (e.tipo == TipoElemento.contatoTemporizado ||
            e.tipo == TipoElemento.contatoTemporizadoNf) {
          final chave = '${e.contatoDe}|${e.tipo.name}';
          final indice = (vistosTemporizador[chave] ?? 0) + 1;
          vistosTemporizador[chave] = indice;
          if ((usosTemporizador[chave] ?? 0) > 1) rotulo = '$rotulo ($indice)';
        }
        mapa[e.id] = rotulo;
      }
    }
    return mapa;
  }

  /// Simula com as proteções e o comando do contator: um fusível cujo limite é
  /// ultrapassado rompe e o circuito é recalculado já sem ele.
  ///
  /// [bobinasLigadas] é o estado vindo da simulação anterior. É ele que faz o
  /// contato de selo manter a bobina depois de soltar a botoeira de partida —
  /// contator tem memória, e quem chama precisa devolver o estado recebido em
  /// [ResultadoSimulacao.bobinasLigadas] na próxima conta.
  ResultadoSimulacao simular({
    Set<String> bobinasLigadas = const {},
    Map<String, double> tempos = const {},
    Map<String, double> temposQueda = const {},
    Map<String, double> temposContato = const {},
    Map<String, double> temposQuedaContato = const {},
  }) {
    var atual = this;
    final queimados = <String>{};
    final desarmados = <String>{};
    var ligadas = Set<String>.of(bobinasLigadas);
    var ultimo = _solucionar(
        bobinasLigadas: ligadas,
        temporizadoresAtivos: const {},
        tempos: tempos,
        temposQueda: temposQueda,
        temposContato: temposContato,
        temposQuedaContato: temposQuedaContato);
    for (var tentativa = 0; tentativa < 6; tentativa++) {
      final parcial =
          atual._comandar(ligadas, tempos, temposQueda, temposContato, temposQuedaContato);
      ultimo = parcial;
      if (!parcial.calculado) return parcial;
      ligadas = parcial.bobinasLigadas;
      final estourados = <String>{};
      for (final e in atual.elementos) {
        if (e.tipo != TipoElemento.fusivel || e.queimado) continue;
        final medida = parcial.medidas[e.id];
        if (medida != null && medida.corrente.abs() > e.valor + 1e-9) {
          estourados.add(e.id);
        }
      }
      // Relé térmico: desarma acima do ajuste e fica desarmado até o rearme.
      final disparados = <String>{};
      for (final e in atual.elementos) {
        if (e.tipo != TipoElemento.releTermico || e.desarmado) continue;
        final medida = parcial.medidas[e.id];
        if (medida != null && medida.corrente.abs() > e.valor + 1e-9) {
          disparados.add(e.id);
        }
      }
      if (estourados.isEmpty && disparados.isEmpty) {
        if (queimados.isEmpty && desarmados.isEmpty) return parcial;
        return ResultadoSimulacao(
          calculado: true,
          tensoes: parcial.tensoes,
          medidas: parcial.medidas,
          avisos: parcial.avisos,
          fusiveisQueimados: queimados,
          potenciaTotal: parcial.potenciaTotal,
          bobinasLigadas: ligadas,
          relesDesarmados: desarmados,
          temporizadoresAtivos: parcial.temporizadoresAtivos,
        );
      }
      if (estourados.isNotEmpty) {
        queimados.addAll(estourados);
        atual = atual.marcarQueimados(estourados);
      }
      if (disparados.isNotEmpty) {
        desarmados.addAll(disparados);
        atual = atual.desarmar(disparados);
      }
    }
    return ultimo;
  }

  /// Resolve o comando por iteração: resolve o circuito, vê quais bobinas puxam
  /// (70% da nominal) ou soltam (abaixo de 50%) e quais temporizadores estão
  /// energizados, reajusta os contatos auxiliares e resolve de novo até o
  /// estado não mudar mais.
  ResultadoSimulacao _comandar(Set<String> anteriores, Map<String, double> tempos,
      Map<String, double> temposQueda, Map<String, double> temposContato,
      Map<String, double> temposQuedaContato) {
    final bobinas =
        elementos.where((e) => e.tipo == TipoElemento.bobina).toList();
    final temporizadores =
        elementos.where((e) => e.tipo == TipoElemento.temporizador).toList();
    var ligadas = <String>{
      for (final id in anteriores)
        if (porId(id)?.tipo == TipoElemento.bobina) id,
    };
    var ativos = <String>{};
    if (bobinas.isEmpty && temporizadores.isEmpty) {
      return _solucionar(
          bobinasLigadas: ligadas,
          temporizadoresAtivos: ativos,
          tempos: tempos,
          temposQueda: temposQueda,
          temposContato: temposContato,
          temposQuedaContato: temposQuedaContato);
    }

    ResultadoSimulacao? ultimo;
    for (var iteracao = 0; iteracao < 12; iteracao++) {
      ultimo = _solucionar(
          bobinasLigadas: ligadas,
          temporizadoresAtivos: ativos,
          tempos: tempos,
          temposQueda: temposQueda,
          temposContato: temposContato,
          temposQuedaContato: temposQuedaContato);
      if (!ultimo.calculado) return ultimo;
      final novasBobinas = <String>{};
      for (final bobina in bobinas) {
        final medida = ultimo.medidas[bobina.id];
        if (medida == null) continue;
        final nominal = bobina.tensaoNominal <= 0 ? 24.0 : bobina.tensaoNominal;
        final tensao = medida.tensao.abs();
        final jaLigada = ligadas.contains(bobina.id);
        if (jaLigada ? tensao >= nominal * 0.5 : tensao >= nominal * 0.7) {
          novasBobinas.add(bobina.id);
        }
      }
      final novosAtivos = <String>{};
      for (final timer in temporizadores) {
        final medida = ultimo.medidas[timer.id];
        if (medida == null) continue;
        final nominal = timer.tensaoNominal <= 0 ? 24.0 : timer.tensaoNominal;
        if (medida.tensao.abs() >= nominal * 0.7) novosAtivos.add(timer.id);
      }
      final parou = novasBobinas.length == ligadas.length &&
          novasBobinas.containsAll(ligadas) &&
          novosAtivos.length == ativos.length &&
          novosAtivos.containsAll(ativos);
      ligadas = novasBobinas;
      ativos = novosAtivos;
      if (parou) {
        return ResultadoSimulacao(
          calculado: true,
          tensoes: ultimo.tensoes,
          medidas: ultimo.medidas,
          avisos: ultimo.avisos,
          potenciaTotal: ultimo.potenciaTotal,
          bobinasLigadas: ligadas,
          temporizadoresAtivos: ativos,
        );
      }
    }

    return ResultadoSimulacao(
      calculado: true,
      tensoes: ultimo!.tensoes,
      medidas: ultimo.medidas,
      avisos: [
        const AvisoCircuito(
          'O comando do contator não se estabiliza: o contato de selo e a '
          'bobina ficam se mantendo em ciclo. Confira a ligação do selo e da '
          'botoeira de parada.',
          GravidadeAviso.erro,
        ),
        ...ultimo.avisos,
      ],
      potenciaTotal: ultimo.potenciaTotal,
      bobinasLigadas: ligadas,
      temporizadoresAtivos: ativos,
    );
  }

  ResultadoSimulacao _solucionar({
    required Set<String> bobinasLigadas,
    required Set<String> temporizadoresAtivos,
    required Map<String, double> tempos,
    Map<String, double> temposQueda = const {},
    Map<String, double> temposContato = const {},
    Map<String, double> temposQuedaContato = const {},
  }) {
    final nomes = rotulos();
    final relesDesarmados = <String>{
      for (final e in elementos)
        if (e.tipo == TipoElemento.releTermico && e.desarmado) e.id,
    };
    // Temporizador acionado: completou o atraso contando energizado e, depois
    // de perder energia, continua acionado até o retardo na queda vencer.
    final temporizadoresAcionados = <String>{};
    for (final e in elementos) {
      if (e.tipo != TipoElemento.temporizador) continue;
      final subiu = (tempos[e.id] ?? 0) + 1e-9 >= e.atraso;
      if (!subiu) continue;
      if (temporizadoresAtivos.contains(e.id)) {
        temporizadoresAcionados.add(e.id);
      } else if ((temposQueda[e.id] ?? 0) + 1e-9 < e.atrasoQueda) {
        temporizadoresAcionados.add(e.id);
      }
    }
    // Cada contato 67/68 pode ter o próprio atraso: ele compara o relógio do
    // temporizador com o tempo dele (0 s = usa o atraso base do temporizador).
    final contatosTemporizados = <String>{};
    for (final e in elementos) {
      if (e.tipo != TipoElemento.contatoTemporizado &&
          e.tipo != TipoElemento.contatoTemporizadoNf) {
        continue;
      }
      final dono = e.contatoDe == null ? null : porId(e.contatoDe!);
      if (dono == null || dono.tipo != TipoElemento.temporizador) continue;
      final atraso = atrasoDoContato(e);
      // Cada contato conta o próprio relógio: o do contato quando informado,
      // senão o do temporizador (compatibilidade com os circuitos antigos).
      final relogio = relogioDoContato(e, temposContato, tempos);
      if (relogio + 1e-9 < atraso) continue;
      final queda = atrasoQuedaDoContato(e);
      final relogioQueda =
          relogioQuedaDoContato(e, temposQuedaContato, temposQueda);
      if (temporizadoresAtivos.contains(dono.id) ||
          relogioQueda + 1e-9 < queda) {
        contatosTemporizados.add(e.id);
      }
    }
    bool ativa(Elemento e) => e.ativaEm(bobinasLigadas,
        relesDesarmados: relesDesarmados,
        contatosTemporizados: contatosTemporizados);
    final fontes = elementos.where((e) => e.tipo == TipoElemento.fonte).toList();
    final passivos = elementos
        .where((e) => e.tipo != TipoElemento.fonte && ativa(e))
        .toList();
    final abertos = elementos
        .where((e) => e.tipo != TipoElemento.fonte && !ativa(e))
        .toList();

    if (fontes.isEmpty) {
      return const ResultadoSimulacao.falha(
          'Falta uma fonte: sem ela não existe tensão para calcular.');
    }
    if (passivos.isEmpty) {
      return const ResultadoSimulacao.falha(
          'Falta um caminho fechado com carga entre os polos da fonte.');
    }

    final terra = fontes.first.b;
    final visinhos = <int, Set<int>>{};
    void ligar(int a, int b) {
      visinhos.putIfAbsent(a, () => <int>{}).add(b);
      visinhos.putIfAbsent(b, () => <int>{}).add(a);
    }

    for (final e in [...fontes, ...passivos]) {
      ligar(e.a, e.b);
    }

    final alcancaveis = <int>{terra};
    final fila = <int>[terra];
    while (fila.isNotEmpty) {
      final n = fila.removeLast();
      for (final v in visinhos[n] ?? const <int>{}) {
        if (alcancaveis.add(v)) fila.add(v);
      }
    }

    final avisos = <AvisoCircuito>[];
    for (final e in passivos) {
      if (!alcancaveis.contains(e.a) || !alcancaveis.contains(e.b)) {
        avisos.add(AvisoCircuito(
          '${nomes[e.id]} está fora da malha da fonte: nenhum caminho de '
          'ida e volta chega até ele. Ligue com fios até os dois polos.',
          GravidadeAviso.atencao,
        ));
      }
    }

    final nos = <int>{terra};
    for (final e in passivos) {
      if (alcancaveis.contains(e.a)) nos.add(e.a);
      if (alcancaveis.contains(e.b)) nos.add(e.b);
    }
    for (final f in fontes) {
      if (alcancaveis.contains(f.a)) nos.add(f.a);
      if (alcancaveis.contains(f.b)) nos.add(f.b);
    }

    final listaNos = nos.toList()..sort();
    final posicao = <int, int>{};
    var contador = 0;
    for (final n in listaNos) {
      if (n == terra) continue;
      posicao[n] = contador++;
    }
    final quantidadeNos = contador;
    final tamanho = quantidadeNos + fontes.length;
    final matriz =
        List.generate(tamanho, (_) => List<double>.filled(tamanho, 0.0));
    final vetor = List<double>.filled(tamanho, 0.0);

    for (final e in passivos) {
      final g = 1.0 / e.resistencia;
      final pa = posicao[e.a];
      final pb = posicao[e.b];
      if (pa != null) matriz[pa][pa] += g;
      if (pb != null) matriz[pb][pb] += g;
      if (pa != null && pb != null) {
        matriz[pa][pb] -= g;
        matriz[pb][pa] -= g;
      }
    }

    for (var k = 0; k < fontes.length; k++) {
      final fonte = fontes[k];
      final pa = posicao[fonte.a];
      final pb = posicao[fonte.b];
      final linha = quantidadeNos + k;
      if (pa != null) {
        matriz[pa][linha] += 1;
        matriz[linha][pa] += 1;
      }
      if (pb != null) {
        matriz[pb][linha] -= 1;
        matriz[linha][pb] -= 1;
      }
      vetor[linha] = fonte.valor;
    }

    final solucao = _resolver(matriz, vetor);
    if (solucao == null) {
      return const ResultadoSimulacao.falha(
          'O sistema não tem solução única. Causas comuns: duas fontes em '
          'paralelo com tensões diferentes, ou um nó sem nenhum caminho para o '
          'retorno da fonte.');
    }

    final tensoes = <int, double>{terra: 0};
    for (final entrada in posicao.entries) {
      tensoes[entrada.key] = solucao[entrada.value];
    }

    final medidas = <String, Medida>{};
    var potenciaTotal = 0.0;
    for (final e in passivos) {
      final va = tensoes[e.a];
      final vb = tensoes[e.b];
      if (va == null || vb == null) {
        medidas[e.id] = Medida(id: e.id, tensao: 0, corrente: 0, potencia: 0);
        continue;
      }
      final tensao = va - vb;
      final corrente = tensao / e.resistencia;
      final potencia = tensao * corrente;
      potenciaTotal += potencia;
      medidas[e.id] = Medida(
        id: e.id,
        tensao: tensao,
        corrente: corrente,
        potencia: potencia,
      );
    }

    var correnteFontes = 0.0;
    for (var k = 0; k < fontes.length; k++) {
      final fornecida = -solucao[quantidadeNos + k];
      correnteFontes += fornecida;
      medidas[fontes[k].id] = Medida(
        id: fontes[k].id,
        tensao: fontes[k].valor,
        corrente: fornecida,
        potencia: fontes[k].valor * fornecida,
      );
    }

    const limiteCurto = 25.0;
    if (medidas.entries.any((m) => m.value.corrente.abs() > limiteCurto)) {
      avisos.insert(
        0,
        AvisoCircuito(
          'Curto-circuito: ${_amperes(correnteFontes.abs())} passam direto '
          'entre os polos, sem carga no caminho. Corrija o fio que liga os '
          'polos ou coloque uma lâmpada/resistor em série.',
          GravidadeAviso.erro,
        ),
      );
    }

    if (correnteFontes.abs() < 1e-9) {
      final motivo = abertos.isEmpty
          ? 'O caminho não fecha.'
          : 'Um contato aberto interrompe o caminho: interruptor, botoeira '
              'solta, contato de selo sem bobina ligada ou fusível queimado.';
      avisos.add(AvisoCircuito(
          'Circuito aberto: não passa corrente. $motivo', GravidadeAviso.info));
    }

    for (final e in passivos) {
      final m = medidas[e.id];
      if (m == null) continue;
      if (e.tipo == TipoElemento.lampada) {
        final tensao = m.tensao.abs();
        final nominal = e.tensaoNominal <= 0 ? 12.0 : e.tensaoNominal;
        if (tensao > nominal * 1.1) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} recebe ${_volts(tensao)} e a nominal é '
            '${_volts(nominal)}: a lâmpada vai queimar. Reduza a tensão da '
            'fonte ou use duas em série.',
            GravidadeAviso.erro,
          ));
        } else if (tensao > 0.05 && tensao < nominal * 0.6) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} recebe só ${_volts(tensao)} de '
            '${_volts(nominal)}: acende fraca.',
            GravidadeAviso.info,
          ));
        }
      }
      if (e.tipo == TipoElemento.resistor && m.potencia.abs() > 0.5) {
        avisos.add(AvisoCircuito(
          '${nomes[e.id]} dissipa ${_watts(m.potencia.abs())}: acima de '
          'resistores comuns de 1/4 W. Use um de maior potência.',
          GravidadeAviso.atencao,
        ));
      }
      if (e.tipo == TipoElemento.fusivel && !e.queimado) {
        final corrente = m.corrente.abs();
        if (corrente > e.valor * 0.9 && corrente <= e.valor) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} está no limite: passam ${_amperes(corrente)} do '
            'limite de ${_amperes(e.valor)}.',
            GravidadeAviso.atencao,
          ));
        }
      }
    }

    for (final e in elementos) {
      if (e.tipo == TipoElemento.bobina) {
        final tensao = (medidas[e.id]?.tensao ?? 0).abs();
        final nominal = e.tensaoNominal <= 0 ? 24.0 : e.tensaoNominal;
        if (bobinasLigadas.contains(e.id)) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} está ligada com ${_volts(tensao)} (nominal '
            '${_volts(nominal)}) e mantém fechados os contatos de selo dela.',
            GravidadeAviso.info,
          ));
        } else if (tensao >= nominal * 0.5) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} recebe só ${_volts(tensao)} dos ${_volts(nominal)}: '
            'abaixo de 70% a bobina não puxa. Confira a queda de tensão no '
            'comando.',
            GravidadeAviso.atencao,
          ));
        }
      }
      if (e.tipo == TipoElemento.motor) {
        final tensao = (medidas[e.id]?.tensao ?? 0).abs();
        final nominal = e.tensaoNominal <= 0 ? 12.0 : e.tensaoNominal;
        if (tensao > nominal * 1.1) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} recebe ${_volts(tensao)} e a nominal é '
            '${_volts(nominal)}: acima disso o motor real sobreaquece. Reduza '
            'a tensão da fonte.',
            GravidadeAviso.erro,
          ));
        } else if (tensao > 0.05 && tensao < nominal * 0.9) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} recebe só ${_volts(tensao)} dos ${_volts(nominal)}: '
            'no modelo a potência cai; num motor real a rotação também cai.',
            GravidadeAviso.atencao,
          ));
        }
      }
      if (e.tipo == TipoElemento.releTermico) {
        final corrente = (medidas[e.id]?.corrente ?? 0).abs();
        if (e.desarmado) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} desarmou: o motor e o comando ficaram sem '
            'corrente. Corrija a causa e use Rearmar.',
            GravidadeAviso.erro,
          ));
        } else if (corrente > e.valor * 0.9 && corrente <= e.valor) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} está no limite: passam ${_amperes(corrente)} do '
            'ajuste de ${_amperes(e.valor)}.',
            GravidadeAviso.atencao,
          ));
        }
      }
      if (e.tipo == TipoElemento.contatoRele &&
          (e.contatoDe == null ||
              porId(e.contatoDe!)?.tipo != TipoElemento.releTermico)) {
        avisos.add(AvisoCircuito(
          '${nomes[e.id]} não tem relé térmico: escolha o relé que comanda '
          'este contato 95/96.',
          GravidadeAviso.atencao,
        ));
      }
      if (e.tipo == TipoElemento.temporizador) {
        final tensao = (medidas[e.id]?.tensao ?? 0).abs();
        final nominal = e.tensaoNominal <= 0 ? 24.0 : e.tensaoNominal;
        if (temporizadoresAtivos.contains(e.id)) {
          final tempo = tempos[e.id] ?? 0;
          final fechado = tempo + 1e-9 >= e.atraso;
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} está energizado com ${_volts(tensao)} e conta '
            '${tempo.toStringAsFixed(0)} s (ajuste base de '
            '${e.atraso.toStringAsFixed(0)} s): '
            '${fechado ? 'o atraso base já completou; ' : ''}'
            'cada contato 67/68 usa o próprio atraso quando ajustado.',
            GravidadeAviso.info,
          ));
        } else if (tensao >= nominal * 0.5) {
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} recebe só ${_volts(tensao)} dos ${_volts(nominal)}: '
            'abaixo de 70% o temporizador não conta tempo.',
            GravidadeAviso.atencao,
          ));
        } else if (temporizadoresAcionados.contains(e.id)) {
          final queda = temposQueda[e.id] ?? 0;
          avisos.add(AvisoCircuito(
            '${nomes[e.id]} está sem energia e ainda há contato segurando: '
            '${queda.toStringAsFixed(0)} s de '
            '${e.atrasoQueda.toStringAsFixed(0)} s do retardo base na queda '
            '(cada contato usa o próprio quando ajustado).',
            GravidadeAviso.info,
          ));
        }
      }
      if ((e.tipo == TipoElemento.contatoTemporizado ||
              e.tipo == TipoElemento.contatoTemporizadoNf) &&
          (e.contatoDe == null ||
              porId(e.contatoDe!)?.tipo != TipoElemento.temporizador)) {
        avisos.add(AvisoCircuito(
          '${nomes[e.id]} não tem temporizador: escolha o temporizador que '
          'comanda este contato 67/68.',
          GravidadeAviso.atencao,
        ));
      }
      if ((e.tipo == TipoElemento.contatoSelo ||
              e.tipo == TipoElemento.contatoNf ||
              e.tipo == TipoElemento.contatoPotencia) &&
          (e.contatoDe == null || porId(e.contatoDe!) == null)) {
        avisos.add(AvisoCircuito(
          '${nomes[e.id]} não tem bobina: escolha a bobina que comanda este '
          'contato auxiliar.',
          GravidadeAviso.atencao,
        ));
      }
    }

    for (final e in abertos) {
      final texto = switch (e.tipo) {
        TipoElemento.fusivel => '${nomes[e.id]} queimou e agora está aberto: o '
            'caminho ficou interrompido. Troque o fusível depois de corrigir a '
            'causa.',
        TipoElemento.botoeira => e.normalmenteFechado
            ? '${nomes[e.id]} está apertada (NF): o comando está desligado '
                'enquanto ela estiver pressionada.'
            : '${nomes[e.id]} está solta (NA): aperte a botoeira para fechar o '
                'comando.',
        TipoElemento.contatoSelo => '${nomes[e.id]} está aberto porque a bobina '
            'dele está desligada.',
        TipoElemento.contatoNf => '${nomes[e.id]} está aberto porque a bobina '
            'dele está ligada: é o intertravamento agindo.',
        TipoElemento.contatoPotencia =>
          '${nomes[e.id]} está aberto porque o contator não puxou: o motor '
              'fica desligado.',
        TipoElemento.contatoRele =>
          '${nomes[e.id]} está aberto porque o relé térmico desarmou: o comando '
              'não fecha enquanto o relé não for rearmado.',
        TipoElemento.contatoTemporizado =>
          '${nomes[e.id]} está aberto: o temporizador está sem energia ou '
              'ainda não completou o atraso de '
              '${atrasoDoContato(e).toStringAsFixed(0)} s deste contato.',
        TipoElemento.contatoTemporizadoNf =>
          '${nomes[e.id]} está aberto porque o atraso de '
              '${atrasoDoContato(e).toStringAsFixed(0)} s deste contato se '
              'completou: sendo NF, ele abre quando o temporizador termina de '
              'contar.',
        _ => '${nomes[e.id]} está aberto: nada passa por ele.',
      };
      avisos.add(AvisoCircuito(
        texto,
        e.tipo == TipoElemento.fusivel
            ? GravidadeAviso.atencao
            : GravidadeAviso.info,
      ));
    }

    return ResultadoSimulacao(
      calculado: true,
      tensoes: tensoes,
      medidas: medidas,
      avisos: avisos,
      potenciaTotal: potenciaTotal,
      bobinasLigadas: bobinasLigadas,
      temporizadoresAtivos: temporizadoresAtivos,
    );
  }

  static List<double>? _resolver(List<List<double>> matriz, List<double> vetor) {
    final n = vetor.length;
    final a = [
      for (final linha in matriz) List<double>.of(linha),
    ];
    final b = List<double>.of(vetor);

    for (var coluna = 0; coluna < n; coluna++) {
      var pivo = coluna;
      var maior = a[coluna][coluna].abs();
      for (var linha = coluna + 1; linha < n; linha++) {
        final valor = a[linha][coluna].abs();
        if (valor > maior) {
          maior = valor;
          pivo = linha;
        }
      }
      if (maior < 1e-12) return null;
      if (pivo != coluna) {
        final troca = a[pivo];
        a[pivo] = a[coluna];
        a[coluna] = troca;
        final tb = b[pivo];
        b[pivo] = b[coluna];
        b[coluna] = tb;
      }
      final diagonal = a[coluna][coluna];
      for (var linha = coluna + 1; linha < n; linha++) {
        final fator = a[linha][coluna] / diagonal;
        if (fator == 0) continue;
        for (var c = coluna; c < n; c++) {
          a[linha][c] -= fator * a[coluna][c];
        }
        b[linha] -= fator * b[coluna];
      }
    }

    final x = List<double>.filled(n, 0);
    for (var linha = n - 1; linha >= 0; linha--) {
      var soma = b[linha];
      for (var c = linha + 1; c < n; c++) {
        soma -= a[linha][c] * x[c];
      }
      x[linha] = soma / a[linha][linha];
      if (x[linha].isNaN || x[linha].isInfinite) return null;
    }
    return x;
  }
}

/// Formata números em português, com vírgula decimal e sem zeros inúteis.
String formatarNumero(double valor, {int casas = 2}) {
  if (valor.abs() >= 1000) {
    return valor.toStringAsFixed(0).replaceAll('.', ',');
  }
  var texto = valor.toStringAsFixed(casas);
  if (texto.contains('.')) {
    texto = texto.replaceAll(RegExp(r'0+$'), '');
    texto = texto.replaceAll(RegExp(r'\.$'), '');
  }
  if (texto == '-0') texto = '0';
  return texto.replaceAll('.', ',');
}

String _volts(double v) => '${formatarNumero(v)} V';
String _amperes(double i) => '${formatarNumero(i, casas: 3)} A';
String _watts(double p) => '${formatarNumero(p)} W';

class ExemploCircuito {
  const ExemploCircuito(this.nome, this.descricao, this.montar);
  final String nome;
  final String descricao;
  final Circuito Function() montar;
}

Elemento _fio(int a, int b) =>
    Elemento(id: chaveTrecho(a, b), tipo: TipoElemento.fio, a: a, b: b);

Elemento _fonte(int a, int b, double volts) => Elemento(
    id: chaveTrecho(a, b), tipo: TipoElemento.fonte, a: a, b: b, valor: volts);

Elemento _lampada(int a, int b, double watts, double volts) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.lampada,
        a: a,
        b: b,
        valor: watts,
        tensaoNominal: volts);

Elemento _interruptor(int a, int b, {bool fechado = true}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.interruptor,
        a: a,
        b: b,
        fechado: fechado);

Elemento _fusivel(int a, int b, double amperes) => Elemento(
    id: chaveTrecho(a, b), tipo: TipoElemento.fusivel, a: a, b: b, valor: amperes);

Elemento _resistor(int a, int b, double ohms) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.resistor,
    a: a,
    b: b,
    valor: ohms);

Elemento _botoeira(int a, int b, {bool normalmenteFechado = false}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.botoeira,
        a: a,
        b: b,
        normalmenteFechado: normalmenteFechado);

Elemento _sensor(int a, int b,
        {bool normalmenteFechado = true, bool acionado = false}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.botoeira,
        a: a,
        b: b,
        sensor: true,
        normalmenteFechado: normalmenteFechado,
        pressionada: acionado);

Elemento _bobina(int a, int b, double ohms, double nominal) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.bobina,
    a: a,
    b: b,
    valor: ohms,
    tensaoNominal: nominal);

Elemento _contatoSelo(int a, int b, {required String contatoDe}) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.contatoSelo,
    a: a,
    b: b,
    contatoDe: contatoDe);

Elemento _contatoNf(int a, int b, {required String contatoDe}) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.contatoNf,
    a: a,
    b: b,
    contatoDe: contatoDe);

Elemento _contatoPotencia(int a, int b, {required String contatoDe}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.contatoPotencia,
        a: a,
        b: b,
        contatoDe: contatoDe);

Elemento _motor(int a, int b, double watts, double volts) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.motor,
    a: a,
    b: b,
    valor: watts,
    tensaoNominal: volts);

Elemento _releTermico(int a, int b, double amperes) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.releTermico,
    a: a,
    b: b,
    valor: amperes);

Elemento _contatoRele(int a, int b, {required String contatoDe}) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.contatoRele,
    a: a,
    b: b,
    contatoDe: contatoDe);

Elemento _temporizador(int a, int b, double segundos,
        {double ohms = 240, double nominal = 24, double queda = 0}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.temporizador,
        a: a,
        b: b,
        valor: ohms,
        tensaoNominal: nominal,
        atraso: segundos,
        atrasoQueda: queda);

Elemento _contatoTemporizado(int a, int b,
        {required String contatoDe, double atraso = 0, double queda = 0}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.contatoTemporizado,
        atraso: atraso,
        atrasoQueda: queda,
        a: a,
        b: b,
        contatoDe: contatoDe);

Elemento _contatoTemporizadoNf(int a, int b,
        {required String contatoDe, double atraso = 0, double queda = 0}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.contatoTemporizadoNf,
        atraso: atraso,
        atrasoQueda: queda,
        a: a,
        b: b,
        contatoDe: contatoDe);

List<ExemploCircuito> get exemplosCircuito => [
      ExemploCircuito(
        'Lâmpada e interruptor',
        'Fonte de 12 V, interruptor fechado e lâmpada de 12 V / 5 W.',
        () {
          final c = Circuito();
          final n = c.no;
          return Circuito(elementos: [
            _fonte(n(0, 1), n(0, 2), 12),
            _fio(n(0, 1), n(1, 1)),
            _fio(n(1, 1), n(2, 1)),
            _fio(n(2, 1), n(2, 0)),
            _interruptor(n(2, 0), n(3, 0)),
            _fio(n(3, 0), n(4, 0)),
            _lampada(n(4, 0), n(4, 1), 5, 12),
            _fio(n(4, 1), n(4, 2)),
            _fio(n(4, 2), n(3, 2)),
            _fio(n(3, 2), n(2, 2)),
            _fio(n(2, 2), n(1, 2)),
            _fio(n(1, 2), n(0, 2)),
          ]);
        },
      ),
      ExemploCircuito(
        'Duas lâmpadas em série',
        'As duas dividem os 12 V: cada uma recebe 6 V e acende fraca.',
        () {
          final c = Circuito();
          final n = c.no;
          return Circuito(elementos: [
            _fonte(n(0, 1), n(0, 2), 12),
            _fio(n(0, 1), n(1, 1)),
            _fio(n(1, 1), n(2, 1)),
            _fio(n(2, 1), n(2, 0)),
            _lampada(n(2, 0), n(3, 0), 5, 12),
            _fio(n(3, 0), n(4, 0)),
            _lampada(n(4, 0), n(4, 1), 5, 12),
            _fio(n(4, 1), n(4, 2)),
            _fio(n(4, 2), n(3, 2)),
            _fio(n(3, 2), n(2, 2)),
            _fio(n(2, 2), n(1, 2)),
            _fio(n(1, 2), n(0, 2)),
          ]);
        },
      ),
      ExemploCircuito(
        'Duas lâmpadas em paralelo',
        'Cada lâmpada recebe os 12 V inteiros e acende com a potência nominal.',
        () {
          final c = Circuito();
          final n = c.no;
          return Circuito(elementos: [
            _fonte(n(0, 1), n(0, 2), 12),
            _fio(n(0, 0), n(0, 1)),
            _fio(n(0, 0), n(1, 0)),
            _lampada(n(1, 0), n(2, 0), 5, 12),
            _fio(n(2, 0), n(3, 0)),
            _fio(n(3, 0), n(4, 0)),
            _fio(n(0, 1), n(1, 1)),
            _lampada(n(1, 1), n(2, 1), 5, 12),
            _fio(n(2, 1), n(3, 1)),
            _fio(n(3, 1), n(4, 1)),
            _fio(n(4, 0), n(4, 1)),
            _fio(n(4, 1), n(4, 2)),
            _fio(n(4, 2), n(3, 2)),
            _fio(n(3, 2), n(2, 2)),
            _fio(n(2, 2), n(1, 2)),
            _fio(n(1, 2), n(0, 2)),
          ]);
        },
      ),
      ExemploCircuito(
        'Divisor de tensão',
        'R1 de 1 kΩ e R2 de 2 kΩ: o meio entrega 8 V dos 12 V da fonte.',
        () {
          final c = Circuito();
          final n = c.no;
          return Circuito(elementos: [
            _fonte(n(0, 1), n(0, 2), 12),
            _fio(n(0, 1), n(1, 1)),
            _resistor(n(1, 1), n(2, 1), 1000),
            _resistor(n(2, 1), n(2, 2), 2000),
            _fio(n(2, 2), n(1, 2)),
            _fio(n(1, 2), n(0, 2)),
          ]);
        },
      ),
      ExemploCircuito(
        'Partida direta com selo',
        'Comando em 24 V: botoeira de parada (NF), botoeira de partida (NA), '
            'bobina K1 de 240 Ω e o contato de selo de K1 em paralelo com a '
            'partida. Aperte a partida: o selo mantém o contator ligado mesmo '
            'depois de soltar.',
        () {
          final c = Circuito();
          final n = c.no;
          final bobina = chaveTrecho(n(3, 2), n(3, 3));
          return Circuito(elementos: [
            _fonte(n(0, 0), n(0, 1), 24),
            _fio(n(0, 0), n(1, 0)),
            _fio(n(1, 0), n(2, 0)),
            // Botoeira de parada: NF, fecha em repouso.
            _botoeira(n(2, 0), n(3, 0), normalmenteFechado: true),
            // Ramo 1: botoeira de partida (NA) e o fio que desce até o retorno.
            _botoeira(n(3, 0), n(3, 1)),
            _fio(n(3, 1), n(3, 2)),
            // Ramo 2: contato de selo de K1, em paralelo com a partida.
            _fio(n(3, 0), n(4, 0)),
            _contatoSelo(n(4, 0), n(4, 1), contatoDe: bobina),
            _fio(n(4, 1), n(4, 2)),
            _fio(n(4, 2), n(3, 2)),
            // Bobina do contator: 240 Ω em 24 V dá 100 mA.
            _bobina(n(3, 2), n(3, 3), 240, 24),
            _fio(n(3, 3), n(2, 3)),
            _fio(n(2, 3), n(1, 3)),
            _fio(n(1, 3), n(0, 3)),
            _fio(n(0, 3), n(0, 2)),
            _fio(n(0, 2), n(0, 1)),
          ]);
        },
      ),
      ExemploCircuito(
        'Reversão com intertravamento',
        'Dois contatores em 24 V: cada bobina tem o próprio selo e passa pelo '
            'contato NF (21-22) do outro. Com K1 ligado, apertar a partida de '
            'K2 não faz nada. Aperte a parada para poder trocar o sentido.',
        () {
          const colunas = 8;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(3, 1), no(3, 2));
          final k2 = chaveTrecho(no(6, 1), no(6, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            // Fonte e botoeira de parada comum aos dois sentidos.
            _fonte(no(0, 0), no(0, 1), 24),
            _botoeira(no(0, 0), no(1, 0), normalmenteFechado: true),
            // Barramento positivo até os dois ramos.
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _fio(no(3, 0), no(4, 0)),
            _fio(no(1, 0), no(1, 1)),
            _fio(no(4, 0), no(4, 1)),
            // Ramo do sentido 1 (K1): partida, selo e intertravamento.
            _botoeira(no(1, 1), no(2, 1)),
            _fio(no(1, 1), no(1, 2)),
            _contatoSelo(no(1, 2), no(2, 2), contatoDe: k1),
            _fio(no(2, 2), no(2, 1)),
            _contatoNf(no(2, 1), no(3, 1), contatoDe: k2),
            _bobina(no(3, 1), no(3, 2), 240, 24),
            _fio(no(3, 2), no(3, 3)),
            _fio(no(3, 3), no(3, 4)),
            // Ramo do sentido 2 (K2): mesma estrutura, travado por K1.
            _botoeira(no(4, 1), no(5, 1)),
            _fio(no(4, 1), no(4, 2)),
            _contatoSelo(no(4, 2), no(5, 2), contatoDe: k2),
            _fio(no(5, 2), no(5, 1)),
            _contatoNf(no(5, 1), no(6, 1), contatoDe: k1),
            _bobina(no(6, 1), no(6, 2), 240, 24),
            _fio(no(6, 2), no(6, 3)),
            _fio(no(6, 3), no(6, 4)),
            // Retorno: barra de baixo e coluna da esquerda até o polo negativo.
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(5, 4), no(6, 4)),
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Partida direta de motor DC',
        'Comando e potência no mesmo esquema, em 24 V: a partida puxa K1, o selo '
            'mantém e o contato principal K1-1/2 liga o motor de 24 V / 24 W, '
            'que fica com 1 A. A bobina consome 100 mA.',
        () {
          const colunas = 6;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(3, 1), no(3, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Comando: parada NF, partida NA e selo de K1.
            _botoeira(no(0, 0), no(1, 0), normalmenteFechado: true),
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1)),
            _fio(no(1, 1), no(1, 2)),
            _contatoSelo(no(1, 2), no(2, 2), contatoDe: k1),
            _fio(no(2, 2), no(2, 1)),
            _fio(no(2, 1), no(3, 1)),
            _bobina(no(3, 1), no(3, 2), 240, 24),
            _fio(no(3, 2), no(3, 3)),
            _fio(no(3, 3), no(3, 4)),
            // Potência: contato principal em série com o motor.
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _contatoPotencia(no(3, 0), no(4, 0), contatoDe: k1),
            _fio(no(4, 0), no(5, 0)),
            _motor(no(5, 0), no(5, 1), 24, 24),
            _fio(no(5, 1), no(5, 2)),
            _fio(no(5, 2), no(5, 3)),
            _fio(no(5, 3), no(5, 4)),
            // Retorno até o polo negativo da fonte.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Sequência com temporizador',
        'Partida em 24 V com temporizador KT1 de 3 s: K1 puxa na hora e a '
            'lâmpada L1 acende só quando o contato 67/68 fecha. Use Avançar 1 s '
            'para correr o relógio do temporizador.',
        () {
          const colunas = 6;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(3, 1), no(3, 2));
          final kt1 = chaveTrecho(no(4, 1), no(4, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Comando: parada NF, partida NA e selo de K1.
            _botoeira(no(0, 0), no(1, 0), normalmenteFechado: true),
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1)),
            _fio(no(1, 1), no(1, 2)),
            _contatoSelo(no(1, 2), no(2, 2), contatoDe: k1),
            _fio(no(2, 2), no(2, 1)),
            _fio(no(2, 1), no(3, 1)),
            _bobina(no(3, 1), no(3, 2), 240, 24),
            _fio(no(3, 2), no(3, 3)),
            _fio(no(3, 3), no(3, 4)),
            // Temporizador em paralelo com a bobina do contator.
            _fio(no(3, 1), no(4, 1)),
            _temporizador(no(4, 1), no(4, 2), 3),
            _fio(no(4, 2), no(4, 3)),
            _fio(no(4, 3), no(4, 4)),
            // Depois do atraso, o 67/68 acende a lâmpada de 24 V / 5 W.
            _fio(no(4, 0), no(5, 0)),
            _fio(no(5, 0), no(5, 1)),
            _contatoTemporizado(no(5, 1), no(5, 2), contatoDe: kt1),
            _lampada(no(5, 2), no(5, 3), 5, 24),
            _fio(no(5, 3), no(5, 4)),
            // Barramentos.
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _fio(no(3, 0), no(4, 0)),
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Desligamento em sequência',
        'Partida em 24 V que se desliga sozinha: a partida puxa K1 e o selo '
            'mantém; o KT1 conta 3 s e então o contato 67/68 NF, que fica em '
            'série com a bobina, abre e derruba K1 — o motor de 24 V / 24 W '
            'para sem ninguém apertar a parada. Use Avançar 1 s até o fim do '
            'atraso.',
        () {
          const colunas = 6;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(3, 1), no(3, 2));
          final kt1 = chaveTrecho(no(4, 1), no(4, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Comando: parada NF, partida NA e selo de K1.
            _botoeira(no(0, 0), no(1, 0), normalmenteFechado: true),
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1)),
            _fio(no(1, 1), no(1, 2)),
            _contatoSelo(no(1, 2), no(2, 2), contatoDe: k1),
            _fio(no(2, 2), no(2, 1)),
            // O NF do temporizador fica em série com a bobina: ao completar o
            // atraso ele abre e derruba o contator.
            _contatoTemporizadoNf(no(2, 1), no(3, 1), contatoDe: kt1),
            _bobina(no(3, 1), no(3, 2), 240, 24),
            _fio(no(3, 2), no(3, 3)),
            _fio(no(3, 3), no(3, 4)),
            // Temporizador em paralelo com a bobina do contator.
            _fio(no(3, 1), no(4, 1)),
            _temporizador(no(4, 1), no(4, 2), 3),
            _fio(no(4, 2), no(4, 3)),
            _fio(no(4, 3), no(4, 4)),
            // Potência: contato principal em série com o motor.
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _contatoPotencia(no(3, 0), no(4, 0), contatoDe: k1),
            _fio(no(4, 0), no(5, 0)),
            _motor(no(5, 0), no(5, 1), 24, 24),
            _fio(no(5, 1), no(5, 2)),
            _fio(no(5, 2), no(5, 3)),
            _fio(no(5, 3), no(5, 4)),
            // Barramentos.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Desligamento temporizado',
        'Partida em 24 V com 3 s de retardo na queda: a partida puxa K1, o '
            'motor de 24 V / 24 W roda e o KT1 conta 3 s. O 67/68 fica em '
            'paralelo com o contato de potência; ao apertar a parada o K1 cai e o '
            'KT1 perde energia, mas o motor continua por mais 3 s, até o contato '
            'abrir. Use Avançar 1 s para correr os dois relógios.',
        () {
          const colunas = 7;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(3, 2), no(4, 2));
          final kt1 = chaveTrecho(no(3, 3), no(4, 3));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            _fio(no(0, 0), no(1, 0)),
            _fio(no(1, 0), no(1, 2)),
            // Comando: partida NA, parada NF e bobina de K1.
            _botoeira(no(1, 2), no(2, 2)),
            _botoeira(no(2, 2), no(3, 2), normalmenteFechado: true),
            _bobina(no(3, 2), no(4, 2), 240, 24),
            // Selo de K1 em paralelo com a partida.
            _fio(no(1, 2), no(1, 3)),
            _contatoSelo(no(1, 3), no(2, 3), contatoDe: k1),
            _fio(no(2, 3), no(2, 2)),
            // Temporizador em paralelo com a bobina: 3 s para acionar e 3 s de
            // retardo na queda.
            _fio(no(3, 2), no(3, 3)),
            _temporizador(no(3, 3), no(4, 3), 3, queda: 3),
            _fio(no(4, 3), no(4, 2)),
            // Potência: contato principal e motor de 24 V / 24 W.
            _contatoPotencia(no(1, 0), no(2, 0), contatoDe: k1),
            _fio(no(2, 0), no(3, 0)),
            _motor(no(3, 0), no(4, 0), 24, 24),
            _fio(no(4, 0), no(5, 0)),
            _fio(no(5, 0), no(5, 1)),
            _fio(no(5, 1), no(5, 2)),
            _fio(no(5, 2), no(5, 3)),
            // O 67/68 em paralelo com o contato de potência: segura o motor
            // durante o retardo na queda.
            _fio(no(1, 0), no(1, 1)),
            _contatoTemporizado(no(1, 1), no(2, 1), contatoDe: kt1),
            _fio(no(2, 1), no(2, 0)),
            // Retorno da bobina e barramento negativo.
            _fio(no(4, 2), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(0, 1), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(5, 3), no(5, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Quedas diferentes no temporizador',
        'Um KT1 com atraso base de 2 s e retardo base de 2 s na queda. Os dois '
            'contatos foram ajustados com o mesmo atraso de 2 s, mas com quedas '
            'diferentes, em 24 V: o 67/68 NA segura a lâmpada L1 por 1 s depois '
            'da parada e o 67/68 NF mantém a lâmpada L2 apagada por 4 s. Aperte '
            'a partida, avance 2 s e aperte a parada: L1 apaga 1 s depois e L2 '
            'só volta 4 s depois.',
        () {
          const colunas = 8;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(4, 1), no(4, 2));
          final kt1 = chaveTrecho(no(5, 1), no(5, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Barramento positivo no topo, da fonte até a coluna do NF.
            _fio(no(0, 0), no(1, 0)),
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _fio(no(3, 0), no(4, 0)),
            _fio(no(4, 0), no(5, 0)),
            _fio(no(5, 0), no(6, 0)),
            _fio(no(6, 0), no(7, 0)),
            // Comando: parada NF, partida NA, selo de K1 e a bobina.
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1), normalmenteFechado: true),
            _botoeira(no(2, 1), no(3, 1)),
            _fio(no(2, 1), no(2, 2)),
            _contatoSelo(no(2, 2), no(3, 2), contatoDe: k1),
            _fio(no(3, 2), no(3, 1)),
            _fio(no(3, 1), no(4, 1)),
            _bobina(no(4, 1), no(4, 2), 240, 24),
            _fio(no(4, 2), no(4, 4)),
            // Temporizador com atraso de 2 s e 2 s de retardo base na queda.
            _fio(no(4, 1), no(5, 1)),
            _temporizador(no(5, 1), no(5, 2), 2, queda: 2),
            _fio(no(5, 2), no(5, 4)),
            // 67/68 NA: atraso de 2 s e só 1 s de queda.
            _fio(no(6, 0), no(6, 1)),
            _contatoTemporizado(no(6, 1), no(6, 2),
                contatoDe: kt1, atraso: 2, queda: 1),
            _lampada(no(6, 2), no(6, 3), 5, 24),
            _fio(no(6, 3), no(6, 4)),
            // 67/68 NF: atraso de 2 s e 4 s de queda.
            _fio(no(7, 0), no(7, 1)),
            _contatoTemporizadoNf(no(7, 1), no(7, 2),
                contatoDe: kt1, atraso: 2, queda: 4),
            _lampada(no(7, 2), no(7, 3), 5, 24),
            _fio(no(7, 3), no(7, 4)),
            // Barramento negativo.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(5, 4), no(6, 4)),
            _fio(no(6, 4), no(7, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Contatos com tempos diferentes',
        'Um KT1 com ajuste base de 3 s e dois contatos com tempo próprio, em '
            '24 V: o 67/68 NA ajustado em 1 s acende a lâmpada L1 logo no '
            'primeiro segundo e o 67/68 NF ajustado em 5 s só apaga a lâmpada '
            'L2 aos 5 s. O ajuste base do KT1 fica valendo só para os contatos '
            'deixados em 0 s.',
        () {
          const colunas = 8;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(4, 1), no(4, 2));
          final kt1 = chaveTrecho(no(5, 1), no(5, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Barramento positivo no topo, da fonte até a coluna do NF.
            _fio(no(0, 0), no(1, 0)),
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _fio(no(3, 0), no(4, 0)),
            _fio(no(4, 0), no(5, 0)),
            _fio(no(5, 0), no(6, 0)),
            _fio(no(6, 0), no(7, 0)),
            // Comando: parada NF, partida NA, selo de K1 e a bobina.
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1), normalmenteFechado: true),
            _botoeira(no(2, 1), no(3, 1)),
            _fio(no(2, 1), no(2, 2)),
            _contatoSelo(no(2, 2), no(3, 2), contatoDe: k1),
            _fio(no(3, 2), no(3, 1)),
            _fio(no(3, 1), no(4, 1)),
            _bobina(no(4, 1), no(4, 2), 240, 24),
            _fio(no(4, 2), no(4, 4)),
            // Temporizador em paralelo com a bobina: ajuste base de 3 s.
            _fio(no(4, 1), no(5, 1)),
            _temporizador(no(5, 1), no(5, 2), 3),
            _fio(no(5, 2), no(5, 4)),
            // 67/68 NA com 1 s: acende L1 no primeiro segundo.
            _fio(no(6, 0), no(6, 1)),
            _contatoTemporizado(no(6, 1), no(6, 2), contatoDe: kt1, atraso: 1),
            _lampada(no(6, 2), no(6, 3), 5, 24),
            _fio(no(6, 3), no(6, 4)),
            // 67/68 NF com 5 s: mantém L2 acesa até os 5 s.
            _fio(no(7, 0), no(7, 1)),
            _contatoTemporizadoNf(no(7, 1), no(7, 2),
                contatoDe: kt1, atraso: 5),
            _lampada(no(7, 2), no(7, 3), 5, 24),
            _fio(no(7, 3), no(7, 4)),
            // Barramento negativo.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(5, 4), no(6, 4)),
            _fio(no(6, 4), no(7, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Relógios independentes no temporizador',
        'Cada contato conta o próprio relógio, em 24 V. O KT1 tem ajuste base '
            'de 12 s, mas ninguém espera por ele: o 67/68 NA tem relógio próprio '
            'de 2 s e o 67/68 NF tem relógio próprio de 7 s. Aperte a partida e '
            'avance 1 s: L1 acende aos 2 s e L2 apaga aos 7 s, cada uma pelo '
            'relógio do seu contato. O relógio do KT1 continua em 0 s porque o '
            'atraso base dele não é usado por nenhum dos dois.',
        () {
          const colunas = 8;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(4, 1), no(4, 2));
          final kt1 = chaveTrecho(no(5, 1), no(5, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Barramento positivo no topo, da fonte até a coluna do NF.
            _fio(no(0, 0), no(1, 0)),
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _fio(no(3, 0), no(4, 0)),
            _fio(no(4, 0), no(5, 0)),
            _fio(no(5, 0), no(6, 0)),
            _fio(no(6, 0), no(7, 0)),
            // Comando: parada NF, partida NA, selo de K1 e a bobina.
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1), normalmenteFechado: true),
            _botoeira(no(2, 1), no(3, 1)),
            _fio(no(2, 1), no(2, 2)),
            _contatoSelo(no(2, 2), no(3, 2), contatoDe: k1),
            _fio(no(3, 2), no(3, 1)),
            _fio(no(3, 1), no(4, 1)),
            _bobina(no(4, 1), no(4, 2), 240, 24),
            _fio(no(4, 2), no(4, 4)),
            // Temporizador em paralelo com a bobina: ajuste base de 12 s.
            _fio(no(4, 1), no(5, 1)),
            _temporizador(no(5, 1), no(5, 2), 12),
            _fio(no(5, 2), no(5, 4)),
            // 67/68 NA com relógio próprio de 2 s.
            _fio(no(6, 0), no(6, 1)),
            _contatoTemporizado(no(6, 1), no(6, 2), contatoDe: kt1, atraso: 2),
            _lampada(no(6, 2), no(6, 3), 5, 24),
            _fio(no(6, 3), no(6, 4)),
            // 67/68 NF com relógio próprio de 7 s.
            _fio(no(7, 0), no(7, 1)),
            _contatoTemporizadoNf(no(7, 1), no(7, 2),
                contatoDe: kt1, atraso: 7),
            _lampada(no(7, 2), no(7, 3), 5, 24),
            _fio(no(7, 3), no(7, 4)),
            // Barramento negativo.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(5, 4), no(6, 4)),
            _fio(no(6, 4), no(7, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Dois contatos do temporizador',
        'Um temporizador KT1 com 3 s e os dois contatos dele em 24 V: o 67/68 '
            'NA acende a lâmpada L1 ("pronto") e o 67/68 NF mantém a lâmpada L2 '
            '("aguarde") acesa até o atraso terminar. Aperte a partida e use '
            'Avançar 1 s três vezes para o KT1 trocar as duas lâmpadas.',
        () {
          const colunas = 8;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(4, 1), no(4, 2));
          final kt1 = chaveTrecho(no(5, 1), no(5, 2));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Barramento positivo no topo, da fonte até a coluna do NF.
            _fio(no(0, 0), no(1, 0)),
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _fio(no(3, 0), no(4, 0)),
            _fio(no(4, 0), no(5, 0)),
            _fio(no(5, 0), no(6, 0)),
            _fio(no(6, 0), no(7, 0)),
            // Comando: parada NF, partida NA, selo de K1 e a bobina.
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1), normalmenteFechado: true),
            _botoeira(no(2, 1), no(3, 1)),
            _fio(no(2, 1), no(2, 2)),
            _contatoSelo(no(2, 2), no(3, 2), contatoDe: k1),
            _fio(no(3, 2), no(3, 1)),
            _fio(no(3, 1), no(4, 1)),
            _bobina(no(4, 1), no(4, 2), 240, 24),
            _fio(no(4, 2), no(4, 4)),
            // Temporizador em paralelo com a bobina.
            _fio(no(4, 1), no(5, 1)),
            _temporizador(no(5, 1), no(5, 2), 3),
            _fio(no(5, 2), no(5, 4)),
            // 67/68 NA: acende L1 depois dos 3 s.
            _fio(no(6, 0), no(6, 1)),
            _contatoTemporizado(no(6, 1), no(6, 2), contatoDe: kt1),
            _lampada(no(6, 2), no(6, 3), 5, 24),
            _fio(no(6, 3), no(6, 4)),
            // 67/68 NF: mantém L2 acesa até os 3 s e apaga no fim.
            _fio(no(7, 0), no(7, 1)),
            _contatoTemporizadoNf(no(7, 1), no(7, 2), contatoDe: kt1),
            _lampada(no(7, 2), no(7, 3), 5, 24),
            _fio(no(7, 3), no(7, 4)),
            // Barramento negativo.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
            _fio(no(5, 4), no(6, 4)),
            _fio(no(6, 4), no(7, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Partida com relé de sobrecarga',
        'Comando e potência em 24 V com proteção: FT1 fica em série com o motor '
            'e o contato 95/96 em série com a bobina. Ajustado em 1,5 A, o motor '
            'de 1 A roda normal; baixe o ajuste e o relé desarma o comando.',
        () {
          const colunas = 6;
          const linhas = 5;
          int no(int x, int y) => y * colunas + x;
          final k1 = chaveTrecho(no(3, 1), no(3, 2));
          final ft1 = chaveTrecho(no(4, 0), no(5, 0));
          return Circuito(
              colunas: colunas, linhas: linhas, elementos: [
            _fonte(no(0, 0), no(0, 1), 24),
            // Comando: parada NF, partida NA, selo e o 95/96 do relé.
            _botoeira(no(0, 0), no(1, 0), normalmenteFechado: true),
            _fio(no(1, 0), no(1, 1)),
            _botoeira(no(1, 1), no(2, 1)),
            _fio(no(1, 1), no(1, 2)),
            _contatoSelo(no(1, 2), no(2, 2), contatoDe: k1),
            _fio(no(2, 2), no(2, 1)),
            _contatoRele(no(2, 1), no(3, 1), contatoDe: ft1),
            _bobina(no(3, 1), no(3, 2), 240, 24),
            _fio(no(3, 2), no(3, 3)),
            _fio(no(3, 3), no(3, 4)),
            // Potência: contato principal, relé térmico e motor.
            _fio(no(1, 0), no(2, 0)),
            _fio(no(2, 0), no(3, 0)),
            _contatoPotencia(no(3, 0), no(4, 0), contatoDe: k1),
            _releTermico(no(4, 0), no(5, 0), 1.5),
            _motor(no(5, 0), no(5, 1), 24, 24),
            _fio(no(5, 1), no(5, 2)),
            _fio(no(5, 2), no(5, 3)),
            _fio(no(5, 3), no(5, 4)),
            // Retorno até o polo negativo da fonte.
            _fio(no(0, 1), no(0, 2)),
            _fio(no(0, 2), no(0, 3)),
            _fio(no(0, 3), no(0, 4)),
            _fio(no(0, 4), no(1, 4)),
            _fio(no(1, 4), no(2, 4)),
            _fio(no(2, 4), no(3, 4)),
            _fio(no(3, 4), no(4, 4)),
            _fio(no(4, 4), no(5, 4)),
          ]);
        },
      ),
      ExemploCircuito(
        'Curto protegido por fusível',
        'Um fio liga os polos direto: o fusível de 1 A rompe e desliga tudo.',
        () {
          final c = Circuito();
          final n = c.no;
          return Circuito(elementos: [
            _fonte(n(0, 1), n(0, 2), 12),
            _fio(n(0, 1), n(1, 1)),
            _fusivel(n(1, 1), n(2, 1), 1),
            _fio(n(2, 1), n(3, 1)),
            _fio(n(3, 1), n(3, 2)),
            _fio(n(3, 2), n(2, 2)),
            _fio(n(2, 2), n(1, 2)),
            _fio(n(1, 2), n(0, 2)),
          ]);
        },
      ),
      ExemploCircuito(
        'Sensor de fim de curso',
        'Sensor NF em série com a lâmpada: em repouso ela acende; ao acionar o '
            'sensor (botão Acionar sensor no editor), o contato abre e apaga.',
        () {
          final c = Circuito(colunas: 4, linhas: 3);
          final n = c.no;
          return Circuito(colunas: 4, linhas: 3, elementos: [
            _fonte(n(0, 0), n(0, 1), 12),
            _fio(n(0, 0), n(1, 0)),
            _sensor(n(1, 0), n(2, 0)),
            _lampada(n(2, 0), n(3, 0), 5, 12),
            _fio(n(3, 0), n(3, 1)),
            _fio(n(3, 1), n(2, 1)),
            _fio(n(2, 1), n(1, 1)),
            _fio(n(1, 1), n(0, 1)),
          ]);
        },
      ),
    ];

Circuito circuitoExemplo(String nome) {
  for (final exemplo in exemplosCircuito) {
    if (exemplo.nome == nome) return exemplo.montar();
  }
  return exemplosCircuito.first.montar();
}
