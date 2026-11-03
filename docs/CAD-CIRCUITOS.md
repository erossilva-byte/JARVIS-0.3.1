# Circuitos elétricos no `.cad` — 1.42.4

> O `.cad` continua sendo o documento do CadSimu (corpo 3D em primitivas). A partir da 1.42.2
> ele aceita uma seção **opcional** `circuito`, com componentes e ligações por terminal, que é
> validada no aparelho e exportada como **netlist** para o PC. Nada de executar SPICE no celular:
> o celular monta, valida e prepara; a simulação de verdade roda no computador.

## Estrutura

```json
{
  "formato": "CadSimu CAD",
  "versao": 1,
  "nome": "pisca-led",
  "unidades": "mm",
  "objetos": [
    { "tipo": "caixa", "nome": "base", "posicao": [0, 0, 0], "dimensoes": [80, 50, 3] }
  ],
  "circuito": {
    "componentes": [
      { "id": "V1",  "tipo": "fonte",     "valor": 9 },
      { "id": "R1",  "tipo": "resistor",  "valor": 330 },
      { "id": "LED1","tipo": "led",       "valor": 2 },
      { "id": "G1",  "tipo": "terra" }
    ],
    "conexoes": [
      { "de": "V1.1",  "para": "R1.1" },
      { "de": "R1.2",  "para": "LED1.1" },
      { "de": "LED1.2","para": "G1.1" },
      { "de": "V1.2",  "para": "G1.1" }
    ]
  }
}
```

Cada conexão também aceita o formato curto `["V1.1", "R1.1"]`.

## Componentes aceitos

| tipo | terminais | valor |
| --- | --- | --- |
| `resistor` | 2 | Ω (obrigatório) |
| `capacitor` | 2 | F |
| `indutor` | 2 | H |
| `fonte` | 2 | V (obrigatório) |
| `led` | 2 | V |
| `diodo` | 2 | V |
| `chave` | 2 | — |
| `terra` | 1 | — |
| `carga` | 2 | Ω |
| `motor` | 2 | V |
| `fusivel` | 2 | A |

`id` começa com letra, até 24 caracteres (`R1`, `LED2`, `V_BAT`). Limites: **200 componentes** e
**400 conexões**.

## O que a validação recusa (erro) e o que só avisa

**Erro** (o arquivo é recusado com o motivo):

- componente com tipo desconhecido, `id` inválido ou repetido;
- conexão com componente/terminal inexistente, ou terminal ligado nele mesmo;
- `valor` não numérico ou negativo;
- **fonte em curto** (os dois terminais na mesma rede);
- mais componentes/conexões que o limite.

**Aviso** (o arquivo abre, mas o circuito pede atenção):

- componente **solto** (nenhum terminal ligado);
- **LED sem resistor** em série;
- **circuito sem fonte**;
- conexão repetida;
- resistor/fonte sem `valor`.

## Netlist

`CAD.netlist(doc)` devolve texto no formato de netlist (SPICE-like):

```
* J.A.R.V.I.S. Nova — netlist do circuito
* componentes: 4 · conexões: 4
V1 1 0 9
R1 1 2 330
D1 2 0 2
.end
```

Terra vira a rede `0`; a numeração das demais redes é derivada das conexões. Componentes sem
valor aparecem sem o campo. A netlist é gerada **depois** da validação e não substitui a
simulação: quem calcula tensão/corrente é o simulador do PC.

## Onde isso aparece no aplicativo

Em **Arquivos ▸ Montar circuito** o circuito é editado num **palco**:

- escolha o tipo, informe id e valor e toque em **Adicionar componente** — o símbolo aparece no palco;
- **toque num terminal** (fica destacado) e **no outro** para criar a ligação; toque de novo no mesmo
  terminal para cancelar. **Terminal A**/**Terminal B** + **Ligar terminais** continuam disponíveis;
- **arraste** o componente para mover; a posição `x`/`y` é salva;
- toque no componente para selecionar: **Aplicar edição** renomeia (ajustando as ligações) e troca o
  valor; **Apagar selecionado** remove o componente e as ligações dele;
- **Carregar .cad salvo** devolve o circuito mais recente do cofre para edição;
- **Validar**, **Gerar netlist** e **Salvar .cad do circuito** (placa de 120×80×2 mm como geometria)
  seguem iguais.

Ao analisar um `.cad` com `circuito`, o cartão de análise mostra quantos componentes, conexões e
redes existem, além dos erros/avisos — o mesmo resumo volta em `CAD.analisar(texto).resumo`.
O arquivo continua listável, baixável e apagável como qualquer `.cad`.

Regressões: `tests/test_cad_circuito.js` (15 verificações do formato) e
`tests/test_cad_circuito_ui.js` (app inteiro no jsdom: desenha 4 símbolos/4 fios, edita valor, arrasta, salva, apaga e recarrega) e `tests/test_cad_posicao.js` (x/y opcional e preservado).

## Limites honestos

- O editor é de palco simples: sem zonas, roteamento automático de fios, seleção múltipla nem desfazer/refazer além de remover a última ligação.
- Não há simulação elétrica no aparelho — só validação estrutural e netlist.
- Compatibilidade: arquivos sem `circuito` seguem válidos; a seção é opcional.
