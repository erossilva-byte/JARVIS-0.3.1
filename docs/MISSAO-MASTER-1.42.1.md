# Missão Master — auditoria e entrega (base 1.42.1)

> Branch: `feat/evolucao-1.42.0` · versão 1.42.1 / versionCode 10421 · build publicado.
> Este documento é a entrega da **Fase 1 (auditoria)** com evidências reais. Ele **não** afirma
> que a evolução completa foi concluída: as fases 2 a 5 estão listadas como pendentes, com
> prioridade e justificativa. Nada aqui foi declarado pronto só por existir no código.

## 1. Inventário de funcionalidades (classificação honesta)

Legenda: **FT** funcionando e testada (contrato automatizado) · **INT** implementada, não testada
em aparelho · **PAR** parcial · **DEF** defeituosa · **AUS** ausente.

| Área | Classificação | Evidência |
| --- | --- | --- |
| Núcleo 3D / plasma / HUD | INT | `orbita.js`, `avatar.js`; jsdom confirma DOM/animação, sem validação visual em aparelho |
| Voz STT (Automático/Groq/Android/local), VAD, WAV 16 kHz | FT (contrato) | `test_fala.js`, `test_audio_pcm.js`, `test_voz_motor.js`, `test_stt_avancado.py` |
| TTS masculino PT-BR + voz neural offline | INT | `fala.js`, `JarvisVozPlugin.java`; contrato nos testes, sem medição acústica |
| Wake word "Jarvis" (detector fonético próprio) | FT (contrato) | `test_ativacao.js`, `test_ativacao_propria.py`, `JarvisAtivacao.java` |
| Jarvis Core (planejar → executar → verificar, recuperação por componente) | FT (contrato) | `test_core.js`, `core.js` + registro em `app.js` |
| Agentes e recibos de execução | FT (contrato) | `test_agentes.js`, `agentes.js` |
| Provedores cloud (Groq, Gemini, Mistral, Cerebras) | PAR | fallback e validação implementados; sem chave/rede não há teste ao vivo |
| IA local (MediaPipe `.task`, Gemma 3 1B) | INT | `JarvisLocalAIPlugin.java`, `test_local_ai.py` (25 contratos); **sem modelo real executado** |
| Memória local + Obsidian | FT (contrato) | `test_memoria_md.js`, `test_memoria_semantica.js`, `memoria.js` |
| Pessoas / identificação (voz e rosto) | INT | `identidade.js` (consentimento, limiar/margem, open-set), `test_identidade.js`, `test_pessoas*.js`; câmera/mic reais não testados |
| Vision (imagem/vídeo, balões, transcrição) | PAR | `visao.js` (geometria testada) + análise por IA; sem chave/rede não há teste real |
| Arquivos e CAD | FT (contrato) | `test_cad_formatos.js`, `test_cad_pacote.py`, `test_cad_projeto.js`, `test_arquivos_sistema.py` |
| Tarefas persistentes, rotinas, alarmes | FT (contrato) | `test_plano.js`, `test_plano_integracao.py`, `test_segundo_plano*.py`, `JarvisAlarmScheduler.java` |
| Acessibilidade (leitura/clique de tela) | INT | `JarvisAcessibilidade*.java`, contratos de UI; não exercitado em aparelho |
| Segundo plano (FGS por tipo, boot, watchdog) | INT | `JarvisService.java` escolhe `MICROPHONE`/`DATA_SYNC` conforme permissão; `JarvisBootReceiver`, `JarvisWatchdog` |
| Bloqueio opcional (PIN, biometria, recuperação) | INT | `JarvisSeguranca.java`, `test_secure_keys.py`; biometria real não testada |
| Painel PC / Windows (Electron) | PAR | `pc.js` só liga com `window.jarvisNative`; contratos `test_pc_*.js/py`; não aberto em Windows aqui |
| Atualização interna (download/instalação) | PAR | `JarvisUpdatePlugin.java`, `#upd-*`; fluxo real não executado |
| Interface (13 painéis, abas, áreas) | FT (runtime) | auditoria jsdom: 13 painéis abrem e fecham simetricamente, 0 erros, 0 IDs duplicados |
| Botões da interface | FT (runtime) | 300 botões, 239 medidos com clique real, 0 exceções; 15 sem efeito classificados |
| Windows nativo | AUS | preparado por `platforms/desktop`; sem build/validação Windows nesta máquina |

## 2. Problemas encontrados e causas

1. **"Liberar memória" (voz neural) mudo sem plugin** — `if (!p) return;` no handler, sem
   mensagem. Causa: guarda de disponibilidade sem feedback, diferente dos botões irmãos.
2. **Microfone do núcleo mudo sem backend de áudio** — `gravar()` devolvia `null` e
   `ouvirUmaVez` tratava como "sem fala". Causa: dois significados no mesmo retorno (`null` =
   cancelado *e* sem backend).
3. **Auditoria anterior superestimava "botões falsos"** — a primeira versão do auditor carregava
   zero scripts (regex apagava `<script src>`), marcando 277/277 sem efeito. Causa: regex de
   remoção de scripts inline. Corrigido; números válidos só depois disso.
4. **`VERSAO.json.notas` quebrava contratos históricos** — os testes 1.15/1.39/1.40 exigem
   palavras-chave (plasma, animação, raciocínio, personalidade, áreas, flash). Causa: notas
   reescritas sem checar os contratos. Corrigido antes do build.

Nenhum defeito de arquitetura, dependência circular ou inicialização duplicada foi encontrado
nesta varredura: o boot em jsdom termina com **0 erros**, sem IDs duplicados e sem exceções em
nenhum dos 13 painéis.

## 3. Correções efetivamente implementadas

- `#c-neural-liberar` agora responde com mensagem de indisponibilidade sem o plugin.
- Microfone: falha de backend vira mensagem; cancelamento continua silencioso.
- Regressão nova `tests/test_botoes_honestos.js` no `test:all` (três cenários do botão neural +
  clique real no microfone com app completo).
- Auditoria permanente de efeito (instrumento local, `artifacts/audit_buttons_effect.js`).
- Verificações estáticas: ações das áreas × `acaoNavegacao`, IDs únicos, `label for`, `href="#"`,
  `onclick` inline, handlers vazios.

## 4. Funcionalidades testadas e evidências

| Verificação | Resultado |
| --- | --- |
| `npm run test:all` | **EXIT 0**, 2.088 `OK`, 0 falhas (89 arquivos de teste) |
| Auditoria de efeito de botões | 300 encontrados, **239 medidos**, 0 exceções, 0 erros de boot |
| Auditoria de painéis | 13 painéis abrem/fecham, 0 erros, 0 IDs duplicados |
| Ações das áreas | 24/24 com caso no roteador |
| HTML estático | 636 IDs únicos, nenhum `label for` quebrado, nenhum `onclick` inline |
| Plugin de IA local | 25 contratos verificados (`test_local_ai.py`) |

## 5. Pendências e justificativas

- **Teste em aparelho físico (Poco X7 / Android 16)**: sem dispositivo nesta máquina. Bloqueia
  mic real, wake word, biometria, câmera, FGS, bateria e instalação do APK.
- **IA local com modelo real**: exige baixar um `.task` (centenas de MB) e rodar no aparelho;
  os contratos provam a integração, não a inferência.
- **Provedores cloud ao vivo**: sem chaves/rede de teste, o caminho real não foi exercitado.
- **Vision com imagem real**: depende de provedor configurado.
- **Painel PC/Windows**: só liga no Electron; build Windows não executado aqui.
- **Fases 2–5 da missão** (arquitetura, inteligência, interface, otimização): planejadas abaixo,
  não implementadas nesta rodada — declará-las prontas seria desonesto.

## 6. Análise dos oito projetos de referência (o que foi aproveitado ou descartado)

Nada de código foi copiado; a comparação é arquitetural e respeita licenças.

| Projeto | Licença | Achado útil | Decisão |
| --- | --- | --- | --- |
| `adewaskar/jarvis` | MIT | capability probing (`/health`) escolhe motor no boot; VAD local para barge-in; tool gate default-deny | **Adotar o conceito** de probe de capacidades e gate por risco (já há `risco`/`disp` no `hermes.js`); descartar a ponte Node |
| `open-jarvis/OpenJarvis` | Apache 2.0 | interface única de engine, memória híbrida, skills sob demanda, agentes agendados | Parcialmente já existe (provedores atrás de função, memória híbrida local, rotinas); adotar "tool budget" para o modelo 1B |
| `microsoft/JARVIS` | MIT | plano em JSON com dependências (DAG) e resultados parciais | **Adotar** como evolução do `plano.js` (dependências explícitas) — pendente |
| `jgm-source/jarvis-opensource` | **CC BY-NC 4.0** | cascata de provedores com cooldown, confirmação + undo, memória em 2 camadas | **Descartar código** (licença não comercial); conceito de cooldown/quota é adotável |
| `sukeesh/Jarvis` | MIT | registro declarativo de plugins com requisitos de plataforma | Já existe no formato de ferramentas do `hermes.js`; manter |
| `AnaaySampat/jarvis` | MIT | roteador multi-provedor com ladder de quota; brain TS + plugin nativo fino | **Adotar** o ladder com quarentena por quota — pendente |
| `Aryan-0001/Jarvis-AI` | MIT | intents diretos para comandos triviais | Só a ideia; código é single-file com chave no cliente — descartado |
| `VarsshanCoder/JARVIS-OS-...` | Apache 2.0 | tool call validado no meio, matriz de acessibilidade, regra de frescor/"não pude verificar" | **Adotar** a regra de verificação factual e a matriz de ações — pendente |

## 7. Situação da compilação e do GitHub Actions

- Release `v1.42.1` publicada (não draft, não pré-release) em 2026-11-03T09:59:19Z.
- Run do APK `41615261533`: **sucesso** em 2m16s. Run do PC `41615261503`: **sucesso**.
- APK `jarvis-nova-1.42.1-10421.apk` — 81.209.170 bytes, SHA-256
  `506ee0a5c45919f095942f91b496a1fad1c00bc6c99038d15f730d68502ae013`, baixado e conferido;
  `app.js` interno declara `VERSAO_APP = '1.42.1'` e o HTML interno tem 6 chips `v1.42.1`.
- Instaladores Windows no mesmo release: `J.A.R.V.I.S.Nova.1.42.1.exe` (82.065.217 bytes) e
  `Setup` (82.230.973 bytes).

## 8. Link direto do APK

https://github.com/erossilva-byte/JARVIS-0.3.1/releases/download/v1.42.1/jarvis-nova-1.42.1-10421.apk

## 9. Limitações conhecidas e próximos passos priorizados

1. **Validar em aparelho** (bloqueado sem dispositivo): instalar o APK, microfone, wake word,
   FGS, biometria, câmera, bateria e desempenho no Poco X7.
2. **Ladder de provedores com quarentena** (AnaaySampat/OpenJarvis): falha/quota tira o provedor
   por N minutos e o roteador escolhe o próximo; testável em jsdom.
3. **Tool budget para Gemma 1B**: expor 3–5 ferramentas por turno em vez do catálogo inteiro.
4. **Regra de verificação factual** (VarsshanCoder): consulta factual sem fonte verificada
   responde "não pude verificar" em vez de inventar.
5. **Plano com dependências (DAG)** no `plano.js`, com progresso por etapa na interface.
6. **Testes de migração/backup** entre versões para garantir que dados do usuário sobrevivem.
7. **Windows**: empacotar e abrir o instalador em uma máquina Windows antes de prometer suporte.
