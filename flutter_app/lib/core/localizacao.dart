/// Localização do aparelho — contrato puro, sem Flutter e sem rede.
///
/// Os números vêm do Android (`LocationManager` e, quando possível, do
/// `Geocoder` do próprio aparelho). Campo ausente vira `null` e a tela diz
/// "não informado": nada é inventado e nada é arredondado para parecer exato.
library;

/// Estado da permissão e dos provedores de localização.
class EstadoLocalizacao {
  const EstadoLocalizacao({
    required this.permissao,
    required this.gpsLigado,
    required this.redeLigada,
    required this.geocoder,
  });

  final bool permissao;
  final bool gpsLigado;
  final bool redeLigada;
  final bool geocoder;

  static const desconhecido = EstadoLocalizacao(
    permissao: false,
    gpsLigado: false,
    redeLigada: false,
    geocoder: false,
  );

  bool get algumProvedor => gpsLigado || redeLigada;

  /// Tudo pronto para uma leitura acontecer.
  bool get podeLer => permissao && algumProvedor;

  static EstadoLocalizacao deMapa(Map<Object?, Object?>? mapa) {
    if (mapa == null) return desconhecido;
    return EstadoLocalizacao(
      permissao: mapa['permissao'] == true,
      gpsLigado: mapa['gpsLigado'] == true,
      redeLigada: mapa['redeLigada'] == true,
      geocoder: mapa['geocoder'] == true,
    );
  }

  String get descricao {
    if (!permissao) {
      return 'Sem permissão de localização. O JARVIS não vê onde o aparelho está até você autorizar.';
    }
    if (!algumProvedor) {
      return 'A localização do aparelho está desligada. Ative o GPS nas configurações do Android.';
    }
    final fontes = [
      if (gpsLigado) 'GPS',
      if (redeLigada) 'rede',
    ].join(' e ');
    return 'Permissão concedida; $fontes disponível(is).';
  }
}

/// Uma leitura de localização, com a origem e a idade do dado.
class LocalizacaoAparelho {
  const LocalizacaoAparelho({
    required this.ok,
    required this.mensagem,
    this.latitude,
    this.longitude,
    this.precisaoMetros,
    this.fonte = '',
    this.provedor = '',
    this.idadeMs = 0,
    this.endereco = '',
    this.aviso = '',
    this.precisaPermissao = false,
  });

  final bool ok;
  final String mensagem;
  final double? latitude;
  final double? longitude;
  final double? precisaoMetros;

  /// `nova_leitura` ou `ultima_conhecida`.
  final String fonte;
  final String provedor;
  final int idadeMs;
  final String endereco;
  final String aviso;
  final bool precisaPermissao;

  static const indisponivel = LocalizacaoAparelho(
    ok: false,
    mensagem: 'A localização não foi lida neste aparelho.',
  );

  bool get temCoordenadas => latitude != null && longitude != null;

  /// Coordenadas válidas e dentro do planeta; fora disso a leitura é recusada.
  bool get valida =>
      ok &&
      temCoordenadas &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  String get coordenadas => temCoordenadas
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'não informado';

  String get precisaoRotulo =>
      precisaoMetros == null ? 'precisão não informada' : '±${precisaoMetros!.round()} m';

  String get idadeRotulo {
    if (idadeMs <= 0) return 'agora';
    final segundos = idadeMs ~/ 1000;
    if (segundos < 60) return 'há $segundos s';
    final minutos = segundos ~/ 60;
    if (minutos < 60) return 'há $minutos min';
    return 'há ${minutos ~/ 60} h';
  }

  String get fonteRotulo => switch (fonte) {
        'nova_leitura' => 'leitura nova do aparelho',
        'ultima_conhecida' => 'último ponto conhecido',
        _ => 'origem não informada',
      };

  /// Texto principal da tela e base da resposta falada.
  String get descricao {
    if (!valida) return mensagem;
    final lugar = endereco.trim().isEmpty
        ? 'Endereço aproximado indisponível.'
        : 'Perto de $endereco.';
    return '$lugar Coordenadas $coordenadas · $precisaoRotulo · $fonteRotulo ($idadeRotulo).';
  }

  static LocalizacaoAparelho deMapa(Map<Object?, Object?>? mapa) {
    if (mapa == null) return indisponivel;
    double? numero(Object? valor) => valor is num ? valor.toDouble() : null;
    final latitude = numero(mapa['latitude']);
    final longitude = numero(mapa['longitude']);
    final ok = mapa['ok'] == true;
    if (ok && (latitude == null || longitude == null)) {
      return const LocalizacaoAparelho(
        ok: false,
        mensagem: 'O Android respondeu sem as coordenadas.',
      );
    }
    return LocalizacaoAparelho(
      ok: ok,
      mensagem: mapa['mensagem']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      precisaoMetros: numero(mapa['precisaoMetros']),
      fonte: mapa['fonte']?.toString() ?? '',
      provedor: mapa['provedor']?.toString() ?? '',
      idadeMs: mapa['idadeMs'] is num ? (mapa['idadeMs'] as num).toInt() : 0,
      endereco: mapa['endereco']?.toString() ?? '',
      aviso: mapa['aviso']?.toString() ?? '',
      precisaPermissao: mapa['precisaPermissao'] == true,
    );
  }
}

/// Frase para o JARVIS falar ou escrever. Nunca afirma precisão que não tem.
String fraseLocalizacao(LocalizacaoAparelho local) {
  if (!local.valida) {
    return local.mensagem.isEmpty
        ? 'Não consegui saber onde o aparelho está agora.'
        : local.mensagem;
  }
  final onde = local.endereco.trim().isEmpty
      ? 'Não tenho o endereço aproximado'
      : 'Você está perto de ${local.endereco.trim()}';
  final aviso = local.aviso.trim().isEmpty ? '' : ' ${local.aviso.trim()}';
  return '$onde. Coordenadas ${local.coordenadas}, ${local.precisaoRotulo}, '
      '${local.fonteRotulo} (${local.idadeRotulo}).$aviso';
}
