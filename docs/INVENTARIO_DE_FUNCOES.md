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

## Aparelho conectado (Flutter, versão 1.60.0)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Relógio próprio por contato 67/68 | Sim | Não | Verificada (cálculo e tela) | `core/circuito.dart` (`relogioDoContato`, `temposContato`), `tool/circuito_test.dart` grupos 53–57, `test/circuito_page_test.dart` | — | Passos de 1 s; sem teste em aparelho |
| Aviso "JARVIS ATIVO" no segundo plano | Sim | Não | Não verificado | `MainActivity.kt` (`acao=ativo`), `home_screen.dart` (`jarvis-ativo`), `AparelhoService.ativarEmSegundoPlano` | microfone | Não exercitado com o app fechado |
| Leitura de notificações | Sim | Não | Não verificado | `JarvisNotificacaoListener.kt`, `aparelho_page.dart` | acesso a notificações | Sem teste em aparelho; lista só em memória |
| Mensagem por qualquer app | Sim | Não | Parcial | `core/aparelho.dart` (`appsMensagem`, `interpretarMensagem`), `JarvisAparelho.kt` (`enviarMensagem`), `tool/aparelho_test.dart` | permissão do app/SMS | Apps de terceiros não enviam sozinhos; só SMS sai direto |
| Controle do Spotify | Sim | Não | Parcial | `JarvisAparelho.kt` (`spotify`, `tocarFaixa`, `verificarFaixa`, `MediaController`), `interpretarSpotify`, `uriSpotify`, `faixaConfere` | sessão ativa + acesso a notificações | Música pedida toca por `MEDIA_PLAY_FROM_SEARCH`; faixa exata só com link `spotify:track:…`; confirmação em até 8 s |
| Contatos e ligações | Sim | Não | Não verificado | `JarvisAparelho.kt` (`buscarContatos`, `ligar`) | READ_CONTACTS, CALL_PHONE | Sem teste em aparelho |
| Status e ajustes básicos | Sim | Não | Parcial | `JarvisAparelho.kt` (`status`, `abrirAjustes`), `EstadoAparelho.descrever` | — | Só leitura de status; abrir ajustes depende do aparelho |
| Ficha a partir de contato | Sim | Não | Verificada (modelo) | `fichaDeContato`, `perguntasBasicasPessoa`, `aparelho_page.dart`, `PessoasStore` | consentimento | Ficha nasce vazia; sem teste em aparelho |

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
| Abrir app, volume, lanterna e alarme | Sim | Parcial | Parcial | `flutter_app/lib/core/comandos_android.dart`, `JarvisComandos.kt`, `tests/test_comandos_android.py` | nenhuma permissão nova | Só quatro ações de baixo risco; não fecha apps, não alterna Wi-Fi/dados e não envia SMS/ligações; sem teste em aparelho |
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
| CADeSIMU importar/exportar | Sim (leitura) | Não | Parcial | `flutter_app/lib/services/cadesimu_cad.dart`, `cadesimu_page.dart`, `tests/test_cadesimu_flutter.py`, `tests/test_cadesimu_sonda.py` | seletor do sistema | Leitura somente; não edita, não simula e não gera netlist; exportação 10B bloqueada até tabela de pinos e teste no CADeSIMU oficial |
| Simulador de circuitos DC com comando por contator | Sim | Não | Verificado no código | `flutter_app/lib/core/circuito.dart`, `circuito_page.dart`, `tool/circuito_test.dart` (20 grupos), `test/circuito_page_test.dart` (6 testes) | — | Só DC linear, sem motor nem CA; CADeSIMU em si não foi embutido |
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

| Atalhos do ícone (falar, conversa, histórico) | Sim | — | Implementado | `shortcuts.xml` + `prepare_android_sistema.py` + teste | Fase 5 | Não instalado em aparelho |
| Widget da tela inicial | Sim | — | Implementado | `JarvisWidgetProvider.kt` + layout | Fase 5 | Estado vem do app; sem teste no launcher |
| Receber texto compartilhado | Sim | — | Implementado | filtro `ACTION_SEND` + teste Dart | Fase 5 | — |
| Compartilhar conversa | Sim | — | Implementado | `SistemaAndroid.compartilhar` + folha do sistema | Seção 3D | Sem teste no aparelho |

| Conferência do APK no CI | Sim | — | Verificado (simulação) | conteúdo do pacote + manifesto + dex | Fase 5 | Compilação real só no CI |

| Cofre local de notas | Sim | — | Verificado | `core/memoria.dart` + `memoria_store.dart` | Fase 6 | Sem cofre real grande |
| Busca lexical com motivo | Sim | — | Verificado | 11 blocos em `tool/memoria_test.dart` | Fase 6 | Não é busca neural |
| Importação Markdown com conflito | Sim | — | Verificado | repetida/conflito em teste | Fase 6 | Colagem, não pasta SAF |
| Citação na conversa | Sim | — | Verificado no núcleo | `montarMensagens` + `fontes` | Fase 6 | Sem chamada real à IA |
| Cofre via SAF e sync Obsidian | Não | Não | Não implementado | — | Fase 7B | Exige aparelho e seletor de pasta |

| Cofre via SAF (pasta do Obsidian) | Sim | Não | Verificado no código | permissão durável + teste estático | Fase 6 | Não exercitado em aparelho |
| Importar pasta conectada | Sim | — | Verificado | 6 testes com canal simulado | Fase 6 | Sem pasta real |
| Sincronização Obsidian | Não | Não | Não implementado | — | Fase 7B | Ação explícita hoje |

| Sincronização com Obsidian (dois sentidos) | Sim | — | Verificado no núcleo | 13 casos + 8 de serviço | Fase 6 | Sem aparelho real |
| Conflito de sincronização | Preservado | — | Verificado | nada é sobrescrito nem apagado | Fase 6 | Resolução é manual |
| Escrita na pasta via SAF | Sim | Não | Verificado no código | teste estático + canal simulado | Fase 6 | Não exercitada em aparelho |

| Sincronização automática (abrir/voltar) | Sim | — | Verificado | 2 testes com ciclo de vida | Fase 6 | Sem aparelho |

| Resolver conflito escolhendo versão | Sim | — | Verificado | 4 testes, backup preservado | Fase 6 | Sem inspeção visual |

| Revisar e limpar backups de conflito | Sim | — | Verificado | 5 testes, exclusão confirmada | Fase 6 | Sem inspeção visual |

| Fichas de pessoas (local, criptografada) | Sim | — | Verificado | 5 testes + privacidade estática | Fase 7 | Sem aparelho |
| Consentimento obrigatório (LGPD) | Sim | — | Verificado | teste recusa sem marcar | Fase 7 | — |
| Ambiguidade de nomes | Sim | — | Verificado | dois "João" não são escolhidos | Fase 7 | — |
| Contexto de pessoas para a IA | Sim | Não | Verificado no núcleo | bloco seguro, 9 grupos de teste | Fase 7 | Sem chave real |
| Foto e reconhecimento facial | Não | Não | Não implementado | tela declara ausência | Fase 7 | Fora desta entrega |

| Transparência das fichas na conversa | Sim | — | Verificado | guarda o bloco literal e mostra a ficha usada; 3 testes de widget | Fase 7 | Sem inspeção visual |

| Personalidade em três níveis | Sim | — | Verificado | 9 grupos puros + 3 de widget | Fase 7 | Sem chave real |
| Humor suspenso em assunto sensível | Sim | — | Verificado no núcleo | saúde, luto, violência, segurança e dinheiro | Fase 7 | — |
| Nível de humor no prompt da conversa | Sim | Não | Verificado no código | `estiloDoTurno` antes do envio | Fase 7 | Modelo real não exercitado |

| Visão de imagem (galeria/câmera) | Sim | Não | Verificado no código | 5 testes de widget + contrato puro | Fase 8 | Plugin não exercitado |
| Consentimento antes de enviar imagem | Sim | — | Verificado | botão exige imagem + autorização | Fase 8 | — |
| Análise por provedor com visão | Sim | Não | Verificado no contrato | 4 provedores; resposta multimodal | Fase 8 | Sem chave real |
| Reconhecimento facial | Não | Não | Não implementado | prompt proíbe identificar pessoas | Fase 8 | Modelo pode desobedecer |
| OCR local / modelo no aparelho | Não | Não | Não implementado | tela declara ausência | Fase 8 | Fora desta entrega |

| Arquivos de texto na pasta privada | Sim | Não | Verificado | 8 testes de widget + pasta real | Fase 9 | Plugin não exercitado |
| Caminho confinado e nome seguro | Sim | — | Verificado no núcleo | `../`, barra e absoluto externo recusados | Fase 9 | — |
| Limite de 200 arquivos / 512 kB | Sim | — | Verificado no núcleo | medido em bytes UTF-8 | Fase 9 | — |
| Sandbox de execução de código | Não | Não | Não implementado | tela declara ausência | Fase 9 | Dart não isola SO |
| Pasta externa via SAF | Não | Não | Não implementado | — | Fase 9 | Exige seletor e permissão |

| Promessa de execução isolada | Removida | — | Verificada | catálogo, gaveta e tela declaram ausência; 4 testes | Fase 9 | Sem sandbox |

## Simulador de circuitos DC — Fase 10 (ajustes 061 e 062, 2026-11-18)

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Simulação DC por análise nodal modificada | Sim | Não | Verificado no código | `lib/core/circuito.dart`; 42 grupos em `tool/circuito_test.dart` | — | Só DC linear, sem CA ou transitórios |
| Montagem visual em grade | Sim | Não | Verificado no código | `circuito_page.dart`; 11 testes de tela | — | Sem arrastar componente nem zoom |
| Botoeira de comando NA e NF | Sim | Não | Verificado no código | `TipoElemento.botoeira`, `ativaEm`; teste da partida direta | — | Sem botoeira com retenção mecânica nem contato duplo |
| Bobina de contator com puxar e soltar | Sim | Não | Verificado no código | teste "24 V e 100 mA" e teste de bobina com 55% da tensão | — | Puxa em 70% e solta em 50%; sem tempo de operação nem bobina CA |
| Contato de selo comandado pela bobina | Sim | Não | Verificado no código | teste "contato de selo mantém a bobina" | — | NA apenas; sem contato NF de selo |
| Contato NF auxiliar (21-22) e intertravamento | Sim | Não | Verificado no código | `TipoElemento.contatoNf`; teste "contato NF de K1 impede K2" e teste de tela da reversão | — | Elétrico, um contato por bobina; sem trava mecânica |
| Reversão com dois contatores (exemplo) | Sim | Não | Verificado no código | grade 8×5, K1 e K2 com selo, 100 mA cada | — | Só comando; sem reversão de potência |
| Contato principal de potência (1-2) | Sim | Não | Verificado no código | teste "motor parado: contato de potência aberto" | — | Um contato por bobina |
| Motor DC com tensão e potência nominais | Sim | Não | Verificado no código | 24 V / 24 W → 1 A e 24 W; fonte com 1,1 A | — | Carga resistiva: sem corrente de partida, inércia ou rotação |
| Partida direta de motor (exemplo) | Sim | Não | Verificado no código | 5 grupos de cálculo no teste puro + teste de tela | — | Sem motor de indução nem partida real |
| Relé térmico com ajuste de corrente | Sim | Não | Verificado no código | testes "1,5 A deixa rodar" e "0,5 A desarma" | — | Desarme instantâneo, sem curva tempo-corrente |
| Contato 95/96 do relé no comando | Sim | Não | Verificado no código | teste do desarme derrubando a bobina | — | Um contato por relé |
| Desarme com memória e rearme manual | Sim | Não | Verificado no código | testes "rearmar não religa" e teste de tela com `rearmar-rele` | — | Rearme só pelo app, sem rearme automático |
| Temporizador com atraso em segundos | Sim | Não | Verificado no código | grupos "não acende antes do atraso" e "fecha aos 3 s" | — | Tempo em passos de 1 s, sem contagem contínua |
| Contato 67/68 do temporizador | Sim | Não | Verificado no código | teste do 67/68 acendendo a lâmpada | — | Um contato por temporizador |
| Contato 67/68 NF do temporizador | Sim | Não | Verificado no código | teste do NF derrubando K1 aos 3 s | — | Um contato NF por temporizador |
| Desligamento em sequência (exemplo) | Sim | Não | Verificado no código | motor para sozinho aos 3 s e nova partida religa | — | Só DC, com o tempo em passos de 1 s |
| Retardo na queda do temporizador | Sim | Não | Verificado no código | grupos 34–38: motor segue 24 W aos 2 s de queda e para aos 3 s | — | Um ajuste por temporizador, em segundos inteiros |
| Desligamento temporizado (exemplo) | Sim | Não | Verificado no código | partida, parada, 2 s com o motor ligado e 3 s desligando | — | Só DC; queda em passos de 1 s |
| Dois contatos no mesmo temporizador (NA e NF) | Sim | Não | Verificado no código | exemplo "Dois contatos do temporizador": L2 acesa antes dos 3 s, L1 e L2 trocam aos 3 s | — | Os contatos dividem o mesmo atraso e retardo na queda |
| Atraso próprio de cada contato 67/68 | Sim | Não | Verificado no código | exemplo "Contatos com tempos diferentes": L1 aos 1 s e L2 só aos 5 s, no mesmo KT1 | — | Compartilham o relógio e o retardo na queda do temporizador |
| Atraso 0 s usa o ajuste base do temporizador | Sim | Não | Verificado no código | teste `atrasoDoContato` igual ao atraso do KT1 e exemplos antigos sem mudança | — | Não há atraso negativo nem por contato na queda |
| Retardo na queda próprio de cada contato | Sim | Não | Verificado no código | exemplo "Quedas diferentes no temporizador": L1 apaga em 1 s e L2 volta aos 4 s | — | O relógio da queda continua sendo do temporizador |
| Queda 0 s usa o retardo base do temporizador | Sim | Não | Verificado no código | teste `atrasoQuedaDoContato` igual à queda do KT1 | — | Não há queda negativa nem independente do relógio |
| Campo da queda própria na tela | Sim | Não | Verificado no código | `campo-queda-contato`, `aplicar-queda-contato` e o texto `queda-contato` | — | Um segundo por passo, sem animação |
| Campo do atraso próprio na tela | Sim | Não | Verificado no código | `campo-atraso-contato`, `aplicar-atraso-contato` e o texto `atraso-contato` | — | Um segundo por passo, sem animação |
| Escolha individual do tipo do contato | Sim | Não | Verificado no código | chips `contato-tipo-na`/`contato-tipo-nf`; trocar um não mexe no outro e teste dos rótulos | — | Só NA ou NF, sem contato com atraso próprio |
| Rótulos numerados para contatos repetidos | Sim | Não | Verificado no código | teste dos dois contatos NA no mesmo temporizador | — | Numeração só quando o tipo se repete |
| Relógio da queda com Avançar 1 s | Sim | Não | Verificado no código | teste de tela com o chip `relogio-queda` em 2 s e 3 s de 3 s | — | Um segundo por toque, sem animação |
| Campo do retardo na queda | Sim | Não | Verificado no código | `campo-atraso-queda` e `aplicar-atraso-queda` no editor do temporizador | — | Sem retardo por contato |
| Relógio do temporizador com Avançar 1 s | Sim | Não | Verificado no código | teste de tela indo de 0 a 3 s com `avancar-tempo` | — | Um segundo por toque, sem animação |
| Partida direta com selo (exemplo) | Sim | Não | Verificado no código | `exemplosCircuito` + teste de tela com apertar/soltar/parar | — | Comando em 24 V DC; sem motor nem contato de potência |
| Comando que não estabiliza é avisado | Sim | Não | Verificado no código | limite de 12 iterações em `_comandar` | — | Avalia o estado final, sem gráfico de tempo |
| Inserir, remover e selecionar componente | Sim | Não | Verificado no código | teste "ferramenta apagar remove o componente" | — | Um componente por trecho |
| Diagnósticos: curto, aberto, ilha, sobretensão, potência | Sim | Não | Verificado no código | avisos com teste dedicado no motor | — | Curto classificado acima de 25 A |
| Fusível que rompe e abre o circuito | Sim | Não | Verificado no código | teste do exemplo "Curto protegido por fusível" | — | Rompimento imediato, sem curva tempo-corrente |
| Exemplos prontos de circuito | Sim | Não | Verificado no código | 5 circuitos, todos calculam no teste | — | Fixos, sem geração por IA ainda |
| Simulador do próprio CADeSIMU | Não | Não | Fora de escopo | CADeSIMU é freeware de Windows, sem versão Android, sem API e sem motor separado; WebView é proibido | — | Não há forma legítima de embutir |
| `.cad` → netlist para simular | Não | Não | Não implementado | relatório 059 | — | Falta a tabela de pinos e a prova no CADeSIMU oficial |

## Engenharia de circuitos — Fase 10 (ajuste 074, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Sensor NA/NF no simulador | Sim | Não | Verificada (teste puro) | 15 verificações de engenharia | Nenhuma | Modelo DC; acionado por botão |
| Verificar ligações e continuidade | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Análise de ligação, não simulação |
| Lista de materiais | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Sem preço nem cotação |
| Exportar/importar `.circ` | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Formato próprio; `.cad` só leitura |
| Dimensionamento de carga e motor | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Tabela resumida; não é projeto assinado |
| CLP didático (ladder) | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Lógica pura, sem I/O físico |

## Central do aparelho — Fase 11 (ajuste 074, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Memória, armazenamento, bateria, rede e uptime | Sim | Não | Parcial | modelo + widget test; falta Poco X7 | Nenhuma | Valores do Android, sem histórico |
| Lista de apps com tela inicial | Sim | Não | Parcial | idem | Nenhuma | Até 120 apps |
| Abrir app pelo pacote | Sim | Não | Parcial | idem | Nenhuma | Só apps com intent de lançamento |
| Tarefas e automações agendadas | Sim | Não | Parcial | modelo + 3 testes de widget; falta Poco X7 | — | Ações não-aviso rodam com o app aberto |
| Pareamento Android ↔ Windows | Não | Não | Não implementada | — | — | Depende de contraparte Windows |

## Tarefas e automações — Fase 11 (ajuste 075, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Tarefas com prazo, prioridade e conclusão | Sim | Não | Parcial | `core/tarefas.dart`, `TarefasStore`, 17 verificações + widget | Nenhuma | Sem teste em aparelho; 100 tarefas |
| Alarme de tarefa e aviso de horário | Sim | Não | Não verificado | `JarvisAgenda.kt` (`setAlarmClock`), `AgendaService` | notificação (Android 13+) | Não testado com app fechado nem após reiniciar |
| Automação por bateria baixa | Sim | Não | Parcial | `automacaoVencida`, tela | leitura de bateria | Avaliada só com o app aberto; intervalo de 6 h |
| Automação de abrir app / criar tarefa | Sim | Não | Parcial | fila + `executarItem` | canal do aparelho | Também só com o app aberto |
| Mensagem por automação | Sim | Não | Parcial | fila `aguardandoConfirmacao`, Confirmar/Recusar | app de mensagem instalado | Abre a conversa; envio é do usuário |
| Fila offline com novas tentativas | Sim | Não | Verificada (teste puro) | `marcarItemFalha`, 3 tentativas | — | Sem execução em segundo plano |
| Histórico de execuções | Sim | Não | Verificada (teste puro) | `EventoAutomacao`, últimas 200 | — | Só neste aparelho |

## Visão — erro 404 do Gemini (ajuste 076, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Análise de imagem resistente a modelo aposentado | Sim | Não | Parcial | `modelos` em `core/visao.dart`, laço de `VisaoService`, teste puro + 9 de widget | chave de provedor com visão | Sem chave real do Google e sem Poco X7 |
| Troca automática de provedor de visão na falha | Sim | Não | Parcial | `VisaoService.analisar` percorre todos os configurados | 2ª chave cadastrada | Só testado com cliente falso/estático |
| Mensagem de 404 explicando o modelo | Sim | Não | Verificada (teste puro) | `mensagemErroVisao` | — | — |

## Segundo plano de verdade — Fase 12 (ajuste 077, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Comando por voz com o app fechado | Sim | Não | Parcial | `KwsForegroundService` + `JarvisEscutaFundo`, 6 grupos puros + 5 de widget | microfone + escuta ligada | Não testado em aparelho; depende do pacote offline pt-BR |
| Abrir app a partir do segundo plano | Sim | Não | Parcial | `JarvisFundo.abrirApp`, contrato estático | “Exibir sobre outros apps” (`SYSTEM_ALERT_WINDOW`) | Fabricante pode restringir a exceção |
| Lanterna, volume e alarme por voz no fundo | Sim | Não | Parcial | `JarvisFundo.executar` | idem para alarme | Volume é conferido; lanterna não relê o estado |
| Aviso “JARVIS ativo” na tela | Sim | Não | Parcial | canal `jarvis_ativo_aviso`, `IMPORTANCE_HIGH` | notificações (Android 13+) | Não Perturbe pode reter o aviso na gaveta |
| Modo sem tela (não abrir o app) | Sim | Não | Verificada (teste puro + tela) | `modoSemTela`, switch na tela | — | Escolha por aparelho |
| Teste de comando por escrito | Sim | Não | Parcial | `executarTexto` no canal + teste de widget | — | Executa dentro do app aberto, não pelo serviço |

## Tela de bloqueio — Fase 13 (ajuste 078, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Tela de bloqueio com PIN próprio | Sim | Não | Parcial | `core/seguranca.dart`, `TelaBloqueio`, 7 grupos puros + 8 testes de widget | — | Sem teste de toque em aparelho |
| PIN derivado com sal (PBKDF2-HMAC-SHA256) | Sim | Não | Verificada (teste puro) | `derivarPin`, `compararDigest`, `CofreSeguro` | cofre seguro do aparelho | Custo medido só em teste, não em celular de entrada |
| Limite de tentativas e espera de 30 s | Sim | Não | Verificada (teste puro) | `avaliarTentativa` | — | Sem persistência à prova de reinício do processo |
| Bloqueio ao abrir e ao voltar | Sim | Não | Parcial | `BloqueioGate`, `deveBloquearAoVoltar` | — | Ciclo de vida não testado em aparelho |
| Biometria opcional | Sim | Não | Não verificado | `JarvisBiometria.kt`, `BiometriaService` | biometria cadastrada | Prompt e HyperOS não testados |
| Recuperação com credencial do aparelho | Sim | Não | Não verificado | `KeyguardManager`, `redefinirComCredencialDoAparelho` | aparelho com PIN/padrão/senha | Retorno da tela não testado |
| Configurações da tela de bloqueio | Sim | Não | Parcial | `SegurancaPage`, testes de widget do gate | — | — |

## Status do celular e localização — Fase 14 (ajuste 079, 2026-11-19)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Bateria, memória, rede e uptime na Central do aparelho | Sim | Não | Parcial | `core/dispositivo.dart`, `dispositivo_page.dart`, 7 testes de widget | Nenhuma | Sem teste no Poco X7; sem histórico |
| Notificações na Central do aparelho | Sim | Não | Parcial | `JarvisNotificacaoListener.kt`, seção `NOTIFICAÇÕES` | Acesso a notificações | Lista só em memória (80); HyperOS não verificado |
| Localização do aparelho (coordenadas e precisão) | Sim | Não | Não verificado | `JarvisLocalizacao.kt`, `core/localizacao.dart`, 4 testes de widget + 12 grupos puros | `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` | GPS real e permissão não testados em aparelho |
| Endereço aproximado | Sim | Não | Não verificado | `Geocoder` no Kotlin, marcação “aproximado” na tela | rede para o Geocoder | Pode falhar sem internet; nunca é exato |
| Comando falado “onde estou” | Sim | Não | Parcial | registro + `InterpretadorComandos`, teste puro | permissão já concedida | Só com o app aberto |

## Microfone do comando e segunda escuta — Fase 14 (ajuste 080, 2026-11-20)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Um microfone por vez entre detector e comando | Sim | Não | Parcial | `KwsForegroundService.marcarComandoAtivo`/`pausarMotor`, `MainActivity`, `home_screen` não religa o KWS, contrato estático | microfone | Corrida real só se confirma no aparelho |
| Segunda escuta automática em “não entendi” | Sim | Não | Parcial | `tentativaValeRepetir` + `tentativasComando` no Kotlin, contrato estático | microfone | Uma repetição por comando; não testado em aparelho |
| Folga de silêncio para comando curto | Sim | Não | Não verificado | `EXTRA_SPEECH_INPUT_*_SILENCE_LENGTH_MILLIS`, `MINIMUM_LENGTH` | microfone | O reconhecedor do aparelho pode ignorar as medidas |
| Pacote offline pt-BR ausente explicado | Sim | Não | Parcial | mensagens de `ERROR_LANGUAGE_NOT_SUPPORTED`/`ERROR_LANGUAGE_UNAVAILABLE` | pacote de voz offline do Android | Sem instalar o pacote, não há transcrição offline |
| Comando em segundo plano sem “Exibir sobre outros apps” | Sim | Não | Parcial | `!JarvisFundo.podeAbrirApps` no serviço, contrato estático | microfone + escuta ligada | Abrir apps continua exigindo a autorização |
| Botão “Autorizar abrir apps” no aviso “JARVIS ativo” | Sim | Não | Não verificado | `addAction` com `ACTION_MANAGE_OVERLAY_PERMISSION` | notificações | HyperOS pode recolher o aviso no modo Não Perturbe |

## Histórico de execuções — Fase 14 (ajuste 081, 2026-11-20)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Registro de comando executado com horário e resultado | Sim | Não | Parcial | `JarvisFundo.anotar`/`historico`, `core/historico_voz.dart`, testes puros | — | Só Android; sem teste no Poco X7 |
| Registro do comando executado em segundo plano | Sim | Não | Parcial | `KwsForegroundService` chama `JarvisFundo.registrar` com o texto ouvido; contrato estático | microfone + escuta ligada | Depende do serviço continuar vivo |
| Histórico alimentado pelo comando falado com a tela aberta | Sim | Não | Parcial | `VoiceConversationPage._concluirComando` + `registrarExecucao`; teste de widget da tela | microfone já usado | Origem “voz” só quando veio do KWS |
| Lista com dia, hora, pedido, ação e mensagem | Sim | Não | Parcial | `historico_voz_page.dart`, 5 testes de widget | — | Sem teste em aparelho |
| Limite de 100 registros e limpeza com confirmação | Sim | Não | Verificada (teste puro + widget) | `RegistroExecucao.limite`, `registrosDeMapa`, botão “Limpar histórico deste aparelho” | — | Limpeza apaga também a última ação |
| Histórico só no aparelho, sem áudio e sem nuvem | Sim | Não | Parcial | `SharedPreferences` (`jarvis_fundo`), contrato sem `http`/nuvem | — | Não sincroniza entre aparelhos |

## Microfone e resposta — Fase 14 (ajuste 082, 2026-11-20)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Entrega confirmada do microfone | palavra de ativação | espera o `AudioRecord` do detector fechar antes de abrir o reconhecedor (prazo 1,5 s, fora da thread principal) | `MainActivity.kt`, `KwsForegroundService.kt`, `JarvisKwsEngine.java` |
| Repetição com folga por erro | silêncio, “não entendi”, microfone ocupado | tenta mais uma vez; 800 ms para áudio ocupado, 350 ms para silêncio | `MainActivity.kt`, `JarvisEscutaFundo.kt` |
| Aproveitamento do parcial | frase reconhecida pela metade | usa o que já foi entendido em vez de pedir tudo de novo | `MainActivity.kt`, `JarvisEscutaFundo.kt` |
| Ganho automático | voz baixa ou longe | até 4x de ganho em fala fraca, 1x em fala normal, com transição suave | `JarvisKwsEngine.java` |
| Repetição no segundo plano | comando sem tela | uma nova escuta automática antes de desistir, sem falar por cima do microfone | `KwsForegroundService.kt` |
| Resposta antes de rearmar | fim do comando | a palavra de ativação só volta quando a síntese termina; sem confirmação, espera proporcional | `KwsForegroundService.kt`, `JarvisVoz.kt` |

Limite honesto: voz real, ruído, sotaque e o pacote offline pt-BR continuam
dependendo do aparelho físico.

## Palavra de ativação mais confiável — Fase 14 (ajuste 083, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Sensibilidade ajustável na tela | controle deslizante 0–100% (passos de 5) | grava no aparelho e religa o detector com o limiar novo | `services/kws_settings_page.dart`, `KwsForegroundService.definirSensibilidade` |
| Limiar com cinco faixas | valor escolhido | 0,50 / 0,42 / 0,33 / 0,25 / 0,20, com pontuação das palavras 1,5 → 1,8 → 2,0 | `JarvisKwsEngine.limiarPara`/`pontuacaoPalavra`, `core/ativacao_sensibilidade.dart` |
| Sensibilidade sobrevive ao app fechado | última escolha | preferência `jarvis_kws`, lida a cada início do motor | `KwsForegroundService.sensibilidadeDe` |
| Recuperação de falha do motor | erro de JNI ou captura | até três tentativas com espera crescente antes de encerrar o serviço | `KwsForegroundService.onError`, `atrasoFalha` |
| Vigia do detector | motor parado sem comando | religa sozinho a cada 20 s, nunca durante comando ou ativação recente | `KwsForegroundService.iniciarVigia` |
| Rearme mais rápido | fim do comando / abertura da tela | detector volta em 8 s em vez de 35 s | `KwsForegroundService.REARM_DELAY_MS` |
| Diagnóstico honesto | atualizar diagnóstico | mostra a sensibilidade e o limiar que o Android está usando | `MainActivity.statusMap`, `services/kws_bridge.dart` |

Limite honesto: o modelo KWS é treinado em inglês; a sensibilidade aumenta a
tolerância, mas a taxa de acerto por faixa só pode ser medida no aparelho físico.

## Sentinela de mensagens — Fase 14 (ajuste 084, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Resposta direta na notificação (RemoteInput) | botão de responder na mensagem | injeta o texto no campo da própria notificação, sem abrir o app | `JarvisNotificacaoListener.responder`, `JarvisAparelho.kt`, `aparelho_page.dart` |
| Recusa honesta sem campo de resposta | notificação sem RemoteInput ou serviço desconectado | explica o motivo, não registra envio | `JarvisNotificacaoListener.kt`, `core/aparelho.dart` |
| Ler mensagens em voz alta | botão "Ler em voz alta" e alto-falante por linha | lê até cinco mensagens (ou uma) na voz pt-BR do aparelho | `aparelho_page.dart`, `VozJarvis` |
| Escolha da mensagem a responder | app ou pacote | pega a respondível mais recente; nada é escolhido se não houver | `notificacaoParaResponder` |
| Notificação fixa fora da resposta | evento contínuo | `FLAG_ONGOING_EVENT` não entra na lista | `JarvisNotificacaoListener.kt` |
| Peças nativas copiadas pelo preparo | build release | `JarvisAparelho.kt` e `JarvisNotificacaoListener.kt` passam a ser reproduzíveis | `tool/prepare_android_sistema.py` |

Limite honesto: o envio real depende do aplicativo (algumas versões do WhatsApp
recusam RemoteInput) e não foi medido em aparelho físico.

## Resposta em qualquer modo e resumo tático — Fase 14 (ajuste 085, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Rota por visibilidade | palavra de ativação com o app aberto | comando vai para a conversa, não para a recusa de segundo plano | `MainActivity.marcarVisivel`, `KwsForegroundService` |
| Hora e data no aparelho | "que horas são", "que dia é hoje" | responde em frase falável, sem provedor e sem rede | `JarvisFundo.horaFalada`, `dataFalada` |
| Pergunta livre por voz em segundo plano | qualquer pergunta fora dos comandos | envia ao provedor configurado pela ponte e fala a resposta | `JarvisPonteIa.kt`, `PonteIaFundo`, `ProviderService` |
| Recusa honesta sem IA | app encerrado ou sem chave | avisa que não pôde consultar e registra no histórico | `KwsForegroundService.responderPerguntaLivre` |
| Texto falado limpo | resposta do provedor | remove markdown, links e cercas antes da síntese de voz | `respostaFalada` |
| Resumo tático das mensagens | botão no cartão de notificações | separa ruído de grupo, destaca urgente e sugere respostas | `core/resumo_tatico.dart`, `resumo_ia_service.dart`, `aparelho_page.dart` |
| Triagem sem provedor | nenhuma chave configurada | mostra urgência e ruído por regra local, com o motivo escrito | `triagemLocal`, `mensagemUrgente`, `ruidoDeGrupo` |
| Sugestão aproveitada | "Usar" em uma resposta sugerida | abre a resposta da notificação do app certo já preenchida | `_responderSugestao`, `textoInicial` |

Limite honesto: a ponte de IA depende do motor do Flutter vivo; sem aparelho,
a fala real e a classificação de grupos reais não foram medidas.

## Habilidades em Markdown — Fase 15 (ajuste 086, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Pastas de habilidades no aparelho | `Skills/` ou `Habilidades/` na pasta conectada (SAF) e pasta local do app | cada `.md` vira uma habilidade, com limite de 24 | `habilidades_service.dart`, `caminhoDeHabilidade` |
| Cabeçalho da habilidade | frontmatter `nome`, `descricao`, `gatilhos` | nome, descrição e gatilhos; o corpo é o passo a passo | `lerHabilidade`, `lerMarkdown` |
| Habilidade repetida ou fora da pasta | arquivo na raiz do cofre, nome igual | é ignorada, sem duplicar o procedimento | `habilidadesDosArquivos` |
| Ativação pela pergunta | pergunta com gatilho ou palavra do nome | no máximo duas habilidades entram no pedido | `habilidadesQueCasam` |
| Bloco no pedido ao provedor | habilidade ativada | instrução de sistema com nome, quando e passos, com limite de 4000 caracteres | `blocoHabilidades`, `montarMensagens` |
| Transparência da habilidade usada | resposta com habilidade | a conversa mostra “Habilidades usadas” e o histórico guarda os nomes | `conversa.dart`, `voice_conversation_page.dart` |
| Tela de habilidades | módulo “Habilidades em Markdown” | lista, origem, gatilhos, “Ler de novo” e “Criar exemplo” | `habilidades_page.dart` |

Limite honesto: o Markdown orienta a IA, não executa nada; a leitura real em
aparelho e a qualidade da ativação por gatilho não foram medidas.

## Flip-to-shush e modo noturno — Fase 15 (ajuste 087, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Virar para calar | celular de bruços (Z ≤ −8,0) | para a voz da tela e do serviço e devolve o microfone ao detector | `JarvisSensores.Vigia`, `MainActivity.calarTudo`, `ACTION_CALAR` |
| Histerese do gesto | celular volta para cima (Z ≥ −4,0) | rearma o aviso; no máximo um a cada 1,2 s | `JarvisSensores` |
| Sensor só com a tela na frente | onPause/onResume | registra e desregistra o acelerômetro | `MainActivity.rearmarVigia` |
| Calar agora | botão na tela de gestos | chama o mesmo caminho do gesto | `sensores_service.dart`, `gestos_page.dart` |
| Brilho do modo noturno | interruptor e controle 10–100% | aplica só na janela do app, sem WRITE_SETTINGS | `MainActivity.aplicarBrilho` |
| Voz suave no modo noturno | resposta falada | volume em 45% via `KEY_PARAM_VOLUME` | `JarvisVoz.falar` |
| Estado persistido | abrir a tela ou o app | lê `jarvis_gestos` e reaplica brilho e sensor | `JarvisSensores.estado` |

Limite honesto: sem aparelho físico não foi medido o gesto real, o tempo de
silenciamento nem o brilho percebido; o sensor não funciona com o app fechado.

## Perfis de timbre — Fase 15 (ajuste 088, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Escolher o timbre | tela “Perfis de timbre” (gaveta e catálogo) | grava o perfil e aplica tom e ritmo na síntese | `JarvisTimbre.kt`, `VozJarvis.definirTimbre`, `timbre_page.dart` |
| Grave | perfil original | tom 0,72 e ritmo 0,88, sem regressão do ajuste anterior | `core/timbre_voz.dart`, `JarvisTimbre.PERFIS` |
| Natural | perfil neutro | tom e ritmo nativos da voz do aparelho | `JarvisVoz.aplicarTimbre` |
| Ágil | perfil rápido | tom 1,15 e ritmo 1,12 | `JarvisTimbre.PERFIS` |
| Ouvir exemplo | botão na tela | fala a frase de exemplo com o timbre atual | `fraseExemploTimbre`, `VozJarvis.falar` |
| Um timbre para tudo | voz da tela e do segundo plano | as duas instâncias leem a mesma preferência do aparelho | `JarvisVoz.onInit` |
| Padrão seguro | id desconhecido ou vazio | cai no grave sem quebrar a tela | `timbreDe`, `JarvisTimbre.perfil` |

Limite honesto: a voz continua sendo a do aparelho; qualidade e percepção de
tom não foram medidas em aparelho físico.

## Segundo plano sem app aberto — Fase 15 (ajuste 089, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Motor sem tela | pergunta livre sem motor do app | sobe um `FlutterEngine` do serviço com a entrada `mainFundo` | `JarvisPonteIa.kt`, `main.dart` |
| Mesma IA | pergunta livre | usa o mesmo `ProviderService`, chaves e personalidade do app | `PonteIaFundo.ligar` no motor sem tela |
| Espera do canal | motor recém-criado | tenta de novo por até 12 s até o Dart atender | `esperarCanal` |
| Motor ocioso | 3 min sem pergunta ou fim do serviço | desliga o motor para não gastar memória | `OCIOSIDADE_MS`, `JarvisPonteIa.encerrar` |
| Motivo na voz | falha da IA | separa falta de provedor, demora e falha de rede | `KwsForegroundService.responderPerguntaLivre` |

Limite honesto: o motor sem tela só existe depois de o serviço estar de pé; o
tempo de subida não foi medido em aparelho físico.

## Modo de visita (Duress PIN) — Fase 15 (ajuste 090, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| PIN de coação | tela “Segurança e privacidade” | valida o PIN principal, checa a política, recusa igual ao principal e grava sal e digest próprios | `BloqueioStore.definirCoacao` |
| Abrir em visita | PIN de coação na tela de bloqueio | confere os dois PINs sempre e abre o app vazio, nunca o real | `BloqueioStore.conferir`, `bloqueio_gate.dart` |
| Esconder dados | modo de visita | o app real nem é montado; conversa, memória, fichas, arquivos e chaves não aparecem | `ModoVisitaPage` |
| Sem IA na coação | pergunta no modo de visita | respostas locais, nenhum provedor, nenhuma rede | `core/modo_visita.dart` |
| Desligar a escuta | entrar em visita | para a palavra de ativação para não falar dados em voz alta | `jarvisKwsController.stop` |
| Prompt sugerido | tela de segurança e ajustes da visita | texto “Modo de visita” com regras de neutralidade, botão de copiar | `promptModoVisita` |
| Registro de uso | tela de segurança | data do último uso, só visível com o PIN principal | `coacaoUsadaEm` |

Limite honesto: esconde, não apaga nem criptografa de novo; biometria ainda abre
o app real e quem souber os dois PINs não é protegido.

## Assinatura de release — Fase 15 (ajuste 091, 2026-11-21)

| Recurso | Entrada | Ação | Onde |
|---|---|---|---|
| Chave de release | `key.properties` fora do repositório | assina o APK com a chave do projeto | `build.gradle.kts` (gerado por `tool/prepare_android_sistema.py`) |
| Ordem de procura | env `JARVIS_KEY_PROPERTIES` → `android/key.properties` → `~/.jarvis/key.properties` | o segredo fica fora da pasta do projeto por padrão | bloco `chaveRelease` |
| CI | propriedades `-P` com os secrets existentes | mesma assinatura sem arquivo versionado | `storeFile`, `storePassword`, `keyAlias`, `keyPassword` |
| Recusa de debug | build de release sem chave | para com mensagem, em vez de gerar APK que não atualiza | `gradle.taskGraph.whenReady` |
| Conferência | `tool/verificar_assinatura.py` | mostra certificado e SHA-256, compara com o esperado e reprova debug | `--exigir-release` |
| Modelo | `flutter_app/key.properties.example` | campos obrigatórios sem segredo real | — |
| Esteira de release | `.github/workflows/flutter-release-apk.yml` (disparo manual) | compila o APK arm64, decodifica o keystore dos secrets em `$RUNNER_TEMP`, confere com `keytool -list` e publica APK + SHA-256 | contrato em `tests/test_assinatura_release.py` |
| Parada sem segredo | qualquer um dos quatro secrets faltando | job para antes de compilar, sem cair na chave de debug | `test -n` de cada secret |
| Identidade Android | `tool/prepare_android_identidade.py` | `com.jarvis.nova`, rótulo e `MainActivity` no runner gerado | usado pelas duas esteiras |

Limite honesto: a chave é do dono do app e nunca entra no repositório; perdê-la
obriga todos os usuários a desinstalar para receber versões futuras.
