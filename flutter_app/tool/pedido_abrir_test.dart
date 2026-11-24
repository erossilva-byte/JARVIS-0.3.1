import 'package:jarvis_nova/core/pedido_abrir.dart';

void main() {
  // 1. Telas pedidas com verbo de abrir.
  final casos = <String, TelaJarvis>{
    'abre o modo visão': TelaJarvis.visao,
    'abrir visão': TelaJarvis.visao,
    'abre a câmera': TelaJarvis.visao,
    'abrir modo vision': TelaJarvis.visao,
    'exibe o modo palco': TelaJarvis.palco,
    'abre o palco': TelaJarvis.palco,
    'abre a memória': TelaJarvis.memoria,
    'mostra as notas': TelaJarvis.memoria,
    'mostra as pessoas': TelaJarvis.pessoas,
    'abre as tarefas': TelaJarvis.tarefas,
    'abre as rotinas': TelaJarvis.tarefas,
    'abre o modo programação': TelaJarvis.programacao,
    'abre os arquivos': TelaJarvis.arquivos,
    'abre o CAD': TelaJarvis.cadesimu,
    'abre o simulador': TelaJarvis.circuito,
    'abre o projetista': TelaJarvis.projetista,
    'abre a segurança': TelaJarvis.seguranca,
    'abre a personalização': TelaJarvis.personalizacao,
    'abre as configurações': TelaJarvis.configuracoes,
    'abre as habilidades': TelaJarvis.habilidades,
    'abre os gestos': TelaJarvis.gestos,
    'abre os perfis de timbre': TelaJarvis.timbre,
    'abre o histórico': TelaJarvis.historico,
    'abre o segundo plano': TelaJarvis.segundoPlano,
    'abre os comandos do android': TelaJarvis.comandos,
    'abre a central do aparelho': TelaJarvis.dispositivo,
    'abre os provedores': TelaJarvis.provedores,
    'abre o avatar': TelaJarvis.avatar,
    'abre a conversa': TelaJarvis.conversa,
    'abre o modo voz': TelaJarvis.voz,
    'abre os modelos locais': TelaJarvis.modelosLocais,
    'jarvis, abre a memória': TelaJarvis.memoria,
    'abre a visão e fala o que você vê': TelaJarvis.visao,
  };
  casos.forEach((texto, esperado) {
    final pedido = pedidoAbrir(texto);
    assert(pedido != null, '“$texto” não foi reconhecido');
    assert(pedido!.tela == esperado,
        '“$texto” abriu ${pedido.tela.name}, esperado ${esperado.name}');
  });

  // 2. "Voz externa" não pode virar "modo voz".
  final externa = pedidoAbrir('abre a voz externa');
  assert(externa != null && externa.tela == TelaJarvis.vozExterna,
      'voz externa veio como ${externa?.tela.name}');

  // 3. "Modo X" sem verbo vale; o nome puro também.
  assert(pedidoAbrir('modo palco')?.tela == TelaJarvis.palco,
      '“modo palco” sem verbo não abriu');
  assert(pedidoAbrir('visão')?.tela == TelaJarvis.visao,
      '“visão” sozinho não abriu');

  // 4. Abrir app de terceiro continua sendo do comando de app, não daqui.
  for (final texto in [
    'abre o WhatsApp',
    'abrir o Instagram',
    'abre o Spotify',
    'abre o app do banco',
  ]) {
    assert(pedidoAbrir(texto) == null, '“$texto” virou tela do JARVIS');
  }

  // 5. Mensagem e ligação têm caminho próprio.
  for (final texto in [
    'manda mensagem para a Ana no WhatsApp dizendo que chego às 9',
    'envia mensagem para o João pelo Telegram',
    'liga para a Ana',
    'abre o WhatsApp e manda mensagem para as pessoas',
  ]) {
    assert(pedidoAbrir(texto) == null, '“$texto” virou abertura de tela');
  }

  // 6. Pergunta nunca vira ação.
  for (final texto in [
    'como abro a memória?',
    'por que a visão não abre?',
    'onde fica o histórico',
  ]) {
    assert(pedidoAbrir(texto) == null, 'pergunta virou ação: “$texto”');
  }

  // 7. Conversa comum não abre nada.
  for (final texto in [
    'bom dia',
    'qual a capital da França',
    'aumenta o volume',
    'toca uma música',
    'me explica o que é um contator',
  ]) {
    assert(pedidoAbrir(texto) == null, '“$texto” virou tela do JARVIS');
  }

  // 8. Chave do Android volta para a tela certa.
  assert(TelaJarvis.porChave('voz_externa') == TelaJarvis.vozExterna,
      'chave voz_externa não voltou');
  assert(TelaJarvis.porChave('segundo_plano') == TelaJarvis.segundoPlano,
      'chave segundo_plano não voltou');
  assert(TelaJarvis.porChave('inexistente') == null,
      'chave desconhecida virou tela');

  // 9. Resumo e frase falada usam o rótulo da tela.
  final memoria = pedidoAbrir('abre a memória')!;
  assert(memoria.resumo == 'abrir a memória', 'resumo veio “${memoria.resumo}”');
  assert(memoria.fraseFalada == 'Abrindo a memória.',
      'frase falada veio “${memoria.fraseFalada}”');
}
