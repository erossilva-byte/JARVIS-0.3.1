# Especialização elétrica — estado real, decisões e limites

Documento da revisão 1.42.7. Ele descreve o que o J.A.R.V.I.S. Nova **faz de verdade** com circuitos
elétricos, o que foi acrescentado nesta revisão e o que continua **não** implementado. Nada aqui deve
ser lido como "o Jarvis virou especialista porque recebeu um prompt": o que existe é motor determinístico,
base técnica consultável e testes com resultado esperado.

## 1. Arquitetura real (auditada antes de mexer)

| Peça | Onde | O que faz | Ligado a quê |
|---|---|---|---|
| Interpretação + projeto + verificação | `projetista.js` | lê o pedido em PT-BR, monta componentes/pinos/redes, valida por regras, corrige, compara, versiona, relata, ladder e salva | interface em Arquivos, chat/voz em `app.js` |
| Base técnica | `eletrica.js` (1.42.7) | biblioteca de componentes, tabelas, dimensionamento com memória, conferência independente, referências com procedência | `projetista.js` (dimensionar/validar) e chat |
| Interface | bloco `projetistaEletricoUI` em `app.js` + `#proj-*` no `index.html` | desenho SVG com símbolos IEC, seleção de pino, redes, saída técnica | ponte `window.JarvisProjetistaUI` |
| Chat e voz | `responderProjetista` em `app.js` | intercepta o turno antes da IA (texto e fala), responde e fala o resumo | `window.JarvisProjetista` |
| Visão | `visao.js` / `hermes.js` | analisa imagem **quando há chave de IA configurada**; não converte símbolo em netlist | não usado pelo projetista |
| Memória | `memoria.js` / Obsidian | memória contextual e notas; não é treinamento | Ajustes ▸ Memória |

### Problemas encontrados na auditoria

1. **Crítico (corrigido na 1.42.6)**: `projetista.js`, `pc.js` e `cad_projeto.js` não eram copiados para `www/`
   pelo workflow Android; o APK 1.42.5 saiu sem o motor do projetista. Hoje há teste de empacotamento.
2. **Corrigido na 1.42.7**: o dimensionamento era uma estimativa solta (sem cabo, sem faixa de térmico, sem
   memória de cálculo) e não era confrontado com o que o projeto declarava.
3. **Corrigido na 1.42.7**: não existia segunda análise; `validar()` verificava estrutura, mas não "o pedido foi
   atendido?" (dois motores, tempo, proteção por motor).
4. **Aberto e declarado**: não há geração nem leitura do `.cad` nativo do CADeSIMU (formato proprietário, sem
   especificação pública). O que existe é formato próprio documentado (`ProjetistaEletrico CAD` v1) e netlist v1.
5. **Aberto e declarado**: foto/captura de diagrama não vira netlist. A visão atual descreve a imagem; converter
   símbolo → componente → terminal exigiria modelo de visão dedicado e validação humana, e não há chave de IA
   neste build para testar isso de ponta a ponta.
6. **Aberto e declarado**: não há simulação elétrica (tensão/corrente no tempo), nem FBD/texto estruturado
   executável; o ladder é uma lista de expressões verificável, não o arquivo de um CLP específico.

## 2. Base técnica (`eletrica.js`)

- **12 componentes** com terminais, função, limites, regras de uso e símbolo IEC 60617 descrito.
- **Tabelas de referência**: ampacidade cobre/PVC método B1, série de contatores AC-3, série de disjuntores,
  faixas comerciais de térmico.
- **`dimensionar(spec)`**: In por fórmula declarada (η 0,90 / fp 0,80), contator, disjuntor + curva, ajuste e
  faixa do térmico, cabo por ampacidade (≥ 1,25 × In) e queda ≤ 4%, com **memória de cálculo** linha a linha.
- **`conferirDimensionamento(projeto)`**: verificação independente; reprova contator, disjuntor, térmico ou cabo
  menores que o necessário e injeta `dimensionamento_*` em `validar()`.
- **`consultar(termo)`**: consulta técnica com fonte; **`enderecarClp(mapa)`**: valida `%I0.0`/`%Q0.0` e duplicidade.
- **Referências**: `registrarReferencia` guarda título, texto, fonte e confiança. É **memória consultável**, com
  aviso explícito de que **não é treinamento** do modelo.

## 3. Motor de projetos

Fluxo determinístico, sem IA no caminho: interpretar → classificar topologia → dimensionar → montar componentes
com pinos nomeados → definir redes → sequência de operação → verificar → corrigir → relatar.

Topologias: partida direta, reversão, estrela-triângulo, compensadora, **sequência de dois motores com
temporizador (1.42.7)**, comando com selo, iluminação e CLP de nível.

Exemplo da missão, executado de verdade: *"controlar dois motores, onde o segundo só possa ligar depois que o
primeiro estiver funcionando por cinco segundos"* gera Q1/Q2, K1/F2/M1, K2/F3/M2, KT de 5 s alimentado por K1,
selo em K1, emergência e sinalização; `validar()` aprova e `conferirObjetivo()` confirma dois motores, tempo de
5 s, proteção por motor e bobina de K2 vinda do contato temporizado.

## 4. Segunda análise

`conferirObjetivo(projeto)` não reutiliza `validar()`: compara a estrutura com a especificação (emergência,
sinalização, topologia, número de motores, tempo do temporizador, intertravamento, proteção por motor, CLP com
rungs). Se o temporizador for removido, a segunda análise reprova — e o teste cobre isso.

## 5. Arquivos e interoperabilidade

- Formato próprio `ProjetistaEletrico CAD` v1 (JSON) com versões, restauração e comparação estrutural.
- **Netlist v1** (`exportarNetlist` / `importarDiagramaTexto`): texto com `COMP`, `PINO` e `REDE`; ida e volta
  preservando pinos, coberta por teste.
- `.cad` do CADeSIMU: **não suportado**. Nenhuma alegação de abertura, edição ou geração.
- Relatório técnico declara, em cada entrega, o que foi e o que **não** foi verificado.

## 6. Testes (executados nesta revisão)

| Comando | Resultado |
|---|---|
| `node tests/test_eletrica.js` | 8 grupos OK (dimensionamento 5/15 CV e monofásico, recusa sem potência, conferência independente, biblioteca, CLP, memória) |
| `node tests/test_projetista.js` | 73 verificações + sequência de dois motores, segunda análise e netlist OK |
| `node tests/test_projetista_ui.js` | app inteiro no jsdom: símbolos, pino, chat e desfazer OK |
| `python3 tests/test_empacotamento.py` | OK (todo script do `index.html` no Android e no Windows) |
| `python3 tests/test_v1_13_0.py` | 42 verificações OK |
| `python3 tests/validate_project.py` | 683 IDs, versão 1.42.7 OK |

## 7. Limitações assumidas

- Sem simulação elétrica, sem transitórios e sem cálculo normativo fechado; tabelas são de referência didática.
- Sem `.cad` do CADeSIMU; interoperabilidade por formato próprio e netlist.
- Sem reconstrução automática de foto/PDF; visão descreve, não converte em circuito.
- Sem CLP executável (FBD/ST reais); ladder é lista verificável.
- Sem validação em aparelho físico, Windows real ou CADeSIMU instalado nesta máquina.

## 8. Próximos passos com maior retorno

1. Ler netlist de arquivos exportados por ferramentas que publiquem formato aberto (ex.: CSV/DXF de outros CADs),
   com adaptador por ferramenta e teste de ida e volta.
2. Ligar a visão ao projetista com contrato estrito: imagem → JSON de componentes → **confirmação humana** →
   netlist, com teste de precisão em conjunto fixo de imagens.
3. Ampliar topologias (partida com inversão temporizada, contadores, fim de curso, alarmes) mantendo o mesmo
   padrão: projeto + verificação + segunda análise + teste.
4. Catálogo por fabricante (corrente, curva, faixa) como dado versionado, sem inventar valores.

## 8. Correções da 1.44.0

- Séries ampliadas: contator AC-3 até 800 A, disjuntor até 800 A, cabo até 300 mm² e faixas de
  térmico até 800 A.
- Fora da tabela, `dimensionar()` devolve `ok:false` com código (`fora_da_tabela` ou
  `cabo_fora_da_tabela`) e o projetista **não monta** o circuito; antes ele aprovava um contator
  menor que a corrente.
- Cabo que não atende ampacidade/quedas não é mais substituído por 50 mm² com aviso.
- Iluminação não herda emergência; partida monofásica não exige os polos 5/6 do térmico.
- Testes: 10 grupos na base elétrica e 84 verificações no projetista.
