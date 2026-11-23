# Bloco 105 — especialidades, modo palco e microfone de perguntas

Data: 2026-11-23
Versão: 1.88.5+18805

## 1. Pedido

O usuário pediu quatro coisas:

1. que o JARVIS seja **especializado no CADeSIMU e em programação**;
2. um **modo palco** que pesquisa imagens, vídeos ou notícias na internet e
   traz o resultado para a tela;
3. **aprimorar o microfone** para um reconhecimento melhor;
4. ajustar o **microfone do segundo plano** para aceitar perguntas, não só
   comandos.

## 2. O que já existia

- O roteador de agentes (`core/agentes.dart`) escolhia o domínio do pedido, mas
  a instrução de sistema era uma frase genérica por domínio. Não havia
  profundidade própria de CADeSIMU nem de programação.
- O segundo plano já respondia pergunta livre (`PonteIaFundo`), mas a escuta
  cortava em 12 s, o anúncio dizia “ouvindo seu comando” e o reconhecedor
  ficava com a primeira alternativa, sem pista de vocabulário.
- Não havia pesquisa de imagens, vídeos ou notícias no APK. O núcleo web tinha
  pesquisa por Wikipédia/Groq; o Flutter não.

## 3. O que foi feito

### 3.1. Especialidades (`lib/core/especialidades.dart`)

- Duas áreas com id próprio: `cadesimu` e `programacao`.
- Cada uma tem domínio, focos, exemplos e **limites escritos**: o `.cad` é
  proprietário e não é gerado; o CADeSIMU não é simulado por dentro; código não
  é executado, compilado nem testado (não há sandbox no APK).
- `especialidadeDe(texto)` reconhece por palavra-chave, com CADeSIMU antes de
  programação — “programa do CLP” é engenharia, não código.
- `instrucaoDaEspecialidade` monta o bloco de sistema; `blocoDaEspecialidade`
  devolve string vazia para conversa comum, então nada muda no pedido normal.
- A instrução entra em `montarMensagens` (conversa), em
  `mensagensPerguntaLivre` (pergunta livre) e em `PonteIaFundo` (voz de fundo).
- A tela de agentes passou a listar as duas especializações com exemplo.

### 3.2. Modo palco (`lib/core/palco.dart`, `palco_service.dart`, `palco_page.dart`)

- `pedidoPalco(texto)` reconhece “mostra fotos…”, “me mostra um vídeo sobre…”,
  “traz as últimas notícias de…” e limpa o assunto. Conversa comum não abre o
  palco; “mostra o volume” também não.
- Três fontes públicas, sem chave e sem conta:
  - imagens: `commons.wikimedia.org/w/api.php` (espaço de nomes 6, miniatura de
    1200 px);
  - notícias: `news.google.com/rss/search` (`hl=pt-BR`, `gl=BR`);
  - vídeos: `api.dailymotion.com/videos`.
- Os leitores são puros (`lerImagensDoCommons`, `lerNoticiasDoRss`,
  `lerVideosDoDailymotion`), aceitam o formato novo e o antigo da Wikimedia,
  decodificam entidades e descartam o que não for imagem/áudio ou link seguro.
- Link colado no pedido é exibido direto: imagem por extensão, vídeo de
  YouTube/Dailymotion/Vimeo, o resto como página.
- A tela mostra a imagem ou a capa, o título, a fonte, o crédito/duração/data, o
  resumo da notícia, o endereço, “Abrir no navegador” e “Copiar link”, com
  anterior/próximo e lista de resultados.
- Toda falha (tempo, conexão, HTTP, lista vazia) vira frase na tela; nada de
  resultado inventado.
- O Android ganhou `abrirUrl` no canal `com.jarvis.nova/sistema`, restrito a
  `http(s)`.

### 3.3. Microfone (`JarvisEscutaFundo.kt`, `MainActivity.kt`)

- Melhor alternativa pela nota de confiança (`CONFIDENCE_SCORES`); nota negativa
  é “não informada” e vale a hipótese mais completa.
- Pista de vocabulário (`EXTRA_BIASING_STRINGS`, Android 13+) com termos de
  elétrica/CADeSIMU, programação, palco e comandos.
- Silêncio de fim de fala em 2,6 s (possível 2,0 s; mínimo 1,2 s), para pergunta
  com pausa no meio da frase.
- A escuta de fundo vai a 20 s e anuncia “pergunte ou dê um comando”. O que não
  for comando reconhecido segue para a ponte de IA, como antes, e agora com a
  especialidade aplicada.
- Textos de `core/fundo.dart` e da tela de segundo plano passaram a dizer que a
  pergunta é aceita.

### 3.4. Catálogo e estado

- `Modo palco` entrou no catálogo (grupo Conhecimento) e na tabela de estado
  como **parcial**, com tela própria: 26 módulos — 17 prontos, 5 parciais e 4
  ausentes.

## 4. Evidência

- `flutter analyze` sem problemas.
- `flutter test` — 341 testes, todos aprovados (337 anteriores + 4 novos do
  palco).
- `dart run tool/palco_test.dart` — pedido, endereços sem chave, leitores das
  três fontes, links seguros e entidades.
- `dart run tool/especialidades_test.dart` — reconhecimento das duas áreas,
  prioridade CADeSIMU, conversa comum intacta e limites escritos.
- `dart run tool/estado_modulos_test.dart` — 26 módulos, 17/5/4.
- `python3 tests/test_palco_especialidades.py` — contrato estático deste bloco.
- `python3 ci/contratos_python.py` — 107/107 comandos Python aprovados.

## 5. Limites declarados

- O palco **não** baixa mídia para a pasta do app, **não** cria conta e **não**
  toca vídeo dentro do APK: vídeo e matéria abrem no navegador.
- As fontes são serviços de terceiros; podem mudar de formato, limitar pedidos
  ou sair do ar. A tela diz o motivo e não substitui o resultado por texto
  inventado.
- A especialização é instrução de prompt, não ferramenta: não gera `.cad`
  nativo, não abre o CADeSIMU e não executa código.
- O reconhecimento continua sendo **só o offline do Android**; não há fallback
  de nuvem. A pista de vocabulário só existe no Android 13+.

## 6. Não verificado

- Nada foi aberto em aparelho físico.
- As três fontes não foram consultadas pelo app no celular; a rede do ambiente
  de desenvolvimento respondeu, mas isso não mede Wi-Fi/5G do usuário.
- O microfone novo não foi ouvido: não há medição de acerto, ruído nem sotaque.
- O aviso “pergunte ou dê um comando” e o limite de 20 s não foram observados
  com o app fechado.
- `abrirUrl` não foi exercitado no Android; o teste cobre só a restrição a
  `http(s)` e a presença do método.
- O modo palco não foi visto em tela: layout, imagem grande e lista não foram
  conferidos visualmente.
