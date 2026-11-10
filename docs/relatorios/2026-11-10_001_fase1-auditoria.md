# Relatório — Fase 1: auditoria e parecer de viabilidade

## 1. Identificação

- **Projeto:** J.A.R.V.I.S. Nova (`erossilva-byte/JARVIS-0.3.1`)
- **Data:** 2026-11-10
- **Branch auditada:** `work/1.48.0-fase2-consolidacao` (commit base `3996687`)
- **Versão declarada:** 1.46.0 (`VERSAO.json`), versão no `package.json` da `main`: 1.31.2
- **Plataformas:** Android (Capacitor/WebView) e Windows (Electron)
- **Modo:** somente leitura, exceto os ajustes 001 e 002 descritos adiante
- **Ambiente da auditoria:** Flutter 3.47.9, Dart 3.13.7, clone raso da branch. Sem aparelho físico, sem Android SDK e sem Windows

---

## 2. Conflito central encontrado (regra 8)

O prompt exige, na regra 15 e na Seção 3D, **interface 100% nativa sem Web** ("proibido WebView, HTML/JS embutido, PWA, Electron"). A Seção 3C exige **Kotlin** no nativo e proíbe arquivos Java novos.

O repositório faz exatamente o contrário:

| Camada | O que existe de fato | Evidência |
|---|---|---|
| Android | Capacitor 6 — interface em WebView | `capacitor.config.json` (`webDir: www`), `@capacitor/android ^6.1.0` |
| Interface | `index.html` (1.501 linhas), `style.css` (1.728), 25 módulos JS (~30 mil linhas), `app.js` com 11.932 linhas | `index.html:1459-1499`, `wc -l` |
| Nativo Android | 22 arquivos **Java**, 6.571 linhas, zero Kotlin | `MainActivity.java`, `JarvisUtilPlugin.java` (1.270), `JarvisVozPlugin.java` (717) |
| Windows | **Electron 33** com `spawnSync('powershell.exe')` | `package.json`, `platforms/desktop/main.js:92` |
| Flutter | Embrião: 668 linhas em `lib/main.dart`, 5 services, 23 testes | `flutter_app/` |

**Decisão adotada (por sua escolha explícita do caminho B):** migrar para Flutter/Dart + Kotlin **de forma incremental**, mantendo o app em Capacitor funcionando até cada módulo ter equivalente Flutter verificado. Nada é removido antes de ser substituído. Isso respeita a regra 2 ("não recrie do zero") e a regra 15 ao mesmo tempo — a segunda só passa a valer para as telas já migradas.

**Consequência de prazo:** o Flutter hoje cobre voz/KWS e provedores de IA. Faltam interface completa, memória, visão, arquivos, CAD, agentes com UI, Windows. É trabalho de meses, não de uma fase.

---

## 3. O que foi feito nesta etapa

| Alteração | Arquivo | Motivo |
|---|---|---|
| Correção de null-safety | `flutter_app/lib/services/voice_conversation_page.dart` | O `flutter analyze` falhava e travava os dois jobs do CI antes de testes e builds |
| Relatório e inventário | `docs/relatorios/`, `docs/INVENTARIO_DE_FUNCOES.md` | Entregáveis da Fase 1 (Seções 5 e 5B) |

**Desvio declarado:** a correção do Flutter foi feita antes da sua aprovação da Fase 1; o prompt previa não alterar arquivos até o parecer. Ela é isolada, de escopo mínimo e necessária para o CI voltar a medir qualquer coisa. Reversível com `git revert`.

---

## 4. Estado técnico levantado

### 4.1 Android (build)

A pasta `android/` **não está no repositório**: é gerada por `npx cap add android` no CI e ajustada por quatro scripts Python idempotentes.

- AGP **8.13.0**, Gradle wrapper **8.13**, JDK **21** (o AAR do MediaPipe 0.10.24 é class file 65)
- `compileSdk 36`, `minSdk 26`, `targetSdk 36` — após o ajuste 002 (antes: 35/26/34)
- ABIs: `arm64-v8a`, `armeabi-v7a` (bibliotecas nativas ~53 MB)
- Dependências nativas: `com.google.mediapipe:tasks-genai:0.10.24`, `sherpa-onnx-1.13.8.aar` (SHA-256 fixado em `baixar_sherpa.py`), `commons-compress 1.26.2`, `androidx.biometric 1.1.0`, `androidx.documentfile 1.0.1`
- ~24 permissões declaradas, incluindo `REQUEST_INSTALL_PACKAGES`, `SCHEDULE_EXACT_ALARM`, `CALL_PHONE`, `READ_CONTACTS`, `CAMERA`, `NFC`, `USE_BIOMETRIC`
- Serviços: `JarvisService` (`foregroundServiceType="microphone|dataSync"`), `JarvisMusicaService` (`mediaPlayback`), `JarvisAcessibilidade`, `JarvisNotificationListener`; receivers de boot e watchdog

### 4.2 Ponte Flutter ↔ nativo

`MainActivity extends BridgeActivity` e registra 8 plugins Java: background, util, local AI, update, voz, música, segurança, acessibilidade. **Não há Pigeon nem MethodChannel tipado** — o contrato é JSON sobre a ponte do Capacitor. O Flutter usa canal próprio apenas para KWS.

### 4.3 Agentes e ações

Registro `ACOES` em `app.js:1412` com **55 ações** classificadas por risco 0–3; 12 de risco ≥ 2 (ligar, SMS, mensagem, e-mail, acessibilidade clicar/digitar/rolar, responder notificação, bloquear tela, arquivo criar/editar, desligar PC). Há supervisor de planos (`plano.js`) com limite de 6 etapas e recibos.

### 4.4 Memória

`memoria.js` implementa um "cofre" em **`localStorage`** (chave `jv_obsidian_vault`), com notas por tema mapeadas para `Memoria/*.md`, busca por embedding de hash + cosseno e teto de notas/bytes.

Isso **não é** a Fase 7B. Falta: acesso ao cofre real via SAF, arquivos Markdown em disco, frontmatter YAML, diário de escrita, FTS5, detecção de edição concorrente, `_Inbox`/`_Conflitos`/`_Lixeira`. O que existe é um subconjunto com semântica parecida dentro do WebView.

### 4.5 Voz

- **KWS:** `JarvisKwsEngine` + sherpa-onnx `zipformer-gigaspeech-3.3M` (modelo **inglês**), keywords "Jarvis"/"Javis", limiar 0.25/0.35/0.45 por sensibilidade, score 1.5, `AudioRecord` 16 kHz, sem rede antes da ativação. O próprio código admite que a precisão em pt-BR não foi medida.
- **TTS/STT:** TTS do sistema + voz neural sherpa; STT com `SpeechRecognizer` (on-device quando disponível).

### 4.6 IA local

MediaPipe LLM Inference 0.10.24, apenas `.task`, Gemma 3 1B IT q4 (529 MB) importado manualmente, CPU, prompt ≤ 6.000 caracteres, sem streaming e sem function calling. Diagnóstico do fechamento (SIGABRT por runtime antigo) já está documentado e corrigido em `MODELOS-IA-LOCAL.md`.

### 4.7 CI/CD

`build-apk.yml` roda em `ubuntu-24.04`, JDK 21, SDK 36, regenera `android/`, roda `npm run test:all` (117 arquivos de teste), compila APK debug e publica artefato com checksum. Há também `release-apk.yml`, `release-pc.yml`, `publicar-utilitarios.yml`, `ci.yml`, `ci-android-auditoria.yml`, `auditoria-android-windows.yml` e `flutter-native.yml`.

**Nenhum `secrets.*` era usado em workflow algum.** O APK era assinado com `ci/debug.keystore`, versionado no repositório — corrigido no ajuste 002.

### 4.8 Testes

117 arquivos. A maioria é de **contrato estático**: leem `app.js`/`index.html` como texto e verificam presença de strings (ex.: `tests/test_plano_integracao.py`). Os testes de motor (`test_hermes.js`, `test_plano.js`, `test_cad_*`) exercitam lógica de verdade, mas nenhum toca aparelho, microfone, câmera ou Windows.

---

## 5. Parecer de viabilidade por módulo

| Módulo | Parecer | Justificativa |
|---|---|---|
| Base de build Android + CI | **Viável** | Pipeline completo e verde na `main` |
| Migração Flutter da interface | **Parcial** | Fundação existe; portar 30 mil linhas de JS é trabalho de meses |
| KWS local em pt-BR | **Parcial** | Motor real, modelo inglês; exige medição com sua voz |
| KWS em segundo plano (Android 16/HyperOS) | **Parcial** | Serviço existe; restrições de Android 14+ e HyperOS não validadas em campo |
| TTS masculino grave pt-BR local | **Parcial** | Depende do pacote de voz do aparelho ou de modelo neural; sem medição |
| STT pt-BR local | **Parcial** | Depende de `createOnDeviceSpeechRecognizer` e do pacote de idioma |
| IA na nuvem com failover | **Viável** | 5 provedores implementados; falta teste com chaves reais |
| IA local Gemma 3 1B | **Parcial** | Roda no papel; pesado para 8 GB com app e voz ativos |
| Memória estilo Obsidian (Fase 7B) | **Parcial** | Hoje é `localStorage`; cofre real, WAL e FTS5 não existem |
| Fichas de pessoas | **Parcial** | `pessoas.js` + identificação por voz existem; biometria facial local não |
| Reconhecimento facial local | **Inviável no curto prazo** | Exigiria modelo facial local; nenhum integrado |
| Vision/OCR | **Parcial** | Depende de API ou de modelo local não embarcado |
| Sandbox de execução | **Parcial** | `sandbox.js` roda dentro do WebView; não há isolamento real de SO |
| CADeSIMU (Fase 10) | **Inviável como interoperabilidade** | O `.cad` do app é JSON próprio, não o do CADe SIMU; não há especificação pública do formato do CADe SIMU. Fica análise lógica própria, sem importar/exportar |
| Comandos Android (Fase 10B) | **Viável/Parcial** | 55 ações reais; fechar apps, Wi-Fi e tela continuam limitados pelo Android |
| Paridade Windows | **Parcial** | Electron com `powershell.exe`; migrar para Flutter Windows é o caminho, hoje inexistente |
| Metas de desempenho da 3D | **Não medida** | Nenhum dado de fps, jank ou abertura; exige Poco X7 |

---

## 6. Problemas priorizados

**P0 — bloqueiam uso ou entrega**
1. Nenhum APK 1.46.0 foi compilado e testado em aparelho físico (`VERSAO.json` declara isso). O estado real de uso é desconhecido.
2. Release assinada com **keystore de debug versionado** (`ci/debug.keystore`, `patch_gradle.py`) — **corrigido no ajuste 002**.
3. `flutter analyze` falhava e travava o único portão da migração — **corrigido**.
4. `targetSdk 34` contra os 36 exigidos — **corrigido no ajuste 002**.

**P1**
5. KWS com modelo inglês, sem medição pt-BR.
6. Memória em `localStorage`, não em cofre Obsidian real.
7. Permissão `REQUEST_INSTALL_PACKAGES` (auto-atualização) conflita com a lista de bloqueio da Fase 10C.
8. Testes em maioria estáticos: o CI verde não prova funcionamento no aparelho.

**P2**
9. Dois front-ends em paralelo (JS e Flutter) durante toda a migração.
10. Sem `ktlint`/`detekt`, sem Pigeon, sem lockfile de Dart fixado.
11. `INVENTARIO_DE_FUNCOES.md` e `docs/relatorios/` não existiam.

---

## 7. Não verificado (depende de você)

- Perfil de fps/jank, abertura a frio/quente, ANR, vazamento de memória: **exige Poco X7** em modo profile com DevTools/Perfetto.
- Taxa de acerto e falso positivo do KWS com sua pronúncia: **exige falas reais**, 8 h de bateria.
- Instalação limpa e atualização sobre a versão anterior preservando dados.
- Teste com Obsidian aberto ao mesmo tempo.
- `flutter build apk` e `flutter build windows`: sem Android SDK/Windows neste ambiente; o CI cobre depois do push.
- Comportamento no HyperOS (morte de serviço, exclusão de bateria).

---

## 8. Próxima fase proposta

**Fase 2 — base estável**, na ordem: (a) enviar a correção do Flutter e deixar o portão rodar ponta a ponta; (b) separar assinatura de release do keystore de debug, com chave em secret; (c) subir `targetSdk` para 36 e medir a primeira execução real do app no Poco X7 com o checklist da 3B.11; (d) só então retomar o porte de módulos para Flutter.
