# Ajuste 065 — relé de sobrecarga (térmico) no motor (Fase 10)

## 1. Identificação

- **Versão:** 1.53.0+15300 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-18.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Artefato:** `JARVIS-Nova-1.53.0-rele-termico.apk`, 117.134.340 bytes, SHA-256
  `f48c061379c3d1e1340a507ffad14696d978ea47602da0bafe87508ca5cea258`, em
  `https://files.catbox.moe/2zx9q8.apk`. Build de teste, assinado com a chave de depuração, ABI ARM.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada foi alterado no núcleo web, no
  Electron, nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

Entrou o **relé de sobrecarga (térmico)**: um elemento em série com o motor que **desarma** quando
a corrente passa do ajuste, com o **contato 95/96** no comando. Desarmar abre o 95/96, derruba a
bobina, abre o contato de potência e corta o motor — a sequência do painel real. O relé **tem
memória** e só volta com **Rearmar**, e rearmar não religa o motor. O exemplo novo é a **partida
com relé de sobrecarga**, em 24 V, com motor de 1 A e FT1 ajustado em 1,5 A; baixando o ajuste
para 0,5 A o relé desarma na hora.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Relé térmico com ajuste de corrente | nova função | Proteger o motor como no painel real | `flutter_app/lib/core/circuito.dart` (`TipoElemento.releTermico`, `desarmado`) |
| Contato 95/96 | nova função | Tirar o comando quando o relé desarma | `TipoElemento.contatoRele`, `ativaEm` |
| Estado que não se apaga sozinho | nova função | Relé desarmado tem de continuar desarmado até o rearme | `Circuito.desarmar`, `Circuito.rearmarReles`, `relesDesarmados` no resultado |
| Laço de proteção no cálculo | nova função | Desarmar, recalcular e mostrar o circuito já protegido | `Circuito.simular` (laço de 6 rodadas, junto com o fusível) |
| Exemplo de partida com relé | nova função | Mostrar a proteção agindo com números | `exemplosCircuito` (9 circuitos, grade 6×5) |
| Símbolo e botão de rearme | nova função | Operar a proteção sem WebView | `flutter_app/lib/services/circuito_page.dart` (`rearmar-rele`) |
| Diagnósticos | nova função | Relé desarmado, relé no limite (90% do ajuste) e 95/96 sem relé | avisos em `_solucionar` |
| Versão | melhoria | Marcar a entrega | `flutter_app/pubspec.yaml` 1.53.0+15300 |

### Como o desarme é calculado

1. O relé mede a corrente que passa por ele (1 µΩ de resistência, em série com o motor).
2. Se a corrente passar do ajuste, o relé é marcado como desarmado e o circuito é **recalculado**
   com o contato 95/96 aberto.
3. Com o 95/96 aberto, a bobina perde a alimentação (abaixo de 50% ela solta), o contato de
   potência abre e o motor fica com 0 A. O laço confere de novo e para.
4. O relé continua desarmado (estado guardado no próprio elemento), então a proteção não volta
   sozinha: é preciso **Rearmar** — e mesmo assim o motor só religa apertando a partida, porque o
   selo do contator também caiu.
5. Comportamento verificado no teste de tela: **rearmar com a partida ainda apertada desarma de
   novo na hora**, porque a corrente continua acima do ajuste. É o que aconteceria num painel real.

## 4. Inventário de funções (trecho novo)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Relé térmico com ajuste de corrente | Sim | Não | Verificado no código | testes "1,5 A deixa rodar" e "0,5 A desarma" | — | Desarme instantâneo, sem curva tempo-corrente nem bimetal térmico |
| Contato 95/96 no comando | Sim | Não | Verificado no código | teste do desarme com bobina caindo | — | Um contato por relé |
| Estado de desarme com rearme | Sim | Não | Verificado no código | testes "rearmar não religa" e teste de tela com o botão | — | Rearme manual pelo app, sem rearme automático |
| Exemplo de partida com relé | Sim | Não | Verificado no código | 3 grupos de cálculo + teste de tela | — | Motor como carga resistiva |

## 5. Mudanças desde o relatório anterior (064)

- **Novo:** relé térmico, contato 95/96, estado de desarme com rearme, exemplo de partida com relé,
  botão **Rearmar** e três diagnósticos de proteção.
- **Mudou:** o laço de proteção do cálculo agora trata fusível **e** relé; o texto de limites diz
  que o desarme é instantâneo, sem curva de tempo.
- **Sem regressão:** `flutter analyze` limpo; suíte Flutter de 150 para **151 testes**; grupos de
  cálculo puro de 32 para **35**.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **35 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **9 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **151 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | **✓ Built app-release.apk (117,1 MB)** |
| Conferência do APK | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.53.0`, `versionCode=15300` |
| Conteúdo do APK | `strings libapp.so` | `releTermico` e `rearmarReles` presentes |
| Integridade do download | `curl` do link público + `sha256sum` | SHA-256 igual ao do arquivo local |

Números conferidos à mão nos testes:

| Verificação | Conta | Resultado no teste |
|---|---|---|
| FT1 em 1,5 A com motor de 1 A | 1 A < 1,5 A | não desarma; motor com 1 A |
| FT1 em 0,5 A com motor de 1 A | 1 A > 0,5 A | desarma, bobina cai, motor em 0 A, aviso "desarmou" |
| Rearme sem apertar a partida | selo aberto, partida solta | motor continua em 0 A |
| Rearme com a partida apertada | 1 A > 0,5 A de novo | desarma outra vez (teste de tela) |

**Feito:** relé térmico, contato 95/96, memória de desarme com rearme, exemplo de partida com relé,
botão de rearme, diagnósticos, testes e documentação; versão 1.53.0.

**Evidência:** comandos e números na tabela acima; APK conferido por dentro e link público baixado
com SHA-256 comparado ao arquivo local.

**Critérios de aceitação atendidos:** (1) o relé desarma acima do ajuste e o motor para; (2) o
desarme derruba o comando pelo 95/96 e não se desfaz sozinho; (3) rearmar não religa o motor;
(4) o app explica o motivo do desarme; (5) há teste de cálculo e de tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular.

## 7. Problemas conhecidos, riscos e limitações

- **Desarme instantâneo:** não há curva tempo-corrente, aquecimento de bimetal nem memória térmica
  real. Um relé real tolera sobrecargas curtas; aqui ele desarma no primeiro cálculo acima do
  ajuste.
- **Um ajuste por relé**, sem faixa (não bloqueia ajuste fora da corrente do motor).
- **Motor como carga resistiva:** sem corrente de partida, que num motor real já desarmaria um
  relé ajustado perto da nominal.
- **Sem corrente alternada, motor de indução, contator reversor de potência ou temporizador.**
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `build.gradle.kts` é gerado pelo `flutter create` e
  não fica no repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.53.0 (`https://files.catbox.moe/2zx9q8.apk`) e abrir **CADeSIMU e
   elétrica ▸ Abrir simulador de circuitos ▸ Partida com relé de sobrecarga**.
2. **Conferir**: apertar a partida (motor com 1 A), depois tocar no FT1, baixar o ajuste para
   0,5 A e apertar a partida de novo — o relé deve desarmar e o motor parar.
3. **Testar o rearme**: soltar a partida, tocar no FT1, **Rearmar relé** e apertar a partida.
4. **Dizer o que ficou confuso** nos símbolos e nos textos dos avisos.

## 9. Próximos passos propostos

- Temporizador com retardo, para uma sequência de partida de verdade.
- Proteção com curva simples (desarme acima do ajuste por N ciclos), declarando que não é a curva
  do fabricante.
- Exportar o circuito em JSON próprio (formato com especificação conhecida), sem fingir `.cad`.
