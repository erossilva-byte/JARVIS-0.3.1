# Fase 4B — plano para o aparelho (Poco X7)

Data: 2026-11-13 · Branch: `work/1.48.0-fase2-consolidacao`

Este documento prepara a Fase 4B (execução em segundo plano) para ser executada **no
aparelho**. Ele parte do que já está no código — não de suposição — e separa o que falta
implementar do que falta apenas medir. Nada aqui foi medido em hardware ainda.

## 1. O que já existe hoje

| Peça | Onde | Situação |
|---|---|---|
| Serviço de primeiro plano único | `JarvisService.java` (668 linhas) | Inicia com tipo `microphone` quando há `RECORD_AUDIO`; sem a permissão, usa `dataSync` para não cair na exceção de serviço não iniciado |
| Notificação persistente | `JarvisService.java` (montagem) | Título "J.A.R.V.I.S. Nova ativo", texto de estado, ações **"Ouvir agora"** e **"Desligar escuta"**; tocar abre o app |
| Detector local | `JarvisKwsEngine.java` | sherpa-onnx `KeywordSpotter`, modelo `sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01`, limiar por sensibilidade (0,25 / 0,35 / 0,45) |
| Pausa automática | `JarvisService.java` | Chamada ativa pausa sempre; mídia pausa se o usuário ligou a opção; estado vai para a notificação |
| Reinício após desligar | `JarvisBootReceiver.java` | Agenda o vigia para 20 s depois do boot (o Android 14+ não deixa iniciar serviço de microfone direto do boot) |
| Vigia | `JarvisWatchdog.java` | Alarme de 15 min, inexato para ser entregue no Doze; reinicia a escuta e grava o motivo da falha |
| Lembretes | `JarvisAlarmScheduler.java` | `AlarmManager` com restauração após reinício |
| Diagnóstico | `JarvisBackgroundPlugin.diagnosticoEscuta()` | Consulta real de microfone, notificação, bateria sem restrição, sobreposição, acesso a notificações, serviço ativo, escutando, detector, sensibilidade, calibragem, último erro, último evento, fabricante/modelo/Android |
| Interface | Ajustes ▸ Voz | "Desligar escuta em segundo plano", "Impedir suspensão pela bateria", "Permitir abrir na tela", diagnóstico com quatro pontos e atalho de autostart do fabricante |

## 2. Lacunas em relação ao que a Fase 4B pede

| # | Pedido | Hoje | O que falta |
|---|---|---|---|
| 1 | Ações **Pausar**, **Parar** e **Abrir** na notificação | Implementado no ajuste 022: Pausar/Retomar com estado persistido, Abrir, Ouvir agora e Desligar escuta | Compilar e conferir no aparelho |
| 2 | Perfis de energia: **Sempre ouvindo**, **Somente carregando**, **Horários definidos**, **Desligado** | Implementado nos ajustes 022 e 023: perfil persistido, checado em `iniciarMotor`, redução com bateria ≤ 15% ou economia de energia, retomada automática | Compilar e medir no aparelho |
| 3 | Tarefas agendadas com **WorkManager** (rotinas, indexação) | Implementado no ajuste 025 para manutenção (lembretes, vigia, estado) a cada 6 h, sem bateria baixa | Rotinas e indexação continuam na interface: Worker não executa JavaScript |
| 4 | Estado **Pausado automaticamente** por fone desconectado ou outro app usando o microfone | Implementado no ajuste 026 e corrigido no 030: aviso de rota de áudio (5 s) e `getActiveRecordingConfigurations` com a sessão do `AudioRecord` para ignorar a própria captura; retomada pelo laço de 1 s. O nome do outro app não é visível para app comum. | Compilar e medir no Poco X7 |
| 5 | Botão **"Por que parou?"** | Diagnóstico mostra "Último erro do detector" e último evento; comando de voz "por que a escuta parou" existe | Botão dedicado na tela de segundo plano que mostre motivo, hora e última detecção |
| 6 | Consumo medido com tela apagada | Nunca medido | Medição de 8 h no aparelho (seção 4) |
| 7 | Nenhum áudio antes da ativação | Implementado no ajuste 028: auditoria estática, contador `TrafficStats` na tela e roteiro de 4 provas (`docs/FASE-4B-PRIVACIDADE.md`) | Provas de campo pendentes no Poco X7 |
| 8 | Windows em segundo plano | Fora desta rodada | Fica para depois; o app Windows não tem serviço de escuta contínua |

## 3. Ordem de implementação no código (quando houver SDK)

1. **Ação Pausar** em `JarvisService`: `ACAO_PAUSAR` que para o motor sem desligar
   `desejaOuvir`; a notificação passa a mostrar "Escuta pausada por você" com ação "Retomar".
   Aceitação: pausar e retomar pela notificação sem abrir o app.
2. **Perfis de energia** em `JarvisPrefs` (`perfil` = `sempre|carregando|horario|desligado`,
   `horarioInicio`, `horarioFim`) e checagem em `JarvisService.aoIniciar`: fora da janela ou
   sem carregador, o serviço não sobe e a notificação diz o motivo.
3. **Redução por bateria**: abaixo de 15% ou em economia do sistema, pausar e registrar;
   retomar quando carregar.
4. **Fone/microfone disputado**: ouvinte de `AudioManager.ACTION_AUDIO_BECOMING_NOISY` e
   checagem de `AudioRecord.getRecordingState()`/`getState()` para pausar e retomar.
5. **WorkManager** para rotinas e indexação, com `Constraints` de rede e carregamento.
6. **Botão "Por que parou?"** na interface lendo o diagnóstico que já existe.
7. **Teste automatizado** (jsdom + estático) para as novas chaves de perfil e para o botão,
   como foi feito nos ajustes 014–020.

Nada disso pode ser compilado aqui: o ambiente não tem Android SDK nem `gradle`. O CI do
repositório compila o APK; a verificação de comportamento é no aparelho.

## 4. Preparação do Poco X7 — passo a passo

1. **Instalar** o APK da build mais recente do CI (release assinada, não a de debug).
2. **Permissões**: microfone, notificações e (se for usar) acesso a notificações. Conceder
   em Ajustes ▸ Apps ▸ J.A.R.V.I.S. Nova ▸ Permissões.
3. **Bateria sem restrição**: toque em "Impedir suspensão pela bateria" no app e confirme na
   tela do sistema.
4. **Início automático (HyperOS)**: toque em "Abrir tela de início automático" e permita o
   app na lista; em HyperOS isso costuma estar em "Iniciar automaticamente" e "Economia de
   bateria sem restrições".
5. **Sobreposição**: "Permitir abrir na tela" (necessário para ele abrir quando chamado em
   segundo plano).
6. **Fechar o app nos recentes uma vez** e conferir se a notificação "J.A.R.V.I.S. Nova
   ativo" volta; se não voltar, anotar o que o diagnóstico diz.
7. **Carregar a bateria até 100%** antes do teste de 8 h e não usar o aparelho nesse período
   (deixar a tela apagada, sem música e sem chamadas).

## 5. O que medir, com que números

Ficha pronta para preencher: `docs/FASE-4B-FICHA-MEDICAO.md`.

### Teste A — 8 horas com a tela apagada

- Registrar bateria inicial e final (Configurações ▸ Bateria) e calcular **%/hora**.
- Meta do prompt: **até 3% por hora**. Se passar, registrar o perfil e a versão do Android.
- Dizer "Jarvis" **20 vezes espaçadas** (10 com voz normal, 10 baixa) e anotar acertos.
- Contar **falsos positivos** no período (o app registra último evento; o log de ativações
  mostra a hora).
- Meta de aceitação: serviço ainda ativo no fim, sem vazamento de microfone.

### Teste B — Sobrevivência

Para cada item: fazer, esperar 2 minutos, dizer "Jarvis" três vezes e anotar se acordou.

1. Reiniciar o aparelho (esperar o aviso "toque para ativar a escuta", se aparecer).
2. Deixar em Doze (tela apagada, sem carregar, 30 min).
3. Deslizar o app nos recentes.
4. Ligar economia de bateria.
5. Receber uma chamada telefônica de 1 minuto.
6. Conectar e desconectar fone Bluetooth.
7. Abrir outro app que use o microfone (gravador de voz) e fechar.
8. Alternar Wi-Fi ↔ dados móveis.

### Teste C — Tarefas agendadas

- Criar um lembrete para daqui a 10 minutos, apagar a tela e conferir se dispara com
  tolerância de **1 minuto**.
- Repetir com o aparelho reiniciado antes do horário.

### Teste D — Privacidade

- Com o app em segundo plano e sem dizer "Jarvis", usar o aparelho por 10 minutos e conferir
  no monitor de rede do Android (Configurações ▸ Rede ▸ Uso de dados) que o app não enviou
  dados no período.

### Teste E — Palavra de ativação em português

- 20 tentativas em ambiente silencioso e 20 com ruído (TV ou rua).
- Anotar acertos, falsos positivos e o limiar de sensibilidade usado.
- Se a taxa for baixa, repetir com sensibilidade 75–100 e comparar.

## 6. O que trazer de volta

1. A ficha preenchida (ou foto dela).
2. Captura do diagnóstico de segundo plano do app (Ajustes ▸ Voz).
3. Se possível, o log do sistema filtrado pelo app:
   `adb logcat -d | findstr jarvis` (Windows) ou `adb logcat -d | grep -i jarvis`.
4. Modelo, versão do Android e do HyperOS, e se a build é release ou debug.

## 7. Limitações conhecidas que o teste precisa confirmar

- O modelo de KWS é treinado em inglês; "Jarvis" com pronúncia brasileira pode ter taxa baixa.
- HyperOS pode matar o serviço mesmo com bateria liberada; o vigia de 15 min recupera, mas
  com atraso — o teste mede esse atraso.
- Android 15+ não deixa iniciar serviço de microfone no boot: o caminho é a notificação
  "toque para ativar".
- Sem Android SDK e sem aparelho aqui, **nada desta fase foi medido**; este documento é
  plano e roteiro, não resultado.
