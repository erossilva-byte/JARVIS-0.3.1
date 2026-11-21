# Ajuste 074 — fechamento da Fase 10 e início da Fase 11

## 1. Identificação

- **Versão:** 1.62.0+16200
- **Data:** 2026-11-19
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** `JARVIS-Nova-1.62.0-fase-10-e-11.apk` (arm64, release, 117.414.216 bytes)
- **SHA-256:** `3fef550917b23c9068fa9435699ffec641bbf1eaceef30135921dc729f58627f`
- **Download (72 h):** https://litter.catbox.moe/qeav7b.apk
- **Plataformas afetadas:** Android (Flutter/Dart e Kotlin). Windows não foi tocado.

## 2. Resumo do ajuste

A Fase 10 (sandbox CADeSIMU e engenharia) foi fechada no que o simulador próprio
consegue provar: sensor de fim de curso, verificação de ligações e continuidade,
lista de materiais, arquivo `.circ` versionado, dimensionamento de condutor e
disjuntor e lógica ladder de CLP. A Fase 11 começou pela **Central do aparelho**,
que lê memória, armazenamento, bateria, rede, tempo ligado e a lista real de apps
instalados, e abre um app pelo pacote informando o que aconteceu.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Simulador — sensor | nova função | A Fase 10 lista sensores entre os componentes | `lib/core/circuito.dart`, `lib/services/circuito_page.dart` |
| Simulador — engenharia | nova função | Verificar ligações, continuidade, lista de materiais | `lib/core/engenharia.dart` |
| Simulador — arquivo `.circ` | nova função | Importar/exportar só formato com especificação conhecida | `lib/core/engenharia.dart` |
| Simulador — dimensionamento | nova função | Cálculos de seção, disjuntor e queda de tensão | `lib/core/engenharia.dart` |
| Simulador — CLP didático | nova função | A Fase 10 pede CLPs; entrega lógica ladder real, sem fingir CLP físico | `lib/core/clp.dart` |
| Central do aparelho | nova função | Primeiro entregável da Fase 11 | `lib/core/dispositivo.dart`, `lib/services/dispositivo_page.dart`, `lib/services/aparelho_service.dart`, `JarvisAparelho.kt` |
| Navegação | melhoria | Abrir a central pelo módulo "Android e dispositivos" | `lib/pages.dart` |

### Detalhes que importam

- **Sensor:** usa o mesmo modelo elétrico da botoeira (contato NA/NF), com o campo
  `sensor` para rótulo `S1` e para a tela falar "acionado/em repouso" em vez de
  "apertada/solta". É o comportamento de um fim de curso: a máquina aciona e o
  contato fica assim até voltar ao repouso. Exemplo novo "Sensor de fim de curso"
  (NF em série com a lâmpada: acesa em repouso, apaga ao acionar).
- **Verificação de ligações:** aponta fonte ausente, carga ausente, elemento com
  terminal solto, contato apontando para comando inexistente, temporizador sem
  contato 67/68, contato temporizado sem temporizador, relé térmico sem 95/96 e
  **curto** entre os polos da fonte por caminho só de fios e contatos fechados.
- **Continuidade:** busca em largura entre dois nós por elementos de resistência
  desprezível; a fonte não conta como caminho. É a resposta de um multímetro em
  modo de teste, não uma medida de resistência.
- **Lista de materiais:** agrupa por tipo e especificação, com os rótulos do
  circuito e o total de elementos.
- **`.circ`:** JSON com `formato: "jarvis.circ"`, `versao: 1`, grade e todos os
  campos de cada elemento (inclusive `sensor`, atrasos, dono do contato e estado).
  A importação recusa JSON inválido, formato estranho, versão futura, tipo
  desconhecido, nó fora da grade e dois elementos no mesmo trecho — sempre com
  mensagem, nunca carregando meio circuito. **Não é o `.cad` do CADeSIMU**, que
  continua apenas leitura.
- **Dimensionamento:** ampacidade resumida de cobre (B1, 2 condutores, 30 °C),
  disjuntores padronizados, queda de tensão em trecho de ida e volta e fator 1,25.
  Motor usa rendimento e fator de potência e informa a partida estimada (6×).
  A tela diz "dentro/fora dos limites" e explica o motivo; não é projeto assinado.
- **CLP didático:** degraus com contatos em série/paralelo, bobina por degrau,
  execução em ciclos com saídas retidas (o selo se mantém entre leituras) e limite
  de ciclos para lógica oscilante. Dois programas de exemplo testados: partida com
  selo e liga/desliga encadeado. É **análise lógica**, não simulação elétrica.
- **Central do aparelho:** `ActivityManager` (RAM), `StatFs` (armazenamento),
  bateria por `ACTION_BATTERY_CHANGED`, `ConnectivityManager` (Wi-Fi/móvel/offline),
  `SystemClock` (tempo ligado) e lista de apps com tela inicial (até 120). "Abrir"
  usa `getLaunchIntentForPackage`; sem tela inicial, o app informa o motivo.

## 4. Inventário de funções (recorte deste ajuste)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Sensor NA/NF no simulador | Sim | Não | Verificada (teste puro) | 15 verificações de engenharia | Nenhuma | Modelo DC; sensor é acionado por botão, não por grandeza física |
| Verificar ligações | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Análise de ligação; não substitui a simulação |
| Continuidade entre nós | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Só elementos de resistência desprezível |
| Lista de materiais | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Agrupa por tipo; não cota preço |
| Exportar/importar `.circ` | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Formato próprio; `.cad` continua só leitura |
| Dimensionamento de carga/motor | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Tabela resumida; não é projeto assinado |
| CLP didático (ladder) | Sim | Não | Verificada (teste puro) | idem | Nenhuma | Lógica pura; sem I/O físico nem tempo real |
| Central do aparelho (RAM/disco/rede/apps) | Sim | Não | Parcial | teste de widget + modelo; falta teste no Poco X7 | Nenhuma | Lista limitada a 120 apps com tela inicial |
| Abrir app pelo pacote | Sim | Não | Parcial | teste de widget (canal simulado); falta teste no aparelho | Nenhuma | Só apps com intent de lançamento |
| Pareamento Android ↔ Windows | Não | Não | Não implementada | — | — | Próximo bloco da Fase 11 |
| Tarefas e automações agendadas | Não | Não | Não implementada | — | — | Próximo bloco da Fase 11 |

## 5. Mudanças desde o relatório anterior

- **Novas:** sensor, verificação de ligações, continuidade, lista de materiais,
  `.circ`, dimensionamento, CLP didático, central do aparelho e abrir app.
- **Regressões:** nenhuma conhecida. A suíte existente continua passando e o
  sensor nasce com `sensor: false`, então circuitos antigos não mudam.
- **Estado alterado:** a Fase 10 deixa de ter "sensores, cálculos e diagnósticos"
  como pendência; a Fase 11 passa de "não iniciada" para "iniciada".

## 6. Testes executados e resultados

- `dart run tool/engenharia_test.dart` — **15 verificações**: sensor em repouso e
  acionado, rótulo, curto detectado, sem falso positivo, continuidade, circuito
  incompleto, lista de materiais, ida e volta do `.circ`, quatro arquivos inválidos
  recusados, dimensionamento aprovado e reprovado, motor com partida, entrada
  inválida, CLP com selo e CLP encadeado.
- `dart run tool/dispositivo_test.dart` — **5 verificações** de percentuais,
  formatação, apps inválidos, resposta ausente e rede móvel.
- `flutter test test/dispositivo_page_test.dart` — **3 testes**: números e apps,
  sem ponte nativa, busca.
- `flutter analyze` — sem nenhum problema.
- `flutter test` — **166 testes aprovados**.
- `python3 tests/test_aparelho_flutter.py`, `tests/test_circuito_flutter.py` e
  `tests/test_engenharia_flutter.py` — os três contratos aprovados.
- `flutter build apk --release --target-platform android-arm64` — concluído em
  88,7 s; `dispositivoInfo` e `abrirApp` presentes no `classes.dex` do APK.

## 7. Problemas conhecidos, riscos e limitações

- **Sem teste no Poco X7.** Nada deste ajuste foi instalado ou aberto no aparelho.
  Memória, armazenamento, rede, lista de apps e abertura de app têm prova apenas
  de código, teste de modelo e teste de widget com canal simulado.
- O CLP é lógica ladder didática; não conversa com CLP físico, não tem I/O real
  nem temporizadores de CLP (os do simulador são contatos elétricos).
- O dimensionamento usa tabela resumida e não cobre CA trifásico, fator de
  agrupamento, temperatura, eletroduto ou curva de coordenação.
- O `.circ` não abre no CADeSIMU e o `.cad` continua sem importação de rede.
- A central do aparelho não encerra apps, não mexe em janelas e não pareia com o
  Windows: são limites do Android e trabalho ainda não feito da Fase 11.

## 8. O que depende de você

1. Instalar o APK no Poco X7 e abrir **Android e dispositivos → Central do
   aparelho**; conferir memória, armazenamento, rede e a lista de apps.
2. Tocar em **Abrir** em dois apps e confirmar que abrem.
3. Abrir o simulador, escolher o exemplo **Sensor de fim de curso**, acionar o
   sensor no editor e ver a lâmpada apagar.
4. Em **Engenharia**, tocar em **Verificar ligações**, **Lista de materiais**,
   **Exportar .circ**, **Importar .circ** (colar o texto exportado) e
   **Dimensionar**; o CLP didático abre a partida com selo.
5. Dizer se o próximo bloco da Fase 11 deve ser **tarefas e automações** ou
   **pareamento com o Windows** (o pareamento depende de uma contraparte Windows
   que ainda não existe nesta versão).

## 9. Próximos passos

- Fase 11: tarefas e automações persistentes com fila offline e confirmação para
  ações sensíveis.
- Fase 11: pareamento Android ↔ Windows por QR Code e canal criptografado,
  quando houver a contraparte Windows.
- Testes de campo no Poco X7 de tudo que ficou marcado como Parcial.
