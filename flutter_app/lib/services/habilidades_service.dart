import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/habilidades.dart';
import 'cofre_saf.dart';

/// O que foi carregado do aparelho, com o motivo quando nada aparece.
class ResultadoHabilidades {
  const ResultadoHabilidades({
    this.habilidades = const [],
    this.aviso = '',
    this.pastaNome = '',
    this.lidas = 0,
  });

  final List<Habilidade> habilidades;

  /// Explicação honesta quando a lista está vazia (ou parcial).
  final String aviso;

  /// Nome da pasta conectada, quando existe.
  final String pastaNome;

  /// Quantos arquivos `.md` foram lidos ao todo (dentro e fora das pastas).
  final int lidas;

  bool get vazio => habilidades.isEmpty;
}

/// Carrega as habilidades em Markdown do próprio aparelho.
///
/// Duas origens, sem nuvem:
/// 1. a pasta conectada via SAF (a mesma do cofre), procurando `Skills/` ou
///    `Habilidades/` em qualquer nível;
/// 2. a pasta local do app (`habilidades/`), útil quando o cofre não está
///    conectado.
///
/// Nada é executado: o corpo do Markdown entra no pedido ao provedor de IA
/// como instrução, e apenas quando os gatilhos casam com a pergunta.
class HabilidadesService {
  const HabilidadesService();

  static const pastaLocal = 'habilidades';

  Future<ResultadoHabilidades> carregar() async {
    final arquivos = <({String caminho, String conteudo})>[];
    var pastaNome = '';
    var avisoPasta = '';

    final pasta = await CofreSaf.pastaAtual();
    if (pasta.ok && pasta.valor != null) {
      pastaNome = pasta.valor!.nome;
      final leitura = await CofreSaf.listarNotas();
      if (leitura.ok && leitura.valor != null) {
        for (final nota in leitura.valor!.notas) {
          arquivos.add((caminho: nota.caminho, conteudo: nota.conteudo));
        }
      } else if (leitura.erro != null) {
        avisoPasta = 'A pasta $pastaNome não pôde ser lida: ${leitura.erro}';
      }
    }

    final locais = await _lerPastaLocal();
    arquivos.addAll(locais);

    final habilidades = habilidadesDosArquivos(arquivos);
    var aviso = avisoPasta;
    if (habilidades.isEmpty && avisoPasta.isEmpty) {
      aviso = pastaNome.isEmpty
          ? 'Nenhuma pasta de habilidades encontrada. Conecte a pasta do '
              'Obsidian em Memória semântica e crie uma pasta Skills/, ou use '
              '“Criar exemplo no aparelho”.'
          : 'A pasta $pastaNome foi lida, mas nenhum arquivo .md está em '
              'Skills/ ou Habilidades/. Crie a pasta e escreva um arquivo por '
              'habilidade.';
    }
    return ResultadoHabilidades(
      habilidades: habilidades,
      aviso: aviso,
      pastaNome: pastaNome,
      lidas: arquivos.length,
    );
  }

  Future<List<({String caminho, String conteudo})>> _lerPastaLocal() async {
    final lidos = <({String caminho, String conteudo})>[];
    try {
      final raiz = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/$pastaLocal');
      if (!await raiz.exists()) return lidos;
      await for (final entidade in raiz.list(recursive: true, followLinks: false)) {
        if (entidade is! File) continue;
        if (!entidade.path.toLowerCase().endsWith('.md')) continue;
        if (lidos.length >= limiteHabilidades) break;
        try {
          final conteudo = await entidade.readAsString();
          final relativo = entidade.path
              .substring(raiz.path.length)
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'^/+'), '');
          lidos.add((caminho: 'Habilidades/$relativo', conteudo: conteudo));
        } catch (_) {
          // Arquivo ilegível não derruba a leitura dos outros.
        }
      }
    } catch (_) {
      // Plataforma sem pasta de documentos: a lista fica só com o cofre.
    }
    return lidos;
  }

  /// Grava o modelo de habilidade no aparelho.
  ///
  /// Prefere a pasta conectada (`Skills/exemplo-revisar-texto.md`), porque é
  /// onde o usuário consegue editar pelo gerenciador de arquivos; sem pasta
  /// gravável, escreve na pasta local do app e diz onde foi.
  Future<({bool ok, String mensagem})> criarExemplo() async {
    final pasta = await CofreSaf.pastaAtual();
    if (pasta.ok && pasta.valor != null) {
      if (pasta.valor!.podeEscrever) {
        final gravado = await CofreSaf.escreverNota(
            caminho: 'Skills/exemplo-revisar-texto.md',
            conteudo: exemploHabilidade);
        if (gravado.ok) {
          return (
            ok: true,
            mensagem: 'Exemplo gravado em Skills/exemplo-revisar-texto.md na '
                'pasta ${pasta.valor!.nome}. Edite pelo gerenciador de arquivos '
                'e toque em “Ler de novo”.',
          );
        }
        return (ok: false, mensagem: gravado.erro ?? 'A pasta não confirmou a gravação.');
      }
      return (
        ok: false,
        mensagem: 'A pasta ${pasta.valor!.nome} está conectada somente para '
            'leitura. Conecte de novo permitindo editar para o exemplo ser '
            'gravado em Skills/.',
      );
    }
    try {
      final raiz = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/$pastaLocal');
      final arquivo = File('${raiz.path}/exemplo-revisar-texto.md');
      await arquivo.parent.create(recursive: true);
      await arquivo.writeAsString(exemploHabilidade);
      return (
        ok: true,
        mensagem: 'Sem pasta do Obsidian conectada: o exemplo ficou na pasta '
            'local do app ($pastaLocal/exemplo-revisar-texto.md). Conecte a '
            'pasta em Memória semântica para editar pelo gerenciador de arquivos.',
      );
    } catch (_) {
      return (
        ok: false,
        mensagem: 'Não foi possível gravar o exemplo neste aparelho.',
      );
    }
  }
}
