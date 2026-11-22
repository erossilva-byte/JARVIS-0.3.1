# Ajuste 081 — histórico do que o JARVIS executou (Fase 14)

## 1. Identificação

- **Versão:** 1.68.0+16800
- **Data:** 2026-11-20
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** `JARVIS-Nova-1.68.0-historico.apk` (arm64, release, 117 825 904 bytes)
- **SHA-256:** `b43082b648377b056dc856cb2de8c5e2b48836a7245287f36e5b84365fa463d2`
- **Download:** https://files.catbox.moe/lj6cly.apk
- **Plataformas afetadas:** Android (Kotlin e Flutter/Dart). Windows não foi tocado.

## 2. Resumo do ajuste

O pedido foi: saber **o que o JARVIS executou por voz, com horário e resultado,
para conferir depois**. Antes, o comando rodava e a informação desaparecia junto
com a conversa — não havia como lembrar o que foi pedido nem se aquilo tinha
dado certo.

Agora cada comando executado entra numa lista guardada **no próprio aparelho**,
com o horário, o que foi pedido, a ação decidida, se foi executado ou não, a
resposta que veio do Android e a origem (voz, segundo plano, digitado ou teste).
A lista é a mesma para a tela aberta e para o comando que chega pelo serviço em
segundo plano, e fica limitada aos 100 registros mais recentes.

O histórico é gravado pelo lado Android (`SharedPreferences`, chave
`historico_acoes`) porque o serviço de segundo plano precisa registrar o comando
mesmo com a tela fechada. O Flutter só lê, mostra e pede a limpeza.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivo |
|---|---|---|---|
| Registro no aparelho | nova função | Lista limitada a 100, mais recente primeiro, com horário, pedido, ação, resultado e mensagem | `android/JarvisFundo.kt` |
| Canais do app | melhoria | `historicoExecucoes` e `registrarExecucao` para ler e gravar a lista | `android/JarvisFundoCanal.kt` |
| Comando em segundo plano | melhoria | Grava o comando ouvido com `origem = segundo_plano` e o texto realmente escutado | `android/KwsForegroundService.kt` |
| Modelo do histórico | nova função | Ordena do mais recente, corta em 100, descarta registro sem pedido e não aceita `ok` não booleano como sucesso | `lib/core/historico_voz.dart` |
| Ponte Flutter | nova função | Fala com o mesmo canal do segundo plano e trata a ausência do Android sem inventar sucesso | `lib/services/historico_voz_service.dart` |
| Tela do histórico | nova tela | Lista por dia, com hora, selo Executado/Não executado, pedido, ação, mensagem e origem; resumo, atualizar e limpar com confirmação | `lib/services/historico_voz_page.dart` |
| Resultado do comando | melhoria | `ResultadoComando.acao` passa a carregar a ação decidida até a tela | `lib/services/comandos_android_service.dart` |
| Conversa | melhoria | Todo comando falado ou digitado é registrado com a origem certa; comando bloqueado no limite não aparece como executado | `lib/services/voice_conversation_page.dart` |
| Entradas para a tela | melhoria | Atalho em Comandos do Android e botão na tela de segundo plano | `comandos_android_page.dart`, `segundo_plano_page.dart` |
| Provas | melhoria | Teste puro, teste de widget e contrato estático | `tool/historico_voz_test.dart`, `test/historico_voz_page_test.dart`, `tests/test_historico_voz_flutter.py` |

Regras de honestidade aplicadas:

- **O resultado vem do Android, não da conversa.** Um comando bloqueado pelo
  limite de execuções é registrado como “Não executado”, mesmo que o texto tenha
  sido entendido.
- **Uma lista só, com a origem marcada.** Voz, segundo plano, digitado e teste
  entram no mesmo histórico; dá para saber de onde veio cada linha.
- **Só o texto fica guardado.** Nenhum áudio é gravado e nada sai do aparelho —
  não há rede no caminho do histórico.
- **A limpeza pede confirmação** e apaga também a “última ação”, para não sobrar
  um vestígio do que foi apagado.
- **Nada de permissão nova, dependência nova ou nuvem.**

Correções de apoio na suíte (não mudam o que o app faz):

- As **travas de versão** dos contratos 077–080 passaram de `1.67.0` para
  `1.68.0+16800`, como em todo bloco que sobe a versão.
- Dois testes puros (`historico_voz_test.dart` e `localizacao_test.dart`) usavam
  `print`; viraram `stdout.writeln`, então `flutter analyze` fica sem nenhum
  aviso e `test:all` não para mais nesse ponto.
- A checagem de idempotência do manifesto Android passou a contar **os dois**
  receptores que o preparo insere (`JarvisWidgetProvider` e
  `JarvisAgendaReceiver`), cada um uma única vez; antes ela esperava um só.
- A checagem “modelos não são embarcados no APK” (1.9.0) passou a ignorar o
  detector da palavra de ativação em `assets/kws` — que é embutido de propósito —
  e a pasta `build/`, que é saída de compilação. Os pacotes de voz continuam
  proibidos no APK.

## 4. Evidência

| Prova | Comando | Resultado |
|---|---|---|
| Teste puro do modelo | `dart run tool/historico_voz_test.dart` | Aprovado |
| Análise estática | `flutter analyze --no-fatal-infos` | Sem erros (só os `avoid_print` já existentes nos testes puros) |
| Suíte Flutter | `flutter test` | **191 testes aprovados** |
| Contrato do histórico | `python3 tests/test_historico_voz_flutter.py` | Aprovado |
| Suíte completa | `npm run test:all` | **Aprovada** (todos os passos, `EXIT_TEST_ALL=0`) |
| Contratos de apoio | `test_microfone_fundo_flutter.py`, `test_fundo_flutter.py`, `test_status_celular_flutter.py`, `test_comandos_android.py`, `test_dart_core.py` | Todos aprovados (as travas de versão dos contratos 077–080 foram atualizadas para 1.68.0) |
| APK release arm64 | `flutter build apk --release --target-platform android-arm64` | Construído (117 825 904 bytes) |

## 5. Limites conhecidos

- **Sem aparelho.** O histórico foi verificado por teste puro, widget e contrato
  estático; o preenchimento real na tela do Poco X7 continua não verificado.
- **100 registros.** Ao passar disso, o mais antigo sai — o histórico não é um
  arquivo permanente nem substitui um backup.
- **Só comandos do JARVIS.** Conversa solta, pergunta respondida sem ação e
  comando que nem chegou a ser entendido não entram: o histórico é do que foi
  executado (ou tentado), não da conversa inteira.
- **Limpar é definitivo.** A confirmação evita acidente, mas não há desfazer.
- **O segundo plano depende do serviço estar de pé**, como no bloco 080.

## 6. Não verificado

- Preenchimento do histórico no Poco X7 falando de verdade (“Jarvis, liga a
  lanterna” com a tela aberta e com o app fechado).
- Se o HyperOS mantém o serviço em primeiro plano tempo suficiente para registrar
  o comando do segundo plano.
- Aparência da tela do histórico em tela pequena de celular real.
- Horário com o fuso do aparelho e a virada de dia (meia-noite) na lista.

## 7. Próximo passo sugerido

Instalar o APK e conferir, nesta ordem: (1) dizer “Jarvis” e “liga a lanterna”
com o app aberto; (2) abrir Comandos do Android → Histórico e ver a linha com
hora, ação e “Executado”; (3) fechar o app, chamar “Jarvis” e pedir o volume;
(4) reabrir o histórico e ver a origem “Segundo plano”; (5) pedir um app sem a
autorização de sobreposição e conferir se aparece “Não executado” com a
mensagem do Android; (6) limpar o histórico e confirmar que a lista fica vazia.
