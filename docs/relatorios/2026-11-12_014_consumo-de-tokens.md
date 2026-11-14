# Ajuste 014 — Consumo de tokens por provedor (Fase 3)

Data: 2026-11-12
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 3 pede e o que faltava

A Fase 3 do prompt exige, na central de provedores: "inserir, testar, editar e remover
chaves; escolher provedor e modelo principal e alternativos; failover automático; **exibir
erros, limites, consumo e informações de conexão quando a API fornecer**".

Auditoria do código: erro e limite aparecem (`MOTIVO_FALHA`, `pausar`, mensagens de 401/429),
o failover e o roteador do Hermes existem, e o modelo alternativo é escolhido. **Consumo não
existia**: os dois caminhos de resposta liam o JSON do provedor e o campo `usage` era
descartado. O usuário não tinha como ver quantos tokens gastou nem com qual provedor.

## O que foi feito

- **`consumo_ia.js`** — módulo puro, sem rede e sem tela, com a conta:
  - `lerUso(usage)` aceita `prompt_tokens`/`completion_tokens`/`total_tokens` e também
    `input_tokens`/`output_tokens`; calcula o total quando só as partes vierem;
  - devolve `null` quando não há número legível — **nunca devolve zero inventado**;
  - `somar(estado, id, uso)` devolve estado novo (não altera o recebido) e conta a chamada
    mesmo quando o consumo não veio;
  - `resumo`/`linhas` escrevem a frase em português e dizem quantas chamadas ficaram sem
    consumo informado.
- **`app.js`** — o consumo passou a ser registrado nos dois caminhos (resposta normal e
  streaming), somado por provedor e guardado em `jv_consumo_ia`, sobrevivendo ao fechamento
  do app. Aparece em **Ajustes ▸ IA** (campo `#c-consumo-ia`, atualizado ao abrir e a cada
  resposta) e no **diagnóstico**, como linha "Consumo de IA (tokens)".
- **Streaming** — o pedido agora inclui `stream_options: { include_usage: true }` (padrão
  OpenAI). Provedor que recusa esse campo responde 400 e é **marcado e repetido sem o campo**,
  em vez de perder o streaming por causa de um opcional.
- **Interface** — o lugar do texto existe em Ajustes, com explicação de que provedor que não
  informa aparece como tal.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_consumo_ia.js` | **exit 0, 23 verificações** |
| `npm run test:all` | **exit 0, 2.353 verificações** (o teste novo roda dentro da suíte) |
| `python3 tests/test_empacotamento.py` | exit 0 — `consumo_ia.js` entra no workflow Android e no pacote Windows |
| Tela real, Ajustes ▸ IA | campo visível; ao abrir, mostra "Nenhuma chamada de IA registrada ainda…" |
| Módulo na tela real | `typeof window.ConsumoIA === 'object'` |
| Frase com dados | "Groq: 2 chamada(s), 1.515 tokens informados (1.200 de entrada, 300 de saída)." |
| Frase sem dados | "Mistral: 1 chamada(s); o provedor não informou o consumo." |

O teste cobre o comportamento do módulo com dados que os provedores realmente devolvem
(inclusive `total_tokens` como texto, valores negativos, ausência de `usage`, formato
entrada/saída) e verifica que o app está ligado ao módulo nos dois caminhos — sem a ligação,
a conta não chegaria à tela.

## O que não foi verificado

- **Sem chave real de provedor**, nenhuma chamada de verdade foi feita: a contagem aparece
  com respostas simuladas. O caminho de rede (incluindo o recuo do `stream_options`) está
  coberto por leitura de código e teste estático, não por tráfego real.
- Nada foi rodado em aparelho físico (Gate B continua não feito).
- Limites e cotas continuam sendo os que a API informa no erro; o app não estima cota
  restante, porque os provedores não devolvem esse número de forma padronizada.
