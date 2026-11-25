# Bloco 120 — a máscara de PIN e os comandos com número

**Versão:** 1.97.0+19700
**Data:** 25 de novembro de 2026

## A pergunta

Se a máscara de 4 a 8 dígitos poderia atrapalhar um apelido com número
(“Murilo 2”) ou um comando com número (“dizendo que o código é 4321”).

## A resposta curta

Não atrapalha, por construção: a máscara **só** é chamada na hora de gravar.

Levantamento de todas as chamadas:

| Onde | Arquivo | O que grava |
| --- | --- | --- |
| App → Android | `lib/services/historico_voz_service.dart` | pedido do histórico de execuções |
| Android | `android/JarvisFundo.kt` (dentro de `anotar`) | a mesma coisa, cobrindo o segundo plano |
| Conversa | `lib/services/conversa_store.dart` | título, mensagens e rascunho salvos |

Nenhum desses pontos participa da interpretação da fala. As regras que entendem
o pedido — `core/pedido_apelido.dart`, `core/nome_contato.dart` e
`core/aparelho.dart` — não importam `segredo_pedido.dart`, e o Kotlin que
resolve contato e envia mensagem (`JarvisContatos`, `JarvisMensagens`,
`JarvisApelidos`) não chama `JarvisSegredo`. O fluxo é: ouvir → entender →
executar → (só então) gravar a cópia mascarada.

## Provas

Teste puro `flutter_app/tool/pin_sem_colisao_test.dart`:

1. `pedidoApelido('chama o Murilo de Murilo 2')` → apelido `Murilo 2`, nome
   `Murilo`, confirmação falada com o número.
2. `pedidoApelido('o apelido do Murilo é Murilo 2026')` → `Murilo 2026`
   guardado inteiro (quatro dígitos, que seriam mascarados só na cópia).
3. `normalizarNomeContato('Murilo 2')` → `murilo 2`; `escolherContato` devolve o
   contato `Murilo 2`, não o `Murilo`.
4. `interpretarMensagem('manda mensagem para o Murilo no WhatsApp dizendo que o
   código é 4321')` → destino `Murilo`, texto `o código é 4321`, com o número
   intacto; o mesmo vale para `a senha é 1234`.
5. Aplicar a máscara no texto do pedido muda **só a cópia** (`o código é
   [oculto]`); o objeto do pedido continua com `4321`, que é o que vai ao envio.
6. `protegerPinNoPedido('Murilo 2')` não muda nada: um dígito só não é PIN.

Contrato `tests/test_bloco_120.py`:

- varre todos os `.dart` e falha se `protegerPinNoPedido` aparecer fora dos três
  arquivos de gravação;
- varre os `.kt` e falha se `ocultarPin` aparecer fora de `JarvisSegredo.kt` e
  `JarvisFundo.kt`;
- confirma que apelido, contato e mensagem não importam a máscara;
- confere que a faixa de dígitos é a mesma nas duas linguagens;
- confere versão, CHANGELOG, relatório e registros.

## O que continua valendo

- A máscara vale para o que é **salvo a partir da 1.95.0** (histórico) e da
  1.96.0 (conversa). Registros antigos no disco ficaram como estavam.
- O envio de mensagem usa o texto original; o histórico mostra `[oculto]`.
  Isso é intencional: o histórico serve para explicar, não para guardar segredo.
- Sem aparelho nesta sessão: a prova é de regra e de leitura de código, não uma
  mensagem enviada de verdade.
