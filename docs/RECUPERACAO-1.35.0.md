# Confiabilidade e recuperação — 1.35.0

Data: 31 de outubro de 2026

## Escopo

Esta revisão não tenta transformar o J.A.R.V.I.S. em um sistema operacional autônomo. Ela cria uma camada verificável de **autodiagnóstico, causa provável, pré-checagem e recuperação limitada** sobre o Core da 1.34.0. Diagnóstico não é recuperação; recuperação não é permissão para reiniciar serviços Android.

## Auditoria: o que já existia

- `executarDiagnostico()` em `app.js` já verifica pacote, módulos, armazenamento, cofre, rotinas, pessoas, segundo plano, microfone, TTS, IA local, provedores, câmera, rede, recibos e erros recentes.
- `sistema.js` já tem catálogo de ferramentas, checkpoints de tarefas, permissões, confirmação, timeout e diagnóstico próprio.
- `core.js` já tinha sete componentes, diagnóstico a cada 120 s e histórico do último diagnóstico.
- O painel de Ajustes ▸ Diagnóstico já exibia estados, impacto, orientação e detalhes técnicos reais.

## Problemas encontrados

1. O Core registrava “falhou”, mas não dizia se a causa era temporária, de configuração ou crítica.
2. O watchdog só media; não tinha recuperação, espera, limite de tentativas nem histórico.
3. A delegação não fazia pré-checagem das dependências antes de chamar um executor.
4. O diagnóstico não mostrava estado do Core, recuperações nem recursos do aparelho.
5. Não havia teste de que um componente pudesse voltar a funcionar sem reiniciar o aplicativo inteiro.
6. A interface não distinguia aviso de falha no painel do Core.

## Correções realizadas

- Componentes agora declaram categoria, dependências, recuperação segura e se ela pode ser automática.
- Cada falha recebe causa provável (`temporaria`, `configuracao` ou `critica`), detalhe e orientação.
- `recuperarComponente()` executa somente a função declarada pelo próprio componente, com timeout de 4 s, rechecagem do efeito e histórico.
- A recuperação tem espera de 20 s e no máximo 2 tentativas por janela de 5 min; isso evita loop.
- `recuperarFalhas()` só tenta componentes que declararam recuperação; o automático exige `recuperacaoAutomatica: true`.
- A pré-checagem verifica dependências do agente e bloqueia a execução sem mascarar o bloqueio como falha.
- O diagnóstico do Core mostra causa, evidência, orientação e histórico; o diagnóstico de Ajustes inclui uma linha do Core.
- O diagnóstico de recursos só mostra RAM JavaScript e bateria quando a API existe. CPU é exibida apenas como número de núcleos; percentual de uso não é inventado.
- O painel ganhou histórico de recuperações e botão explícito; nada reinicia serviço Android.

## Classificação

| Recurso | Classificação | Evidência / limite |
|---|---|---|
| Autodiagnóstico do Core | **IMPLEMENTADO E TESTADO** | `node tests/test_core.js` verifica componentes, causa, aviso e histórico; teste em APK ainda pendente |
| Classificação de causa | **IMPLEMENTADO E TESTADO** | temporária, configuração e crítica no Core; cobertura unitária |
| Recuperação manual por componente | **IMPLEMENTADO E TESTADO** | recuperou componente de teste, rechecou efeito e limitou repetição |
| Recuperação automática | **IMPLEMENTADO E TESTADO** | somente componente opt-in; tentativa automática coberta no Core |
| Prevenção de loop | **IMPLEMENTADO E TESTADO** | espera e limite por janela cobertos no teste do Core |
| Pré-checagem operacional | **IMPLEMENTADO E TESTADO** | bloqueio antes de delegar coberto no Core |
| Diagnóstico integrado de Ajustes | **PARCIALMENTE IMPLEMENTADO** | já existia e foi ampliado; validação em aparelho não feita |
| Painel de recuperação | **IMPLEMENTADO, MAS NÃO TESTADO** | HTML, UI e CSS presentes; sem teste visual/interativo |
| RAM, CPU e bateria | **PARCIALMENTE IMPLEMENTADO** | só exibe quando a WebView fornece; sem instrumentação no aparelho |
| Abertura, voz, microfone, câmera e acessibilidade | **BLOQUEADO POR PERMISSÃO OU LIMITAÇÃO TÉCNICA** | requer aparelho físico e permissões reais |
| Serviço Android em segundo plano | **NÃO IMPLEMENTADO NESTA ETAPA** | `JarvisWatchdog` e serviço existentes foram preservados; o Core não os reinicia |
| Integrações PC/TV/ESP32 e MCP | **NÃO IMPLEMENTADO** | continuam fora do escopo desta revisão |

## Preservação

Nenhum painel, ferramenta, agente, memória, voz, núcleo 3D, HUD, plasma, órbita, área, modo ou fluxo de confirmação foi removido. O Core continua sem rede, sem DOM e sem chaves.

## Testes

- `node tests/test_core.js`: agentes, contexto, verificação, recuperação, repetição, automático, pré-checagem e watchdog.
- `python3 tests/test_v1_35_0.py`: contrato estático e honestidade da interface.
- `npm run test:all`: regressão completa.
- Build Android e `aapt`: executados após a suíte.

## Build 1.35.0

- Arquivo: `jarvis-nova-1.35.0-10350.apk`.
- Bytes: 81.179.307.
- SHA-256: `ef370fe3d41dbb34937ce4cff2d97953157af0d73f5bf067c5b6cf0fc00fbbb2`.
- `aapt`: pacote `com.jarvis.nova`, versão 1.35.0, versionCode 10350, minSdk 26, targetSdk 34.
- Assets confirmados: `core.js`, `core_ui.js`, `core.css` e `index.html`.
- Build: `assembleDebug`, JDK 21, SDK 35, build-tools 35.0.0, 26 s.
- Acessibilidade: serviço `com.jarvis.nova.JarvisAcessibilidade` com `BIND_ACCESSIBILITY_SERVICE` confirmado.
- Instalação, abertura, microfone, câmera, acessibilidade real, segundo plano, RAM e bateria não foram testados em aparelho físico.

## Limitações

Sem aparelho Android, não é possível provar instalação, abertura, microfone, câmera, acessibilidade, wake word, segundo plano, RAM, bateria ou reinício real de serviço. O Core não reinicia serviços Android por conta própria; essa é uma decisão de segurança, não uma promessa de recuperação total.
