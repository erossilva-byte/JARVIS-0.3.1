# Bloco 104 — modo programação, avatar 3D e voz do Fish Audio

Data: 2026-11-23 · Versão: 1.88.4+18804 · Branch: `main`

## 1. O que o usuário pediu

Três coisas, na mesma frase:

1. começar o **modo de programação** do JARVIS — criar, analisar, modificar e
   explicar código, com prompt de pedido e uma área para o código;
2. **finalizar o Avatar 3D**, que a tela dizia não existir no APK;
3. usar o **ID de voz do Fish Audio** `82d13948027e4be69892dd3d0104e681` como
   voz do JARVIS, ou deixá-lo guardado como padrão local.

## 2. Modo programação

Arquivos novos:

| Peça | Arquivo | O que faz |
| --- | --- | --- |
| Contrato puro | `lib/core/programacao.dart` | 5 tarefas, 17 linguagens, validação, mensagens ao provedor, extração de blocos, nome do arquivo, prompt local e limites |
| Tela | `lib/services/programacao_page.dart` | chips de tarefa, linguagem, área de código, campo de erro, resposta com blocos, copiar, usar na área e salvar em Arquivos |
| Teste puro | `tool/programacao_test.dart` | tarefas, validação, cercas, explicação, nome do arquivo e prompt |
| Teste de tela | `test/programacao_page_test.dart` | recusa sem chamada, resposta com bloco, usar na área, salvar e prompt sem provedor |

O que a tela faz de verdade:

- **Criar**: pedido em texto, resposta com bloco de código.
- **Analisar**: exige código colado; a instrução manda citar trecho por achado.
- **Modificar**: exige código e o que mudar; devolve o arquivo inteiro.
- **Explicar erro**: exige código e a mensagem de erro.
- **Prompt de código**: montado no aparelho com `promptDeCodigo`, **sem
  provedor e sem rede**.
- **Área de código**: campo monoespaçado com contador, colar e limpar; recebe
  qualquer bloco da resposta com “Usar na área”.
- **Salvar em Arquivos**: grava `codigo_<linguagem>.txt` na pasta isolada, sem
  sobrescrever (`_2`, `_3`…).

A resposta usa o mesmo `ProviderService` do Hermes: primeiro provedor
configurado, chave no cofre, erros traduzidos. Sem chave, a tela diz que falta a
chave — não inventa resposta. O prompt local continua funcionando.

Limite dito na tela: **nada é executado, compilado ou testado**. Não há sandbox,
terminal nem permissão para rodar programa neste APK.

## 3. Avatar 3D

O que existia: um holograma 2D do núcleo (`hologram.dart`) e a frase “não há
malha 3D nem renderizador 3D neste APK”.

O que passou a existir:

| Peça | Arquivo | O que faz |
| --- | --- | --- |
| Geometria pura | `lib/core/avatar3d_geo.dart` | perfil do busto, malha por revolução, rotação em dois eixos, projeção em perspectiva, olhos, boca, reator, órbitas e partículas |
| Pintura | `lib/avatar3d.dart` | algoritmo do pintor: ordena as faces por profundidade, ilumina pela normal e desenha rosto e adereços |
| Tela | `lib/services/avatar_page.dart` | avatar 360 px, arraste horizontal para girar, dois toques para centralizar, cinco estados e “girar sozinho” |
| Teste puro | `tool/avatar3d_test.dart` | comprimento preservado no giro, perspectiva, malha, normal, rosto, boca e órbitas |
| Teste de tela | `test/avatar_page_test.dart` | desenha, gira com o dedo, troca de estado e desliga o balanço |

Escolhas técnicas, para não prometer o que não há:

- **Sem modelo importado** (glTF/OBJ) e **sem motor de terceiros**: a malha do
  busto nasce da revolução de um perfil (peito → ombros → pescoço → cabeça) com
  960 a 1.800 faces, e cada quadro gira, projeta e ordena as faces no próprio
  Flutter.
- A boca abre por duas senoides (não é áudio real); os olhos piscam e apertam
  no estado “pensando”; o reator pulsa; as órbitas giram em velocidades
  diferentes.
- O giro por gesto é **horizontal** de propósito: o deslize vertical continua
  rolando a página, sem disputa entre os dois gestos.
- As expressões são **prévia**: o avatar não escuta o microfone. Ligar ao áudio
  fica declarado como próximo passo, na tela e aqui.

## 4. Voz do Fish Audio

O ID pedido já era o padrão do app (`idVozPadrao`), mas o serviço por trás era o
ElevenLabs — URL, corpo (`model_id`, `voice_settings`) e nome errados para o
Fish Audio. Agora:

- `nomeServicoVoz = 'Fish Audio'`; endereço `https://api.fish.audio/v1/tts`;
- corpo com `text`, `reference_id` (o ID, normalizado) e `format: mp3`;
- o ID vai **no corpo**, como o serviço pede, não na URL;
- a chave vai em `Authorization: Bearer …`, só nesse cabeçalho — nunca na URL
  nem no corpo, para não sobrar em log;
- erros 401/403, 402/429 e 422 seguem traduzidos, com o nome do serviço.

O ID continua guardado localmente em `SharedPreferences` e a chave no cofre do
aparelho. Sem chave, o JARVIS fala com a voz do sistema.

## 5. O que mudou de estado

`Programação (sem execução)` e `Avatar 3D` saíram de **ausente** e passaram a
**parcial**, com tela própria. A gaveta passou a chamar o item de
`Programação`. A contagem do catálogo ficou em 17 prontos, 4 parciais e 4
ausentes — os ausentes que sobraram são os que dependem de canal, ponte ou
motor que não existem: pareamento, controle do Windows, ESP32 e modelos locais.

## 6. Verificação

Nesta sessão, com Flutter 3.50.1 (Dart 3.14) instalado fora do projeto:

- `flutter pub get` — dependências do lockfile, sem upgrade;
- `flutter analyze` — **nenhum problema**;
- `flutter test` — **337 testes aprovados**, incluindo os dois arquivos novos;
- `dart run` dos testes puros novos: `tool/programacao_test.dart`,
  `tool/avatar3d_test.dart`, `tool/voz_externa_test.dart`,
  `tool/estado_modulos_test.dart` — todos OK;
- `python3 ci/contratos_python.py` — **106/106** contratos.

Contratos ajustados porque a realidade mudou, não para calar falha:
`tests/test_dart_core.py` (dois testes puros novos),
`tests/test_arquivos_flutter.py` (o módulo agora tem tela e continua sem
execução) e os 27 pinos de versão para `1.88.4+18804`.

## 7. Limites declarados

- **Nada foi aberto em aparelho.** Não há Android SDK nem celular nesta sessão:
  o avatar e o modo programação foram verificados por análise estática e testes
  de widget, não por uso real.
- **Nenhum código foi executado**, por definição do modo; a resposta do
  provedor não é testada pelo app.
- **A voz do Fish Audio nunca falou aqui**: não há chave do serviço nesta
  sessão. A tela de voz externa continua sendo o lugar de cadastrar a chave.
- O avatar **não reage ao microfone** e não tem semelhança com pessoa real.
- O APK de release com estas mudanças **ainda não foi gerado**; a esteira
  `flutter-release-apk.yml` precisa rodar no commit que incluir este bloco.
