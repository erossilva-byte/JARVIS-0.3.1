import 'dart:convert';
import 'dart:io';

import 'package:jarvis_nova/core/pareamento.dart';
import 'package:jarvis_nova/services/pareamento_service.dart';

/// PC simulado: só fala HTTP com o serviço do celular em 127.0.0.1.
class PcSimulado {
  PcSimulado(this.host, this.porta);

  final String host;
  final int porta;
  final HttpClient _cliente = HttpClient();

  Future<({int codigo, Map<String, dynamic> corpo})> pedir(
    String metodo,
    String caminho, {
    Map<String, Object?>? corpo,
    String? token,
  }) async {
    final pedido = await _cliente.openUrl(
        metodo, Uri.parse('http://$host:$porta$caminho'));
    if (token != null) {
      pedido.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (corpo != null) {
      pedido.headers.contentType = ContentType.json;
      pedido.write(jsonEncode(corpo));
    }
    final resposta = await pedido.close();
    final texto = await utf8.decoder.bind(resposta).join();
    final lido = texto.isEmpty ? const <String, dynamic>{} : jsonDecode(texto);
    return (
      codigo: resposta.statusCode,
      corpo: lido is Map ? Map<String, dynamic>.from(lido) : <String, dynamic>{},
    );
  }

  void fechar() => _cliente.close(force: true);
}

Future<void> main() async {
  var agora = DateTime(2026, 11, 25, 9, 0, 0);
  var leituras = 0;

  final servico = PareamentoService(
    porta: 0,
    nome: 'Celular de teste',
    versao: '1.104.0',
    relogio: () => agora,
    status: () async {
      leituras++;
      return {
        'bateria': 73,
        'carregando': false,
        'ramTotal': 6 * 1024 * 1024 * 1024,
        'ramLivre': 3 * 1024 * 1024 * 1024,
        'sistema': 'Android 14 · teste',
        'conexao': 'Wi-Fi',
      };
    },
  );
  final porta = await servico.iniciar();
  final pc = PcSimulado('127.0.0.1', porta);

  try {
    // 1. Sem oferta, o PC é avisado — não recebe desafio inventado.
    final semOferta = await pc.pedir('GET', '/jarvis/info');
    assert(semOferta.codigo == 409, 'sem oferta deveria ser 409');
    assert(semOferta.corpo['precisaOferta'] == true, 'faltou o aviso de abrir oferta');

    // 2. Oferta aberta: o PC descobre nome e desafio, nunca o código.
    final oferta = await servico.abrirOferta();
    final info = await pc.pedir('GET', '/jarvis/info');
    assert(info.codigo == 200, 'info deveria ser 200: ${info.codigo}');
    assert(info.corpo['nome'] == 'Celular de teste', 'nome do celular errado');
    assert(info.corpo['desafio'] == oferta.desafio, 'desafio diferente do aberto');
    assert(!info.corpo.containsKey('codigo'), 'o código vazou para a rede');
    assert((info.corpo['expiraEmSegundos'] as num) > 60, 'prazo não informado');

    // 3. Código errado é recusado e gasta tentativa.
    final errado = await pc.pedir('POST', '/jarvis/parear', corpo: {
      'dispositivo': 'PC da oficina',
      'prova': provaDePareamento('000000', oferta.desafio),
    });
    assert(errado.codigo == 403, 'código errado deveria ser 403');
    assert(errado.corpo['tentativasRestantes'] == tentativasPareamento - 1,
        'tentativa não foi contada');
    assert(!servico.pareado, 'código errado pareou');

    // 4. Prova certa pareia e devolve o token uma única vez.
    final certo = await pc.pedir('POST', '/jarvis/parear', corpo: {
      'dispositivo': 'PC da oficina',
      'prova': provaDePareamento(oferta.codigo, oferta.desafio),
    });
    assert(certo.codigo == 200, 'pareamento correto falhou: ${certo.codigo}');
    final token = certo.corpo['token'] as String?;
    assert(token != null && token.length == 64, 'token ausente ou curto');
    assert(servico.pareado, 'serviço não registrou o PC');
    assert(servico.oferta == null, 'oferta continuou aberta depois do par');

    // 5. Status é só leitura e exige o token.
    final semToken = await pc.pedir('GET', '/jarvis/status');
    assert(semToken.codigo == 401, 'status sem token deveria ser 401');
    final tokenErrado = await pc.pedir('GET', '/jarvis/status', token: 'f' * 64);
    assert(tokenErrado.codigo == 401, 'token errado aceito');
    final status = await pc.pedir('GET', '/jarvis/status', token: token);
    assert(status.codigo == 200, 'status com token falhou: ${status.codigo}');
    final dados = status.corpo['status'] as Map;
    assert(dados['bateria'] == 73, 'bateria não chegou');
    assert(dados['conexao'] == 'Wi-Fi', 'conexão não chegou');
    assert(leituras == 1, 'status foi lido $leituras vezes, esperado 1');
    final post = await pc.pedir('POST', '/jarvis/status', token: token);
    assert(post.codigo == 404, 'status aceitou POST — canal deveria ser só leitura');

    // 6. Esquecer revoga o token na hora.
    final esqueceu = await pc.pedir('POST', '/jarvis/esquecer', token: token);
    assert(esqueceu.codigo == 200 && esqueceu.corpo['esquecido'] == true,
        'esquecer não confirmou');
    assert(!servico.pareado, 'serviço continuou pareado');
    final depois = await pc.pedir('GET', '/jarvis/status', token: token);
    assert(depois.codigo == 401, 'token sobreviveu ao esquecimento');

    // 7. Oferta expirada não aceita prova certa.
    final nova = await servico.abrirOferta();
    agora = nova.criadoEm.add(const Duration(seconds: validadeOfertaSegundos + 1));
    final expirada = await pc.pedir('POST', '/jarvis/parear', corpo: {
      'dispositivo': 'PC atrasado',
      'prova': provaDePareamento(nova.codigo, nova.desafio),
    });
    assert(expirada.codigo == 410, 'oferta expirada aceitou pareamento');
    assert(!servico.pareado, 'oferta expirada pareou');

    // 8. Cinco erros queimam a oferta: sem força bruta de 6 dígitos.
    final queimada = await servico.abrirOferta();
    for (var i = 0; i < tentativasPareamento; i++) {
      await pc.pedir('POST', '/jarvis/parear', corpo: {
        'dispositivo': 'PC insistente',
        'prova': provaDePareamento('000000', queimada.desafio),
      });
    }
    assert(servico.oferta == null, 'oferta sobreviveu às tentativas');
    final depoisQueima = await pc.pedir('GET', '/jarvis/info');
    assert(depoisQueima.codigo == 409, 'info respondeu com oferta queimada');
    final certaDepois = await pc.pedir('POST', '/jarvis/parear', corpo: {
      'dispositivo': 'PC insistente',
      'prova': provaDePareamento(queimada.codigo, queimada.desafio),
    });
    assert(certaDepois.codigo != 200, 'código certo valeu depois de queimar');

    stdout.writeln('OK: pareamento em rede local — oferta, prova, token, leitura, '
        'esquecimento, expiração e força bruta.');
  } finally {
    pc.fechar();
    await servico.fechar();
  }
}
