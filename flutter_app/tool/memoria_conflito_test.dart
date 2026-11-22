import 'dart:io';

import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/core/memoria_conflito.dart';
import 'package:jarvis_nova/core/memoria_sync.dart';

NotaMemoria local(String texto, {String titulo = 'Motor', String? hash}) => NotaMemoria(
      id: 'motor',
      titulo: titulo,
      texto: texto,
      caminho: 'Oficina/Motor.md',
      hashSincronizado: hash,
      criadaEm: DateTime(2026, 11, 1),
      atualizadaEm: DateTime(2026, 11, 1),
    );

ConflitoSync conflito({required NotaMemoria nota, required String remoto}) => ConflitoSync(
      local: nota,
      remoto: ArquivoRemoto(
        caminho: 'Oficina/Motor.md',
        conteudo: '---\ntitulo: Motor do Obsidian\n---\n$remoto',
      ),
      motivo: 'as duas cópias mudaram',
    );

void main() {
  final quando = DateTime(2026, 11, 15);

  // 1. Aparelho vence: envia o texto local e guarda o remoto como backup
  final peloAparelho = planejarResolucao(
    conflito(nota: local('texto do aparelho'), remoto: 'texto do obsidian'),
    DecisaoConflito.aparelho,
    agora: quando,
  );
  assert(peloAparelho.envio != null, 'aparelho vencendo deveria escrever na pasta');
  assert(peloAparelho.envio!.conteudo.contains('texto do aparelho'), 'não enviou o texto do aparelho');
  assert(peloAparelho.notaOficial.hashSincronizado == hashConteudo('texto do aparelho'), 'hash oficial errado');
  assert(peloAparelho.notaOficial.caminho == 'Oficina/Motor.md', 'caminho oficial errado');
  assert(peloAparelho.backup.texto == 'texto do obsidian', 'versão da pasta não foi preservada');
  assert(peloAparelho.backup.caminho == null, 'backup não pode apontar para o caminho em disputa');
  assert(peloAparelho.backup.id != peloAparelho.notaOficial.id, 'backup e oficial com o mesmo id');

  // 2. Pasta vence: adota o remoto e guarda o texto local como backup
  final pelaPasta = planejarResolucao(
    conflito(nota: local('texto do aparelho'), remoto: 'texto do obsidian'),
    DecisaoConflito.pasta,
    agora: quando,
  );
  assert(pelaPasta.envio == null, 'pasta vencendo não deveria escrever');
  assert(pelaPasta.notaOficial.texto == 'texto do obsidian', 'oficial não adotou o remoto');
  assert(pelaPasta.notaOficial.titulo == 'Motor do Obsidian', 'título remoto não adotado');
  assert(pelaPasta.notaOficial.hashSincronizado == hashConteudo('texto do obsidian'), 'hash remoto errado');
  assert(pelaPasta.backup.texto == 'texto do aparelho', 'texto local não foi preservado');
  assert(pelaPasta.backup.titulo.contains('Motor'), 'backup sem relação com a nota');
  assert(pelaPasta.backup.caminho == null, 'backup não pode ocupar o caminho');

  // 3. A versão perdedora existe nos dois sentidos — nada é descartado
  assert(peloAparelho.backup.texto.isNotEmpty && pelaPasta.backup.texto.isNotEmpty, 'backup vazio');

  // 4. Resolver o mesmo conflito duas vezes não gera ids diferentes para o backup
  final repetido = planejarResolucao(
    conflito(nota: local('texto do aparelho'), remoto: 'texto do obsidian'),
    DecisaoConflito.aparelho,
    agora: quando,
  );
  assert(repetido.backup.id == peloAparelho.backup.id, 'backup duplicaria a cada resolução');

  // 5. Conflito sem nota local é recusado em vez de inventar
  var recusou = false;
  try {
    planejarResolucao(
      ConflitoSync(remoto: ArquivoRemoto(caminho: 'A.md', conteudo: 'x'), motivo: 'sem local'),
      DecisaoConflito.pasta,
      agora: quando,
    );
  } on ArgumentError {
    recusou = true;
  }
  assert(recusou, 'conflito sem nota local deveria ser recusado');

  stdout.writeln('OK: resolução de conflito — escolha, backup preservado e ids estáveis');
}
