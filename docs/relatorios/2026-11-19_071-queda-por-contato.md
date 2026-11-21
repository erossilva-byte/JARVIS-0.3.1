# Ajuste 071 — retardo na queda por contato (Fase 10)

## 1. Identificação

- **Versão:** 1.59.0+15900 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada mudou no núcleo web, no Electron,
  nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

Cada contato 67/68 passou a ter **o próprio retardo na queda**, em vez de os dois usarem o retardo do
temporizador. Depois que o temporizador perde energia, cada contato compara o relógio da queda com o
tempo dele: o de queda menor abre (ou fecha) primeiro e o de queda maior segura por mais tempo.
Deixar o campo em **0 s** mantém o comportamento anterior: usa o retardo base do temporizador.

O exemplo novo é o **Quedas diferentes no temporizador**, em 24 V: KT1 com atraso base de 2 s e queda
base de 2 s; o 67/68 NA tem atraso de 2 s e **queda de 1 s** (lâmpada L1), o 67/68 NF tem atraso de
2 s e **queda de 4 s** (lâmpada L2). Depois da parada, L1 apaga em 1 s e L2 só volta a acender em
4 s.

## 3. O que mudou no código

- **Motor (`flutter_app/lib/core/circuito.dart`)**
  - Novo `Circuito.atrasoQuedaDoContato(Elemento)` e `Circuito.contatosDe(id)`, que devolvem,
    respectivamente, a queda efetiva do contato e os contatos de um temporizador.
  - `_solucionar` compara o relógio da queda com a **queda de cada contato** (0 s cai no retardo
    base do temporizador).
  - Ajudantes `_contatoTemporizado`/`_contatoTemporizadoNf` aceitam `queda`.
  - Aviso do temporizador sem energia passou a dizer "ainda há contato segurando" e a citar que o
    retardo base é o padrão.
  - Exemplo novo **Quedas diferentes no temporizador**, em grade 8×5.
- **Tela (`flutter_app/lib/services/circuito_page.dart`)**
  - `_algumContatoAtrasado` decide quando o relógio da queda anda e quando o temporizador zera: o
    relógio só para depois da maior queda entre os contatos (sem contatos, vale o ajuste base).
  - Estado dos contatos, na lista e no desenho do tabuleiro, usa `atrasoQuedaDoContato`.
  - Editor do contato: campo `campo-queda-contato`, botão `aplicar-queda-contato` e o texto
    `queda-contato` ("Retardo na queda deste contato: N s (próprio)/(o do temporizador)").
  - A descrição do contato na lista mostra o atraso e a queda próprios quando ajustados.

## 4. Números conferidos

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Partida | KT1 energizado | L2 (NF) com 24 V / 5 W e L1 (NA) com 0 W |
| 2 s de subida | atraso de 2 s | L1 acende com 5 W e L2 apaga |
| Parada, queda 0 s | contatos acionados | L1 ainda com 5 W e L2 ainda apagada |
| 1 s de queda | queda do NA = 1 s | L1 cai para 0 W; o NF ainda segura (4 s) |
| 4 s de queda | queda do NF = 4 s | L2 volta a acender com 5 W; L1 continua apagada |
| Contato com queda 0 s | usa o retardo base | `atrasoQuedaDoContato` igual à queda do KT1 (2 s) |

## 5. O que mudou nos testes e na documentação

- `tool/circuito_test.dart`: grupos **48 a 52** (partida, 2 s de subida, parada com queda 0 s, 1 s e
  4 s de queda, e o contato com queda 0 s herdando o base). Total: **61 grupos**.
- `test/circuito_page_test.dart`: teste de tela novo "cada contato segura pela própria queda depois
  da parada". Total: **15 testes de tela**.
- O teste antigo da troca individual de tipo passou a conferir a troca pela descrição no editor, em
  vez da leitura da lâmpada, porque a lista de resultados sai da área construída ao rolar a página.
- `tests/test_circuito_flutter.py`: contrato estático passa a exigir `atrasoQuedaDoContato`, o
  exemplo novo, o campo da queda e este relatório.
- `CHANGELOG.md` (1.59.0) e `docs/INVENTARIO_DE_FUNCOES.md` atualizados.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **61 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **15 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **157 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ gerado, ver 6.1 |

### 6.1 APK

| Verificação | Comando | Resultado |
|---|---|---|
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ 117.199.936 bytes (117,2 MB) em 112,6 s |
| Pacote e versão | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.59.0`, `versionCode=15900` |
| Conteúdo | `strings lib/arm64-v8a/libapp.so` | `Quedas diferentes no temporizador` e `campo-queda-contato` presentes |
| SHA-256 | `sha256sum` | `8b10533002402e3505b6f2b8a092ec062354789c57b5b790a2f44ced8ca73c64` |
| Publicação | upload em `litter.catbox.moe` (72 h) | `https://litter.catbox.moe/wlwrw4.apk` |
| Conferência do download | baixado de volta e comparado | 117.199.936 bytes e SHA-256 igual ao local |

**Feito:** retardo na queda individual por contato, queda base como padrão, exemplo com quedas
diferentes, campo na tela, testes e documentação; versão 1.59.0.

**Evidência:** comandos e números acima; os testes de cálculo e de tela provam que, com o mesmo
relógio de queda, o contato de 1 s abre primeiro e o de 4 s segura mais tempo.

**Critérios de aceitação atendidos:** (1) cada contato tem o próprio retardo na queda; (2) queda 0 s
mantém o comportamento antigo; (3) há exemplo calculado com tempos diferentes; (4) há teste de
cálculo e de tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular.

## 7. Problemas conhecidos, riscos e limitações

**Limitações:** o tempo é por passos de 1 s, o relógio da subida e da queda continua sendo do
temporizador (o que é individual é o atraso e a queda de cada contato), e não há CA, motor de
indução, curva térmica, CLP nem leitura de `.cad`; nada foi testado em aparelho físico.

- **Tempo por passos:** o relógio só anda com **Avançar 1 s**; não existe animação.
- **Relógio compartilhado:** um contato com atraso maior que o ajuste base depende de o temporizador
  continuar energizado para o relógio crescer.
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `android/` é gerado pelo `flutter create` e não fica no
  repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.59.0 e abrir **CADeSIMU e elétrica ▸ Abrir simulador de circuitos ▸ Quedas
   diferentes no temporizador**.
2. **Conferir**: apertar a partida e avançar 2 s — L1 acende e L2 apaga; apertar a parada e avançar
   1 s — L1 apaga e L2 continua apagada; avançar até 4 s — L2 volta a acender.
3. **Testar o campo**: tocar num contato e mudar a **queda própria**; com 0 s ele volta a usar o
   retardo do temporizador.
4. **Dizer o que ficou confuso** entre o relógio do temporizador e o tempo de cada contato.

## 9. Próximos passos propostos

- Relógio próprio por contato, sem depender do temporizador.
- Um exemplo com dois temporizadores e quatro contatos.
