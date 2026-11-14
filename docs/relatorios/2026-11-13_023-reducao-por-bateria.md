# Ajuste 023 — redução automática por bateria e economia de energia

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 4B pede e o que faltava

O plano da Fase 4B previa reduzir a escuta quando a bateria estivesse baixa ou a economia de
energia do sistema ligada. Os perfis (ajuste 022) já limitavam por carregador e horário, mas
não havia limite por nível de bateria nem reação à economia do Android.

## O que foi feito

**`JarvisService.java`**

- `LIMITE_BATERIA = 15`: abaixo disso (inclusive 15%) e sem carregador, o detector não abre o
  microfone. Carregando, a escuta continua mesmo em 5%.
- `economiaEnergia()` consulta `PowerManager.isPowerSaveMode()`; com economia ligada, a escuta
  é reduzida mesmo com a bateria cheia.
- `bloqueioBateria()` devolve o motivo ("bateria em 9% (limite 15%)." ou "economia de energia
  do sistema ligada.") ou vazio. `nivelBateria()` lê nível e escala reais da bateria; sem
  informação, devolve -1 e não bloqueia nada.
- A checagem entra em `iniciarMotor()`, depois do perfil e antes de tocar no microfone. O laço
  de 1 s já existente volta a tentar, então **carregar ou desligar a economia retoma a escuta
  sozinho**, sem abrir o app.
- A notificação diz "Escuta reduzida para poupar bateria — <motivo>", e só é reescrita quando
  o texto muda (evita atualização a cada segundo).

**`JarvisBackgroundPlugin.java`**

- Diagnóstico e `estadoEnergia` passam a informar `nivelBateria`, `economiaEnergia` e
  `bloqueioBateria`.

**`perfil_energia.js` / `segundo_plano.js`**

- O resumo do perfil informa a redução e que ela volta sozinha; o botão "Por que parou?"
  reconhece a causa `bateria-baixa`.
- A regra de decisão **não** foi duplicada em JavaScript: quem decide é o Java, e a tela apenas
  descreve o `bloqueioBateria` que ele devolve.

**`index.html`**

- A dica do perfil explica o limite de 15% e a economia de energia.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_perfil_energia.js` | exit 0, **17 verificações** |
| `node tests/test_segundo_plano.js` | exit 0, **17 verificações** |
| `npm run test:all` | **exit 0, suíte completa** |
| Regra no serviço | `iniciarMotor` consulta `bloqueioBateria` antes do microfone |
| Limiar | `nivel <= LIMITE_BATERIA` **e** `!carregando(c)`; economia bloqueia por si |
| Sem nível informado | `-1` → não bloqueia nem inventa redução |
| Texto da tela | "Redução para poupar bateria: … A escuta volta sozinha ao carregar ou sair da economia." |

## O que não foi verificado

- **Não compilado**: sem Android SDK e sem `gradle` aqui; a compilação é do CI.
- **Não medido no aparelho**: o comportamento real em 15%, em economia de energia e a
  retomada automática ao carregar só podem ser confirmados no Poco X7.
- O consumo resultante dessa redução não foi medido; ele entra no teste A da ficha da Fase 4B.
