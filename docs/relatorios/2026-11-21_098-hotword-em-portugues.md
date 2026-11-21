# Ajuste 098 — hotword em português

Data: 2026-11-21 · Versão: 1.84.0+18400 · Branch: `work/1.84.0-bloco-098`

## 1. Pedido do usuário

Fazer o bloco da hotword em português, a próxima lacuna do comparativo do
U.L.T.R.O.N., e dizer antes o que muda na ativação por voz.

## 2. O que a lacuna realmente era

O comparativo dizia: “Hotword fonético com variações — KWS com aliases (Javis,
Jarve, Charles…) — **Parcial** (modelo inglês, sem modelo pt-BR)”. O problema
não era falta de detector: era que a lista de palavras existia só no
`keywords.txt` empacotado, escrita à mão em inglês, e a pessoa não tinha como
dizer ao JARVIS como ela chama nem como ela pronuncia.

O modelo acústico disponível (GigaSpeech, do sherpa-onnx) continua sendo
treinado em inglês — não existe modelo público de KWS em português. Então o
bloco **não troca o modelo**: ele coloca as frases em português do Brasil em uma
tabela única, deixa a pessoa escolher quais valem e leva a escolha ao motor,
inclusive com o app fechado. Isso é declarado como limite, não escondido.

## 3. O que foi feito

### Tabela única em Dart

- **`lib/core/hotword_portugues.dart`** (novo): 15 frases com id estável,
  escrita, dica de pronúncia, grupo e a **linha tokenizada** que o detector
  entende.
  - **O nome**: Jarvis, Javis, Jarvi, Jarve, Jarviz, Jarves, Javi, Javali.
  - **Chamando com tratamento**: “Ei Jarvis”, “Oi Jarvis”, “Alô Jarvis”,
    “Olá Jarvis” — as que estavam faltando.
  - **Apelidos que o modelo já aceitava**: Charles, Chales, Chale.
  - `nomeAmigavel` traduz o que o detector devolveu (`▁E I ▁JA R VI S`) para
    “Ei Jarvis”.
- **`lib/services/hotword_store.dart`** (novo): grava os ids escolhidos em
  `jarvis.hotword.ativos` e as linhas tokenizadas em `jarvis.hotword.linhas`.
  É preferência, não segredo: fica fora do cofre de chaves.

### Escolha na tela

- **`kws_settings_page.dart`**: card “Palavras que acordam o JARVIS”, agrupado,
  com a pronúncia de cada frase, contador (“N de 15 ligadas”) e o limite de 16
  frases ao mesmo tempo. Ligar ou desligar grava e religa o detector na hora.
  A tela não deixa zerar: sem frase nenhuma a escuta ficaria muda.
- **Padrão inalterado**: as 11 frases antigas continuam ligadas de fábrica; as
  quatro com “ei/oi/alô/olá” vêm desligadas, porque cada palavra extra custa
  processamento e abre espaço para disparo por engano.
- O texto de limitação passou a dizer, em letras claras, que o modelo é inglês e
  que “Ei Jarvis” chega a ele como sons parecidos com palavras inglesas.

### Nativo

- **`JarvisKwsEngine.java`**: novo construtor de cinco argumentos (o antigo de
  quatro continua, para o `JarvisService` legado), campo `linhasHotword` e
  `gravarPalavrasChave(dir)`:
  - só aceita linha cujos **tokens existem no `tokens.txt`** do modelo — linha
    inválida faria o `KeywordSpotter` falhar na criação do stream;
  - grava em `keywords.txt.part` e renomeia (troca atômica);
  - sem linha válida, o `keywords.txt` dos assets continua valendo;
  - o diagnóstico passa a mostrar as frases **realmente em uso**, em letras
    comuns, via `fraseLegivel`.
- **`KwsForegroundService.kt`**: lê as linhas de `FlutterSharedPreferences`
  (`flutter.jarvis.hotword.linhas`), como já faz com o consentimento de
  acessibilidade; `aplicarHotword` reinicia o detector pelo caminho de
  `ACTION_REINICIAR`, que espera o `AudioRecord` fechar.
- **`MainActivity.kt`**: método `aplicarHotword` no canal `com.jarvis.nova/kws`
  e `hotword` (quantidade em uso) no diagnóstico.

## 4. Evidência

- `test/hotword_portugues_test.dart`: lê o `tokens.txt` real do APK e confere
  **token por token** que toda frase é montável; confere também que os tokens
  reconstroem a palavra escrita, que não há id nem linha repetida, que o padrão
  tem 11 frases e que as quatro frases de tratamento existem.
- `test/hotword_store_test.dart`: padrão sem nada gravado, gravação das linhas
  para o Android, descarte de id desconhecido e restauração do padrão.
- `test/hotword_page_test.dart`: card na tela, padrão ligado, ligar “Ei Jarvis”
  grava e chama o detector, e desligar a última frase é recusado com aviso.
- `tests/test_hotword_portugues.py`: contrato estático que prende a tabela ao
  `tokens.txt`, o conjunto de fábrica ao `keywords.txt`, o limite de 16 dos dois
  lados, a leitura das preferências pelo Kotlin e as proibições de sempre.
- `flutter analyze` sem avisos e `flutter test` com a suíte inteira verde.

## 5. O que muda na ativação por voz

- **Nada muda para quem não abrir a tela.** As 11 frases de fábrica continuam
  iguais; o `keywords.txt` empacotado não foi reescrito.
- **Passa a existir escolha.** Em “Voz e palavra de ativação” aparecem as 15
  frases com a pronúncia de cada uma; ligar “Ei Jarvis”, “Oi Jarvis”, “Alô
  Jarvis” ou “Olá Jarvis” faz o detector aceitar a frase inteira (duas palavras)
  em vez de só o nome.
- **A escolha vale com o app fechado**, porque o serviço lê as linhas gravadas
  pelo Flutter antes de abrir o microfone.
- **A ativação passa a ser nomeada**: a tela mostra “Última ativação recebida:
  Ei Jarvis” em vez da linha de tokens.
- **O que não muda**: o modelo continua inglês, o áudio continua sendo
  processado no aparelho e nenhum som sai do celular antes da palavra-chave.
  Mais frases ligadas = mais processamento e mais chance de disparo por engano;
  por isso o teto de 16 e o padrão conservador.

## 6. Não verificado

- **Nada compilado**: sem Android SDK nesta sessão. O `JarvisKwsEngine.java` e o
  `KwsForegroundService.kt` alterados só serão provados no CI com
  `flutter build apk`.
- **Nada executado em aparelho**: não há microfone real aqui. A taxa de acerto
  de “Ei Jarvis” dita em português brasileiro **não foi medida** — é exatamente
  o número que depende do aparelho e da voz.
- **Tokenização**: os tokens foram conferidos contra o `tokens.txt` (cada token
  existe), mas a segmentação BPE foi escrita à mão a partir do vocabulário; o
  `sherpa-onnx-cli text2token` não está instalado aqui para repetir a geração.
  Se o CI rodar `preparar_kws.py` do zero, o `keywords.txt` dos assets é
  regenerado só com as frases antigas — a seleção da tela continua sendo
  aplicada em tempo de execução por cima dele.
- **Som do “Olá”**: o `Á` não existe no vocabulário do modelo; a linha usa
  `▁O LA`, que é o som sem acento. Se o detector não aceitar, desligar a frase
  na tela devolve o comportamento anterior.

## 7. Arquivos

- Novos: `lib/core/hotword_portugues.dart`, `lib/services/hotword_store.dart`,
  `test/hotword_portugues_test.dart`, `test/hotword_store_test.dart`,
  `test/hotword_page_test.dart`, `tests/test_hotword_portugues.py`, este
  relatório.
- Alterados: `JarvisKwsEngine.java`, `KwsForegroundService.kt`, `MainActivity.kt`,
  `kws_bridge.dart`, `kws_controller.dart`, `kws_settings_page.dart`,
  `test/kws_controller_test.dart`, `test/kws_sensibilidade_page_test.dart`,
  `pubspec.yaml`, `CHANGELOG.md`, `docs/INVENTARIO_DE_FUNCOES.md`,
  `docs/COMPARATIVO-ULTRON.md`, `package.json`.
