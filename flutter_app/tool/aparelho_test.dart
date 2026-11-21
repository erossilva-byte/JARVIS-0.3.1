// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/aparelho.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) throw StateError(mensagem);
}

void main() {
  // 1. Apps de mensagem conhecidos.
  exigir(appMensagemPorId('whatsapp')?.pacote == 'com.whatsapp',
      'o WhatsApp devia apontar para com.whatsapp');
  exigir(appMensagemPorId('sms')?.tipo == TipoEnvio.sms,
      'o SMS devia ser o único envio direto');
  exigir(appMensagemPorId('gmail') != null, 'o Gmail devia estar no registro');
  ok('registro de apps de mensagem com WhatsApp, SMS e Gmail');

  // 2. Mensagem no WhatsApp com texto exato.
  final zap = interpretarMensagem(
      'manda mensagem para Ana no WhatsApp dizendo que chego às 9');
  exigir(zap != null, 'o pedido de WhatsApp não foi reconhecido');
  exigir(zap!.app.id == 'whatsapp', 'o app devia ser o WhatsApp');
  exigir(zap.destino == 'Ana', 'o destino devia ser Ana e veio "${zap.destino}"');
  exigir(zap.texto == 'chego às 9',
      'o texto devia ser "chego às 9" e veio "${zap.texto}"');
  ok('mensagem para Ana no WhatsApp com o texto exato');

  // 3. SMS com número.
  final sms = interpretarMensagem(
      'envia um sms para 11999998888 dizendo estou chegando');
  exigir(sms != null && sms.app.id == 'sms', 'o SMS não foi reconhecido');
  exigir(sms!.destino == '11999998888',
      'o número devia ser preservado e veio "${sms.destino}"');
  exigir(sms.texto == 'estou chegando', 'o texto do SMS saiu errado');
  ok('SMS para número com o texto pedido');

  // 4. Instagram com texto depois de dois-pontos.
  final insta = interpretarMensagem(
      'manda no Instagram para joao o texto: bora treinar amanhã');
  exigir(insta != null && insta.app.id == 'instagram',
      'o pedido de Instagram não foi reconhecido');
  exigir(insta!.destino == 'joao', 'o destino devia ser joao');
  exigir(insta.texto == 'bora treinar amanhã',
      'o texto devia começar em "bora" e veio "${insta.texto}"');
  ok('mensagem no Instagram com destinatário e texto separados');

  // 5. Texto comum não vira mensagem.
  exigir(interpretarMensagem('manda um oi para a sua mãe') == null,
      'sem app de mensagem o texto não devia ser sequestrado');
  exigir(interpretarMensagem('como está o tempo hoje?') == null,
      'pergunta comum não devia virar mensagem');
  ok('conversa comum continua indo para a IA');

  // 6. Controles do Spotify.
  exigir(interpretarSpotify('pausa a música')?.acao == AcaoSpotify.pausar,
      'pausar não foi reconhecido');
  exigir(interpretarSpotify('próxima música')?.acao == AcaoSpotify.proxima,
      'avançar não foi reconhecido');
  exigir(interpretarSpotify('volta a música')?.acao == AcaoSpotify.anterior,
      'voltar não foi reconhecido');
  exigir(interpretarSpotify('reinicia a música')?.acao == AcaoSpotify.reiniciar,
      'reiniciar não foi reconhecido');
  exigir(interpretarSpotify('continua a música')?.acao == AcaoSpotify.continuar,
      'continuar não foi reconhecido');
  ok('pausar, continuar, avançar, voltar e reiniciar o Spotify');

  // 7. Tocar a música pedida.
  final tocar = interpretarSpotify('toca Bohemian Rhapsody no Spotify');
  exigir(tocar != null && tocar.acao == AcaoSpotify.tocar,
      'tocar a faixa não foi reconhecido');
  exigir(tocar!.faixa.toLowerCase().contains('bohemian rhapsody'),
      'a faixa devia ser Bohemian Rhapsody e veio "${tocar.faixa}"');
  ok('tocar a música pedida pelo nome');

  // 8. "Voltar" numa conversa não mexe na música.
  exigir(interpretarSpotify('volta para a tela inicial') == null,
      'um pedido comum não devia controlar o Spotify');
  ok('controle de música não sequestra conversa comum');

  // 9. Ligação por nome.
  final ligacao = interpretarLigacao('liga para Ana');
  exigir(ligacao != null && ligacao.destino == 'Ana',
      'a ligação para Ana não foi reconhecida');
  exigir(interpretarLigacao('desliga a luz da sala') == null,
      '"desliga" não é pedido de ligação');
  ok('ligação para contato reconhecida sem confundir com "desligar"');

  // 10. Status do aparelho lido do mapa.
  final estado = EstadoAparelho.deMapa({
    'bateria': 84,
    'carregando': true,
    'rede': 'Wi-Fi',
    'volume': 40,
    'brilho': 60,
    'modelo': 'Poco X7',
    'android': '15',
  });
  exigir(estado != null && estado.bateria == 84, 'a bateria devia ser 84%');
  final lido = estado!;
  exigir(lido.carregando, 'devia estar carregando');
  exigir(lido.descrever().contains('Wi-Fi'), 'a rede devia aparecer');
  exigir(lido.descrever().contains('84%'), 'a bateria devia aparecer');
  ok('status do aparelho descreve só o que foi lido');

  // 11. Notificação e contato vindos do Android.
  final notificacao = NotificacaoAparelho.deMapa({
    'app': 'WhatsApp',
    'titulo': 'Ana',
    'texto': 'chegou',
    'hora': '2026-11-19T10:00:00Z',
  });
  exigir(notificacao?.app == 'WhatsApp', 'a notificação devia ser lida');
  final contato = ContatoAparelho.deMapa({
    'nome': 'Ana Paula',
    'telefones': ['+55 11 99999-8888'],
  });
  exigir(contato?.primeiroTelefone.contains('99999') == true,
      'o telefone do contato devia ser lido');
  final contatoLido = contato!;
  ok('notificações e contatos do aparelho convertidos');

  // 12. Ficha criada a partir do contato nasce sem consentimento.
  final ficha = fichaDeContato(contatoLido,
      agora: DateTime.utc(2026, 11, 19, 12));
  exigir(ficha.nome == 'Ana Paula', 'a ficha devia herdar o nome');
  exigir(!ficha.consentimento, 'a ficha não pode nascer com consentimento');
  exigir(ficha.preferencias.isEmpty, 'nada pode ser preenchido sozinho');
  exigir(ficha.contatos.contains('99999'), 'o telefone devia ir para a ficha');
  ok('ficha de contato nasce vazia e sem consentimento');

  // 13. Perguntas básicas da pessoa.
  exigir(perguntasBasicasPessoa.length == 5,
      'deviam existir 5 perguntas básicas');
  exigir(
      perguntasBasicasPessoa.any((p) => p.toLowerCase().contains('relação')),
      'a relação devia ser perguntada');
  exigir(
      perguntasBasicasPessoa.any((p) => p.toLowerCase().contains('consentimento')),
      'o consentimento devia ser perguntado');
  ok('perguntas básicas incluem relação e consentimento');

  // 14. Resultado do Android nunca inventa sucesso.
  final resposta = ResultadoAparelho.deMapa({'ok': true, 'mensagem': 'feito'});
  exigir(resposta.ok && resposta.mensagem == 'feito',
      'o resultado ok devia ser respeitado');
  final falha = ResultadoAparelho.deMapa(null);
  exigir(!falha.ok, 'sem resposta do Android não existe sucesso');
  ok('resultado do Android é obrigatório para declarar sucesso');

  // 15. Link do Spotify vira URI exata.
  exigir(
      uriSpotify('toca spotify:track:4uLU6hMCjMI75M1A2tKUQC') ==
          'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
      'a URI spotify:track: devia ser preservada');
  exigir(
      uriSpotify(
              'toca https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC no Spotify') ==
          'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
      'o link open.spotify.com devia virar URI');
  exigir(uriSpotify('toca Bohemian Rhapsody') == '',
      'sem link não existe URI para inventar');
  ok('link e URI do Spotify reconhecidos sem inventar identificador');

  // 16. Pedido com link mantém a URI e limpa o nome.
  final comLink = interpretarSpotify(
      'toca Bohemian Rhapsody https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC no Spotify');
  exigir(comLink != null && comLink.acao == AcaoSpotify.tocar,
      'o pedido com link não foi reconhecido');
  exigir(comLink!.uri == 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
      'a URI não foi para o pedido');
  exigir(comLink.faixa.toLowerCase().contains('bohemian rhapsody'),
      'a faixa devia continuar no pedido e veio "${comLink.faixa}"');
  ok('pedido com link leva a URI exata e o nome da faixa');

  // 17. A conferência aceita o que é a faixa pedida.
  exigir(
      faixaConfere('Bohemian Rhapsody',
          titulo: 'Bohemian Rhapsody', artista: 'Queen'),
      'título igual devia conferir');
  exigir(
      faixaConfere('bohemian rhapsody',
          titulo: 'Bohemian Rhapsody - Remastered 2011', artista: 'Queen'),
      'título contido devia conferir');
  exigir(
      faixaConfere('queen bohemian',
          titulo: 'Bohemian Rhapsody', artista: 'Queen'),
      'todas as palavras no título/artista deviam conferir');
  ok('conferência aceita título igual, contido e palavras do artista');

  // 18. A conferência recusa outra música — o Jarvis não mente "tocando".
  exigir(
      !faixaConfere('Bohemian Rhapsody',
          titulo: 'Love of My Life', artista: 'Queen'),
      'outra música não pode ser confirmada como a pedida');
  exigir(!faixaConfere('', titulo: 'Bohemian Rhapsody'),
      'pedido vazio não confirma nada');
  exigir(!faixaConfere('Bohemian Rhapsody', titulo: ''),
      'sem título do Spotify não existe confirmação');
  ok('sem correspondência o Jarvis não declara a faixa tocando');

  print('\nAparelho conectado: $checks grupos de verificação aprovados.');
}
