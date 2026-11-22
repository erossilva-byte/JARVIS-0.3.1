# Ajuste 017 — Modo de desenvolvimento com autorização

Data: 2026-11-12
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 3 pede e o que faltava

O prompt pede um "modo de desenvolvimento avançado: analisar, corrigir, testar e evoluir o
próprio projeto **somente com a minha autorização**".

O app já tinha um painel "Dev. Arquivos" real: recebe arquivos e `.zip`, analisa estrutura,
JSON inválido, importações faltando, duplicatas, segredos e marcadores de conflito, corrige
(JSON, fim de linha, espaços, BOM) preservando o original, cria projeto e arquivo, e exporta.
Também já existia o sandbox JavaScript isolado para testar código.

O que **não** existia era a autorização. Qualquer instrução, inclusive vinda da IA, chegava ao
painel e alterava arquivos sem porta nenhuma. "Somente com a minha autorização" era uma
promessa, não uma regra do programa.

## O que foi feito

**`modo_dev.js` (novo, sem DOM e sem rede)**

- Duas classes de operação: **leitura** (`analisar`, `testar`, `exportar`, `listar`) é sempre
  livre porque não altera nada; **escrita** (`corrigir`, `criar`, `editar`, `aplicar`,
  `projeto`) exige autorização ativa e dentro do prazo.
- Operação desconhecida é **negada**: nada é liberado por engano.
- Autorização com prazo: padrão 30 minutos, mínimo 5, máximo 240; expira sozinha.
- `verificar()` decide **e** registra; a negativa também entra no histórico, com hora,
  operação, se foi permitida e o motivo. Histórico limitado a 40 entradas.
- `ehCodigoDoProjeto()` reconhece os arquivos do próprio aplicativo (`app.js`, `index.html`,
  `hermes.js`, `agentes.js`, `package.json`, `nucleo_v3.*`, `consumo_ia.js`, `modo_dev.js` e
  `tests/test_*.js`). É conservador de propósito: pedir autorização a mais é melhor que editar
  o produto sem ninguém saber.
- Recebe loja e relógio de fora, para ser testado com tempo simulado em vez de espera real.

**`app.js`**

- Instância criada com a mesma loja do app, então a autorização sobrevive a recarregar.
- Porta única `devAutorizado(operacao, detalhe)`: decide, registra e mostra o motivo na tela.
- `devCorrigir`, `devCriarProjeto` e `devCriarArquivo` agora começam por essa porta.
- Escrita de código do próprio app (`arquivo_editar`/`arquivo_criar` apontando para os
  arquivos acima) é bloqueada sem autorização, com frase explicando onde autorizar; a
  tentativa entra no log como `bloqueado`.
- `devRenderModo()` mostra na tela se o modo está ativo e quantos minutos restam.

**`index.html`**

- Seção "Autorização" no topo do painel de desenvolvimento: "Autorizar por 30 minutos",
  "Encerrar agora" e o estado atual. Autorizar pede confirmação explícita; recusar não altera
  nada.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_modo_dev.js` | exit 0, **17 verificações** |
| `npm run test:all` | **exit 0, 2.361 verificações** |
| `python3 tests/test_empacotamento.py` | exit 0 (workflow e pacote incluem o novo script) |
| Porta fechada por padrão | `corrigir` negado ao abrir; `analisar` liberado |
| Expiração | ativo aos 9 min de 10, negado aos 11 — com relógio simulado |
| Recusa registrada | histórico mostra `permitido: false` com motivo |
| Operação desconhecida | negada com `classe: desconhecida` |
| Código do app | `app.js`, `hermes.js`, `tests/test_agentes.js` reconhecidos; `notas.md`, `src/main.py` não |

## Conferência na tela (13/11, navegador real)

Fluxo completo executado no app aberto, não só em teste:

1. Painel "Dev. Arquivos" aberto: seção "Autorização" no topo, estado "desligado".
2. Arquivo JSON mal formatado adicionado (49 B, 2 linhas).
3. "Autorizar por 30 minutos" → modal de confirmação → confirmado. Estado mudou para
   "ATIVO por mais 30 minuto(s)", `jv_modo_dev` gravado com prazo de 30 minutos e o histórico
   recebeu `ligar · permitido`.
4. "Aplicar correção" com o modo ativo: arquivo passou a 74 B / 10 linhas, marcado
   **MODIFICADO** na lista, histórico `corrigir · permitido · modo ativo`.
5. "Encerrar agora": estado voltou a desligado e `jv_modo_dev` ficou vazio.
6. "Aplicar correção" de novo: **bloqueado** em vermelho — "modo de desenvolvimento desligado
   ou expirado", histórico `corrigir · permitido: false`.

**Defeito encontrado na tela e corrigido**: a análise automática feita ao fim da correção
sobrescrevia o aviso "1 arquivo(s) corrigido(s)". A mensagem agora é reescrita depois da
análise e o teste estático passou a cobrir isso (18 verificações no módulo).

## Conferência em telas pequenas (13/11)

Medido no navegador com viewport real de **360×740** e **320×700** (não simulacro de fonte):

| Medida | Antes | Depois |
|---|---|---|
| Selo do topo sobre o título | sim (sobreposição de retângulos) | não — desce para a própria linha |
| Largura do selo | estourava | 324 em 360 px · 284 em 320 px |
| Rótulo "Autorizar por 30 minutos" | duas linhas em botão de 158 px | uma linha, botão empilhado de 324/284 px |
| Botões de autorização | lado a lado, apertados | empilhados, 40 px de altura, largura cheia |
| Corte de texto (scroll > client) | — | nenhum nos botões, no estado e no título |
| Rolagem horizontal | nenhuma | nenhuma (scrollWidth = 360 e 320) |
| Botões abaixo de 30 px | nenhum | nenhum |
| Em 1024 px | lado a lado | continua lado a lado (252×40 cada) |

Correções aplicadas em `nucleo_v3.css` (regras ≤420 px e ≤340 px) e uma classe
`.botoes-autorizacao` no painel para empilhar os botões em tela estreita.

## O que não foi verificado

- Sem chave de provedor, a IA não pediu uma edição de código de verdade; esse bloqueio
  específico foi exercitado no módulo e conferido por teste estático no app.
- Nada em aparelho físico (Gate B continua não feito); a conferência foi no WebView/navegador.
