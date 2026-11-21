# Ajuste 066 — temporizador com retardo e sequência de partida (Fase 10)

## 1. Identificação

- **Versão:** 1.54.0+15400 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-18.
- **APK:** 117.199.936 bytes, ABI ARM, assinado com a chave de depuração, em
  `https://files.catbox.moe/bgvutu.apk`. SHA-256
  `f913526eff2547f21c293bdc6e87bcb39e0f727ca5cf387c82cc0715a5d97c80`.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada mudou no núcleo web, no Electron,
  nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

Entrou o **temporizador com retardo**: uma bobina KT com atraso em segundos e um **contato 67/68**
que só fecha quando o tempo completa. Como a conta do simulador é instantânea, o tempo é dado em
**passos**: o editor do temporizador tem o botão **Avançar 1 s**, que soma um segundo ao relógio dos
temporizadores energizados e resolve o circuito de novo. Sem energia, o relógio volta a zero.

O exemplo novo é a **sequência com temporizador**: em 24 V, a partida puxa K1 na hora e a lâmpada
de 24 V / 5 W só acende depois de 3 s, quando o 67/68 fecha.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Temporizador com atraso | nova função | Ter sequência de partida como no painel | `core/circuito.dart` (`TipoElemento.temporizador`, campo `atraso`) |
| Contato 67/68 | nova função | Ligar a segunda etapa só depois do tempo | `TipoElemento.contatoTemporizado` |
| Relógio por passos | nova função | Conta instantânea não tem tempo contínuo | `simular({tempos})`, `temporizadoresAtivos` no resultado |
| Laço de comando com temporizador | melhoria | O contato do tempo entra na mesma iteração do selo | `_comandar` |
| Exemplo de sequência | nova função | Mostrar o tempo agindo com números | `exemplosCircuito` (10 circuitos) |
| Botão Avançar 1 s e relógio na tela | nova função | Operar o tempo sem WebView | `services/circuito_page.dart` (`avancar-tempo`, `relogio-temporizador`) |
| Símbolo com relógio | nova função | Ver o temporizador no desenho | pintor do tabuleiro |
| Diagnósticos | nova função | Tempo contando, tensão baixa e 67/68 sem temporizador | avisos em `_solucionar` |

### Como o tempo é calculado

1. O temporizador é uma bobina em paralelo com o comando (240 Ω em 24 V, como a bobina do
   contator). Com 70% da nominal ou mais ele fica **energizado** e conta tempo.
2. O relógio fica em `tempos[id]`, fora do circuito. Cada toque em **Avançar 1 s** soma 1 ao relógio
   dos temporizadores energizados.
3. O contato 67/68 fecha quando o temporizador está energizado **e** o relógio chegou ao atraso.
   Aí o circuito é resolvido com o contato fechado e a lâmpada acende.
4. Se o comando cai (parada apertada ou bobina sem tensão), o temporizador fica sem energia, o
   relógio é zerado e o 67/68 abre.

## 4. Inventário de funções (trecho novo)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Temporizador com atraso em segundos | Sim | Não | Verificado no código | grupos "não acende antes do atraso" e "fecha aos 3 s" | — | Tempo em passos de 1 s, sem contagem contínua |
| Contato 67/68 do temporizador | Sim | Não | Verificado no código | teste do 67/68 acendendo a lâmpada | — | Um contato por temporizador |
| Relógio que zera sem energia | Sim | Não | Verificado no código | teste "sem energia o temporizador zera" | — | Sem retardo na queda (é instantâneo) |
| Exemplo de sequência com temporizador | Sim | Não | Verificado no código | 3 grupos de cálculo + teste de tela | — | Lâmpada no lugar de um segundo motor |
| Botão Avançar 1 s | Sim | Não | Verificado no código | teste de tela com o relógio indo de 0 a 3 s | — | Um segundo por toque |

## 5. Mudanças desde o relatório anterior (065)

- **Novo:** temporizador KT, contato 67/68, relógio por passos, botão Avançar 1 s, símbolo com
  relógio, exemplo de sequência e três diagnósticos.
- **Mudou:** o laço de comando agora itera bobinas **e** temporizadores; o texto de limites explica
  que o tempo não corre sozinho.
- **Sem regressão:** `flutter analyze` limpo; suíte Flutter de 151 para **152 testes**; grupos de
  cálculo puro de 35 para **38**.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **38 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **10 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **152 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ gerado |
| Conferência do APK | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.54.0`, `versionCode=15400` |
| Integridade do download | `curl` de `https://files.catbox.moe/bgvutu.apk` + `sha256sum` | 117.199.936 bytes, SHA-256 igual ao do arquivo local |

Números conferidos à mão:

| Verificação | Conta | Resultado no teste |
|---|---|---|
| KT1 energizado, relógio em 0 s | 24 V no KT, atraso 3 s | lâmpada com 0 W, 67/68 aberto |
| Relógio em 2 s | 2 s < 3 s | lâmpada continua com 0 W |
| Relógio em 3 s | 3 s = atraso | 67/68 fechado, lâmpada com 24 V e 5 W |
| Parada apertada | comando sem tensão | KT1 sem energia, relógio zerado, lâmpada apagada |

**Feito:** temporizador com atraso, contato 67/68, relógio por passos com botão de avançar,
exemplo de sequência, símbolos, diagnósticos, testes e documentação; versão 1.54.0.

**Evidência:** comandos e números acima; APK conferido por dentro e link público baixado com SHA-256
comparado ao arquivo local.

**Critérios de aceitação atendidos:** (1) o contato só fecha depois do atraso; (2) antes do atraso
nada liga; (3) sem energia o relógio zera e o contato abre; (4) o app explica o tempo e ensina a
avançar; (5) há teste de cálculo e de tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular.

## 7. Problemas conhecidos, riscos e limitações

- **Tempo em passos:** o relógio só anda com **Avançar 1 s**. Não há contagem automática, animação
  nem atrasos fracionários na prática (o campo aceita decimal, mas o passo é 1 s).
- **Sem retardo na queda:** ao perder energia o contato abre e o relógio zera na hora; um temporizador
  real pode ter retardo também no desligamento.
- **Um contato por temporizador**, sem contato NF temporizado.
- **Sem CA, motor de indução, curva térmica, CLP ou leitura de `.cad`.**
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `android/` é gerado pelo `flutter create` e não fica no
  repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.54.0 (`https://files.catbox.moe/bgvutu.apk`) e abrir **CADeSIMU e elétrica ▸ Abrir simulador de circuitos ▸ Sequência
   com temporizador**.
2. **Conferir**: apertar a partida (K1 puxa, lâmpada apagada), tocar no KT1 e usar **Avançar 1 s**
   três vezes — a lâmpada deve acender no terceiro toque.
3. **Testar a parada**: apertar a parada e ver o relógio voltar a zero.
4. **Dizer o que ficou confuso** no símbolo do relógio e no texto do tempo.

## 9. Próximos passos propostos

- Contato NF temporizado e temporizador com retardo na queda.
- Avançar 5 s ou avançar até o próximo evento, para sequências longas.
- Exportar o circuito em JSON próprio, sem fingir `.cad`.
