# Ajuste 087 — flip-to-shush e modo noturno com os sensores do aparelho

Data: 2026-11-21 · Versão: 1.74.0+17400 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido

Seguir o roadmap do comparativo com o U.L.T.R.O.N. 2.0: flip-to-shush (virar o
celular para calar) e modo noturno, usando os sensores e o brilho do próprio
aparelho.

## 2. O que existia

- A voz do JARVIS roda em dois lugares: `JarvisVoz` na tela (`MainActivity`) e no
  serviço de palavra de ativação (`KwsForegroundService`), com timbre fixo.
- Não havia leitura de sensor nenhum no app Flutter: nenhum acelerômetro, nenhum
  gesto. O brilho era sempre o do sistema.

## 3. O que foi feito

### Flip-to-shush

- **`JarvisSensores.kt`** lê o acelerômetro do aparelho
  (`TYPE_ACCELEROMETER`, `SENSOR_DELAY_NORMAL`). Celular de bruços é Z ≤ −8,0;
  para rearmar é preciso voltar a Z ≥ −4,0 (histerese) e há intervalo mínimo de
  1,2 s entre avisos — virar de lado não cala duas vezes.
- **`MainActivity`** liga o vigia só com a opção ativa e a tela na frente; ao sair
  (`onPause`) o sensor é desregistrado para não gastar bateria.
- **O gesto calam as duas vozes**: a da tela (`voz?.parar()`) e a do serviço, por
  um `ACTION_CALAR` que para a síntese, encerra a escuta do comando e devolve o
  microfone ao detector de palavra.
- A conversa em streaming é interrompida quando o gesto acontece, e a tela mostra
  o aviso “JARVIS calado pelo gesto do aparelho”.

### Modo noturno

- **Brilho na janela do app** (10–100%) com
  `WindowManager.LayoutParams.screenBrightness`; `BRIGHTNESS_OVERRIDE_NONE`
  devolve o controle ao sistema. Mudar o brilho do aparelho exigiria
  WRITE_SETTINGS, que o app **não** pede.
- **Voz mais suave**: `JarvisVoz` passa `KEY_PARAM_VOLUME` em 45% no modo
  noturno, sem silenciar de vez.
- Estado guardado em `SharedPreferences` (`jarvis_gestos`), reaplicado ao abrir o
  app (`onResume`) e ao voltar de outra tela.

### Tela e transparência

- **Nova tela “Gestos e modo noturno”** (módulo no catálogo, atalho na gaveta,
  rota na home): estado real, interruptor de virar para calar (travado e
  explicado sem acelerômetro), interruptor e controle de brilho do modo noturno,
  botão “Calar agora” e a lista de limites.
- Fora do Android, o canal não existe e a tela explica em vez de mostrar opção
  que não funciona.

## 4. Evidência

- `flutter analyze` → `No issues found!`
- `flutter test` → `+209: All tests passed!` (inclui os 5 casos de
  `gestos_page_test.dart`)
- Teste puro com asserções ligadas:
  `dart --enable-asserts run tool/gestos_test.dart` → OK
- Contrato `tests/test_gestos_flutter.py` dentro de `npm run test:all`
- APK release arm64: `JARVIS-Nova-1.74.0-gestos.apk`, 117 973 900 bytes,
  SHA-256 `9558e635589cb14de2db40c8e4af42d8e1644ddb06f33bf8872b1436bf89ab19`
  (https://files.catbox.moe/0btv8l.apk).

## 5. Arquivos

- `flutter_app/android/JarvisSensores.kt` (novo): acelerômetro, histerese,
  preferências de gesto e modo noturno.
- `flutter_app/android/MainActivity.kt`: canal `sensores`, brilho da janela,
  vigia e `calarTudo`.
- `flutter_app/android/KwsForegroundService.kt`: `ACTION_CALAR`.
- `flutter_app/android/JarvisVoz.kt`: volume do modo noturno.
- `flutter_app/lib/core/gestos.dart` (novo): regra pura do gesto, brilho seguro e
  limites.
- `flutter_app/lib/services/sensores_service.dart` e `gestos_page.dart` (novos).
- `flutter_app/lib/home_screen.dart`, `drawer.dart`, `catalog.dart`: navegação e
  reação ao gesto.
- `flutter_app/lib/services/voice_conversation_page.dart`: interrupção da
  resposta no gesto.
- `flutter_app/tool/prepare_android_sistema.py`: copia `JarvisSensores.kt`.
- Testes: `tool/gestos_test.dart`, `test/gestos_page_test.dart`; contrato
  `tests/test_gestos_flutter.py`.

## 6. Não verificado

- **Nenhum aparelho físico nesta sessão**: o gesto real (ângulo, tempo, falso
  positivo ao deitar o celular na mesa), o silenciamento das duas vozes e o
  brilho percebido não foram medidos.
- O sensor só atua com a tela do JARVIS na frente; com o app fechado o gesto não
  existe.
- O brilho vale só na janela do JARVIS, não no sistema inteiro.
- No modo noturno a voz depende do volume de mídia do aparelho; se estiver mudo,
  continua muda.
- Nada foi commitado nem enviado.
