# Ajuste 063 — contato NF auxiliar, intertravamento e reversão (Fase 10)

## 1. Identificação

- **Versão:** 1.51.0+15100 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-18.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Artefato:** `JARVIS-Nova-1.51.0-intertravamento-e-reversao.apk`, 117.134.220 bytes, SHA-256
  `41d9641cd2a462705318c92dd17608b08c7af5e88f2cf84bb0e31540eea243d0`, em
  `https://files.catbox.moe/cgj87f.apk`. Build de teste, assinado com a chave de depuração, ABI ARM.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada foi alterado no núcleo web, no
  Electron, nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

O simulador ganhou o **contato NF auxiliar (21-22)** de contator, que é como se faz
**intertravamento**: ele fica fechado enquanto a bobina do contator está solta e abre quando ela
liga. Com isso entrou o exemplo **reversão com intertravamento**, em 24 V, com dois contatores
(K1 e K2), cada um com partida, selo e o contato NF do outro em série com a bobina. O circuito é
resolvido pelo mesmo cálculo iterativo do ajuste 062 e mostra, com números, que um contator
impede o outro de ligar.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Contato NF auxiliar (21-22) | nova função | Intertravamento elétrico entre contatores | `flutter_app/lib/core/circuito.dart` (`TipoElemento.contatoNf`, `ativaEm`) |
| Rótulos `K1-21/22` | melhoria | Identificar o contato pelo contator dono, como no CADeSIMU didático | `Circuito.rotulos` |
| Exemplo de reversão | nova função | Dar um comando de dois contatores que já abre calculado | `exemplosCircuito` (7 circuitos, grade 8×5) |
| Aviso de intertravamento | melhoria | Explicar por que o segundo contator não liga | aviso em `_solucionar` |
| Símbolo e paleta na tela | melhoria | Montar e ver o contato NF sem WebView | `flutter_app/lib/services/circuito_page.dart` |
| Testes do travamento | nova função | Provar que K2 não liga com K1 ligado e que o comando instável é avisado | `tool/circuito_test.dart`, `test/circuito_page_test.dart` |
| Versão | melhoria | Marcar a entrega | `flutter_app/pubspec.yaml` 1.51.0+15100 |

### Como a reversão é calculada

1. A parada (NF) alimenta os dois ramos; cada ramo tem partida (NA), selo (NA de K1 ou K2) em
   paralelo e, em série com a bobina, o **contato NF do outro contator**.
2. Com as duas partidas soltas, nada puxa: os dois NF estão fechados, mas os caminhos estão
   abertos nas partidas e nos selos.
3. Apertando a partida 1: o caminho fecha pelo NF de K2 (solta); a bobina K1 recebe 24 V em
   240 Ω (100 mA) e puxa; o selo de K1 fecha e o NF de K1 abre.
4. O app resolve de novo: K1 continua pela própria selagem e o ramo de K2 fica interrompido pelo
   NF de K1. A partida 2, mesmo apertada, não energiza K2 — e o app mostra o aviso do contato NF.
5. Apertar as duas partidas ao mesmo tempo cria o ciclo "K1 liga → abre o NF de K2 → K2 cai →
   fecha o NF de K2 → K1 mantém…". O app tenta 12 iterações e **avisa que o comando não se
   estabiliza**, em vez de escolher um resultado.

## 4. Inventário de funções (trecho novo)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Contato NF auxiliar (21-22) | Sim | Não | Verificado no código | teste "contato NF de K1 impede K2", teste de tela da reversão | — | Um contato por bobina; sem contato temporizado |
| Intertravamento elétrico entre contatores | Sim | Não | Verificado no código | exemplo da reversão com 4 verificações próprias | — | Elétrico (contato NF na bobina), não mecânico |
| Reversão com dois contatores | Sim | Não | Verificado no código | grade 8×5, K1 e K2 com selo; 100 mA cada | — | Só comando; sem contatos de potência nem motor |
| Comando instável é avisado | Sim | Não | Verificado no código | teste "duas partidas ao mesmo tempo" | — | Avalia o estado final, sem gráfico de tempo |

## 5. Mudanças desde o relatório anterior (062)

- **Novo:** contato NF auxiliar, rótulos `K1-21/22`, exemplo de reversão em grade 8×5, aviso de
  intertravamento e teste de tela com a grade maior.
- **Mudou:** a grade do tabuleiro passou a ser lida do circuito (o exemplo da reversão usa 8×5);
  os limites escritos no app agora citam o contato NF de intertravamento.
- **Sem regressão:** `flutter analyze` limpo; suíte Flutter de 148 para **149 testes**; grupos de
  cálculo puro de 20 para **26**, todos aprovados.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **26 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **7 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **149 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | **✓ Built app-release.apk (117,1 MB)** |
| Conferência do APK | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.51.0`, `versionCode=15100` |
| Conteúdo do APK | `strings libapp.so` | `contatoNf`, "intertravamento" e "Revers…" presentes |

Grupos novos (números conferidos à mão):

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Reversão parada | partidas soltas, selos abertos | nenhuma bobina ligada |
| Partida 1 | 24 V em 240 Ω | K1 liga com 100 mA; K2 fica desligada |
| Soltar a partida 1 | selo de K1 | K1 continua ligada |
| Partida 2 com K1 ligada | NF de K1 aberto | K2 não liga, K1 não cai, aviso "intertravamento agindo" |
| Parada e depois partida 2 | NF de K1 fechado | K2 liga, K1 fica desligada |
| As duas partidas juntas | ciclo de 12 iterações | aviso "o comando não se estabiliza" |

**Feito:** contato NF auxiliar, rótulos 21-22, exemplo de reversão, aviso de intertravamento,
testes de cálculo e de tela, versão 1.51.0, CHANGELOG, inventário e este relatório.

**Evidência:** comandos, números e conferência do APK na tabela acima; o link público foi baixado
e o SHA-256 conferido contra o arquivo local.

**Critérios de aceitação atendidos:** (1) a reversão é resolvida numericamente, com tensão,
corrente e potência por componente; (2) K2 não liga com K1 ligado e o motivo é explicado no app;
(3) a sequência parada → outro sentido funciona; (4) comando que oscila é avisado, não inventado;
(5) há teste automático para o cálculo e para a tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular; a
leitura dos símbolos numa tela real não foi avaliada.

## 7. Problemas conhecidos, riscos e limitações

- **Intertravamento elétrico apenas:** não há trava mecânica, nem contato temporizado, nem
  contato de potência. A reversão aqui é de comando, não de motor.
- **Sem corrente alternada, sem motor, sem CLP e sem temporizador.**
- **As duas partidas apertadas ao mesmo tempo** produzem um comando que não estabiliza; o app
  avisa, mas não anima o chattering.
- **Contato NF ligado a uma bobina por vez**; sem contato NF de selo nem intertravamento triplo.
- **Grade maior no exemplo (8×5)**: em tela estreita os nós ficam mais próximos; o toque em alvos
  pequenos não foi medido em aparelho real.
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `build.gradle.kts` é gerado pelo `flutter create` e
  não fica no repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.51.0 (`https://files.catbox.moe/cgj87f.apk`) e abrir **CADeSIMU e
   elétrica ▸ Abrir simulador de circuitos ▸ Reversão com intertravamento**.
2. **Conferir**: apertar a partida 1 (K1 liga), apertar a partida 2 (não deve ligar K2), apertar a
   parada, apertar a partida 2 (K2 liga).
3. **Dizer o que ficou confuso** na grade 8×5: tamanho dos alvos, rótulos `K1-13/14` e `K1-21/22`.
4. **Decidir o próximo passo**: (a) contato de potência e motor em DC, (b) temporizador, (c)
   voltar ao restante da Fase 10B.

## 9. Próximos passos propostos

- Contato principal de potência e motor em corrente contínua, mantendo os limites escritos.
- Temporizador (retardo na energização) como contato auxiliar com tempo.
- Exportar o circuito em JSON próprio (formato com especificação conhecida), sem fingir `.cad`.
