import 'dart:io';

import 'package:jarvis_nova/core/aparelho.dart';
import 'package:jarvis_nova/core/resumo_tatico.dart';

NotificacaoAparelho _n(String app, String titulo, String texto, {int min = 0}) =>
    NotificacaoAparelho(
      app: app,
      titulo: titulo,
      texto: texto,
      hora: DateTime(2026, 11, 21, 10, 30).subtract(Duration(minutes: min)),
    );

void main() {
  final agora = DateTime(2026, 11, 21, 10, 30);

  // 1. Urgência vem de palavra que pede ação, sem inventar nada.
  assert(mensagemUrgente(_n('WhatsApp', 'Mãe', 'Pague o boleto hoje, por favor')),
      'boleto de hoje deveria ser urgente');
  assert(mensagemUrgente(_n('SMS', 'Banco', 'Seu código de confirmação é 1234')),
      'código de confirmação deveria ser urgente');
  assert(!mensagemUrgente(_n('Instagram', 'Fulano', 'curtiu sua foto')),
      'curtida não é urgência');

  // 2. Ruído de grupo tem sinais próprios.
  assert(ruidoDeGrupo(_n('WhatsApp', 'Grupo da família', 'Bom dia a todos')),
      'título com grupo deveria ser ruído');
  assert(ruidoDeGrupo(_n('Telegram', 'Turma 302', '12 mensagens')),
      'contagem de mensagens deveria ser ruído');
  assert(!ruidoDeGrupo(_n('WhatsApp', 'Chefe', 'Podemos falar às 15h?')),
      'recado direto não é ruído de grupo');

  // 3. A triagem separa cada notificação uma única vez.
  final triagem = triarMensagens([
    _n('WhatsApp', 'Mãe', 'Ligue agora, é urgente'),
    _n('WhatsApp', 'Grupo do prédio', '3 mensagens novas'),
    _n('SMS', 'Loja', 'Sua encomenda chegou ao centro de distribuição'),
  ]);
  assert(triagem.total == 3, 'a triagem perdeu notificações');
  assert(triagem.urgentes.length == 1, 'urgente não foi isolado');
  assert(triagem.ruido.length == 1, 'ruído não foi isolado');
  assert(triagem.restantes.length == 1, 'recado comum não foi isolado');

  // 4. O pedido enviado ao provedor tem as regras e as notificações.
  final pedido = mensagensResumoTatico(triagem.restantes,
      agora: agora);
  assert(pedido.length == 2, 'pedido deveria ter sistema e lista');
  final sistema = pedido.first['content'] ?? '';
  assert(pedido.first['role'] == 'system', 'falta instrução de sistema');
  assert(sistema.contains('SOMENTE com um JSON'), 'formato exigido ausente');
  assert(sistema.contains('Não invente'), 'regra contra invenção ausente');
  final usuario = pedido.last['content'] ?? '';
  assert(usuario.contains('SMS'), 'app não apareceu no pedido');
  assert(usuario.contains('encomenda'), 'texto não apareceu no pedido');

  // 5. O limite corta a lista sem quebrar o pedido.
  final muitas = [
    for (var i = 0; i < 60; i++) _n('App$i', 'Título $i', 'Texto $i'),
  ];
  final grande = mensagensResumoTatico(muitas, agora: agora);
  final corpo = grande.last['content'] ?? '';
  assert(corpo.trim().isNotEmpty, 'pedido vazio');
  assert(corpo.contains('App0'), 'a mais recente precisa entrar');
  assert(!corpo.contains('App40'), 'o limite não foi respeitado');

  // 6. A resposta do provedor é lida mesmo com cerca de código em volta.
  final lido = lerResumoTatico('''
Aqui está:
```json
{"resumo":"Duas mensagens diretas e um grupo.","urgentes":["Ligue para a mãe"],
 "ruido":["Grupo do prédio"],"respostas":[{"app":"WhatsApp","texto":"Já te ligo."}]}
```''');
  assert(lido != null, 'JSON cercado por código não foi lido');
  final resumoIa = lido!;
  assert(resumoIa.resumo.contains('Duas mensagens'), 'resumo perdido');
  assert(resumoIa.urgentes.single == 'Ligue para a mãe', 'urgente perdido');
  assert(resumoIa.ruido.single == 'Grupo do prédio', 'ruído perdido');
  assert(resumoIa.respostas.single.app == 'WhatsApp',
      'app da sugestão perdido');
  assert(resumoIa.respostas.single.texto == 'Já te ligo.', 'sugestão perdida');
  assert(resumoIa.daIa, 'resposta do provedor precisa ser marcada como IA');

  // 7. Resposta inválida ou vazia não vira resumo inventado.
  assert(lerResumoTatico('desculpe, não consegui') == null,
      'texto sem JSON deveria ser recusado');
  assert(lerResumoTatico('{"resumo":"","urgentes":[],"ruido":[],"respostas":[]}') ==
          null,
      'resumo vazio deveria ser recusado');

  // 8. A frase falada junta as partes que existem.
  final fala = resumoIa.fala;
  assert(fala.contains('Duas mensagens'), 'fala sem resumo');
  assert(fala.contains('Urgente:'), 'fala sem urgente');
  assert(fala.contains('filtradas como ruído'), 'fala sem ruído');
  assert(fala.contains('Sugestão de resposta'), 'fala sem sugestão');

  stdout.writeln('OK: resumo tático — urgência, ruído, pedido, leitura e fala');
}
