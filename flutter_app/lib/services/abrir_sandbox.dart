import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/arquivos.dart';
import 'arquivo_sandbox.dart';

/// Cria (se preciso) a pasta privada dentro dos documentos do app e devolve o sandbox.
Future<ArquivoSandbox> abrirSandboxPadrao() async {
  final documentos = await getApplicationDocumentsDirectory();
  final pasta = Directory(p.join(documentos.path, nomePastaArquivos));
  await pasta.create(recursive: true);
  return ArquivoSandboxDispositivo(pasta.path);
}
