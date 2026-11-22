# Ajuste 075 — tarefas e automações persistentes (Fase 11)

## 1. Identificação

- **Versão:** 1.63.0+16300
- **Data:** 2026-11-19
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** o APK 1.63.0 foi substituído pelo **1.63.1** (`files/JARVIS-Nova-1.63.1-gemini-404.apk`, 117 611 108 bytes, SHA-256 `ee90918898f08123eabf4cc9ca055a39e31517cc99a6786c3a9ea3591001288e`), que contém este bloco e a correção do 404 da Visão; o `classes.dex` do pacote traz `JarvisAgenda`. Ver o ajuste 076.
- **Plataformas afetadas:** Android (Flutter/Dart e Kotlin). Windows não foi tocado.

## 2. Resumo do ajuste

Segundo bloco da Fase 11: **tarefas e automações persistentes**. O app cria,
edita, conclui e apaga tarefas com prazo e prioridade; cria automações por
horário ou bateria baixa; agenda o aviso no `AlarmManager` do Android; mantém
uma **fila offline** que tenta de novo o que falhou; registra um **histórico**
do que o Android respondeu; e trata **mensagem como ação sensível**, que só
abre a conversa depois do toque em **Confirmar**. Nada é enviado sozinho.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivos principais |
|---|---|---|---|
| Núcleo de tarefas | nova função | Modelos, validação, prazos, gatilhos, fila | `lib/core/tarefas.dart` |
| Armazenamento | nova função | Persistência local com limites e falha explicada | `lib/services/tarefas_store.dart` |
| Agendamento | nova função | Alarme real no Android, diário e após reiniciar | `lib/services/agenda_service.dart`, `JarvisAgenda.kt` |
| Canal do aparelho | melhoria | `agendarLembrete` e `cancelarLembrete` | `JarvisAparelho.kt` |
| Tela | nova função | Tarefas, automações, confirmações e histórico | `lib/services/tarefas_page.dart` |
| Navegação | melhoria | Abrir pelo módulo "Android e dispositivos" | `lib/pages.dart` |
| Manifesto e preparação | melhoria | Receptor de alarme/boot e permissão | `AndroidManifest.xml`, `tool/prepare_android_sistema.py` |

### Regras que sustentam o bloco

- **Tarefa** tem título, notas, prazo opcional, prioridade e origem (`manual`
  ou `automacao`). Prazo aceita `19:30`, `24/12 19:30`, `24/12/2026 19:30` ou
  `2026-12-24 19:30`; data inexistente (31/02) é recusada, não "corrigida".
- **Automação** dispara por horário (com janela de 5 min para quando o app é
  aberto atrasado) ou por bateria abaixo de um limite, no máximo uma vez a cada
  6 h. Ações: aviso, criar tarefa, abrir app e mensagem.
- **Mensagem é a única ação sensível.** Ela nasce como
  `aguardandoConfirmacao`; o toque em Confirmar chama o fluxo já existente de
  mensagem, que abre a conversa com o texto exato. O envio continua sendo do
  usuário; nenhum app de terceiro recebe envio silencioso.
- **Fila offline:** aviso que o Android não confirmou, app que não abriu ou
  tarefa que não gravou ficam pendentes e são tentados de novo ao abrir a tela,
  ao tocar em "Tentar de novo agora" e após cada automação, até 3 tentativas.
- **Aviso de horário** vai para o `AlarmManager` com `setAlarmClock` (o mesmo
  tratamento de alarme do usuário, sem exigir `SCHEDULE_EXACT_ALARM`) e é
  reprogramado para o dia seguinte pelo receptor. Depois de reiniciar o
  aparelho, o receptor de `BOOT_COMPLETED` restaura os alarmes.
- **Histórico** guarda as últimas 200 execuções com o estado real: executada,
  aguardando confirmação, falhou ou ignorada.
- **Limites:** 100 tarefas, 40 automações, 100 itens de fila, 200 eventos e
  128 kB no total. Acima disso a tela explica o que apagar.

## 4. Evidência

- `dart run tool/tarefas_test.dart`: **17 verificações** aprovadas — leitura de
  prazo, próxima ocorrência, janela de horário, bateria e intervalo, validação,
  fila com 3 tentativas, serialização tolerante, id estável e ordenação.
- `flutter test test/tarefas_page_test.dart`: **3 testes de widget** aprovados —
  criar/concluir/apagar tarefa com lembrete agendado e cancelado; automação de
  mensagem que não abre a conversa antes do Confirmar; e aviso honesto quando o
  Android não confirma o alarme.
- `python3 tests/test_tarefas_flutter.py`: contrato estático aprovado.
- `flutter analyze` sem problemas; suíte Flutter completa aprovada.
- Build release arm64 concluído; `agendarLembrete`, `cancelarLembrete` e as
  classes da agenda conferidas no `classes.dex`.
- APK, tamanho e SHA-256 registrados ao final do ajuste.

## 5. Como usar

1. **Android e dispositivos → Tarefas e automações**.
2. Em **Tarefas**, toque em *Nova tarefa*; o prazo é opcional. Com prazo, o
   Android recebe o alarme e a tela confirma o agendamento.
3. Em **Automações**, toque em *Nova automação*. Escolha o gatilho, a ação e o
   texto. Para mensagem, escolha o app e o destinatário.
4. Use *Verificar* para avaliar agora as automações de bateria; *Executar agora*
   testa uma automação específica.
5. O que ficou pendente aparece em **fila**; mensagem aparece em **aguardando
   confirmação** com os botões Confirmar e Recusar.
6. O **Histórico** mostra o que aconteceu, com o motivo quando falhou.

## 6. Não verificado

- **Nada foi instalado ou aberto no Poco X7.** Não há prova de campo do alarme
  tocando com o app fechado, da restauração após reiniciar o aparelho, da
  permissão de notificação no Android 13+ nem do comportamento no HyperOS.
- Não foi medido consumo de bateria do receptor nem atraso real do
  `setAlarmClock` no aparelho.
- Não foi testada a abertura de conversa em cada app de mensagem; o caminho é o
  mesmo já existente da tela do aparelho conectado.

## 7. Limitações

- **Automação de bateria** é avaliada quando o app está aberto (ou ao tocar em
  Verificar). Sem um serviço em segundo plano, ela não dispara com o app
  fechado; o app não finge que disparou.
- **Abrir app e criar tarefa** também rodam quando o app está aberto; a fila
  guarda o que falhou, mas não executa nada em segundo plano.
- **Aviso de horário** depende da permissão de notificação para aparecer; o
  alarme é entregue ao Android mesmo assim, e a tela declara essa limitação.
- **Mensagem** nunca é enviada sozinha: a confirmação abre a conversa, e o
  toque final em enviar é do usuário (regra mantida do aparelho conectado).
- **Android pode adiar alarmes** em modo de economia extrema; não há garantia
  de segundo exato.
- Sem sincronização entre aparelhos: tarefas, automações e histórico ficam
  somente neste aparelho.
- O pareamento Android ↔ Windows continua não implementado.