# Relatório 058 — formato `.cad` do CADeSIMU (2026-11-15)

## 1. O que foi feito

Antes de implementar a Fase 10, o formato nativo foi sondado com arquivos reais. O resultado
desmonta a classificação anterior de “inviável por falta de especificação”: o `.cad` é texto
legível e há engenharia reversa pública suficiente para ler sem perda. O que continua faltando é a
tabela completa de pinos por símbolo para reconstruir a netlist elétrica.

Nada no app foi alterado para importar ou exportar `.cad`. O que entrou no repositório é uma
sonda reproduzível, um teste e a documentação da decisão.

## 2. Arquivos usados

Baixados apenas para a análise, fora do repositório:

| Arquivo | Bytes | SHA-256 |
|---|---:|---|
| `cadesimu-motor_arranque-indirecto.cad` | 3.958 | `f7101cb5e1e674745608de763e21c788ea9eb8bb1e31479218b346911d3a312b` |
| `cadesimu-inversor-giro.cad` | 6.777 | `7077c67b867c0dd47ff49c978471381749311e226a512bada0cd9e58c4146522` |
| `mezcladora.cad` | 9.533 | `4af345283d9329047824d3ec41561dcd1046c8c56b93f476e223f3ebc45ecbf3` |

Os dois primeiros são circuitos elétricos (partida indireta e inversão de giro); o terceiro é um
arquivo de ladder/CLP, incluído para testar tipos diferentes, índices repetidos e texto.

## 3. Resultado da sonda

```
$ python3 tools/cadesimu_sonda.py /tmp/cadesimu/*.cad
cadesimu-motor_arranque-indirecto.cad: 3958 bytes, 50 registros
  símbolos=15 fios=30 junções=5 textos=0
  redes geométricas=20 rodapé=sim
  round-trip byte a byte: OK · sha256=f7101cb5e1e67474…
cadesimu-inversor-giro.cad: 6777 bytes, 89 registros
  símbolos=19 fios=55 junções=13 textos=2
  redes geométricas=23 rodapé=sim
  round-trip byte a byte: OK · sha256=7077c67b867c0dd4…
mezcladora.cad: 9533 bytes, 116 registros
  símbolos=95 fios=0 junções=0 textos=12
  redes geométricas=0 rodapé=sim
  round-trip byte a byte: OK · sha256=4af345283d932904…
```

O teste de ida e volta compara a string reescrita com o texto original, não só a contagem de
registros. Os três arquivos passaram.

## 4. O que o formato revelou

- Texto ISO-8859-1, sem terminadores de linha.
- Cabeçalho `CADe_SIMU*0*` e primeiro registro com índice implícito 0.
- Registros seguintes em `#*índice*tipo#rótulos*campos`.
- Tipo `8` é texto livre, sem separador `#` antes do próximo registro.
- Rodapé `#$$$` com data, nome e flags.
- Índices podem se repetir: no arquivo de ladder, quatro objetos usaram o mesmo índice.
- Campos de posição `x`, `y`, `x2`, `y2` são inteiros de grade; a caixa do símbolo vem depois.
- Junções `4001` no meio de um segmento formam T; cruzamento sem `4001` não conecta.
- As redes gravadas não são a verdade da simulação: a engenharia reversa do executável mostra que
  “Simular” as zera e recalcula por geometria. Isso foi tratado como evidência de terceiros, não
  como teste nosso.

## 5. Limite que decide o escopo

Nos circuitos elétricos, 14/15 e 19/19 símbolos têm um extremo de fio na origem. Mas um contator
amostrado tem extremos em quatro pontos e oito rótulos de terminal; a origem é **um** pino, não
todos. Sem a posição de cada pino por classe, orientação e tamanho, uma netlist elétrica
reconstruída seria adivinhação.

Por isso:

- **importar** como leitura fiel, inventário, geometria e anotações: viável;
- **importar** com netlist elétrica completa: não prometido;
- **exportar** `.cad` a partir do projetista: não prometido sem tabela de pinos e abertura no
  CADeSIMU oficial.

## 6. O que mudou no repositório

- `tools/cadesimu_sonda.py` — leitor/escritor lossless e resumo, sem dependências.
- `tests/test_cadesimu_sonda.py` — 6 grupos: ida e volta, geometria, texto, resumo, latin-1 e
  recusa de arquivo malformado.
- `docs/FASE-10-ESTUDO.md` — estudo, decisão e gate.
- `docs/CADESIMU-PONTE.md` — corrigida a afirmação de que o formato não tem especificação pública;
  agora separa “sem especificação oficial” de “ilegível”.
- `docs/INVENTARIO_DE_FUNCOES.md`, `docs/PROJETISTA-ELETRICO.md` e `docs/ESTADO-FASE-2.md` —
  estado atualizado.

## 7. Verificação

```
python3 tests/test_cadesimu_sonda.py  → 6 grupos, exit 0
python3 tools/cadesimu_sonda.py ...    → 3 arquivos, round-trip OK
npm run verificar                     → 4 de 4 etapas
```

## 8. O que continua sem prova

- **O CADeSIMU não foi aberto** nesta máquina: não há Windows, Wine nem o programa instalado.
- **Nenhum `.cad` gerado por nós foi aberto** no programa; a sonda só leu e reescreveu arquivos
  existentes.
- **CADeSIMU 5.0 não foi testado**; as amostras e as notas miram a versão 4.0.
- **Netlist elétrica completa e simulação** continuam fora do escopo desta etapa.
- A especificação é **engenharia reversa**, não documentação do fabricante; pode mudar entre
  versões.
