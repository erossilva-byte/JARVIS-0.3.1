# Aprendizado explícito — 1.36.0

Data: 31 de outubro de 2026

## O que foi auditado

O projeto já tinha perfis de pessoas, memória por tópicos, Obsidian, planos, tarefas, voz, núcleo 3D, PC e diagnóstico. Não existia um módulo que registrasse preferências e correções do usuário de forma explícita, revisável e sem alterar permissões.

## Implementado

- `aprendizado.js`: módulo local, sem DOM e sem rede.
- Aprende apenas instruções explícitas (`prefiro`, `evite`, `sempre`, `nunca`, `lembre que`, `corrija`).
- Não aprende senhas, tokens, dados financeiros, biometria ou chaves.
- Deduplica, registra confiança, permite remover, desfazer, limpar, exportar e importar.
- Contexto do prompt limitado a dez itens ativos com confiança mínima.
- `aprendizado_ui.js`: painel de revisão em Memória, com ensinar, exportar, apagar e ver o contexto.
- `app.js`: aprende no turno e inclui o contexto no prompt, sem transformar aprendizado em instrução de segurança.
- Testes `tests/test_aprendizado.js` e `tests/test_v1_36_0.py`.

## Classificação

| Recurso | Estado |
|---|---|
| Aprendizado explícito de preferências/correções | **IMPLEMENTADO E TESTADO** em Node |
| Remoção, desfazer, exportação e importação | **IMPLEMENTADO E TESTADO** em Node |
| Bloqueio de conteúdo sensível | **IMPLEMENTADO E TESTADO** |
| Aplicação no prompt | **IMPLEMENTADO, MAS NÃO TESTADO** em conversa com provedor real |
| Painel em Memória | **IMPLEMENTADO, MAS NÃO TESTADO** visualmente em aparelho |
| Aprendizado automático de hábitos por observação | **NÃO IMPLEMENTADO** — exigiria inferência e consentimento adicionais |
| Perfis com permissões por pessoa | **PARCIALMENTE IMPLEMENTADO** — perfis e consentimentos existem; controles de acesso por perfil não foram ampliados nesta etapa |
| Sincronização Android↔Windows | **PARCIALMENTE IMPLEMENTADO** — Obsidian/PC existentes preservados; canal autenticado novo não implementado |
| ESP32/Home Assistant | **NÃO IMPLEMENTADO** |
| Interface completamente nova | **NÃO IMPLEMENTADO** — a identidade existente foi preservada e o painel de aprendizado foi integrado |
| RAG vetorial | **NÃO IMPLEMENTADO** |

## Preservação

Nenhum painel, ferramenta, agente, memória, voz, núcleo 3D, HUD, plasma, órbita, área, modo, permissão ou fluxo de confirmação foi removido.

## Build 1.36.0

- Arquivo: `jarvis-nova-1.36.0-10360.apk`.
- Bytes: 81186074.
- SHA-256: `0a643a41af7bfed0bf16dc4e40c3288c4f0b500e73528c2fe6be7a3ffeca6bc7`.
- `aapt`: pacote `com.jarvis.nova`, versão 1.36.0, versionCode 10360, minSdk 26.
- Assets: `aprendizado.js`, `aprendizado_ui.js`, `core.js`, `core_ui.js`, `core.css` e `index.html`.
- Build: `assembleDebug`, JDK 21, SDK 35, build-tools 35.0.0, 26 s.
- Acessibilidade confirmada; instalação e abertura não testadas em aparelho.

## Limitações

Sem aparelho físico, não foi possível validar visualmente o painel, o microfone, a voz, a persistência após reinício do Android ou a conversa com cada provedor. Aprendizado é explícito; não é uma inferência silenciosa de hábitos.
