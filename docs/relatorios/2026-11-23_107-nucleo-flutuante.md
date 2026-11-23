# 107 — Núcleo flutuante 3D, no estilo Shimeji

Data: 2026-11-23

## O que foi pedido

Um “Núcleo do JARVIS” no estilo dos mascotes de desktop (Shimeji/Aneko), com
tamanho adequado ao Android, modelo 3D animado e brilhoso, que se movimenta pela
tela se teletransportando com animação.

## O que ficou pronto

- **Janela de sobreposição** (`android/JarvisNucleo.kt`): o núcleo é uma janela
  `TYPE_APPLICATION_OVERLAY`, pequena e transparente, por cima dos outros apps.
  Tamanho padrão **112 dp**, ajustável de **72 a 160 dp**; posição limitada à
  área visível, descontando barra de status e de navegação.
- **Esfera 3D calculada no aparelho**: icosaedro subdividido (42 vértices, 120
  arestas), girado em dois eixos e projetado em perspectiva, com arestas mais
  fortes na frente, halo radial, núcleo branco-azulado, dois anéis e partículas
  em órbita. Não há imagem pronta nem motor 3D externo — é geometria projetada,
  como no avatar 3D do app.
- **Teletransporte**: a cada 4–12 s (padrão 7 s, com variação), o núcleo encolhe
  e some em 170 ms, a janela muda para um ponto aleatório e ele volta com
  `OvershootInterpolator` e um clarão em anel.
- **Interação**: arrastar move a janela e pausa o teletransporte por 2,5 s; tocar
  abre o app.
- **Tela de controle** (`lib/nucleo/nucleo_page.dart`, alcançável pelo Avatar
  3D): prévia animada no app, interruptor, tamanho, ritmo, botão “Teletransportar
  agora” e o atalho para autorizar “Exibir sobre outros apps”. A tela avisa do
  consumo de bateria.
- **Canal** `com.jarvis.nova/nucleo`: estado, iniciar, parar, teletransportar e
  abrir o ajuste de sobreposição.

## Pausar e modo econômico

- **Pausar** congela o tempo do desenho (giro, anéis, partículas e flutuação) e
  cancela o teletransporte agendado; o núcleo continua visível, arrastável e
  abrindo o app no toque. Retomar volta do ponto congelado. O estado mora no
  objeto do serviço: fechar e reabrir a tela do app não despausa. Mudar tamanho
  ou ritmo recria a janela e preserva a pausa.
- **Modo econômico** limita o desenho a 20 quadros por segundo (um quadro a cada
  50 ms), aplica 85% de brilho, para de desenhar quando a tela apaga (volta ao
  acender) e dobra o intervalo do teletransporte. É uma redução, medida pelo que
  o código faz, não uma promessa de número de bateria.

## Menu no núcleo e medição da economia

- **Menu**: toque curto abre o app; toque longo (480 ms) abre um menu escuro
  ancorado ao lado do núcleo, com Pausar/Retomar, Modo econômico, Teletransportar
  agora (desabilitado quando pausado), Tamanho P/M/G, Abrir o JARVIS e Desligar o
  núcleo. Tocar fora fecha. Cada item chama a mesma função da tela; nada é
  decorativo. Enquanto o menu está aberto, o teletransporte agendado fica
  suspenso.
- **Medição**: o próprio desenho conta quadros e tempo em cada modo (normal e
  econômico). A tela mostra quadros/s, segundos medidos, a diferença percentual e
  um botão para zerar. Com menos de 5 s em um dos modos, a tela diz que a amostra
  é curta e não conclui. Não há promessa de bateria: a medição diz trabalho de
  desenho, não consumo elétrico.

## Menu acompanhando e consumo real

- **Menu acompanha o núcleo**: o arrasto atualiza a posição do menu com a mesma
  geometria isolada em `PosicaoMenu.calcular` (à direita quando cabe, à esquerda
  quando não, limitado às barras). O menu mede a própria altura depois de
  montado e se reposiciona; a regra é espelhada em Dart e testada nos quatro
  cantos, no menu maior que a tela e no deslocamento junto com o núcleo.
- **Consumo real**: janelas controladas medem `Process.getElapsedCpuTime()` e a
  variação de `BATTERY_PROPERTY_CAPACITY` em cada modo. A tela mostra CPU (ms/s),
  bateria (%/h), duração e a diferença entre os modos, com motivo explícito
  quando a amostra não conclui: menos de 20 s, tela apagada, aparelho carregando
  ou bateria sem queda. O texto diz que o Android **não** entrega energia por
  janela sobreposta: isto compara trabalho, não watts.

## Limites, sem rodeio

- **O núcleo vive enquanto o processo do JARVIS viver.** Ele não é um serviço
  em primeiro plano próprio: se o Android encerrar o app, ele some. Manter o
  modo sem tela ligado ajuda, mas não é garantia.
- **Precisa de “Exibir sobre outros apps”**. Sem a autorização, a tela explica e
  oferece o ajuste; nada é desenhado por cima de ninguém.
- **Bateria**: a esfera é redesenhada continuamente para girar. Em aparelho
  modesto isso pesa; o tamanho e o ritmo são ajustáveis, mas não há modo
  “econômico” ainda.
- Alguns fabricantes bloqueiam sobreposição por padrão ou exigem autorização
  extra; o app avisa o que falta, não finge que apareceu.

## Verificação

- `flutter analyze` limpo.
- `flutter test` — **383 testes** aprovados (357 anteriores + 7 da tela do
  núcleo com canal simulado + 5 da medição de quadros + 6 do posicionamento do
  menu + 8 do cálculo de consumo).
- `python3 tests/test_nucleo_flutuante.py` aprovado e registrado no `test:all`.

## O que não foi verificado

- O menu do núcleo **não foi aberto em aparelho** e não tem teste de toque real:
  o contrato confere estrutura, itens e chamadas, não o comportamento na janela
  sobreposta.
- **Compilação Kotlin/Android**: não há Android SDK nesta sessão. O contrato
  confere o código e o desenho, não o `addView` nem o APK.
- **Aparência real** do núcleo, do brilho, do teletransporte e do arrasto em
  celular — nenhuma imagem foi vista.
- Comportamento em fabricantes que restringem sobreposição.
