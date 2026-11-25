// Protocolo jarvis/2 — regras puras e rota de comando do celular.
//
// Roda com `dart run tool/comando_remoto_test.dart` (sem Flutter): o serviço de
// pareamento é Dart puro, então o canal pode ser provado fora da interface.
import 'dart:convert';
import 'dart:io';

import 'package:jarvis_nova/core/comando_remoto.dart';
import 'package:jarvis_nova/core/pareamento.dart';
import 'package:jarvis_nova/services/pareamento_service.dart';

var falhas = 0;

void confere(bool ok, String descricao) {
  if (!ok) {
    falhas += 1;
    stdout.writeln('FALHA: $descricao');
  } else {
    stdout.writeln('ok: $descricao');
  }
}

var _contador = 0;

/// 32 hex diferentes a cada chamada: id repetido é recusado de propósito, então
/// o teste precisa de valores novos para cada pedido.
String id16() {
  _contador += 1;
  final corpo = List<int>.generate(14, (i) => (i * 7 + _contador) % 256)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return corpo + _contador.toRadixString(16).padLeft(4, '0');
}

Map<String, Object?> pedido({
  String acao = 'abrir_tela',
  String tela = 'memoria',
  String? id,
  DateTime? quando,
  String protocolo = protocoloAtual,
}) =>
    {
      'protocolo': protocolo,
      'id': id ?? id16(),
      'emitidoEm': (quando ?? DateTime.now()).toUtc().toIso8601String(),
      'acao': acao,
      'argumentos': {'tela': tela},
    };

Future<Map<String, Object?>> chamar(
  int porta,
  String caminho, {
  String metodo = 'GET',
  String? token,
  Object? corpo,
}) async {
  final cliente = HttpClient();
  try {
    final alvo = Uri.parse('http://127.0.0.1:$porta$caminho');
    final pedido = await cliente.openUrl(metodo, alvo);
    if (token != null) pedido.headers.set('Authorization', 'Bearer $token');
    if (corpo != null) {
      pedido.headers.contentType = ContentType.json;
      pedido.write(jsonEncode(corpo));
    }
    final resposta = await pedido.close();
    final texto = await resposta.transform(utf8.decoder).join();
    final lido = jsonDecode(texto);
    return {'status': resposta.statusCode, 'corpo': lido is Map ? lido : <String, Object?>{}};
  } finally {
    cliente.close(force: true);
  }
}

Future<void> main() async {
  // 1. Negociação: celular novo anuncia, celular antigo não quebra o PC.
  confere(protocoloAtual == 'jarvis/2', 'protocolo atual é jarvis/2');
  confere(
    negociacao(comando: true)['recursos'].toString() == '[status, comando]',
    'comando ligado anuncia status e comando',
  );
  confere(
    negociacao(comando: false)['recursos'].toString() == '[status]',
    'sem comando anuncia só status',
  );
  final antigo = lerNegociacao({'nome': 'Celular 1.108', 'desafio': 'x'});
  confere(antigo.protocolo == protocoloLegado, 'sem negociação vira jarvis/1');
  confere(antigo.recursos.length == 1 && antigo.recursos.first == 'status',
      'sem negociação só tem o recurso status');
  final mentiroso = lerNegociacao({'protocolo': 'jarvis/1', 'recursos': ['comando']});
  confere(!aceitaComando(mentiroso), 'protocolo 1 não ganha comando por anunciar');
  final extra = lerNegociacao({'protocolo': 'jarvis/2', 'recursos': ['comando', 'admin']});
  confere(extra.recursos.toString() == '[status, comando]', 'recurso desconhecido é descartado');

  // 2. Validação do envelope: cada recusa com motivo e código.
  final agora = DateTime.now().toUtc();
  final semVistos = <String>{};
  confere(validarComando(pedido(), agora: agora, idsUsados: semVistos).ok, 'envelope bom passa');
  confere(
    validarComando(pedido(protocolo: 'jarvis/1'), agora: agora, idsUsados: semVistos).codigoHttp == 400,
    'protocolo errado recusa com 400',
  );
  confere(
    validarComando({'protocolo': protocoloAtual, 'id': 'curto'}, agora: agora, idsUsados: semVistos).codigoHttp == 400,
    'id curto recusa com 400',
  );
  confere(
    validarComando(pedido(quando: agora.subtract(const Duration(seconds: 90))), agora: agora, idsUsados: semVistos).codigoHttp == 409,
    'fora do prazo recusa com 409',
  );
  final repetido = pedido();
  final idUsado = (repetido['id'] as String);
  final jaFoi = validarComando(repetido, agora: agora, idsUsados: {idUsado});
  confere(jaFoi.codigoHttp == 409 && jaFoi.erro.contains('já foi executado'),
      'id repetido recusa com 409');
  confere(
    validarComando(pedido(acao: 'apagar_tudo'), agora: agora, idsUsados: semVistos).codigoHttp == 422,
    'ação fora da lista recusa com 422',
  );
  confere(
    validarComando(pedido(tela: 'configuracoes'), agora: agora, idsUsados: semVistos).codigoHttp == 422,
    'tela fora da lista recusa com 422',
  );
  final foraDoRelogio = validarComando(
    pedido(quando: agora.add(const Duration(seconds: 45))),
    agora: agora,
    idsUsados: semVistos,
  );
  confere(foraDoRelogio.ok, 'folga de relógio de 45 s ainda passa');

  // 3. Registro de comandos: não repete e não vira rajada.
  final registro = RegistroDeComandos(intervaloMinimo: const Duration(milliseconds: 50));
  final t0 = DateTime.now();
  confere(registro.podeExecutar(t0), 'primeiro comando no ritmo');
  registro.registrar('a' * 32, t0);
  confere(!registro.podeExecutar(t0), 'dois no mesmo instante: o segundo espera');
  confere(registro.podeExecutar(t0.add(const Duration(seconds: 1))), 'depois de 1 s volta a aceitar');
  for (var i = 0; i < comandosPorMinuto; i++) {
    registro.registrar(List.filled(32, 'b').join() + i.toString().padLeft(2, '0'),
        t0.add(Duration(seconds: 2 + i)));
  }
  confere(
    !registro.podeExecutar(t0.add(Duration(seconds: 2 + comandosPorMinuto + 1))),
    'mais de $comandosPorMinuto por minuto barra',
  );

  // 4. Rota de comando de verdade, com o serviço real em 127.0.0.1.
  final executados = <String>[];
  final servico = PareamentoService(
    porta: 0,
    nome: 'Celular de teste',
    versao: '1.109.0',
    status: () async => {'bateria': 50},
    executarComando: (comando) async {
      executados.add('${comando.acao}:${comando.argumento}');
      return 'abri ${comando.argumento}';
    },
  );
  final porta = await servico.iniciar();
  try {
    final oferta = await servico.abrirOferta();
    final info = await chamar(porta, '/jarvis/info');
    final dadosInfo = info['corpo'] as Map<String, Object?>;
    confere(info['status'] == 200, 'info responde 200');
    confere(dadosInfo['protocolo'] == 'jarvis/2', 'info anuncia protocolo 2');
    confere(dadosInfo['recursos'].toString() == '[status, comando]', 'info anuncia comando');

    final pareou = await chamar(porta, '/jarvis/parear',
        metodo: 'POST',
        corpo: {'dispositivo': 'PC de teste', 'prova': provaDePareamento(oferta.codigo, oferta.desafio)});
    final token = (pareou['corpo'] as Map)['token'].toString();

    final semToken = await chamar(porta, '/jarvis/comando', metodo: 'POST', corpo: pedido());
    confere(semToken['status'] == 401, 'comando sem token responde 401');

    final ok1 = await chamar(porta, '/jarvis/comando', metodo: 'POST', token: token, corpo: pedido());
    confere(ok1['status'] == 200, 'comando com token responde 200');
    confere((ok1['corpo'] as Map)['resultado'] == 'abri memoria', 'devolve o que a tela fez');
    confere(executados.toString() == '[abrir_tela:memoria]', 'a tela executou uma vez');

    final repetidoDeNovo = await chamar(porta, '/jarvis/comando',
        metodo: 'POST', token: token, corpo: pedido(id: (ok1['corpo'] as Map)['id'].toString()));
    confere(repetidoDeNovo['status'] == 409, 'mesmo id responde 409');

    final acaoRuim = await chamar(porta, '/jarvis/comando',
        metodo: 'POST', token: token, corpo: pedido(acao: 'formatar'));
    confere(acaoRuim['status'] == 422, 'ação desconhecida responde 422');

    // Ritmo: a segunda chamada em menos de 1 s é barrada.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await chamar(porta, '/jarvis/comando', metodo: 'POST', token: token, corpo: pedido(tela: 'pessoas'));
    final rajada = await chamar(porta, '/jarvis/comando',
        metodo: 'POST', token: token, corpo: pedido(tela: 'visao'));
    confere(rajada['status'] == 429, 'rajada responde 429');

    final revogado = await chamar(porta, '/jarvis/esquecer', metodo: 'POST', token: token);
    confere(revogado['status'] == 200, 'esquecer revoga');
    final depois = await chamar(porta, '/jarvis/comando', metodo: 'POST', token: token, corpo: pedido());
    confere(depois['status'] == 401, 'token revogado não executa');
  } finally {
    await servico.fechar();
  }

  // 5. Serviço sem executor: continua só de leitura e o PC é avisado.
  final soLeitura = PareamentoService(porta: 0, nome: 'Celular antigo');
  final portaLenta = await soLeitura.iniciar();
  try {
    final oferta = await soLeitura.abrirOferta();
    final info = await chamar(portaLenta, '/jarvis/info');
    confere(
      ((info['corpo'] as Map)['recursos'] as List).toString() == '[status]',
      'sem executor o celular anuncia só status',
    );
    final pareou = await chamar(portaLenta, '/jarvis/parear',
        metodo: 'POST',
        corpo: {'dispositivo': 'PC', 'prova': provaDePareamento(oferta.codigo, oferta.desafio)});
    final token = (pareou['corpo'] as Map)['token'].toString();
    final recusa = await chamar(portaLenta, '/jarvis/comando', metodo: 'POST', token: token, corpo: pedido());
    confere(recusa['status'] == 409, 'sem executor a rota responde 409 explicado');
    confere(
      (recusa['corpo'] as Map)['erro'].toString().contains('só de leitura'),
      'a recusa diz que é canal de leitura',
    );
  } finally {
    await soLeitura.fechar();
  }

  if (falhas > 0) {
    stdout.writeln('\n$falhas falha(s) no protocolo jarvis/2.');
    exit(1);
  }
  stdout.writeln('\ncomando_remoto: protocolo jarvis/2 — negociação, envelope, registro e rota — OK');
}
