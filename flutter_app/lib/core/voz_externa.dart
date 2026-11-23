/// Voz externa por ID — contrato puro, sem Flutter e sem rede.
///
/// A voz de resposta do app é a do aparelho, ajustada por tom e ritmo. Um *ID
/// de voz* só tem efeito quando existe um serviço de voz remota: aqui o serviço
/// é o **Fish Audio**, e o ID é o `reference_id` da voz escolhida. Este arquivo
/// guarda o ID padrão, valida o formato, monta o endereço e o corpo do pedido —
/// quem fala com a rede é `voz_externa_service.dart`, e quem toca o áudio é o
/// canal de voz do Android.
///
/// Sem chave configurada nada é gerado: a tela diz que falta a chave e a voz do
/// aparelho continua valendo. O ID sozinho não fala.
library;

/// ID de voz do Fish Audio pedido pelo usuário e adotado como padrão.
const idVozPadrao = '82d13948027e4be69892dd3d0104e681';

/// Serviço que usa ID de voz neste formato.
const nomeServicoVoz = 'Fish Audio';

/// Endereço de síntese do Fish Audio.
const enderecoVozExterna = 'https://api.fish.audio/v1/tts';

/// Formato de saída: MP3 — o que o Android toca sem conversão.
const formatoVozPadrao = 'mp3';

/// Aceita IDs alfanuméricos de 16 a 40 caracteres, com hífen e sublinhado.
///
/// O ID do Fish Audio tem 32 caracteres hexadecimais. O app não adivinha o
/// serviço pelo formato — só recusa o que não pode ser ID.
bool idVozValido(String? id) {
  final limpo = (id ?? '').trim();
  return RegExp(r'^[A-Za-z0-9_-]{16,40}$').hasMatch(limpo);
}

/// ID normalizado: sem espaço nas pontas; vazio ou inválido cai no padrão.
String normalizarIdVoz(String? id) {
  final limpo = (id ?? '').trim();
  return idVozValido(limpo) ? limpo : idVozPadrao;
}

/// Endereço do pedido de síntese. O ID vai no corpo, não na URL.
String urlVozExterna() => enderecoVozExterna;

/// Corpo do pedido: texto, voz e formato. Nada além do texto sai do aparelho.
Map<String, Object> corpoVozExterna(
  String texto, {
  String id = idVozPadrao,
}) =>
    {
      'text': texto.trim(),
      'reference_id': normalizarIdVoz(id),
      'format': formatoVozPadrao,
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
  'O texto da resposta sai do aparelho e vai para o $nomeServicoVoz: é o '
      'contrário da voz local, que nunca sai daqui.',
  'Precisa de internet e da chave do serviço; o ID sozinho não fala nada.',
  'Cada resposta consome cota do serviço — a fatura é sua, não do app.',
  'O áudio é tocado pelo MediaPlayer do Android; se a rede falhar, o app volta '
      'para a voz do aparelho em vez de ficar mudo.',
  'O ID não é segredo, mas a chave é: ela fica no cofre do aparelho e nunca '
      'volta para a tela.',
];
