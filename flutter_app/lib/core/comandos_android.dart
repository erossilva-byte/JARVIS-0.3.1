/// Registro e interpretação local dos comandos Android de baixo risco.
///
/// Este arquivo não depende de Flutter: o interpretador pode ser testado sem emulador. A execução
/// nativa fica em `services/comandos_android_service.dart`; aqui só se decide o que foi pedido,
/// com qual risco e qual permissão. Comando não reconhecido devolve `null` e segue para a conversa.
library;

enum RiscoComando { baixo, medio, alto }

class AcaoAndroid {
  const AcaoAndroid({
    required this.nome,
    required this.descricao,
    required this.exemplo,
    required this.risco,
    required this.permissao,
  });

  final String nome;
  final String descricao;
  final String exemplo;
  final RiscoComando risco;
  final String permissao;
}

const acoesAndroid = <AcaoAndroid>[
  AcaoAndroid(
    nome: 'lanterna',
    descricao: 'Liga, desliga ou alterna a lanterna e confirma o estado real.',
    exemplo: 'ligar a lanterna',
    risco: RiscoComando.baixo,
    permissao: 'Nenhuma permissão; usa a câmera traseira do aparelho.',
  ),
  AcaoAndroid(
    nome: 'volume',
    descricao:
        'Define ou ajusta o volume de mídia e confirma o valor aplicado.',
    exemplo: 'volume 50',
    risco: RiscoComando.baixo,
    permissao: 'Nenhuma permissão; não altera o modo Não Perturbe.',
  ),
  AcaoAndroid(
    nome: 'abrir_app',
    descricao:
        'Abre um app instalado pelo nome; pede desambiguação se houver mais de um.',
    exemplo: 'abrir WhatsApp',
    risco: RiscoComando.baixo,
    permissao:
        'Visibilidade de pacotes instalados; nenhuma permissão sensível.',
  ),
  AcaoAndroid(
    nome: 'alarme',
    descricao:
        'Abre o alarme do relógio no horário pedido; quem cria o alarme é você, na tela do relógio.',
    exemplo: 'alarme 7:30',
    risco: RiscoComando.baixo,
    permissao: 'Nenhuma permissão; o alarme é confirmado no app do relógio.',
  ),
  AcaoAndroid(
    nome: 'localizacao',
    descricao:
        'Informa onde o aparelho está, com precisão e idade da leitura; o endereço aproximado vem do Android quando disponível.',
    exemplo: 'onde estou',
    risco: RiscoComando.medio,
    permissao: 'Localização (precisa ou aproximada), pedida na hora.',
  ),
];

sealed class ComandoAndroid {
  const ComandoAndroid();
  String get resumo;
}

class ComandoLanterna extends ComandoAndroid {
  const ComandoLanterna(this.ligar);
  final bool? ligar;
  @override
  String get resumo => ligar == null
      ? 'alternar a lanterna'
      : ligar!
          ? 'ligar a lanterna'
          : 'desligar a lanterna';
}

class ComandoVolume extends ComandoAndroid {
  const ComandoVolume({this.percentual, this.delta});
  final int? percentual;
  final int? delta;
  @override
  String get resumo => percentual != null
      ? 'definir o volume em $percentual%'
      : 'ajustar o volume em ${delta! > 0 ? '+' : ''}$delta%';
}

class ComandoAbrirApp extends ComandoAndroid {
  const ComandoAbrirApp(this.nome);
  final String nome;
  @override
  String get resumo => 'abrir o app $nome';
}

class ComandoLocalizacao extends ComandoAndroid {
  const ComandoLocalizacao();
  @override
  String get resumo => 'informar a localização do aparelho';
}

class ComandoAlarme extends ComandoAndroid {
  const ComandoAlarme(this.hora, this.minuto);
  final int hora;
  final int minuto;
  @override
  String get resumo =>
      'abrir o alarme para ${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
}

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final indice = de.indexOf(caractere);
    saida.write(indice < 0 ? caractere : para[indice]);
  }
  return saida.toString();
}

String _limpar(String texto) => _semAcento(texto)
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[?!.]+$'), '')
    .trim();

class InterpretadorComandos {
  const InterpretadorComandos._();

  static final _alarme =
      RegExp(r'\b(?:alarme|despertador)\b.*?\b(\d{1,2})\s*(?::|h)\s*(\d{2})\b');
  static final _volumeNumero = RegExp(r'\bvolume\b.*?\b(\d{1,3})\s*%?');
  static final _volumePorcento =
      RegExp(r'\b(\d{1,3})\s*%\s*(?:de\s+)?volume\b');
  static final _localizacao = RegExp(
      r'^(?:me diga\s+|jarvis,?\s+)?(?:onde (?:eu )?estou(?: agora)?|'
      r'qual (?:e )?(?:a )?minha localizacao(?: atual)?|'
      r'minha localizacao(?: atual)?|localizacao(?: atual)?)$');

  // "abra", "abri" e "abram" faltavam: "Abra o WhatsApp" (a forma que o
  // reconhecimento de voz devolve) caía na conversa e o modelo respondia com
  // instruções em vez de abrir o app.
  static final _abrir = RegExp(
      r'^(?:abrir|abre|abra|abri|abram|iniciar|inicie|executar|execute)\s+'
      r'(?:o\s+|a\s+|os\s+|as\s+|um\s+|uma\s+)?'
      r'(?:app\s+(?:do\s+|da\s+)?)?(.+)$');

  /// Nome dito → pacote conhecido. Vale mesmo quando o rótulo do app é outro
  /// ("zap" abre o WhatsApp) e quando o Android esconde o rótulo.
  static const pacotesConhecidos = <String, String>{
    'zap': 'com.whatsapp',
    'whats': 'com.whatsapp',
    'whatsapp': 'com.whatsapp',
    'wpp': 'com.whatsapp',
    'whatsapp business': 'com.whatsapp.w4b',
    'wpp business': 'com.whatsapp.w4b',
    'insta': 'com.instagram.android',
    'instagram': 'com.instagram.android',
    'telegram': 'org.telegram.messenger',
    'youtube': 'com.google.android.youtube',
    'you tube': 'com.google.android.youtube',
    'spotify': 'com.spotify.music',
    'gmail': 'com.google.android.gm',
    'maps': 'com.google.android.apps.maps',
    'mapa': 'com.google.android.apps.maps',
    'mapas': 'com.google.android.apps.maps',
    'facebook': 'com.facebook.katana',
    'face': 'com.facebook.katana',
    'messenger': 'com.facebook.orca',
    'discord': 'com.discord',
    'signal': 'org.thoughtcrime.securesms',
    'ifood': 'br.com.brainweb.ifood',
    'uber': 'com.ubercab',
    'waze': 'com.waze',
  };

  static ComandoAndroid? interpretar(String texto) {
    final original = texto.trim();
    final limpo = _limpar(original);
    if (limpo.isEmpty) return null;

    final alarme = _alarme.firstMatch(limpo);
    if (alarme != null) {
      final hora = int.parse(alarme.group(1)!);
      final minuto = int.parse(alarme.group(2)!);
      if (hora <= 23 && minuto <= 59) return ComandoAlarme(hora, minuto);
    }

    if (RegExp(r'\blanterna\b').hasMatch(limpo) &&
        !limpo.contains('como ') &&
        !limpo.contains('por que')) {
      if (RegExp(
              r'\b(desligar|desliga|desligue|apagar|apaga|apague|desativar|desativa|desative)\b')
          .hasMatch(limpo)) {
        return const ComandoLanterna(false);
      }
      if (RegExp(
              r'\b(ligar|liga|ligue|acender|acende|acenda|ativar|ativa|ative)\b')
          .hasMatch(limpo)) {
        return const ComandoLanterna(true);
      }
      if (RegExp(r'^(a |minha )?lanterna$').hasMatch(limpo)) {
        return const ComandoLanterna(null);
      }
    }

    final numero =
        _volumeNumero.firstMatch(limpo) ?? _volumePorcento.firstMatch(limpo);
    if (numero != null) {
      final valor = int.parse(numero.group(1)!);
      if (valor <= 100) return ComandoVolume(percentual: valor);
    }
    if (!limpo.contains('como ') && !limpo.contains('por que')) {
      if (RegExp(r'\b(aumentar|aumenta|aumente|subir|sobe|suba)\b.*\bvolume\b')
          .hasMatch(limpo)) {
        return const ComandoVolume(delta: 10);
      }
      if (RegExp(
              r'\b(diminuir|diminui|diminua|baixar|baixa|abaixar|abaixa|abaixe)\b.*\bvolume\b')
          .hasMatch(limpo)) {
        return const ComandoVolume(delta: -10);
      }
      if (RegExp(r'\b(silenciar|mudo|mutar)\b').hasMatch(limpo) &&
          limpo.length <= 24) {
        return const ComandoVolume(percentual: 0);
      }
    }

    // Localização só em pedido direto; pergunta com "como" ou "por que" segue para a conversa.
    if (!limpo.contains('como ') && !limpo.contains('por que') &&
        _localizacao.hasMatch(limpo)) {
      return const ComandoLocalizacao();
    }

    final abrir = _abrir.firstMatch(limpo);
    if (abrir != null) {
      final nome = abrir.group(1)!.trim();
      if (nome.isEmpty) return null;
      for (final proibido in [
        'arquivo',
        'pasta',
        'conversa',
        'memoria',
        'configuracoes',
        'ajustes',
        'cad',
      ]) {
        if (nome == proibido || nome.startsWith('$proibido ')) return null;
      }
      // O nome do app volta sem acento e em minúsculas; o Android compara sem
      // diferenciar caixa e conhece os apelidos (zap, insta, waze…).
      return ComandoAbrirApp(nome);
    }
    return null;
  }
}
