# Ajuste 047 — sincronização nos dois sentidos com o Obsidian (2026-11-15)

## Por que

O ajuste 046 ligou a pasta, mas importar só trazia cópias; o que o usuário escrevesse no aparelho
nunca chegava ao Obsidian. Faltava conciliar os dois lados sem perder nota de ninguém.

## Como a decisão é tomada

Toda a regra vive em `core/memoria_sync.dart`, sem Flutter e sem Android, para poder ser provada
aqui. Cada nota guarda o `caminho` na pasta e o `hashSincronizado` do último conteúdo combinado.

| Situação | Ação |
| --- | --- |
| Conteúdo igual nos dois lados | nada (no máximo adota caminho/hash) |
| Só no aparelho | cria o `.md` na pasta |
| Só na pasta | importa como nota nova |
| Aparelho mudou, pasta está na versão sincronizada | envia |
| Pasta mudou, aparelho está na versão sincronizada | recebe |
| Os dois mudaram (ou nunca sincronizaram e diferem) | **conflito**: não escreve nada |
| Nota local cujo arquivo sumiu da pasta | registra “só neste aparelho”; não apaga nem recria |
| Mesmo título em caminhos diferentes | conflito, para não duplicar |
| Nome de arquivo duplicado na leitura | usa um e reporta |

Não existe ação de apagar em nenhum ponto do núcleo. O pior resultado possível é conflito.

A comparação usa o **corpo** da nota, não o frontmatter: datas geradas pelo app não fazem a
sincronização achar que houve mudança, então ela não entra em laço. O hash é FNV-1a duplo de
32 bits, só para detectar mudança — não é hash de segurança.

## Escrita no Android

`escreverNota` no canal `com.jarvis.nova/memoria` grava via `DocumentsContract`:

- se o arquivo existe, `openOutputStream(uri, "wt")` trunca e regrava em UTF-8;
- se não existe, cria as subpastas que faltarem com `createDocument(MIME_TYPE_DIR)` e o arquivo com
  `createDocument("text/markdown")`;
- o seletor agora pede `FLAG_GRANT_WRITE_URI_PERMISSION`; se o provedor só conceder leitura, a
  permissão durável é de leitura e a tela avisa “só para leitura”, com o botão desabilitado;
- nenhuma chamada de `deleteDocument` existe no código.

## Tela

O cartão da pasta ganhou “Sincronizar” ao lado de “Importar notas”. O resumo diz enviadas,
recebidas, já iguais, conflitos e notas só neste aparelho. Se houver conflito, abre um diálogo
listando os arquivos e explicando que nada foi apagado nem sobrescrito.

## Verificação

```
dart run tool/memoria_sync_test.dart        → 13 casos, OK
flutter test test/sincronizador_test.dart   → 8 testes, All tests passed!
flutter test test/cofre_saf_test.dart       → 8 testes, All tests passed!
flutter test                                → 69 testes, All tests passed!
flutter analyze                             → No issues found!
npm run verificar                           → ver relatório do ajuste
```

Os 13 casos do núcleo cobrem envio, recebimento, igualdade, adoção de caminho, alteração de cada
lado, conflito, ausência na pasta, mesmo título, arquivo duplicado e estabilidade do hash. Os 8 do
serviço usam um cofre falso em memória e provam, entre outras coisas, que a segunda sincronização
sem mudanças **não escreve nada** (sem laço) e que falha de escrita não marca a nota como
sincronizada. Os de widget provam que o botão fica desabilitado sem permissão de escrita e que o
resumo aparece.

## Limites

- Nada disso foi exercitado num aparelho: sem Android SDK, a compilação do Kotlin e a escrita real
  no cartão só se confirmam no CI e no Poco X7.
- A detecção é por comparação de conteúdo na hora de sincronizar, não por observador do sistema:
  mudanças aparecem quando o usuário toca em “Sincronizar”, não em tempo real.
- Conflito é preservado, não resolvido: o app não escolhe sozinho qual versão vale.
- Exclusão proposital feita no Obsidian deixa a nota no aparelho marcada como “só neste aparelho”;
  apagar do aparelho continua sendo decisão explícita do usuário.
