# Bloco 110 — contatos para fora, recorrência e palco adaptativo

Data: 2026-11-24 · versão **1.89.0**

## 1. Exportar contatos

- `JarvisAparelho.kt`: novos métodos de canal `exportarContatos` e
  `compartilharArquivo`. Lê telefones e e-mails de todos os contatos (limite de
  2.000), junta por nome sem duplicar e monta **vCard 3.0** com escape de
  `\ ; ,` e quebra de linha.
- O arquivo vai para `getExternalFilesDir(null)/exports/contatos-jarvis-<data>.vcf`
  e o compartilhamento usa o `FileProvider` que já existia, com
  `external-files-path` novo em `jarvis_arquivos.xml` — nenhuma permissão ampla
  de armazenamento.
- Tela do aparelho: botão "Exportar todos (.vcf)", contagem de contatos
  exportados e "Enviar o arquivo para…".

## 2. Rotinas, automações e tarefas com recorrência

- `core/tarefas.dart`: enum `Recorrencia` (diária, semanal, mensal, anual, uma
  vez), campos novos em `Automacao` (`recorrencia`, `diasSemana`, `diaDoMes`,
  `mesAno`, `diaAno`) e em `Tarefa` (`recorrencia`), todos persistidos.
- Regras: `diaCombinaCom` (com fim de mês respeitado), `proximaOcorrenciaAutomacao`,
  `proximaDataTarefa`; `automacaoVencida` passou a exigir o dia certo.
- `JarvisAgenda.kt`: guarda e devolve a repetição; `proximoCiclo` avança dia,
  semana, mês ou ano; o receptor reprograma sozinho o que repete.
- Tela: "Repetir" na automação (com dias da semana, dia do mês e dia/mês do ano)
  e na tarefa; botão "Editar" nos dois, com os campos preenchidos.
- Concluir uma tarefa que repete cria a próxima data e agenda o lembrete novo.

## 3. Palco adaptativo

- `core/palco.dart`: `MolduraPalco` e `molduraDoItem(item)` decidem a caixa pela
  forma real da mídia — capa larga (recorte), retrato inteiro, quadrada, capa de
  vídeo, capa de notícia e "sem imagem". `ItemPalco` passou a guardar largura e
  altura declaradas pela fonte (Wikimedia entrega esses campos).
- `palco_page.dart`: altura e `BoxFit` vêm da moldura; teto de 62% da tela.

## Verificação

- `python3 tests/test_bloco_110.py` — OK
- `tool/recorrencia_test.dart` e `tool/palco_enquadramento_test.dart` entraram em
  `tests/test_dart_core.py` e rodam no CI.
- `flutter analyze`, `flutter test` e os contratos rodam no CI do commit.

## Limites

- Mensal e anual são agendadas para a próxima data e reprogramadas na abertura do
  app; diária e semanal o Android repete sozinho.
- Sem teste em aparelho: nada de contatos, alarme ou palco foi aberto em celular
  nesta sessão.
