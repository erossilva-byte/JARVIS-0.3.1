# Ajuste 100 — circuito por prompt no chat e na voz

Data: 2026-11-22 · Versão: 1.86.0+18600 · Branch: `work/1.86.0-bloco-100`

## 1. Pedido do usuário

Levar o circuito por prompt para o chat e para a voz, interceptando o pedido
antes do provedor, montando, simulando e oferecendo abrir no simulador.

## 2. O que faltava

O bloco 099 criou o projetista, mas ele só era alcançável por dentro de
“CADeSIMU e elétrica” (e pelo botão do Hermes). No caminho natural — escrever ou
falar com o JARVIS — o pedido “monta um circuito de lâmpada de 12 V” ia para o
provedor de IA como texto e voltava uma descrição em português, não um circuito.
O motor existia; o caminho não.

## 3. O que foi feito

### 3.1 A decisão, em núcleo puro

**`lib/core/circuito_no_chat.dart`** (novo) responde uma pergunta só: *este texto
é um pedido para montar um circuito?*

- Exige **verbo de montagem** (monta, monte, faz, faça, cria, gera, projeta,
  desenha, constrói, “preciso de”, “quero um”) **e substantivo de circuito**
  (circuito, esquema, diagrama, lâmpada, LED, resistor, divisor, partida direta,
  reversão, temporizador, contator, motor).
- **Pergunta pura fica de fora**: “o que é um resistor”, “explica o divisor de
  tensão”, “como funciona um contator” continuam indo para a IA. Só passa a
  interceptar quando a pergunta traz imperativo (“como monto…”).
- Comando do aparelho e conversa comum também não são tocados: “aumenta o
  volume”, “abre o simulador de circuitos” e “bom dia” seguem o fluxo normal.

Errar para o lado de não interceptar só devolve a pergunta ao provedor; errar
para o outro lado engoliria uma pergunta legítima. Por isso a regra é
conservadora e está presa no teste.

`responderPedidoDeCircuito` monta com `montarProjetoDe`, confere
`circuito.simular()` e devolve dois textos: o completo, para a bolha, e o
**falável**, curto e sem aspas tipográficas, para o alto-falante.

### 3.2 Na conversa

Em `voice_conversation_page.dart`, a decisão entra **depois** do executor de
comandos do Android e **antes** de qualquer provedor — a mesma ordem vale para o
texto digitado e para a fala, porque é a mesma tela.

- A resposta entra como mensagem do assistente (“Montei o circuito ‘Lâmpada com
  interruptor’: 12 trechos, simulação fechada, 5 W no total…”), é falada na
  versão curta e fica no histórico como `circuito por prompt` (ou `circuito
  recusado`, quando não monta).
- Quando a montagem fecha, aparece um **cartão acima do campo de texto** —
  “Circuito montado: <título> · N trechos · simulação fechada” — com o botão
  **“Abrir no simulador”**, que abre `CircuitoPage(inicial:)` com o esquema já na
  tela.
- Recusa não abre nada: o cartão só existe com simulação fechada.
- Circuito não entra no limite de cinco comandos seguidos: ele não toca em nada
  do aparelho.

### 3.3 Na voz de fundo

`PonteIaFundo.responderPergunta` (canal `com.jarvis.nova/fundo_ia`, usado com o
app fora da tela) intercepta antes de pedir a chave e devolve o texto falável.
Sem provedor configurado, o circuito continua sendo montado e falado — é o único
caminho do app que responde algo útil sem chave nenhuma.

## 4. Verificação

- `flutter analyze` → **No issues found**.
- `flutter test` → **323 testes verdes** (eram 319), incluindo
  `test/conversa_circuito_test.dart` (monta na conversa, abre o simulador, recusa
  honesta não abre, conversa comum não vira circuito).
- `dart --enable-asserts run tool/circuito_no_chat_test.dart` → OK: 7 pedidos
  reconhecidos, 6 perguntas poupadas, montagem e recusa conferidas.
- Contrato `tests/test_circuito_no_chat.py` dentro de `npm run test:all`,
  verificando inclusive a **ordem** (depois dos comandos, antes do provedor).
- **Todos os contratos e preflights** (`tests/*.py`, `preflight_*.py`,
  `verificar.py`) com EXIT=0. No caminho apareceu uma falha **antiga**, do 099:
  `tests/test_arquivos_flutter.py` ainda procurava o aviso “Execução de código
  não disponível” em `pages.dart`, mas o 099 mudou esse texto para
  `core/estado_modulos.dart`. O teste passou a ler o catálogo de estado — a
  promessa de “sem sandbox” continua verificada, no lugar certo.

## 5. Limites declarados

- **Nada foi compilado nem instalado nesta sessão.** O APK 1.85.0 e o 1.86.0 não
  existem no aparelho; nenhuma dessas telas foi vista funcionando fora do teste.
- A interceptação é **por texto**, não por intenção aprendida: pedido fora das
  frases previstas segue para o provedor como antes. Não é um classificador.
- O projetista continua montando **oito famílias** em corrente contínua;
  trifásico, transistor, CI e o `.cad` nativo do CADeSIMU seguem fora, com motivo
  escrito.
- Na voz de fundo o circuito é montado e falado, mas **não há botão** — para ver
  o esquema é preciso abrir o app; o texto falado diz isso.

## 6. Arquivos

Novos: `lib/core/circuito_no_chat.dart`, `tool/circuito_no_chat_test.dart`,
`test/conversa_circuito_test.dart`, `tests/test_circuito_no_chat.py`.

Alterados: `lib/services/voice_conversation_page.dart` (interceptação, conclusão
dedicada, cartão e atalho), `lib/services/ponte_ia_fundo.dart` (mesma decisão
para a voz de fundo), `tests/test_dart_core.py`, `package.json`, `pubspec.yaml`,
`CHANGELOG.md`, `docs/INVENTARIO_DE_FUNCOES.md`, `docs/COMPARATIVO-ULTRON.md`.
