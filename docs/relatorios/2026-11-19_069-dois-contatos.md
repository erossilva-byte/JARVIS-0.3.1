# Ajuste 069 — dois contatos por temporizador (Fase 10)

## 1. Identificação

- **Versão:** 1.57.0+15700 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada mudou no núcleo web, no Electron,
  nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

O mesmo temporizador agora pode ter **os dois contatos ao mesmo tempo**: um 67/68 NA e um 67/68 NF.
Cada contato é escolhido um a um — no editor de qualquer contato temporizado há as opções **67/68 NA**
e **67/68 NF**, e trocar o tipo de um não mexe no outro. Contatos do mesmo tipo no mesmo temporizador
passam a ter rótulo numerado (`KT1-67/68`, `KT1-67/68 (2)`) para não se confundirem no diagnóstico.

O exemplo novo é o **Dois contatos do temporizador**, em 24 V: o KT1 conta 3 s em paralelo com a
bobina do K1; o 67/68 NF mantém a lâmpada L2 ("aguarde") acesa e o 67/68 NA acende a lâmpada L1
("pronto") só no fim do atraso. Aos 3 s o mesmo temporizador troca as duas lâmpadas.

## 3. O que mudou no código

- **Motor (`flutter_app/lib/core/circuito.dart`)**
  - `copiarCom` aceita `tipo`, para um contato virar NA ou NF no lugar, sem perder posição nem o
    temporizador escolhido.
  - `rotulos` numera os contatos do mesmo tipo no mesmo temporizador quando há mais de um.
  - Exemplo novo **Dois contatos do temporizador**, em grade 8×5, com os dois ramos de lâmpada.
- **Tela (`flutter_app/lib/services/circuito_page.dart`)**
  - `_trocarTipoContato` troca só o contato selecionado.
  - Editor do contato temporizado: chips **67/68 NA** (`contato-tipo-na`) e **67/68 NF**
    (`contato-tipo-nf`), ao lado do seletor de temporizador que já existia.

## 4. Números conferidos

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Partida | K1 em 24 V / 240 Ω e KT1 energizado | K1 puxa, KT1 conta; L2 com 24 V / 5 W e L1 com 0 W |
| Solta a partida | selo mantém K1 | K1 continua ligado e o KT1 continua contando |
| Aos 3 s | atraso completo | 67/68 NA fecha (L1 com 5 W) e 67/68 NF abre (L2 com 0 W) |
| Parada, retardo de queda zero | temporizador sem energia | K1 cai, L1 apaga e L2 volta a acender (5 W) |
| Contato trocado NA → NF | `copiarCom(tipo:)` | o contato passa a abrir com o atraso completo |

## 5. O que mudou nos testes e na documentação

- `tool/circuito_test.dart`: grupos **39 a 42** (partida com o NF acendendo L2, troca das duas
  lâmpadas aos 3 s, troca individual de tipo e rótulos, parada voltando ao repouso). Total:
  **51 grupos**.
- `test/circuito_page_test.dart`: teste de tela novo "dois contatos do temporizador trocam as
  lâmpadas aos 3 s", que também usa os chips de tipo. Total: **13 testes de tela**.
- `tests/test_circuito_flutter.py`: contrato estático passa a exigir o exemplo novo, `tipo:`,
  `_trocarTipoContato`, os chips de tipo e este relatório.
- `CHANGELOG.md` (1.57.0) e `docs/INVENTARIO_DE_FUNCOES.md` atualizados.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **51 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **13 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **155 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ gerado, ver 6.1 |

### 6.1 APK

| Verificação | Comando | Resultado |
|---|---|---|
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ 117.199.932 bytes (117,2 MB) em 121,1 s |
| Pacote e versão | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.57.0`, `versionCode=15700` |
| Conteúdo | `strings lib/arm64-v8a/libapp.so` | `Dois contatos do temporizador` e `contato-tipo-nf` presentes |
| SHA-256 | `sha256sum` | `e118533ce8c14ee7d17a04423b7107a742e8b28810a01a417eef9db1e4045f57` |
| Publicação | upload em `files.catbox.moe` | **falhou nesta data**; o APK foi entregue como arquivo do chat |

**Feito:** NA e NF no mesmo temporizador, escolha individual do tipo de cada contato, rótulos
numerados, exemplo com os dois contatos, testes e documentação; versão 1.57.0.

**Evidência:** comandos e números acima; o teste de cálculo prova que os dois contatos respondem ao
mesmo relógio, e o de tela prova que trocar um contato não mexe no outro.

**Critérios de aceitação atendidos:** (1) o mesmo temporizador tem um 67/68 NA e um 67/68 NF ao
mesmo tempo; (2) cada contato escolhe o tipo dele; (3) há exemplo calculado usando os dois; (4) há
teste de cálculo e de tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular.

## 7. Problemas conhecidos, riscos e limitações

**Limitações:** o tempo é por passos de 1 s, os contatos de um mesmo temporizador compartilham o
atraso e o retardo na queda (não há atraso por contato), e não há CA, motor de indução, curva
térmica, CLP nem leitura de `.cad`; nada foi testado em aparelho físico.

- **Tempo por passos:** o relógio só anda com **Avançar 1 s**; não existe animação.
- **Um atraso por temporizador:** todos os contatos dele fecham/abrem no mesmo instante.
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `android/` é gerado pelo `flutter create` e não fica no
  repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.57.0 e abrir **CADeSIMU e elétrica ▸ Abrir simulador de circuitos ▸ Dois
   contatos do temporizador**.
2. **Conferir**: apertar a partida — L2 ("aguarde") acende e L1 fica apagada; tocar no KT1 e usar
   **Avançar 1 s** três vezes — L1 acende e L2 apaga no mesmo instante.
3. **Testar a escolha individual**: tocar num dos contatos e trocar entre **67/68 NA** e **67/68
   NF**; o outro contato deve continuar como estava.
4. **Dizer o que ficou confuso** nos nomes dos dois contatos.

## 9. Próximos passos propostos

- Mais de um temporizador no mesmo circuito com atrasos diferentes (já funciona pelo motor, falta um
  exemplo).
- Atraso individual por contato, em vez de por temporizador.
