# Ajuste 070 — atraso próprio de cada contato (Fase 10)

## 1. Identificação

- **Versão:** 1.58.0+15800 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada mudou no núcleo web, no Electron,
  nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

Cada contato 67/68 passou a ter **o próprio atraso**, em vez de os dois esperarem o tempo do
temporizador. O temporizador continua sendo a fonte do relógio e do **ajuste base**; o contato com
atraso próprio compara esse relógio com o tempo dele. Deixar o campo em **0 s** mantém o
comportamento anterior: o contato usa o ajuste base do temporizador.

O exemplo novo é o **Contatos com tempos diferentes**, em 24 V: o KT1 tem ajuste base de 3 s, o
67/68 NA está ajustado em **1 s** e acende a lâmpada L1 no primeiro segundo; o 67/68 NF está ajustado
em **5 s** e só apaga a lâmpada L2 aos cinco segundos. O mesmo relógio serve aos dois.

## 3. O que mudou no código

- **Motor (`flutter_app/lib/core/circuito.dart`)**
  - Cada contato temporizado entra no conjunto de contatos acionados pelo **próprio atraso**
    (`e.atraso`, com 0 s caindo no `atraso` do temporizador), comparado ao relógio de subida e ao
    retardo na queda do temporizador.
  - Novo `Circuito.atrasoDoContato(Elemento)`, que devolve o atraso efetivo do contato.
  - Ajudantes `_contatoTemporizado` e `_contatoTemporizadoNf` aceitam `atraso`.
  - Diagnósticos: o temporizador informa o ajuste base; o contato aberto/fechado mostra o atraso que
    ele mesmo usa.
  - Exemplo novo **Contatos com tempos diferentes**, em grade 8×5.
- **Tela (`flutter_app/lib/services/circuito_page.dart`)**
  - Campo `campo-atraso-contato` com o botão `aplicar-atraso-contato` no editor do contato, mais o
    texto `atraso-contato` ("Atraso deste contato: N s (próprio)/(o do temporizador)").
  - O estado do contato, na lista e no desenho do tabuleiro, usa `atrasoDoContato`; o relógio do
    temporizador passou a mostrar "(ajuste base)".

## 4. Números conferidos

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Partida | KT1 energizado com ajuste base de 3 s | L2 (NF de 5 s) com 24 V / 5 W e L1 (NA de 1 s) com 0 W |
| 1 s de relógio | 1 s = atraso do NA | L1 acende com 5 W e L2 continua com 5 W |
| 4 s de relógio | 4 s < 5 s | as duas lâmpadas com 5 W |
| 5 s de relógio | 5 s = atraso do NF | L2 cai para 0 W e L1 continua com 5 W |
| Contato em 0 s | usa o ajuste base | `atrasoDoContato` igual ao atraso do KT1 (3 s) |
| Parada | temporizador sem energia | K1 cai, L1 apaga e L2 volta a acender |

## 5. O que mudou nos testes e na documentação

- `tool/circuito_test.dart`: grupos **43 a 47** (tempos próprios, 1 s, 5 s, atraso 0 s herdando o
  base e parada voltando ao repouso). Total: **56 grupos**.
- `test/circuito_page_test.dart`: teste de tela novo "cada contato usa o próprio atraso no mesmo
  temporizador". Total: **14 testes de tela**.
- A asserção antiga do diagnóstico do temporizador passou de "já fechou" para "o atraso base já
  completou", porque o texto mudou junto com o ajuste base.
- `tests/test_circuito_flutter.py`: contrato estático passa a exigir `atrasoDoContato`, o exemplo
  novo, o campo do atraso e este relatório.
- `CHANGELOG.md` (1.58.0) e `docs/INVENTARIO_DE_FUNCOES.md` atualizados.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **56 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **14 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **156 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ gerado, ver 6.1 |

### 6.1 APK

| Verificação | Comando | Resultado |
|---|---|---|
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ 117.199.936 bytes (117,2 MB) em 105,9 s |
| Pacote e versão | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.58.0`, `versionCode=15800` |
| Conteúdo | `strings lib/arm64-v8a/libapp.so` | `Contatos com tempos diferentes` e `campo-atraso-contato` presentes |
| SHA-256 | `sha256sum` | `31e2fee8736b02943868b581f7ff5e6d87a7d55fcbce2a50ead2f920144b372a` |
| Publicação | upload em `litter.catbox.moe` (72 h) | `https://litter.catbox.moe/1vl1mi.apk` |
| Conferência do download | baixado de volta e comparado | 117.199.936 bytes e SHA-256 igual ao local |

**Feito:** atraso individual por contato, ajuste base como padrão, exemplo com tempos diferentes,
campo na tela, testes e documentação; versão 1.58.0.

**Evidência:** comandos e números acima; os testes de cálculo e de tela provam que, com o mesmo
relógio, o contato de 1 s fecha primeiro e o de 5 s só depois.

**Critérios de aceitação atendidos:** (1) cada contato tem o próprio atraso; (2) o atraso 0 s mantém
o comportamento antigo; (3) há exemplo calculado com tempos diferentes; (4) há teste de cálculo e de
tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular.

## 7. Problemas conhecidos, riscos e limitações

**Limitações:** o tempo é por passos de 1 s, os contatos de um temporizador ainda compartilham o
relógio e o retardo na queda (o que é individual é o atraso), e não há CA, motor de indução, curva
térmica, CLP nem leitura de `.cad`; nada foi testado em aparelho físico.

- **Tempo por passos:** o relógio só anda com **Avançar 1 s**; não existe animação.
- **Relógio compartilhado:** um contato com atraso maior que o ajuste base depende de o temporizador
  continuar energizado para o relógio crescer.
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `android/` é gerado pelo `flutter create` e não fica no
  repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.58.0 e abrir **CADeSIMU e elétrica ▸ Abrir simulador de circuitos ▸ Contatos
   com tempos diferentes**.
2. **Conferir**: apertar a partida — L2 acende e L1 fica apagada; tocar no KT1 e usar **Avançar 1 s**
   uma vez — L1 acende e L2 continua acesa; avançar até 5 s — L2 apaga e L1 continua acesa.
3. **Testar o campo**: tocar num contato, mudar o **atraso próprio** para outro número e usar
   **Aplicar**; com 0 s ele volta a usar o tempo do temporizador.
4. **Dizer o que ficou confuso** na diferença entre ajuste base e atraso do contato.

## 9. Próximos passos propostos

- Retardo na queda individual por contato.
- Um exemplo com dois temporizadores e quatro contatos.
