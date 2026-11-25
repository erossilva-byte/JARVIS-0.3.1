# Bloco 115 — mensagem sem toque e abrir app com ação

**Versão:** 1.92.0+19200
**Data:** 25 de novembro de 2026

## O pedido

Dois pedidos que faltavam depois do bloco 114:

1. **Mensagem sem toque** — depois de abrir a conversa com o texto pronto, não
   precisar tocar em “enviar”.
2. **Abrir app com ação** — abrir o app de terceiro já na conversa, no rascunho,
   na busca ou na rota, em vez da tela inicial.

## Como ficou

### Abrir app com ação

Uma regra pura nova, `lib/core/pedido_app.dart`, com duas tabelas de chaves
estáveis (apps e ações) e o reconhecimento da frase. Ela só age com verbo de
abrir **e** uma ação reconhecida; mensagem, ligação, telas do JARVIS e perguntas
ficam de fora. O pedido vira `app + ação + alvo`:

| Frase | App | Ação | Alvo |
| --- | --- | --- | --- |
| abre o WhatsApp na conversa da Ana | whatsapp | conversa | Ana |
| abre a conversa com o João no WhatsApp | whatsapp | conversa | João |
| abre o Gmail para escrever para a Ana | gmail | escrever | Ana |
| abre o mapa até a Rua das Flores | maps | navegar | Rua das Flores |
| abre o mapa de São Paulo | maps | pesquisar | São Paulo |
| abre o YouTube e pesquisa gatos | youtube | pesquisar | gatos |
| abre o Spotify e toca Legião Urbana | spotify | tocar | Legião Urbana |
| abre a câmera | camera | camera | — |
| abre a calculadora | calculadora | abrir | — |

O link é montado no Kotlin (`android/JarvisAbrirApp.kt`), porque é lá que estão
o `PackageManager` e os contatos: `wa.me`, `t.me`, `ig.me/m`, `mailto:`,
`google.navigation:q=`, `geo:0,0?q=`, a busca do YouTube, `spotify:search:` e a
câmera do sistema. Quando o contato não é achado ou o app recusa o link, a
resposta diz — nunca “abri” sem ter aberto.

Caminhos ligados:

- `voice_conversation_page.dart` chama `AbrirAppComAcao.executar` antes do
  comando de abrir app pela lista;
- `KwsForegroundService.kt` chama `JarvisAbrirApp.interpretar` antes da pergunta
  livre, com a mesma checagem de “Exibir sobre outros apps”;
- `JarvisAparelho.kt` ganhou o método `abrirComAcao` do canal
  `com.jarvis.nova/aparelho`.

### Mensagem sem toque

`android/JarvisEnvioSemToque.kt` procura o botão Enviar na árvore de
acessibilidade e toca nele por `ACTION_CLICK`. As travas, todas no código:

- exige o serviço de acessibilidade autorizado (`servicoLigado`);
- exige o interruptor “Enviar mensagem sem toque” ligado (padrão ligado);
- exige que a janela ativa seja **do pacote** que o JARVIS acabou de abrir;
- exige o texto pedido visível na tela antes de tocar;
- só toca em nó com rótulo “enviar/send” (ou id de envio), nunca em bolha de
  mensagem;
- prazo curto (6 s no app aberto, 5 s no segundo plano); passou disso, não toca.

O resultado separa três casos e o alto-falante fala o que aconteceu: enviado,
aberto mas sem achar o botão, ou aberto com o texto e o toque ainda seu. O
interruptor fica na tela de acessibilidade, separado do consentimento de
leitura, e é lido/gravado pelo canal `com.jarvis.nova/acessibilidade`.

### Empacotamento

As classes Kotlin novas (`JarvisAbrirApp.kt` e `JarvisEnvioSemToque.kt`) e as do
bloco 114 (`JarvisAbrirTela.kt`, `JarvisMensagens.kt`, `KwsForegroundService.kt`)
não estavam na lista de cópias de `tool/prepare_android_sistema.py` — sem isso o
APK sairia sem elas e o build quebraria. As cinco linhas de cópia entraram, e o
contrato deste bloco passou a cobrá-las.

## Verificações feitas

- `dart run tool/pedido_app_test.dart` — 25 frases conferidas (ação, alvo,
  resumo e frase falada), incluindo as que **não** podem virar ação de app.
- `flutter analyze` — sem problemas.
- `flutter test` — suíte completa.
- `python3 tests/test_bloco_115.py` — contrato do bloco.
- Suíte Python inteira (`tests/test_*.py`).

## Limites (sem aparelho)

- Kotlin não é compilável nesta máquina: os arquivos nativos foram conferidos
  por leitura e pelo contrato, não por build.
- Não foi possível confirmar no celular o toque real no Enviar (rótulos e tempo
  de carregamento variam por versão do WhatsApp, Gmail e Telegram), a conversa
  do WhatsApp aberta por nome de contato nem a rota no Google Maps.
- Instagram e Telegram só abrem direto na conversa quando o usuário é dito; com
  nome de contato o app abre na tela inicial, e a resposta diz isso.
- O envio sem toque não funciona com o serviço de acessibilidade desligado nem
  quando o app de destino muda o botão de lugar.
