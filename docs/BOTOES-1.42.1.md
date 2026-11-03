# Botões e erros impactantes — 1.42.1

> Versão: 1.42.1 (versionCode 10421). Este documento registra o que foi auditado, o que foi
> corrigido, o que foi classificado como comportamento correto e o que continua sem validação
> física. Não há alegação de 100% de precisão nem de "todos os botões testados em aparelho".

## Objetivo da rodada

Encontrar, com clique real e não só leitura de código, botões que não fazem nada, erros de
integração entre HTML e JavaScript, e falhas silenciosas em handlers.

## Método

1. **Auditoria estática** (`python3` sobre `index.html`/`app.js`/`interface.js`):
   - todo `$('#id')` de `app.js` existe no HTML;
   - nenhum `id` duplicado (636 ids);
   - nenhum `label for` apontando para id inexistente;
   - nenhum `href="#"`, nenhum `onclick` inline e nenhum handler vazio;
   - nenhuma `<form>` (logo, nenhum botão sem `type` pode recarregar a página).
2. **Mapa de navegação**: as 24 ações declaradas em `interface.js` têm caso em `acaoNavegacao`;
   os dois `data-area-acao` do HTML (`config-ia`, `config-voz`) também.
3. **Auditoria de efeito com clique real** (jsdom, `artifacts/audit_buttons_effect.js`, fora do
   repositório): sobe o app inteiro, espera o boot estabilizar e compara `body.innerHTML` +
   atributos do `<body>` + `localStorage` antes/depois de cada clique.
   - 300 botões encontrados; **239 medidos** depois de abrir cada painel da barra lateral, cada
     aba de Ajustes e cada cartão de Áreas (rodadas até não medir mais nada);
   - botões ocultos/desabilitados foram separados dos medidos (61 no fim), porque não são
     alcançáveis pelo usuário e pertencem a estados reais (tela de abertura, editor sem seleção,
     painel PC sem Electron, tela de PIN, modelo local carregado);
   - **0 exceções de clique** e **0 erros globais de boot**. Os dois avisos restantes
     (`URL.createObjectURL` e `HTMLMediaElement.prototype.pause`) são funções que o jsdom não
     implementa; existem no Chrome/WebView/Electron.

## Resultado: 15 cliques sem efeito, todos classificados

| Botão | Classificação |
| --- | --- |
| `#btn-anexo`, `#dev-escolher`, `#obs-importar-btn`, `#idp-importar`, `#visao-escolher-imagem`, `#visao-escolher-video` | Abrem seletor/câmera do sistema (`input.click()`); o jsdom não abre seletor. Correto. |
| `.config-tab.ativo`, `#tarefas-filtro-todas`, `#c-atualizar-celular`, `#core-atualizar`, `#c-bg-sobreposicao`, `#sis-acess-parar` | Ação idempotente: o valor já estava aplicado (aba já ativa, filtro já "todas", status já preenchido, re-render sem mudança). Correto. |
| `#dash-visao` | O painel de Visão já estava aberto pelo botão anterior. Correto. |
| `#btn-enviar` | Campo vazio: não há o que enviar, por desenho. Correto. |
| `#upd-abrir-release` | `window.open` no navegador; o jsdom substitui por um stub. Correto. |

## Falhas reais corrigidas

1. **`#c-neural-liberar` ("Liberar memória", Ajustes ▸ Voz)** — `if (!p) return;` fazia o clique
   desaparecer quando o plugin `JarvisVoz` não existe (navegador/desktop), enquanto "Testar voz
   neural" e "Parar" já respondiam. Agora mostra "A voz neural está disponível apenas no
   aplicativo Android; não há memória para liberar."
2. **Microfone do núcleo (`#btn-mic`)** — sem `AudioContext`/`MediaRecorder` o app voltava a
   `idle` sem nenhuma mensagem (o estado `listening` durava microssegundos). Agora a falha vira
   mensagem: "Não consegui abrir o microfone neste ambiente. Verifique a permissão ou use o
   aplicativo Android para falar comigo." O caminho de cancelamento (`abortar`) continua mudo,
   como deve.

## Regressão

- `tests/test_botoes_honestos.js` (dentro de `npm run test:all`):
  - executa o handler do botão neural em três cenários — sem plugin (mensagem de
    indisponibilidade), com plugin (libera e confirma) e plugin com erro (mensagem de falha);
  - sobe o app inteiro no jsdom e clica no microfone, exigindo mensagem visível em vez de
    clique mudo.
- `npm run test:all`: **EXIT 0**, 2.088 `OK`, 0 falhas (log desta rodada em
  `artifacts/test-all-1.42.1.log`, fora do repositório).

## Limites desta rodada

- Sem aparelho físico: microfone real, wake word, toque real, serviço em primeiro plano, bateria
  e desempenho no Poco X7 continuam sem validação.
- Sem chaves/rede: STT (Groq/Gemini) e IA não foram exercitados acusticamente.
- Sem Windows/Electron aberto: o painel PC (`pcx-*`) fica oculto fora do Electron e foi validado
  apenas pelos testes de contrato (`test_pc_*.js`, `test_pc_windows.py`).
- A auditoria de efeito é um instrumento de diagnóstico; ela prova efeito no DOM, não correção
  de negócio em cada fluxo.

## Build 1.42.1

- Build: GitHub Actions (`release-apk.yml`), tag `v1.42.1`.
- O checksum e o tamanho deste APK são registrados em `VERSAO.json` e no `LEIA-ME.md` depois que
  o run publica o asset; até lá o campo `build.resultado` fica `pendente`.
