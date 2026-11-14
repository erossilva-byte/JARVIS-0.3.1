# Ajuste 038 — Fase 5: porta de entrada da interface nativa (2026-11-14)

## Por que

A Fase 5 do prompt mestre é a interface Flutter/Dart, com um critério objetivo: **nenhuma
WebView ou tela web, verificado por busca automatizada no CI**. O projeto tinha o app Flutter
sem webview, mas nada impedia que isso voltasse, e a navegação não cobria duas das doze seções
pedidas.

## O que foi feito

### 1. Pré-checagem da interface

`ci/preflight_interface.py` verifica:

- `pubspec.yaml` sem `webview_flutter`, `flutter_inappwebview`, `flutter_webview_plugin`,
  `webviewx` ou `flutter_html`;
- nenhum arquivo Dart com `WebView`, `WebViewController`, `InAppWebView`, `loadUrl(`,
  `IFrameElement`, `platformViewRegistry`, `Html(` ou `dart:html`;
- gaveta com as doze seções da Fase 5 (IA, Voz, Memória, Visão, Pessoas, Arquivos, CADeSIMU,
  Tarefas, Celular, Segurança, Personalização, Configurações);
- `home_screen.dart` respeitando `disableAnimations`;
- `command_center.dart` com `RepaintBoundary` no núcleo animado.

Entrou como etapa própria do `npm run verificar` e no começo do `npm run test:all`, com teste
de empacotamento garantindo que o passo não seja removido.

### 2. Teste negativo da regra

`tests/test_preflight_interface.py` monta projetos falsos mínimos e prova que a pré-checagem
reprova: WebView no código, pacote de webview no `pubspec`, `Html(` embutido, gaveta ausente,
sem animação reduzida e sem `RepaintBoundary`. Também confirma que o repositório atual passa.

### 3. Navegação e animação

- Gaveta ganhou **Segurança** (para “Segurança e privacidade”) e **Personalização**; o
  catálogo ganhou o módulo `Personalização`, para a seção não abrir vazia.
- `home_screen.dart`: `didChangeDependencies` lê `MediaQuery.disableAnimations` e para o
  controlador do núcleo quando a preferência do sistema está ligada.
- `command_center.dart`: núcleo animado dentro de `RepaintBoundary`.

## Verificação

```
Resumo da verificação
  OK      Pré-checagem Android         0.1 s
  OK      Pré-checagem da interface    0.0 s
  OK      Suíte completa              27.7 s · 2365 verificações OK, 1 aviso(s)
  OK      Empacotamento                0.0 s

Tudo certo: 4 de 4 etapas.
```

- `python3 ci/preflight_interface.py` — 15 arquivos Dart, 12 seções, sem WebView.
- `python3 tests/test_preflight_interface.py` — reprova os seis defeitos plantados e aprova o
  repositório.

## Limites

Sem Flutter/Dart nesta máquina, as mudanças de interface não foram compiladas nem analisadas:
`flutter analyze` e o teste de widget continuam pendentes, e nenhuma medição de fps foi feita.
A pré-checagem é estrutural: ela impede regressão de arquitetura, não prova comportamento.

## Documento da fase

`docs/FASE-5-INTERFACE.md` — inventário, critérios, o que foi feito e a fila restante.
