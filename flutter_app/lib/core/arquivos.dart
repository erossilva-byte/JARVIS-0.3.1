/// Arquivos de texto na pasta isolada do app — contrato puro, sem Flutter e sem rede.
///
/// A pasta é privada do aplicativo: não é a pasta do Obsidian, não é Downloads e não recebe
/// caminho do usuário. O nome é validado antes de virar arquivo e o caminho final é conferido para
/// não escapar da raiz.
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

const limiteArquivos = 200;
const limiteBytesArquivo = 512 * 1024;
const extensaoArquivo = '.txt';
const nomePastaArquivos = 'JarvisArquivos';

class NomeArquivo {
  const NomeArquivo.ok(this.nome) : erro = null;
  const NomeArquivo.recusado(this.erro) : nome = null;

  final String? nome;
  final String? erro;

  bool get valido => erro == null;
}

/// Aceita nome simples e acrescenta `.txt` quando faltar. Recusa separador, caminho e nome vazio.
NomeArquivo validarNomeArquivo(String bruto) {
  final limpo = bruto.trim();
  if (limpo.isEmpty) {
    return const NomeArquivo.recusado('Dê um nome ao arquivo.');
  }
  if (limpo == '.' || limpo == '..') {
    return const NomeArquivo.recusado('Esse nome não é permitido.');
  }
  if (limpo.length > 64) {
    return const NomeArquivo.recusado('O nome deve ter no máximo 64 caracteres.');
  }
  if (RegExp(r'[\\/:*?"<>|\x00-\x1F]').hasMatch(limpo)) {
    return const NomeArquivo.recusado('O nome não pode conter barras nem os caracteres \\ / : * ? " < > |.');
  }
  final minusculo = limpo.toLowerCase();
  final reservados = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)');
  if (reservados.hasMatch(minusculo)) {
    return const NomeArquivo.recusado('Esse nome é reservado pelo sistema. Escolha outro.');
  }
  final nome = minusculo.endsWith(extensaoArquivo) ? limpo : '$limpo$extensaoArquivo';
  if (nome.length > 68) {
    return const NomeArquivo.recusado('O nome com a extensão passou de 68 caracteres.');
  }
  return NomeArquivo.ok(nome);
}

/// Devolve a recusa quando o texto passa de 512 kB, ou nulo quando cabe.
String? validarConteudoArquivo(String texto) {
  final bytes = utf8.encode(texto).length;
  if (bytes > limiteBytesArquivo) {
    return 'O texto tem ${(bytes / 1024).toStringAsFixed(0)} kB; o limite é 512 kB.';
  }
  return null;
}

/// Caminho final dentro da raiz, ou nulo quando o nome tentaria sair dela.
String? caminhoSeguroNaPasta(String raiz, String nome) {
  final base = p.normalize(p.absolute(raiz));
  final alvo = p.normalize(p.absolute(p.join(raiz, nome)));
  if (p.equals(base, alvo) || !p.isWithin(base, alvo)) return null;
  return alvo;
}

class ArquivoResumo {
  const ArquivoResumo({required this.nome, required this.bytes, this.modificadoEm});

  final String nome;
  final int bytes;
  final DateTime? modificadoEm;

  String get tamanhoLegivel {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} kB';
  }
}
