# Relatório — Fase 2, ajuste 004: matriz de capacidades do Flutter e indicadores honestos

## 1. Identificação

- **Projeto:** J.A.R.V.I.S. Nova · **Versão:** 1.46.0
- **Data:** 2026-11-11 · **Branch:** `work/1.48.0-fase2-consolidacao`
- **Ajuste:** 004 (item "matriz de capacidades" da Fase 2)
- **Plataformas afetadas:** app Flutter (Android e Windows), documentação

## 2. Resumo

Os 21 módulos do catálogo Flutter foram conferidos contra o código: **1 implementado, 3 parciais,
16 não migrados e 1 fora de escopo**. Três indicadores que afirmavam coisa que o código não fazia
foram corrigidos, e um bug real de layout (estouro de 68 px no cabeçalho da gaveta) apareceu no
caminho. O catálogo em si não foi inflado nem esvaziado: os 21 itens continuam visíveis, agora com
a página dizendo o que realmente existe.

## 3. O que foi feito

| # | Mudança | Arquivo | Tipo |
|---|---|---|---|
| 1 | Matriz dos 21 módulos com promessa, código real, evidência e estado | `docs/MATRIZ-CAPACIDADES-FLUTTER.md` | documentação |
| 2 | Gaveta: `SYSTEM STATUS`/`ONLINE` fixo → estado real do detector (`KWS ESCUTANDO`, `KWS PRONTO`, `KWS INDISPONÍVEL`, `KWS COM FALHA`, `KWS NÃO VERIFICADO`) | `flutter_app/lib/drawer.dart`, `home_screen.dart` | correção de indicador |
| 3 | Conversa: tarja "Comando capturado por voz" só quando a origem é o KWS; texto digitado mostra "Comando digitado" | `flutter_app/lib/services/voice_conversation_page.dart` | correção de indicador |
| 4 | Removida a `HomeScreen` morta (não era o `home:` do app) e seus widgets `_Heading`, `_Status` e `_Quick`, que traziam um segundo catálogo com `ATIVO`/`PENDENTE` | `flutter_app/lib/` | remoção de código morto |
| 5 | Cabeçalho da gaveta com `Expanded` e elipse (estourava 68 px) | `flutter_app/lib/drawer.dart` | correção de layout |
| 6 | `flutter_app/lib/main.dart` (669 linhas) separado em `catalog`, `ui_common`, `hologram`, `pages`, `provider_settings_page`, `command_center`, `systems_view`, `drawer`, `home_screen` | `flutter_app/lib/` | organização |
| 7 | Três testes novos cobrindo os dois indicadores e o estado da gaveta | `flutter_app/test/indicadores_test.dart` | teste |

## 4. Por que

O item da Fase 2 pede matriz de capacidades reais **e** remoção de indicador enganoso. A auditoria
mostrou que o problema não estava no catálogo (ele já avisava "Integração em auditoria" nos 19
módulos sem ponte), mas em três pontos de status que não mediam nada: o `ONLINE` verde da gaveta,
a tarja de voz aplicada a qualquer origem e a tela de status duplicada em código morto.

## 5. Evidência (executada neste ambiente)

```
flutter analyze                          -> No issues found! (8.8 s)
flutter test                             -> 26 testes, todos passando (23 anteriores + 3 novos)
```

O teste da gaveta reprovou na primeira execução por motivo legítimo — `RenderFlex overflowed by 68
pixels on the right` no cabeçalho da gaveta — e foi o que revelou o bug de layout corrigido no item 5.

## 6. Estado por módulo (resumo)

| Estado | Quantidade | Módulos |
|---|---|---|
| Implementado | 1 | Provedores de IA |
| Parcial | 3 | Voz e KWS, Avatar 3D (holograma 2D), Segurança e privacidade (só cofre de credenciais) |
| Não migrado | 16 | Hermes, Modelos locais, Agentes, Memória, Obsidian, Visão, Arquivos, Sandbox, CADeSIMU, Pessoas, Tarefas, Android, Pareamento, Windows, Backup, Atualizações |
| Fora de escopo | 1 | ESP32 e Home Assistant |

## 7. Não verificado

- **Nada foi executado em aparelho.** Os testes são de widget, com o plugin nativo ausente — o que
  prova o comportamento da interface, não a integração KWS real.
- O Android/Windows do app Flutter não foram compilados aqui; a verificação de build continua sendo
  o CI (`flutter-native.yml`), que roda `flutter build apk --debug` e `flutter build windows`.
- O `dart format` local usa o estilo novo do Dart 3.13 e reformataria os 11 arquivos; por isso não
  foi executado como parte do commit. O CI roda `dart format` sem checagem de saída, então o build
  não depende disso.

## 8. Próximos passos

1. Primeira execução do app Flutter em aparelho (Gate B), com o checklist da 3B.11.
2. Migrar o primeiro módulo da lista "não migrado" com paridade demonstrada, não por catálogo.
