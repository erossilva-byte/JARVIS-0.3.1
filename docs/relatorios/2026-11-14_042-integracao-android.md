# Ajuste 042 — integração com o sistema Android (2026-11-14)

## Por que

O item 11 da Fase 5 (atalhos do ícone, widget e compartilhar) estava pendente por depender de
código Android. Este ajuste entrega a parte nativa e a ponte com o Flutter, pronta para o CI
compilar; o que não dá para fazer aqui é instalar e olhar no aparelho.

## O que foi feito

### Atalhos do ícone

`android/sistema/res/xml/shortcuts.xml` declara três atalhos estáticos: **Falar com o Jarvis**,
**Nova conversa** e **Histórico**. Cada um dispara uma ação (`com.jarvis.nova.ACAO_VOZ`,
`...ACAO_CONVERSA`, `...ACAO_HISTORICO`) recebida pelo `MainActivity`.

### Widget da tela inicial

`JarvisWidgetProvider.kt` + `res/layout/jarvis_widget.xml`: mostra o último estado conhecido do
KWS e dois botões (FALAR e CONVERSA). O estado chega pelo canal do app; sem atualização, o widget
mostra “JARVIS pronto” em vez de inventar que está tudo certo. `updatePeriodMillis=0` porque o
estado é empurrado pelo app, não pesquisado em segundo plano.

### Compartilhar

- **Para fora**: `SistemaAndroid.compartilhar` abre a folha do sistema via `ACTION_SEND`.
- **Para dentro**: filtro `ACTION_SEND` + `text/plain` no `MainActivity`; o texto recebido abre a
  conversa já preenchida.
- A tela de conversa ganhou o botão de compartilhar o histórico inteiro.

### Ponte Flutter ↔ Android

Canal `com.jarvis.nova/sistema` com `intencaoPendente` (o que abriu o app), `compartilhar` e
`atualizarWidget`. Com o app já aberto, o Android envia a intenção como chamada `intencao` para o
Dart. A intenção é consumida ao ser lida (`action` volta para `MAIN` e o texto é removido), para
girar a tela não repetir o pedido.

No Flutter, `SistemaAndroid` escuta as intenções e a tela principal decide: voz → tela cheia,
histórico → lista, conversa → tela vazia, compartilhar → conversa com o texto. Fora do Android
(Windows e testes), o canal não existe, as chamadas devolvem `false` e nada quebra.

### Preparação do runner

O runner Android nasce do `flutter create` no CI. `tool/prepare_android_sistema.py` copia recursos
e Kotlin, e ajusta o manifesto de forma **idempotente**: filtros e meta-data de atalhos na
atividade, receptor do widget na aplicação. O script confere o XML resultante e recusa runner
incompleto; rodar duas vezes não duplica nada. O workflow ganhou a etapa correspondente.

## Verificação

```
python3 tests/test_sistema_android.py  → 5 casos, OK
flutter analyze                        → No issues found!
flutter test                           → 43 testes, All tests passed!
python3 ci/preflight_android.py        → 23 classes, 6 workflows, consistente
npm run verificar                      → ver abaixo
```

Os casos Python montam um runner falso, rodam o script e conferem manifesto, atalhos, layout,
receptor e idempotência. Os testes Dart usam o canal simulado para provar que a intenção
pendente é consumida, o compartilhamento com o app aberto vira evento, e cada ação abre a tela
certa — sem depender de Android.

## Limites

- Nenhum APK foi compilado aqui: não há Android SDK nem aparelho. A compilação e o comportamento
  real (launcher, widget, folha de compartilhamento) só se confirmam no CI e no Poco X7.
- O widget não foi visto renderizado; o layout usa apenas componentes aceitos por `RemoteViews`.
- Painel rápido (Quick Settings) e notificação própria do serviço não entraram: não estavam no
  pedido.
- O atalho “Histórico” depende de o app ter armazenamento local disponível; sem ele, a tela
  principal avisa em vez de abrir uma lista vazia.
