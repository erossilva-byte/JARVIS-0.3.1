# Ajuste 068 — retardo na queda e desligamento temporizado (Fase 10)

## 1. Identificação

- **Versão:** 1.56.0+15600 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada mudou no núcleo web, no Electron,
  nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

O temporizador passou a ter **dois ajustes**: o atraso de subida (o que já existia) e o **retardo na
queda**. Com o retardo na queda maior que zero, o contato 67/68 **demora a abrir** depois que o
temporizador perde energia — ele continua acionado até o relógio da queda vencer. Assim o mesmo
contato demora a fechar (na energização) e demora a abrir (na desenergização), como no temporizador
com retardo na queda de um painel real.

O exemplo novo é o **desligamento temporizado**, em 24 V: a partida puxa K1 e o motor de 24 V / 24 W
roda com 1 A; o KT1 fica em paralelo com a bobina e conta 3 s; o 67/68 fica em paralelo com o
contato de potência. Ao apertar a parada o K1 cai, o KT1 perde energia, mas o motor **continua
rodando** por mais 3 s, até o 67/68 abrir. Com `atrasoQueda = 0` o contato abre na hora, como antes.

## 3. O que mudou no código

- **Motor (`flutter_app/lib/core/circuito.dart`)**
  - Novo campo `atrasoQueda` em `Elemento`, copiado em `copiarCom`, com helper `_temporizador(...,
    queda:)`.
  - `simular` recebe `temposQueda`: segundos desde que o temporizador perdeu energia.
  - Regra do contato acionado: energizado, vale `tempos >= atraso`; sem energia, continua acionado
    enquanto `tempos >= atraso` **e** `temposQueda < atrasoQueda`.
  - `_solucionar` devolve `temporizadoresAcionados`, usado pelos contatos 67/68 NA e NF.
  - Aviso novo: "está sem energia e ainda segura o contato: N s de M s do retardo na queda".
  - Exemplo novo **Desligamento temporizado**, em grade 7×5.
- **Tela (`flutter_app/lib/services/circuito_page.dart`)**
  - Estado `temposQueda`; `_fixarRelogios` zera o temporizador quando o retardo na queda vence (a
    próxima energização conta tudo de novo) e `_avancarTempo` conta subida ou queda, conforme o
    caso.
  - `_acionado` e `_contatoTemporizadoFechado` usam os dois relógios, tanto no estado quanto no
    pintor do tabuleiro.
  - Editor do temporizador: chip **Queda: N s de M s** (`relogio-queda`), campo
    `campo-atraso-queda` e botão `aplicar-atraso-queda`; o seletor de temporizador do 67/68 aceita
    também o NF.

## 4. Números conferidos

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Partida | 24 V no motor de 24 V / 24 W | K1 puxa, motor com 24 V, 1 A e 24 W |
| 3 s de subida | relógio = atraso | 67/68 fecha e fica pronto para segurar |
| Parada | bobina sem tensão | K1 cai, `temporizadoresAtivos` vazio, motor **ainda com 24 W** |
| 2 s de queda | 2 s < 3 s | 67/68 fechado, motor com 24 W |
| 3 s de queda | 3 s = retardo | 67/68 abre, motor com **0 W** |
| `atrasoQueda = 0` | queda zero | contato abre na hora (comportamento antigo) |

## 5. O que mudou nos testes e na documentação

- `tool/circuito_test.dart`: grupos **34 a 38** (partida com motor rodando, 2 s de queda ainda
  ligado, 3 s desligando, retardo zero abrindo na hora e relógios coerentes). Total: **47 grupos**.
- `test/circuito_page_test.dart`: teste de tela novo "desligamento temporizado segura o motor no
  retardo da queda", lendo a medição na linha do próprio motor. Total: **12 testes de tela**.
- `tests/test_circuito_flutter.py`: contrato estático passa a exigir `atrasoQueda`, `temposQueda`, o
  exemplo novo, os três identificadores da tela e este relatório.
- `CHANGELOG.md` (1.56.0) e `docs/INVENTARIO_DE_FUNCOES.md` atualizados.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **47 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **12 testes** aprovados |
| Suíte Flutter completa | `flutter test` | ver seção 6.1 |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ver seção 6.2 |

### 6.1 Suíte completa

`flutter test` — **154 testes aprovados**, sem falhas.

### 6.2 APK

| Verificação | Comando | Resultado |
|---|---|---|
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ 117.199.936 bytes (117,2 MB) em 166,3 s |
| Pacote e versão | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.56.0`, `versionCode=15600`, rótulo `J.A.R.V.I.S. Nova` |
| Conteúdo | `strings lib/arm64-v8a/libapp.so` | `Desligamento temporizado` e `aplicar-atraso-queda` presentes |
| Bibliotecas nativas | `unzip -l` | 9 entradas `libsherpa*`, AAR do sherpa empacotado |
| SHA-256 | `sha256sum` | `c66ae9251dd28dee6c67a941a1db539cdfe63a871fe6bbfbbf0a709ae83cf5ae` |
| Publicação | upload em `files.catbox.moe` e `0x0.st` | **falhou nesta data** (tempo esgotado); o APK foi entregue como arquivo do chat |

**Feito:** retardo na queda no temporizador, exemplo de desligamento temporizado, chip e campo do
retardo na tela, testes e documentação; versão 1.56.0.

**Evidência:** comandos e números acima; o teste de tela antigo do desligamento em sequência
continua passando, o que prova que `atrasoQueda = 0` mantém o comportamento anterior.

**Critérios de aceitação atendidos:** (1) o contato demora a fechar e demora a abrir; (2) aos 3 s de
queda o motor para; (3) o relógio da queda aparece e não anda enquanto o temporizador está
energizado; (4) retardo zero reproduz o comportamento antigo; (5) há teste de cálculo e de tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular.

## 7. Problemas conhecidos, riscos e limitações

**Limitações:** o tempo é por passos de 1 s na subida e na queda, o retardo é por temporizador e não
por contato, e não há CA, motor de indução, curva térmica, CLP nem leitura de `.cad`; nada foi
testado em aparelho físico.

- **Tempo por passos:** o relógio só anda com **Avançar 1 s**; não existe animação nem contagem
  contínua, nem para a subida nem para a queda.
- **Um ajuste de queda por temporizador**, em segundos inteiros; sem retardo ajustável por contato.
- **Um contato de cada tipo por temporizador** (67/68 NA e 67/68 NF).
- **Sem CA, motor de indução, curva térmica, CLP ou leitura de `.cad`.**
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `android/` é gerado pelo `flutter create` e não fica no
  repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.56.0 e abrir **CADeSIMU e elétrica ▸ Abrir simulador de circuitos ▸
   Desligamento temporizado**.
2. **Conferir**: apertar a partida (motor roda); tocar no KT1 e usar **Avançar 1 s** três vezes para
   o contato fechar; apertar a parada e ver o motor **continuar**; tocar no KT1 outra vez e avançar
   1 s duas vezes (motor ainda roda) e uma terceira (motor para).
3. **Conferir o outro exemplo**: em **Desligamento em sequência** o motor deve parar na hora em que o
   NF abre, sem retardo.
4. **Dizer o que ficou confuso** no campo do retardo na queda.

## 9. Próximos passos propostos

- Dois contatos por temporizador, um NA e um NF, com escolha individual.
- Retardo na queda ajustável por contato, em vez de por temporizador.
