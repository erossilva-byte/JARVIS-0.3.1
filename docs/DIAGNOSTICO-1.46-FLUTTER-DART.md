# Diagnóstico técnico inicial — migração Flutter/Dart do J.A.R.V.I.S. Nova

Data da inspeção: 2026-11-08  
Repositório: `erossilva-byte/JARVIS-0.3.1`  
Branch de trabalho criada: `feat/flutter-dart-migration-1.46.0`  
Base de trabalho inspecionada: `work/1.46.0-auditoria-funcoes-apk`

> Este documento registra uma pré-auditoria baseada em leitura dos arquivos e metadados disponíveis pela API do GitHub. Não representa inspeção local integral, build novo ou teste em dispositivo. Nenhuma função é marcada como concluída sem evidência.

## 1. Estado e histórico Git

- Branch padrão: `main`.
- `main` declara `package.json.version = 1.31.2`.
- `work/1.46.0-auditoria-funcoes-apk` declara `package.json.version = 1.45.0` e `VERSAO.json.version = 1.45.0`.
- Comparação de refs: histórico divergente; a branch de evolução tem 56 commits exclusivos e está 9 commits atrás da main.
- Foi criada uma branch de integração para avaliar a reconciliação. A PR #7 foi fechada sem merge porque a integração inicial não estava limpa/segura. A main não foi alterada.
- Foi criada a branch `feat/flutter-dart-migration-1.46.0` a partir da branch de evolução, como linha isolada de trabalho.

## 2. Arquitetura atual versus arquitetura solicitada

| Área | Estado observado | Ação necessária |
|---|---|---|
| Interface Android | HTML/CSS/JS em Capacitor WebView | Migrar a interface principal para Flutter |
| Desktop | Electron + Node.js | Flutter Windows como interface principal; preservar serviços nativos úteis |
| Flutter/Dart | `pubspec.yaml` ausente na raiz e na branch inspecionada | Criar workspace Flutter Android/Windows, testes e pipelines |
| Hermes Agent | Presente em `hermes.js` | Preservar contrato e expor adaptador Dart ↔ runtime |
| Core/agentes/planos | `core.js`, `core_ui.js`, `agentes.js`, `plano.js` presentes | Manter lógica útil, formalizar API e testar integração |
| Avatar/HUD | `avatar.js` usa Three.js/WebGL com fallback Canvas 2D | Reimplementar HUD Flutter com renderização 3D eficiente e acessível |
| PC | `platforms/desktop/main.js`, `preload.js`, `pc.js` e serviços Node | Preservar capacidades do PC por bridge nativa segura |

A migração deve ser incremental e manter uma camada de compatibilidade até cada recurso ter sido migrado e testado. Não remover Electron/Node de forma abrupta antes de os serviços equivalentes do Windows existirem.

## 3. Provedores de IA

O array `PROVEDORES` de `app.js` contém Groq, Cerebras, Mistral e Gemini. Na auditoria inicial a busca não encontrou OpenRouter, DeepSeek ou Gemma 3 1B IT. **Nesta etapa da 1.46.0, OpenRouter foi adicionado como reserva logo após Groq, com DeepSeek como modelo inicial; a chave é independente e usa o fluxo de cofre seguro já existente.** A validação automatizada foi adicionada, mas ainda depende da execução do CI e de teste real com uma chave do usuário.

Requisitos de implementação:
1. Groq como prioridade.
2. OpenRouter como segundo adaptador, com DeepSeek como modelo inicial; testar troca de modelo e fallback.
3. Mistral, Gemini e Cerebras como provedores independentes.
4. Cinco campos de chave separados, armazenamento em cofre seguro, teste real, limites, timeout, cooldown, métricas e fallback.
5. Nunca embutir chaves em código, workflow, logs ou artefatos.
6. Preservar modo local/offline e diagnosticar Gemma 3 1B IT sem presumir que esteja funcional.

## 4. Palavra de ativação e voz

- `JarvisAtivacao.java` implementa comparação textual/fonética para a palavra “Jarvis”.
- `JarvisService.java` usa `SpeechRecognizer`, preferindo `createOnDeviceSpeechRecognizer` quando o idioma offline está instalado.
- Se o reconhecimento local não estiver disponível, o código pode alternar para `createSpeechRecognizer` (serviço padrão, potencialmente em rede).
- O workflow baixa o AAR sherpa-onnx 1.13.8, mas o fluxo observado em `JarvisService.java` usa `SpeechRecognizer`; a presença do AAR não prova que um KWS acústico sherpa esteja ligado ao ciclo de ativação.
- `escuta.js` implementa VAD/segmentação PCM com pré-roll, limiar adaptativo e fim de fala.

Conclusão: existe serviço de escuta em segundo plano e detecção textual de “Jarvis”, mas isso não equivale a um KWS acústico dedicado, comprovadamente local e sem fallback de rede antes da ativação. A migração deve integrar KWS local real, confirmar licença/modelo, testar português brasileiro, falsos positivos, consumo e recuperação em Android 16/HyperOS e Windows. O reconhecimento de comando depois da ativação pode usar provedores configurados conforme consentimento.

## 5. Visão, segurança, CADeSIMU e Windows

### Visão
Há módulos `visao.js`/contexto visual e integração de câmera no app. A auditoria funcional precisa testar perguntas de seguimento, OCR, reconhecimento de objetos, busca complementar e comportamento honesto quando o objeto não é identificado.

### Segurança
`seguranca.js` modela PIN, biometria, NFC e algumas combinações. A enumeração observada não cobre diretamente todas as políticas solicitadas (PIN + biometria, PIN + NFC, PIN OU biometria, PIN OU NFC). “Biometria” depende do que o Android oferece; não prova que reconhecimento facial e digital possam ser escolhidos separadamente em todo aparelho. NFC deve ser tratado como fator de conveniência, não como identidade forte apenas pelo UID.

### CADeSIMU
Há `cad.js`, `eletrica.js` e `projetista.js`, com biblioteca elétrica, regras de continuidade e geração de projetos. Porém:
- `cad.js` documenta um formato JSON próprio “CadSimu CAD”.
- `projetista.js` declara explicitamente que não gera o formato nativo proprietário do CADeSIMU.
- `platforms/WINDOWS.md` descreve criação/edição de `.cad`, criando uma divergência documental que precisa ser resolvida por testes com arquivos reais do CADeSIMU.
- Não anunciar compatibilidade nativa até abrir e salvar arquivos reais no programa.

### Windows
O workflow `release-pc.yml` ainda empacota Electron/NSIS/portátil. A documentação informa que algumas capacidades mobile não têm equivalente desktop. A matriz Android ↔ Windows deve ser preenchida recurso por recurso, com adaptação real para sensores, câmera, chamadas, biometria, notificações, mídia e status do sistema.

## 6. Build e publicação

- `release-apk.yml` compila APK em evento de tag ou execução manual e anexa APK/checksum ao Release.
- `release-pc.yml` compila instalador e portátil Windows usando Electron.
- O registro de `VERSAO.json` informa APK 1.45.0 (versionCode 10450), compilado em 2026-11-05, SHA-256 `6453e4a051fd4e388090382ffce2a798154e52b9ce1dd7acf5f3d006fca1cbc7`; o próprio registro diz que não foi instalado em aparelho físico.
- Não há `pubspec.yaml` nem workflow Flutter nesta branch inspecionada.
- Build antigo não valida código novo. O APK final precisa vir do commit/tag exato, com checksum, assinatura consistente, artefatos Android e Windows e relatório de testes.

## 7. Critérios obrigatórios de aceite

1. Inventário único de todos os recursos dos dois PDFs e do histórico, sem duplicações e sem omissões silenciosas.
2. Matriz por recurso: estado real, Android, Windows, dependências, permissão, limitações, teste e evidência.
3. Flutter/Dart como UI oficial nos dois sistemas; nenhum botão sem ação real.
4. Hermes/Core/agentes/memória preservados e integrados por interfaces testáveis.
5. Cinco provedores e chaves isoladas, Groq prioritário e OpenRouter/DeepSeek integrado.
6. KWS local real antes da ativação, sem enviar áudio à nuvem; fluxo pós-ativação separado e configurável.
7. Visão com contexto de sessão, OCR e descrição curta quando não houver identificação confiável.
8. Segurança com PIN, biometria, NFC e políticas AND/OR solicitadas, respeitando hardware e APIs.
9. CADeSIMU validado com arquivos reais; formatos próprios identificados claramente.
10. Paridade Android/Windows com status do PC, controle de PC, pareamento QR autenticado e serviços nativos.
11. Testes unitários, integração, widgets Flutter, Android 16 em aparelho real e testes Windows.
12. GitHub Actions reproduzíveis, APK e pacote Windows originados do mesmo release, checksums, notas, rollback e links verificados.

## 8. Ordem de execução

1. Reconciliar branches sem perder commits e sem sobrescrever a main.
2. Criar workspace Flutter e pipeline de testes/build Android + Windows.
3. Migrar shell visual, navegação, núcleo animado e acessibilidade.
4. Integrar Hermes e serviços existentes via bridge com contratos versionados.
5. Migrar voz/KWS, visão, memória, segurança e provedores.
6. Migrar arquivos, CADeSIMU, programação/sandbox, pessoas, tarefas, mídia, integrações e dispositivos.
7. Completar matriz de paridade, testes reais e Release.

**Status deste documento:** diagnóstico inicial registrado; não declara migração, build ou Release concluídos.


## 9. Execução da linha 1.46.0 — andamento
- [x] Branch isolada criada: `feat/flutter-dart-migration-1.46.0`.
- [x] Documento de pré-auditoria registrado.
- [x] OpenRouter adicionado ao roteador após Groq; DeepSeek é o modelo inicial.
- [x] Campo de chave OpenRouter adicionado à interface; armazenamento, leitura e remoção reaproveitam o cofre seguro genérico existente.
- [x] OpenRouter excluído da seleção automática de visão nesta etapa, pois o modelo DeepSeek configurado é textual.
- [x] Teste estático de contrato criado e incluído em `test:all` e `test:syntax`.
- [x] Pipeline CI de desenvolvimento criado para pull requests e pushes nas branches de trabalho.
- [x] Documentação do Windows corrigida: `.cad` é formato interno Jarvis CAD, não formato nativo CADeSIMU.
- [ ] Executar CI remoto e corrigir todos os erros encontrados.
- [ ] Validar OpenRouter com chave real sem expor segredo em logs.
- [ ] Iniciar workspace Flutter e migrar uma tela/fluxo por vez, com paridade funcional.
- [ ] Implementar e validar KWS acústico local sem fallback de rede antes da palavra de ativação.
- [ ] Completar políticas de segurança AND/OR respeitando os fatores que o hardware oferece.
- [ ] Validar CADeSIMU com arquivos reais e o aplicativo original.
- [ ] Completar paridade Android/Windows e testes físicos.
- [ ] Gerar APK e pacote Windows a partir do mesmo commit de release, com hashes e evidências.

**Regra de status:** os itens marcados como concluídos acima são alterações registradas no repositório, não certificação de funcionamento em dispositivo. Os itens pendentes não podem ser anunciados como entregues.
