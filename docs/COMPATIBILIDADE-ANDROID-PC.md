# Compatibilidade Android ↔ PC

Este documento é o contrato entre o app do celular (Flutter) e o app do PC
(Electron) quando estão na mesma rede local. Ele diz o que já funciona, o que
cada lado anuncia, o que o canal aceita e o que continua de fora.

## O que já existe

| Peça | Onde | Estado |
|------|------|--------|
| Pareamento (código de 6 dígitos + HMAC, token) | `core/pareamento.dart`, `pareamento_service.dart`, `platforms/desktop/pareamento.js` | funciona desde a 1.104.0 |
| Leitura de status do celular no PC | `GET /jarvis/status` | funciona |
| Esquecer o PC / esquecer o celular | `POST /jarvis/esquecer` | funciona |
| **Negociação de protocolo e recursos** | `/jarvis/info` e `/jarvis/parear` | **novo na 1.109.0** |
| **Comando do PC para o celular** (`abrir_tela`) | `POST /jarvis/comando` | **novo na 1.109.0** |

O pareamento continua sendo por IP manual na rede local. Nada sai para a
internet: o celular só escuta, e os dois lados recusam endereço fora da LAN
antes de abrir qualquer conexão.

## Protocolo jarvis/2

### Negociação

O celular anuncia o que sabe fazer em `/jarvis/info` e repete a informação na
resposta do pareamento:

```json
{
  "nome": "JARVIS no celular",
  "versao": "1.109.0",
  "protocolo": "jarvis/2",
  "recursos": ["status", "comando"],
  "desafio": "…",
  "expiraEmSegundos": 118,
  "tentativas": 5
}
```

- `protocolo` ausente ou desconhecido → o PC trata como **`jarvis/1`**.
- Recurso desconhecido é descartado; não vira permissão.
- `comando` só aparece quando a tela do celular injetou um executor. Sem isso o
  canal é só de leitura e o PC sabe disso sem tentar nada.
- Registro gravado antes da 1.109.0 não tem esses campos: vira `jarvis/1` e a
  tela do PC desabilita os botões de comando.

### Comando

`POST /jarvis/comando` com `Authorization: Bearer <token>`:

```json
{
  "protocolo": "jarvis/2",
  "id": "9f2c…(32 hex)",
  "emitidoEm": "2026-11-25T14:03:11.000Z",
  "acao": "abrir_tela",
  "argumentos": { "tela": "memoria" }
}
```

Resposta de sucesso: `{ "ok": true, "id": "...", "resultado": "abri a memória no celular" }`.

O celular confere **nesta ordem**:

1. **Token** — sem ele, 401. O corpo só é lido depois disso.
2. **Protocolo** — diferente de `jarvis/2` → 400.
3. **`id`** — precisa ser hex de 32 a 64 caracteres → senão 400.
4. **Prazo** — `emitidoEm` a mais de 60 s do relógio do celular → 409.
5. **Repetição** — o mesmo `id` por 5 minutos → 409.
6. **Ação** — fora da lista → 422, com a lista aceita na mensagem.
7. **Ritmo** — mais de 20 por minuto, ou dois em menos de 1 s → 429.

Ações aceitas hoje (lista fechada, igual nas duas linguagens):

| Ação | Argumento | O que faz |
|------|-----------|-----------|
| `abrir_tela` | `memoria`, `pessoas`, `visao`, `historico`, `conversa` | abre a tela pedida no celular, pelo mesmo caminho que a voz usa |

Ação nova entra no `acoesRemotas` do Dart **e** no `ACOES_REMOTAS` do PC; o
teste do bloco 132 compara as duas listas e falha se divergirem.

## No PC

- `platforms/desktop/pareamento.js` — `lerNegociacao`, `aceitaComando`,
  `conferirPedidoDeComando` e `enviarComando`. Ação ou argumento inválido é
  recusado **antes** de tocar a rede; canal de leitura dá erro explicado.
- `platforms/desktop/main.js` — IPC `comandar_celular`.
- `index.html` + `app.js` — bloco “Comandos” no painel do celular, com botões
  desabilitados quando o celular não anunciou `comando`.

## Limites declarados

- **Nada disso foi executado em aparelho Android nem em PC físico.** A prova é
  de regra e de protocolo: um celular falso em Node
  (`tests/test_comando_remoto.js`) para o cliente do PC e o teste Dart do
  serviço (`flutter_app/tool/comando_remoto_test.dart`, serviço real em
  127.0.0.1), ambos verdes.
- **Sem TLS.** O canal é HTTP na LAN; o token e o `id` trafegam em claro. Serve
  para rede de confiança, não para Wi-Fi público. Criptografar exige certificado
  próprio nos dois lados e é decisão de um bloco futuro.
- **Um comando só.** `abrir_tela` abre uma tela e para. Não há conversa
  remota, envio de arquivo, leitura de memória pelo PC nem controle do
  microfone.
- **O canal só existe com a tela de pareamento aberta.** O servidor morre com a
  tela; comando enviado depois disso não chega.
- **Relógio.** Prazo de 60 s exige os dois aparelhos com hora razoável; um
  celular com hora errada recusa todo comando com 409 e a mensagem diz para
  conferir a hora.
- **A tela de destino precisa poder abrir.** Se o cofre da memória não existir
  no aparelho, o comando falha e o PC recebe o motivo, não um “ok” falso.
