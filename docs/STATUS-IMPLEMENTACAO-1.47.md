# Status de implementação — sequência 1.47.0

Este registro é atualizado por evidência de código e CI. Não confundir arquivo/documentação com integração concluída.

## Alterações efetivamente registradas nesta branch
- [x] Branch isolada `feat/functional-integration-1.47.0` criada a partir da linha Flutter 1.46.
- [x] PR #9 aberta como draft, sem alteração direta na `main`.
- [x] Plano técnico com seis frentes e critérios de aceite registrado em `docs/SEQUENCIA-1.47-INTEGRACAO-FUNCIONAL.md`.
- [x] Núcleo visual Flutter ajustado: resposta tátil com escala animada, animação contínua, interação por toque/arraste e painel de contexto.
- [x] Teste de widget para a interação do núcleo adicionado.
- [x] Textos de configurações deixam explícito que KWS sherpa-onnx já existe no Android legado, mas a ponte Flutter ainda está pendente; deixam explícito também o estado pendente de Obsidian, memória e pareamento.
- [x] Workflow Flutter atualizado para incluir a branch 1.47 e PRs encadeadas na branch Flutter 1.46.

## Estado real das frentes
| Frente | Evidência atual | Estado |
|---|---|---|
| Flutter UI | Shell Flutter, provedor de IA e núcleo holográfico; tela ainda não chama todos os serviços | Parcial |
| Kotlin + KWS | `JarvisKwsEngine` e `JarvisService` sherpa-onnx/AudioRecord existem no legado Android; modelo KWS base GigaSpeech é inglês | Parcial; ponte Flutter ausente e PT-BR precisa validação |
| CADeSIMU | Projetista e formato Jarvis próprio; sem round-trip demonstrado com o CADeSIMU oficial | Pendente |
| Paridade Windows | Electron/Node legado existe; Flutter Windows compila, sem todos os serviços migrados | Pendente |
| IA local | Plugin MediaPipe legado existe; Gemma 3 1B IT ainda requer teste real no Poco X7; Windows sem runtime integrado | Parcial |
| Memória semântica | Busca lexical/hash e Markdown no legado; sem embedding neural multilíngue e sem sync Flutter/Obsidian validada | Parcial |
| QR Android–Windows | Sem protocolo/implementação comprovada na interface Flutter | Pendente |

## Bloqueios técnicos que precisam de evidência
1. O workflow Flutter gera os runners Android/Windows durante CI; os runners não estão versionados como projeto Flutter pronto. Para integrar Kotlin, será necessário versionar a plataforma Android ou garantir patch reprodutível após `flutter create`.
2. O `JarvisService` atual tem dependências do aplicativo Android legado (watchdog, wake bus, preferências, assets sherpa, notificações e classes Capacitor). Copiar apenas `JarvisKwsEngine.java` não é suficiente e causaria build quebrado.
3. O modelo KWS atual foi treinado em inglês. O motor é KWS local real, mas reconhecimento confiável com pronúncia PT-BR precisa avaliação acústica e, se necessário, modelo treinado/ajustado.
4. CADeSIMU é formato proprietário: sem arquivos de amostra reais e validação no programa original, não é seguro implementar escritor que alegue compatibilidade.
5. Windows local AI precisa runtime e distribuição de modelo específicos; não presumir que o plugin MediaPipe Android rode no Windows.
6. A sincronização Obsidian precisa lidar com SAF no Android e caminhos/permissões no Windows, além de conflitos e deduplicação.

## Critérios de saída
- [ ] Bridge Flutter ↔ Kotlin com lifecycle, permissões e eventos KWS; iniciar/parar/diagnóstico/teste de ativação.
- [ ] KWS validado em Android 16/HyperOS, inclusive tela bloqueada, Doze, app removido dos recentes, reinício, falsos positivos e pronúncia PT-BR.
- [ ] CADeSIMU: abrir/editar/salvar cópia e reabrir no CADeSIMU oficial.
- [ ] Matriz Android/Windows por capacidade, com ações e testes reais.
- [ ] Gemma offline executando no Android e modelo local offline no Windows.
- [ ] Busca semântica multilíngue por paráfrases e Obsidian bidirecional sem perda/duplicação.
- [ ] QR com confirmação bilateral, desafio único, criptografia, escopos e revogação.
- [ ] Workflow Flutter Android/Windows verde após todas as alterações; testes em hardware real.
- [ ] Release Android e Windows do mesmo commit, com checksums e notas.

**Status da sequência:** em implementação inicial. Não publicar como versão pronta enquanto houver qualquer critério de saída desmarcado.
