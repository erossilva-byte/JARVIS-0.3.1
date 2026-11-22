# Rastreabilidade dos oito repositórios — J.A.R.V.I.S. Nova 1.32.0

Data: 31/10/2026. Método: leitura de README, licença, manifesto e código dos forks já clonados em `refs/`
(análise iniciada em 1.29.0) + implementação própria no Nova. Nenhum código de terceiro foi copiado.
Estados: **implementado**, **aprimorado**, **parcial**, **pendente**, **incompatível**.

## Licenças e limites de reaproveitamento

| Repositório | Licença | Decisão |
|---|---|---|
| adewaskar/jarvis | MIT | Ideias de HUD, gate de permissão e MCP; sem copiar a ponte Claude/React. |
| open-jarvis/OpenJarvis | Apache-2.0 | Ideias de skills, agentes e avaliação; backend Python não adotado. |
| microsoft/JARVIS | MIT | Pipeline de planejamento/model selection; modelos HuggingFace não adotados. |
| jgm-source/jarvis-opensource | CC BY-NC 4.0 | Apenas referência comportamental; **nenhum código reutilizado** por restrição não comercial. |
| sukeesh/Jarvis | MIT | Ideia de catálogo declarativo de plugins, reimplementada. |
| AnaaySampat/jarvis | MIT | Melhor referência Android para acessibilidade, FGS e supervisor. |
| Aryan-0001/Jarvis-AI | MIT | Projeto Flutter incompleto e chave embutida; **incompatível** como base. |
| VarsshanCoder/JARVIS-OS | Apache-2.0 | Contrato de ferramenta e executor de acessibilidade; backend/Qdrant não adotados. |

## Matriz de recursos

| Repositório | Recurso relevante | Estado no Nova 1.32.0 | Evidência e teste |
|---|---|---|---|
| adewaskar | HUD 3D, partículas, shaders e painéis orbitais | **aprimorado (já existia)** | `orbita.js`, `style.css`, `index.html`; HUD/plasma/órbita preservados. Sem teste visual em aparelho. |
| adewaskar | Gate de permissão por ferramenta e histórico do que foi executado | **implementado** | `sistema.js`: níveis leitura/escrita/execução, `confirmar` injetado, traces sem valores; `tests/test_sistema.js`. |
| adewaskar | MCP servers e ferramentas externas | **parcial** | Catálogo/contrato pronto; cliente MCP remoto não implementado. Sem servidor MCP no APK. |
| open-jarvis | Skills/plugins descobertos por catálogo | **implementado (núcleo)** | `SISTEMA.registrarFerramenta`, `descobrir`, `listarFerramentas`, central Sistema. |
| open-jarvis | Agentes on-demand, agendados e contínuos | **parcial** | Agentes e planos existentes; tarefas persistentes de ferramentas com checkpoint. Falta agente contínuo nativo. |
| open-jarvis | Avaliação de energia, latência, FLOPs e custo | **parcial** | Latência de provedores já medida; diagnóstico de microfone; benchmark de energia/FLOPs pendente. |
| microsoft/JARVIS | Planejamento → seleção → execução → resposta | **aprimorado (já existia)** | `plano.js` + `agentes.js` + `executarSeguro`; 25 testes de plano e integração. |
| microsoft/JARVIS | Seleção de modelos especialistas | **parcial** | `Hermes.planejarIA` escolhe por tarefa/latência/falha; custo/energia explícitos ainda pendentes. |
| jgm-source | Wake word local, STT, TTS e briefing | **já existia / preservado** | `JarvisService`, `JarvisAtivacao`, `hermes.js`, `voz_motor.js`; sem validação de campo. |
| jgm-source | Rodízio de chaves/modelos com cooldown | **aprimorado (já existia)** | `pausas`, `errosIA`, `planejarIA`; testes de fallback. |
| sukeesh/Jarvis | Plugins declarativos com contrato pequeno | **implementado** | `sistema.js` + ferramentas locais; teste de registro/duplicata/permissão. |
| sukeesh/Jarvis | Calculadora, conversão, QR, PDF, jogos e clima | **parcial** | Calculadora, unidades, senha, JSON, hash, datas, clima e PDF já existentes. QR e jogos pendentes. |
| AnaaySampat | AccessibilityService para operar apps | **implementado, não testado em aparelho** | `JarvisAcessibilidade.java`: árvore, clique, digitar, rolar, esperar, voltar/início; senha omitida. |
| AnaaySampat | FGS de microfone, boot receiver e watchdog | **já existia / preservado** | `JarvisService`, `JarvisBootReceiver`, `JarvisWatchdog`; build compila, campo pendente. |
| AnaaySampat | Supervisor de tarefas com checkpoint e não repetir incerto | **implementado no núcleo** | `sistema.js`: `criarTarefa`, `executarTarefa`, persistência, pausa/retomada; `tests/test_sistema.js`. |
| AnaaySampat | STOP flutuante em qualquer app | **parcial** | Botão **Parar tudo** na central e parada do serviço; overlay flutuante não implementado. |
| AnaaySampat | Pareamento PC, tela remota, TV e WhatsApp | **pendente** | Windows/arquivos/CAD já existem; pareamento, tela remota e TV não. |
| Aryan-0001 | Flutter + Gemini com chave no APK | **incompatível** | Não adotado: projeto incompleto e segredo embutido. Nova usa cofre Android/Keystore. |
| Aryan-0001 | Visão experimental | **já existia / preservado** | `visao.js` + câmera + balões; sem teste de campo. |
| Varsshan | Executor CLICK_TEXT/TYPE_TEXT/SCROLL/WAIT/CAPTURE_TREE | **implementado** | `JarvisAcessibilidade` + plugin + `ACOES`; `tests/test_v1_32_0.py` e build Android. |
| Varsshan | Contrato de ferramenta com resultado estruturado | **implementado** | `{ok, resultado, erro, codigo, duracaoMs, traceId}` em `sistema.js`; testes. |
| Varsshan | Qdrant/RAG e backend FastAPI/CrewAI | **pendente / rejeitado como dependência** | Memória local/Obsidian preservada; RAG vetorial não implementado. Não se adiciona backend externo obrigatório. |
| Varsshan | Contexto por regras e busca grounded | **parcial** | Hermes e pesquisa com fontes existentes; regras de contexto dedicadas pendentes. |

## O que foi realmente adicionado nesta versão

1. `sistema.js`: catálogo, permissões, timeout, eventos, traces, detecção de injeção, tarefas persistentes e ferramentas locais.
2. `JarvisAcessibilidade.java` + `JarvisAcessibilidadePlugin.java`: automação Android opt-in.
3. `patch_manifest.py`: serviço, permissão de binding e XML de configuração.
4. `app.js`: integração com voz, `ACOES`, central Sistema, seleção de microfone, diagnóstico de áudio e parada de emergência.
5. `index.html`/`style.css`: central operacional e painel.
6. Testes: `tests/test_sistema.js` (17) e `tests/test_v1_32_0.py` (contrato estático).

## Limitações honestas

- **Sem aparelho Android** neste ambiente: acessibilidade, microfone, wake word, TTS, barge-in, FGS e instalação não foram validados em campo.
- A árvore de acessibilidade é opt-in e depende do serviço habilitado; apps com `FLAG_SECURE`, WebViews ou virtualização podem recusar nós/ações.
- Não há clique por coordenada, gesto livre, overlay flutuante, MCP remoto, RAG vetorial, avatar com visemas, TV ou ESP32 nesta fase.
- Tarefas persistentes são reais no núcleo, mas ainda não há um agente autônomo que as crie sozinho em segundo plano; a criação é explícita.
- A calculadora é um parser próprio e limitado; não é um CAS simbólico.
- O diagnóstico de áudio mede o stream local por 1,2 s; não substitui medição de latência acústica em hardware real.
