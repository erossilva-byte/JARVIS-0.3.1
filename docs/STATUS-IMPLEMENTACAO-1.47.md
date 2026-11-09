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
- [x] Dependências `sentencepiece` e `pypinyin` adicionadas ao ambiente de CI, exigidas pelo comando oficial `sherpa-onnx-cli text2token`.
- [x] Script de preparação nativa ajustado para inserir dependências Gradle mesmo quando o template do Flutter não gera previamente um bloco `dependencies`.
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

1. O runner Android continua sendo gerado durante CI. A preparação do KWS e o download do AAR passaram; a execução mais recente falhou ao aplicar as dependências Gradle porque o template Flutter não continha o bloco `dependencies`. O script foi corrigido para tratar ambos os formatos, mas ainda precisa passar no workflow seguinte.
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


## Gate obrigatório para avançar de etapa

Nenhuma nova etapa de integração, merge ou Release pode ser considerada autorizada sem cumprir os gates abaixo. Falha, cancelamento, execução pendente ou ausência de evidência contam como **bloqueio**, não como aprovação.

### Gate A — CI reproduzível (obrigatório em cada commit candidato)
- [ ] Android: geração limpa do runner, preparação do sherpa-onnx/AAR/modelo, `dart format`, `flutter analyze`, `flutter test`, APK debug compilado e artefato publicado.
- [ ] Windows: geração limpa do runner, `flutter analyze`, `flutter test`, build Windows e artefato publicado.
- [ ] Job agregado `advance-gate (Android + Windows)` concluído com sucesso; ele falha se qualquer plataforma falhar ou não concluir com sucesso.
- [ ] Conferir que os dois artefatos pertencem ao mesmo SHA do commit avaliado; não reutilizar artefatos antigos.
- [ ] Corrigir a causa raiz de toda falha e repetir o workflow no novo commit. Não contornar removendo testes, etapas ou validações.

### Gate B — validação funcional antes de declarar a etapa pronta
- [ ] Instalar e executar o APK no Poco X7 com Android 16/HyperOS.
- [ ] Testar KWS com a palavra “Jarvis” em português brasileiro em ambiente silencioso e com ruído; medir falsos positivos, falsos negativos e latência. O modelo inglês atual não recebe aprovação automática.
- [ ] Validar captura/transcrição offline pt-BR, permissões, bloqueio de tela, Doze, app removido dos recentes, rearme, reinício e consumo de bateria.
- [ ] Verificar que nenhuma captura/transcrição de áudio é enviada à nuvem sem autorização explícita.
- [ ] Executar a matriz de funções equivalentes Android/Windows e registrar o que ainda estiver parcial.

### Regra de decisão
- **Avançar para a próxima etapa de implementação:** Gate A verde no SHA atual; Gate B pode continuar como tarefa explícita da etapa, sem rotular como concluída a função ainda não testada.
- **Marcar a etapa como concluída, retirar o rascunho, fazer merge ou publicar Release:** Gates A e B aprovados, além dos critérios específicos da funcionalidade e evidência registrada.
- ESP32 continua fora do escopo desta sequência. Picovoice não pode ser introduzido como dependência ou alternativa obrigatória.
