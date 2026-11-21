# 084 — sentinela de mensagens: responder e ouvir sem abrir o app

**Versão:** 1.71.0+17100 · **Data:** 2026-11-21 · **Bloco:** 084
**Pedido:** comparar as funções do U.L.T.R.O.N. 2.0 com as do JARVIS e
adicionar as que faltam.

## 1. O que a comparação mostrou

O comparativo completo está em `docs/COMPARATIVO-ULTRON.md`. Resumo: o JARVIS
já tem equivalente ou algo melhor em controle do aparelho, voz, memória local,
pessoas, visão e segurança básica. As ausências reais eram de **conveniência de
mensagens** e **automação**. A mais barata e de maior efeito era a sentinela:
ler as mensagens em voz alta e responder pela própria notificação.

## 2. O que mudou

### Android
- `JarvisNotificacaoListener.kt`
  - guarda `chave`, `pacote` e `respondivel` por notificação;
  - mantém as notificações vivas que aceitam resposta, por chave, até 40;
  - `responder(chave, texto, pacote)` injeta o texto pelo `RemoteInput` da
    notificação e entrega pelo `PendingIntent` dela — o aplicativo não abre;
  - recusa explícita quando o serviço não está conectado, quando não há campo de
    resposta, quando a notificação já saiu ou quando o app recusa o envio;
  - notificação fixa (`FLAG_ONGOING_EVENT`) e notificação removida ficam fora da
    lista de respostas.
- `JarvisAparelho.kt`: novo método `responderNotificacao` no canal do aparelho.
- `tool/prepare_android_sistema.py`: `JarvisAparelho.kt` e
  `JarvisNotificacaoListener.kt` passaram a ser copiados para o projeto Android
  (antes existiam só na pasta gerada, com risco de sumirem em instalação limpa).

### Flutter
- `core/aparelho.dart`: `chave`, `pacote`, `respondivel`, `fraseLeitura`,
  `notificacaoParaResponder()` e `frasesDeLeitura()` — tudo puro e testável.
- `services/aparelho_service.dart`: `responderNotificacao()`.
- `services/aparelho_page.dart`: botão de responder por mensagem (só quando o
  Android informou campo de resposta), diálogo de resposta com estado próprio,
  botão “Ler em voz alta” e alto-falante por linha.

## 3. O que foi feito

Arquivos tocados: `JarvisNotificacaoListener.kt` (novo, com resposta por
`RemoteInput`), `JarvisAparelho.kt` (método `responderNotificacao`),
`prepare_android_sistema.py` (cópia dos dois arquivos nativos),
`core/aparelho.dart` (chave, pacote, respondível, escolha e frases),
`aparelho_service.dart`, `aparelho_page.dart` (botões, diálogo e leitura),
`tool/aparelho_resposta_test.dart`, `test/aparelho_sentinela_test.dart`,
`tests/test_sentinela_mensagens_flutter.py`, versão, CHANGELOG, inventário e
`docs/COMPARATIVO-ULTRON.md`.

## 4. Evidência

| Verificação | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `dart run tool/aparelho_resposta_test.dart` | aprovado (6 grupos puros) |
| `flutter test test/aparelho_sentinela_test.dart` | 3 testes aprovados |
| `flutter test` (suíte inteira) | `+199: All tests passed!` |
| `python3 tests/test_sentinela_mensagens_flutter.py` | contrato aprovado |
| `npm run test:all` | `EXIT_TEST_ALL3=0` |
| `flutter build apk --release --target-platform android-arm64` | APK de 117 826 044 bytes |

APK release arm64: `JARVIS-Nova-1.71.0-sentinela.apk`,
SHA-256 `e72255d495a29fe916221efce0a4c0e4a8dbb317cfc5ec1d1b84e022cdb0b7f1`,
disponível em https://files.catbox.moe/c4gg1s.apk.

## 5. Como usar

1. Autorize o acesso a notificações em Configurações → Notificações → JARVIS Nova.
2. Abra a aba CELULAR.
3. Em **NOTIFICAÇÕES DO APARELHO**, toque no alto-falante de uma linha para ouvir
   aquela mensagem, ou em **Ler em voz alta** para ouvir as cinco mais recentes.
4. Nas mensagens com campo de resposta aparece o ícone de responder: escreva e
   toque em **Enviar**. O WhatsApp/Telegram não abre.

## 6. Não verificado

- **Nenhum aparelho físico foi usado.** O envio real no WhatsApp, Telegram, SMS,
  Signal e Discord depende da versão de cada app e do campo de resposta que ele
  publica na notificação.
- O áudio da leitura em voz alta depende da voz pt-BR instalada no aparelho.
- HyperOS pode limitar o serviço de notificações em segundo plano.
- Nada aqui envia áudio ou mensagem para a nuvem além do próprio app de mensagem.

## 7. Fechamento

O que dá para afirmar sem aparelho: a notificação agora carrega chave e campo de
resposta, a resposta é entregue pelo `RemoteInput` com recusa explícita em todos
os caminhos de falha, a escolha da mensagem é determinística e a leitura em voz
alta usa só o que veio do Android. O que só o aparelho diz: se o WhatsApp aceita
o campo e se a voz instalada lê bem as mensagens.
