# Ajuste 054 — personalidade e humor (2026-11-15)

## Por que

As fichas de pessoas fecharam uma parte da Fase 7, mas o J.A.R.V.I.S. do Flutter ainda respondia
com o tom padrão do modelo: sem nível escolhido, sem o sarcasmo seco da identidade e sem garantia de
silêncio em assunto sério. O app legado tinha isso; a interface nativa não.

## Como ficou

- **Três níveis**, com o mesmo vocabulário do app legado: Discreto (35), Equilibrado (65) e Avançado
  (90). Discreto mantém elegância e opinião, mas proíbe piada, ironia e sarcasmo.
- **Regras explícitas no prompt**: personalidade obrigatória nos níveis com humor, informação antes
  da graça, uma observação por resposta, sem repetir construção, piada sempre com a situação —
  nunca com a pessoa, aparência, religião ou tragédia — e proibição de copiar falas de filmes.
- **Tom do turno** detectado no texto: assunto sensível (saúde, luto, violência, segurança, dinheiro
  perdido) zera o humor mesmo no Avançado; pressa encurta a resposta e não recebe ângulo de humor.
- **Ângulo contextual** por tema (saudação, bug, código, arquivo, agradecimento, geral), escolhido
  sem repetir os últimos oito da conversa. É sugestão para adaptar, não fala pronta.
- **Tela “Personalidade e humor”** com cartões, prévia textual e gravação em preferência local. O
  menu “Personalização” abre a tela real. A tela declara que o nível não muda a voz, não autentica e
  não amplia o que a IA pode fazer.
- O estilo entra como **primeira mensagem de sistema**, antes da memória, das fichas e do histórico;
  o nível salvo é lido a cada envio, então mudar a preferência vale na resposta seguinte.

## Verificação

```
dart run tool/personalidade_test.dart          → 9 grupos, OK
flutter test test/personalidade_page_test.dart → 3 testes, All tests passed!
python3 tests/test_personalidade_flutter.py    → OK (estático)
flutter test                                   → 90 testes, All tests passed!
flutter analyze                                → No issues found!
npm run verificar                              → 4 de 4 etapas
```

O teste puro prova nível padrão, leitura tolerante, JSON, detecção de saúde/luto/dinheiro/pressa,
proibição de piada no Discreto, limites nos demais níveis, humor zero e ausência de ângulo em
assunto sensível, não repetição de ângulo e posição do prompt na conversa. O teste de widget prova
que a tela abre no nível salvo, que trocar atualiza a prévia sem gravar sozinho e que salvar persiste
e informa o usuário. O estático garante que o menu abre a tela real e que a tela não promete voz ou
autenticação.

## Limites

- **Nenhuma resposta real de modelo foi gerada**: sem chave de provedor, está provado o prompt que
  sai, não a obediência do modelo a ele.
- O nível **não altera a voz sintetizada** nem a prosódia; isso continua no app legado e não foi
  migrado.
- A tela não foi vista em aparelho; a prévia é um exemplo fixo, não uma simulação da IA.
- A detecção de assunto sensível é lexical: metáfora, ironia ou contexto anterior podem escapar.
