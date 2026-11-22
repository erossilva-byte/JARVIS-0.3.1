# Ajuste 052 — fichas de pessoas na conversa (2026-11-15)

## Por que

As fichas existiam, mas a conversa não as usava. O pedido era enviar **apenas o bloco seguro** e
dizer quando a pessoa não for encontrada — sem mandar contato, anotação, compromisso ou histórico.

## Como ficou

- `blocoPessoasParaConsulta` (núcleo) decide, a partir da pergunta, o que enviar:
  - **uma pessoa citada**: nome, apelido, relação e preferências; mais a instrução de que contato,
    anotações, compromissos e histórico não estão disponíveis e que, se pedirem isso, deve dizer
    que não encontrou;
  - **nome desconhecido**: “nenhuma ficha corresponde… diga que não encontrou; não invente”;
  - **mais de uma correspondência**: lista os nomes e manda perguntar qual, sem escolher;
  - **pergunta que não é sobre pessoa**: string vazia, nada é enviado.
- Nome completo vence primeiro nome: “Ana Paula” não vira ambiguidade com “Ana”. Apelido também
  resolve (“Cadu” → Carlos).
- `montarMensagens` ganhou um parâmetro opcional `pessoas`; quando presente, entra como mensagem de
  sistema antes do histórico. Sem ele, a montagem antiga continua idêntica.
- `VoiceConversationPage` carrega o `PessoasStore` (se o armazenamento seguro não estiver
  disponível, segue sem fichas) e calcula o bloco com o texto que o usuário enviou.
- Nada de contato/histórico é enviado nem quando o usuário pergunta por eles: a resposta instruída
  é que não está disponível.

## Verificação

```
dart run tool/pessoas_conversa_test.dart     → 9 grupos, OK
python3 tests/test_pessoas_privacidade.py    → OK (estático)
flutter test                                 → ver contagem no relatório da suíte
flutter analyze                              → No issues found!
npm run verificar                            → 4 de 4 etapas
```

O teste puro prova bloco seguro, ausência de telefone/observação/compromisso/histórico, nome
desconhecido, ambiguidade, prioridade do nome completo, resolução por apelido, pergunta genérica
sem bloco e a posição da mensagem de sistema. O teste estático garante que a tela de conversa usa
esse bloco e que ele não referencia campos sensíveis.

## Limites

- Sem chave real de provedor, **a resposta do modelo não foi exercitada**: o que está provado é o
  que o app monta e envia, não como a IA responde.
- Não há indicação visual na conversa de que uma ficha foi usada; o usuário não vê “o que lembrei”
  para pessoas.
- O bloco é decidido por correspondência de nome/apelido na pergunta; perguntas indiretas (“e a
  irmã dela?”) não resolvem a pessoa sozinhas.
