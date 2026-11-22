import 'dart:io';

import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/core/memoria_sync.dart';

NotaMemoria local(
  String titulo,
  String texto, {
  String? caminho,
  String? hashSincronizado,
}) =>
    NotaMemoria(
      id: titulo.toLowerCase().replaceAll(' ', '-'),
      titulo: titulo,
      texto: texto,
      caminho: caminho,
      hashSincronizado: hashSincronizado,
      criadaEm: DateTime(2026, 11, 1),
      atualizadaEm: DateTime(2026, 11, 1),
    );

ArquivoRemoto remoto(String caminho, String corpo) => ArquivoRemoto(caminho: caminho, conteudo: corpo);

void main() {
  final quando = DateTime(2026, 11, 14);

  // 1. Só na pasta: vira nota local, com caminho e hash
  final importado = planejarSincronizacao([], [remoto('Oficina/Motor.md', 'Ligação em estrela-triângulo.')], agora: quando);
  assert(importado.recebidas.length == 1, 'arquivo novo da pasta não importado');
  assert(importado.recebidas.single.nota.titulo == 'Motor', 'título não veio do arquivo');
  assert(importado.recebidas.single.caminho == 'Oficina/Motor.md', 'caminho errado');
  assert(importado.recebidas.single.nota.hashSincronizado == hashConteudo('Ligação em estrela-triângulo.'), 'hash não gravado');

  // 2. Só no local: vira arquivo novo com nome seguro
  final enviado = planejarSincronizacao([local('Bancada de testes', 'Texto local.')], [], agora: quando);
  assert(enviado.envios.length == 1, 'nota local nova não enviada');
  assert(enviado.envios.single.caminho == 'bancada-de-testes.md', 'nome de arquivo: ${enviado.envios.single.caminho}');
  assert(enviado.envios.single.novo, 'deveria ser arquivo novo');
  assert(enviado.envios.single.conteudo.contains('titulo: Bancada de testes'), 'Markdown sem frontmatter');

  // 3. Iguais dos dois lados: nada a fazer
  final iguais = planejarSincronizacao(
    [local('Motor', 'mesmo texto', caminho: 'Motor.md', hashSincronizado: hashConteudo('mesmo texto'))],
    [remoto('Motor.md', 'mesmo texto')],
    agora: quando,
  );
  assert(iguais.vazio, 'plano não deveria ter ação');
  assert(iguais.iguais == 1, 'igual não contado');

  // 4. Local novo com mesmo conteúdo de arquivo existente: só adota caminho
  final adota = planejarSincronizacao([local('Motor', 'mesmo texto')], [remoto('Motor.md', 'mesmo texto')], agora: quando);
  assert(adota.envios.isEmpty && adota.recebidas.isEmpty, 'conteúdo igual gerou escrita');
  assert(adota.marcar.single.titulo == 'Motor', 'caminho não foi adotado');

  // 5. Local mudou, pasta continua na versão sincronizada: envia
  final localMudou = planejarSincronizacao(
    [local('Motor', 'texto novo', caminho: 'Motor.md', hashSincronizado: hashConteudo('texto antigo'))],
    [remoto('Motor.md', 'texto antigo')],
    agora: quando,
  );
  assert(localMudou.envios.single.caminho == 'Motor.md', 'alteração local não enviada');
  assert(localMudou.conflitos.isEmpty, 'alteração local virou conflito');

  // 6. Pasta mudou, local continua na versão sincronizada: recebe
  final recebeu = planejarSincronizacao(
    [local('Motor', 'texto antigo', caminho: 'Motor.md', hashSincronizado: hashConteudo('texto antigo'))],
    [remoto('Motor.md', 'texto novo do Obsidian')],
    agora: quando,
  );
  assert(recebeu.recebidas.single.nota.texto == 'texto novo do Obsidian', 'alteração remota não recebida');
  assert(recebeu.envios.isEmpty, 'receber não deveria enviar');
  assert(recebeu.recebidas.single.nota.hashSincronizado == hashConteudo('texto novo do Obsidian'), 'hash não atualizado');

  // 7. Os dois mudaram: conflito, nada é sobrescrito
  final conflito = planejarSincronizacao(
    [local('Motor', 'local novo', caminho: 'Motor.md', hashSincronizado: hashConteudo('base'))],
    [remoto('Motor.md', 'remoto novo')],
    agora: quando,
  );
  assert(conflito.envios.isEmpty && conflito.recebidas.isEmpty, 'conflito não pode escrever');
  assert(conflito.conflitos.single.local?.texto == 'local novo', 'conflito sem a cópia local');

  // 8. Nunca sincronizada e diferente: conflito, não sobrescreve
  final semBase = planejarSincronizacao(
    [local('Motor', 'local', caminho: 'Motor.md')],
    [remoto('Motor.md', 'remoto')],
    agora: quando,
  );
  assert(semBase.conflitos.length == 1, 'diferença sem base deveria ser conflito');
  assert(semBase.envios.isEmpty, 'não pode enviar por cima de arquivo não sincronizado');

  // 9. Arquivo sumiu da pasta: nota fica, registrada como ausente
  final sumiu = planejarSincronizacao(
    [local('Motor', 'texto', caminho: 'Motor.md', hashSincronizado: hashConteudo('texto'))],
    [],
    agora: quando,
  );
  assert(sumiu.ausentesNaPasta.single.titulo == 'Motor', 'ausência não registrada');
  assert(sumiu.envios.isEmpty, 'ausência não pode recriar nem apagar');

  // 10. Mesmo título em caminhos diferentes: conflito em vez de duplicar
  final mesmoTitulo = planejarSincronizacao(
    [local('Motor', 'texto local')],
    [remoto('Outra pasta/Motor.md', 'texto remoto')],
    agora: quando,
  );
  assert(mesmoTitulo.recebidas.isEmpty, 'duplicou nota de mesmo título');
  assert(mesmoTitulo.conflitos.length == 1, 'mesmo título deveria ser conflito');

  // 11. Caminho duplicado na leitura: usa um e reporta
  final duplicado = planejarSincronizacao(
    [],
    [remoto('A.md', 'um'), remoto('A.md', 'dois')],
    agora: quando,
  );
  assert(duplicado.caminhosDuplicados.single == 'A.md', 'duplicata não reportada');
  assert(duplicado.recebidas.length == 1, 'duplicata foi importada duas vezes');

  // 12. Hash estável e sensível
  assert(hashConteudo('abc') == hashConteudo('abc'), 'hash não é estável');
  assert(hashConteudo('abc') != hashConteudo('abd'), 'hash não detecta mudança');
  assert(hashConteudo('').isNotEmpty, 'hash vazio');

  // 13. Conteúdo com frontmatter é comparado pelo corpo, não pelos metadados
  final comFrontmatter = planejarSincronizacao(
    [local('Motor', 'corpo', caminho: 'Motor.md', hashSincronizado: hashConteudo('corpo'))],
    [ArquivoRemoto(caminho: 'Motor.md', conteudo: '---\ntitulo: Motor\natualizada: 2030-01-01\n---\ncorpo')],
    agora: quando,
  );
  assert(comFrontmatter.vazio || comFrontmatter.iguais == 1, 'frontmatter diferente gerou escrita');

  stdout.writeln('OK: sincronização — envio, recebimento, igual, conflito, ausente e duplicata');
}
