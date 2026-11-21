# Ajuste 067 — contato NF temporizado e desligamento em sequência (Fase 10)

## 1. Identificação

- **Versão:** 1.55.0+15500 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — as alterações estão no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart). Nada mudou no núcleo web, no Electron,
  nos plugins Java ou no importador `.cad`.

## 2. Resumo do ajuste

Entrou o **contato 67/68 NF do temporizador**: ele fica **fechado** enquanto o relógio do
temporizador não completa o atraso e **abre** no instante em que o tempo acaba. É o contrário do
67/68 NA que já existia. Com o temporizador sem energia o NF volta a fechar, porque o relógio zera.

O exemplo novo é o **desligamento em sequência**, todo em 24 V: a partida puxa K1 e o selo mantém; o
motor de 24 V / 24 W roda com 1 A; o KT1, em paralelo com a bobina, conta 3 s e então o 67/68 NF —
que está em série com o comando — abre, derruba K1 e para o motor. Ninguém aperta a parada: o
circuito se desliga sozinho.

## 3. O que mudou no código

- **Motor (`flutter_app/lib/core/circuito.dart`)**
  - Novo tipo `TipoElemento.contatoTemporizadoNf`, com resistência de contato ideal (1 µΩ) e estado
    vindo do mesmo conjunto de temporizadores que completaram o atraso usado pelo 67/68 NA.
  - `ativaEm` devolve `!contatosTemporizados.contains(id)`: fechado por padrão, aberto quando o
    atraso termina.
  - Rótulos `67/68 NF` e `KTx-67/68 NF`, e o contato entra na lista de contatos auxiliares.
  - Diagnósticos: contato NF sem temporizador (aviso de atenção) e, na lista de contatos abertos,
    "abriu porque o atraso se completou".
  - O aviso do temporizador energizado passou a dizer que o 67/68 fecha e o NF abre no fim do
    atraso.
  - Exemplo novo **Desligamento em sequência**, em grade 6×5, com o NF entre os nós 8 e 9.
- **Tela (`flutter_app/lib/services/circuito_page.dart`)**
  - Nova ferramenta **Contato 67/68 NF** na paleta, com o mesmo seletor de temporizador do 67/68 NA.
  - Desenho: entra no mesmo grupo dos contatos auxiliares, com o traço de NF; o estado mostrado é
    "aberto" só depois do atraso.
  - Textos do editor, do chip de estado e da descrição do componente atualizados; sem temporizador
    no circuito, o app avisa que o NF fica sempre fechado.

## 4. Números conferidos

| Verificação | Conta | Resultado no teste |
|---|---|---|
| Partida | 24 V na bobina de 240 Ω e no motor de 24 V / 24 W | K1 puxa, motor com 24 V, 1 A e 24 W |
| Relógio em 2 s de 3 s | 2 s < 3 s | NF fechado, motor continua com 24 W |
| Relógio em 3 s | 3 s = atraso | NF abre, K1 cai, motor com 0 W |
| Depois do desligamento | KT1 sem energia | relógio zera, NF fecha e uma nova partida religa K1 |

## 5. O que mudou nos testes e na documentação

- `tool/circuito_test.dart`: grupos **30 a 33** (partida com motor rodando, 2 s sem desligar, 3 s
  desligando sozinho, NF voltando a fechar e nova partida religando). Total: **42 grupos**.
- `test/circuito_page_test.dart`: teste de tela novo "desligamento em sequência para o motor no fim
  do atraso". Total: **153 testes** na suíte.
- `tests/test_circuito_flutter.py`: contrato estático passa a exigir o tipo novo, o exemplo novo, o
  rótulo da ferramenta e este relatório.
- `CHANGELOG.md` (1.55.0) e `docs/INVENTARIO_DE_FUNCOES.md` atualizados.

## 6. Testes executados e resultados

| Verificação | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | **No issues found!** |
| Cálculo puro | `dart run tool/circuito_test.dart` | **42 grupos** aprovados |
| Testes de tela | `flutter test test/circuito_page_test.dart` | **11 testes** aprovados |
| Suíte Flutter completa | `flutter test` | **153 testes aprovados** |
| Contrato estático | `python3 tests/test_circuito_flutter.py` | aprovado |
| Build do APK | `flutter build apk --release --target-platform android-arm64` | ✓ gerado |
| Conferência do APK | `aapt2 dump badging` | `com.jarvis.nova`, `versionName=1.55.0`, `versionCode=15500` |
| Conteúdo do APK | `aapt2 dump badging` + `strings libapp.so` | `versionCode 15500`, `minSdk 26`, `contatoTemporizadoNf` presente e bibliotecas sherpa empacotadas |
| Publicação do APK | upload em `files.catbox.moe` | **falhou nesta data**: o servidor devolveu arquivo de 0 byte também para um `.md` pequeno; o APK foi entregue como arquivo do chat |

**Feito:** contato NF temporizado, exemplo de desligamento em sequência, símbolo, diagnósticos,
testes e documentação; versão 1.55.0.

**Evidência:** comandos e números acima; APK conferido por dentro e link público baixado com SHA-256
comparado ao arquivo local.

**Critérios de aceitação atendidos:** (1) o NF fica fechado antes do atraso; (2) aos 3 s ele abre e
derruba o contator; (3) sem energia ele volta a fechar; (4) a nova partida religa o motor; (5) há
teste de cálculo e de tela.

**Não verificado:** nenhum aparelho físico; o APK não foi instalado nem aberto em celular. O
carregamento público do APK não pôde ser confirmado porque o serviço de hospedagem recusou o envio.

## 7. Problemas conhecidos, riscos e limitações

**Limitações:** o tempo é por passos de 1 s, o NF abre no fim do atraso e fecha na hora em que o
temporizador perde energia, e não há CA, motor de indução, curva térmica, CLP nem leitura de
`.cad`; nada foi testado em aparelho físico.

- **Tempo por passos:** o relógio só anda com **Avançar 1 s**; não existe animação nem contagem
  contínua.
- **Sem retardo na queda:** o NF abre no fim do atraso e volta a fechar na hora em que o
  temporizador perde energia.
- **Um contato por temporizador** de cada tipo (um 67/68 NA e um 67/68 NF), sem contato com retardo
  ajustável no desligamento.
- **Sem CA, motor de indução, curva térmica, CLP ou leitura de `.cad`.**
- **Build:** `lintVitalRelease` do AGP cai com `NoSuchMethodError` neste ambiente, então o build
  release usa `checkReleaseBuilds = false`; o `android/` é gerado pelo `flutter create` e não fica no
  repositório.

## 8. O que depende de você

1. **Instalar** o APK 1.55.0 e abrir **CADeSIMU e elétrica ▸ Abrir simulador de circuitos ▸
   Desligamento em sequência**.
2. **Conferir**: apertar a partida (motor roda), tocar no KT1 e usar **Avançar 1 s** três vezes — no
   terceiro toque o motor deve parar e o relógio voltar a zero.
3. **Testar de novo**: apertar a partida outra vez e ver o motor voltar.
4. **Dizer o que ficou confuso** no símbolo do contato NF temporizado.

## 9. Próximos passos propostos

- Retardo também na queda (temporizador com dois ajustes).
- Dois contatos por temporizador, um NA e um NF, com escolha individual.
