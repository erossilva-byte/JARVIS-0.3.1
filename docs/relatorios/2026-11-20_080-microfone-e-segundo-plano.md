# Ajuste 080 — microfone confiável, comando no segundo plano e abrir apps (Fase 14)

## 1. Identificação

- **Versão:** 1.67.0+16700
- **Data:** 2026-11-20
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** `JARVIS-Nova-1.67.0-microfone.apk` (arm64, release, 117 760 080 bytes)
- **SHA-256:** `87ad7254d6e8a2cfe38d17d1ff4b86256430409b6214f5ac0e6b286b53c79d24`
- **Download:** https://files.catbox.moe/gplsic.apk
- **Plataformas afetadas:** Android (Kotlin e Flutter/Dart). Windows não foi tocado.

## 2. Resumo do ajuste

O relato no aparelho foi direto: falar com o JARVIS e receber **“Não consegui
entender o comando. Tente falar novamente.”**. O código mostrava três motivos
possíveis e todos foram tratados:

1. **Dois microfones ao mesmo tempo.** Quando a palavra de ativação abria a tela,
   o detector local (sherpa-onnx) voltava a ligar antes de o reconhecedor do
   comando começar. Os dois disputavam a captura e o reconhecedor recebia
   silêncio — o Android devolvia `ERROR_NO_MATCH`. Agora o serviço **reserva o
   microfone para o comando**, solta o `AudioRecord` do detector e a tela **não
   religa o KWS** enquanto o comando está em andamento.
2. **Comando curto cortado cedo.** “Abrir WhatsApp” era concluído antes da fala
   terminar. Foram pedidos 2 s de silêncio para concluir, 1,5 s de silêncio
   provável e 1 s de fala mínima — no comando aberto e no segundo plano.
3. **Tela bloqueada pelo Android.** Sem “Exibir sobre outros apps”, o Android não
   deixa o serviço trazer o app para a frente; o JARVIS tentava abrir a tela e
   ficava sem comando nenhum. Agora, nesse caso, **o microfone funciona no
   segundo plano** e a limitação é dita em vez de o comando sumir.

Além disso, “não entendi” ganhou **uma segunda escuta automática** e o pacote
offline de português ausente passou a ser explicado com o caminho do ajuste no
Android — sem nenhum reconhecedor de nuvem.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivo |
|---|---|---|---|
| Reserva do microfone | correção | Um microfone por vez entre detector e comando; `comandoAtivo`, `pausarMotor` e `ACTION_PAUSE` | `KwsForegroundService.kt` |
| Estado do comando | melhoria | `comandoAtivo` no `statusMap`, `start` recusado enquanto o comando usa o microfone | `MainActivity.kt` |
| Segunda escuta | nova função | Repetição automática em “não entendi”/silêncio, uma vez, com aviso falado | `MainActivity.kt` |
| Tempo de escuta | correção | Folga de silêncio e de fala mínima no comando e no fundo | `MainActivity.kt`, `JarvisEscutaFundo.kt` |
| Pacote offline ausente | melhoria | Mensagem com o caminho do ajuste e aviso de que nada vai para a nuvem | `MainActivity.kt`, `JarvisEscutaFundo.kt` |
| Comando sem a tela na frente | correção | Serviço ouve e executa quando a sobreposição não está autorizada | `KwsForegroundService.kt` |
| Autorizar abrir apps | melhoria | Botão no aviso “JARVIS ativo” que abre o ajuste do Android | `KwsForegroundService.kt` |
| Estado na interface | melhoria | `KwsStatus.comandoAtivo` e a tela não religa o detector | `lib/services/kws_bridge.dart`, `lib/home_screen.dart` |
| Limites do segundo plano | documentação | Diz o que funciona sem a sobreposição (lanterna e volume) e o que não | `lib/core/fundo.dart` |
| Contratos | melhoria | `test_fundo_flutter.py` ampliado e novo `test_microfone_fundo_flutter.py` | `tests/` |

Regras de honestidade aplicadas:

- **Nenhum reconhecedor de nuvem.** Continua só o `createOnDeviceSpeechRecognizer`
  com `EXTRA_PREFER_OFFLINE`; o contrato falha se `createSpeechRecognizer`
  aparecer em `MainActivity.kt` ou `JarvisEscutaFundo.kt`.
- **Silêncio não é sucesso.** “Não entendi”, “nenhuma fala detectada” e “pacote
  ausente” são mensagens diferentes, e nenhuma delas finge que o comando rodou.
- **A limitação do Android é dita**, não contornada: abrir app no segundo plano
  continua exigindo “Exibir sobre outros apps”, com botão para autorizar.
- **Nada de permissão nova** e nenhuma dependência nova.

## 4. Evidência

| Prova | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | Limpo (só o `avoid_print` já existente no teste puro 079) |
| Suíte Flutter | `flutter test` | **186 testes aprovados** |
| Contrato do microfone | `python3 tests/test_microfone_fundo_flutter.py` | Aprovado |
| Contrato do segundo plano | `python3 tests/test_fundo_flutter.py` | Aprovado (ampliado com o microfone e a pausa do detector) |
| Contratos de versão | `test_engenharia_flutter.py`, `test_tarefas_flutter.py`, `test_seguranca_flutter.py`, `test_status_celular_flutter.py`, `test_comandos_android.py` | Todos aprovados |
| APK release arm64 | `flutter build apk --release --target-platform android-arm64` | Construído (117 760 080 bytes). A primeira tentativa falhou na compilação Kotlin de `JarvisEscutaFundo.kt` (concatenação de texto quebrada em várias linhas); corrigida, o build passou |

## 5. Limites conhecidos

- **Sem aparelho.** Nada foi instalado no Poco X7. A corrida de microfone, a
  segunda escuta, o tempo de silêncio e o botão de autorização continuam **não
  verificados** em hardware real.
- **Sem o pacote offline pt-BR, não há transcrição.** O app explica e oferece o
  caminho do ajuste, mas não instala o pacote por você e não usa a nuvem.
- **Uma repetição por comando.** Duas tentativas evitam laço infinito; se as duas
  falharem, a mensagem pede para chamar o JARVIS de novo.
- **O microfone no segundo plano depende da escuta ligada** e de o Android não
  encerrar o serviço em primeiro plano (economia de bateria do HyperOS pode
  encerrar).
- **Abrir apps e alarme com o app fechado** continua dependendo da autorização de
  sobreposição; sem ela, só lanterna e volume rodam no fundo.

## 6. Não verificado

- Voz real, ruído ambiente, sotaque e microfone do Poco X7.
- Se o pacote offline de português está instalado no aparelho.
- Comportamento do HyperOS ao segurar o microfone (serviço em primeiro plano) e ao
  tentar abrir outro app a partir do serviço.
- Notificação “JARVIS ativo” com o botão novo e o retorno do ajuste de
  sobreposição.

## 7. Próximo passo sugerido

Instalar o APK e conferir, nesta ordem: (1) dizer “Jarvis” e “abrir WhatsApp” com
o app aberto, duas vezes seguidas; (2) repetir falando baixo, para ver a segunda
escuta; (3) fechar o app, chamar “Jarvis” e pedir a lanterna; (4) pedir “abrir
YouTube” com o app fechado, autorizar pelo botão do aviso e repetir; (5) abrir
Configurações → Google → Voz → Reconhecimento de fala offline e confirmar o
português instalado.
