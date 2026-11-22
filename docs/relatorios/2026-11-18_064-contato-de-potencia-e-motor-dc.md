# Ajuste 064 — contato de potência e motor DC (Fase 10)

## 1. Identificação

- **Versão:** 1.52.0+15200 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-18.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Artefato:** `JARVIS-Nova-1.52.0-motor-dc.apk`, 117.134.224 bytes, SHA-256
  `3112b0d28e41e0c171d2fab239f7e56c32ad8f5468a8e0b35a29697391a419c4`, em
  `https://files.catbox.moe/f4r1w3.apk`. Build de teste, assinado com a chave de depuração, ABI ARM.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada foi alterado no núcleo web, no
  Electron, nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

O simulador passou a ter **circuito de potência**: o **contato principal do contator (1-2)** e o
**motor de corrente contínua**. O contato fecha junto com a bobina, e o motor entra como carga com
tensão e potência nominais (24 V / 24 W → 24 Ω → 1 A em 24 V). O exemplo novo é a **partida direta
de motor DC**, com comando e potência no mesmo esquema, e mostra os números certos: bobina com
100 mA, motor com 1 A e fonte entregando 1,1 A. O motor é carga resistiva **de propósito**: a
corrente de partida de um motor real é várias vezes maior e o app diz isso na tela.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Contato principal de potência (1-2) | nova função | Ligar e desligar a carga pelo contator, separado do comando | `flutter_app/lib/core/circuito.dart` (`TipoElemento.contatoPotencia`) |
| Motor DC como carga nominal | nova função | Ter a carga que o contato de potência comanda, com números reais do modelo | `TipoElemento.motor`, `Elemento.resistencia` |
| Exemplo de partida direta de motor | nova função | Um esquema completo com comando e potência calculados | `exemplosCircuito` (8 circuitos, grade 6×5) |
| Diagnósticos do motor | nova função | Avisar acima e abaixo da tensão nominal | avisos em `_solucionar` |
| Símbolos e editor | melhoria | Montar contato de potência e motor sem WebView | `flutter_app/lib/services/circuito_page.dart` |
| Limites reescritos na tela | melhoria | Deixar claro que a corrente de partida real não está no modelo | texto do simulador |
| Versão | melhoria | Marcar a entrega | `flutter_app/pubspec.yaml` 1.52.0+15200 |

### Como a partida do motor é calculada

1. O comando é resolvido primeiro, como nos ajustes 062 e 063: partida (NA), selo (NA) e bobina.
2. Com a bobina ligada, o contato principal `K1-1/2` fecha (1 µΩ) e o motor entra na malha.
3. O motor é `R = Vnom² / Pnom`: 24 V e 24 W dão 24 Ω, então em 24 V passa 1 A e a potência é
   24 W. A bobina, de 240 Ω, consome 100 mA. A fonte entrega 1,1 A e 26,4 W no total.
4. Sem contator puxado, o contato principal fica aberto e o motor aparece com 0 V / 0 A, com aviso
   de que o contator não puxou — nada de inventar rotação ou corrente.
5. Motor acima de 110% da nominal gera aviso de sobreaquecimento; abaixo de 90% avisa que a
   potência do modelo cai (num motor real a rotação também cai).

## 4. Inventário de funções (trecho novo)

| Função | Android | Windows | Estado | Evidência | Permissão ou requisito | Limitações |
|---|---|---|---|---|---|---|
| Contato principal de potência (1-2) | Sim | Não | Verificado no código | teste "motor parado: contato de potência aberto" | — | Um contato por bobina, sem reversão de potência |
| Motor DC com tensão e potência nominais | Sim | Não | Verificado no código | 24 V / 24 W → 1 A e 24 W; fonte com 1,1 A | — | Carga resistiva: sem corrente de partida, inércia, conjugado ou rotação |
| Partida direta de motor (exemplo) | Sim | Não | Verificado no código | 5 grupos de cálculo + teste de tela | — | Comando e potência em DC, sem proteção térmica |
| Avisos de tensão do motor | Sim | Não | Verificado no código | teste "motor acima da nominal" | — | Só o modelo, não o comportamento térmico real |
| Motor de indução / corrente alternada | Não | Não | Fora de escopo | — | — | Exigiria modelo de CA e outro cálculo |

## 5. Mudanças desde o relatório anterior (063)

- **Novo:** contato principal de potência, motor DC, exemplo de partida direta de motor, avisos de
  tensão do motor e um teste de tela novo.
- **Mudou:** o texto de limites do simulador agora cita o motor como carga resistiva e diz que a
  corrente de partida real não é simulada.
- **Sem regressão:** `flutter analyze` limpo; suíte Flutter de 149 para **150 testes**; grupos de
  cálculo puro de 26 para **32**.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **32 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **8 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **150 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | **✓ Built app-release.apk (117,1 MB)** |
| Conferência do APK | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.52.0`, `versionCode=15200` |
| Conteúdo do APK | `strings libapp.so` | `contatoPotencia` e "Partida direta de motor DC" presentes |
| Integridade do download | `curl` do link público + `sha256sum` | SHA-256 igual ao do arquivo local |

Números conferidos à mão nos testes:

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Motor parado | contato `K1-1/2` aberto | 0 V, 0 A, aviso "contator não puxou" |
| Partida apertada | bobina 24 V / 240 Ω; motor 24 V / 24 W | bobina 100 mA; motor 24 V, 1 A, 24 W |
| Corrente da fonte | 1 A + 0,1 A | **1,1 A** e 26,4 W nas cargas |
| Soltar a partida | selo de K1 | motor continua com 1 A |
| Parada | comando aberto | motor volta a 0 A |
| Motor em 48 V | nominal 24 V | aviso de sobreaquecimento |

**Feito:** contato principal de potência, motor DC, exemplo de partida direta de motor,
diagnósticos de tensão do motor, testes de cálculo e de tela, versão 1.52.0, CHANGELOG, inventário
e este relatório.

**Evidência:** comandos, números e conferência do APK na tabela acima; o link público foi baixado
e o SHA-256 comparado com o arquivo local.

**Critérios de aceitação atendidos:** (1) o motor é alimentado só quando o contator puxa;
(2) tensão, corrente e potência do motor e da bobina aparecem calculadas; (3) o app declara que a
corrente de partida real não está no modelo; (4) há teste automático do cálculo e da tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular; a
leitura dos símbolos de potência numa tela real não foi avaliada.

## 7. Problemas conhecidos, riscos e limitações

- **Motor como carga resistiva:** sem força contra-eletromotriz, sem corrente de partida (que num
  motor real é várias vezes a nominal), sem inércia, conjugado, rotação ou aquecimento. O app diz
  isso na tela; não serve para dimensionar proteção de motor.
- **Sem corrente alternada e sem motor de indução.**
- **Sem contato reversor de potência, sem proteção térmica e sem temporizador.**
- **Fios e contatos ideais (1 µΩ)**, sem queda real.
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `build.gradle.kts` é gerado pelo `flutter create` e
  não fica no repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.52.0 (`https://files.catbox.moe/f4r1w3.apk`) e abrir **CADeSIMU e
   elétrica ▸ Abrir simulador de circuitos ▸ Partida direta de motor DC**.
2. **Conferir**: apertar a partida (motor com 1 A e 24 W, bobina com 100 mA), soltar (o selo
   mantém), apertar a parada (motor para).
3. **Dizer o que ficou confuso**: símbolo do motor, contato de potência, valores na tela.
4. **Decidir o próximo passo**: (a) temporizador, (b) proteção térmica/relé de sobrecarga no
   modelo, (c) voltar ao restante da Fase 10B.

## 9. Próximos passos propostos

- Relé de sobrecarga (térmico) como elemento que desarma por corrente acima do ajuste.
- Temporizador com retardo na energização, para partida estrela-triângulo didática.
- Exportar o circuito em JSON próprio (formato com especificação conhecida), sem fingir `.cad`.
