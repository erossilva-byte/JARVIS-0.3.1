# Ajuste 035 — plugins restantes e regra de primeiro plano (2026-11-14)

## O que foi revisado

Continuação da revisão 034, agora nos plugins que ainda não tinham sido lidos por inteiro:
`JarvisSeguranca`, `JarvisNotificationListener`, `JarvisWatchdog`, `JarvisAlarmReceiver`,
`JarvisAtivacao` e `JarvisUtilPlugin` (1270 linhas, o maior).

## Defeitos encontrados e corrigidos

### 1. NFC deixava uma promessa pendente

`JarvisSeguranca` guardava o `PluginCall` de `lerTag` e só o resolvia quando uma tag
aparecia. Se a leitura fosse cancelada (`handleOnDestroy`), a promessa do JavaScript ficava
esperando para sempre e o app podia travar o fluxo que a aguardava.

- Correção: `cancelarLeitura()` resolve o `call` guardado com `{cancelado: true}` e zera a
  referência; `handleOnDestroy` chama esse método antes do `super`.

### 2. Notificações: listener incompleto e lista estática acumulando

`JarvisNotificationListener` não implementava `onNotificationRemoved` e não limpava a lista
estática `RECENTES` ao ser destruído. Além disso tinha um `import` duplicado.

- Correção: `onNotificationRemoved` remove a entrada correspondente; `onDestroy` limpa a
  lista; import duplicado removido. A lista deixa de crescer entre ciclos de vida do serviço.

### 3. Watchdog desfazia a pausa manual

`JarvisWatchdog` reiniciava o serviço a cada 15 minutos mesmo quando o usuário tinha pausado
o assistente manualmente — o oposto do que o botão de pausa promete.

- Correção: antes de reativar, consulta `pausadoManual` nas preferências e só age quando o
  usuário não pausou.

### 4. `JarvisUtilPlugin`: disco e contatos na thread principal

`cofreStatus`, `cofreListar` e `lerContatos` percorriam a árvore de arquivos do cofre (SAF) e
o `ContentResolver` na thread principal do WebView. Em cofre grande isso trava a interface e
pode gerar ANR.

- Correção: executor único `fundo` (`Executors.newSingleThreadExecutor()`) e o auxiliar
  `emFundo(PluginCall, Supplier<JSObject>)`, que executa a leitura fora da thread principal e
  resolve a promessa na thread principal; erros viram `call.reject`.
- `listarContatos`, `aposPermissaoContatos`, `cofreStatus` e `cofreListar` passaram a usar o
  executor. `handleOnDestroy` encerra o executor (`shutdownNow`).

### 5. `JarvisUtilPlugin`: streams vazando

`cofreLer` fechava o `InputStream` só no caminho feliz e `cofreEscrever` o `OutputStream`
também. Uma exceção no meio deixava o descritor aberto.

- Correção: `close()` em `finally`, com o fechamento protegido por `try/catch`.
- `listFiles()` passou a checar `null` antes de iterar (o SAF devolve `null` quando a pasta
  foi revogada).

## Regra nova na pré-checagem: primeiro plano com saída

Serviço criado com `startForegroundService()` que falha ao promover é morto pelo Android com
`ForegroundServiceDidNotStartInTimeException`. O padrão perigoso é `try { startForeground(...) }
catch (Exception e) { /* só registra */ }`: o processo continua vivo achando que está em
primeiro plano.

`ci/preflight_android.py` ganhou `verificar_primeiro_plano()`:

1. para cada `try` cujo corpo contém `startForeground(`, acha o `catch` seguinte (se não
   houver `catch`, quem chama trata e a regra não opina);
2. exige, no `catch` ou no resto do método, uma saída explícita: `stopSelf`,
   `stopForeground`, `pararTudo`, `return false` ou `throw`;
3. sem saída, reprova com o nome do arquivo e o motivo.

Teste negativo feito: um arquivo `ProbeForeground.java` com `catch` vazio foi criado na raiz,
a pré-checagem saiu 1 apontando o arquivo, e o arquivo foi apagado — a pré-checagem voltou a
sair 0. O código atual (`JarvisService`, `JarvisMusicaService`) passa, porque ambos param o
serviço quando não conseguem promover.

Limite conhecido e aceito: a regra é estática e heurística. Ela não prova que o caminho de
sucesso promove de fato, nem cobre laços de nova tentativa que terminam em `return` sem parar
o serviço. O que ela impede é o caso silencioso, que foi o defeito real deste projeto.

## Verificação

- `python3 ci/preflight_android.py` — exit 0 (23 classes, 6 workflows, 8 APIs restritas).
- `npm run verificar` — exit 0, 3 de 3 etapas, 2364 verificações OK.
- Java continua sem compilação local (sem JDK e sem SDK Android nesta máquina); a
  compilação é o Gate A, no CI.
