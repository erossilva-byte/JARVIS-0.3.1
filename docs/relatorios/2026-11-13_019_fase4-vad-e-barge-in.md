# Ajuste 019 — Fase 4: atividade de voz e barge-in

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que a Fase 4 pede e o que faltava

A Fase 4 (voz e palavra de ativação) exige, entre outros itens: **detecção de atividade de
voz**, **interromper a fala do Jarvis quando o usuário começa a falar (barge-in), com
cancelamento de eco** e **diagnóstico de microfone**.

O que existia: captura com pré-roll e fim de fala (`escuta.js`), medição de qualidade vocal,
perfis de locutor, botão de parar e o "Jarvis, para" experimental. O que **não** existia:

- nenhuma decisão de "há fala agora" a partir do nível do microfone — não havia VAD;
- **nenhum barge-in**: se você falasse durante a resposta, ele continuava falando por cima;
- nenhuma medição simples do microfone que devolvesse nível, piso de ruído e pico.

## O que foi feito

**`escuta_voz.js` (novo, puro, sem DOM, sem microfone)**

- `nivel(amostras)` → dBFS e pico, com piso em -100 dB.
- `criarDetector({ sensibilidade })` → máquina de estados `silencio`/`fala` com:
  - **piso de ruído adaptativo** (só aprende o ambiente enquanto ninguém fala; 3% por bloco);
  - limiar = piso + margem que cai de 15 dB a 6 dB conforme a sensibilidade sobe;
  - confirmação de 120 ms de energia para começar (blip de porta não vira comando);
  - **cauda de 500 ms** para pausas naturais não cortarem a fala;
  - eventos `inicio`/`fim` e `desdeFalaMs` contando desde a subida de energia.
- `deveInterromper(estado, desdeFalaMs, minimo)` → barge-in só com fala sustentada (padrão 300 ms).
- `resumir(leituras)` → duração, tempo de fala, silêncio, ruído mínimo, pico e classe dominante.

**`app.js`**

- `armarBargeIn()` é chamado junto com a fala: durante o TTS, abre o microfone com
  `echoCancellation`, `noiseSuppression` e `autoGainControl`, mede blocos e, ao detectar fala
  sustentada, **corta a fala na hora** (`interromperFala`) e registra o nível e o limiar.
- `desarmarBargeIn()` roda no `finally` de `falar()`: microfone e contexto de áudio fechados em
  todos os caminhos, sem vazar trilha.
- `medirMicrofone()`: 3 segundos reais de medição, veredito honesto (nada chegou, sinal
  saturando, quase nenhuma fala, fala detectada) com tempo de fala, silêncio, ruído e pico.
  Sem microfone, diz o erro do aparelho em vez de inventar número.
- Interruptor salvo em `voz_interromper` (padrão ligado), com registro no log ao mudar.

**`index.html`**

- Interruptor "Interromper a resposta quando eu começar a falar" (com explicação de que nada é
  gravado nem enviado) e botão "Medir microfone (3 s)" com a linha de resultado.

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_escuta_voz.js` | exit 0, **22 verificações** |
| `npm run test:all` | **exit 0, suíte completa** (inclui o `test_escuta.js` original) |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Silêncio | -100 dB, classe `mudo`, sem fala |
| Tom de 0,2 | cerca de -17 dB (RMS = amplitude/√2), pico 0,2, classe `bom` |
| Início de fala | aos 120 ms (5 blocos de 20 ms não bastam, 6 bastam) |
| Pausa curta | 400 ms de silêncio mantêm a fala; 500 ms encerram com evento `fim` |
| Ruído de fundo | 2 s de ruído baixo não disparam; o piso desce com o ambiente |
| Sensibilidade | o mesmo tom é detectado em 0,9 e ignorado em 0,1 |
| Barge-in | 150 ms e 299 ms não interrompem; 300 ms interrompem |
| Tela (360×740) | `EscutaJarvis` e `EscutaVoz` carregados; interruptor ligado; botão 186×40; sem corte nem rolagem lateral |
| Persistência | desligar grava `0` e volta desmarcado ao recarregar; religar grava `1` |
| Caminho de erro | "Não consegui abrir o microfone: Requested device not found. Verifique a permissão…" em vermelho |

## Incidente durante o ajuste (declarado)

O módulo novo foi criado por cima de um `escuta.js` que **já existia** (pré-roll e detector de
fluxo), e o mesmo aconteceu com `tests/test_escuta.js`. Os dois arquivos foram restaurados do
repositório e o módulo novo passou a se chamar `escuta_voz.js`. A troca de nome também atingiu
duas referências a `window.EscutaJarvis` no app; foram revertidas e o teste agora **falha** se
esse nome voltar a ser alterado. A suíte completa e o `test_escuta.js` original passam.

## O que não foi verificado

- **Microfone real**: este ambiente não tem dispositivo de áudio, então a medição só foi
  exercitada no caminho de erro. Níveis, VAD e barge-in com voz de verdade dependem do aparelho.
- **Barge-in com TTS real**: idem — sem áudio, não houve fala para interromper.
- **KWS sherpa-onnx, serviço de primeiro plano com microfone, notificação persistente e
  segundo plano (Fase 4B)**: são Kotlin/Android nativo; sem SDK e sem o Poco X7 não há como
  implementar nem medir. Continua bloqueado, como o Gate B.
- Nada em aparelho físico.
