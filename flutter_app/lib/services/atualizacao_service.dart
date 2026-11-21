import 'dart:async';

import 'package:flutter/services.dart';

/// Erro explicado da ponte de atualização.
class AtualizacaoIndisponivel implements Exception {
  const AtualizacaoIndisponivel(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Versão instalada e estado do APK já baixado.
class EstadoAtualizacao {
  const EstadoAtualizacao({
    this.versao = '',
    this.versionCode = -1,
    this.pacote = '',
    this.repositorio = '',
    this.urlReleases = '',
    this.instaladorAutorizado = false,
    this.baixado = false,
    this.baixadoBytes = 0,
  });

  final String versao;
  final int versionCode;
  final String pacote;
  final String repositorio;
  final String urlReleases;

  /// O Android autorizou este app a abrir o instalador de APK.
  final bool instaladorAutorizado;
  final bool baixado;
  final int baixadoBytes;

  String get versaoCompleta =>
      versionCode > 0 ? '$versao (build $versionCode)' : versao;

  static EstadoAtualizacao deMapa(Object? dados) {
    if (dados is! Map) return const EstadoAtualizacao();
    String texto(Object? v) => v is String ? v : '';
    int inteiro(Object? v) => v is num ? v.toInt() : -1;
    return EstadoAtualizacao(
      versao: texto(dados['versao']),
      versionCode: inteiro(dados['versionCode']),
      pacote: texto(dados['pacote']),
      repositorio: texto(dados['repositorio']),
      urlReleases: texto(dados['urlReleases']),
      instaladorAutorizado: dados['instaladorAutorizado'] == true,
      baixado: dados['baixado'] == true,
      baixadoBytes: inteiro(dados['baixadoBytes']),
    );
  }
}

/// Release publicado no GitHub, com o que foi anexado pela esteira.
class ReleasePublicado {
  const ReleasePublicado({
    this.disponivel = false,
    this.motivo = '',
    this.versao = '',
    this.tag = '',
    this.versaoInstalada = '',
    this.urlApk = '',
    this.nomeArquivo = '',
    this.tamanho = -1,
    this.urlSha256 = '',
    this.nomeSha256 = '',
    this.digesto = '',
    this.notas = '',
    this.urlRelease = '',
    this.urlReleases = '',
  });

  final bool disponivel;

  /// `disponivel`, `atualizado`, `nenhum-release` ou `sem-apk`.
  final String motivo;
  final String versao;
  final String tag;
  final String versaoInstalada;
  final String urlApk;
  final String nomeArquivo;
  final int tamanho;
  final String urlSha256;
  final String nomeSha256;

  /// SHA-256 que o release publica (arquivo `.sha256` ou o digesto do GitHub).
  final String digesto;
  final String notas;
  final String urlRelease;
  final String urlReleases;

  /// O release publica o digesto que o download vai conferir.
  bool get temDigestoPublicado =>
      urlSha256.isNotEmpty || hashSha256Publicado(digesto) != null;

  static ReleasePublicado deMapa(Object? dados) {
    if (dados is! Map) return const ReleasePublicado();
    String texto(String chave) {
      final valor = dados[chave];
      return valor is String ? valor : '';
    }

    final tamanho = dados['tamanho'];
    return ReleasePublicado(
      disponivel: dados['disponivel'] == true,
      motivo: texto('motivo'),
      versao: texto('versao'),
      tag: texto('tag'),
      versaoInstalada: texto('versaoInstalada'),
      urlApk: texto('urlApk'),
      nomeArquivo: texto('nomeArquivo'),
      tamanho: tamanho is num ? tamanho.toInt() : -1,
      urlSha256: texto('urlSha256'),
      nomeSha256: texto('nomeSha256'),
      digesto: texto('digesto'),
      notas: texto('notas'),
      urlRelease: texto('urlRelease'),
      urlReleases: texto('urlReleases'),
    );
  }
}

/// Resultado do download conferido.
class ResultadoDownload {
  const ResultadoDownload({
    this.sha256 = '',
    this.bytes = 0,
    this.versao = '',
    this.nomeArquivo = '',
  });

  final String sha256;
  final int bytes;
  final String versao;
  final String nomeArquivo;

  static ResultadoDownload deMapa(Object? dados) {
    if (dados is! Map) return const ResultadoDownload();
    String texto(String chave) =>
        dados[chave] is String ? dados[chave] as String : '';
    final bytes = dados['bytes'];
    return ResultadoDownload(
      sha256: texto('sha256'),
      bytes: bytes is num ? bytes.toInt() : 0,
      versao: texto('versao'),
      nomeArquivo: texto('nomeArquivo'),
    );
  }
}

/// O que o instalador respondeu.
class ResultadoInstalacao {
  const ResultadoInstalacao({required this.ok, required this.mensagem});
  final bool ok;
  final String mensagem;

  static ResultadoInstalacao deMapa(Object? dados) {
    if (dados is! Map) {
      return const ResultadoInstalacao(
          ok: false, mensagem: 'O Android não respondeu sobre a instalação.');
    }
    final mensagem = dados['mensagem'];
    return ResultadoInstalacao(
      ok: dados['ok'] == true,
      mensagem: mensagem is String && mensagem.isNotEmpty
          ? mensagem
          : 'O Android não explicou o resultado.',
    );
  }
}

/// Progresso do download, em passos de 5%.
class ProgressoDownload {
  const ProgressoDownload(this.pct, this.bytes);
  final int pct;
  final int bytes;

  static ProgressoDownload? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final pct = dados['pct'];
    final bytes = dados['bytes'];
    if (pct is! num) return null;
    return ProgressoDownload(pct.toInt(), bytes is num ? bytes.toInt() : 0);
  }
}

/// Ponte com o Android para atualizar o app pelo release publicado.
///
/// Fora do Android (testes, Windows) o canal não existe: cada chamada devolve
/// erro explicado e a tela continua funcionando. Nada aqui declara sucesso sem
/// a resposta nativa — e a instalação nunca acontece sem confirmação do Android.
class AtualizacaoService {
  AtualizacaoService({MethodChannel? canal, EventChannel? eventos})
      : _canal = canal ?? const MethodChannel('com.jarvis.nova/atualizacao'),
        _eventos = eventos ??
            const EventChannel('com.jarvis.nova/atualizacao/eventos');

  final MethodChannel _canal;
  final EventChannel _eventos;

  Stream<ProgressoDownload> get progresso => _eventos
      .receiveBroadcastStream()
      .map(ProgressoDownload.deMapa)
      .where((item) => item != null)
      .cast<ProgressoDownload>();

  Future<Map<Object?, Object?>?> _chamar(String metodo) async {
    try {
      return await _canal.invokeMapMethod<Object?, Object?>(metodo);
    } on MissingPluginException {
      throw const AtualizacaoIndisponivel(
          'Este aparelho não tem a ponte de atualização do Jarvis.');
    } on PlatformException catch (erro) {
      final mensagem = erro.message;
      throw AtualizacaoIndisponivel(
          mensagem == null || mensagem.trim().isEmpty
              ? 'O Android recusou a atualização.'
              : mensagem.trim());
    }
  }

  Future<EstadoAtualizacao> status() async =>
      EstadoAtualizacao.deMapa(await _chamar('status'));

  /// Consulta o release publicado. Devolve o motivo quando não há atualização.
  Future<ReleasePublicado> verificar() async =>
      ReleasePublicado.deMapa(await _chamar('verificar'));

  /// Baixa o APK já conferindo o SHA-256 publicado pela esteira.
  Future<ResultadoDownload> baixar() async =>
      ResultadoDownload.deMapa(await _chamar('baixar'));

  /// Abre o instalador do Android. A confirmação final é sempre do sistema.
  Future<ResultadoInstalacao> instalar() async =>
      ResultadoInstalacao.deMapa(await _chamar('instalar'));

  Future<bool> abrirReleases() async {
    await _chamar('abrirReleases');
    return true;
  }
}

/// Primeiro SHA-256 de um texto no formato `hash  arquivo.apk`.
String? hashSha256Publicado(String texto) {
  final achado = RegExp(r'[0-9a-fA-F]{64}').firstMatch(texto);
  return achado?.group(0)?.toLowerCase();
}

List<int>? partesDaVersao(String texto) {
  final achado = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(texto);
  if (achado == null) return null;
  return [
    for (var i = 1; i <= 3; i++)
      int.tryParse(achado.group(i) ?? '') ?? 0,
  ];
}

/// Compara versões numéricas (`1.78.0` contra `1.77.0`).
bool versaoMaiorQue(String nova, String atual) {
  final a = partesDaVersao(nova);
  final b = partesDaVersao(atual);
  if (a == null) return false;
  if (b == null) return nova.trim().isNotEmpty;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Frase honesta para cada motivo de não haver atualização.
String mensagemDoMotivo(String motivo) {
  switch (motivo) {
    case 'atualizado':
      return 'A versão instalada já é a mais recente publicada.';
    case 'nenhum-release':
      return 'Não há release publicado com APK. Publique pela esteira do GitHub Actions para o app poder se atualizar.';
    case 'sem-apk':
      return 'O release mais novo não tem APK anexado.';
    default:
      return 'Nenhum release com APK disponível para baixar.';
  }
}
