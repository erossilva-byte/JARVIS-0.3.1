import 'dart:io';

import 'package:jarvis_nova/core/aparelho.dart';

void main() {
  // 1. A notificação guarda o que o Android mandou, sem inventar nada.
  final completa = NotificacaoAparelho.deMapa({
    'app': 'WhatsApp',
    'pacote': 'com.whatsapp',
    'chave': '0|com.whatsapp|123|null|10',
    'titulo': 'Mãe',
    'texto': 'Já cheguei em casa',
    'respondivel': true,
    'hora': '2026-11-21T10:00:00Z',
  });
  assert(completa != null, 'notificação completa foi descartada');
  final n = completa!;
  assert(n.chave.startsWith('0|com.whatsapp'), 'chave perdida');
  assert(n.pacote == 'com.whatsapp', 'pacote perdido');
  assert(n.respondivel, 'campo de resposta perdido');
  assert(n.hora.year == 2026, 'hora perdida');

  // 2. Sem o campo, a notificação continua válida mas não respondível.
  final semCampo = NotificacaoAparelho.deMapa({
    'app': 'YouTube',
    'titulo': 'Novo vídeo',
    'texto': 'Assista agora',
  });
  assert(semCampo != null && !semCampo.respondivel,
      'notificação sem campo virou respondível');

  // 3. Escolha da notificação para responder: a mais recente respondível.
  final lista = [
    NotificacaoAparelho.deMapa({
      'app': 'WhatsApp',
      'pacote': 'com.whatsapp',
      'chave': 'a',
      'titulo': 'João',
      'texto': 'Oi',
      'respondivel': true,
    })!,
    NotificacaoAparelho.deMapa({
      'app': 'YouTube',
      'pacote': 'com.google.android.youtube',
      'chave': 'b',
      'titulo': 'Vídeo',
      'respondivel': false,
    })!,
    NotificacaoAparelho.deMapa({
      'app': 'Telegram',
      'pacote': 'org.telegram.messenger',
      'chave': 'c',
      'titulo': 'Ana',
      'texto': 'Chegou?',
      'respondivel': true,
    })!,
  ];
  assert(notificacaoParaResponder(lista)?.chave == 'a',
      'a lista chega do mais recente para o mais antigo');
  assert(notificacaoParaResponder(lista, app: 'telegram')?.chave == 'c',
      'filtro por app não achou a mensagem');
  assert(notificacaoParaResponder(lista, app: 'com.whatsapp')?.chave == 'a',
      'filtro por pacote não achou a mensagem');
  assert(notificacaoParaResponder(lista, app: 'Instagram') == null,
      'app sem mensagem respondeu por outro');

  // 4. Sem nenhuma respondível, nada é prometido.
  assert(
      notificacaoParaResponder([
        NotificacaoAparelho.deMapa({'app': 'YouTube', 'chave': 'x'})!,
      ]) ==
          null,
      'notificação sem resposta foi escolhida');
  assert(notificacaoParaResponder(const []) == null, 'lista vazia respondeu');

  // 5. Frase de leitura junta app e mensagem uma vez só.
  final leitura = NotificacaoAparelho.deMapa({
    'app': 'WhatsApp',
    'titulo': 'Mãe',
    'texto': 'Já cheguei em casa',
  })!;
  assert(leitura.fraseLeitura == 'WhatsApp: Mãe. Já cheguei em casa',
      'frase de leitura errada: ${leitura.fraseLeitura}');
  final soTexto = NotificacaoAparelho.deMapa({
    'app': 'SMS',
    'texto': 'Bom dia',
  })!;
  assert(soTexto.fraseLeitura == 'SMS. Bom dia',
      'frase sem título errada: ${soTexto.fraseLeitura}');
  final mesmoTitulo = NotificacaoAparelho.deMapa({
    'app': 'SMS',
    'titulo': 'Bom dia',
    'texto': 'Bom dia',
  })!;
  assert(mesmoTitulo.fraseLeitura == 'SMS. Bom dia',
      'título repetido no áudio: ${mesmoTitulo.fraseLeitura}');

  // 6. Leitura em lote respeita o limite e ignora vazias.
  final lote = frasesDeLeitura(lista, limite: 2);
  assert(lote.length == 2, 'limite de leitura ignorado: $lote');
  assert(lote.first.startsWith('WhatsApp'), 'ordem da leitura errada');
  assert(frasesDeLeitura(const []).isEmpty, 'lista vazia gerou áudio');
  assert(frasesDeLeitura(lista, limite: 0).length == 1,
      'limite zero deveria virar uma mensagem');

  stdout.writeln(
      'OK: sentinela de mensagens — chave, respondível, escolha e leitura.');
}
