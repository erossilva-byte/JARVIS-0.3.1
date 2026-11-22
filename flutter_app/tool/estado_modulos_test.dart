import 'dart:io';

import 'package:jarvis_nova/core/estado_modulos.dart';

void main() {
  // 1. Um estado por módulo, com nome único.
  assert(situacoesModulos.length == 25,
      'esperava 25 módulos, achei ${situacoesModulos.length}');
  final nomes = situacoesModulos.map((s) => s.nome).toList();
  assert(nomes.toSet().length == nomes.length, 'nome de módulo repetido');

  // 2. Nenhum módulo usa o aviso genérico: todos têm título e detalhe próprios.
  for (final situacao in situacoesModulos) {
    assert(situacao.titulo.trim().isNotEmpty, '${situacao.nome} sem título');
    assert(situacao.detalhe.trim().length > 40,
        '${situacao.nome} com detalhe curto demais');
    assert(!situacao.detalhe.contains('Integração em auditoria'),
        '${situacao.nome} ainda usa o aviso genérico');
  }

  // 3. Módulo com tela tem botão; módulo sem tela diz onde ela mora.
  for (final situacao in situacoesModulos) {
    if (situacao.tela == TelaModulo.nenhuma) {
      assert(situacao.onde.isNotEmpty || situacao.estado == EstadoModulo.ausente,
          '${situacao.nome} sem tela e sem dizer onde ela mora');
    } else if (situacao.estado == EstadoModulo.ausente) {
      // Ausente também pode abrir tela — desde que a tela seja a explicação do
      // que falta, e não uma promessa de função.
      assert(situacao.detalhe.toLowerCase().contains('não'),
          '${situacao.nome} abre tela de ausente sem dizer o que falta');
    }
  }

  // 4. O que não existe está declarado com motivo, não escondido.
  final ausentes = situacoesModulos
      .where((s) => s.estado == EstadoModulo.ausente)
      .map((s) => s.nome)
      .toList();
  for (final esperado in [
    'Programação (sem execução)',
    'Pareamento Windows',
    'Controle do Windows',
    'ESP32 e Home Assistant',
    'Avatar 3D',
    'Modelos locais',
  ]) {
    assert(ausentes.contains(esperado), '$esperado deveria estar como ausente');
  }

  // 5. O que o usuário pediu para terminar está como pronto.
  for (final pronto in [
    'Hermes Agent',
    'Agentes especializados',
    'Tarefas e rotinas',
    'CADeSIMU e elétrica',
    'Segurança e privacidade',
    'Perfis de timbre',
  ]) {
    assert(situacaoDe(pronto).estado == EstadoModulo.pronto,
        '$pronto deveria estar como pronto');
  }

  // 6. Módulo fora da tabela não promete nada.
  final fora = situacaoDe('Módulo inventado');
  assert(fora.estado == EstadoModulo.ausente, 'módulo fora da tabela prometeu');
  assert(fora.titulo.contains('fora da tabela'), 'módulo fora sem aviso');

  // 7. Contagem por estado fecha com o total.
  final contagem = contagemPorEstado();
  final soma = contagem.values.fold<int>(0, (a, b) => a + b);
  assert(soma == situacoesModulos.length, 'contagem não fecha: $soma');

  stdout.writeln('OK: ${situacoesModulos.length} módulos com estado próprio '
      '(${contagem[EstadoModulo.pronto]} prontos, '
      '${contagem[EstadoModulo.parcial]} parciais, '
      '${contagem[EstadoModulo.ausente]} ausentes)');
}
