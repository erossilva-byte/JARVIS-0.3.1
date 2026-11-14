# Ajuste 016 — Delegação entre agentes com validação da cadeia

Data: 2026-11-12
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 3 pede e o que faltava

A Fase 3 exige "agentes especializados (programação, pesquisa, engenharia, eletrônica,
arquivos, visão, automação) com **delegação, colaboração e verificação de resultados**" e
"validação antes de declarar tarefa concluída".

O que existia: nove agentes (conversa, pesquisa, dispositivo, arquivos, memória, pessoas,
visão, computador, sistema), recibos com classificação de efeito (`classificar`) e um
supervisor de planos que pausa quando uma etapa fica incerta. O que **não** existia:

- **três especialidades do prompt**: programação, engenharia e eletrônica — ações de
  `sandbox_js`, `projetista_*` e `cadesimu_*` caíam todas em "Conversa";
- **nenhum registro de delegação**: o recibo dizia quem executou, nunca quem pediu nem em
  qual tarefa o passo entrou;
- **nenhuma validação da cadeia**: o plano verificava etapa por etapa, mas ninguém
  consolidava "todos os elos desta tarefa estão confirmados" antes de anunciar conclusão;
- **nenhuma visão por agente**: o resumo era global, sem mostrar quem fez o quê.

## O que foi feito

**`agentes.js`**

- Agentes `programacao`, `engenharia` e `eletronica`, com regras posicionadas antes das
  genéricas (`arquivos` casa "projeto" e "cad_", então precisava vir depois delas).
- Dois casos reais que caíam em "Conversa" foram corrigidos: `status_dispositivo` e
  `acessibilidade_*` agora vão para o agente Dispositivo.
- Recibo passou a guardar `de` (quem delegou), `para` (agente que recebeu) e `tarefa`.
- `abrirTarefa(objetivo, de)`, `recibosDaTarefa(id)`, `verificarTarefa(id)` e `porAgente()`.
- `verificarTarefa` só devolve `ok: true` com **pelo menos um recibo e todos confirmados**;
  elo aberto, incerto, falho, bloqueado ou cancelado vira pendência com agente, ação e motivo.

**`app.js`**

- `executarSeguro` passa o contexto de delegação a cada recibo (quem pediu e em qual tarefa).
- `iniciarPlano` abre a tarefa delegada antes da primeira etapa, alimenta a cadeia e, no fim,
  chama `verificarTarefa`. Se a validação reprovar, a fala muda: em vez de "Plano concluído",
  o Jarvis diz que a validação final reprovou, qual etapa, qual agente, qual estado e o motivo,
  e afirma que **não considera a tarefa concluída**. Quando passa, a fala cita os agentes que
  participaram.
- Diagnóstico ganhou a linha "Agentes especializados" com confirmadas/total por agente.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_agentes.js` | exit 0, **75 verificações** (45 novas) |
| `npm run test:all` | **exit 0, 2.361 verificações** |
| Mapeamento medido | `sandbox_js`→programacao, `projetista_ladder`→engenharia, `cadesimu_importar`→eletronica, `status_dispositivo`→dispositivo, `arquivo_editar`→arquivos |
| Cadeia com elo incerto | `ok: false`, `total: 2`, `confirmados: 1`, pendência com ação/agente/estado/motivo |
| Cadeia só com elos confirmados | `ok: true`, 2 de 2 confirmados |
| Cadeia com etapa cancelada | `ok: false`, pendência `cancelado` |
| Tarefa inexistente | `ok: false`, `total: 0` (não passa por omissão) |
| Recibo aberto | conta como pendência `aberto` antes de fechar |
| Recibo persistido | guarda `tarefa` depois de fechado e recarregado do armazenamento |

## O que não foi verificado

- **Plano ponta a ponta com IA real**: sem chave de provedor, não houve plano gerado de
  verdade; a validação foi exercitada no módulo de agentes e a ligação no app por teste
  estático (as quatro chamadas e a frase de reprovação).
- A linha de diagnóstico por agente não foi vista renderizada na tela; está coberta por
  teste estático e pelo comportamento do módulo.
- Nada em aparelho físico (Gate B continua não feito).
