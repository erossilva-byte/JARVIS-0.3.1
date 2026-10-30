# Registro da 1.30.0 — agentes e recibos

## O que mudou

| Arquivo | Mudança |
| --- | --- |
| `agentes.js` (novo) | Nove agentes especializados e recibos de execução com classificação de efeito. |
| `app.js` | `executarSeguro` abre/fecha recibo em todos os caminhos e anexa `res.recibo`; diagnóstico ganhou a linha de recibos; versão 1.30.0. |
| `index.html` | Carrega `agentes.js` antes do app; rótulos v1.30.0. |
| `tests/test_agentes.js` (novo) | 30 verificações de mapeamento, classificação, privacidade, persistência e limite. |
| `package.json` / `package-lock.json` | Versão 1.30.0, validação e empacotamento do novo módulo. |
| Workflows | `agentes.js` no gatilho e na cópia para `www/`. |
| `CHANGELOG.md`, `LEIA-ME.md`, `VERSAO.json` | Registro da versão. |

## Funcionalidades preservadas

- Hermes e suas habilidades; rotinas; `ACOES` e níveis de risco; confirmação e PIN; modo seguro; modo offline.
- Personalidade e humor; captura de voz com VAD/pré-roll; identificação de pessoas; memória; visão; IA local.
- Painéis, navegação, tarefas, arquivos, PC/Windows e segundo plano Android.

## Como o recibo funciona

1. A ferramenta é aberta com `abrir(acao, args)`; só as chaves dos argumentos são guardadas.
2. O resultado real é classificado:
   - `ok`: `verificado`, `ok` ou `sucesso` explícitos;
   - `falhou`: erro/falha explícita ou texto de falha;
   - `bloqueado`: segurança, offline ou permissão;
   - `cancelado`: usuário recusou ou retorno nulo;
   - `incerto`: ação disparada sem confirmação de efeito.
3. O diagnóstico lê `resumo()` e mostra a taxa de verificação.

## Limitações honestas

- O recibo não transforma uma API de “abrir app” em confirmação de que o app abriu; nesses casos ele permanece `incerto`.
- Sem aparelho Android, os caminhos nativos não foram exercitados de ponta a ponta. Os testes usam resultados sintéticos e a suíte estática do projeto.
- Não há sincronização entre dispositivos, agentes autônomos em nuvem nem árvore de acessibilidade nesta fase.
