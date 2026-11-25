# Bloco 117 — apelido novo, mapa da voz e funções restantes

**Versão:** 1.94.0+19400
**Data:** 25 de novembro de 2026

## Os três pedidos

1. **Aprender apelido novo** — ensinar pela fala que “Murilin” é o “Murilo”.
2. **Conferir funções restantes** — fechar a lista do que ainda não respondia
   por voz.
3. **Ver telas por voz** — uma tela que mostre tudo o que dá para falar.

## Aprender apelido novo

Regra pura nova em `lib/core/pedido_apelido.dart`, com espelho em
`android/JarvisApelidos.kt`. Formas reconhecidas:

| Frase | Nome | Apelido |
| --- | --- | --- |
| o apelido do Murilo é Murilin | Murilo | Murilin |
| apelido de Murilo: Murilin | Murilo | Murilin |
| chama o Murilo de Murilin | Murilo | Murilin |
| conhece o Murilo como Murilin | Murilo | Murilin |
| esquece o apelido Murilin | — | Murilin (remove) |

A exigência de marcador explícito é de propósito: “o céu é azul” e “meu nome é
Murilo” não mexem em contato nenhum. O nome é resolvido pela regra do bloco 116
(apelido, emoji, semelhança); se empatar entre dois contatos, a resposta pede o
sobrenome. O par é gravado em `jarvis_contatos`, lido pela mesma resolução e
mostrado no painel do aparelho, na seção **Apelidos aprendidos**.

Funciona nos dois lugares: `voice_conversation_page` (app aberto) e
`KwsForegroundService` (app fechado), este último via `JarvisApelidos.executar`.

## Mapa da voz

- **Pergunta**: “quais telas você abre?”, “que comandos de voz você tem?”, “me
  mostra as telas” e “o que você faz por voz” são respondidas no aparelho, sem
  provedor, com o total de telas e a dica da lista completa.
- **Tela**: `MapaVozPage`, aberta por “abre o mapa da voz”, “telas por voz”,
  “comandos de voz” ou “mapa dos comandos”. Cada item é a frase de exemplo.
- **Sem lista paralela**: as telas vêm de `TelaJarvis`, então acrescentar uma
  tela já a coloca no mapa. O contrato confere que o total do Kotlin
  (`JarvisMapaVoz.TOTAL_TELAS`) é igual ao número de telas da tabela Dart.

## Conferência das funções restantes

A lista de páginas do app foi comparada com a tabela de voz e com `AbrirTela`.
O resultado virou teste (`tests/test_bloco_117.py`): toda página precisa estar
no mapa **ou** na lista de exclusões com motivo, e o contrato falha se alguém
acrescentar uma tela sem voz.

| Página | Voz |
| --- | --- |
| acessibilidade, aparelho, arquivos, atualização, avatar, backups | abre a tela |
| cad e simulador, circuito, projetista, programação | abre a tela |
| comandos Android, dispositivo, aparelho conectado | abre a tela |
| gestos, habilidades, hermes, histórico, histórico de voz | abre a tela |
| memória, modelos locais, palco, regras do palco | abre a tela |
| personalidade, pessoas, segundo plano, segurança, tarefas | abre a tela |
| timbre, visão, voz externa, voz em tela cheia | abre a tela |
| conversa, palavra de ativação, mapa da voz | abre a tela |
| bloqueio | abre `segurança` (a tela é a mesma) |
| **conflitos** | **excluída**: precisa da lista de conflitos e do cofre |
| **modo visita** | **excluída**: fluxo de segurança com PIN e bloqueio |

Fora das telas, os caminhos que já respondem por fala: apps com ação, mensagem,
ligação, envio sem toque, lanterna/volume/alarme/abrir app pelo nome, Spotify,
palco, ficha de pessoa, visão, núcleo flutuante, automação de tela, circuito por
prompt e a conversa com o provedor.

## Verificações feitas

- `dart run tool/pedido_apelido_test.dart` — oito formas de ensinar, três de
  esquecer, oito frases que **não** podem virar apelido, resumo e frase falada.
- `dart run tool/mapa_voz_test.dart` — pergunta reconhecida, frases que não são
  pergunta, catálogo completo e total igual à tabela.
- `flutter test test/apelido_test.dart` — canal envia apelido, nome e
  `esquecer`; lê a lista; repassa recusa.
- `flutter analyze` — sem problemas.
- `flutter test` — suíte completa.
- `python3 tests/test_bloco_117.py` — contrato, incluindo a cobertura de todas
  as páginas.
- Suíte Python inteira.

## Limites (sem aparelho)

- A gravação foi conferida no código e nos testes de regra; não foi validada com
  contatos reais no celular.
- Apelido fica no aparelho (SharedPreferences), não sincroniza.
- Modo visita e conflitos seguem fora da voz pelos motivos acima.
- Kotlin não é compilável aqui: o nativo foi conferido por leitura e contrato.
