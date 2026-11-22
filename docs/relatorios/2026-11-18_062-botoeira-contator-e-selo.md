# Ajuste 062 — botoeira, bobina de contator e contato de selo (Fase 10)

## 1. Identificação

- **Versão:** 1.50.0+15000 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-18.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Artefato:** `JARVIS-Nova-1.50.0-contator-e-selo.apk`, 117.134.220 bytes, SHA-256
  `92ffa93fe28506a9c375fcbe64dce1dfc928c21d392d5df5538015a1eaa0932e`, em
  `https://files.catbox.moe/ci2udw.apk`. Build de teste, assinado com a chave de depuração, ABI ARM.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada foi alterado no núcleo web, no
  Electron, nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

O simulador de circuitos passou a montar **comando elétrico**, não só carga: entraram **botoeira
(NA e NF)**, **bobina de contator** e **contato de selo**. Como o contato de selo fecha o caminho
que alimenta a própria bobina, o circuito deixou de ser linear: o motor agora resolve por
iteração, com puxar em 70% da tensão nominal e soltar abaixo de 50%. O exemplo novo é a **partida
direta com selo** em 24 V, com os valores calculados (bobina de 240 Ω → 100 mA). Continua sendo
corrente contínua: não é o CADeSIMU e não há motor nem corrente alternada.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Botoeira NA/NF | nova função | Comando precisa de partida (NA) e parada (NF) | `flutter_app/lib/core/circuito.dart` |
| Bobina de contator | nova função | Representar o contator como carga com tensão de operação | idem |
| Contato de selo | nova função | É o que mantém o contator ligado depois de soltar a partida | idem |
| Resolução iterativa do comando | nova função | Contator não é linear: o selo depende da bobina e a bobina do selo | `Circuito._comandar` |
| Memória do contator | nova função | Sem guardar o estado das bobinas, o selo abriria a cada recálculo | `simular(bobinasLigadas:)`, `ResultadoSimulacao.bobinasLigadas`, `_CircuitoPageState.bobinas` |
| Diagnósticos de comando | nova função | Apontar bobina fraca, selo sem bobina e comando instável | avisos dentro de `_solucionar` |
| Símbolos e editor na tela | nova função | Montar e operar o comando sem WebView | `flutter_app/lib/services/circuito_page.dart` |
| Exemplo de partida direta | nova função | Dar um circuito de comando que já abre calculado | `exemplosCircuito` (6 circuitos) |
| Versão | melhoria | Marcar a entrega | `flutter_app/pubspec.yaml` 1.50.0+15000 |

### Como o comando por contator é calculado

1. O circuito é resolvido pela mesma análise nodal modificada (MNA) já usada para as cargas.
2. Contatos (botoeira apertada, selo fechado) valem 1 µΩ quando fechados e ficam fora da matriz
   quando abertos.
3. Depois da primeira solução, cada bobina é avaliada: puxa se receber **70% ou mais** da tensão
   nominal; se já estava ligada, só solta abaixo de **50%** (histerese).
4. Os contatos de selo são reajustados conforme as bobinas e o circuito é resolvido de novo, até
   o estado não mudar mais (limite de 12 iterações; se não estabilizar, o app avisa em vez de
   entregar um resultado inventado).
5. O estado final das bobinas volta em `ResultadoSimulacao.bobinasLigadas` e a tela devolve esse
   estado na próxima conta — é isso que faz o selo segurar o contator depois de soltar a botoeira.

## 4. Inventário de funções (trecho novo)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Botoeira NA e NF | Sim | Não | Verificado no código | teste da partida direta (partida NA, parada NF) | — | Sem retenção mecânica nem contato duplo |
| Bobina de contator | Sim | Não | Verificado no código | 24 V / 240 Ω → 100 mA; bobina com 55% não puxa | — | Puxa em 70%, solta em 50%; sem tempo de operação nem bobina CA |
| Contato de selo | Sim | Não | Verificado no código | teste "contato de selo mantém a bobina" | — | Apenas NA; sem contato NF auxiliar nem intertravamento |
| Partida direta com selo | Sim | Não | Verificado no código | exemplo + teste de tela (apertar, soltar, parar) | — | Comando em 24 V DC, sem motor nem circuito de potência |
| Comando instável é avisado | Sim | Não | Verificado no código | limite de 12 iterações em `_comandar` | — | Avalia o estado final, sem gráfico de tempo |
| **O CADeSIMU dentro do Jarvis** | Não | Não | Fora de escopo | freeware de Windows, sem versão Android, sem API e sem motor separado; WebView é proibido | — | Não existe forma legítima de embutir |
| Motor, contato de potência, temporizador | Não | Não | Não implementado | — | — | Fora desta etapa; declarado na tela |

## 5. Mudanças desde o relatório anterior (061)

- **Novo:** botoeira, bobina de contator, contato de selo, resolução iterativa do comando e o
  exemplo de partida direta com selo.
- **Mudou:** a tela do simulador agora guarda o estado das bobinas entre os cálculos; os limites
  escritos no app deixaram de citar "contatores" como ausentes e passaram a citar motores,
  temporizadores e CLP.
- **Sem regressão:** `flutter analyze` continua limpo; a suíte Flutter subiu de 147 para **148
  testes**, todos aprovados; os 13 grupos de cálculo antigos continuam passando (agora 20).

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **20 grupos** aprovados |
| Suíte Flutter completa | `flutter test` | **148 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | **✓ Built app-release.apk (117,1 MB)** |
| Conferência do APK | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.50.0`, `versionCode=15000` |
| Conteúdo do APK | `strings libapp.so` | `bobinasLigadas`, `Partida direta com selo` e `apertar-botoeira` presentes |
| Integridade do download | `curl` do link público + `sha256sum` | SHA-256 igual ao do arquivo local |

Grupos novos do cálculo puro (números conferidos à mão):

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Partida solta | sem caminho fechado | bobina desligada, corrente 0 A, aviso "solta (NA)" |
| Partida apertada | 24 V em 240 Ω | bobina ligada, 24 V, **100 mA**, 2,4 W |
| Soltar a partida | selo fecha o mesmo caminho | bobina continua ligada com 100 mA |
| Parada (NF) apertada | caminho aberto | bobina solta e corrente cai a zero |
| Soltar a parada depois | selo aberto, partida solta | continua parado (não religa sozinho) |
| Bobina com 55% | 24 V em 200 Ω + 240 Ω | 13,09 V → não puxa, com aviso |
| Selo sem bobina | contato sem dono | fica aberto e o app explica |

**Feito:** botoeira NA/NF, bobina de contator com puxar/soltar, contato de selo, resolução
iterativa do comando, memória do contator na tela, três diagnósticos novos, exemplo de partida
direta, versão 1.50.0, testes e documentação.

**Evidência:** comandos e números da tabela acima; APK compilado e conferido por dentro;
link público com SHA-256 conferido após o download.

**Critérios de aceitação atendidos:** (1) a partida direta é resolvida numericamente e mostra
tensão, corrente e potência de cada componente; (2) o selo mantém o contator depois de soltar a
botoeira e a parada derruba o comando; (3) bobina fraca, selo sem bobina e comando instável têm
aviso próprio; (4) existe teste automático para o cálculo e para a interação na tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular; o toque
nos alvos pequenos numa tela real não foi medido.

## 7. Problemas conhecidos, riscos e limitações

- **Modelo simplificado de contator:** puxa em 70% e solta em 50% da nominal, sem tempo de
  operação, sem bobina CA, sem contato de potência e sem motor. Não representa partida de motor
  real (corrente de partida, conjugado, proteção térmica).
- **Sem corrente alternada:** o comando é DC. Um contator de 220 V CA não pode ser simulado aqui.
- **Contato de selo apenas NA** e ligado a uma bobina por vez; sem intertravamento entre
  contatores e sem contato NF auxiliar.
- **Fusível e fios ideais (1 µΩ)**, como no ajuste anterior: sem curva tempo-corrente e sem queda
  real nos condutores.
- **Comando instável** é avisado, mas o app não mostra o gráfico temporal do que oscilou.
- **Nenhum aparelho físico:** nada foi instalado ou aberto no Poco X7 nesta rodada.
- **Build:** o `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `build.gradle.kts` é gerado pelo `flutter create` e
  não fica no repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.50.0 (`https://files.catbox.moe/ci2udw.apk`) e abrir **CADeSIMU e
   elétrica ▸ Abrir simulador de circuitos ▸ Partida direta com selo**.
2. **Conferir o comportamento**: tocar na botoeira de partida, apertar, soltar (o contator deve
   continuar ligado), apertar a parada (deve cair) e soltar a parada (deve continuar parado).
3. **Dizer o que ficou confuso** no toque: tamanho dos alvos, símbolos de botoeira e bobina,
   rótulos K1 e K1-13/14.
4. **Decidir o próximo passo**: (a) contato NF auxiliar e intertravamento entre dois contatores,
   (b) motor com contato de potência, (c) voltar ao restante da Fase 10B.

## 9. Próximos passos propostos

- Contato NF auxiliar e intertravamento (reversão), que é o próximo degrau didático do CADeSIMU.
- Circuito de potência com motor e contato principal do contator, ainda em DC e com limites
  escritos.
- Exportar o circuito em JSON próprio (formato com especificação conhecida), sem fingir `.cad`.
