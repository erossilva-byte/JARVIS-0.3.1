# Projetista elétrico — o que ele faz, o que ele verifica e o que ele não faz

O **Projetista elétrico** fica no painel **Arquivos ▸ Projetista elétrico**. Você descreve o
circuito em português e o aplicativo monta o projeto por **regras determinísticas** — sem IA no
meio, sem sorteio: o mesmo pedido gera sempre o mesmo projeto, e cada regra aplicada pode ser
apontada na saída.

## Como usar

1. Escreva o pedido (ou use o exemplo que já vem no campo).
2. **Criar circuito**: o projeto é montado e verificado.
3. **Analisar** revalida; **Corrigir erros** aplica as correções estruturais que o motor conhece.
4. **Relatório técnico** gera o texto completo; **Ladder do CLP** gera a lista de lógica (se o
   projeto tiver CLP).
5. **Salvar projeto** guarda no aparelho, na lista abaixo do botão (Abrir / Apagar).

A vista de projeto desenha cada componente como um cartão com seus pinos e a rede (fio) de cada
pino; as linhas tracejadas são os fios. Componente com erro aparece destacado.

## Pelo chat e pela voz

O mesmo motor responde no turno do Jarvis, antes da IA: "projetista: crie uma partida direta para
motor trifásico de 5 CV", "converta para reversão", "remova H1", "analise o projeto", "corrija",
"relatório", "ladder". A resposta é falada, o painel Arquivos abre e a saída técnica fica no
painel. Perguntas comuns não são capturadas (é preciso verbo de projeto + termo elétrico, ou o
prefixo "projetista"). A fala reconhecida usa o mesmo caminho do texto.

## Símbolos e edição de pinos

A vista desenha símbolo por tipo (contator com bobina e contatos, térmico, motor 3~, disjuntor,
botoeira, temporizador, transformador, autotransformador, sensor, CLP, sinaleiro, fusível, fonte,
interruptor), com o pino e a rede de cada terminal. **Tocar num pino** preenche "Pino" e "Rede";
digitar outra rede e tocar em **Ligar pino à rede** regrava aquela ligação e revalida na hora —
se criar curto ou deixar terminal solto, a verificação aponta. **Desfazer ligação** volta a última
alteração de pino (até 10).

## Editar projeto existente, versões e comparação

Depois de criar (ou abrir) um projeto, o campo **Modificação do projeto** aceita pedidos como:

| Pedido de modificação | O que o motor faz |
| --- | --- |
| "adicionar temporizador de 10 segundos" | insere `KT` comandado pela bobina do contator principal e um sinaleiro que acende depois do tempo |
| "remover H1" | remove o componente, seus pinos e as ligações dele (e o tira de intertravamentos) |
| "adicionar proteção" | insere relé térmico no circuito de força da carga |
| "comando em 24 V" | reconstrói o comando na tensão pedida (bobinas, fonte e proteção) |
| "converter para reversão" / "estrela-triângulo" / "compensadora" / "partida direta" | reconstrói a topologia mantendo potência, tensões e emergência |
| qualquer outra coisa | recusa com exemplos do que entende |

O projeto **original não é alterado**: a modificação trabalha sobre uma cópia e a saída mostra a
**comparação** (componentes adicionados, removidos, alterados e redes novas/removidas). Isso é
diferença de estrutura — não é simulação elétrica.

**Versões**: cada gravação guarda a anterior (até 5). O botão **Versões** lista o histórico do
último projeto salvo e oferece **Restaurar**; restaurar grava a versão escolhida como versão nova,
mantendo a atual no histórico — nada é perdido. **Comparar** usa o projeto de antes da modificação
(ou a última versão salva) como referência.

## Topologias reconhecidas pelo pedido

| Pedido (palavras-chave) | Topologia montada |
| --- | --- |
| "partida direta" | disjuntor, contator, relé térmico, motor, comando com selo, emergência e sinaleiro |
| "reversão" | dois contatores com duas fases trocadas, NF cruzado (intertravamento elétrico) e selos |
| "estrela-triângulo" | três contatores, temporizador, motor de 6 pontas, NF cruzado entre estrela e triângulo |
| "compensadora" | autotransformador com tap, contator de tap e de regime, temporizador, NF cruzado |
| "CLP" / "nível" | CLP 24 Vcc com boias, botoeira, contator da bomba, potência com disjuntor e térmico, ladder |
| "iluminação" / "lâmpada" | disjuntor bipolar, interruptor (ou sensor de presença) e lâmpada |
| "comando" / "liga-desliga" | fusível, fonte/transformador, liga, desliga, selo, emergência e sinaleiro |

O pedido também define: potência em CV, trifásico ou monofásico, tensão de potência (380/440/220 V),
tensão de comando (24 V quando citada, senão 220 V), tempo do temporizador e se há emergência e
sinalização. O que não vier no pedido é **assumido e declarado** em "Decisões" e "Pendências".

## Verificação (estrutural, não simulação)

Regras aplicadas sobre os pinos e as redes do projeto:

- **terminal solto** — pino obrigatório sem ligação;
- **curto** — dois terminais do mesmo componente (contato, bobina, polo) na mesma rede;
- **curto entre fases** — caminho fechado entre L1/L2/L3 (ignorando contatores intertravados, que
  não podem fechar juntos);
- **bobina sem alimentação** — A1 não alcança a energia do comando ou A2 não alcança o retorno;
- **falta de emergência** — bobina energizável sem passar pela botoeira de emergência;
- **falta de proteção** — motor/bomba sem relé térmico (ou disjuntor-motor) no caminho de força;
- **falta de intertravamento** — contator que pode ser energizado com o outro fechado, sem NF cruzado;
- **tensão de bobina** incompatível com a tensão de comando;
- **sem temporizador** em estrela-triângulo ou compensadora;
- **endereço de CLP** duplicado ou fora do formato `%I0.0` / `%Q0.0`;
- avisos para rede com um só ponto, saída de CLP sem carga declarada e afins.

O caminho é calculado por busca em largura sobre os fios e os contatos (contato NA/NF, botoeira,
fusível, disjuntor, térmico). Bobina, carga, fonte, transformador e CLP **não conduzem**: é assim
que "bobina sem alimentação" tem sentido.

### Níveis de verificação — declarados no relatório

| Nível | Situação |
| --- | --- |
| Estrutural (regras acima) | executado |
| Elétrica (tensão, corrente, transitórios) | **não executado** |
| Simulação funcional | **não executado** |
| Abertura no CADeSIMU | **não executado** |

## Correção automática

O motor corrige o que ele sabe corrigir e diz o que fez:

- insere o **NF cruzado** que falta, em série com a bobina;
- insere a **botoeira de emergência** na alimentação do comando;
- insere **relé térmico** no circuito de força da carga;
- ajusta a **tensão da bobina** para a tensão de comando.

Se sobrar erro que não é corrigível por regra, ele continua listado — a correção não "aprova" o
projeto escondendo o problema.

## Formato de arquivo

`ProjetistaEletrico CAD` v1, JSON, documentado no topo de `projetista.js`:

```json
{
  "formato": "ProjetistaEletrico CAD",
  "versao": 1,
  "titulo": "Partida direta de motor trifásico com comando em 220 V",
  "tipo": "partida_direta",
  "spec": { "cv": 5, "trifasico": true, "tensaoPotencia": 380, "tensaoComando": 220 },
  "redes": { "energia": ["L1", "L2", "L3", "R1C"], "retorno": ["N", "PE"], "fases": ["L1", "L2", "L3"] },
  "componentes": [
    { "id": "K1", "tipo": "contator", "funcao": "Contator principal", "tensao": 220,
      "x": 470, "y": 98, "pinos": { "A1": "K1A", "A2": "N", "1": "R1", "2": "S1" } }
  ],
  "sequencia": ["..."],
  "rungs": []
}
```

Cada pino aponta para o **nome da rede**; dois pinos com o mesmo nome estão no mesmo fio. O arquivo
é reaberto e revalidado ao carregar (`parse`), e versão futura é recusada.

## Limitações — sem rodeios

- **CADeSIMU**: o `.cad` nativo do CADe SIMU é proprietário e não tem especificação pública. Este
  módulo **não** gera esse arquivo, **não** abre esse arquivo e **não** foi testado no CADe SIMU.
  O que existe é o formato documentado acima, mais a netlist do painel "Montar circuito" para
  simuladores de PC.
- **Sem simulação elétrica**: não há cálculo de tensão, corrente, queda, curto real ou transitório.
- **Dimensionamento didático**: corrente estimada com fp 0,8 e rendimento 0,9; disjuntor/contator/
  térmico saem de uma série comercial. Projeto executivo exige cálculo normativo (NBR 5410) e
  catálogo do fabricante.
- **Intertravamento mecânico** é físico e não é representável no arquivo (aparece na sequência e
  no aviso).
- **Ladder** é entregue como lista de expressões verificáveis, não como arquivo nativo de CLP.
- Sem zonas, roteamento automático de fios, seleção múltipla ou desfazer geral na vista (há desfazer por pino, até 10).

## Testes

- `tests/test_projetista.js` — 84 verificações: interpretação dos seis pedidos da missão,
  projeto e aprovação das seis topologias, determinismo, relatório, ladder, arquivo, detecção de
  falta de intertravamento/emergência/proteção, tensão errada, endereço de CLP duplicado, curto,
  terminal solto, a correção de cada um, o histórico de versões com restauração e a modificação de projeto existente.
- `tests/test_projetista_ui.js` — app inteiro no jsdom: criar, desenhar (símbolos IEC, pinos e fios), editar pino com desfazer, responder pelo chat, analisar,
  corrigir sem inventar correção, relatório, ladder do CLP, salvar, reabrir e apagar.

## Arquivos

| Arquivo | Papel |
| --- | --- |
| `projetista.js` | motor: interpretação, projeto, verificação, correção, relatório, ladder e arquivo |
| `app.js` | bloco `projetistaEletricoUI`: interface no painel Arquivos |
| `index.html` | seção "Projetista elétrico" e carregamento do módulo |
| `style.css` | vista de projeto (cartões, pinos, fios, destaque de erro) |

## Correções da 1.44.0

Motores acima da série não são mais entregues com contator/disjuntor menor que a corrente: as
séries vão até 800 A e, acima disso, o pedido é recusado com o motivo. Iluminação não exige
emergência e a partida monofásica não deixa os polos 5/6 do térmico soltos.

## Ponte CADeSIMU (1.45.0)

O `.cad` nativo continua **não suportado**. O que existe agora é `conferirTrocaCadesimu` (checklist)
e `exportarTrocaCadesimu` (JSON de intercâmbio com símbolo IEC, terminais e netlist), além do comando
`projetista: cadesimu`. Detalhes em [CADESIMU-PONTE.md](CADESIMU-PONTE.md).

Reversão, estrela-triângulo, compensadora e sequência são recusadas para motor monofásico com o
código `topologia_trifasica`: essas topologias exigem três fases.
