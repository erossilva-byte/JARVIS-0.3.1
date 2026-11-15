import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/visao.dart';
import 'provider_service.dart';

abstract interface class AnalisadorVisao {
  /// Nome do provedor que será usado, ou nulo quando nenhum está configurado.
  Future<String?> provedorAtual();

  Future<String> analisar({required ImagemParaAnalise imagem, String pergunta = ''});

  void fechar();
}

/// Envia a imagem ao primeiro provedor com visão que tenha chave no cofre seguro.
///
/// A chave nunca sai daqui; a imagem não é gravada e só é enviada quando [analisar] é chamado.
class VisaoService implements AnalisadorVisao {
  VisaoService({required SecretStore secrets, http.Client? client})
      : _secrets = secrets,
        _client = client ?? http.Client();

  final SecretStore _secrets;
  final http.Client _client;

  Future<ProvedorVisao?> _escolher() async {
    for (final provedor in provedoresVisao) {
      final chave = await _secrets.read(provedor.id);
      if (chave != null && chave.isNotEmpty) return provedor;
    }
    return null;
  }

  @override
  Future<String?> provedorAtual() async => (await _escolher())?.nome;

  @override
  Future<String> analisar({required ImagemParaAnalise imagem, String pergunta = ''}) async {
    final erro = validarImagemVisao(imagem.bytes, imagem.mime);
    if (erro != null) throw StateError(erro);

    final provedor = await _escolher();
    if (provedor == null) {
      throw StateError(
        'Nenhum provedor com visão está configurado. Cadastre a chave do Gemini, Groq, Mistral '
        'ou OpenRouter em Provedores de IA.',
      );
    }
    final chave = await _secrets.read(provedor.id);
    if (chave == null || chave.isEmpty) {
      throw StateError('A chave do provedor ${provedor.nome} não está disponível.');
    }

    try {
      final resposta = await _client
          .post(
            Uri.parse(provedor.endpoint),
            headers: {'Authorization': 'Bearer $chave', 'Content-Type': 'application/json'},
            body: jsonEncode(montarCorpoVisao(
              modelo: provedor.modelo,
              imagem: imagem,
              pergunta: pergunta,
            )),
          )
          .timeout(const Duration(seconds: 60));

      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw StateError(switch (resposta.statusCode) {
          401 || 403 => 'O provedor ${provedor.nome} recusou a chave. Confira a credencial.',
          413 => 'A imagem é grande demais para este provedor. Escolha uma menor.',
          429 => 'Limite de requisições do provedor atingido. Aguarde e tente novamente.',
          >= 500 => 'O serviço do provedor está instável. Tente novamente mais tarde.',
          _ => 'O provedor ${provedor.nome} não concluiu a análise (HTTP ${resposta.statusCode}).',
        });
      }

      final texto = extrairTextoVisao(resposta.body);
      if (texto == null) {
        throw StateError('O provedor respondeu, mas o formato da análise não foi reconhecido.');
      }
      return texto;
    } on TimeoutException {
      throw StateError('A análise excedeu 60 segundos e foi interrompida.');
    } on http.ClientException {
      throw StateError('Não foi possível alcançar o provedor. Verifique a conexão.');
    }
  }

  @override
  void fechar() => _client.close();
}
