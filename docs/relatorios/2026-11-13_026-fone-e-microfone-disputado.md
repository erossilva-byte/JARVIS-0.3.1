# Ajuste 026 — fone desconectado e microfone usado por outro app

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 4B pede e o que faltava

A Fase 4B prevê pausar quando o fone cai ou outro app toma o microfone, retomando quando
liberar. O serviço já tratava chamada e mídia, mas não a troca de rota de áudio nem a
concorrência pelo microfone.

## O que foi feito

**`JarvisService.java`**

- **Fone:** receptor de `AudioManager.ACTION_AUDIO_BECOMING_NOISY` (o aviso que o Android manda
  quando a rota de áudio muda — fone Bluetooth cai, cabo sai). Registrado com
  `ContextCompat.registerReceiver(..., RECEIVER_NOT_EXPORTED)` no `onCreate` e desregistrado no
  `onDestroy`. Ao receber, o detector solta o microfone, a notificação diz "Escuta pausada: o
  fone foi desconectado" e a escuta volta sozinha em **5 segundos**.
- **Outro app gravando:** `bloqueioMicrofone()` consulta
  `AudioManager.getActiveRecordingConfigurations()` — que informa pacote e fonte, **sem acesso ao
  áudio** — e ignora o próprio pacote. Antes de abrir o microfone, `iniciarMotor()` desiste e a
  notificação explica; enquanto está ouvindo, o laço de 1 s detecta a tomada e pausa. Quando o
  outro app solta, o mesmo laço retoma.
- A pausa do fone não briga com o laço: `iniciarMotor()` respeita `pausaFoneAte`, então a
  retomada acontece no tempo certo e não a cada segundo.

**`JarvisBackgroundPlugin.java`**

- Diagnóstico passa a informar `bloqueioMicrofone` e `pausaFoneSegundos`.

**`segundo_plano.js`**

- "Por que parou?" reconhece as causas `microfone-ocupado` e `fone`, com texto próprio e na
  ordem em que explicam a parada.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_microfone.js` | exit 0, **9 verificações** |
| `node tests/test_segundo_plano.js` | exit 0, **17 verificações** (sem regressão) |
| `npm run test:all` | **exit 0, suíte completa** |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Causa "outro app" | primeira da lista, com o nome do pacote |
| Causa "fone" | pausa curta citada, com retomada automática |
| Coexistência | as duas aparecem juntas, na ordem |
| Serviço | consulta antes de abrir o microfone e durante a sessão; ignora o próprio app |
| Ciclo de vida | receptor registrado no `onCreate` e desregistrado no `onDestroy` |

## O que não foi verificado

- **Não compilado**: sem Android SDK; `ContextCompat.registerReceiver` e
  `getActiveRecordingConfigurations` compilam no CI.
- **Não medido**: o aviso de rota de áudio varia por fabricante e o Android pode entregar a lista
  de gravações vazia conforme versão/OEM — lista vazia é tratada como "livre", não como certeza.
  Só o Poco X7 confirma os dois casos.

## Correção (revisão 030, 2026-11-13)

A detecção descrita acima **não funcionava como escrita**: `getClientPackageName()` só devolve o
nome do pacote com a permissão de sistema `MODIFY_AUDIO_ROUTING`, que um app comum não tem — sem
ela o retorno é vazio e a comparação nunca dava "ocupado". Corrigido no ajuste 030: a detecção
agora ignora a própria **sessão de áudio** (`getClientAudioSessionId`) e conta as gravações
restantes; o pacote só é citado quando o Android entrega. Ver `docs/REVISAO-JAVA-COMPILACAO.md`.
