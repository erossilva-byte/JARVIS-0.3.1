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

/// Recusa de um modelo específico. O status 0 marca resposta que chegou mas não
/// pôde ser lida (formato desconhecido), que também vale tentar outro modelo.
class _RecusaModelo implements Exception {
  const _RecusaModelo(this.status, this.mensagem);

  final int status;
  final String mensagem;
}

/// Envia a imagem ao primeiro provedor com visão que tenha chave no cofre seguro.
///
/// A chave nunca sai daqui; a imagem não é gravada e só é enviada quando [analisar] é chamado.
/// Quando o modelo principal responde 404 (modelo aposentado para aquela chave) o serviço tenta
/// os modelos alternativos do mesmo provedor e, se nenhum responder, o próximo provedor com
/// chave cadastrada. Uma recusa de credencial (401/403) interrompe: trocar de modelo não
/// conserta chave recusada, e insistir só gastaria tempo.
class VisaoService implements AnalisadorVisao {
  VisaoService({required SecretStore secrets, http.Client? client})
      : _secrets = secrets,
        _client = client ?? http.Client();

  final SecretStore _secrets;
  final http.Client _client;

  Future<List<({ProvedorVisao provedor, String chave})>> _configurados() async {
    final lista = <({ProvedorVisao provedor, String chave})>[];
    for (final provedor in provedoresVisao) {
      final chave = await _secrets.read(provedor.id);
      if (chave != null && chave.isNotEmpty) {
        lista.add((provedor: provedor, chave: chave));
      }
    }
    return lista;
  }

  @override
  Future<String?> provedorAtual() async {
    for (final provedor in provedoresVisao) {
      final chave = await _secrets.read(provedor.id);
      if (chave != null && chave.isNotEmpty) return provedor.nome;
    }
    return null;
  }

  Future<String> _enviar({
    required ProvedorVisao provedor,
    required String chave,
    required String modelo,
    required ImagemParaAnalise imagem,
    required String pergunta,
  }) async {
    final resposta = await _client
        .post(
          Uri.parse(provedor.endpoint),
          headers: {'Authorization': 'Bearer $chave', 'Content-Type': 'application/json'},
          body: jsonEncode(montarCorpoVisao(
            modelo: modelo,
            imagem: imagem,
            pergunta: pergunta,
          )),
        )
        .timeout(const Duration(seconds: 60));

    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw _RecusaModelo(
        resposta.statusCode,
        mensagemErroVisao(
          status: resposta.statusCode,
          provedor: provedor.nome,
          modelo: modelo,
        ),
      );
    }

    final texto = extrairTextoVisao(resposta.body);
    if (texto == null) {
      throw _RecusaModelo(
        0,
        'O modelo $modelo do ${provedor.nome} respondeu num formato que o app não reconhece. '
        'Tente de novo ou cadastre outro provedor com visão.',
      );
    }
    return texto;
  }

  @override
  Future<String> analisar({required ImagemParaAnalise imagem, String pergunta = ''}) async {
    final erro = validarImagemVisao(imagem.bytes, imagem.mime);
    if (erro != null) throw StateError(erro);

    final configurados = await _configurados();
    if (configurados.isEmpty) {
      throw StateError(
        'Nenhum provedor com visão está configurado. Cadastre a chave do Gemini, Groq, Mistral '
        'ou OpenRouter em Provedores de IA.',
      );
    }

    String? ultimoProblema;
    for (final item in configurados) {
      for (final modelo in item.provedor.modelos) {
        try {
          return await _enviar(
            provedor: item.provedor,
            chave: item.chave,
            modelo: modelo,
            imagem: imagem,
            pergunta: pergunta,
          );
        } on _RecusaModelo catch (recusa) {
          ultimoProblema = recusa.mensagem;
          if (recusa.status == 401 || recusa.status == 403) {
            throw StateError(recusa.mensagem);
          }
        } on TimeoutException {
          ultimoProblema = 'A análise excedeu 60 segundos e foi interrompida.';
        } on http.ClientException {
          ultimoProblema =
              'Não foi possível alcançar o provedor. Verifique a conexão.';
        }
      }
    }
    throw StateError(
      ultimoProblema ??
          'Nenhum provedor com visão concluiu a análise. Tente de novo em instantes.',
    );
  }

  @override
  void fechar() => _client.close();
}
