# Fase 5 — Interface Flutter/Dart (em andamento)

**Começo:** 2026-11-14 · **Branch:** `work/1.48.0-fase2-consolidacao`

Esta fase segue a Seção 3D e a Fase 5 do prompt mestre: interface **100% nativa**, sem WebView,
com cara de app de assistente real e orçamento de desempenho. O documento registra o que já
existe, o que foi feito nesta rodada e o que falta — sem marcar como pronto o que não foi
medido.

## 1. Onde a interface está

| Item | Estado em 2026-11-14 |
|---|---|
| App Flutter | 15 arquivos Dart em `flutter_app/lib`, sem dependência de webview |
| Tela principal | `LegacyHomeScreen` com HUD, monitor, comandos rápidos e campo de conversa |
| Navegação | gaveta com 12 seções + barra inferior com 2 abas (Comando, Sistemas) |
| Núcleo animado | `HologramPainter` em `CustomPainter` (2D, desenhado como holograma) |
| Conversa | `VoiceConversationPage` + teste de que comando digitado não vira “captura de voz” |
| Provedores | tela de chaves com armazenamento seguro da plataforma |
| KWS | tela de ajustes e controlador com estados reais (escutando, indisponível, falha…) |
| Módulos | `ModulePage` declara explicitamente “integração em auditoria” |
| Interface web legada | `index.html`/`app.js` sob Capacitor — é o que a Fase 5 substitui |
| Núcleo de streaming | `lib/core/stream_buffer.dart` em Dart puro, com teste executável sem Flutter |

O app Flutter não carrega nenhum HTML: não há `webview_flutter`, `flutter_html`, `dart:html`
nem `WebView` no código. A interface web antiga continua no repositório como aplicativo
Capacitor até a paridade, e a regra de “sem WebView” vale para a interface nativa.

## 2. O que foi feito nesta rodada

### Verificação automática da Seção 3D

`ci/preflight_interface.py` entrou na suíte e no `npm run verificar` (etapa própria). Ele
reprova:

- pacote de webview ou HTML no `pubspec.yaml`;
- uso de `WebView`, `WebViewController`, `InAppWebView`, `loadUrl(`, `IFrameElement`,
  `platformViewRegistry`, `Html(` ou `dart:html` em qualquer arquivo Dart;
- gaveta sem alguma das doze seções da Fase 5;
- tela principal sem `disableAnimations` (animação reduzida);
- central de comando sem `RepaintBoundary` no núcleo animado.

Isso transforma o critério de aceitação “nenhuma WebView ou tela web (busca automatizada no
CI)” em barreira real, e não em promessa de documentação.

### Lacunas de navegação fechadas

A gaveta não oferecia **Segurança** nem **Personalização**, duas das doze seções pedidas.
Ambas entraram, e o catálogo ganhou o módulo `Personalização` para ser o destino real da
segunda — sem botão que não leva a lugar nenhum.

### Animação reduzida e isolamento do núcleo

- `home_screen.dart` passou a ler `MediaQuery.disableAnimations`: com a preferência do sistema
  ligada, o núcleo para de girar em vez de continuar consumindo quadros.
- `command_center.dart` isola o núcleo animado com `RepaintBoundary`, para o `CustomPaint` não
  repintar a lista inteira a cada quadro.

### Núcleo de streaming (agrupamento de tokens)

A Seção 3D exige atualizar a tela a cada 16–50 ms, não a cada token. `StreamBuffer` acumula os
fragmentos do provedor e entrega o texto completo no máximo uma vez por janela (32 ms por
padrão), com agendador injetável para o teste controlar o tempo.

`flutter_app/tool/stream_buffer_test.dart` cobre: vários tokens em uma atualização, respeito à
janela, entrega imediata ao concluir, limpeza e token tardio ignorado. Roda com
`dart run tool/stream_buffer_test.dart`, sem Flutter, e também pelo `npm run test:all` quando
há Dart instalado (`tests/test_dart_core.py`).

O buffer está ligado à tela de conversa (ajuste 040), junto com o parser SSE e o botão de parar.

## 3. Critérios da fase

| Critério (Seção 3D / Fase 5) | Estado | Evidência |
|---|---|---|
| Nenhuma WebView ou tela web | **Verificado** no app Flutter | `ci/preflight_interface.py` + teste negativo |
| Navegação com as 12 seções | **Verificado** | pré-checagem confere a gaveta |
| Modo de animação reduzida | **Implementado, não compilado** | `MediaQuery.disableAnimations` |
| `RepaintBoundary` no núcleo | **Implementado, não compilado** | `command_center.dart` |
| Conversa com streaming, parar, regenerar, fontes | Parcial: streaming e parar prontos; regenerar e fontes pendentes | `voice_conversation_page.dart` + testes puros |
| Atualização em janela de 16–50 ms | **Verificado no núcleo** | teste do `StreamBuffer` |
| Streaming cancelável na tela | **Implementado, não compilado** | `streamComplete` + botão parar |
| Histórico de conversas com busca e fixar | Pendente | — |
| Modo voz em tela cheia com legendas | Pendente | — |
| Estados de carregando/vazio/erro em toda tela | Pendente | hoje há aviso de auditoria |
| Persistência da conversa e rascunhos | Pendente | — |
| Integração com o sistema (atalhos, widget, compartilhar) | Pendente | — |
| Acessibilidade (TalkBack, fonte do sistema, contraste) | Parcial | usa Material 3 e textos escaláveis |
| Fluidez, inicialização e jank medidos no Poco X7 | Pendente | sem aparelho |

## 4. Fila sugerida

1. **Estados completos** nas telas existentes (carregando, vazio, erro com “tentar de novo”):
   é o que mais aparece na Seção 3D e não depende de serviço novo.
2. **Conversa de verdade**: ligar o `StreamBuffer` à tela, com parar geração, regenerar e
   citação das notas usadas. O agrupamento de tokens já está pronto e testado; falta a parte visual.
3. **Modo voz em tela cheia** com os cinco estados já definidos no serviço.
4. **Persistência** de conversa e rascunho após o processo ser morto.
5. **Integração com o sistema**: atalhos do ícone, compartilhar, notificação do serviço de voz.
6. **Medição** de inicialização, fps e jank no Poco X7 (Gate B), em modo profile.

## 5. Limites desta rodada

Sem Flutter/Dart instalados nesta máquina, nada foi compilado: `flutter analyze`, o teste de
widget e a medição de quadros continuam pendentes. A verificação possível foi estrutural —
pré-checagem nova, teste negativo dela e a suíte existente. As quatro mudanças de interface
são pequenas e de sintaxe direta, mas só o CI confirma.
