# Inventário de funções — J.A.R.V.I.S. Nova

Estado em 2026-11-10, branch `work/1.48.0-fase2-consolidacao`, após o ajuste 002.
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
| Cofre de notas temático | Sim | Sim | Parcial | `memoria.js` (`localStorage`) | — | **Não é cofre Obsidian em disco** |
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
| Interface Flutter nativa | Sim (branch) | Sim (branch) | Parcial | `lib/main.dart` (668 linhas) | — | Núcleo, Sistemas, Ajustes e Provedores |

## Arquivos, CAD e desenvolvimento

| Função | Android | Windows | Estado | Evidência | Requisito | Limitações |
|---|---|---|---|---|---|---|
| Arquivos (criar/editar/analisar) | Sim | Sim | Parcial | `arquivos_dev.js`, `platforms/desktop/arquivos.js` | seletor | Sem OCR embarcado |
| Sandbox de execução | Sim | Sim | Parcial | `sandbox.js` | — | Sem isolamento de SO |
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
- **CI da branch verde no commit `20168c8`**: regressão completa, compilação Android 36 e portão Flutter (Android + Windows) no mesmo SHA.
- Nenhuma regressão registrada.
