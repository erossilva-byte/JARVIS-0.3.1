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
| Kotlin + KWS | Bridge Kotlin/Dart, serviço foreground e preparação reprodutível do sherpa-onnx adicionados; CI Android passou no SHA `94f82a6ac326f587b832ea83c6e436b2d64d49b4`. Modelo GigaSpeech é inglês | CI aprovado; validação física e precisão PT-BR pendentes |
| CADeSIMU | Projetista e formato Jarvis próprio; sem round-trip demonstrado com CADeSIMU oficial | Pendente |
| Paridade Windows | Electron/Node legado existe; Flutter Windows compila, sem todos os serviços migrados | Pendente |
| IA local | Plugin MediaPipe legado existe; Gemma 3 1B IT ainda requer teste real no Poco X7; Windows sem runtime integrado | Parcial |
| Memória semântica | Busca lexical/hash e Markdown no legado; sem embedding neural multilíngue e sem sync Flutter/Obsidian validada | Parcial |
| QR Android–Windows | Sem protocolo/implementação comprovada na interface Flutter | Pendente |

## Limitações e bloqueios conhecidos

1. O runner Android continua sendo gerado durante CI. A preparação do KWS, o AAR e o modelo passaram no workflow `42718424474`; o script de preparação Gradle está validado em build limpo.
2. O serviço KWS Flutter ainda não implementa toda a política de persistência/rearme necessária (reinício do processo, reboot, watchdog, pausa por chamadas/mídia e Doze).
3. O reconhecimento do comando usa o SpeechRecognizer on-device do Android (API 31+) e depende de pacote offline pt-BR instalado no aparelho. A disponibilidade real precisa ser testada; se indisponível, o sistema apresenta erro e não usa reconhecimento online como fallback.
4. A conversa Flutter envia a transcrição ao primeiro provedor configurado, priorizando Groq. A execução de ações locais/dispositivo ainda não está ligada ao chat e não deve ser presumida.
5. O modelo KWS disponível foi treinado em inglês. A palavra “Jarvis” pode ser detectada em algumas pronúncias, mas precisão com sotaques brasileiros precisa ser medida; não há alegação de suporte PT-BR validado.
6. CADeSIMU é formato proprietário: sem arquivos de amostra reais e validação no programa original, não é seguro implementar exportador que prometa compatibilidade.
7. Windows local AI precisa runtime e distribuição de modelo específicos; não presumir que o plugin MediaPipe Android rode no Windows.
8. A sincronização Obsidian precisa lidar com SAF no Android e caminhos/permissões no Windows, além de conflitos e deduplicação.

## Critérios de saída

- [x] Workflow Android: format/analyze/test e APK debug compilados com AAR e modelo sherpa-onnx (run `42718424474`, SHA `94f82a6`).
- [ ] KWS validado em Android 16/HyperOS, inclusive permissão, tela bloqueada, Doze, app removido dos recentes, reinício, falsos positivos e pronúncia PT-BR.
- [ ] Validar no Poco X7 a captura/transcrição on-device pt-BR após wake, incluindo ausência de pacote offline, timeouts e repetição.
- [ ] Conectar a conversa a ações locais com confirmação para operações sensíveis.
- [ ] CADeSIMU: abrir/editar/salvar cópia e reabrir no CADeSIMU oficial.
- [ ] Matriz Android/Windows por capacidade, com ações e testes reais.
- [x] Gate A de CI Android + Windows aprovado no run `42718424474`; artefatos Android e Windows publicados para o mesmo SHA `94f82a6ac326f587b832ea83c6e436b2d64d49b4`.
- [ ] Gemma offline executando no Android e modelo local offline no Windows.
- [ ] Busca semântica multilíngue por paráfrases e Obsidian bidirecional sem perda/duplicação.
- [ ] QR com confirmação bilateral, desafio único, criptografia, escopos e revogação.
- [ ] Workflow Flutter Android/Windows verde após todas as alterações; testes em hardware real.
- [ ] Release Android e Windows do mesmo commit, com checksums e notas.

**Status da sequência:** integração KWS nativa compilada; Gate A (CI Android + Windows) aprovado no SHA `94f82a6ac326f587b832ea83c6e436b2d64d49b4`. Gate B (aparelho real) e as integrações funcionais restantes continuam pendentes. Não publicar como versão pronta enquanto houver qualquer critério de saída desmarcado.


## Gate obrigatório para avançar de etapa

Nenhuma nova etapa de integração, merge ou Release pode ser considerada autorizada sem cumprir os gates abaixo. Falha, cancelamento, execução pendente ou ausência de evidência contam como **bloqueio**, não como aprovação.

### Gate A — CI reproduzível (obrigatório em cada commit candidato)
- [x] Android: geração limpa do runner, preparação do sherpa-onnx/AAR/modelo, `dart format`, `flutter analyze`, `flutter test`, APK debug compilado e artefato publicado (run `42718424474`).
- [x] Windows: geração limpa do runner, `flutter analyze`, `flutter test`, build Windows e artefato publicado (run `42718424474`).
- [x] Job agregado `advance-gate (Android + Windows)` concluído com sucesso (run `42718424474`).
- [x] Conferido: os dois artefatos pertencem ao SHA `94f82a6ac326f587b832ea83c6e436b2d64d49b4`.
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

### Ajuste adicional de CI — concorrência por branch
O workflow Flutter agora usa o mesmo grupo de concorrência para eventos `push` e `pull_request` da mesma branch. Antes, o nome do evento fazia os grupos divergirem e permitia builds duplicados concorrentes. A alteração não cancela a execução em andamento (`cancel-in-progress: false`); o novo commit precisa ser validado integralmente.
