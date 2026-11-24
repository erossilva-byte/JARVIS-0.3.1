# Relatório 113 — voz mais rápida, tarefas por voz, botão de mudo e modo de visita

Versão: 1.90.0+19000
Data: 2026-11-24

## 1. O que foi pedido

1. Deixar a voz do JARVIS mais veloz.
2. Fazer o JARVIS realmente executar tarefas pelo microfone — no app **e** no
   segundo plano: abrir apps, mandar mensagens, pausar/retomar música, ativar o
   núcleo, mostrar informações no palco e outras funções já disponíveis.
3. Um botão de mudo na tela principal.
4. Melhorar o visual do modo de visita.

## 2. Como estava antes

- **Voz lenta**: os perfis falavam a 0,88 (grave), 1,00 (natural) e 1,12
  (ágil). O padrão do app era o grave a 0,88, o mais lento dos três.
- **Tarefas por voz**: a conversa executava apenas ficha de pessoa, comandos
  Android (lanterna, volume, abrir app, alarme, localização), circuito, palco e
  automação de tela. Música, mensagem e ligação existiam **só nas telas** — não
  eram alcançáveis falando. O núcleo flutuante só abria pela tela do núcleo.
- **Segundo plano**: o serviço nativo entendia abrir app, lanterna, volume,
  alarme, hora, data, tela e palco, mas não música nem núcleo flutuante.
- **Mudo**: só existia dentro da conversa (ícone de alto-falante), nenhum
  controle na tela principal.
- **Modo de visita**: lista simples de balões e um cabeçalho de duas linhas.

## 3. O que foi feito

### 3.1 Voz mais rápida

- `core/timbre_voz.dart` e `android/JarvisTimbre.kt` (paridade mantida):
  - Grave: tom 0,72 · ritmo **1,12** (era 0,88).
  - Natural: tom 1,00 · ritmo **1,28** (era 1,00).
  - Ágil: tom 1,15 · ritmo **1,45** (era 1,12).
  - **Rápida** (novo): tom 1,00 · ritmo **1,60**, o mais alto que a síntese
    aceita sem picar palavras.
- O padrão continua o Grave — que já fala cerca de 27% mais rápido que antes,
  sem o usuário precisar abrir nada.
- Os limites explicam que acima de ~1,6 a síntese antiga pode picar palavras e
  que o modo noturno continua em 45% de volume.

### 3.2 Tarefas do aparelho por voz

- Novo `core/pedido_nucleo.dart`: entende "ativa o núcleo", "abre o núcleo
  flutuante", "desativa o núcleo". Fica **antes** do comando de abrir app, senão
  o Android procuraria um aplicativo chamado "núcleo". Perguntas ("como ativo o
  núcleo?") não viram ação.
- Novo `services/tarefas_da_voz.dart`: executa, pela ponte real do Android,
  - música: pausar, continuar, próxima, anterior e tocar faixa (a sessão de
    mídia ativa, não só o Spotify);
  - mensagem: WhatsApp, Telegram, SMS, e-mail e os demais apps já registrados;
  - ligação para um contato ou número;
  - núcleo flutuante: ativar e desativar, com o motivo real quando falta
    "Exibir sobre outros apps".
  Textos de lanterna, volume, alarme e núcleo não entram aqui: quem responde por
  eles é o `ExecutorComandosAndroid`, chamado antes.
- `services/voice_conversation_page.dart` passou a chamar a tarefa de núcleo e
  depois as demais tarefas, antes de gastar provedor de IA. Toda execução entra
  no histórico de voz com origem "voz" e o resultado real.
- `android/JarvisFundo.kt` (segundo plano) ganhou dois tipos novos:
  - `MIDIA`: pausar/continuar/próxima/anterior na sessão de mídia ativa. Envia
    o controle pelo `MediaController` do Android e confere o estado depois de
    até 900 ms; se o app não mudar, a resposta diz que não confirmou em vez de
    afirmar que pausou.
  - `NUCLEO`: ativa e desativa o núcleo flutuante pelo `JarvisNucleo`, com
    `sem_permissao` explicado em voz alta.
  O palco em segundo plano já existia e continua igual.

### 3.3 Botão de mudo na tela principal

- `home_screen.dart`: novo estado `mudo`. O botão fica no cartão "MICROFONE" da
  Central de Comando (`ValueKey('mute-button')`) e, ao ligar o mudo, **para o
  detector de palavra de verdade** (`jarvisKwsController.stop()`), interrompe a
  fala em andamento e mostra a faixa "JARVIS MUDO" no topo. Desligar volta a
  escutar pelo mesmo caminho do botão de voz, com o motivo real quando falha.
- Abrir o app com o mudo ligado não religa o detector sozinho.

### 3.4 Fala que começa na hora

- **Causa da demora**: com a voz externa ligada, cada frase era gerada na
  nuvem só na hora de falar (uma ida ao Fish Audio por frase), e a frase
  seguinte só era pedida quando a anterior acabava. O texto já estava na tela e
  o áudio ficava para trás, somando as esperas; o tempo limite da requisição era
  de 30 s antes de cair para a voz local.
- `services/fala_jarvis.dart`: a geração é **adiantada** (`preparar`) enquanto a
  frase atual toca, com até 4 frases à frente. A primeira frase tem prazo de
  2,5 s (3 s no caminho de resposta única). Se a nuvem não responder, a voz do
  aparelho fala na hora e o resto da mesma resposta continua nela, sem trocar de
  voz no meio. `parar()` zera esse estado: a próxima resposta tenta o Fish Audio
  de novo.
- `services/voice_conversation_page.dart`: a fila de fala passa o prazo curto na
  primeira frase e pede a geração adiantada ao enfileirar.
- `services/ponte_ia_fundo.dart`: no segundo plano a voz externa tem 3 s; sem
  isso o serviço ficava em silêncio esperando a nuvem antes de usar a voz do
  aparelho.
- `services/voz_externa_service.dart`: o tempo limite da requisição caiu de
  30 s para 12 s.
- `core/fala_em_fluxo.dart`: frases longas sem ponto final agora falam na
  primeira vírgula ou dois-pontos (a partir de 90 caracteres) e o corte sem
  pontuação caiu de 220 para 140 caracteres — o áudio não espera o parágrafo
  inteiro.
- `tool/fala_em_fluxo_test.dart` e `test/fala_jarvis_test.dart` prendem o novo
  comportamento: geração adiantada sem pedir duas vezes, nuvem lenta caindo
  para o aparelho e retomada depois de `parar()`.

### 3.5 Visual do modo de visita

- Cabeçalho novo com avatar com brilho, selo "MODO DE VISITA", etiqueta "SEM
  DADOS" e a frase de que nada fica visível e nada sai do telefone.
- Sugestões de perguntas que o modo responde sem provedor (horas, data, quem é
  você), que somem depois da primeira pergunta.
- Balões com avatar, cantos assimétricos, gradiente nas falas do usuário e
  rolagem automática para a última mensagem.
- Barra de entrada arredondada com borda ciano.
- Tela de ajustes em cartões: estado do aparelho (tudo vazio), prompt sugerido
  com botão de copiar, o que o modo faz e um aviso de que nada ali muda o app
  real.

## 4. Evidência

- `flutter analyze` sem nenhum problema, 412 testes Flutter (incluindo os novos
  de fala adiantada e de pausa na vírgula) e todos os contratos Python.

- `flutter analyze` sem nenhum problema.
- `flutter test` com toda a suíte Flutter.
- `python3 tests/test_dart_core.py` e todos os `tests/test_*.py`, incluindo o
  contrato dos perfis de timbre atualizado para os quatro perfis e para os novos
  ritmos (0,72/1,12, 1,00/1,28, 1,15/1,45, 1,00/1,60).
- Versão elevada para 1.90.0+19000 no `pubspec.yaml` e nos contratos.

## 5. O que não foi verificado

- Nada foi testado em aparelho físico nesta máquina: voz mais rápida, mudo
  parando o KWS, núcleo flutuante por voz, música e mensagens por voz no app e
  no segundo plano precisam de um celular Android com o APK 1.90.0.
- O controle de música em segundo plano depende de o JARVIS ter acesso a
  notificações; sem esse acesso o Android não entrega as sessões de mídia e a
  resposta será a de "nenhum app de música ativo".
- Mensagem e ligação continuam só no caminho com o app aberto: o Android não
  permite abrir a conversa de outro app a partir do segundo plano sem
  "Exibir sobre outros apps", então isso segue declarado como limite em vez de
  prometido.
- A velocidade 1,60 pode picar palavras em sintetizadores antigos; o texto da
  tela avisa e o usuário pode voltar para Natural ou Grave.
