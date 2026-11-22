import 'dart:io';

import 'package:jarvis_nova/core/modo_visita.dart';

void main() {
  // 1. O prompt sugerido tem nome e as proibições que dão sentido ao modo.
  assert(nomePromptModoVisita == 'Modo de visita', 'nome do prompt mudou');
  assert(promptModoVisita.contains(nomePromptModoVisita),
      'prompt sem o próprio nome');
  for (final regra in [
    'português do Brasil',
    'Nunca mencione o dono',
    'Não invente',
    'não peça senhas',
    'dados configurados',
  ]) {
    assert(promptModoVisita.contains(regra), 'prompt sem a regra "$regra"');
  }

  // 2. A primeira fala é de um app recém-instalado, sem dado do dono.
  assert(boasVindasVisita.contains('JARVIS'), 'boas-vindas sem o nome');
  assert(boasVindasVisita.contains('provedor'),
      'boas-vindas não explicam a falta de provedor');
  for (final proibido in ['conversa', 'memória', 'arquivo', 'ficha']) {
    assert(!boasVindasVisita.toLowerCase().contains(proibido),
        'boas-vindas expõem "$proibido"');
  }

  // 3. Hora e data saem do relógio do aparelho, sem rede.
  final quando = DateTime(2026, 11, 21, 9, 5);
  final hora = respostaVisita('que horas são?', agora: quando);
  assert(hora.contains('09 horas e 05 minutos'), 'hora errada: $hora');
  final data = respostaVisita('que dia é hoje?', agora: quando);
  assert(data.contains('sábado') && data.contains('21 de novembro de 2026'),
      'data errada: $data');

  // 4. Cumprimento e identidade respondem curto, sem inventar dados.
  assert(respostaVisita('oi').contains('posso ajudar'), 'cumprimento errado');
  assert(respostaVisita('quem é você?').contains('JARVIS'),
      'identidade sem o nome');

  // 5. Pergunta de conhecimento cai na falta de provedor, sem fingir resposta.
  final culinaria = respostaVisita('Jarvis, me fale sobre culinária no geral');
  assert(culinaria.contains('não tenho um provedor'),
      'culinária fingiu uma resposta: $culinaria');
  final qualquer =
      respostaVisita('como está tudo Jarvis', agora: quando);
  assert(qualquer.contains('não consigo responder'),
      'pergunta livre fingiu uma resposta: $qualquer');
  assert(respostaVisita('   ').isNotEmpty, 'texto vazio ficou sem resposta');

  // 6. Nenhuma resposta menciona dados do dono nem manda abrir nada.
  for (final pergunta in [
    'como está tudo',
    'me fale sobre culinária',
    'qual a minha agenda',
    'o que eu falei ontem',
  ]) {
    final texto = respostaVisita(pergunta).toLowerCase();
    for (final proibido in ['ontem', 'agenda de', 'sua memória', 'abra o app']) {
      assert(!texto.contains(proibido),
          '"$pergunta" respondeu "$proibido": $texto');
    }
  }

  // 7. Os ajustes do modo de visita estão sempre vazios.
  assert(ajustesVisita.length >= 5, 'ajustes de visita incompletos');
  for (final item in ajustesVisita) {
    assert(item.$1.isNotEmpty && item.$2.isNotEmpty, 'item vazio');
    assert(
        item.$2.startsWith('Nenhum') ||
            item.$2.startsWith('Nenhuma') ||
            item.$2.startsWith('Vazia') ||
            item.$2.startsWith('Desligada'),
        '${item.$1} não está vazio: ${item.$2}');
  }

  // 8. Os limites não escondem o que o modo faz e não faz.
  final limites = limitesModoVisita.join(' ').toLowerCase();
  for (final termo in ['não apaga', 'root', 'biometria', 'internet', 'dois pins']) {
    final achado = termo == 'dois pins'
        ? limites.contains('dois pins') || limites.contains('dois pin')
        : limites.contains(termo);
    assert(achado, 'limite sobre "$termo" ausente');
  }

  stdout.writeln(
      'OK: modo de visita — prompt, respostas locais, ajustes vazios e limites');
}
