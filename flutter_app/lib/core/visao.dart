/// Visão de imagem na interface Flutter — contrato puro, sem rede e sem Flutter.
///
/// A regra desta fase: a imagem é escolhida pelo usuário, enviada só depois de autorização
/// explícita e analisada apenas pelo que está visível. Não há reconhecimento facial, identificação
/// de pessoas nem armazenamento da imagem pelo app.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Limite do que sai do aparelho numa análise. Imagem maior é recusada antes de qualquer envio.
const limiteBytesVisao = 4 * 1024 * 1024;

const mimesVisao = <String>['image/jpeg', 'image/png', 'image/webp'];

class ImagemParaAnalise {
  const ImagemParaAnalise(
      {required this.bytes, required this.mime, this.nome = 'imagem'});

  final Uint8List bytes;
  final String mime;
  final String nome;

  int get tamanho => bytes.length;
}

class ProvedorVisao {
  const ProvedorVisao({
    required this.id,
    required this.nome,
    required this.endpoint,
    required this.modelo,
    this.modelosAlternativos = const [],
  });

  final String id;
  final String nome;
  final String endpoint;
  final String modelo;

  /// Nomes tentados somente quando o principal responde 404. O Google aposenta
  /// modelos para chaves novas, e o 404 é o aviso de que o nome mudou; a chave
  /// continua a mesma.
  final List<String> modelosAlternativos;

  /// Ordem de tentativa, do principal ao último alternativo.
  List<String> get modelos => [modelo, ...modelosAlternativos];
}

/// Provedores com modelo que aceita imagem, na ordem de preferência da visão.
///
/// Groq segue como principal na conversa, mas o modelo de texto não enxerga; por isso a visão tem
/// a própria ordem e nunca cai num modelo textual só para "ter resposta".
const provedoresVisao = <ProvedorVisao>[
  ProvedorVisao(
    id: 'gemini',
    nome: 'Gemini 2.5 Flash',
    endpoint:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    modelo: 'gemini-2.5-flash',
    modelosAlternativos: ['gemini-2.0-flash', 'gemini-flash-latest'],
  ),
  ProvedorVisao(
    id: 'groq',
    nome: 'Groq · Llama 4 Scout',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    modelo: 'meta-llama/llama-4-scout-17b-16e-instruct',
    modelosAlternativos: ['meta-llama/llama-4-maverick-17b-128e-instruct'],
  ),
  ProvedorVisao(
    id: 'mistral',
    nome: 'Mistral · Pixtral',
    endpoint: 'https://api.mistral.ai/v1/chat/completions',
    modelo: 'pixtral-12b-2409',
    modelosAlternativos: ['pixtral-large-latest'],
  ),
  ProvedorVisao(
    id: 'openrouter',
    nome: 'OpenRouter · Gemini',
    endpoint: 'https://openrouter.ai/api/v1/chat/completions',
    modelo: 'google/gemini-2.5-flash',
    modelosAlternativos: ['google/gemini-2.0-flash-001'],
  ),
];

/// Explicação do que o provedor recusou, já sem chave e sem corpo bruto.
///
/// O 404 é o caso do modelo aposentado para a chave: não é culpa da credencial,
/// então a mensagem precisa dizer isso em vez de "falha desconhecida".
String mensagemErroVisao({
  required int status,
  required String provedor,
  required String modelo,
}) =>
    switch (status) {
      401 || 403 =>
        'O provedor $provedor recusou a chave. Confira a credencial em Provedores de IA.',
      404 =>
        'O modelo $modelo do $provedor não está disponível para esta chave (HTTP 404). '
            'O catálogo do app pode estar desatualizado; tente de novo ou cadastre outra chave '
            'com visão.',
      413 => 'A imagem é grande demais para o $provedor. Escolha uma menor.',
      429 =>
        'O $provedor está no limite de requisições. Aguarde alguns instantes e tente de novo.',
      >= 500 => 'O serviço do $provedor está instável. Tente novamente mais tarde.',
      _ => 'O $provedor não concluiu a análise (HTTP $status).',
    };

/// Instrução fixa. O usuário pode perguntar algo, mas nunca desbloqueia identificação de pessoas.
const instrucaoVisao =
    'Analise somente o que está visível na imagem enviada pelo próprio usuário. '
    'Descreva objetos, cena, cores e textos legíveis; diga quando algo estiver borrado, cortado ou '
    'incerto, em vez de adivinhar. Não identifique pessoas, não faça reconhecimento facial e não '
    'estime idade, emoção, saúde, deficiência, etnia, religião, orientação sexual ou qualquer '
    'atributo sensível. Não deduza localização, documento, placa ou dado pessoal: se aparecer, '
    'ignore e avise que não trata disso. Não invente o que não está na imagem e não afirme ter '
    'executado ações.'
    '\n\nResponda em JSON válido, sem cercas de código, neste formato: '
    '{"summary":"frase curta","objects":[{"label":"objeto","confidence":0.0,'
    '"bbox":[0.0,0.0,0.0,0.0]}],"text":["texto legível"]}. '
    'bbox é [x,y,w,h] normalizado de 0 a 1. Se não houver objetos ou texto, use listas vazias. '
    'Para qualquer pessoa, use somente o rótulo "Pessoa"; não descreva rosto, idade, gênero, '
    'emoção ou identidade.';

String montarPedidoVisao(String pergunta) {
  final limpa = pergunta.trim();
  if (limpa.isEmpty) return instrucaoVisao;
  return '$instrucaoVisao\n\nPedido do usuário sobre a imagem: $limpa';
}

/// Devolve a mensagem de recusa, ou nulo quando a imagem pode ser enviada.
String? validarImagemVisao(Uint8List bytes, String mime) {
  if (bytes.isEmpty) return 'A imagem está vazia. Escolha outro arquivo.';
  if (bytes.length > limiteBytesVisao) {
    return 'A imagem tem ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB. '
        'O limite é 4 MB; escolha uma imagem menor.';
  }
  if (!mimesVisao.contains(mime.toLowerCase())) {
    return 'Formato não aceito para análise. Use JPEG, PNG ou WebP.';
  }
  return null;
}

/// Corpo no formato OpenAI-compatible, aceito pelos provedores com visão.
Map<String, Object?> montarCorpoVisao({
  required String modelo,
  required ImagemParaAnalise imagem,
  String pergunta = '',
}) =>
    {
      'model': modelo,
      'temperature': 0.2,
      'max_tokens': 700,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': montarPedidoVisao(pergunta)},
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${imagem.mime};base64,${base64Encode(imagem.bytes)}',
              },
            },
          ],
        },
      ],
    };

/// Lê o texto da resposta. Aceita `content` como string ou como lista de partes.
String? extrairTextoVisao(String corpo) {
  try {
    final dados = jsonDecode(corpo);
    if (dados is! Map) return null;
    final escolhas = dados['choices'];
    if (escolhas is! List || escolhas.isEmpty) return null;
    final primeira = escolhas.first;
    if (primeira is! Map) return null;
    final mensagem = primeira['message'];
    if (mensagem is! Map) return null;
    final conteudo = mensagem['content'];
    if (conteudo is String) {
      final texto = conteudo.trim();
      return texto.isEmpty ? null : texto;
    }
    if (conteudo is List) {
      final partes = <String>[];
      for (final parte in conteudo) {
        if (parte is Map &&
            parte['type'] == 'text' &&
            parte['text'] is String) {
          final texto = (parte['text'] as String).trim();
          if (texto.isNotEmpty) partes.add(texto);
        }
      }
      return partes.isEmpty ? null : partes.join('\n');
    }
    return null;
  } catch (_) {
    return null;
  }
}
