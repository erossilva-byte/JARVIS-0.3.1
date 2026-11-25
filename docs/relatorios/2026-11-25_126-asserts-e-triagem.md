# Bloco 126 — asserts ligados e triagem dos testes puros

## O problema

`dart run` roda com os asserts **desligados** por padrão. Como os testes puros
de `tool/` são feitos de `assert`, o executor `tests/test_dart_core.py` abria
cada arquivo, não verificava nada e imprimia “OK”. A suíte estava verde por
omissão, não por acerto: um `assert(1 == 2)` passa sem a flag e falha com ela.

## A correção

`tests/test_dart_core.py` agora chama `dart run --enable-asserts`. Com a flag,
15 arquivos falharam. A triagem separou defeito real de expectativa velha.

## Defeito real (16)

| # | Onde | O que estava errado |
|---|------|---------------------|
| 1 | `ativacao_sensibilidade.dart` | `resumo` interpolava a **função** `rotulo`, não o valor: “Closure: (int) => String · limiar 0.25”. |
| 2 | `especialidades.dart` | “qual a bitola do cabo para 30 A” não caía em CADeSIMU, embora bitola esteja nos focos da área. |
| 3 | `especialidades.dart` | “null check operator used on a null value” não caía em programação; só `null pointer` estava previsto. |
| 4 | `aparelho.dart` | “liga o volume” era interpretado como ligação. A guarda do Dart estava atrás da do Kotlin. |
| 5 | `aparelho.dart` | “como liga o bluetooth” discava. O segundo plano já recusava pergunta com “como”; o Dart não. |
| 6 | `comandos_android.dart` | “Onde eu estou agora?” não virava comando: o `?` final impedia o casamento da regra. |
| 7 | `memoria_busca.dart` | Consulta sem relação (“astronomia quântica”) puxava três notas por colisão do embedding: o corte de 0.10 aceitava ruído de ~0.27. |
| 8 | `memoria_sync.dart` | Nota “Motor” não adotava `Motor.md`: o caminho gerado é minúsculo e a comparação era sensível a caixa, então o mesmo conteúdo virava arquivo novo. |
| 9 | `palco.dart` | Data da notícia sempre vazia: o RSS do Google usa RFC 822 e `DateTime.tryParse` não lê esse formato. |
| 10 | `pedido_app.dart` | “conversa com o João no WhatsApp” levava o alvo “João no”: o conector antes do app ficava sobrando. |
| 11 | `pedido_app.dart` | “abre o Gmail para escrever um e-mail novo” abria o app de e-mail genérico: vencia o alias mais longo, não o citado primeiro. |
| 12 | `pedido_app.dart` | “traça a rota até o aeroporto” levava “até o aeroporto”: os conectores eram comparados com acento. |
| 13 | `pedido_app.dart` | “abre o Gmail” virava ação de escrever, roubando o comando de abrir app. |
| 14 | `pedido_ficha.dart` | “deixa pra lá” não cancelava a ficha. |
| 15 | `pessoas.dart` | “quem é Ana?” com “Ana” e “Ana Paula” na agenda escolhia uma ficha em silêncio, em vez de perguntar qual. |
| 16 | `nome_contato.dart` | “Murilo 2” resolvia para “Murilo”: o empate por prefixo encurtava o nome mesmo quando o nome dito era exato. |

Os itens 3 e 5 e os itens 11–13 estavam escondidos atrás da primeira falha de
cada arquivo; só apareceram depois de corrigir a anterior.

Havia ainda **cinco testes puros fora do executor**: `aparelho`, `dispositivo`,
`engenharia`, `pedido_ficha` e `tarefas`. Eles existiam, compilavam e nunca
rodavam no CI — o mesmo tipo de silêncio, com outra causa. Entraram no
`CASOS`, e o contrato 126 passa a exigir que todo `tool/*_test.dart` esteja
registrado.

## Expectativa velha (5)

| Onde | O teste pedia | O que o código faz, e por quê |
|------|---------------|-------------------------------|
| `arquivos_test.dart` | recusar `'ç' × (limite/2)` | São exatamente 512 kB, e o limite é “mais de 512 kB”. O teste estava errado por um caractere; passou a usar `limite/2 + 1`. |
| `palco_test.dart` | `%20` na consulta | `Uri.encodeQueryComponent` codifica espaço como `+`, que é forma válida de consulta. O teste agora confere o parâmetro decodificado e a ausência de espaço cru. |
| `personalidade_test.dart` | `'não copie falas'` | O prompt diz “Não copie falas”, com maiúscula. A regra existia; a comparação passou a ignorar caixa. |
| `visao_test.dart` | `'não invente'` | Mesmo caso: “Não invente” no prompt. Comparação sem caixa. |
| `segredo_pedido_test.dart` | deixar `12345abc` legível | A máscara cobre dígitos colados a letra. Mantido o lado seguro (mascarar) e o teste alinhado à regra documentada. |

## Prova

- `dart run --enable-asserts` em **50** arquivos de `tool/`: 0 falhas; com os
  cinco recém-registrados, o executor cobre os 50.
- `flutter analyze`: sem problemas.
- `flutter test`: 429 testes, todos passando.
- Suíte Python completa (`tests/test_*.py`): 0 falhas.
- `tests/test_bloco_126.py`: prende a flag, a cobertura do executor e cada
  correção acima.

## Limites

- Nada disso foi rodado em aparelho Android ou PC físico; a prova é de regra e
  de contrato.
- O Kotlin não compila nesta máquina. As guardas de ligação do Dart foram
  alinhadas às do `JarvisMensagens`, mas a igualdade dos dois lados continua
  provada por leitura e contrato, não por execução no aparelho.
