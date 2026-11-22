/// Voz externa por ID — contrato puro, sem Flutter e sem rede.
///
/// A voz de resposta do app é a do aparelho, ajustada por tom e ritmo. Um *ID de
/// voz* só tem efeito quando existe um serviço de voz remota: o ID é o nome da
/// voz naquele serviço. Este arquivo guarda o ID escolhido, valida o formato e
/// monta o pedido — quem fala com a rede é `voz_externa_service.dart`, e quem
/// toca o áudio é o canal de voz do Android.
///
/// Sem chave configurada nada é gerado: a tela diz que falta a chave e a voz do
/// aparelho continua valendo. Nenhuma promessa de voz clonada sem o serviço.
library;

/// ID de voz pedido pelo usuário e adotado como padrão da voz externa.
const idVozPadrao = '82d13948027e4be69892dd3d0104e681';

/// Serviço que usa ID de voz neste formato.
const nomeServicoVoz = 'ElevenLabs';

/// Modelo de síntese usado no pedido.
const modeloVozPadrao = 'eleven_multilingual_v2';

/// Formato de saída: MP3 de 44,1 kHz — o que o Android toca sem conversão.
const formatoVozPadrao = 'mp3_44100_128';

/// Aceita IDs alfanuméricos de 16 a 40 caracteres, com hífen e sublinhado.
///
/// Os dois formatos em uso no mercado caem aqui: 20 caracteres alfanuméricos e
/// 32 hexadecimais. O app não adivinha o serviço pelo formato — só recusa o que
/// não pode ser ID.
bool idVozValido(String? id) {
  final limpo = (id ?? '').trim();
  return RegExp(r'^[A-Za-z0-9_-]{16,40}$').hasMatch(limpo);
}

/// ID normalizado: sem espaço nas pontas; vazio ou inválido cai no padrão.
String normalizarIdVoz(String? id) {
  final limpo = (id ?? '').trim();
  return idVozValido(limpo) ? limpo : idVozPadrao;
}

/// Endereço do pedido de síntese para este ID.
String urlVozExterna(String id, {String formato = formatoVozPadrao}) =>
    'https://api.elevenlabs.io/v1/text-to-speech/'
    '${normalizarIdVoz(id)}?output_format=$formato';

/// Corpo do pedido: texto e modelo. Nada além do texto sai do aparelho.
Map<String, Object> corpoVozExterna(String texto,
        {String modelo = modeloVozPadrao}) =>
    {
      'text': texto.trim(),
      'model_id': modelo,
      'voice_settings': {
        'stability': 0.45,
        'similarity_boost': 0.75,
        'style': 0.0,
        'use_speaker_boost': true,
      },
    };

/// Resumo curto para a tela.
String resumoVozExterna(String id,
    {required bool ativa, required bool temChave}) {
  final alvo = normalizarIdVoz(id);
  final estado = !temChave
      ? 'sem chave: a voz do aparelho continua valendo'
      : !ativa
          ? 'pronta, mas desligada'
          : 'ligada para as respostas';
  return 'Voz externa $nomeServicoVoz, ID $alvo — $estado.';
}

/// O que a voz externa custa e o que ela muda. Fica escrito na tela.
const limitesVozExterna = <String>[
  'O texto da resposta sai do aparelho e vai para o serviço de voz: é o '
      'contrário da voz local, que nunca sai daqui.',
  'Precisa de internet e da chave do serviço; o ID sozinho não fala nada.',
  'Cada resposta consome cota do serviço — a fatura é sua, não do app.',
  'O áudio é tocado pelo MediaPlayer do Android; se a rede falhar, o app volta '
      'para a voz do aparelho em vez de ficar mudo.',
  'O ID não é segredo, mas a chave é: ela fica no cofre do aparelho e nunca '
      'volta para a tela.',
];
