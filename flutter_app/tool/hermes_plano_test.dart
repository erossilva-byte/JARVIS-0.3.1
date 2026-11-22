import 'dart:io';

import 'package:jarvis_nova/core/agentes.dart';
import 'package:jarvis_nova/core/hermes_plano.dart';

void main() {
  // 1. Os doze agentes existem, com id único e ordem estável.
  assert(agentesEspecializados.length == 12, 'deveriam ser doze agentes');
  final ids = agentesEspecializados.map((a) => a.id).toList();
  assert(ids.toSet().length == 12, 'id de agente repetido');
  assert(ids.first == 'conversa', 'a conversa deveria ser o padrão');

  // 2. Roteamento: a ordem das regras importa.
  final roteamento = <String, String>{
    'abre o arquivo notas.txt': 'arquivos',
    'aumenta o volume do celular': 'dispositivo',
    'monta um circuito com LED': 'eletronica',
    'partida direta de motor': 'engenharia',
    'revisa esse código': 'programacao',
    'como está o clima hoje': 'pesquisa',
    'lembra que o R1 é de 1k': 'memoria',
    'o que tem nessa imagem': 'visao',
    'faz um diagnóstico do sistema': 'sistema',
    'bom dia, Jarvis': 'conversa',
  };
  roteamento.forEach((texto, esperado) {
    final agente = agenteDe(texto);
    assert(agente.id == esperado,
        '“$texto” foi para ${agente.id}, esperado $esperado');
  });

  // 3. Id desconhecido cai na conversa, sem quebrar a tela.
  assert(agentePorId('inexistente').id == 'conversa', 'id inválido não caiu');
  assert(agentePorId(null).id == 'conversa', 'id nulo não caiu');

  // 4. Plano elétrico: quatro passos entre engenharia e eletrônica.
  final eletrico = planejarPedido('monta um divisor de tensão de 12 V');
  assert(eletrico.eletrico, 'plano elétrico não marcado');
  assert(eletrico.total == 4, 'plano elétrico com ${eletrico.total} passos');
  assert(eletrico.rota.id == 'eletronica', 'rota do circuito errada');
  assert(
      eletrico.passos.any((p) => p.agente.id == 'engenharia') &&
          eletrico.passos.any((p) => p.agente.id == 'eletronica'),
      'plano elétrico sem os dois domínios');
  assert(eletrico.aviso.contains('CADeSIMU'),
      'plano elétrico sem o limite do CADeSIMU');

  // 5. Plano de código declara que não executa.
  final codigo = planejarPedido('revisa esse código');
  assert(codigo.total == 3, 'plano de código com ${codigo.total} passos');
  assert(codigo.aviso.contains('não executa'),
      'plano de código não avisa que não executa');

  // 6. Conversa comum tem dois passos e o aviso de chave ausente.
  final conversa = planejarPedido('bom dia');
  assert(conversa.total == 2, 'plano de conversa com ${conversa.total} passos');
  assert(conversa.aviso.contains('falta a chave'),
      'conversa não avisa sobre a chave');

  // 7. O plano é determinístico e o resumo cita a rota.
  final a = resumoPlano(planejarPedido('bom dia'));
  final b = resumoPlano(planejarPedido('bom dia'));
  assert(a == b, 'plano não é determinístico');
  assert(a.contains('Conversa'), 'resumo sem a rota');

  // 8. As mensagens do passo levam a instrução do agente e o pedido original.
  final mensagens = mensagensDoPasso(eletrico, eletrico.passos.first);
  assert(mensagens.length == 2, 'mensagens do passo com tamanho errado');
  assert(mensagens.first['content']!.contains('Engenharia'),
      'instrução do agente não entrou no pedido');
  assert(mensagens.last['content']!.contains('divisor de tensão'),
      'pedido original não entrou no passo');

  stdout.writeln('OK: 12 agentes, ${roteamento.length} roteamentos, 3 planos '
      'conferidos (elétrico, código e conversa)');
}
