import 'dart:io';

import 'package:jarvis_nova/core/historico_voz.dart';

void main() {
  const milissegundos = 1880000000000; // 2029-07-25T22:13:20Z, só para fixar a conta.

  // 1. Registro completo: horário, origem, ação, resultado e mensagem.
  final completoLido = RegistroExecucao.deMapa({
    'em': milissegundos,
    'origem': 'voz',
    'pedido': 'abrir WhatsApp',
    'acao': 'abrir o app whatsapp',
    'ok': true,
    'mensagem': 'Abertura de WhatsApp enviada ao Android.',
  });
  assert(completoLido != null, 'registro completo foi descartado');
  final completo = completoLido!;
  final quando = DateTime.fromMillisecondsSinceEpoch(milissegundos);
  assert(completo.em == quando, 'horário do Android perdido');
  assert(completo.hora ==
          '${quando.hour.toString().padLeft(2, '0')}:'
          '${quando.minute.toString().padLeft(2, '0')}',
      'hora formatada errado');
  assert(completo.origem == OrigemExecucao.voz, 'origem de voz perdida');
  assert(completo.ok && completo.resultadoRotulo == 'Executado',
      'resultado positivo não marcado');
  assert(completo.titulo == 'abrir o app whatsapp', 'título não usou a ação');

  // 2. Resultado não confirmado nunca vira sucesso.
  final falhouLido = RegistroExecucao.deMapa({
    'em': milissegundos,
    'origem': 'segundo_plano',
    'pedido': 'abrir YouTube',
    'acao': 'abrir app youtube',
    'ok': false,
    'mensagem': 'Nenhum app instalado corresponde a "YouTube".',
  });
  assert(falhouLido != null && !falhouLido.ok, 'falha virou execução');
  final falhou = falhouLido!;
  assert(falhou.origem == OrigemExecucao.segundoPlano,
      'origem do segundo plano perdida');
  assert(falhou.resultadoRotulo == 'Não executado',
      'rótulo de falha errado');
  assert(falhou.mensagem.contains('Nenhum app'), 'mensagem do Android perdida');
  final semOk = RegistroExecucao.deMapa({
    'em': milissegundos,
    'pedido': 'lanterna',
  });
  assert(semOk != null && !semOk.ok, 'campo ok ausente foi tratado como sucesso');

  // 3. Registro sem horário ou sem pedido não pode virar linha vazia.
  assert(
      RegistroExecucao.deMapa({
            'origem': 'voz',
            'pedido': 'lanterna',
            'ok': true,
          }) ==
          null,
      'registro sem horário foi aceito');
  assert(
      RegistroExecucao.deMapa({
            'em': milissegundos,
            'pedido': '   ',
            'ok': true,
          }) ==
          null,
      'registro sem pedido foi aceito');
  assert(RegistroExecucao.deMapa(null) == null, 'mapa nulo virou registro');
  assert(RegistroExecucao.deMapa('texto') == null, 'texto virou registro');

  // 4. Horário em texto (como alguns canais devolvem) também é lido.
  final emTexto = RegistroExecucao.deMapa({
    'em': '$milissegundos',
    'pedido': 'volume 30',
    'ok': true,
  });
  assert(emTexto != null && emTexto.em == quando, 'horário em texto não lido');

  // 5. Origem desconhecida não inventa que foi por voz.
  final semOrigem = RegistroExecucao.deMapa({
    'em': milissegundos,
    'pedido': 'lanterna',
  });
  assert(semOrigem?.origem == OrigemExecucao.desconhecida,
      'origem ausente virou voz');
  assert(OrigemExecucao.deId('teste') == OrigemExecucao.teste,
      'origem de teste não reconhecida');
  assert(OrigemExecucao.deId('xyz') == OrigemExecucao.desconhecida,
      'origem inválida não caiu no desconhecido');

  // 6. Lista: ordena do mais recente para o mais antigo e descarta repetidos.
  final lista = registrosDeMapa([
    {'em': milissegundos - 60000, 'pedido': 'lanterna', 'ok': true},
    {'em': milissegundos, 'pedido': 'volume 30', 'ok': false},
    {'em': milissegundos, 'pedido': 'volume 30', 'ok': false},
    'lixo',
  ]);
  assert(lista.length == 2, 'repetidos ou lixo entraram na lista');
  assert(lista.first.pedido == 'volume 30', 'ordem do mais recente errada');
  assert(lista.last.pedido == 'lanterna', 'ordem do mais antigo errada');

  // 7. Limite de 100 registros preserva os mais recentes.
  final muitos = registrosDeMapa([
    for (var i = 0; i < 130; i++)
      {'em': milissegundos - i * 1000, 'pedido': 'comando $i', 'ok': true},
  ]);
  assert(muitos.length == RegistroExecucao.limite, 'limite não aplicado');
  assert(muitos.first.pedido == 'comando 0', 'perdeu o mais recente');
  assert(muitos.last.pedido == 'comando 99', 'guardou além do limite');

  // 8. Resposta inválida do Android não derruba a tela.
  assert(registrosDeMapa(null).isEmpty, 'nulo virou lista');
  assert(registrosDeMapa('texto').isEmpty, 'texto virou lista');

  // 9. Cabeçalho de dia.
  final agora = DateTime(2026, 11, 20, 10, 0);
  assert(diaRotulo(DateTime(2026, 11, 20, 8, 13), agora) == 'Hoje',
      'hoje rotulado errado');
  assert(diaRotulo(DateTime(2026, 11, 19, 23, 59), agora) == 'Ontem',
      'ontem rotulado errado');
  assert(diaRotulo(DateTime(2026, 11, 1, 12), agora) == '01/11/2026',
      'data antiga formatada errado');

  // 10. Resumo mostra execuções e falhas sem esconder o que não rodou.
  assert(resumoExecucoes(const []) == '', 'resumo vazio inventou texto');
  final umOk = registrosDeMapa([
    {'em': milissegundos, 'pedido': 'lanterna', 'ok': true},
  ]);
  assert(resumoExecucoes(umOk) == '1 comando · todos executados',
      'resumo de um comando errado');
  final misto = registrosDeMapa([
    {'em': milissegundos, 'pedido': 'lanterna', 'ok': true},
    {'em': milissegundos - 1000, 'pedido': 'abrir app', 'ok': false},
  ]);
  assert(resumoExecucoes(misto) ==
          '2 comandos · 1 executado · 1 não executado',
      'resumo misto errado');
  final nenhum = registrosDeMapa([
    {'em': milissegundos, 'pedido': 'abrir app', 'ok': false},
  ]);
  assert(resumoExecucoes(nenhum) == '1 comando · nenhum executado',
      'resumo sem execução errado');

  stdout.writeln(
      'OK: histórico de execuções — horário, origem, resultado e limites.');
}
