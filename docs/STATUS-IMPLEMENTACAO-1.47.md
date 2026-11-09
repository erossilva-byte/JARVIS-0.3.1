# Status de implementação — sequência 1.47.0

Este registro é atualizado por evidência de código e CI. Código preparado não equivale a integração validada em aparelho.

## Alterações efetivamente registradas nesta branch

- [x] Branch isolada `feat/functional-integration-1.47.0` e PR #9 em rascunho; nenhuma alteração direta na `main`.
- [x] Núcleo visual Flutter com resposta tátil e painel contextual; testes de widget ajustados.
- [x] Contrato Dart `KwsGateway` e controlador `KwsController` para diagnóstico, iniciar/parar/testar, estados e eventos.
- [x] Controlador assina o fluxo de eventos antes de iniciar o microfone, evitando perder detecções muito rápidas; teste de regressão adicionado.
- [x] `MainActivity.kt` registra MethodChannel e EventChannel `com.jarvis.nova/kws` e `com.jarvis.nova/kws/events`, solicita permissão de microfone e só reporta escuta ativa após confirmação do motor.
- [x] `KwsForegroundService.kt` implementa serviço foreground do tipo microphone, notificação persistente, ciclo de vida do motor sherpa-onnx, janela de teste e encaminhamento do evento de wake para a Activity.
- [x] Script `flutter_app/tool/prepare_android_kws.py` aplica patch reproduzível no runner Android gerado pelo Flutter, copia o motor Java legado, instala fontes Kotlin, registra permissões/serviço, adiciona AAR e fixa minSdk 26.
- [x] Workflow Android baixa o AAR sherpa-onnx com SHA-256 verificado, prepara os assets do modelo KWS e aplica o patch nativo antes da compilação.
- [x] Dependência `sentencepiece` adicionada ao ambiente de CI, necessária para o comando oficial `sherpa-onnx-cli text2token`.
- [x] Timeout Android ampliado para acomodar download e preparação dos artefatos locais.

## Estado real das frentes

| Frente | Evidência atual | Estado |
|---|---|---|
| Flutter UI | Shell Flutter, provedor de IA e núcleo holográfico; nem todos os serviços estão ligados às telas | Parcial |
| Kotlin + KWS | Bridge Kotlin/Dart, serviço foreground e preparação reprodutível do sherpa-onnx adicionados; ainda aguardam build e validação no dispositivo. Modelo GigaSpeech é inglês | Implementação registrada; CI e aparelho pendentes |
| CADeSIMU | Projetista e formato Jarvis próprio; sem round-trip demonstrado com CADeSIMU oficial | Pendente |
| Paridade Windows | Electron/Node legado existe; Flutter Windows compila, sem todos os serviços migrados | Pendente |
| IA local | Plugin MediaPipe legado existe; Gemma 3 1B IT ainda requer teste real no Poco X7; Windows sem runtime integrado | Parcial |
| Memória semântica | Busca lexical/hash e Markdown no legado; sem embedding neural multilíngue e sem sync Flutter/Obsidian validada | Parcial |
| QR Android–Windows | Sem protocolo/implementação comprovada na interface Flutter | Pendente |

## Limitações e bloqueios conhecidos

1. O runner Android continua sendo gerado durante CI. A integração foi tornada reproduzível por script, mas o script precisa passar no workflow real.
2. O serviço KWS Flutter atual não implementa ainda a política completa de persistência/rearme do serviço legado (reinício do processo, reboot, watchdog, pausa por chamadas/mídia e Doze).
3. O reconhecimento do comando usa o SpeechRecognizer on-device do Android (API 31+) e depende de pacote offline pt-BR instalado no aparelho. A disponibilidade real precisa ser testada; se indisponível, o sistema apresenta erro e não usa reconhecimento online como fallback.
4. A conversa Flutter envia a transcrição ao primeiro provedor configurado, priorizando Groq. A execução de ações locais/dispositivo ainda não está ligada ao chat e não deve ser presumida.
5. O serviço KWS ainda não implementa toda a política de persistência/rearme do legado (reinício do processo, reboot, watchdog, pausa por chamadas/mídia e Doze).
6. O modelo KWS disponível foi treinado em inglês. A palavra “Jarvis” pode ser detectada em algumas pronúncias, mas precisão com sotaques brasileiros precisa ser medida; não há alegação de suporte PT-BR validado.
7. CADeSIMU é formato proprietário: sem arquivos de amostra reais e validação no programa original, não é seguro implementar exportador que prometa compatibilidade.
8. Windows local AI precisa runtime e distribuição de modelo específicos; não presumir que o plugin MediaPipe Android rode no Windows.
9. A sincronização Obsidian precisa lidar com SAF no Android e caminhos/permissões no Windows, além de conflitos e deduplicação.

## Critérios de saída

- [ ] Workflow Android: format/analyze/test e APK debug compilados com AAR e modelo sherpa-onnx.
- [ ] KWS validado em Android 16/HyperOS, inclusive permissão, tela bloqueada, Doze, app removido dos recentes, reinício, falsos positivos e pronúncia PT-BR.
- [ ] Validar no Poco X7 a captura/transcrição on-device pt-BR após wake, incluindo ausência de pacote offline, timeouts e repetição.
- [ ] Conectar a conversa a ações locais com confirmação para operações sensíveis.
- [ ] CADeSIMU: abrir/editar/salvar cópia e reabrir no CADeSIMU oficial.
- [ ] Matriz Android/Windows por capacidade, com ações e testes reais.
- [ ] Gemma offline executando no Android e modelo local offline no Windows.
- [ ] Busca semântica multilíngue por paráfrases e Obsidian bidirecional sem perda/duplicação.
- [ ] QR com confirmação bilateral, desafio único, criptografia, escopos e revogação.
- [ ] Workflow Flutter Android/Windows verde após todas as alterações; testes em hardware real.
- [ ] Release Android e Windows do mesmo commit, com checksums e notas.

**Status da sequência:** integração KWS nativa implementada em código, aguardando prova de compilação e execução. Não publicar como versão pronta enquanto houver qualquer critério de saída desmarcado.
