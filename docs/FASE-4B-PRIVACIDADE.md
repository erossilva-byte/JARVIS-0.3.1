# Fase 4B — verificação de privacidade da ativação

Objetivo: provar que **nenhum áudio sai do aparelho antes da palavra de ativação**. A prova
tem quatro partes independentes; nenhuma sozinha basta.

## 1. Inspeção do código (automática)

Rode:

```
node tests/test_privacidade.js
```

O teste verifica, lendo os arquivos:

- `JarvisKwsEngine.java` (o detector) não importa nem usa `java.net`, `HttpURLConnection`,
  OkHttp, `Socket`, `WebSocket` ou `URLConnection` — e usa `AudioRecord` + sherpa-onnx local.
- `JarvisService.java` (quem mantém a escuta) também não tem cliente de rede.
- `audio_pcm.js` e `escuta_voz.js` (captura e VAD no app) não usam `fetch`, `XMLHttpRequest`,
  `WebSocket` nem `sendBeacon`.
- Em `disparar()` — o método chamado quando a palavra é detectada — só existem abrir a tela e
  avisar o barramento interno; nenhuma chamada de envio.
- O contador de tráfego usa `TrafficStats.getUidTxBytes(Process.myUid())`, do próprio app.

Resultado esperado: **todas as verificações aprovadas**. Se alguma falhar, é falha de
privacidade, não de teste.

## 2. Contador do próprio app (no aparelho)

1. Abra Ajustes ▸ Voz ▸ Segundo plano e ligue a escuta.
2. Deixe a tela apagada por **10 minutos**, sem usar o aparelho.
3. Volte à mesma tela e leia a linha "Privacidade: …".

Esperado: "Nenhum byte de rede saiu do app desde que o serviço iniciou." Se aparecer um valor,
anote o número: é o tráfego total do app (pode incluir verificação de atualização), não prova
sozinho o que era.

Limites honestos: o contador do Android é por app e reinicia quando o aparelho reinicia; ele
não diz **o que** foi enviado. Por isso as provas 1, 3 e 4 existem.

## 3. Modo avião (prova de que a ativação não depende de rede)

1. Ligue o modo avião, desligue também Wi-Fi e Bluetooth.
2. Com a escuta ligada, diga "Jarvis" três vezes.
3. Anote quantas vezes o app abriu.

Esperado: o detector continua funcionando e o app abre. Se não abrir sem rede, a ativação
depende de rede — o que contradiz o projeto e precisa ser investigado.

Observação: depois de abrir, o app pode tentar falar com o provedor de IA ao processar um
comando. Isso é **depois** da palavra, não antes.

## 4. Captura externa (prova de que nada sai)

Duas opções, use a que tiver:

- **Roteador:** olhe o consumo por dispositivo durante 10 minutos com o celular parado e a
  escuta ligada. Esperado: nenhum tráfego originado pelo celular no período (fora de
  sincronização do próprio sistema).
- **Uso de dados do Android:** Configurações ▸ Rede e internet ▸ Uso de dados ▸ J.A.R.V.I.S.
  Nova, anote antes e depois dos 10 minutos. Esperado: 0 B.

Se aparecer tráfego, registre o valor e o horário; isso precisa ser explicado antes de a fase
ser considerada aprovada.

## O que conta como falha

- Qualquer envio de áudio, trecho ou transcrição antes da palavra.
- Qualquer tráfego do app no período ocioso que não seja verificação de atualização
  identificada.
- O detector precisar de rede para acordar.
- O app gravar áudio em arquivo durante a espera.

## Ficha para devolver

| Prova | Resultado | Observação |
|---|---|---|
| 1. Inspeção (`node tests/test_privacidade.js`) | | |
| 2. Contador do app após 10 min | | |
| 3. Modo avião — acordou (de 3) | | |
| 4. Uso de dados externo em 10 min | | |
| Aparelho / Android / versão do app | | |
