import 'package:jarvis_nova/core/pedido_app.dart';

void main() {
  void confere(
    String texto,
    AppComAcao app,
    TipoAcaoApp acao, [
    String alvo = '',
  ]) {
    final pedido = pedidoAppComAcao(texto);
    assert(pedido != null, '“$texto” não foi reconhecido');
    if (pedido == null) return;
    assert(pedido.app == app,
        '“$texto” abriu ${pedido.app.chave}, esperado ${app.chave}');
    assert(pedido.acao == acao,
        '“$texto” fez ${pedido.acao.chave}, esperado ${acao.chave}');
    assert(pedido.alvo == alvo,
        '“$texto” levou o alvo “${pedido.alvo}”, esperado “$alvo”');
  }

  // 1. Conversa com alguém.
  confere('abre o WhatsApp na conversa da Ana',
      AppComAcao.whatsapp, TipoAcaoApp.conversa, 'Ana');
  confere('abre a conversa com o João no WhatsApp',
      AppComAcao.whatsapp, TipoAcaoApp.conversa, 'João');
  confere('abre o WhatsApp para falar com a Maria',
      AppComAcao.whatsapp, TipoAcaoApp.conversa, 'Maria');
  confere('jarvis, abre o WhatsApp Business na conversa com a Ana',
      AppComAcao.whatsappBusiness, TipoAcaoApp.conversa, 'Ana');
  confere('abre o Telegram na conversa com o Pedro',
      AppComAcao.telegram, TipoAcaoApp.conversa, 'Pedro');
  confere('abre o Instagram no direct da Ju',
      AppComAcao.instagram, TipoAcaoApp.conversa, 'Ju');
  confere('abre o SMS para a Ana',
      AppComAcao.sms, TipoAcaoApp.conversa, 'Ana');

  // 2. Escrever.
  confere('abre o Gmail para escrever para o João',
      AppComAcao.gmail, TipoAcaoApp.escrever, 'João');
  confere('abre o e-mail para escrever para a Ana',
      AppComAcao.email, TipoAcaoApp.escrever, 'Ana');
  confere('abre o Gmail para escrever um e-mail novo',
      AppComAcao.gmail, TipoAcaoApp.escrever);

  // 3. Mapa: rota e lugar.
  confere('abre o mapa até a Rua das Flores',
      AppComAcao.maps, TipoAcaoApp.navegar, 'Rua das Flores');
  confere('abre o mapa e traça a rota até o aeroporto',
      AppComAcao.maps, TipoAcaoApp.navegar, 'aeroporto');
  confere('abre o mapa de São Paulo',
      AppComAcao.maps, TipoAcaoApp.pesquisar, 'São Paulo');

  // 4. Busca e música.
  confere('abre o YouTube e pesquisa gatos',
      AppComAcao.youtube, TipoAcaoApp.pesquisar, 'gatos');
  confere('abre o YouTube e pesquisar receitas de bolo',
      AppComAcao.youtube, TipoAcaoApp.pesquisar, 'receitas de bolo');
  confere('abre o Spotify e toca Legião Urbana',
      AppComAcao.spotify, TipoAcaoApp.tocar, 'Legião Urbana');
  confere('abre o Spotify e pesquisa Legião',
      AppComAcao.spotify, TipoAcaoApp.pesquisar, 'Legião');

  // 5. Câmera e calculadora.
  confere('abre a câmera', AppComAcao.camera, TipoAcaoApp.camera);
  confere('abre a câmera para tirar foto',
      AppComAcao.camera, TipoAcaoApp.camera);
  confere('abre a calculadora', AppComAcao.calculadora, TipoAcaoApp.abrir);

  // 6. Abrir o app pelado continua no comando de app que já existe.
  for (final texto in [
    'abre o WhatsApp',
    'abrir o Instagram',
    'abre o YouTube',
    'abre o mapa',
    'abre o Gmail',
  ]) {
    assert(pedidoAppComAcao(texto) == null, '“$texto” virou ação de app');
  }

  // 7. Mensagem e ligação têm caminho próprio.
  for (final texto in [
    'manda mensagem para a Ana no WhatsApp dizendo que chego às 9',
    'abre o WhatsApp e manda mensagem para a Ana',
    'envia um SMS para o João',
    'liga para a Ana',
  ]) {
    assert(pedidoAppComAcao(texto) == null, '“$texto” virou ação de app');
  }

  // 8. Tela do JARVIS e pergunta não são ação de app.
  for (final texto in [
    'abre o modo visão',
    'abre a memória',
    'como abro o WhatsApp na conversa da Ana?',
    'onde fica o mapa',
    'bom dia',
  ]) {
    assert(pedidoAppComAcao(texto) == null, '“$texto” virou ação de app');
  }

  // 9. Resumo e frase falada.
  final conversa = pedidoAppComAcao('abre o WhatsApp na conversa da Ana')!;
  assert(conversa.resumo == 'abrir o WhatsApp na conversa com Ana',
      'resumo veio “${conversa.resumo}”');
  assert(conversa.fraseFalada == 'Abrindo o WhatsApp na conversa com Ana.',
      'frase falada veio “${conversa.fraseFalada}”');
  final rota = pedidoAppComAcao('abre o mapa até a Rua das Flores')!;
  assert(rota.fraseFalada == 'Traçando a rota até Rua das Flores.',
      'frase falada veio “${rota.fraseFalada}”');

  // 10. Chaves estáveis voltam pelos dois lados.
  assert(AppComAcao.porChave('whatsapp') == AppComAcao.whatsapp,
      'chave whatsapp não voltou');
  assert(TipoAcaoApp.porChave('navegar') == TipoAcaoApp.navegar,
      'chave navegar não voltou');
  assert(AppComAcao.porChave('inexistente') == null,
      'chave desconhecida virou app');
}
