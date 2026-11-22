# Fase 10 — o que o formato `.cad` do CADeSIMU permite (estudo)

**Data:** 2026-11-15 · **Status:** estudo concluído; nada do app foi alterado para ler ou gerar `.cad`.

## 1. A pergunta

A Fase 10 pede interoperabilidade com o CADeSIMU. Antes de escrever importador ou exportador, era
preciso responder com arquivos reais:

1. O `.cad` é texto ou binário?
2. Dá para ler sem perder dados?
3. Dá para reconstruir componentes, fios e redes elétricas?
4. Dá para gerar um arquivo que o CADeSIMU abra?

## 2. Resposta curta

O `.cad` **é texto** ISO-8859-1, sem quebras de linha. Não tem especificação oficial, mas há
engenharia reversa pública consistente e arquivos de exemplo. Nesta máquina:

- três arquivos públicos foram lidos e reescritos **byte a byte idênticos**;
- componentes, rótulos, posições, fios, junções e textos são extraíveis;
- a **netlist elétrica completa** ainda não é reconstruível com segurança, porque cada símbolo tem
  seus próprios deslocamentos de pino e a tabela pública cobre isso de forma parcial;
- **gerar** um `.cad` completo a partir do projetista não é um passo de serialização: exige
  biblioteca de símbolos, posições, orientação e roteamento de fios, e precisa ser aberto no
  CADeSIMU oficial como prova final.

Conclusão de escopo: **importação somente leitura é viável**; exportação fica condicionada a uma
tabela de pinos validada e a um teste no programa original.

## 3. O que o programa em si importa e exporta

O manual do CADeSIMU trata de arquivos `.CAD` para abrir/guardar o desenho. No menu de arquivo, a
importação e a exportação de imagem são **BMP**; não há DXF, PDF, XML ou JSON documentados. PDF é
impressão, não formato de intercâmbio. Isso separa duas coisas:

- **formato nativo** `.cad`: o desenho editável;
- **imagem**: BMP, apenas para ilustração.

O estudo não testou o CADeSIMU 5.0; as amostras e a engenharia reversa disponível miram a versão
4.0.

## 4. Estrutura observada

```
CADe_SIMU*0*<tipo>#<rótulo>#...#<campos>*...*<x>*<y>*...*<x2>*<y2>...
  #*<índice>*<tipo>#...          ← próximo registro
  ...
#$$$*...*<data>*...*<nome>...&&& ← rodapé
```

- O primeiro registro vem logo depois de `CADe_SIMU*0*` e tem índice implícito 0.
- Registros seguintes começam em `#*índice*tipo#`.
- O tipo `8` é texto livre e **não** tem `#` antes do próximo registro; o texto fica no fim do
  registro.
- O rodapé começa em `#$$$` e guarda data, nome do arquivo e flags.
- Os índices **não são únicos**: um arquivo de ladder repetiu o mesmo índice em quatro objetos.
  Quem importar não pode usar o índice como identidade.
- Campos desconhecidos foram preservados no teste de ida e volta; a sonda não os interpreta.

Tipos observados nas amostras elétricas: `1000` motor, `2001` contator tripolar, `3000/3001/3004`
alimentações/bornes, `4000` fio, `4001` junção, `4010` fio, `6003` fusível, `6007` térmico,
`6009` disjuntor, `6010` seccionador, `7000/7001` contatos auxiliares, `8000/8001` botões,
`8017/8018` contato do térmico, `9000` bobina, `9008` lâmpada. A amostra de ladder/CLP usa
`1..6` e `10100..10106`, que não são componentes elétricos de potência.

## 5. O que foi medido

Três arquivos públicos, baixados das URLs da seção 9. A sonda é independente, escrita a partir da
gramática observada; não é cópia de código de terceiros.

| Arquivo | Bytes | Registros | Símbolos | Fios | Junções | Textos | Redes geométricas | Ida e volta |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `cadesimu-motor_arranque-indirecto.cad` | 3.958 | 50 | 15 | 30 | 5 | 0 | 20 | byte a byte |
| `cadesimu-inversor-giro.cad` | 6.777 | 89 | 19 | 55 | 13 | 2 (`FUERZA`, `MANDO`) | 23 | byte a byte |
| `mezcladora.cad` (ladder/CLP) | 9.533 | 116 | 95 | 0 | 0 | 12 | 0 | byte a byte |

Nos dois arquivos elétricos, **14 de 15** e **19 de 19** símbolos têm ao menos um extremo de fio
exatamente na origem. Isso confirma que a geometria carrega conexão, mas não prova que a origem
seja o único pino: um contator da amostra tem extremos em `(0,0)`, `(6,0)`, `(0,12)` e `(6,12)`,
e ainda assim só quatro pontos foram vistos para oito rótulos de terminal.

As junções `4001` ficaram todas sobre o meio de um segmento, no caso T — o que bate com a
engenharia reversa: cruzamento sem junção não conecta.

## 6. Importar: o que dá e o que não dá

**Dá para entregar com segurança**

- leitura integral sem perda e reescrita idêntica;
- inventário de símbolos, rótulos, posições, caixas, orientação, fios e anotações;
- desenho da geometria (linhas, pontos, caixas) sem simular;
- grafo de fios por extremidades exatas + junções `4001`;
- preservação de campos desconhecidos ao editar apenas o que foi entendido.

**Não dá para prometer ainda**

- netlist elétrica completa: é preciso saber, para cada classe e orientação, onde ficam **todos**
  os pinos. A engenharia reversa pública avisa que o mapa de pinos ainda é ruidoso e que a
  biblioteca tem centenas de classes;
- semântica de todos os símbolos (contato, bobina, temporizador, CLP, pneumática);
- simulação equivalente: a própria engenharia reversa do executável concluiu que o “Simular” zera
  as redes gravadas e recalcula por geometria; reproduzir isso é um motor à parte;
- edição de um `.cad` real sem abrir o resultado no CADeSIMU: o teste de ida e volta prova
  preservação, não aceitação pelo programa.

## 7. Exportar: o que dá e o que não dá

**Dá** reescrever um arquivo existente preservando o que não foi tocado. **Dá** gerar um esqueleto
válido e circuitos de um subconjunto já mapeado — terceiros relatam partida direta e comando
abertos e simulados no CADeSIMU 4.0, mas isso é evidência deles, não nossa.

**Não dá** converter automaticamente o JSON do projetista em `.cad` completo. O projetista tem
componentes, terminais e netlist; o `.cad` precisa de:

- ID de classe de cada símbolo;
- posição e orientação na grade;
- deslocamento de cada pino;
- segmentos de fio e junções sem cruzamento acidental;
- rótulos e estados que o simulador usa.

Isso é biblioteca de símbolos + layout, não apenas `JSON.stringify`.

## 8. Decisão e próximo gate

1. **Fase 10A — importador somente leitura.** Escolher um `.cad`, mostrar inventário, geometria e
   anotações, com aviso de que não edita nem simula. É útil e não depende de pinos.
2. **Fase 10B — exportação de subconjunto.** Só depois de uma tabela de pinos por classe,
   orientação e tamanho, com corpus fixo e teste no CADeSIMU oficial (Windows/Wine). Sem esse
   gate, o app continua dizendo que não gera `.cad`.
3. **Não prometer** “abre no CADeSIMU” enquanto um arquivo gerado não for aberto e simulado no
   programa. Um parse perfeito não é prova de compatibilidade.

## 9. Fontes e amostras

- Notas de formato: <https://github.com/dajarony/cadesimu-mcp/blob/main/docs/CAD-FORMAT.md>
- Gramática e achados: <https://github.com/MonteiroBySWK/cade-simu-automation/blob/main/docs/formato-cad.md>
- Engenharia reversa de conectividade e simulação:
  <https://github.com/MonteiroBySWK/cade-simu-automation/blob/main/docs/re-engenharia.md>
- Amostras elétricas: <https://github.com/GermanAriza/cadesimu-projects> (arquivos de 2017)
- Amostra de ladder/CLP: <https://github.com/ELECTROALL/CADE-SIMU>
- Manual do programa: <https://cade-simu.com/wp-content/uploads/2020/04/CADe-SIMU-manual.pdf>

As amostras **não** foram copiadas para o repositório; os testes usam uma amostra sintética. O
relatório com hashes e comandos está em
[`relatorios/2026-11-15_058-cadesimu-formato.md`](relatorios/2026-11-15_058-cadesimu-formato.md).
