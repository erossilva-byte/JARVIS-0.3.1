# Ajuste 048 — sincronização automática e fechamento da Fase 6 (2026-11-15)

## Por que

A sincronização do ajuste 047 só acontecia quando o usuário tocava em “Sincronizar”. Para o cofre
ser memória viva, ele precisa se acertar com a pasta ao abrir o app e ao voltar para ele.

## Como ficou

- `MemoriaPage` passou a observar o ciclo de vida. Ao abrir, depois de descobrir a pasta, roda uma
  sincronização em silêncio; ao voltar de segundo plano, roda de novo.
- Só sincroniza ao voltar se o app realmente saiu (`hidden`/`paused`). Um `resumed` repetido sem
  saída — o que acontece com diálogos e notificações — não dispara nada.
- A sincronização automática é silenciosa: não abre diálogo nem empilha aviso. O cartão mostra
  “Sincronizado · 2 enviada(s), 1 recebida(s)…”, ou “Sincronizado · 1 conflito(s) pendente(s)”.
  Conflito continua intacto dos dois lados; o botão “Sincronizar” é que abre a lista e explica.
- Conectar uma pasta já dispara a primeira sincronização, então as notas existentes aparecem sem
  precisar tocar em “Importar notas”.
- Pasta somente leitura não sincroniza automaticamente: o cartão explica e o botão fica desligado.
- Enquanto uma sincronização automática roda, o botão manual não abre outra; falha de leitura ou
  escrita em modo silencioso não vira aviso, só deixa o resumo vazio e o conteúdo local intacto.

## Verificação

```
flutter test test/cofre_saf_test.dart  → 9 testes, All tests passed!
flutter test                           → 70 testes, All tests passed!
flutter analyze                        → No issues found!
npm run verificar                      → ver relatório do ajuste
```

Os dois testes novos usam o canal simulado e o ciclo de vida real do binding: um prova que abrir a
tela com pasta editável já grava a nota local sem toque; o outro simula a saída completa
(`inactive → hidden → paused`) e a volta (`hidden → inactive → resumed`) e confere que uma nota
nova da pasta é importada sozinha.

## Limites e fechamento da fase

- Nada foi exercitado em aparelho: sem Android SDK, o seletor, a escrita real no cartão e o
  comportamento de ciclo de vida do HyperOS só se confirmam no CI e no Poco X7.
- A sincronização automática acontece ao abrir e ao voltar, não em tempo real enquanto a tela está
  aberta: não há observador do sistema de arquivos.
- A Fase 6 fica **fechada no código**: cofre, busca lexical explicada, importação, SAF, escrita e
  sincronização nos dois sentidos com conflito preservado. Seguem fora, declarados: busca semântica
  neural, versionamento de nota e o ensaio no aparelho (Gate B).
