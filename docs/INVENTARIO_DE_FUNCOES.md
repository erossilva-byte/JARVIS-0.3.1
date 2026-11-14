# Inventário de funções — J.A.R.V.I.S. Nova

Estado em 2026-11-11, branch `work/1.48.0-fase2-consolidacao`, após o ajuste 008.
Gerado por leitura do código (registro `ACOES`, plugins Java, services Dart, workflows). **Não é inventário de campo**: nada aqui foi testado em aparelho nesta auditoria.

Estados: **Verificada** (teste real com evidência) · **Parcial** (funciona com limites) · **Com falha conhecida** · **Não implementada** · **Fora de escopo** · **Não verificado** (existe no código, sem teste de campo).

## Núcleo e IA

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Conversa com provedores de nuvem | Sim | Sim | Parcial | `app.js`, `hermes.js`, testes de motor | chave do usuário | Sem teste com chaves reais |
| Failover entre provedores | Sim | Sim | Parcial | `app.js` | ≥1 chave | Ordem de prioridade fixa em código |
| IA local Gemma 3 1B (.task) | Sim | Não | Parcial | `JarvisLocalAIPlugin.java`, `MODELOS-IA-LOCAL.md` | modelo importado | ~529 MB, CPU, sem streaming |
| Agentes especializados | Sim | Sim | Parcial | `agentes.js`, `tests/test_agentes.js` | provedor | Sem verificação de resultado no campo |
| Planos multi-etapas | Sim | Sim | Parcial | `plano.js`, `docs/REGISTRO-1.31.0.md` | provedor | Sem retomada após morte do processo |
| Personalidade e humor | Sim | Sim | Parcial | `humor.js`, `identidade.js` | — | Calibragem não avaliada por humano |
| Cofre de chaves de API | Sim | Sim | Verificada (código e testes) | `JarvisUtilPlugin.java` (AES-256-GCM + AndroidKeyStore), `platforms/desktop/main.js` (`safeStorage`, `0o600`, troca atômica), `tests/test_secure_keys.py` | — | Sem teste em aparelho/Windows real |
| PIN e código de recuperação | Sim | Sim | Verificada (código e testes) | `app.js` PBKDF2-SHA256, sal por instalação, 120k iterações, migração do hash antigo | — | Sem teste de digitação no aparelho |
| Biometria de voz (perfil vocal) | Sim | Não | Parcial | `identidade.js` AES-GCM com **chave local** | microfone | Chave no mesmo armazenamento: ofuscação, não cofre |
| Modo offline | Sim | Parcial | Parcial | `MODO-OFFLINE.md`, `seguranca.js` | — | Depende de pacote de voz do aparelho |

## Voz

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| KWS local sherpa-onnx | Sim | Não | Parcial | `JarvisKwsEngine.java` | RECORD_AUDIO | Modelo **inglês**; precisão pt-BR não medida |
| KWS no Flutter | Sim (branch) | Não | Não verificado | `KwsForegroundService.kt`, `kws_bridge.dart`, 23 testes | microfone | Nunca executado em aparelho |
| Serviço de escuta em segundo plano | Sim | Não | Parcial | `JarvisService`, `patch_manifest.py` | FOREGROUND_SERVICE_MICROPHONE | Restrições Android 14+/HyperOS não validadas |
| STT pt-BR | Sim | Sim | Parcial | `escuta.js`, `JarvisVozPlugin.java` | RECORD_AUDIO | On-device depende do aparelho |
| TTS pt-BR | Sim | Sim | Parcial | `fala.js`, `voz_motor.js` | pacote de voz | Voz masculina grave não garantida |
| Barge-in / interrupção | Sim | Sim | Parcial | `voz_motor.js` | — | Sem medição de eco |

## Memória e pessoas

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Cofre de notas temático | Sim | Sim | Parcial | `memoria.js` (`localStorage`), `tests/test_memoria_md.js` (gravação e leitura reais dos `.md` em disco, separador `---` preservado) | — | **Não é cofre Obsidian em disco**; texto puro no armazenamento local |
| Busca semântica local | Sim | Sim | Parcial | `memoria.js` (hash+cosseno) | — | Embedding por hash, não modelo |
| Cofre real via SAF (Fase 7B) | Não | Não | Não implementada | — | permissão de pasta | WAL, FTS5, conflitos ausentes |
| Fichas de pessoas | Sim | Sim | Parcial | `pessoas.js`, `tests/test_pessoas.js` | consentimento | Sem criptografia dedicada |
| Reconhecimento facial local | Não | Não | Não implementada | — | câmera | Sem modelo facial integrado |
| Identificação por voz | Sim | Não | Parcial | `JarvisVozPlugin.java`, `test_pessoas_voz.js` | microfone | Perfil vocal simples |

## Ações do dispositivo (registro `ACOES`, 55 entradas)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Hora, clima, pesquisa | Sim | Sim | Verificada (motor) | `ACOES` risco 0 | rede (clima) | Clima depende de API |
| Abrir app, volume, lanterna | Sim | Parcial | Parcial | `ACOES` risco 1, `JarvisUtilPlugin` | — | Lista de apps conhecidos |
| Ligações e SMS | Sim | Não | Parcial | `ACOES` risco 2 | CALL_PHONE | Confirmação obrigatória |
| WhatsApp com texto pronto | Sim | Sim | Parcial | `ACOES` risco 2 | — | Envio final é do usuário |
| Acessibilidade (clicar/digitar/rolar) | Sim | Não | Parcial | `JarvisAcessibilidade.java` | serviço opt-in | Não validado contra blocklist em campo |
| Notificações (ler/responder) | Sim | Não | Parcial | `JarvisNotificationListener.java` | acesso especial | Resposta só com ação rápida |
| Alarmes e lembretes | Sim | Parcial | Parcial | `JarvisAlarmScheduler.java` | SCHEDULE_EXACT_ALARM | Alternativa quando negado |
| Bloquear tela | Sim | Sim | Parcial | `ACOES` risco 2 | acessibilidade | Sem admin do dispositivo |
| Desligar PC | Não | Sim | Não verificado | `ACOES` risco 3 | — | `powershell.exe` |
| Fechar outros apps | Sim | — | Parcial | `MODO-OFFLINE.md` | — | Android não permite |

## Interface e plataforma

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Interface atual (Capacitor/Web) | Sim | Electron | Verificada (CI) | `index.html`, `style.css` | — | **Contraria a regra 15 do prompt** |
| Interface Flutter nativa | Sim (branch) | Sim (branch) | Parcial | `lib/` em 9 módulos (`main`, `home_screen`, `command_center`, `catalog`, `ui_common`, `hologram`, `pages`, `systems_view`, `drawer`) | — | Núcleo, Sistemas, Ajustes e Provedores |

## Arquivos, CAD e desenvolvimento

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Arquivos (criar/editar/analisar) | Sim | Sim | Parcial | `arquivos_dev.js`, `platforms/desktop/arquivos.js`, `tests/test_arquivos_dev.js` (PDF/DOCX/XLSX/CSV/ZIP revalidados por leitor independente) | seletor | Sem OCR embarcado; ponte do Electron sem teste |
| Sandbox de execução | Sim | Sim | Parcial | `sandbox.js`, `tests/test_sandbox.js` (limites e isolamento por contrato) | — | Sem isolamento de SO; execução real em navegador não exercitada |
| CAD próprio (`.cad` JSON) | Sim | Sim | Parcial | `cad.js`, `cad_projeto.js`, `CAD-MOBILE.md` | — | Primitivas facetadas, sem B-rep |
| CADeSIMU importar/exportar | Não | Não | Inviável | `CAD-MOBILE.md` | — | Formato sem especificação pública |
| Git/GitHub integrado | Não | Parcial | Não verificado | `pc.js` | token | Não auditado nesta fase |

## Entrega

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| APK debug pelo CI | Sim | — | Verificada | `build-apk.yml` #66 verde; compilação Android 36 verde no CI `42923146108` | — | Só debug |
| Release assinada | Sim | Sim | Parcial | `patch_gradle.py`, `release-apk.yml` (secrets + recusa de `CN=Android Debug`) | 4 secrets | Workflow só roda em tag; falta configurar os secrets |
| Atualização in-app | Sim | Sim | Parcial | `JarvisUpdatePlugin.java` | REQUEST_INSTALL_PACKAGES | Conflita com a Fase 10C |
| Paridade Windows em Flutter | — | Não | Não implementada | — | — | Só existe em Electron |

## O que mudou desde o relatório anterior

- **Release assinada**: de *com falha conhecida* para *Parcial* — assinatura separada da de debug, dependente dos secrets.
- **Android SDK**: `compileSdk`/`targetSdk` em 36; AGP 8.13, Gradle 8.13.
- **Chave de assinatura fora do repositório**: `.gitignore` cobre `*.jks`/`*.keystore` e um teste reprova se alguma chave de release for versionada.
- **Matriz de capacidades do Flutter (2026-11-11)**: dos 21 módulos do catálogo, 1 implementado (Provedores de IA), 3 parciais (Voz/KWS, Avatar 3D, Segurança), 16 não migrados e 1 fora de escopo; fonte em `docs/MATRIZ-CAPACIDADES-FLUTTER.md`.
- **Contrato de conversa auditado (2026-11-11)**: rota do turno verificada no código (Core → projetista → pessoas → Hermes → IA), persona/humor injetados por `promptSistema()`, histórico por `COGNICAO.selecionarHistorico()` e ação sensível sempre por `executarSeguro()` (risco ≥ 2 confirma; ≥ 3 pede PIN). Corrigidos o histórico fora de ordem e a checagem de repetição que nunca disparava; fonte em `docs/relatorios/2026-11-11_006_contrato-de-conversa.md`.
- **Credenciais auditadas (2026-11-11)**: chaves de API no AndroidKeyStore (AES-256-GCM) no Android, `safeStorage` com arquivo `0o600` e troca atômica no desktop, falha fechada sem cofre e remoção da cópia em claro migrada; PIN e recuperação em PBKDF2-SHA256 com sal e 120k iterações; biometria de voz e memória pessoal **não** têm cofre de hardware (chave local / texto puro) e assim estão declaradas. Fonte em `docs/relatorios/2026-11-11_007_persistencia-de-credenciais.md`.
- **Cofre Obsidian em disco (2026-11-11)**: o formato por tópico (`Memoria/*.md`) foi exercitado com arquivos reais — gravados em pasta temporária, relidos e reimportados, com acentos preservados, nomes saneados (barra não vira pasta) e reimportação idempotente. A importação deixou de truncar a nota no primeiro separador `---` do corpo, que antes descartava o texto seguinte em silêncio; regressões travadas em `tests/test_memoria_md.js`. Ponte de pasta do Electron e SAF do Android seguem sem teste. Fonte em `docs/relatorios/2026-11-11_008_cofre-obsidian-em-disco.md`.
- **Visão e pessoas (2026-11-11)**: `visao_contexto.js` descartava todos os atributos que a análise visual trazia (`atributos: {}` fixo), então `comparar()` nunca encontrava diferença e a resposta caía sempre em "sem dados". Os atributos passaram a ser copiados com saneamento (chave/valor curtos, só texto ou número, teto de 12) e com a mesma regra da marca: sem evidência legível, não são mantidos. O teste do contexto visual, que injetava atributos à mão antes de comparar, passou a exercitar o caminho real e foi de 13 para 16 grupos. `pessoas.js` foi sondado (acento, caixa, apelido, ambiguidade, exportar/importar) sem defeito encontrado. Fonte em `docs/relatorios/2026-11-11_010_visao-e-pessoas.md`.
- **Ponte CADeSIMU (2026-11-11)**: `conferirTrocaCadesimu()` reprovava o projeto com ID repetido **sem nenhum item do checklist reprovado** — a pendência era empurrada direto na lista, e o relatório, que imprime o checklist, mostrava "1 pendência" seguido de todas as linhas OK. O ID repetido virou item próprio (`sem ID repetido`), com o ID no detalhe, e o teste passou a exigir que toda pendência corresponda a uma verificação reprovada. Fonte em `docs/relatorios/2026-11-11_011_cadesimu.md`.
- **Arquivos e sandbox (2026-11-11)**: o motor de arquivos do app (`arquivos_dev.js`) ganhou teste de comportamento que não confia no próprio módulo — os bytes de PDF, DOCX, XLSX, CSV e ZIP são reabertos por um leitor escrito no teste, com CRC recalculado e parser de CSV independente. As bordas do motor do PC foram conferidas em pasta temporária real: caminho fora da pasta recusado, `apagar ~` recusado, nenhum `.tmp` sobrando e nada criado fora da raiz. Fonte em `docs/relatorios/2026-11-11_009_arquivos-e-sandbox.md`.
- **CI da branch verde no commit `20168c8`**: regressão completa, compilação Android 36 e portão Flutter (Android + Windows) no mesmo SHA.
- Nenhuma regressão registrada.

## Interface — camada visual v3 (ajuste 013, 2026-11-12)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Núcleo 3D animado próprio (`nucleo_v3.js`) | Sim | Sim | Parcial | `nucleo_v3.js`, `tests/test_interface_dom.js` (80), suíte 2.353, tela real | nenhum (sem dependência) | Sem medição em aparelho físico |
| Reação do núcleo ao microfone e ao estado | Sim | Sim | Parcial | `--nv`, `body[data-state]`, `MutationObserver` | microfone liberado | Nível vem do app; sem calibração por aparelho |
| Pele visual nova (`nucleo_v3.css`) | Sim | Sim | Parcial | Estilos carregados por último; testes de DOM verdes | navegador com CSS moderno | Sem revisão visual em celular real |
| Transcrição em coluna cheia | Sim | Sim | Verificada | Tela real: área 820×575, cabeçalho acima da lista | — | — |
| Empacotamento dos arquivos novos | Sim | Sim | Verificada | `tests/test_empacotamento.py` exit 0 | — | — |
| Interface 100% Flutter nativa (prompt v2, regra 15) | Não | Não | Não implementada | UI atual em WebView | — | Migração inteira, fora desta entrega |

## Central de provedores — Fase 3 (ajuste 014, 2026-11-12)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Consumo de tokens por provedor (`consumo_ia.js`) | Sim | Sim | Verificada | `tests/test_consumo_ia.js` (23), suíte 2.353, tela real | resposta com campo `usage` | Sem chamada real: sem chave de provedor |
| Registro nos dois caminhos (normal e streaming) | Sim | Sim | Parcial | `anotarConsumo` em `chamar`; `usage` lido no SSE | streaming habilitado | Recuo do `stream_options` não exercitado em rede real |
| Exibição em Ajustes e no diagnóstico | Sim | Sim | Verificada | `#c-consumo-ia`, linha "Consumo de IA (tokens)" | — | — |
| Persistência entre aberturas | Sim | Sim | Parcial | `jv_consumo_ia` no armazenamento local | espaço livre | Não criptografado (são contagens, não conteúdo) |
| Cota restante estimada | — | — | Não implementada | — | API não padroniza | Só o limite informado no erro é mostrado |

## Escolha de motor pelo usuário (ajuste 015, 2026-11-12)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Motor principal e alternativo escolhidos na tela | Sim | Sim | Verificada | `tests/test_hermes.js` (28), suíte 2.361, tela real com gravação e reabertura | ao menos uma chave | Sem chamada real a provedor |
| Respeito à escolha mesmo com o provedor em pausa | Sim | Sim | Verificada | caso de teste do roteador | — | Escolher libera a pausa ao salvar |
| Escolha sem chave é ignorada, sem duplicar a fila | Sim | Sim | Verificada | casos de teste do roteador | — | — |
| Modelo alternativo por provedor | Sim | Sim | Parcial | `modeloRaciocinio`, `modelosVisao`, lista de reserva | — | A escolha ordena provedores, não fixa modelo |

## Delegação entre agentes (ajuste 016, 2026-11-12)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| 12 agentes especializados (inclui programação, engenharia, eletrônica) | Sim | Sim | Verificada | `tests/test_agentes.js` (75) | — | Mapeamento por padrão de nome de ação |
| Registro de delegação (`de`, `para`, `tarefa`) no recibo | Sim | Sim | Verificada | teste de recibo | — | — |
| Validação da cadeia antes de concluir (`verificarTarefa`) | Sim | Sim | Verificada | elo ok / incerto / cancelado / aberto | — | Reprovação só aparece em plano; conversa simples valida por etapa |
| Plano reprovado não é anunciado como concluído | Sim | Sim | Parcial | `app.js` + teste estático | — | Sem plano real por falta de chave de provedor |
| Desempenho por agente no diagnóstico | Sim | Sim | Parcial | `porAgente()`, linha "Agentes especializados" | — | Não visto renderizado na tela |

## Modo de desenvolvimento com autorização (ajuste 017, 2026-11-12)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Leitura livre (analisar, testar, exportar, listar) | Sim | Sim | Verificada | `tests/test_modo_dev.js` (17) | — | — |
| Escrita exige autorização ativa (`corrigir`, `criar`, `editar`, `aplicar`, `projeto`) | Sim | Sim | Verificada | porta fechada por padrão | — | Prazo máximo de 240 min |
| Autorização expira sozinha (padrão 30 min) | Sim | Sim | Verificada | relógio simulado 9/11 min | — | — |
| Operação desconhecida negada | Sim | Sim | Verificada | `classe: desconhecida` | — | — |
| Registro de cada tentativa, inclusive recusada | Sim | Sim | Verificada | histórico com `permitido` e motivo | — | 40 entradas |
| Bloqueio de escrita no código do próprio app | Sim | Sim | Parcial | `ehCodigoDoProjeto` + gate em `executarSeguro` | — | Sem IA real; não exercitado na tela |
| Seção de autorização no painel Dev. Arquivos | Sim | Sim | Verificada | conferência na tela 13/11 (desligado → ativo → bloqueado) e em 360/320 px sem sobreposição nem corte | — | WebView, não aparelho físico |

## Painéis em telas pequenas (ajuste 018, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Abas das utilidades filtram a seção | Sim | Sim | Verificada | 1 seção visível por aba, em 360 e 320 | — | — |
| Seções das utilidades com respiro lateral | Sim | Sim | Verificada | primeiro elemento em x=14 | — | — |
| Abas das utilidades sem encolher/transbordar | Sim | Sim | Verificada | 65–87 px, sem sobreposição | — | — |
| Botões de Pessoas em linha inteira (≤420 px) | Sim | Sim | Verificada | 334×40 em 360; 294×40 em 320 | — | — |
| Selo do painel com largura do texto | Sim | Sim | Verificada | 42 px ("v1.46.0") e 129 px (dev) | — | — |
| Auditoria de 16–18 aberturas de painel | Sim | Sim | Verificada | 0 corte, 0 sobreposição, 0 rolagem lateral | — | Viewport de navegador, não aparelho |

## Fase 4 — atividade de voz e barge-in (ajuste 019, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Nível em dBFS e pico por bloco | Sim | Sim | Verificada | tom 0,2 → -17 dB e pico 0,2 | — | — |
| Detector de atividade de voz com piso adaptativo | Sim | Sim | Verificada | 22 verificações; ruído de 2 s não dispara | — | Sem microfone real aqui |
| Cauda de 500 ms e confirmação de 120 ms | Sim | Sim | Verificada | pausa 400 ms mantém, 500 ms encerra | — | — |
| Barge-in interrompe a fala | Sim | Sim | Parcial | regra testada (300 ms); ligado no `falar()` | Fase 4 | Não exercitado com voz/TTS reais |
| Microfone e contexto fechados ao terminar | Sim | Sim | Parcial | `desarmarBargeIn()` no `finally` | — | Não medido em execução longa |
| Interruptor persistente | Sim | Sim | Verificada | `voz_interromper` 0/1 após recarregar | — | — |
| Medição de microfone (3 s) | Sim | Sim | Parcial | caminho de erro na tela; sucesso sem microfone | — | Requer aparelho |
| KWS sherpa-onnx e serviço de primeiro plano | Não | Não | Bloqueada | — | Fase 4 / 4B | Sem SDK Android e sem Poco X7 |

## Cabeçalho do cartão do núcleo (ajuste 020, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Selo e título em linhas separadas no cartão do núcleo | Sim | Sim | Verificada | 360 px: selo y=733, título y=748, sem interseção | — | Viewport de navegador |
| Sem corte e sem rolagem lateral em 320 e 360 | Sim | Sim | Verificada | 0 cortes, docSW = largura | — | — |

## "Por que parou?" no segundo plano (ajuste 021, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Explicar a parada em ordem de causa | Sim | Sim | Verificada | 14 verificações com diagnóstico sintético | Fase 4B | Caminho nativo não executado aqui |
| Escuta ativa é dita ativa, com detector | Sim | Sim | Verificada | teste do módulo | — | — |
| Sem causa conhecida, não inventa | Sim | Sim | Verificada | `sem-causa` | — | — |
| Botão na seção Segundo plano | Sim | Sim | Parcial | botão 320×40 em 360 px; aviso honesto no navegador | Fase 4B | Requer APK para a resposta real |

## Pausa na notificação e perfis de energia (ajuste 022, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Pausar/Retomar pela notificação | Sim | Não | Verificada no código | ações e persistência em `JarvisPrefs.pausadoManual` | Fase 4B | Não compilado nem medido aqui |
| Pausa vence vigia, rearme e recentes | Sim | Não | Verificada no código | `onTaskRemoved`, `agendarRearmeSeTelaNaoResponder`, `monitorMidia` | Fase 4B | idem |
| Perfil Sempre ouvindo | Sim | Não | Verificada no código | `bloqueioPerfil` vazio | Fase 4B | idem |
| Perfil Somente carregando | Sim | Não | Verificada no código | `carregando()` lê a bateria do sistema | Fase 4B | idem |
| Perfil Horários definidos | Sim | Não | Verificada no código | janela com travessia da meia-noite | Fase 4B | idem |
| Perfil Desligado | Sim | Não | Verificada no código | não abre o microfone | Fase 4B | idem |
| Tela: seletor, horários e estado | Sim | Sim | Verificada | 15 verificações + tela 360 px | Fase 4B | Resposta real exige APK |

## Redução por bateria e economia de energia (ajuste 023, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Reduzir a escuta com bateria ≤ 15% sem carregador | Sim | Não | Verificada no código | `bloqueioBateria` em `iniciarMotor` | Fase 4B | Não compilado nem medido aqui |
| Reduzir com economia de energia ligada | Sim | Não | Verificada no código | `PowerManager.isPowerSaveMode()` | Fase 4B | idem |
| Retomar sozinho ao carregar ou sair da economia | Sim | Não | Verificada no código | laço de 1 s do `monitorMidia` | Fase 4B | idem |
| Explicar a redução na tela e no "Por que parou?" | Sim | Sim | Verificada | 17 + 17 verificações | Fase 4B | Texto real exige APK |

## Limite de bateria escolhível e WorkManager (ajustes 024 e 025, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Limite de redução 10/15/20% | Sim | Parcial | Verificada | 20 verificações; seletor em 320 px | Fase 4B | Não compilado nem medido |
| Manutenção periódica (6 h) | Sim | Não | Verificada no código | `JarvisManutencaoWorker`, 9 verificações | Fase 4B | Depende do gradle do CI |
| Restrição de bateria e trabalho único | Sim | Não | Verificada no código | `setRequiresBatteryNotLow`, `KEEP` | Fase 4B | idem |
| Rodar manutenção agora | Sim | Não | Parcial | botão responde no navegador com aviso honesto | Fase 4B | Caminho nativo não executado |
| Rotinas em segundo plano | Não | Não | **Fora de escopo** | Worker não executa JavaScript | Fase 4B | Continua na interface |

## Fone desconectado e microfone disputado (ajuste 026, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Pausar quando a rota de áudio muda | Sim | Não | Verificada no código | `ACTION_AUDIO_BECOMING_NOISY` + 5 s | Fase 4B | Aviso varia por fabricante |
| Retomar sozinho depois do fone | Sim | Não | Verificada no código | `pausaFoneAte` no laço de 1 s | Fase 4B | Não medido no aparelho |
| Pausar quando outro app grava | Sim | Não | Verificada no código | `getActiveRecordingConfigurations()` | Fase 4B | Lista pode vir vazia em alguns OEMs |
| Explicar as duas causas | Sim | Sim | Verificada | 9 + 17 verificações | Fase 4B | Texto real exige APK |

## Microfone em tempo real na tela (ajuste 027, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Linha viva do microfone | Sim | Fallback | Verificada | 12 verificações; linha 320 px | Fase 4B | Caminho nativo não executado |
| Consulta a cada 2,5 s só com a aba aberta | Sim | Sim | Verificada | `clearInterval` ao sair e com painel oculto | — | — |
| Destaque quando outro app grava | Sim | Sim | Verificada | nível `erro` e `.dica.erro` | Fase 4B | idem |

## Verificação de privacidade da ativação (ajuste 028, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Auditoria estática do caminho do áudio | Sim | Sim | Verificada | 11 verificações | Fase 4B | Não prova execução |
| Contador de tráfego do app | Sim | Não | Verificada no código | `TrafficStats.getUidTxBytes` | Fase 4B | Total do app, não o conteúdo |
| Frase honesta sobre bytes | Sim | Sim | Verificada | zero, KB/MB e desconhecido | Fase 4B | — |
| Roteiro de 4 provas | — | — | Pronto | `docs/FASE-4B-PRIVACIDADE.md` | Fase 4B | Provas 2–4 dependem do aparelho |

## Pré-checagem Android e critérios de aceite (ajuste 029, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Pré-checagem de classes e dependências | Sim | Sim | Verificada | 23 classes, 6 workflows; teste negativo | Fase 4B | Não compila |
| Passo de pré-checagem no CI | Sim | — | Implementado | presente nos 4 fluxos de APK | Fase 4B | Só roda no CI |
| Critérios de aceite da fase | — | — | Pronto | `docs/FASE-4B-ACEITE.md` | Fase 4B | Depende da medição |
## Revisão de compilação do Java (ajuste 030, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Detecção de microfone ocupado | Sim | — | Corrigida | sessão do `AudioRecord` + contagem; 12 verificações | Fase 4B | Nome do app não é visível |
| Pausa manual vence o aviso do fone | Sim | — | Corrigida | `test_microfone` | Fase 4B | Não medido |
| Mensagem do teste só com captura | Sim | — | Corrigida | `onState` + `test_microfone` | Fase 4B | Não medido |
| Retentativa do Worker limitada | Sim | — | Corrigida | 2 tentativas por ciclo | Fase 4B | Não medido |
## Pré-checagem de APIs e permissões (ajuste 031, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| API de sistema usada sem revisão | Sim | Sim | Verificada | 8 APIs; teste negativo com `getClientUid` | Fase 4B | Lista curada, não exaustiva |
| Permissão usada e não declarada | Sim | Sim | Verificada | teste negativo com permissão falsa | Fase 4B | — |
| Permissão de sistema no manifesto | Sim | Sim | Verificada | teste negativo com `WRITE_SECURE_SETTINGS` | Fase 4B | — |
## Pré-checagem na suíte local (ajuste 032, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Pré-checagem como primeiro passo da suíte | Sim | Sim | Verificada | `test:all` + teste negativo com permissão de sistema | Fase 4B | Análise estática |
| Passo protegido contra remoção | — | — | Verificado | `tests/test_empacotamento.py` | Fase 4B | Protege a presença, não o conteúdo |
## Comando único de verificação (ajuste 033, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| `npm run verificar` | Sim | Sim | Verificado | 3 de 3 etapas; teste negativo mostra 2 de 3 | Fase 4B | Não compila nem mede |
| Resumo com estado, tempo e contagem | — | — | Verificado | saída real do comando | Fase 4B | Conta apenas linhas `OK:` |
## Revisão do Java restante (ajuste 034, 2026-11-13)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Player de música sem vazamento | Sim | — | Corrigido | `release()` no `catch`; suíte | Revisão | Não medido |
| Player encerra sem primeiro plano | Sim | — | Corrigido | `iniciarPrimeiroPlano()` booleano | Revisão | Não compilado |
| Acessibilidade fora da thread da interface | Sim | — | Corrigido | fila própria; `handleOnDestroy` | Revisão | ANR real não medido |
| Voz não libera motor durante síntese | Sim | — | Corrigido | espera da fila + cadeado | Revisão | Não medido |
| Download fecha stream | Sim | — | Corrigido | `finally` | Revisão | Não medido |

## Plugins restantes e primeiro plano (ajuste 035, 2026-11-14)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| NFC cancela promessa pendente | Sim | — | Corrigido | `cancelarLeitura()` no `handleOnDestroy` | Revisão | Não compilado |
| Listener de notificações sem acúmulo | Sim | — | Corrigido | `onNotificationRemoved` + limpeza no destroy | Revisão | Não medido |
| Watchdog respeita pausa manual | Sim | — | Corrigido | consulta `pausadoManual` antes de reativar | Revisão | Não medido |
| Cofre e contatos fora da thread principal | Sim | — | Corrigido | executor `fundo` + `emFundo` | Revisão | ANR real não medido |
| Streams do cofre fechados em `finally` | Sim | — | Corrigido | `cofreLer`/`cofreEscrever` | Revisão | Não medido |
| `startForeground` com falha precisa sair | — | — | Verificado | pré-checagem + probe negativo | Revisão | Heurística estática |

## Fase 5 — ensaio do patch (2026-11-14)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Patch aplica no HEAD limpo | — | — | Verificado | `ci/rehearsal_gate_a.py` exit 0, 94 arquivos | Fase 5 | Não compila |
| Arquivo novo não fica fora do patch | — | — | Verificado | reprovou antes de `git add -N`, passou depois | Fase 5 | Escopo declarado |
| Pré-checagem roda no código vindo do patch | — | — | Verificado | mesma execução do ensaio | Fase 5 | Só análise estática |

## Ensaio do patch no CI (ajuste 037, 2026-11-14)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Ensaio antes de compilar no CI | — | — | Verificado | passo nos 4 workflows; teste do modo `--aplicar` | Fase 5 | Não compila |
| Patch inválido para a compilação | — | — | Verificado | teste negativo: exit 1 no `git apply` | Fase 5 | Exige patch contra o commit atual |
| Fluxo sem patch continua | — | — | Verificado | mensagem e `exit 0` no passo | Fase 5 | — |

## Fase 5 — interface nativa (ajuste 038, 2026-11-14)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Interface sem WebView | Sim | — | Verificado | `ci/preflight_interface.py` + teste negativo | Fase 5 | Só o app Flutter; web legada em migração |
| Navegação com as 12 seções | Sim | — | Verificado | pré-checagem confere a gaveta | Fase 5 | Seções abrem páginas de módulo |
| Animação reduzida | Sim | — | Implementado | `MediaQuery.disableAnimations` | Seção 3D | Não compilado |
| Núcleo com `RepaintBoundary` | Sim | — | Implementado | `command_center.dart` | Seção 3D | FPS não medido |

| Núcleo de streaming com janela | Sim | — | Verificado | `dart run tool/stream_buffer_test.dart` | Fase 5 | Ainda não ligado à tela |

| Conversa em streaming com parar | Sim | — | Implementado | `streamComplete` + `StreamBuffer` na tela | Fase 5 | Não compilado |
| Parser SSE tolerante a corte | Sim | — | Verificado | `dart run tool/sse_test.dart` | Fase 5 | Sem teste contra API real |
| Estados vazio/processando/erro na conversa | Sim | — | Implementado | tela de conversa | Seção 3D | Só a conversa; outras telas pendentes |

| Histórico de conversas persistente | Sim | — | Verificado | testes de widget + `ConversaStore` | Fase 5 | Sem teste em aparelho |
| Rascunho restaurado | Sim | — | Verificado | teste do store | Fase 5 | — |
| Voz em tela cheia | Sim | — | Implementado | `VozTelaCheiaPage` + teste | Fase 5 | Estado real do KWS no aparelho não medido |
| Regenerar e copiar resposta | Sim | — | Implementado | tela de conversa | Seção 3D | — |
| `flutter analyze` e `flutter test` | Sim | — | Verificado | 0 problemas; 36 testes | Fase 5 | Rodado com Flutter 3.50 |
