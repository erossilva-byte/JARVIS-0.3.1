# Ajuste 028 — verificação de privacidade da ativação

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 4B pede e o que faltava

A Fase 4B pede prova de que **nenhum áudio sai do aparelho antes da palavra de ativação**. O
projeto sempre afirmou isso, mas não havia nem auditoria automatizada nem número na tela para
sustentar a afirmação.

## O que foi feito

**Auditoria estática (`tests/test_privacidade.js`)** — lê os arquivos e cobra:

- `JarvisKwsEngine.java` sem `java.net`, `HttpURLConnection`, OkHttp, `Socket`, `WebSocket`,
  `URLConnection`, e com `AudioRecord` + sherpa-onnx.
- `JarvisService.java` sem cliente de rede.
- `audio_pcm.js` e `escuta_voz.js` sem `fetch`, `XMLHttpRequest`, `WebSocket`, `sendBeacon`.
- `disparar()` sem nenhuma chamada de envio: só abre a tela e avisa o barramento.
- O roteiro de campo existe e cobre as quatro provas.

**Contador real no aparelho** — `JarvisService` guarda `TrafficStats.getUidTxBytes(Process.myUid())`
no início do processo e expõe `redeDesdeInicioBytes()`. O diagnóstico devolve
`redeBytesDesdeInicio`; quando o Android não informa, devolve -1 e a tela **não** diz zero.

**`privacidade.js` (novo, puro)** — formata bytes (B/KB/MB) e monta a frase: nenhum byte,
tráfego informado com a ressalva de que é o total do app, ou "não informou o contador". A
mensagem de que a ativação é local aparece sempre.

**Tela** — linha "Privacidade: …" na seção Segundo plano, atualizada junto do diagnóstico.

**`docs/FASE-4B-PRIVACIDADE.md`** — o roteiro com quatro provas independentes: inspeção
automática, contador do app após 10 minutos ociosos, modo avião (a ativação tem de funcionar
sem rede) e captura externa (roteador ou uso de dados do Android), com critérios de falha e
ficha para devolver.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_privacidade.js` | exit 0, **11 verificações** |
| `npm run test:all` | **exit 0, suíte completa** |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Zero byte | dito como zero |
| Contador indisponível (-1) | dito como desconhecido, nunca como zero |
| Unidades | 512 B, 2,0 KB, 3,0 MB |
| Tela (360×740) | linha 320×35 px, sem rolagem lateral; no navegador mostra o aviso honesto |

## Limites desta prova

- A inspeção mostra que **o caminho do áudio não tem cliente de rede**; ela não prova
  comportamento em tempo de execução.
- `TrafficStats` é por app, inclui todo o tráfego (inclusive verificação de atualização) e
  reinicia com o aparelho; ele não diz o que foi enviado.
- **Nada foi medido no Poco X7**: as provas 2, 3 e 4 do roteiro continuam pendentes. Sem elas,
  a fase não pode ser declarada aprovada em privacidade.
