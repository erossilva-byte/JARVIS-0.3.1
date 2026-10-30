# Registro da 1.31.0 — planos supervisionados

## O que mudou

| Arquivo | Mudança |
| --- | --- |
| `plano.js` (novo) | Normalização, limite de seis etapas, recusa de ação inválida/recursiva e execução com recibos. |
| `app.js` | `planejarComIA`, `iniciarPlano`, comandos de plano e integração com `executarSeguro`; versão 1.31.0. |
| `index.html` | Carrega `plano.js` antes do app; rótulos v1.31.0. |
| `tests/test_plano.js` (novo) | Executor e confirmações injetados: sucesso, incerteza, pausa, falha, cancelamento e privacidade do resumo. |
| `tests/test_plano_integracao.py` (novo) | Contrato estático do comando, confirmação, recibo e carregamento do módulo. |
| `package.json` / `package-lock.json` | Versão 1.31.0, validação, suíte e empacotamento. |
| Workflows | `plano.js` no gatilho e na cópia para `www/`. |
| `CHANGELOG.md`, `LEIA-ME.md`, `VERSAO.json` | Registro da versão. |

## Funcionalidades preservadas

- Hermes, habilidades, rotinas e comandos locais.
- `ACOES`, riscos, confirmação, PIN, modo seguro e modo offline.
- Agentes e recibos da 1.30.0.
- Personalidade/humor, VAD, identificação de pessoas, memória, visão, voz neural, IA local e PC/Windows.
- Painéis, navegação, tarefas, arquivos e segundo plano Android.

## Limitações honestas

- O plano é gerado pela IA configurada; sem provedor ou modelo local não há plano. O app não inventa etapas.
- Não há retomada após reinício do processo nesta fase; o supervisor pausa e informa, mas o checkpoint persistente fica para a próxima etapa.
- O efeito real de ações nativas continua dependendo do adaptador Android. Etapas sem confirmação permanecem `incerto`.
- Sem aparelho Android, microfone, câmera ou Windows, os testes são de motor puro e contrato estático, não de campo.
