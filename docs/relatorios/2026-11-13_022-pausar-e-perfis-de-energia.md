# Ajuste 022 — Pausar/Retomar na notificação e perfis de energia

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 4B pede e o que faltava

Dois itens da Fase 4B ainda não existiam: a ação **Pausar** na notificação do serviço de
escuta (havia só "Ouvir agora" e "Desligar escuta") e os **perfis de energia** — sempre
ouvindo, somente carregando, horários definidos e desligado. A pausa também precisava
sobreviver à tela apagada, e o perfil precisava ser aplicado por quem abre o microfone, não
só pela tela.

## O que foi feito

**`JarvisPrefs.java`**

- `perfilEnergia` (grava só os quatro valores; desconhecido cai em "sempre"), `horarioInicio`
  e `horarioFim` em minutos do dia (limitados a 00:00–23:59), e `pausadoManual`, que persiste
  a pausa do usuário.

**`JarvisService.java`**

- Ações novas `ACAO_PAUSAR` e `ACAO_RETOMAR`. Pausar solta o microfone, mantém o serviço, o
  vigia e a notificação ("Escuta pausada por você — Retomar volta a ouvir"); retomar volta a
  ouvir respeitando o perfil.
- `bloqueioPerfil()` concentra a regra: Desligado nunca abre o microfone; Somente carregando
  exige carregador (bateria cheia conta); Horários exige estar dentro da janela, inclusive
  quando ela atravessa a meia-noite. `carregando()` lê o estado real pela bateria do sistema.
- A checagem ficou em `iniciarMotor()`: o microfone nem abre fora do perfil. O laço de 1 s já
  existente volta a tentar, então conectar o carregador ou entrar na janela libera a escuta
  sem precisar desligar e ligar.
- A pausa manual vence o pedido de ligar — inclusive o do vigia, o rearme de 9 s e o retorno
  depois de fechar nos recentes. Trocar de perfil na tela é aplicado na hora por
  `aplicarPerfil()`.
- Notificação com **Pausar/Retomar** (o rótulo muda conforme o estado), **Abrir**, **Ouvir
  agora** e **Desligar escuta**.

**`JarvisBackgroundPlugin.java`**

- `estadoEnergia`, `definirPerfilEnergia`, `pausarEscutaManual` e `retomarEscutaManual`; o
  diagnóstico passa a informar `pausadoManual`, `perfil`, `horarioInicio`, `horarioFim`,
  `carregando` e `bloqueioPerfil`.

**`perfil_energia.js` (novo, puro)**

- Monta o pedido a partir dos campos, recusando horário inválido (formato e janela de zero
  minuto) antes de chamar o Android; descreve o estado devolvido pelo serviço.

**`segundo_plano.js`**

- "Por que parou?" agora reconhece a pausa manual e o bloqueio de perfil como causas.

**`index.html` / `app.js`**

- Seletor de perfil, campos de início e fim (aparecem só em "Horários definidos") e linha de
  estado, em Ajustes ▸ Voz ▸ Segundo plano. No navegador a resposta é honesta: o perfil
  depende do serviço nativo do Android.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_perfil_energia.js` | exit 0, **15 verificações** |
| `node tests/test_segundo_plano.js` | exit 0, **16 verificações** |
| `npm run test:all` | **exit 0, suíte completa** (2361 OK) |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Perfis | quatro valores, rótulos e dicas; desconhecido cai em "sempre" |
| Horários | 07:30→450, 7:05→425, inválidos recusados, janela de zero minuto recusada, janela que cruza a meia-noite aceita |
| Notificação | Pausar/Retomar, Abrir, Ouvir agora e Desligar escuta presentes no código |
| Serviço | `iniciarMotor` consulta `bloqueioPerfil`; pausa manual bloqueia vigia, rearme e recentes |
| Tela (360×740) | seletor com as quatro opções; horário oculto até escolher "Horários definidos"; campos de 320 px; sem rolagem lateral (360/360) |

## O que não foi verificado

- **Nada foi compilado**: não há Android SDK nem `gradle` aqui. O Java foi escrito sobre as
  APIs já usadas no projeto e coberto por testes estáticos, mas a compilação real é do CI.
- **Nada foi medido no aparelho**: pausa, retomada, carregador, janela de horário e o texto
  da notificação só podem ser confirmados no Poco X7.
- O caminho da tela com o plugin Android não foi executado; no navegador ele cai no aviso de
  que o recurso depende do serviço nativo.
