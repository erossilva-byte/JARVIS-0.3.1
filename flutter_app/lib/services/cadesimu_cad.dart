import 'package:flutter/services.dart';

const _cabecalho = 'CADe_SIMU';
const _marcaRodape = r'#$$$';
const _tipoTexto = 8;
const _tiposFio = {4000, 4009, 4010, 4018, 4019};
const _tiposMarcador = {4001, 4002, 4003, 4004, 10104, 10105, 10106, 10112};

final _inicio = RegExp(r'\*(\d+)\*(\d+)#');
final _proximo = RegExp(r'#\*(\d+)\*(\d+)#');
final _qualquer = RegExp(r'\*(\d+)\*(\d+)#');

class CadesimuErro implements Exception {
  CadesimuErro(this.message);
  final String message;
  @override
  String toString() => message;
}

class RegistroCad {
  const RegistroCad({
    required this.indice,
    required this.tipo,
    required this.bruto,
    this.separador = '',
  });

  final int indice;
  final int tipo;
  final String bruto;
  final String separador;

  List<String> get rotulos {
    final corpo = bruto.split('#').skip(1).join('#');
    return corpo.split('*').first.split('#');
  }

  List<String> get campos {
    final corpo = bruto.split('#').skip(1).join('#');
    final partes = corpo.split('*');
    return partes.length <= 1 ? const [] : partes.sublist(1);
  }

  String get rotulo => rotulos.isEmpty ? '' : rotulos.first;

  List<String> get pinos => rotulos.length <= 2
      ? const []
      : rotulos.sublist(2).where((p) => p.isNotEmpty).toList();

  int? _inteiro(int posicao) {
    if (campos.length <= posicao) return null;
    return int.tryParse(campos[posicao]);
  }

  int? get x => _inteiro(8);
  int? get y => _inteiro(9);
  int? get x2 => _inteiro(10);
  int? get y2 => _inteiro(11);

  String get texto {
    if (tipo != _tipoTexto) return '';
    final partes = bruto.split('#');
    return partes.isEmpty ? '' : partes.last;
  }

  bool get ehFio => _tiposFio.contains(tipo);
  bool get ehMarcador => _tiposMarcador.contains(tipo);
}

class ResumoCad {
  const ResumoCad({
    required this.registros,
    required this.simbolos,
    required this.fios,
    required this.juncoes,
    required this.textos,
    required this.redesGeometricas,
    required this.simbolosComFioNaOrigem,
    required this.rodape,
    required this.tipos,
  });

  final int registros;
  final int simbolos;
  final int fios;
  final int juncoes;
  final List<String> textos;
  final int redesGeometricas;
  final int simbolosComFioNaOrigem;
  final bool rodape;
  final Map<int, int> tipos;
}

class DocumentoCad {
  const DocumentoCad(this.registros, this.rodape);

  final List<RegistroCad> registros;
  final String rodape;

  static DocumentoCad ler(String texto) {
    if (!texto.startsWith(_cabecalho)) {
      throw CadesimuErro('Cabeçalho CADe_SIMU ausente.');
    }
    final posicaoRodape = texto.indexOf(_marcaRodape, _cabecalho.length);
    final corpo = posicaoRodape < 0
        ? texto.substring(_cabecalho.length)
        : texto.substring(_cabecalho.length, posicaoRodape);
    final rodape = posicaoRodape < 0 ? '' : texto.substring(posicaoRodape);
    if (corpo.isEmpty) throw CadesimuErro('O arquivo não tem registros.');

    final registros = <RegistroCad>[];
    var inicio = 0;
    var separador = '';
    while (inicio < corpo.length) {
      final cabeca = _inicio.matchAsPrefix(corpo, inicio);
      if (cabeca == null) {
        final trecho =
            corpo.substring(inicio, (inicio + 40).clamp(0, corpo.length));
        throw CadesimuErro(
            'Registro malformado na posição $inicio: "$trecho".');
      }
      final indice = int.parse(cabeca.group(1)!);
      final tipo = int.parse(cabeca.group(2)!);
      Match? proximo;
      var fim = corpo.length;
      var proximoSeparador = '';
      if (tipo == _tipoTexto) {
        proximo = _proximoTexto(corpo, inicio);
        if (proximo != null) fim = proximo.start;
      } else {
        proximo = _proximo.allMatches(corpo).cast<Match?>().firstWhere(
              (m) => m != null && m.start >= cabeca.end,
              orElse: () => null,
            );
        if (proximo != null) {
          fim = proximo.start;
          proximoSeparador = '#';
        }
      }
      registros.add(RegistroCad(
        indice: indice,
        tipo: tipo,
        bruto: corpo.substring(inicio, fim),
        separador: separador,
      ));
      if (proximo == null) break;
      inicio = tipo == _tipoTexto ? proximo.start : proximo.start + 1;
      separador = proximoSeparador;
    }
    if (registros.isEmpty) throw CadesimuErro('O arquivo não tem registros.');
    return DocumentoCad(registros, rodape);
  }

  static Match? _proximoTexto(String corpo, int inicio) {
    final cabeca = _inicio.matchAsPrefix(corpo, inicio);
    if (cabeca == null) return null;
    final primeiroCampo = corpo.indexOf('*', cabeca.end);
    if (primeiroCampo < 0) return null;
    final fimCampos = corpo.indexOf('#', primeiroCampo);
    if (fimCampos < 0) return null;
    for (final candidato in _qualquer.allMatches(corpo)) {
      if (candidato.start > fimCampos) return candidato;
    }
    return null;
  }

  String escrever() =>
      _cabecalho +
      registros.map((r) => '${r.separador}${r.bruto}').join() +
      rodape;

  bool get temRodape => rodape.startsWith(_marcaRodape);

  List<RegistroCad> get simbolos => registros
      .where((r) => !r.ehFio && !r.ehMarcador && r.tipo != _tipoTexto)
      .toList();

  List<RegistroCad> get fios => registros.where((r) => r.ehFio).toList();

  List<String> get textos =>
      registros.where((r) => r.tipo == _tipoTexto).map((r) => r.texto).toList();

  /// Grupos de fios ligados por extremidade exata ou junção 4001.
  /// Não é a netlist elétrica: pinos de símbolos dependem da classe e da orientação.
  int redesGeometricas() {
    final lista = fios;
    if (lista.isEmpty) return 0;
    final pai = List<int>.generate(lista.length, (i) => i);
    int achar(int i) {
      while (pai[i] != i) {
        pai[i] = pai[pai[i]];
        i = pai[i];
      }
      return i;
    }

    void unir(int a, int b) {
      final ra = achar(a), rb = achar(b);
      if (ra != rb) pai[rb] = ra;
    }

    final extremos = <String, int>{};
    final segmentos = <(int, int, int, int)>[];
    for (var i = 0; i < lista.length; i++) {
      final fio = lista[i];
      if (fio.x == null || fio.y == null || fio.x2 == null || fio.y2 == null) {
        continue;
      }
      final a = (fio.x!, fio.y!);
      final b = (fio.x2!, fio.y2!);
      segmentos.add((a.$1, a.$2, b.$1, b.$2));
      for (final ponto in [a, b]) {
        final chave = '${ponto.$1},${ponto.$2}';
        final existente = extremos[chave];
        if (existente != null) {
          unir(i, existente);
        } else {
          extremos[chave] = i;
        }
      }
    }
    for (final marcador in registros) {
      if (marcador.tipo != 4001 || marcador.x == null || marcador.y == null) {
        continue;
      }
      final px = marcador.x!, py = marcador.y!;
      final tocados = <int>[];
      for (var i = 0; i < segmentos.length; i++) {
        final (x1, y1, x2, y2) = segmentos[i];
        final horizontal = y1 == y2 &&
            py == y1 &&
            px >= (x1 < x2 ? x1 : x2) &&
            px <= (x1 > x2 ? x1 : x2);
        final vertical = x1 == x2 &&
            px == x1 &&
            py >= (y1 < y2 ? y1 : y2) &&
            py <= (y1 > y2 ? y1 : y2);
        if (horizontal || vertical) tocados.add(i);
      }
      for (var i = 1; i < tocados.length; i++) {
        unir(tocados.first, tocados[i]);
      }
    }
    return {for (var i = 0; i < lista.length; i++) achar(i)}.length;
  }

  ResumoCad resumo() {
    final tipos = <int, int>{};
    for (final r in registros) {
      tipos[r.tipo] = (tipos[r.tipo] ?? 0) + 1;
    }
    final extremos = <String>{};
    for (final fio in fios) {
      if (fio.x != null && fio.y != null && fio.x2 != null && fio.y2 != null) {
        extremos.add('${fio.x},${fio.y}');
        extremos.add('${fio.x2},${fio.y2}');
      }
    }
    final comFio = simbolos
        .where((s) =>
            s.x != null && s.y != null && extremos.contains('${s.x},${s.y}'))
        .length;
    return ResumoCad(
      registros: registros.length,
      simbolos: simbolos.length,
      fios: fios.length,
      juncoes: tipos[4001] ?? 0,
      textos: textos,
      redesGeometricas: redesGeometricas(),
      simbolosComFioNaOrigem: comFio,
      rodape: temRodape,
      tipos: tipos,
    );
  }
}

class ArquivoCad {
  const ArquivoCad(this.nome, this.bytes);
  final String nome;
  final Uint8List bytes;

  String get texto => String.fromCharCodes(bytes);
  int get tamanho => bytes.length;
}

abstract interface class SeletorCad {
  Future<ArquivoCad?> escolher();
}

class SeletorCadAndroid implements SeletorCad {
  const SeletorCadAndroid();

  static const canal = MethodChannel('com.jarvis.nova/memoria');

  @override
  Future<ArquivoCad?> escolher() async {
    try {
      final resposta =
          await canal.invokeMapMethod<Object?, Object?>('abrirCad');
      if (resposta == null) return null;
      final nome = resposta['nome']?.toString() ?? 'arquivo.cad';
      final bytes = resposta['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) {
        throw CadesimuErro('O seletor não devolveu o conteúdo do arquivo.');
      }
      return ArquivoCad(nome, bytes);
    } on MissingPluginException {
      throw CadesimuErro(
          'A leitura de .cad está disponível apenas no app Android.');
    } on PlatformException catch (erro) {
      throw CadesimuErro(erro.message?.trim().isNotEmpty == true
          ? erro.message!
          : 'O Android recusou a leitura do arquivo .cad.');
    }
  }
}

ArquivoCad analisarArquivoCad(ArquivoCad arquivo) {
  final documento = DocumentoCad.ler(arquivo.texto);
  if (documento.escrever() != arquivo.texto) {
    throw CadesimuErro(
        'A leitura não devolveu o arquivo original; o arquivo não foi aceito.');
  }
  return arquivo;
}
