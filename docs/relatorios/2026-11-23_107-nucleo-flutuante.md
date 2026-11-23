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
- `flutter test` — **362 testes** aprovados (357 anteriores + 5 da tela do
  núcleo, com canal simulado: ligar, teletransportar, pausar/retomar,
  econômico e autorização).
- `python3 tests/test_nucleo_flutuante.py` aprovado e registrado no `test:all`.

## O que não foi verificado

- **Compilação Kotlin/Android**: não há Android SDK nesta sessão. O contrato
  confere o código e o desenho, não o `addView` nem o APK.
- **Aparência real** do núcleo, do brilho, do teletransporte e do arrasto em
  celular — nenhuma imagem foi vista.
- Comportamento em fabricantes que restringem sobreposição.
