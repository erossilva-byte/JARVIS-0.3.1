# Bloco 116 — conferência da voz e nomes de contato

**Versão:** 1.93.0+19300
**Data:** 25 de novembro de 2026

## O pedido

1. Conferir se o app realiza os pedidos e as funções por comando de voz.
2. Fazer o JARVIS entender o contato do jeito que a pessoa é chamada —
   “Murilin” = “Murilo”, “Biaa🩵🩵” = “Bia” ou “Beatriz” — com a lista de
   contatos do aparelho.

## Conferência da voz

Levantei as telas que existem em `lib/services/*_page.dart` e comparei com a
tabela de voz (`lib/core/pedido_abrir.dart` + `android/JarvisAbrirTela.kt`) e com
`AbrirTela`. Caminhos que respondem por fala, hoje:

| Caminho | O que faz | Onde |
| --- | --- | --- |
| Telas do JARVIS | abre a tela pedida, no app e no segundo plano | `pedido_abrir.dart` → `abrir_tela.dart` |
| App com ação | conversa, rascunho, busca, rota, câmera | `pedido_app.dart` → `JarvisAbrirApp.kt` |
| Mensagem e ligação | WhatsApp, SMS, Telegram, e-mail; liga ou abre o discador | `aparelho.dart` → `JarvisMensagens.kt` / `JarvisAparelho.kt` |
| Envio sem toque | toca em Enviar pelo serviço de acessibilidade | `JarvisEnvioSemToque.kt` |
| Comandos do Android | lanterna, volume, alarme, abrir app pelo nome, localização | `comandos_android.dart` → `JarvisComandos.kt` |
| Tarefas da voz | Spotify (pausar, avançar, tocar faixa), mensagem, ligação | `tarefas_da_voz.dart` |
| Palco | fotos, vídeos e notícias sobre um assunto | `palco.dart` → `JarvisPalco.kt` |
| Ficha de pessoa | entende nome/relação e pede consentimento | `pedido_ficha.dart` → `executor_app.dart` |
| Visão | abre a câmera e descreve a imagem | `visao.dart` → `visao_service.dart` |
| Núcleo flutuante | ativa e desativa o núcleo por cima dos apps | `pedido_nucleo.dart` |
| Automação de tela | ler, tocar por texto e rolar | `acessibilidade.dart` → `JarvisAcessibilidade.kt` |
| Circuito, projetista e CAD | monta e simula por prompt | `circuito_no_chat.dart`, `projetista.dart` |
| Conversa e IA | o resto vai para o provedor configurado | `voice_conversation_page.dart` |

### Lacunas encontradas e corrigidas

Quatro telas existiam no app e não estavam na tabela de voz:

- **backups da memória** (“abre os backups”, “notas de backup”);
- **regras do palco** (“abre as regras do palco”);
- **histórico de voz** (“abre o histórico de voz”);
- **palavra de ativação** (“abre a palavra de ativação”, “hotword”).

As quatro entraram nos dois lados (Dart e Kotlin), com tela montada em
`AbrirTela`. Com isso, 35 telas respondem por voz.

### Lacunas deixadas de propósito

- **Modo visita**: é fluxo de segurança com PIN e bloqueio; abrir por voz sem o
  PIN seria um atalho perigoso. Continua só pela tela de segurança.
- **Conflitos de sincronização**: a tela precisa da lista de conflitos e do
  cofre; abrir vazia não mostra nada.
- **Abrir app pelo nome** depende do rótulo instalado; nome que não existe no
  aparelho recebe recusa, não um palpite.

## Nomes de contato

A busca antiga era `LIKE '%nome%'` no nome salvo. “Murilin” não achava
“Murilo”, “Biaa🩵🩵” não achava “Bia” e “Bia” nunca chegava em “Beatriz”.

Agora existe uma regra única, `JarvisContatos.kt` (Android) com espelho em
`lib/core/nome_contato.dart`:

1. **Normalização**: sem acento, minúsculas, emoji e pontuação fora, letras
   repetidas compactadas. “Biaa🩵🩵” → `bia`; “João!!! 🎉” → `joao`.
2. **Variantes**: nome completo, cada palavra, sem enfeites (“tia”, “trabalho”,
   “whatsapp”), raiz sem a vogal final (“Murilo” → `muril`) e apelidos comuns do
   português (Bia → Beatriz/Bianca, Zé → José, Duda → Eduarda, Nanda → Fernanda,
   Paty → Patrícia, Leo → Leonardo, e outros).
3. **Semelhança**: igual, prefixo, palavra inteira ou distância de edição com
   limite por tamanho. “Murilin” × “Murilo” fica em 0,66; “Ana” × “Mariana” fica
   em zero.
4. **Decisão**: só age com um melhor candidato. Empate vira frase com os nomes:
   “Achei mais de um contato parecido com Bia: Beatriz Lima, Bianca. Diga o
   sobrenome.” Quando dois nomes são um prefixo do outro (“Murilo” e “Murilo
   Silva”), fica o mais curto.
5. **Aprendizado**: nome dito diferente do salvo e contato único → o par fica
   guardado (`jarvis_contatos`), e a próxima vez é acerto exato.

Integrações: `JarvisAparelho` (mensagem, ligação, e-mail e a busca do painel),
`JarvisMensagens` (app fechado, com pergunta de empate) e `JarvisAbrirApp`
(conversa/e-mail já na ação). No painel do aparelho a lista sai ordenada pelo
nome digitado, então o contato mais parecido aparece primeiro.

## Verificações feitas

- `dart run tool/nome_contato_test.dart` — normalização, apelidos, semelhança,
  empate, desempate, lista vazia e ordenação.
- `dart run tool/pedido_abrir_test.dart` — as telas de antes continuam abrindo.
- `flutter analyze` — sem problemas.
- `flutter test` — suíte completa.
- `python3 tests/test_bloco_116.py` — contrato do bloco (paridade dos apelidos e
  das notas entre Dart e Kotlin, integrações, telas, versão e registros).
- Suíte Python inteira.

## Limites (sem aparelho)

- A agenda real não foi lida nesta sessão; os casos “Murilin/Murilo” e
  “Biaa🩵🩵/Bia/Beatriz” foram conferidos na regra pura, com nomes de teste.
- Nome salvo com apelido de família (“Mãezinha”, “Bebê”) não é adivinhado; o
  aprendizado cobre depois da primeira vez com o nome salvo.
- Permissão de contatos negada deixa a lista vazia e a resposta diz isso.
- Kotlin não é compilável nesta máquina: o nativo foi conferido por leitura e
  pelo contrato.
