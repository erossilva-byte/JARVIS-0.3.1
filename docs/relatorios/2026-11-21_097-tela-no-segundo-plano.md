# Ajuste 097 — comandos de tela com o app fechado

Data: 2026-11-21 · Versão: 1.83.0+18300 · Branch: `work/1.83.0-bloco-097`

## 1. Pedido do usuário

Ligar os comandos de tela ao segundo plano, com o app fechado, mantendo a
confirmação antes de tocar e o mesmo consentimento.

## 2. Por que não foi só reaproveitar o ajuste 096

Com o app fechado não existe motor Flutter no caminho: o serviço de palavra de
ativação (`KwsForegroundService`) ouve, interpreta e responde sozinho. A
confirmação também não pode ser um botão, porque não há tela — ela precisa ser
falada e ouvida.

Além disso, o consentimento mora nas preferências do app. O Flutter grava em
`FlutterSharedPreferences` com o prefixo `flutter.`, então o Kotlin lê
`flutter.jarvis.acessibilidade.ativo` e considera ausência como desligado.

## 3. O que foi feito

### Nativo

- **`JarvisTelaVoz.kt`** (novo):
  - interpreta o mesmo escopo estreito — ler, tocar, rolar e parar — com as
    mesmas regras do decisor Dart: pergunta (“como…”, “por que…”) não vira ação,
    toque exige preposição (“toque de recolher” é conversa) e alvo genérico
    (“botão”, “tela”) é recusado;
  - consentimento lido de `FlutterSharedPreferences`;
  - execução pelos métodos estáticos de `JarvisAcessibilidade` (ler, tocar,
    rolar, parar), sem digitar e sem shell;
  - leitura falada em resumo curto, sem “campo de texto” e sem repetidos.
- **`KwsForegroundService.kt`**:
  - a resposta da confirmação é tratada **antes** de qualquer outro comando;
  - comando de tela é avaliado **antes** da pergunta livre (senão “ler a tela”
  ia para a IA);
  - `perguntarConfirmacaoTela` fala a pergunta, só abre o microfone quando a fala
    termina e marca um prazo de 20 s; sem resposta, o toque é descartado;
  - `finalizarComando` limpa a pendência: nada fica armado;
  - leitura, rolagem e toque rodam numa thread própria e voltam para a principal;
  - tudo entra no histórico com a origem “segundo plano”, inclusive a recusa por
    falta de consentimento.

### Preparo do app

`prepare_android_sistema.py` passou a copiar e conferir `JarvisTelaVoz.kt`, como
já fazia com `JarvisAcessibilidade.kt`.

## 4. Como fica o uso

Com o app fechado:

- “Jarvis, ler a tela” → ele lê o resumo em voz alta.
- “Jarvis, rolar para baixo” → rola e confirma.
- “Jarvis, tocar em Enviar” → ele pergunta “Posso tocar em Enviar na tela atual?
  Diga confirmar ou cancelar.”; “confirmar” executa, “cancelar” encerra, qualquer
  outra coisa ou 20 s de silêncio descartam o toque.

## 5. Testes e verificações

- Contrato novo `tests/test_tela_segundo_plano.py` (leitura estática) e
  `tests/test_acessibilidade.py` mantido.
- `python3 tool/prepare_android_sistema.py` rodou e copiou o arquivo novo.
- Contratos da suíte que prendem a versão passaram a apontar 1.83.0+18300.
- `flutter analyze` e `flutter test` continuam verdes (nenhuma linha Dart mudou
  neste bloco; a verificação foi repetida para garantir a árvore).

## 6. Não verificado

- **Nada compilado**: sem Android SDK nesta sessão; o Kotlin só será provado no
  CI com `flutter build apk`.
- **Nada executado em aparelho**: a confirmação falada depende do reconhecimento
  offline em português entender “confirmar”; se não entender, o toque é
  descartado — nunca executado no escuro.
- **Serviço de acessibilidade**: o caminho do fundo usa o mesmo serviço do
  ajuste 095; se ele não estiver autorizado, a resposta é a recusa explicada.
- **Atraso do alto-falante**: o microfone abre quando a síntese avisa que
  terminou; em aparelhos com TTS lento pode haver sobreposição — o prazo de 20 s
  limita o estrago, mas não foi medido.
