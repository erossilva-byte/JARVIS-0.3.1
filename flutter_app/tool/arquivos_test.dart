import 'dart:io';

import 'package:jarvis_nova/core/arquivos.dart';
import 'package:jarvis_nova/services/arquivo_sandbox.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  // 1. Nome seguro: extensão, vazio, caminho e nome reservado.
  assert(validarNomeArquivo('nota').nome == 'nota.txt', 'extensão não acrescentada');
  assert(validarNomeArquivo('  nota.TXT  ').nome == 'nota.TXT', 'extensão existente alterada');
  assert(validarNomeArquivo('').erro != null, 'nome vazio aceito');
  assert(validarNomeArquivo('.').erro != null, 'ponto aceito');
  assert(validarNomeArquivo('..').erro != null, 'dois pontos aceitos');
  assert(validarNomeArquivo('../fora').erro != null, 'caminho relativo aceito');
  assert(validarNomeArquivo('a/b').erro != null, 'barra aceita');
  assert(validarNomeArquivo('a\\b').erro != null, 'barra invertida aceita');
  assert(validarNomeArquivo('con').erro != null, 'nome reservado aceito');
  assert(validarNomeArquivo('x' * 70).erro != null, 'nome longo aceito');

  // 2. Limite de conteúdo em bytes, não em caracteres.
  assert(validarConteudoArquivo('texto') == null, 'texto curto recusado');
  assert(validarConteudoArquivo('a' * (limiteBytesArquivo + 1)) != null, 'texto acima de 512 kB aceito');
  assert(validarConteudoArquivo('ç' * (limiteBytesArquivo ~/ 2 + 1)) != null,
      'bytes de acento não contados');

  // 3. Caminho não escapa da raiz.
  final base = p.join(Directory.systemTemp.path, 'base-jarvis');
  assert(caminhoSeguroNaPasta(base, 'nota.txt') != null, 'caminho simples recusado');
  assert(caminhoSeguroNaPasta(base, '../fora.txt') == null, '../ escapou da raiz');
  assert(caminhoSeguroNaPasta(base, 'a/../../fora.txt') == null, 'subpasta escapou da raiz');
  assert(caminhoSeguroNaPasta(base, p.join(base, '..', 'fora.txt')) == null, 'absoluto externo aceito');

  // 4. Operações reais em pasta temporária.
  final raiz = await Directory.systemTemp.createTemp('jarvis_arquivos_');
  final pasta = Directory(p.join(raiz.path, nomePastaArquivos));
  await pasta.create(recursive: true);
  final sandbox = ArquivoSandboxDispositivo(pasta.path);
  try {
    await sandbox.criar('nota', 'Olá, J.A.R.V.I.S.\nAcentuação: ação, coração.');
    assert(await sandbox.ler('nota.txt') == 'Olá, J.A.R.V.I.S.\nAcentuação: ação, coração.', 'leitura não preservou o texto');
    var lista = await sandbox.listar();
    assert(lista.length == 1 && lista.single.nome == 'nota.txt', 'listagem não encontrou o arquivo');

    await sandbox.gravar('nota.txt', 'Texto atualizado.');
    assert(await sandbox.ler('nota.txt') == 'Texto atualizado.', 'gravação não atualizou');

    await sandbox.renomear('nota.txt', 'outra');
    lista = await sandbox.listar();
    assert(lista.single.nome == 'outra.txt', 'renomear não aplicou extensão');
    assert(!await File(p.join(pasta.path, 'nota.txt')).exists(), 'arquivo antigo ficou para trás');

    // Arquivo que não é .txt não aparece e não é operado.
    await File(p.join(pasta.path, 'ignorar.md')).writeAsString('fora');
    assert((await sandbox.listar()).length == 1, 'arquivo .md entrou na lista');

    var recusou = false;
    try {
      await sandbox.criar('../fora.txt', 'x');
    } on ArgumentError {
      recusou = true;
    }
    assert(recusou, 'criação fora da pasta não foi recusada');
    assert(!await File(p.join(raiz.path, 'fora.txt')).exists(), 'arquivo foi criado fora da pasta');

    recusou = false;
    try {
      await sandbox.ler('../../etc/passwd');
    } on ArgumentError {
      recusou = true;
    }
    assert(recusou, 'leitura fora da pasta não foi recusada');

    recusou = false;
    try {
      await sandbox.criar('outra.txt', 'duplicado');
    } on StateError {
      recusou = true;
    }
    assert(recusou, 'criação duplicada não foi recusada');

    await sandbox.apagar('outra.txt');
    assert((await sandbox.listar()).isEmpty, 'arquivo não foi apagado');

    // Limite de 200 arquivos é barrado antes de criar o 201º.
    for (var i = 0; i < limiteArquivos; i++) {
      await File(p.join(pasta.path, 'lote_$i.txt')).writeAsString('x');
    }
    assert((await sandbox.listar()).length == limiteArquivos, 'lote de teste incompleto');
    recusou = false;
    try {
      await sandbox.criar('excedente', 'x');
    } on StateError {
      recusou = true;
    }
    assert(recusou, 'limite de 200 arquivos não foi aplicado');
    assert(!await File(p.join(pasta.path, 'excedente.txt')).exists(), 'arquivo acima do limite foi criado');
  } finally {
    await raiz.delete(recursive: true);
  }

  // 5. Pasta ausente não inventa arquivo.
  final vazio = ArquivoSandboxDispositivo(p.join(Directory.systemTemp.path, 'jarvis_inexistente_${DateTime.now().microsecondsSinceEpoch}'));
  assert((await vazio.listar()).isEmpty, 'pasta inexistente devolveu arquivo');

  stdout.writeln('OK: arquivos — nome seguro, limite, caminho confinado, criar/ler/renomear/apagar');
}
