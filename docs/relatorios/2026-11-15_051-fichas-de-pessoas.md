# Ajuste 051 — fichas de pessoas na interface Flutter (2026-11-15)

## Por que

A Fase 7 do prompt pede fichas de pessoas com privacidade reforçada. O projeto já tinha um
cadastro no núcleo antigo (Node), mas a interface Flutter só mostrava um cartão de módulo.

## O que foi feito

### Núcleo (`core/pessoas.dart`)

- Ficha com nome, apelido, relação, contatos autorizados, preferências, anotações, compromissos e
  histórico. Todos os campos passam por limpeza (controle, `<>`, espaços, limite por campo).
- Nome é obrigatório e **consentimento é obrigatório**: sem a declaração, nada é gravado.
- `resolverPessoa` devolve exato, único, ambíguo ou nenhum — dois “João” nunca são escolhidos
  sozinhos; nomes parecidos não são fundidos.
- `descreverPessoa` só fala o que foi preenchido; sem dados, diz “nenhuma informação além do nome”.
- `contextoPessoas` monta um bloco para a IA com nome, apelido, relação e preferências, limitado a
  12 pessoas. Contato, observações, compromissos e histórico **não entram**.
- `ultimaInteracao` lê a última linha do histórico escrito pelo usuário; não deduz conversa.

### Armazenamento (`services/pessoas_store.dart`)

- `FlutterSecureStorage` no aparelho, com interface injetável para teste.
- Limite de 50 fichas e 64 kB; falha de gravação é devolvida, não engolida.
- Id gerado com relógio + sequência (dois cadastros no mesmo microssegundo não colidem).
- Nenhuma importação de rede; nada é gravado no cofre do Obsidian.

### Interface (`services/pessoas_page.dart`)

- Lista com busca por nome/apelido, aviso de que nomes parecidos não são fundidos, e cartão que
  mostra “Relação não informada” quando o campo está vazio.
- Editor com todos os campos, botão salvar no topo (formulário longo) e consentimento em destaque.
- Excluir pede confirmação e remove a ficha inteira; não há “restaurar” porque não há cópia.
- O menu “Pessoas e contexto” passou a abrir a tela de verdade.

## Verificação

```
dart run tool/pessoas_test.dart            → OK
flutter test test/pessoas_page_test.dart   → 5 testes, All tests passed!
python3 tests/test_pessoas_privacidade.py  → OK
flutter test                               → ver contagem no relatório da suíte
flutter analyze                            → No issues found!
npm run verificar                          → 4 de 4 etapas
```

O teste puro cobre nome/consentimento, limpeza e limites, JSON, ambiguidade (incluindo dois nomes
iguais), busca sem acento, descrição sem invenção, última interação, contexto sem telefone/segredo
e limite de 12. Os testes de widget criam uma ficha passando pela recusa de consentimento, editam,
buscam, consultam e excluem. O teste estático garante consentimento, armazenamento seguro, ausência
de câmera/rede e contexto sem campos sensíveis.

## Limites

- Sem aparelho: criptografia e layout não foram exercitados de verdade.
- Foto de referência, reconhecimento facial e histórico automático não foram implementados; a tela
  diz isso em vez de exibir botão fictício.
- As fichas ainda não alimentam a conversa; o bloco seguro existe e está testado, mas o envio à IA
  precisa ser ligado numa próxima etapa.
