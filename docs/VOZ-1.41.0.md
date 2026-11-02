# 1.41.0 — Reconhecimento de voz: o que mudou de verdade

## Problemas encontrados

1. **O Android descartava confiança e hipóteses alternativas.** O `RecognitionListener.onResults` devolvia só `texto` e `mecanismo`. O app não podia distinguir uma transcrição firme de uma duvidosa, nem comparar hipóteses.
2. **O caminho de comando não usava os sinais do motor.** A decisão de executar era binária: havia texto, executava. Uma palavra trocada em um comando de ação podia virar efeito real.
3. **O microfone tinha AGC/NS/EC do sistema, mas não uma cadeia própria.** Ruído de sala e voz baixa dependiam inteiramente do WebView; o perfil de locutor e os comandos usavam capturas diferentes.
4. **O centroide do perfil tratava todas as amostras como iguais.** Uma captura ruidosa podia puxar a referência e aumentar falsos negativos.
5. **O indício de replay era decorativo.** `pistaReplay` existia, mas a identificação não o consultava. Além disso, a função lia `m.pausaRatio` em vez de `q.pausaRatio`, então o portão nunca disparava.
6. **Não havia teste de transcrição esperado × reconhecido.** A tela mostrava qualidade acústica, não WER, acerto nem latência do caminho completo.
7. **WebView sem `MediaRecorder` não tinha caminho de áudio.** O PCM já era capturado pelo VAD, mas não havia contêiner para enviar ao STT.

## Melhorias implementadas

- `JarvisBackgroundPlugin.java` (raiz e árvore Android) devolve `confianca` e `alternativas` com até cinco hipóteses; hipóteses vazias são descartadas.
- `fala.js` avalia o texto sem reescrever o sentido: limpeza de bordas, grafia de uma lista fechada, pontuação conservadora, WER e métricas. Comando de ação com confiança abaixo de 45% pede repetição; confiança ausente ou zero é tratada como **não informada**, não como 100%.
- `app.js` integra a avaliação ao Groq, ao fallback Android e ao modo offline; mede latência do início da escuta até o texto.
- `ligarFiltrosMicrofone` aplica high-pass de 85 Hz e compressor (-24 dB, 3:1) antes do `MediaRecorder` e no cadastro do perfil. O destino processado é usado para gravar; se o WebView não oferecer `MediaStreamAudioDestination`, a captura original é preservada.
- `identidade.js` pondera o centroide por SNR e duração e retorna `inconclusivo` com `replay: true` quando há indício de reprodução.
- `voz_motor.js` corrigiu a leitura de `pausaRatio`; a proteção agora é exercitada por teste.
- `gravarWav` usa `audio_pcm.js` como fallback quando não existe `MediaRecorder`; o upload escolhe `audio.wav` ou `audio.webm` pelo tipo real.
- Ajustes ▸ Voz ganhou “Teste de transcrição e precisão”: frase esperada, reconhecido, acerto, WER, latência, confiança e histórico local apagável.

## O que não foi feito

- Não foi baixado nem embutido Whisper local, whisper.cpp, faster-whisper ou sherpa-onnx ASR. Não há modelo, licença, RAM medida nem comparação acústica que justifique trocar o motor funcional.
- Não há correção semântica por contexto. O texto reconhecido é preservado; o contexto continua sendo usado pela IA depois da transcrição, não para “adivinhar” palavras.
- Não há detecção forense de replay. O indício é conservador e pode falhar; ele bloqueia identidade, não prova fraude.
- Não há barge-in novo, treino de wake word nem VAD neural. O VAD existente (pré-roll de 600 ms, silêncio de 1,2 s) foi preservado.
- Não há medição de acurácia, latência ou consumo em aparelho físico nesta máquina.

## Testes executados

- `node tests/test_fala.js`: 29 verificações de limpeza conservadora, confiança, alternativas, comando, WER e métricas.
- `node tests/test_audio_pcm.js`: RIFF/WAVE, mono/16-bit, clipping, tamanho e duração.
- `node tests/test_identidade.js`: inclui o caso de replay que retorna inconclusivo.
- `node tests/test_voz_motor.js`: 21 verificações do motor de locutor com sinais sintéticos.
- `python3 tests/test_stt_avancado.py`: contrato estático do Java, app, módulos, CI e pacote.
- `npm run test:all`: suíte completa; resultado registrado no relatório final.

## Classificação honesta

| Recurso | Classificação |
|---|---|
| Confiança/alternativas do Android no caminho real | IMPLEMENTADO E TESTADO (contrato e sintaxe; não em aparelho) |
| Recusa de comando por baixa confiança | IMPLEMENTADO E TESTADO (unidade) |
| Filtro high-pass/compressor | IMPLEMENTADO, MAS NÃO TESTADO acusticamente |
| Centroide ponderado | IMPLEMENTADO E TESTADO (unidade) |
| Bloqueio de replay | IMPLEMENTADO E TESTADO (unidade), sem validação forense |
| Teste de transcrição/WER/latência | IMPLEMENTADO E TESTADO (unidade/UI estática) |
| WAV PCM de emergência | IMPLEMENTADO E TESTADO (unidade) |
| STT local PT-BR (Whisper/sherpa) | NÃO IMPLEMENTADO |
| Medição real de acurácia/latência no Poco X7 | BLOQUEADO POR LIMITAÇÃO TÉCNICA |

## Build 1.41.0

- Arquivo: `jarvis-nova-1.41.0-10410.apk`.
- Bytes: 81.220.373.
- SHA-256: `d05aab92eb158a27e50fcd249dc2ff64e89927aa8167371b07acc787e0b32953`.
- `aapt`: `com.jarvis.nova`, versionCode 10410, versionName 1.41.0, minSdk 26, targetSdk 34, compileSdk 35.
- Assets no APK: `app.js`, `index.html`, `fala.js` (1.1.0) e `audio_pcm.js`.
- Assinatura debug/CI; não instalado em aparelho físico.

## Próximos passos técnicos

1. Instalar o APK em um aparelho e rodar 30–50 frases PT-BR por cenário (limpo, TV, ventoinha, distância, fala rápida/lenta), salvando o WER de cada uma.
2. Comparar Groq `whisper-large-v3` com o Android local no mesmo conjunto; só trocar o padrão se houver ganho medido e custo aceitável.
3. Se o WER em ruído continuar alto, avaliar sherpa-onnx com modelo PT-BR quantizado, medindo RAM, tamanho e latência antes de embarcar.
4. Para replay, testar gravações de alto-falante e fones em distâncias conhecidas; o limiar atual é indício, não autenticação.
