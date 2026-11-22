# Ajuste 041 — fecha os itens abertos da Fase 5 (2026-11-14)

## Por que

A entrega anterior da Fase 5 deixou itens em aberto por falta de Flutter e de persistência:
histórico, modo voz em tela cheia, retomada de rascunho e a própria verificação de compilação.
Este ajuste ataca todos eles com verificação de verdade.

## Ferramenta instalada (fora do repositório)

Flutter 3.50.0 stable e Dart 3.14 baixados em `/tmp` (não entram no repositório nem no
checkpoint). Com eles:

- `flutter analyze` — **0 problemas**;
- `flutter test` — **36 testes aprovados**.

O primeiro `analyze` apontou 14 avisos de depreciação: o Flutter 3.50 descontinuou
`package:flutter/material.dart` em favor de `package:material_ui/material_ui.dart`. Todos os 14
arquivos foram migrados; `material_ui ^1.11.0` entrou no `pubspec.yaml`. Também entrou
`shared_preferences ^2.5.6`. O `pubspec.lock` foi atualizado de propósito.

## O que foi implementado

### Histórico de conversas persistente

- `core/conversa.dart`: modelo puro com título automático, serialização JSON tolerante a dados
  inválidos e ordenação por fixação/recência.
- `services/conversa_store.dart`: `shared_preferences`, lista corrompida tratada como vazia,
  rascunho separado.
- `services/historico_page.dart`: busca por título ou conteúdo, fixar, apagar com confirmação,
  nova conversa, estados vazio/sem resultado/carregando.
- A conversa salva a cada mensagem; o campo restaura o rascunho ao abrir uma conversa nova.

### Modo voz em tela cheia

`services/voz_tela_cheia_page.dart`: núcleo animado, estado real do KWS (sem “ouvindo”
inventado), legendas do comando, iniciar/parar escuta e encerrar. Respeita animação reduzida e
isola o `CustomPaint` com `RepaintBoundary`. Atalho na tela principal e na conversa.

### Conversa

- **Regenerar** a última resposta (remove a anterior e reenvia a pergunta).
- **Copiar** a resposta para a área de transferência.

### Testes novos

- `test/conversa_store_test.dart` — 6 casos (título, ordem com fixadas, apagar, fixar,
  rascunho, lista corrompida).
- `test/historico_test.dart` — 3 testes de widget (vazio, busca, sem resultado).
- `test/voz_tela_cheia_test.dart` — estado neutro e controles.
- `tool/conversa_test.dart` — título, JSON, lixo e fixação (Dart puro).
- `tests/test_flutter_ui.py` — roda `flutter analyze` e `flutter test` na suíte local quando
  há Flutter; sem Flutter, avisa e não reprova.

## Verificação

```
flutter analyze   → No issues found!
flutter test      → 36 testes, All tests passed!
npm run verificar → 4 de 4 etapas, 2.368 verificações OK
```

## Limites

- Nada foi medido em aparelho: fps, jank, inicialização e comportamento do KWS em tela cheia
  continuam sem número.
- A integração com o sistema (atalhos do ícone, widget, painel rápido, compartilhar) depende de
  Kotlin e de aparelho; não foi feita.
- O modo voz usa o estado do controlador existente; falar e ouvir de verdade só no aparelho.
- `material_ui` exige Flutter 3.47+; o CI usa `stable`, mas uma máquina com Flutter antigo não
  compila mais esta interface.
