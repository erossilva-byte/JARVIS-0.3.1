import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jarvis_nova/core/visao.dart';

ImagemParaAnalise _imagem([String mime = 'image/png']) => ImagemParaAnalise(
      bytes: Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]),
      mime: mime,
      nome: 'teste.png',
    );

void main() {
  // 1. Validação recusa antes de qualquer envio.
  assert(validarImagemVisao(Uint8List(0), 'image/png') != null, 'imagem vazia aceita');
  assert(
    validarImagemVisao(Uint8List(limiteBytesVisao + 1), 'image/png')!.contains('4 MB'),
    'imagem acima do limite aceita',
  );
  assert(validarImagemVisao(Uint8List.fromList([1]), 'image/heic') != null, 'HEIC aceito sem suporte');
  assert(validarImagemVisao(Uint8List.fromList([1]), 'image/png') == null, 'PNG válido recusado');
  for (final mime in mimesVisao) {
    assert(validarImagemVisao(Uint8List.fromList([1]), mime) == null, '$mime deveria ser aceito');
  }

  // 2. Instrução proíbe identificação mesmo quando o usuário pede.
  assert(instrucaoVisao.contains('Não identifique pessoas'), 'prompt não proíbe identificar pessoas');
  assert(instrucaoVisao.contains('reconhecimento facial'), 'prompt não proíbe reconhecimento facial');
  assert(instrucaoVisao.toLowerCase().contains('não invente'), 'prompt não proíbe invenção');
  assert(instrucaoVisao.contains('incerto'), 'prompt não manda dizer quando é incerto');
  final pedido = montarPedidoVisao('identifique a pessoa da foto');
  assert(pedido.contains('Não identifique pessoas'), 'pedido do usuário removeu a proibição');
  assert(pedido.contains('identifique a pessoa da foto'), 'pedido do usuário não foi anexado');
  assert(!montarPedidoVisao('  ').contains('Pedido do usuário'), 'pergunta vazia virou pedido');

  // 3. Corpo no formato multimodal, com a imagem em data URL.
  final corpo = montarCorpoVisao(modelo: 'modelo-visao', imagem: _imagem(), pergunta: 'o que é isso?');
  assert(corpo['model'] == 'modelo-visao', 'modelo não entrou no corpo');
  final mensagens = corpo['messages'] as List;
  final conteudo = (mensagens.single as Map)['content'] as List;
  assert(conteudo.length == 2, 'conteúdo deveria ter texto e imagem');
  assert((conteudo[0] as Map)['type'] == 'text', 'primeira parte não é texto');
  final url = ((conteudo[1] as Map)['image_url'] as Map)['url'] as String;
  assert(url.startsWith('data:image/png;base64,'), 'data URL sem MIME');
  assert(base64Decode(url.split(',').last).length == _imagem().bytes.length, 'base64 não corresponde');

  // 4. Leitura da resposta aceita string e lista de partes.
  final string = extrairTextoVisao(jsonEncode({
    'choices': [
      {
        'message': {'content': ' Uma caneca sobre a mesa. '}
      }
    ]
  }));
  assert(string == 'Uma caneca sobre a mesa.', 'resposta em string não lida');
  final lista = extrairTextoVisao(jsonEncode({
    'choices': [
      {
        'message': {
          'content': [
            {'type': 'text', 'text': 'Primeira linha.'},
            {'type': 'text', 'text': 'Segunda linha.'},
          ]
        }
      }
    ]
  }));
  assert(lista == 'Primeira linha.\nSegunda linha.', 'resposta em lista não lida');
  assert(extrairTextoVisao('{"choices":[]}') == null, 'resposta vazia deveria ser nula');
  assert(extrairTextoVisao('não é json') == null, 'json inválido deveria ser nulo');
  assert(
    extrairTextoVisao(jsonEncode({
      'choices': [
        {
          'message': {'content': '   '}
        }
      ]
    })) == null,
    'texto em branco deveria ser nulo',
  );

  // 5. Provedores de visão não caem em modelo textual.
  assert(provedoresVisao.length >= 3, 'poucos provedores de visão');
  for (final provedor in provedoresVisao) {
    assert(provedor.endpoint.startsWith('https://'), 'endpoint sem HTTPS');
    assert(!provedor.modelo.contains('deepseek'), 'modelo textual DeepSeek na visão');
    assert(!provedor.modelo.contains('gpt-oss'), 'modelo textual gpt-oss na visão');
  }

  // 6. Modelo aposentado (HTTP 404) tem plano B: outros nomes e outro provedor.
  final gemini = provedoresVisao.firstWhere((p) => p.id == 'gemini');
  assert(gemini.modelo == 'gemini-2.5-flash', 'modelo principal do Gemini mudou sem prova');
  assert(gemini.modelos.length >= 3, 'Gemini sem modelos alternativos para o 404');
  assert(gemini.modelos.first == gemini.modelo, 'principal não é o primeiro tentado');
  assert(gemini.modelos.toSet().length == gemini.modelos.length, 'modelo repetido na lista');
  assert(gemini.modelos.contains('gemini-flash-latest'), 'sem alias estável do Google');
  for (final provedor in provedoresVisao) {
    assert(provedor.modelos.isNotEmpty, '${provedor.nome} sem nenhum modelo');
  }
  assert(
    mensagemErroVisao(status: 404, provedor: 'Gemini 2.5 Flash', modelo: 'gemini-2.5-flash')
        .contains('HTTP 404'),
    'erro 404 não é identificado na mensagem',
  );
  assert(
    mensagemErroVisao(status: 404, provedor: 'Gemini 2.5 Flash', modelo: 'm')
        .contains('não está disponível para esta chave'),
    'mensagem de 404 não explica o modelo',
  );
  assert(
    mensagemErroVisao(status: 401, provedor: 'Gemini 2.5 Flash', modelo: 'm')
        .contains('recusou a chave'),
    'mensagem de 401 não aponta a credencial',
  );

  stdout.writeln(
      'OK: visão — validação, prompt sem reconhecimento facial, pedido multimodal, leitura e plano B no 404');
}
