# Ajuste 034 — revisão de compilação do restante do Java (música, acessibilidade, atualização e voz)

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## Por que este ajuste

A revisão 030 olhou o serviço de escuta. Os outros quatro módulos nativos nunca tinham passado
pelo mesmo crivo — e três deles mexem com recursos que o Android cobra caro quando ficam
soltos: player de mídia, árvore de acessibilidade e motor nativo de voz.

## Defeitos corrigidos

1. **Player vazado** (`JarvisMusicaService`): `setDataSource` falhando deixava um `MediaPlayer`
   nativo vivo a cada faixa inválida. Agora libera antes de pular para a próxima.
2. **Música sem primeiro plano** (`JarvisMusicaService`): as duas tentativas de `startForeground`
   eram engolidas e o serviço continuava; com `startForegroundService`, isso termina em
   `ForegroundServiceDidNotStartInTimeException`. A função devolve `boolean` e o comando encerra
   quando não há primeiro plano.
3. **Acessibilidade travando a interface**: `esperar` dormia até 8 s na thread principal, e
   `arvore`/`clicar`/`digitar`/`rolar` percorriam a árvore na mesma thread — ANR provável.
   As cinco operações foram para uma fila própria, encerrada no `onDestroy`.
4. **Motor de voz liberado durante a síntese** (`JarvisVozPlugin`): `onDestroy` liberava o
   `OfflineTts` nativo antes de parar a fila — use-after-free que mata o processo. Agora para a
   fila, espera até 1,5 s e só então libera; `generate()` roda sob o mesmo cadeado.
5. **Stream vazado no download** (`JarvisUpdatePlugin`): `InputStream` só fechava no caminho
   feliz. Agora fecha em `finally`.

## Evidência

| Verificação | Resultado |
|---|---|
| `npm run verificar` | exit 0 — 3 de 3 etapas; **2364 verificações OK**, 1 aviso |
| `python3 tests/test_segundo_plano_1101.py` | 15 verificações, incluindo o novo "player sem primeiro plano para" |
| Suíte antiga ajustada | a asserção de promoção antes do controle passou a exigir o retorno `boolean` |
| Pré-checagem e empacotamento | exit 0 |

## O que continua sem prova

Nada foi compilado e nada foi medido. Ficam para o CI/aparelho: `java.util.function` no
classpath, autoridade do `FileProvider` no APK, áudio em HyperOS, ANR real sob `esperar` e
reciclagem de nós de acessibilidade no Android 8–12. A revisão completa, com riscos por módulo,
está em `docs/REVISAO-JAVA-COMPILACAO.md` (segunda parte).
