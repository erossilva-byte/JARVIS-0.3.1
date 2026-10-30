# Análise comparativa dos repositórios de referência

Data da análise: 30/10/2026. Método: clone raso (`git clone --depth 1`) dos oito repositórios,
inventário de arquivos e extensões, leitura de README, manifesto Android, serviços, motores de voz,
roteadores de ferramentas e licenças. Não houve execução dos projetos de terceiros; as conclusões
abaixo são de inspeção estática. Estrelas e data do último push foram consultadas na API do GitHub
no mesmo dia.

Nenhum código foi copiado para o J.A.R.V.I.S. Nova. O que foi aproveitado são ideias de arquitetura,
reimplementadas no núcleo próprio.

## 1. Inventário

| Repositório | Estrelas | Linguagem principal | Licença | Último push | Tamanho |
|---|---:|---|---|---|---:|
| `adewaskar/jarvis` | 653 | TypeScript | MIT | 05/08/2026 | 11 MB |
| `open-jarvis/OpenJarvis` | 12.536 | Python | Apache-2.0 | 30/10/2026 | 88 MB |
| `microsoft/JARVIS` | 25.527 | Python | MIT | 29/07/2025 | 42 MB |
| `jgm-source/jarvis-opensource` | 435 | Python | CC BY-NC 4.0 (não comercial) | 13/10/2026 | 0,8 MB |
| `sukeesh/Jarvis` | 3.779 | Python | MIT | 01/12/2025 | 5 MB |
| `AnaaySampat/jarvis` | 21 | TypeScript + Kotlin + Rust | MIT | 26/10/2026 | 14 MB |
| `Aryan-0001/Jarvis-AI` | 131 | Dart (Flutter) | MIT | 29/10/2026 | 47 MB |
| `VarsshanCoder/JARVIS-OS-Agentic-AI-Assistant-for-Android` | 7 | Kotlin + Python | Apache-2.0 | 23/07/2026 | 1,4 MB |

Observação de licença: o `jgm-source` usa **CC BY-NC 4.0**, que proíbe uso comercial. Ele serve como
referência de comportamento, não como fonte de código. O `VarsshanCoder` exibe selo MIT no README, mas
o arquivo `LICENSE` é **Apache-2.0** — prevalece o arquivo de licença.

## 2. O que cada projeto realmente tem

### AnaaySampat/jarvis — a melhor referência Android

Arquitetura em três camadas: app Android nativo (Kotlin), plugin de telefone para um app desktop
(Tauri/Rust) e um “cérebro” TypeScript com agentes e ferramentas. Pontos concretos encontrados no
código:

- `WakeWordService.kt`: **foreground service com `foregroundServiceType="microphone"`**, permissões
  `FOREGROUND_SERVICE_MICROPHONE` e `FOREGROUND_SERVICE_SPECIAL_USE`, notificação persistente,
  contador monotônico de detecções e reciclagem periódica da engine (8 min) para se recuperar de
  stall silencioso. O comentário do código documenta a causa raiz: sem FGS, o microfone morre quando
  a tela bloqueia.
- `WakePreRoll.kt`: **anel de pré-roll** dos últimos segundos + captura de comando que termina por
  pausa (1 s), teto de 10 s, confirmação de fala em runs e piso de ruído pelo 30º percentil dos 4 s
  anteriores. Exatamente o problema de “perder a primeira sílaba” da captura de duração fixa.
- `AutonomySupervisorService.kt`: supervisor nativo de tarefas autônomas com identidade de tarefa,
  banco de checkpoints, pausa/retomada e **recusa de repetir ação incerta** depois de morte do processo.
- `JarvisAccessibilityService.kt` + `NativeOperator.kt`: árvore de acessibilidade, clicar por texto,
  digitar, rolar, esperar pacote/texto e voltar — automação real de UI, não só intents.
- `JarvisNotificationListener.kt` e `WhatsAppInbox.kt`: leitura e resposta por notificação.
- `brain/tools/registry.ts` e `dispatch.ts`: catálogo de ferramentas com **gate de permissão** e
  confirmação; `modelRanker.ts`: escolha de modelo por dificuldade e fallback.
- UI: HUD em Three.js/GLSL, tema claro/escuro, command palette, memória com digest diário.

É o projeto que melhor combina Android nativo, segundo plano e agente com ferramentas. O ponto fraco é
a complexidade: depende de um app desktop pareado e de várias permissões especiais.

### VarsshanCoder/JARVIS OS — roteador de ferramentas e contexto

Kotlin multimódulo (`core/background`, `core/speech`, `core/ui`) + backend Python/FastAPI com CrewAI.
O que interessa:

- `McpRouter.kt`, `McpTool.kt`, `McpToolResult.kt`: contrato de ferramenta com **resultado estruturado**
  e erro, no estilo MCP.
- `JarvisAccessibilityService.kt`: executor Android de `CLICK_TEXT`, `TYPE_TEXT`, `SCROLL`,
  `WAIT_PACKAGE`, `WAIT_TEXT`, `PRESS_BACK`, `PRESS_HOME`, `CAPTURE_TREE`.
- `RuleEngine.kt` + `ContextRepository`: contexto de dispositivo/localização/movimento com regras.
- `WakeWordForegroundService.kt`, `BootReceiver.kt`, `BatteryOptimizationHelper.kt`.
- README promete busca “grounded” e Qdrant RAG; o backend exige Qdrant Cloud e credenciais, então a
  independência do aparelho é menor.

O ponto forte é o **contrato de ferramenta com resultado** e o contexto por regras. O ponto fraco é
depender de backend Python e serviços externos para o agente principal.

### adewaskar/jarvis — HUD e gate de permissão

Interface React + Three.js + shaders GLSL próprios (núcleo, órbitas, partículas, lâminas, HUD),
ponte WebSocket com o Claude Agent SDK headless e **MCP servers** do usuário. O `dispatch` demonstra
um gate de permissão por ferramenta e a UI mostra o que foi executado. É a melhor referência visual e
de “vitrine” de ferramentas. Não tem Android nativo: controla o telefone por um MCP `android`.

### OpenJarvis — arquitetura de agentes e avaliação

Framework local-first em Python com extensão Rust. Oito agentes embutidos em três modos (on-demand,
agendado, contínuo): `deep_research`, `monitor_operative`, `orchestrator`, `native_react`,
`native_openhands` (CodeAct), `operative`, `simple`, entre outros. Skills seguem o padrão
`agentskills.io`; a avaliação trata energia, FLOPs, latência e custo como métricas de primeira classe.
É a melhor referência para **modos de agente, catálogo de skills e avaliação**, não para Android.

### microsoft/JARVIS (HuggingGPT) — pipeline de orquestração

Quatro estágios explícitos: **task planning → model selection → task execution → response generation**,
com um LLM como controlador e modelos especialistas como executores. É a referência conceitual mais
clara para transformar um pedido em grafo de tarefas e escolher executor. O projeto está parado desde
2025 e depende de modelos/HuggingFace; não é adequado como base Android.

### sukeesh/Jarvis — plugins simples

CLI Python com plugins registrados por decorator (`@plugin("nome")`), pacote de memória e testes de
plugin. A ideia útil é o **registro declarativo de capacidades**, com contrato pequeno e testável.
Não tem Android, voz contínua nem agentes.

### jgm-source/jarvis-opensource — voz em tempo real (referência restrita)

Assistente desktop com Gemini Live API, streaming de áudio nativo, wake word local, escada de nove
modelos com cooldown, painel de memória, skills autodescritivas e lip-sync por formantes. É a melhor
referência de **latência de voz e fallback de modelos**, mas a licença CC BY-NC impede reutilização
comercial. Nada foi copiado.

### Aryan-0001/Jarvis-AI — experimento

Flutter em um único `jarvis.dart`, Gemini via chave embutida, projeto Android incompleto e marcado
“under maintenance” pelo próprio autor. Não serve como base; serve como alerta contra chave de API
dentro do APK.

## 3. Comparação por critério

| Critério | Melhor referência | Por quê | O que o Nova já tem |
|---|---|---|---|
| Arquitetura Android | AnaaySampat | Kotlin nativo, FGS de microfone, acessibilidade, supervisor de tarefas | Capacitor + Java/Kotlin, FGS, watchdog, wake próprio |
| Reconhecimento de voz | AnaaySampat (local) / jgm (nuvem) | pré-roll + fim de fala vs. streaming Gemini Live | motor de locutor local próprio, TTS, wake word |
| Segundo plano | AnaaySampat / Varsshan | FGS tipado, boot receiver, bateria, reciclagem de engine | serviço em primeiro plano, boot receiver, watchdog |
| Automação | Varsshan / AnaaySampat | árvore de acessibilidade + contrato MCP + confirmação | intents, apps, mídia, alarmes, notificações, arquivos |
| Interface | adewaskar / AnaaySampat | HUD Three.js/GLSL, painéis, command palette | HUD/plasma/órbita 3D já implementados |
| Memória | OpenJarvis / Varsshan | traces, skills, RAG com contexto | memória local + cofre Obsidian + perfis |
| Ferramentas | AnaaySampat / Microsoft | gate de permissão, resultado estruturado, planejamento | ações validadas pelo Hermes, confirmação |
| IA/provedores | jgm / AnaaySampat | escada de modelos com cooldown / ranker | múltiplos provedores, fallback, IA local |
| Integração PC/TV | AnaaySampat | pareamento, tela, Wake-on-LAN | Electron no PC, arquivos e CAD |

## 4. Decisões de adoção

### Adotado agora (1.29.0)

1. **Pré-roll + VAD de fim de fala** (`escuta.js`), inspirado no `WakePreRoll`/`CommandCapture` do
   AnaaySampat. Reimplementado em JavaScript puro, sem copiar código: anel de 600 ms, piso de ruído
   pelo menor valor dos primeiros 400 ms, confirmação de 160 ms, fim após 1,2 s de silêncio, teto
   rígido. Integrado à captura de perfis de voz, à verificação na ativação e ao teste de microfone.

### Próximas fases (avaliadas e viáveis)

2. **Contrato de ferramenta com recibo de execução** (Varsshan/MCP + AnaaySampat): toda ação devolve
   `ok`, `efeito observado` e `erro`; o agente só afirma “feito” quando o recibo confirma. Encaixa no
   `Hermes.validarDecisao` e no registro de atividades.
3. **Supervisor de tarefas nativo** (AnaaySampat): identidade de tarefa, checkpoint, pausa/stop,
   proibição de repetir ação incerta após morte do processo. Exige mudança no serviço Java e testes
   de processo.
4. **Árvore de acessibilidade** (Varsshan/AnaaySampat): `CLICK_TEXT`, `TYPE_TEXT`, `SCROLL`,
   `WAIT_TEXT`, `CAPTURE_TREE` como ferramentas opt-in, com confirmação e escopo por app. É a maior
   alavanca de automação real, mas também a de maior risco de privacidade; precisa de configuração
   explícita e botão de parada.
5. **Roteador de modelos por dificuldade/custo** (AnaaySampat/jgm): ranking e cooldown por provedor,
   com métricas de latência e falha. O Nova já tem fallback; falta a política explícita.
6. **Catálogo de skills** (OpenJarvis/sukeesh): registro declarativo, descrição, permissões e teste
   por skill, em vez de ações espalhadas no `app.js`.
7. **Avaliação de energia/latência** (OpenJarvis): medir tempo de primeira palavra, duração de captura
   e consumo em repouso no Poco X7, com orçamento por versão.
8. **UI**: manter o HUD atual (já competitivo) e evoluir com o padrão de painéis/command palette do
   adewaskar, sem reescrever a cena 3D.

### Rejeitado

- **Copiar o Flutter do Aryan**: projeto incompleto e chave embutida no APK.
- **Adotar o backend Python/CrewAI/Qdrant do Varsshan**: adiciona servidor e dependência de nuvem a um
  app que hoje funciona localmente.
- **Usar código do jgm**: licença CC BY-NC 4.0 incompatível com distribuição comercial.
- **Trocar o motor de locutor local por nuvem**: perde privacidade e offline; a comparação mostra que
  o diferencial do Nova é justamente a identificação local.

## 5. Lacunas do J.A.R.V.I.S. Nova reveladas pela comparação

1. Captura de voz de duração fixa (corrigido nesta versão).
2. Falta de árvore de acessibilidade para automação de UI; hoje o app depende de intents.
3. Falta de supervisor de tarefas com checkpoint nativo e proibição de repetição após crash.
4. Ferramentas sem recibo padronizado de execução.
5. Sem política explícita de ranking/custo de modelos (só fallback).
6. Sem catálogo de skills com permissões declaradas.
7. Sem medição contínua de latência/energia por versão.
8. Sincronização PC↔Mobile ainda manual por exportação.

## 6. Riscos e limites

- A análise é estática; nenhum projeto de referência foi executado neste ambiente.
- Estrelas medem popularidade, não qualidade. `microsoft/JARVIS` tem 25 mil estrelas e está parado;
  `AnaaySampat` tem 21 e é a melhor base Android.
- Acessibilidade e leitura de notificações exigem permissões especiais e política de loja; qualquer
  adoção precisa de opt-in, escopo e botão de parada.
- O VAD desta versão foi validado com sinais sintéticos. Ruído real, eco e sotaque precisam de teste
  no aparelho.
- Nenhuma biblioteca de terceiros foi adicionada; a licença do Nova permanece independente.
