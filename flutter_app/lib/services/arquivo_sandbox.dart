import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/arquivos.dart';

/// Operações de arquivo que a tela pode usar — permite testar sem tocar no disco do aparelho.
abstract interface class ArquivoSandbox {
  Future<List<ArquivoResumo>> listar();

  Future<String> ler(String nome);

  Future<void> criar(String nome, String conteudo);

  Future<void> gravar(String nome, String conteudo);

  Future<void> renomear(String antigo, String novo);

  Future<void> apagar(String nome);
}

/// Pasta privada do app. Todo caminho é resolvido e conferido contra a raiz antes de tocar no disco.
///
/// Não executa código, não abre pasta externa e não guarda caminho escolhido pelo usuário. A
/// criação de arquivo só nasce daqui.
class ArquivoSandboxDispositivo implements ArquivoSandbox {
  ArquivoSandboxDispositivo(this.pasta);

  final String pasta;

  Future<File> _arquivo(String nome) async {
    final validado = validarNomeArquivo(nome);
    if (!validado.valido) throw ArgumentError(validado.erro);
    final caminho = caminhoSeguroNaPasta(pasta, validado.nome!);
    if (caminho == null) throw ArgumentError('Caminho fora da pasta isolada recusado.');
    return File(caminho);
  }

  @override
  Future<List<ArquivoResumo>> listar() async {
    final raiz = Directory(pasta);
    if (!await raiz.exists()) return const [];
    final resumos = <ArquivoResumo>[];
    await for (final entidade in raiz.list(followLinks: false)) {
      if (entidade is! File) continue;
      final nome = p.basename(entidade.path);
      if (!nome.toLowerCase().endsWith(extensaoArquivo)) continue;
      final dados = await entidade.stat();
      resumos.add(ArquivoResumo(
        nome: nome,
        bytes: dados.size,
        modificadoEm: dados.modified,
      ));
    }
    resumos.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return resumos;
  }

  @override
  Future<String> ler(String nome) async {
    final arquivo = await _arquivo(nome);
    if (!await arquivo.exists()) throw StateError('Arquivo não encontrado.');
    return arquivo.readAsString();
  }

  @override
  Future<void> criar(String nome, String conteudo) async {
    final erro = validarConteudoArquivo(conteudo);
    if (erro != null) throw ArgumentError(erro);
    final arquivo = await _arquivo(nome);
    if (await arquivo.exists()) throw StateError('Já existe um arquivo com esse nome.');
    if ((await listar()).length >= limiteArquivos) {
      throw StateError('Limite de $limiteArquivos arquivos atingido. Apague algum antes de criar outro.');
    }
    await arquivo.writeAsString(conteudo, encoding: utf8, flush: true);
  }

  @override
  Future<void> gravar(String nome, String conteudo) async {
    final erro = validarConteudoArquivo(conteudo);
    if (erro != null) throw ArgumentError(erro);
    final arquivo = await _arquivo(nome);
    if (!await arquivo.exists()) throw StateError('Arquivo não encontrado.');
    await arquivo.writeAsString(conteudo, encoding: utf8, flush: true);
  }

  @override
  Future<void> renomear(String antigo, String novo) async {
    final origem = await _arquivo(antigo);
    if (!await origem.exists()) throw StateError('Arquivo não encontrado.');
    final destino = await _arquivo(novo);
    if (await destino.exists()) throw StateError('Já existe um arquivo com esse nome.');
    await origem.rename(destino.path);
  }

  @override
  Future<void> apagar(String nome) async {
    final arquivo = await _arquivo(nome);
    if (await arquivo.exists()) await arquivo.delete();
  }
}
