# Ajuste 082 — microfone confiável e resposta antes de reouvir (Fase 14)

## 1. Identificação

- **Versão:** 1.69.0+16900
- **Data:** 2026-11-20
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** `JARVIS-Nova-1.69.0-microfone.apk` (arm64, release, 117 825 904 bytes)
- **SHA-256:** `793fd0d8b7e4ffdb1ace54dd889c486ac6e6a69250c14ee8a02a5b013364f51b`
- **Download:** https://files.catbox.moe/9w7v9z.apk
- **Plataformas afetadas:** Android (Kotlin, Java nativo e Flutter/Dart). Windows não foi tocado.

## 2. Resumo do ajuste

O bloco 080 tratou sintomas do “Não consegui entender o comando”: dois
microfones ao mesmo tempo, comando curto cortado e tela bloqueada. Mesmo assim a
falha continuou no aparelho. Revisando o caminho do áudio, sobrou **uma corrida
que nenhuma das correções anteriores fechava**:

- quando a palavra de ativação era ouvida, o app pedia ao serviço para pausar o
  detector com um **Intent** — e seguia em frente sem esperar;
- o `AudioRecord` do detector só era fechado depois, na thread do serviço;
- o reconhecedor do comando era criado e chamava `startListening` **antes** disso.

Com dois `AudioRecord` abertos, o que chega ao reconhecedor é silêncio — e o
Android responde `ERROR_NO_MATCH`/`ERROR_AUDIO` com a fala mais clara possível.
Era exatamente a mensagem que continuava aparecendo.

Agora a entrega do microfone é **confirmada**: o detector encerra, o app espera o
`AudioRecord` fechar de verdade (prazo de 1,5 s, fora da thread principal) e só
então abre o reconhecedor, com uma folga curta para o Android reabrir a captura.

Junto com isso, o comando ficou mais difícil de perder: microfone ocupado também
tem nova tentativa, o que já foi reconhecido em parcial vira o comando, a fala
fraca ganha ganho automático no detector e, no segundo plano, a resposta é falada
**antes** de a palavra de ativação voltar — antes o JARVIS voltava a ouvir com o
próprio áudio no ar.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivo |
|---|---|---|---|
| Entrega do microfone | correção | `pararEAguardar(prazo)` encerra e confirma o `AudioRecord` fechado; `microfoneLivre()` diz se pode abrir outro | `JarvisKwsEngine.java` |
| Ponte do serviço | correção | `liberarMicrofone(esperaMs)` para qualquer thread, com o motor atual guardado em `motorAtual` | `KwsForegroundService.kt` |
| Abertura do comando | correção | `abrirMicrofoneDoComando()` espera a confirmação e só depois `iniciarEscutaDoComando()` abre o reconhecedor | `MainActivity.kt` |
| Repetição por erro | melhoria | `ERROR_AUDIO`, `ERROR_RECOGNIZER_BUSY` e `ERROR_CLIENT` entram na repetição; folga de 800 ms para microfone ocupado e 350 ms para silêncio | `MainActivity.kt` |
| Parcial aproveitado | melhoria | o melhor resultado parcial vira o comando quando o reconhecedor falha no fim | `MainActivity.kt`, `JarvisEscutaFundo.kt` |
| Ganho automático | melhoria | até 4x em fala fraca, 1x em fala normal, transição suave e sinal limitado a ±1 | `JarvisKwsEngine.java` |
| Detector não religa | correção | `iniciarMotor` recusa com comando ativo e rearma depois | `KwsForegroundService.kt` |
| Repetição no segundo plano | melhoria | `onErroRepetivel` decide a nova escuta; nada é falado durante a escuta | `KwsForegroundService.kt`, `JarvisEscutaFundo.kt` |
| Resposta antes de reouvir | correção | `UtteranceProgressListener` avisa o fim da fala; sem confirmação, espera proporcional ao texto | `JarvisVoz.kt`, `KwsForegroundService.kt` |
| Estado ao fechar a tela | correção | `onDestroy` limpa `recognitionInProgress` e o parcial, para a próxima ativação não achar que há comando em curso | `MainActivity.kt` |
| Contratos | melhoria | novo `test_microfone_confiavel_flutter.py`; contrato 080 aceita a entrega confirmada | `tests/` |

Regras de honestidade aplicadas:

- **Continua só o reconhecedor offline do Android.** Nenhum `createSpeechRecognizer`
  e nenhuma nuvem; os contratos falham se aparecerem.
- **Erro não vira sucesso.** Quando nada foi entendido, a mensagem é de falha e o
  histórico registra “Não executado”.
- **A espera tem prazo.** Se o microfone não ficar livre em 1,5 s, o comando tenta
  mesmo assim (com folga maior) e o erro real é dito — nada de laço infinito.
- **Nada de permissão nova, dependência nova, `GlobalScope` ou shell.**

## 4. Evidência

| Prova | Comando | Resultado |
|---|---|---|
| Preparação do runner | `baixar_sherpa.py`, `preparar_kws.py`, `prepare_android_kws.py`, `prepare_android_sistema.py` | Runner montado |
| Compilação Kotlin/Java | `flutter build apk --release --target-platform android-arm64` | Construído (117 825 904 bytes). A primeira tentativa falhou na compilação Kotlin (`detectorAtual()` público expondo tipo interno); removida a função, o build passou |
| Análise estática | `flutter analyze` | Sem nenhum aviso (`No issues found`) |
| Suíte Flutter | `flutter test` | **191 testes aprovados** |
| Contrato novo | `python3 tests/test_microfone_confiavel_flutter.py` | Aprovado |
| Contratos de apoio | `test_microfone_fundo_flutter.py`, `test_fundo_flutter.py`, `test_status_celular_flutter.py`, `test_comandos_android.py`, `test_seguranca_flutter.py`, `test_historico_voz_flutter.py` | Todos aprovados |
| Suíte completa | `npm run test:all` | **Aprovada** (todos os passos, `EXIT_TEST_ALL=0`) |

## 5. Limites conhecidos

- **Sem aparelho.** A confirmação de entrega do microfone, o ganho automático e a
  nova tentativa por microfone ocupado estão provados por compilação e contrato,
  **não** por voz real no Poco X7.
- **Uma repetição por comando** na tela e uma no segundo plano; se as duas
  falharem, a mensagem pede para chamar o JARVIS de novo.
- **O pacote offline de português precisa estar instalado.** Sem ele não há
  transcrição: o app explica o caminho e não usa nuvem.
- **A espera de 1,5 s é um teto.** Em aparelho muito lento, o `AudioRecord` pode
  demorar mais; nesse caso a segunda tentativa existe justamente para isso.
- **O ganho automático não é cancelamento de ruído.** Em ambiente muito barulhento
  ele ajuda a fala fraca, mas não separa voz de ruído.

## 6. Não verificado

- Voz real, sotaque, distância do microfone e ruído no Poco X7.
- Se o pacote offline de português está instalado no aparelho.
- Comportamento do HyperOS ao segurar o serviço em primeiro plano com o microfone.
- Se a voz sintetizada do aparelho dispara mesmo o `UtteranceProgressListener` e
  com que atraso.
- Preenchimento do histórico e da tela de status com o comando falado no aparelho.

## 7. Próximo passo sugerido

Instalar o APK e conferir, nesta ordem: (1) dizer “Jarvis” e “abre o WhatsApp”
com o app aberto; (2) repetir três vezes seguidas para ver a entrega do microfone
a cada ativação; (3) falar baixo, de longe, para ver o ganho automático; (4)
fechar o app, chamar “Jarvis” e pedir a lanterna, esperando a resposta terminar
antes de chamar de novo; (5) repetir com o celular em modo silencioso; (6) abrir
Comandos do Android → Histórico e conferir o resultado de cada tentativa.
