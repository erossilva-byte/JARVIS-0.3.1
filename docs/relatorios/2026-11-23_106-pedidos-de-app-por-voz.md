# 106 — Pedidos de app por voz: ficha de pessoa e interruptor duplo

Data: 2026-11-23

## O que foi pedido

Que o JARVIS não só converse, mas execute funções do app quando o pedido é
falado — com dois exemplos: criar a ficha de uma pessoa (“Murilo, 16 anos,
apelido Murilin, melhor amigo”) e montar um circuito de interruptor duplo.

## O que ficou pronto

### 1. Ficha de pessoa por texto e por voz

- `core/pedido_ficha.dart` lê o pedido: nome, idade, apelido e relação
  (“ele é meu melhor amigo”). Pergunta sobre ficha (“qual é a ficha de
  Murilo?”) não é interceptada.
- `services/executor_app.dart` executa a ação no mesmo `PessoasStore` da tela
  de Pessoas. O app nunca gravou ficha sem consentimento; então o executor
  repete os dados entendidos e espera **“confirmo”**, “pode salvar” ou “tenho o
  consentimento”. “Cancela” descarta.
- A conversa (`voice_conversation_page.dart`) e a ponte do segundo plano
  (`ponte_ia_fundo.dart`) chamam o **mesmo** executor, antes de qualquer
  provedor de IA. Com o app fechado, a resposta falada pede a confirmação e a
  fala seguinte grava — enquanto o motor sem tela estiver de pé.
- Pedir a mesma pessoa de novo atualiza a ficha em vez de duplicar; contatos,
  preferências, compromissos e histórico já existentes são preservados.

### 2. Interruptor duplo no projetista

- `FamiliaCircuito.interruptorDuplo`: duas lâmpadas, cada uma com sua tecla, em
  ramos separados alimentados pela mesma fonte. Antes, “interruptor duplo”
  caía na família da lâmpada com interruptor e entregava um esquema com uma
  tecla só.
- O circuito passa pela mesma validação dos outros: `ok` só com simulação
  fechada. A conversa mostra o cartão e o botão “Abrir no simulador”; no
  segundo plano, a resposta falada diz o que foi montado.

## Limites, sem rodeio

- **O CADeSIMU é um programa de computador à parte.** O app monta e simula o
  circuito no projetista próprio e abre no simulador do app; ele **não** opera
  o CADeSIMU instalado no PC nem gera o arquivo do CADeSIMU.
- “Qualquer função do app” ainda não é literal: o executor cobre **fichas**
  por voz hoje; palco, circuito por prompt, comandos do aparelho e perguntas
  livres seguem os caminhos que já existiam. Novas ações entram no mesmo
  executor, uma por vez, com teste.
- O caminho com o app fechado depende do motor sem tela e do plugin de
  armazenamento seguro. Não há Android SDK nesta sessão: **nada disso foi
  compilado nem executado em aparelho**. O que foi verificado é o código e o
  comportamento das partes puras.

## Verificação

- `flutter analyze` limpo.
- `flutter test` — **357 testes** aprovados (349 anteriores + 6 do executor da
  ficha + 2 da conversa).
- `dart run tool/pedido_ficha_test.dart`, `tool/projetista_test.dart` e
  `tool/circuito_no_chat_test.dart` aprovados.
- `python3 tests/test_pedidos_app.py` aprovado, registrado no `test:all`.

## O que não foi verificado

- Criação real da ficha em celular, com voz e com o app fechado.
- Abertura do circuito de interruptor duplo no simulador (visual).
- Compilação Kotlin/Android do pacote.
