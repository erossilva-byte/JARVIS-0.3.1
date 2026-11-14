# Ajuste 015 — Escolher motor principal e alternativo

Data: 2026-11-12
Branch: `work/1.48.0-fase2-consolidacao`

## O que faltava

A Fase 3 do prompt pede "escolher provedor e modelo principal e alternativos". O app tinha
só a escolha automática: o roteador do Hermes decidia a fila por tarefa, latência medida e
falhas recentes, e o usuário não podia dizer "quero o Cerebras primeiro". Quem tinha chave de
vários provedores ficava refém da nota do roteador.

## O que foi feito

- **`hermes.js` (roteador)** — `planejarIA` passou a aceitar `principal` e `alternativo`.
  A fila final é: principal → alternativo → ordem do roteador. Regras aplicadas no próprio
  roteador, não na tela:
  - provedor escolhido **sem chave** não entra (não está entre os elegíveis);
  - escolher o mesmo provedor nos dois campos **não duplica** a fila;
  - o principal **continua sendo a escolha do usuário mesmo em pausa** por falha recente
    (quem decidiu foi ele), com a reserva logo atrás;
  - em tarefa de visão a escolha vale apenas entre os que reconhecem imagens;
  - o motivo registrado no log passa a citar a preferência.
- **`app.js`** — passa `prov_principal` e `prov_alternativo` ao roteador em cada pergunta;
  monta os seletores ao abrir Ajustes; ao salvar, valida os ids, grava e **libera a pausa**
  do provedor escolhido (insistir na pausa seria ignorar a decisão do usuário). O registro
  guarda `motor preferido: x / y`.
- **`index.html`** — dois seletores em Ajustes ▸ IA ("Motor principal" e "Motor
  alternativo"), com a opção "Automático (roteador Hermes)" e marcação "· sem chave" em
  quem ainda não tem chave, mais uma explicação do comportamento.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_hermes.js` | exit 0, **28 verificações** (8 novas) |
| `npm run test:all` | **exit 0, 2.361 verificações** |
| Roteador, medido por script | automático `groq > cerebras`; com escolha `cerebras > groq`; motivo cita "preferência do usuário: Cerebras" |
| Provedor sem chave | escolha ignorada, fila idêntica à automática |
| Mesmo id nos dois campos | `groq > cerebras`, sem repetição |
| Tela real | seletores visíveis, 6 opções cada (Automático + 5 provedores, todos marcados "sem chave" neste ambiente) |
| Gravação pela tela | `Salvar alterações` gravou `jv_prov_principal=cerebras` e `jv_prov_alternativo=groq` |
| Reabertura | valores voltaram nos dois seletores |

Os testes do Hermes cobrem o comportamento da fila (ordem, sem chave, repetição, visão,
pausa e ausência de escolha), não a aparência. A verificação de tela foi feita por execução
no navegador, com leitura do armazenamento depois de clicar em "Salvar alterações".

## O que não foi verificado

- **Sem chave real**, nenhuma resposta de provedor foi obtida: a ordem da fila foi verificada
  no roteador e na tela, não em tráfego de rede.
- Nada em aparelho físico (Gate B continua não feito).
- A escolha não cria um "modelo alternativo" por provedor: ela ordena provedores. Modelo
  alternativo por provedor continua sendo o que o roteador já fazia (`modeloRaciocinio`,
  `modelosVisao` e a lista de reserva de cada provedor).
