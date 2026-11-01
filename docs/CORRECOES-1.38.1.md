# 1.38.1 — Auditoria corretiva

Data: 2026-11-01.

Esta rodada não adiciona recurso novo. Ela corrige defeitos encontrados na auditoria da 1.38.0 e registra, sem simulação, o que continua dependente de aparelho, chave, modelo ou integração externa.

## Defeitos encontrados e corrigidos

### 1. Cancelamento durante a última etapa

**Sintoma:** `cancelarTarefa()` durante uma ação em voo marcava a tarefa como `cancelada`, mas o retorno tardio da ferramenta sobrescrevia o estado para `concluida`.

**Causa:** o laço de `executarTarefa()` não rechecava o estado depois do `await` e a trava `emExecucao` era removida pelo cancelamento antes do `finally`.

**Correção:** depois da ferramenta, o núcleo verifica `cancelada`; a etapa fica `incerto`, a tarefa permanece `cancelada` e a trava só é liberada no `finally`. Um teste com ferramenta bloqueada em `Promise` reproduz o caso.

### 2. Visão 2.0 com declarações duplicadas

**Sintoma:** `abrirVisao`, `limparBaloes`, `desenharBaloes`, `selecionarObjeto` e `analisarQuadro` existiam duas vezes no mesmo escopo. A última declaração vencia; a primeira era código morto. Reabrir o painel não limpava a análise anterior porque a versão ativa de `abrirVisao` não chamava `limparBaloes()`.

**Correção:** os blocos mortos foram removidos, a versão avançada com `VIS.layoutBaloes`, linhas-guia e seleção assíncrona foi preservada, e a abertura agora limpa balões, texto, seleção e progresso. O contrato 1.38.1 falha se uma dessas funções voltar a ter duas declarações de topo.

### 3. Roteador aceitando provedor desconhecido

**Sintoma:** `planejarIA()` usava `CATALOGO[id] || true`, aceitando qualquer ID. Com uma lista só de IDs inválidos, `CATALOGO[primeira].nome` podia lançar exceção.

**Correção:** o filtro agora exige `CATALOGO[id]`, remove duplicatas com `Set` e devolve fila vazia com motivo legível quando não há provedor válido. Dois testes cobrem ID inventado e duplicado.

### 4. Senha com viés de módulo

**Sintoma:** o gerador usava `byte % tamanho` e um shuffle com apenas oito bytes, favorecendo posições/caracteres.

**Correção:** sorteio uniforme com rejeição (`inteiroSeguro`) para caracteres e Fisher-Yates. O teste confere comprimento e presença dos quatro grupos.

### 5. Preparação de ação sem tratamento de exceção

**Sintoma:** uma exceção em `def.prep(args)` escapava do `executarSeguro` sem recibo nem mensagem.

**Correção:** a preparação é envolvida em `try/catch`, registra `recusado` e devolve `{ falhou: true }` com mensagem clara.

### 6. GitHub Actions executava os testes antes de gerar o Android

**Sintoma:** o workflow de release falhou na `v1.38.0` em “Testes estáticos e regressão”, com `FileNotFoundError: android/app/build.gradle`.

**Causa:** `npm run test:all` era executado antes de `npx cap add android`; o contrato 1.37 lê o `build.gradle` nativo, que ainda não existia.

**Correção:** os workflows de build e release agora geram o projeto Android, aplicam `patch_gradle.py`/`patch_android_version.py` e só então executam a suíte. O workflow de build também aceita o nome real `JARVIS-Nova-*-fonte.zip` (além do antigo `JARVIS-NOVA-*`), que antes não disparava por diferença de caixa, e remove a pasta `android/` extraída da fonte antes de `npx cap add`.

## O que foi preservado

Identidade, voz, personalidade, humor, memória, pessoas, agentes, Core, planos, tarefas persistentes, avatar, HUD/plasma/órbita, acessibilidade, PC, aprendizado explícito e confirmações. Nenhum provedor, painel ou ferramenta foi removido.

## Testes executados

- `node tests/test_sistema.js` — 21 verificações, incluindo cancelamento em voo e senha.
- `node tests/test_hermes.js` — roteador com provedor desconhecido/duplicado.
- `npm run test:all` — suíte completa; resultado registrado no relatório final da entrega.
- `python3 tests/test_v1_38_1.py` — contrato da versão após o build.
- Compilação Android e `aapt`/`apksigner` — resultados no relatório de release.
- Workflows: falha da `v1.38.0` reproduzida pelo log do Actions; ordem corrigida e YAML conferido. A execução nova da `v1.38.1` não foi aguardada nesta máquina.

## Limitações que continuam

- Sem `adb`, aparelho ou emulador: não houve instalação, abertura, toque, microfone, wake word, notificações, acessibilidade, segundo plano ou avatar em tela real.
- Sem chaves reais: nenhum provedor em nuvem foi chamado para provar cota, modelo ou qualidade.
- Sem modelo `.task`: a inferência local não foi executada.
- Sem Windows/ESP32/Home Assistant: essas integrações não foram validadas fisicamente.
- Não há navegador/jsdom nesta imagem; a navegação e a rolagem foram verificadas por contratos estáticos, não por interação visual.

## Build 1.38.1

- Arquivo: `jarvis-nova-1.38.1-10381.apk`.
- Tamanho: 81195283 bytes.
- SHA-256: `28a87cb3ec4eaa6d890047406c481190ff8868d080391ce679a0cf832ca8af5b`.
- `aapt`: `com.jarvis.nova`, 1.38.1, versionCode 10381, minSdk 26, targetSdk 34, compileSdk 35.
- `apksigner`: verificação concluída com sucesso (APK debug/CI, assinatura v2).
- Assets conferidos dentro do APK: `app.js` com `VERSAO_APP = '1.38.1'`, `index.html`, `sistema.js`, `hermes.js` e `avatar.js`.
