# Ajuste 025 — manutenção periódica com WorkManager

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 4B pede e o que faltava

A Fase 4B pede tarefas agendadas com **WorkManager**. O app só tinha `AlarmManager` (lembretes
e vigia). Faltava o caminho que o Android entrega dentro do Doze, com restrição de bateria e
retomada depois do reinício.

## O que foi feito

**`JarvisManutencaoWorker.java` (novo)**

- `Worker` periódico de **6 horas**, `setRequiresBatteryNotLow(true)`, registrado como trabalho
  único com `ExistingPeriodicWorkPolicy.KEEP` (não duplica a cada chamada).
- A cada execução: restaura os lembretes futuros (`JarvisAlarmScheduler.restaurar`), grava
  `ultima_manutencao`, e, se a escuta deveria estar no ar mas o serviço caiu, agenda o alarme
  rápido do vigia (5 s) — o Worker não tem isenção para iniciar serviço de microfone; o alarme
  tem. Falha vira `Result.retry()` e fica registrada em `ultimoErro`.
- `rodarAgora()` enfileira uma execução única, para o diagnóstico conferir sem esperar 6 h.

**Agendamento**

- `JarvisService.iniciarEscuta()` agenda ao ligar a escuta; `JarvisBootReceiver` reagenda depois
  de reiniciar o aparelho ou atualizar o app.

**`patch_gradle.py`**

- Injeta `implementation "androidx.work:work-runtime:2.9.1"` no `build.gradle` gerado (mesmo
  mecanismo já usado para MediaPipe, sherpa-onnx, biometria e documentfile).

**Plataforma**

- `JarvisBackgroundPlugin`: `rodarManutencaoAgora()` e os campos `ultimaManutencao` e
  `manutencaoAgendada` no diagnóstico.
- `manutencao.js` (novo, puro): transforma esse estado em frase honesta — nunca rodou, há
  quanto tempo, e aviso quando não está agendada.
- Tela: botão "Rodar manutenção agora" e linha "Última verificação automática…" no diagnóstico.

## O que este ajuste **não** faz

As rotinas do usuário continuam rodando na interface. Um `Worker` não abre a WebView nem
executa o JavaScript das rotinas; dizer o contrário seria mentira. O WorkManager aqui cobre a
manutenção do segundo plano (lembretes, vigia, estado), não a execução das rotinas.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_manutencao.js` | exit 0, **9 verificações** |
| `npm run test:all` | **exit 0, suíte completa** |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Worker | classe, nome único, 6 h, restrição de bateria, `KEEP`, restauração de lembretes |
| Agendamento | presente em `iniciarEscuta` e no `JarvisBootReceiver` |
| Gradle | dependência `androidx.work:work-runtime:2.9.1` injetada pelo script |
| Workflows | cópia de `JarvisManutencaoWorker.java` verificada nos quatro fluxos |
| Tela | botão responde no navegador com "depende do WorkManager do Android"; 294×40 px em 360 px, sem rolagem lateral |

## O que não foi verificado

- **Não compilado**: sem Android SDK; a dependência e o Worker só provam compilação no CI.
- **Não medido**: periodicidade real, execução dentro do Doze e consumo do Worker só no Poco X7.
- O caminho nativo do botão "Rodar manutenção agora" não foi executado aqui.
