# Voz 1.42.0 — análise e aprimoramento do reconhecimento

> Versão: 1.42.0 (versionCode 10420). O APK é compilado pelo release workflow; a validação
> acústica em aparelho físico continua pendente.

## Resumo executivo

O problema principal não era falta de um modelo maior. O caminho normal de comando
usava um detector de energia simples, ignorava os controles de microfone salvos e
não permitia escolher entre o Whisper da Groq e o reconhecimento do Android. Além
disso, a ativação podia consumir um resultado parcial contendo apenas “Jarvis” e
perder o comando que chegaria no parcial seguinte.

Nesta rodada:

- a captura de comando passou a usar o VAD testável (`escuta.js`) e a entregar WAV;
- o áudio é reamostrado para 16 kHz mono antes do STT;
- o teto de fala subiu de 15 s para 20 s;
- os controles de eco, supressão de ruído, AGC e filtro agora chegam ao gravador;
- há um seletor real de motor: Automático, Groq, Android e Android local;
- uma falha 400 do Groq tenta o modelo turbo, sem repetir 429;
- um parcial só com a wake word não ativa mais o assistente;
- o diagnóstico mede duração, bytes e latência da captura.

A validação acústica continua bloqueada: não há microfone, aparelho físico nem
chave/rede da Groq nesta máquina. Portanto, não há taxa de acerto de campo, latência
de rede ou consumo no Poco X7 medidos.

## Problemas encontrados e causas

1. **O gravador normal ignorava as preferências de microfone.**
   `gravar()` criava `getUserMedia` com `echoCancellation`, `noiseSuppression` e
   `autoGainControl` fixos em `true`; os checkboxes salvos em `mic_ec`, `mic_ns` e
   `mic_agc` só valiam para o cadastro do perfil de locutor. O usuário desligava o
   AGC e o caminho de comando continuava com AGC.

2. **O caminho de comando não usava o VAD já testado.**
   `capturarAmostraVoz()` usava `EscutaJarvis` (pré-roll de 600 ms, confirmação,
   silêncio e teto), mas `gravar()` usava um detector RMS separado, com piso fixo
   nos primeiros 350 ms e sem atualização do ruído. Em ambiente barulhento o limiar
   podia ficar alto; em ambiente silencioso, um sopro podia iniciar a captura.

3. **Não havia escolha de mecanismo de STT.**
   O fluxo era Groq primeiro e Android depois, sem opção de forçar o reconhecedor
   local, o Android de rede ou somente o Whisper. Também não havia como declarar
   “não quero enviar áudio à nuvem” sem ativar o modo offline global.

4. **O fallback Android abria uma nova escuta mesmo quando o usuário escolhia Groq.**
   Uma falha do Whisper podia fazer o app pedir a frase novamente pelo Android,
   surpreendendo quem havia selecionado o motor de nuvem.

5. **A ativação podia perder o comando.**
   `conferirAtivacao()` aceitava qualquer parcial com a palavra. Se o Android
   devolvesse “Jarvis” e só depois “Jarvis, abre o Spotify”, o primeiro parcial
   consumia a ativação e o `aoAcordar()` recebia apenas o nome.

6. **O WAV subia em 48 kHz.**
   O VAD precisa da taxa nativa do `AudioContext` para decidir bem, mas o Whisper
   trabalha em 16 kHz. Enviar 48 kHz aumentava o upload em cerca de três vezes sem
   ganho de reconhecimento para fala.

7. **O diagnóstico mostrava latência, mas não o custo do áudio.**
   O teste de transcrição media o tempo total, porém não registrava duração do
   trecho nem bytes enviados, então não havia como separar latência de captura,
   rede e decodificação.

8. **Whisper local, whisper.cpp, faster-whisper e sherpa-onnx ASR não existem no APK.**
   O projeto empacota sherpa-onnx apenas para **TTS**. Não há runtime de ASR,
   modelo PT-BR, ponte nativa, RAM medida ou licença revisada para trocar o motor
   funcional. Isso não foi simulado.

## Melhorias implementadas

### Captura e VAD

- `escuta.js` ganhou `criarDetectorRms()`: piso adaptativo, calibração, confirmação
  de 180 ms, mínimo de fala, silêncio de 1 s, teto e sensibilidade configurável.
- `criarDetector()` no app usa esse módulo puro; o detector antigo só permanece como
  fallback se `escuta.js` não carregar.
- `gravar()` usa `gravarWav()` como caminho principal: VAD + PCM, sem depender do
  `MediaRecorder`; o `MediaRecorder` virou reserva para WebView sem
  `ScriptProcessor`/`AudioPcm`.
- O teto de captura passou para **20 s**, com até 5 s sem fala antes de desistir.
- `capturarAmostraVoz()` aceita opções de VAD e verifica `abortar` durante a captura,
  liberando o microfone quando o usuário toca em Parar.
- `vozMicConfig()` agora alimenta também o gravador normal; eco, ruído, AGC e filtro
  deixaram de ser apenas preferências de interface.

### Áudio para o STT

- `audio_pcm.js` ganhou `reamostrar()` com média de janela para downsample e
  interpolação para upsample.
- O WAV enviado é **16 kHz mono, 16 bits**, com cabeçalho RIFF conferido.
- O áudio bruto não é persistido; o WAV existe apenas como `Blob` em memória até o
  envio ou descarte.

### Motores e fallback

- Novo seletor em Ajustes ▸ Voz:
  - **Automático**: Groq quando há chave e internet; Android quando não há chave ou
    o modo offline está ligado.
  - **Groq Whisper**: envia à nuvem, sem fallback silencioso para o Android.
  - **Android**: `SpeechRecognizer` do aparelho, podendo usar rede.
  - **Android local**: exige o pacote de português offline e usa
    `somenteLocal: true`.
- `transcrever()` aceita o motor escolhido e só permite fallback Android no modo
  automático.
- Falha HTTP 400 do Groq tenta `whisper-large-v3-turbo` uma vez; HTTP 429 continua
  sem repetição automática para não consumir cota.
- O modo offline não envia áudio à nuvem e usa o Android local quando disponível.

### Wake word

- `JarvisAtivacao.temComando()` verifica se há conteúdo depois da palavra.
- `JarvisService` não dispara em parcial que contenha somente “Jarvis”; o resultado
  definitivo ainda pode ativar e pedir o comando em seguida.
- O pré-roll de 600 ms do VAD preserva a primeira sílaba na captura seguinte.

### Diagnóstico e medição

- O teste de transcrição registra `audioMs`, `bytes`, motor, confiança, WER e
  latência total.
- `FalaJarvis.metricas()` calcula captura média e upload médio.
- O diagnóstico de voz mostra o motor STT selecionado.
- O teste de ativação de 20 s e os descartes por ruído continuam disponíveis.

## Motores: comparação honesta

| Motor | Estado | Qualidade | Custo/limite |
|---|---|---|---|
| Groq `whisper-large-v3` | Implementado; selecionável | Melhor opção disponível no projeto, mas não medida aqui | Chave, internet, cota e envio do áudio |
| Groq `whisper-large-v3-turbo` | Implementado como fallback de 400 | Não comparado acusticamente | Mais rápido, potencialmente menos preciso |
| Android `SpeechRecognizer` de rede | Implementado; selecionável | Depende do fabricante/Google | Pode enviar áudio ao serviço do sistema |
| Android `createOnDeviceSpeechRecognizer` | Implementado; selecionável | Depende do pacote PT-BR offline | Áudio local; exige Android 12+ e pacote instalado |
| Whisper local / whisper.cpp / faster-whisper | Não implementado | Não medida | Sem runtime/modelo no APK |
| sherpa-onnx ASR | Não implementado | Não medida | Só o TTS sherpa está empacotado |

O app não troca o motor padrão por um modelo local não validado. A escolha continua
explícita e reversível.

## Testes executados

- `node tests/test_escuta.js`: **10** verificações de pré-roll, confirmação, blip,
  sem-fala, teto, sensibilidade e detector adaptativo.
- `node tests/test_fala.js`: **31** verificações de limpeza conservadora, confiança,
  alternativas, comando, WER e métricas de captura/upload.
- `node tests/test_audio_pcm.js`: RIFF/WAVE, 16 bits, clipping, duração e
  reamostragem 48 kHz → 16 kHz.
- `python3 tests/test_stt_avancado.py`: **24** verificações do caminho Java/app/UI,
  incluindo os quatro motores, WAV/VAD principal e toggles do microfone.
- `python3 tests/test_voz_ui.py`: **53** verificações de controles, perfis,
  diagnóstico e integração com o pacote.
- `python3 tests/test_voice_profile.py`: **19** verificações de consentimento,
  qualidade, três estados, privacidade e replay.
- `python3 tests/test_ativacao_propria.py`: paridade Java/JavaScript, 33 variantes,
  porteiro de ruído e trava de parcial sem comando.
- `npm run test:all`: **EXIT 0**, **2.083 linhas `OK`**, zero `FALHA`.
  Log: `artifacts/test-all-voz-1.42.log`.
- `git diff --check`: sem erros de whitespace.

### Medição local do VAD (sintética, Node)

Sinal de 15 s a 48 kHz, com fala de 5 s e ruído de fundo:

- detector RMS: **6,702 ms** para processar a janela;
- motivo de fim: `silencio`; fala contabilizada: 5.035 ms;
- WAV 48 kHz: **1.440.044 bytes**;
- WAV 16 kHz: **480.044 bytes**;
- RSS do processo Node: **75,7 MB**.

Esses números são do Node nesta VM. Não representam CPU, bateria, memória ou
latência do Poco X7.

## O que não foi medido

- Taxa de acerto acústica em PT-BR, sotaques, fala rápida/lenta, TV, música,
  ventilador, distância variável e nomes próprios.
- Latência real do Groq, do Android de rede e do Android local.
- Consumo de CPU, RAM, bateria e armazenamento no aparelho.
- Falsos positivos/negativos da wake word em campo.
- Identificação de locutor com vozes humanas e resistência real a replay.
- Barge-in e conversa contínua em aparelho.

O teste de WER da camada de texto não é acurácia de STT. Ele apenas confirma que a
comparação esperado × reconhecido funciona (frase idêntica = 0% de erro; uma
substituição em três palavras = 33,33% de WER).

## Classificação final

| Recurso | Classificação |
|---|---|
| VAD adaptativo e pré-roll | IMPLEMENTADO E TESTADO (unidade/sintético) |
| Captura WAV/VAD como caminho principal | IMPLEMENTADO E TESTADO (unidade/contrato) |
| Reamostragem 16 kHz e teto de 20 s | IMPLEMENTADO E TESTADO (unidade) |
| Controles de eco/ruído/AGC no gravador | IMPLEMENTADO, MAS NÃO TESTADO acusticamente |
| Seletor de motor STT | IMPLEMENTADO E TESTADO (contrato/UI) |
| Groq Whisper large-v3/turbo | IMPLEMENTADO, MAS NÃO TESTADO com chave/rede |
| Android de rede e Android local | IMPLEMENTADO, MAS NÃO TESTADO em aparelho |
| Wake word sem perder comando parcial | IMPLEMENTADO E TESTADO (contrato estático) |
| Perfil de locutor e três estados | IMPLEMENTADO E TESTADO (sinais sintéticos) |
| Anti-replay | PARCIAL: indício heurístico, não é prova forense |
| Barge-in | NÃO IMPLEMENTADO |
| Whisper local / sherpa ASR | NÃO IMPLEMENTADO / BLOQUEADO |
| Acurácia, latência e consumo reais | BLOQUEADO POR LIMITAÇÃO TÉCNICA |
| Diagnóstico de voz e métricas | IMPLEMENTADO; teste de campo pendente |

## Build 1.42.0

- Arquivo esperado: `jarvis-nova-1.42.0-10420.apk`.
- Ambiente: GitHub Actions, Ubuntu 24.04, JDK 21, Android SDK 35, `assembleDebug`.
- Assinatura: `ci/debug.keystore`, compatível com o atualizador embutido.
- Hash e tamanho serão registrados nesta branch após a publicação do release.
- Nenhum APK foi instalado em aparelho físico nesta rodada.
