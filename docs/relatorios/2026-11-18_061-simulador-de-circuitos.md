# Ajuste 061 — simulador de circuitos nativo (Fase 10)

## 1. Identificação

- **Versão:** 1.49.0+14900 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-18.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Artefato:** código Flutter + testes e **APK release compilado**:
  `JARVIS-Nova-1.49.0-simulador-circuitos.apk`, 117.134.024 bytes, SHA-256
  `038d47629afd3886c66f5385f98e4f8c0945a84b813508112d985d247f004b92`, em
  `https://files.catbox.moe/oiah3h.apk`. Nada foi publicado em loja, GitHub Release ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada foi alterado no núcleo web,
  no Electron ou nos plugins Java.

## 2. Resumo do ajuste

O módulo **CADeSIMU e elétrica** ganhou um **simulador de circuitos** que funciona dentro do
Jarvis, no próprio aparelho: a pessoa monta o circuito numa grade, o app resolve as tensões e
correntes de verdade (análise nodal modificada) e aponta curto, circuito aberto, componente fora
da malha, lâmpada em sobretensão e fusível queimado. O **CADeSIMU em si não pôde ser embutido**:
é um programa freeware de Windows, sem versão Android, sem API pública e sem motor separado, e o
prompt proíbe WebView. O que existe agora é um simulador próprio, nativo e declaradamente menor
que o CADeSIMU.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Motor de simulação DC | nova função | Resolver o circuito numericamente, sem depender de nuvem e sem inventar resultado | `flutter_app/lib/core/circuito.dart` |
| Editor visual em grade | nova função | Inserir, remover, selecionar e conectar fonte, resistor, lâmpada, interruptor, fusível e fio | `flutter_app/lib/services/circuito_page.dart` |
| Diagnósticos elétricos | nova função | Apontar erro e risco em vez de dizer "funciona" sem prova | avisos dentro de `circuito.dart` |
| Proteção por fusível | nova função | Simular o rompimento pelo limite de corrente e recalcular o circuito aberto | `Circuito.simular`, `marcarQueimados`, `trocarFusiveis` |
| Exemplos prontos | nova função | Dar circuitos que já calculam, para conferir o comportamento | `exemplosCircuito` (5 circuitos) |
| Entradas na interface | melhoria | Deixar o simulador alcançável pelo módulo e pela tela do importador `.cad` | `flutter_app/lib/pages.dart`, `flutter_app/lib/services/cadesimu_page.dart` |
| Versão | melhoria | Marcar a entrega | `flutter_app/pubspec.yaml` 1.49.0+14900 |

O motor é **Dart puro** (nenhum `package:flutter`, nenhum `http`, nenhum `dart:io`): roda igual no
aparelho offline. A tela é 100% nativa com `CustomPaint` e gestos; **nenhum WebView**.

### Como a simulação funciona

1. Cada trecho da grade é um elemento de dois terminais; os nós são os pontos da grade.
2. Os fios, contatos de interruptor e fusíveis têm 1 µΩ; resistores usam o valor informado; a
   lâmpada vira `R = Vnom² / Pnom`; as fontes entram como fonte ideal de tensão.
3. Monta-se a matriz MNA e resolve-se por eliminação de Gauss com pivoteamento parcial.
4. Corrente, tensão e potência de cada elemento vêm da solução; o fusível rompe se a corrente
   passar do limite e o circuito é recalculado já aberto.
5. Nós sem caminho para o retorno da fonte são excluídos da conta e avisados, em vez de receber
   tensão inventada.

## 4. Inventário de funções (trecho novo)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Simulação DC (MNA) | Sim | Não | Verificada no código | `lib/core/circuito.dart`; 13 grupos em `tool/circuito_test.dart` | — | Só DC linear; sem CA, transitórios, contatores, CLP ou motores |
| Montagem visual em grade | Sim | Não | Verificada no código | `circuito_page.dart`; 5 testes de tela | — | Sem arrastar componente nem zoom |
| Diagnósticos (curto, aberto, ilha, sobretensão, potência) | Sim | Não | Verificada no código | avisos com teste dedicado | — | Curto classificado acima de 25 A |
| Fusível que rompe e abre o circuito | Sim | Não | Verificada no código | teste "FU1 queimou" | — | Rompimento imediato, sem curva tempo-corrente |
| Exemplos prontos | Sim | Não | Verificada no código | 5 circuitos, todos calculam | — | Fixos, sem gerar por IA |
| **O CADeSIMU dentro do Jarvis** | Não | Não | Fora de escopo | CADeSIMU é freeware de Windows, sem versão Android, sem API e sem motor separado; WebView é proibido pelo prompt | — | Não existe forma legítima de embutir |
| `.cad` → netlist para simular | Não | Não | Não implementado | relatório 059 | — | Falta a tabela de pinos e a prova no CADeSIMU oficial |

## 5. Mudanças desde o relatório anterior (060)

- **Novo:** simulador de circuitos DC com editor visual, solução numérica e diagnósticos.
- **Sem regressão:** a suíte Flutter passou de 142 para **147 testes**, todos aprovados, e
  `flutter analyze` continua limpo.
- **Importador `.cad`:** continua somente leitura; agora tem atalho para o simulador, sem passar
  a prometer que o arquivo `.cad` é simulado.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **13 grupos** aprovados: série, paralelo, divisor, lâmpada 12 V/5 W, interruptor aberto, curto, fusível, ilha, sem fonte, sobretensão, resistor quente, formatação e exemplos |
| Tela | `flutter test test/circuito_page_test.dart` | **5 testes** aprovados: exemplo inicial, interruptor aberto, troca de resistor no divisor, curto com fusível, apagar componente |
| Suíte Flutter completa | `flutter test` | **147 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado (motor puro/offline, sem WebView, limites no app, testes na suíte) |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | **✓ Built app-release.apk (117,1 MB)** |
| Conferência do APK | `aapt2 dump badging` | `package=com.jarvis.nova`, `versionName=1.49.0`, `versionCode=14900` |
| Conteúdo do APK | `strings libapp.so \| grep circuito-tabuleiro` | chaves do simulador presentes no binário compilado |
| Integridade do download | `curl` do link público + `sha256sum` | SHA-256 igual ao do arquivo local (117.134.024 bytes) |

Números conferidos à mão nos testes: 12 V em 200 Ω → 60 mA e 6 V em cada resistor; 1 kΩ + 2 kΩ em
12 V → 8 V no meio e 4 mA; lâmpada de 12 V/5 W → 0,417 A e 5 W; curto com fusível de 1 A →
fusível rompe e corrente cai a zero.

**Feito:** motor de simulação DC, tela nativa do simulador, diagnósticos elétricos, proteção
por fusível, cinco exemplos prontos, botões de entrada no módulo e no importador `.cad`, versão
1.49.0, testes e documentação.

**Evidência:** `flutter analyze` sem problemas; `dart run tool/circuito_test.dart` com 13 grupos;
`flutter test test/circuito_page_test.dart` com 5 testes; `flutter test` com 147 testes;
`python3 tests/test_circuito_flutter.py` aprovado; números de tensão e corrente conferidos à mão
na tabela acima.

**Critérios de aceitação atendidos:** (1) o circuito é resolvido numericamente e cada elemento
mostra tensão, corrente e potência; (2) curto, aberto, ilha, sobretensão, resistor sobrecarregado
e fusível rompido têm aviso próprio; (3) o app declara o que não é e o que não cobre; (4) existe
teste automático para o cálculo e para a interação na tela.

**Não verificado:** nenhum aparelho físico; o APK foi compilado e conferido por dentro, mas **não
foi instalado nem aberto** em celular; a tela não foi vista rodando; o toque em alvos pequenos numa
tela real não foi medido.

**Decisões e suposições:** o CADeSIMU não foi embutido porque não existe versão Android, API ou
motor reutilizável dele, e o prompt proíbe WebView; em vez de prometer o que não dá, foi entregue
um simulador próprio com limites escritos na tela.

## 7. Problemas conhecidos, riscos e limitações

- **Não é o CADeSIMU** e não ficou igual: o CADeSIMU tem contatores, relés, motores, CLP,
  temporizadores, lógica de comando e potência, e um formato `.cad` fechado. O simulador entregue
  cobre circuitos DC resistivos com cinco tipos de componente.
- **Sem corrente alternada, sem transitórios, sem indutores/capacitores.** A lâmpada é tratada
  como resistor (não modela a variação de resistência com a temperatura).
- **Fios ideais (1 µΩ)**: a queda de tensão nos fios não é realista; o curto aparece como corrente
  enorme, de propósito.
- **Fusível sem curva tempo-corrente**: rompe no primeiro instante em que passa do limite.
- **Nenhum aparelho físico**: nada foi aberto no Poco X7 nesta rodada.
- **APK desta versão compilado, porém não instalado**: o release 1.49.0 saiu com 117,1 MB
  (`https://files.catbox.moe/oiah3h.apk`). É um APK de teste: assinado com a chave de depuração e
  sem ABI x86 (só ARM), porque o alvo é o celular. O app instalado no aparelho continua sendo o
  1.48.1, que não tem o simulador.
- **Lint do Android desligado no build**: o `lintVitalRelease` do AGP cai com
  `NoSuchMethodError` neste ambiente (mistura de versões do parser Java do lint), então o build
  release usa `checkReleaseBuilds = false`. A análise estática do Dart continua sendo feita por
  `flutter analyze`, que está limpo. Quem for compilar noutra máquina precisa do mesmo ajuste ou de
  um AGP atualizado; o `build.gradle.kts` é gerado pelo `flutter create` e não fica no repositório.
- **Sem mover componente por arrasto nem zoom**: a grade fixa cabe na tela do celular, mas
  circuitos grandes exigem apagar e remontar trechos.

## 8. O que depende de você

1. **Instalar** o APK 1.49.0 (`https://files.catbox.moe/oiah3h.apk`) no Poco X7 e conferir:
   módulo **CADeSIMU e elétrica ▸ Abrir simulador de circuitos**. O Android vai pedir para permitir
   a instalação de fonte desconhecida, porque o APK é de teste e não vem da Play Store.
2. **Testar os cinco exemplos** e um circuito montado por você; me diga o que ficou confuso no
   toque (tamanho dos alvos, rótulos, ordem dos componentes).
3. **Decidir o próximo passo**: (a) ampliar o simulador com corrente alternada e contator,
   (b) tentar o caminho do arquivo `.cad` → netlist, que continua bloqueado pela tabela de pinos,
   ou (c) voltar ao restante da Fase 10B (brilho, SMS, ligações, WhatsApp).

## 9. Próximos passos propostos

- Levar o simulador para a conversa/voz: "monta um circuito com duas lâmpadas em paralelo" gerando
  a grade a partir de uma descrição, com o resultado calculado antes de responder.
- Adicionar contator e botoeira como elementos lógicos (bobina e contatos) para chegar perto do
  uso didático do CADeSIMU, mantendo a simulação DC.
- Exportar o circuito em JSON próprio (formato com especificação conhecida), sem fingir `.cad`.
