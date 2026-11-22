# Fase 7 — fichas de pessoas (entrega para aprovação)

**Branch:** `work/1.48.0-fase2-consolidacao`
**Escopo desta entrega:** a Fase 7 completa — **fichas de pessoas** (com uso na conversa e
transparência do que foi enviado) e **personalidade/humor** em três níveis.

## O que existe de verdade

| # | Item | Estado | Evidência |
|---|---|---|---|
| 1 | Ficha local com nome, apelido, relação, contatos, preferências, anotações, compromissos e histórico | **Atendido** | `core/pessoas.dart`, `services/pessoas_page.dart` |
| 2 | Consentimento explícito obrigatório (LGPD) | **Atendido** | `validarPessoa`; teste de widget recusa sem marcar |
| 3 | Criar, editar, pesquisar, consultar e excluir | **Atendido** | tela + 5 testes; exclusão com confirmação |
| 4 | Nomes parecidos não são fundidos nem escolhidos sozinhos | **Atendido** | `resolverPessoa`; dois “João” viram ambiguidade |
| 5 | Não inventar informação | **Atendido** | campos vazios ficam vazios; descrição diz “nenhuma informação além do nome” |
| 6 | Armazenamento local criptografado | **Atendido no código** | `FlutterSecureStorage`; limite de 50 fichas e 64 kB |
| 7 | Contato, observações, compromissos e histórico fora do contexto da IA | **Atendido no núcleo** | `contextoPessoas` só usa nome/apelido/relação/preferências |
| 8 | Foto de referência e reconhecimento facial local | **Não entregue** | exige câmera/modelo local; a tela declara a ausência |
| 9 | Histórico automático de interações e compromissos | **Não entregue** | o histórico é escrito pelo usuário; nada é deduzido de conversa |
| 10 | Fichas usadas na conversa (“quem é essa pessoa?”) | **Atendido no código** | bloco seguro enviado como mensagem de sistema; nome ausente instrui dizer que não encontrou |
| 10b | Ver na conversa qual ficha foi usada e o bloco exato enviado | **Atendido no código** | bolha mostra “Ficha usada: Ana” (ou “Fichas: nenhuma correspondência”) e abre o texto literal enviado; 3 testes de widget |
| 12 | Personalidade e humor em três níveis (Discreto, Equilibrado, Avançado) | **Atendido no código** | `core/personalidade.dart`, `services/personalidade_page.dart`; 9 grupos puros e 3 testes de widget |
| 13 | Humor suspenso em assunto sensível, mesmo no nível máximo | **Atendido no núcleo** | saúde, luto, violência, segurança e dinheiro perdido detectados; prompt diz “Humor zero” |
| 14 | Nível escolhido entra no prompt da conversa | **Atendido no código** | `estiloDoTurno` antes de cada envio; preferência local lida no envio; teste de widget grava e relê |
| 11 | Ensaio no aparelho | **Pendente** | sem Android SDK aqui; armazenamento seguro e resposta real da IA não foram exercitados |

## Privacidade, sem promessa vazia

- A identidade é sempre o nome digitado: não há câmera, biometria, voz ou figura pública.
- O app exige a confirmação de consentimento antes de gravar qualquer ficha.
- Nada sai para a rede: as fichas não importam `http` e ficam no armazenamento seguro do aparelho.
- A tela mostra campo vazio como “não informado”; não preenche relação, preferência nem histórico.
- Excluir remove a ficha inteira do aparelho, com confirmação; não há cópia no cofre do Obsidian.

## Verificação

```
dart run tool/pessoas_test.dart              → OK (validação, ambiguidade, descrição, contexto)
dart run tool/pessoas_conversa_test.dart      → OK (bloco seguro, ausência, ambiguidade e persistência do bloco)
flutter test test/pessoas_page_test.dart     → 5 testes, All tests passed!
flutter test test/conversa_pessoas_test.dart → 3 testes, All tests passed!
dart run tool/personalidade_test.dart        → OK (níveis, tom sensível, pressa e prompt)
flutter test test/personalidade_page_test.dart → 3 testes, All tests passed!
python3 tests/test_personalidade_flutter.py  → OK (estático)
python3 tests/test_pessoas_privacidade.py    → OK (estático)
flutter analyze                              → No issues found!
npm run verificar                            → ver relatório do ajuste
```

## Limites

- Sem aparelho: a tela não foi inspecionada visualmente e a criptografia real do
  `FlutterSecureStorage` só se confirma no Android/CI.
- Foto, reconhecimento facial e histórico automático não existem — e o app não finge que existem.
- A conversa envia o bloco seguro quando a pergunta cita uma pessoa ou pergunta por ela, e a bolha
  registra o bloco **literal** que foi enviado. Contato, anotação, compromisso e histórico continuam
  fora; se a pergunta pedir isso, a instrução manda dizer que não encontrou.
- A transparência foi provada por widget test, mas a bolha **não foi vista em tela**: sem aparelho,
  o layout do bloco expansível em telas estreitas continua pendente.
- O nível de personalidade foi provado no prompt e na tela, mas **nenhuma resposta real foi gerada**:
  sem chave, não se sabe se o modelo obedece ao estilo. O nível também não altera a voz sintetizada
  nem autentica ninguém — a tela diz isso.
- A tela de personalidade não foi inspecionada em aparelho; a prévia é textual, não uma simulação da
  resposta do modelo.
- Nenhuma chamada real à IA foi feita: sem chave de provedor, o que está provado é o bloco e a
  montagem das mensagens, não a resposta do modelo.
