# Ajuste 086 — habilidades em Markdown carregadas do aparelho

Data: 2026-11-21 · Versão: 1.73.0+17300 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido

Seguir o roadmap do comparativo com o U.L.T.R.O.N. 2.0: skills em Markdown, com
pastas de habilidades que o JARVIS carrega do próprio aparelho.

## 2. O que existia

- O cofre já conecta uma pasta do Obsidian por SAF, lê todos os `.md` e grava
  notas com subpastas (`CofreSaf`, `listarNotas`, `escreverNota`).
- O leitor de Markdown já separa frontmatter e corpo (`lerMarkdown`).
- O que faltava: nenhuma regra de “pasta de habilidades”, nenhum casamento entre
  a pergunta e um procedimento, e nenhuma forma de o texto do usuário entrar no
  pedido ao provedor de IA.

## 3. O que foi feito

### Núcleo puro (`core/habilidades.dart`)

- **Pastas reconhecidas**: `Skills/`, `Habilidades/` e `Habilidade/`, em qualquer
  nível do cofre. Arquivo solto na raiz não é habilidade.
- **Leitura**: frontmatter `nome`/`titulo`/`title`, `descricao`/`description` e
  `gatilhos`/`triggers`/`quando`/`para`; o corpo é o passo a passo. Sem
  frontmatter, o título do Markdown vira o nome; sem corpo, a habilidade é
  recusada.
- **Sem duplicata**: nome repetido mantém o primeiro; no máximo 24 habilidades.
- **Ativação**: a pergunta (sem acento e sem caixa) é comparada com os gatilhos
  e com palavras do nome (4+ letras); no máximo duas habilidades por pergunta e
  nada é ativado com pergunta vazia.
- **Bloco de pedido**: nome, descrição, “Quando” e “Passos”, com limite de 4000
  caracteres, mais a instrução para citar a habilidade usada.

### Leitura do aparelho (`services/habilidades_service.dart`)

- Lê a pasta conectada via SAF — a mesma do cofre — e a pasta local do app
  (`habilidades/`), sem nuvem e sem executar nada.
- **“Criar exemplo no aparelho”** grava `Skills/exemplo-revisar-texto.md` na
  pasta conectada quando há escrita; sem cofre, grava na pasta local e diz onde.
- Sem pasta, sem escrita ou sem `Skills/`, a tela explica o motivo.

### Conversa e transparência

- `montarMensagens` ganhou o bloco `habilidades` como instrução de sistema,
  depois da personalidade, da memória e das fichas de pessoas.
- `voice_conversation_page` carrega as habilidades, casa com a pergunta e mostra
  “Habilidades usadas: …” na resposta; o nome fica salvo no histórico.
- A pergunta por voz em segundo plano (ponte de IA do ajuste 085) também usa as
  habilidades que casam.

### Tela e navegação

- Nova tela **Habilidades em Markdown** com o formato do arquivo, a origem da
  leitura, a lista de habilidades (nome, descrição, gatilhos e caminho), “Ler de
  novo” e “Criar exemplo no aparelho”.
- Módulo no catálogo, atalho na gaveta e rota na home.

## 4. Evidência

- `flutter analyze` → `No issues found!`
- `flutter test` → `+204: All tests passed!` (inclui os 3 casos novos de `habilidades_page_test.dart`)
- Teste puro com asserções ligadas:
  `dart --enable-asserts run tool/habilidades_test.dart` → OK
- Contrato `tests/test_habilidades_flutter.py` dentro de `npm run test:all`
- APK release arm64: `JARVIS-Nova-1.73.0-habilidades.apk`, 117 973 784 bytes,
  SHA-256 `b8a60565f0df9233a517f0765a310497430dc2e498bc98a68097da146e27b3d1`
  (https://files.catbox.moe/stibpp.apk).

## 5. Arquivos

- `lib/core/habilidades.dart` (novo): pastas, leitura, casamento e bloco.
- `lib/services/habilidades_service.dart` (novo): SAF + pasta local + exemplo.
- `lib/services/habilidades_page.dart` (novo): tela.
- `lib/core/memoria_busca.dart`: `montarMensagens` com `habilidades`.
- `lib/core/conversa.dart`: habilidades usadas na mensagem e no JSON.
- `lib/services/voice_conversation_page.dart` e `lib/services/ponte_ia_fundo.dart`:
  carga e uso das habilidades.
- `lib/catalog.dart`, `lib/drawer.dart`, `lib/home_screen.dart`: navegação.
- Testes: `tool/habilidades_test.dart`, `test/habilidades_page_test.dart`;
  contrato `tests/test_habilidades_flutter.py`.

## 6. Não verificado

- **Nenhum aparelho físico nesta sessão**: a leitura de uma pasta real via SAF,
  a gravação em `Skills/` e a resposta do provedor com o bloco não foram
  medidas.
- A ativação por gatilho é simples (texto contido). Perguntas com sinônimos que
  não estejam nos gatilhos não ativam a habilidade.
- Habilidades grandes são truncadas no bloco, e só duas entram por pergunta.
- Se o Android encerrar o app, a pergunta por voz em segundo plano não carrega
  as habilidades (a ponte de IA também cai), como já registrado no ajuste 085.
- Nada foi commitado nem enviado.
