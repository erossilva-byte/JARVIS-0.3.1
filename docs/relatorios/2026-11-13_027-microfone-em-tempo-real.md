# Ajuste 027 — microfone em tempo real na tela

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que faltava

O ajuste 026 fez o serviço pausar quando outro app toma o microfone, mas a tela não mostrava
isso: o usuário só descobria pelo botão "Por que parou?" depois do fato.

## O que foi feito

**`JarvisBackgroundPlugin.java`**

- `estadoMicrofone()`: consulta leve com `bloqueioMicrofone`, `pausaFoneSegundos`, `escutando`
  e `servico`. Não lê áudio nem lista pacotes além do necessário.

**`segundo_plano.js`**

- `microfone(estado)` transforma a resposta em linha com nível (`erro`, `aviso`, `ok`) e texto:
  microfone em uso (com o pacote), pausa curta do fone (com segundos restantes), escuta ativa,
  serviço parado ou escuta inativa.

**`index.html` / `app.js`**

- Linha "Microfone: …" na seção Segundo plano, logo abaixo dos botões de bateria e sobreposição.
- Consulta a cada **2,5 s** apenas com a aba Voz aberta: o intervalo se encerra sozinho quando
  a aba fecha, outra categoria é aberta ou o app vai para segundo plano (`document.hidden`).
- Em uso por outro app, a linha fica na cor de alerta (`.dica.erro`).
- No navegador/desktop a linha diz que o monitoramento só existe no APK Android.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_microfone.js` | exit 0, **12 verificações** |
| `npm run test:all` | **exit 0, suíte completa** |
| Microfone ocupado | `ocupado: true`, nível `erro`, texto com o pacote e "até o outro app liberar" |
| Fone | nível `aviso`, "pausa curta de 3 s" |
| Escuta ativa | nível `ok` |
| Serviço parado / inativo | avisos distintos, sem fingir que está tudo bem |
| Ciclo do intervalo | 2,5 s; limpa ao sair da aba (`clearInterval`); para com painel oculto |
| Tela (360×740) | linha 320×35 px, sem rolagem lateral (360/360); no navegador mostra o aviso honesto |

## O que não foi verificado

- **Não compilado** e **não medido**: sem SDK e sem aparelho. A consulta real ao Android e a
  reação ao vivo com outro app gravando só podem ser vistas no Poco X7.
- O texto exibido no navegador é o caminho de fallback, não o comportamento nativo.

## Correção (revisão 030, 2026-11-13)

O texto "com o pacote" só vale quando o Android entrega o nome, o que não acontece para app
comum (exige `MODIFY_AUDIO_ROUTING`). Na prática a linha mostra "outro app está usando o
microfone." sem nome. A detecção em si foi corrigida no ajuste 030 e continua valendo.
