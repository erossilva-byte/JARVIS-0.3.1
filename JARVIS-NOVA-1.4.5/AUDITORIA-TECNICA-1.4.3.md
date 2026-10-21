# Auditoria técnica — J.A.R.V.I.S. Nova 1.4.3

## Alterações nesta revisão
- Refinamento CSS responsivo para Android: áreas seguras, rolagem dos painéis, quebra de texto, controles menores, acessibilidade de foco, orientação horizontal e preferência por movimento reduzido.
- Mantida a ativação por palavra via Porcupine com AccessKey, sem afirmar que funciona sem credenciais.
- Pesquisa técnica de alternativa open-source: sherpa-onnx oferece KWS offline para Android, mas os modelos públicos identificados não são um substituto pronto e validado para a palavra “Jarvis” em português. A dependência não foi incluída sem modelo e teste reproduzível.
- Versão atualizada para 1.4.3 / versionCode 1403.

## Limitações conhecidas
1. A palavra de ativação continua dependente de AccessKey Picovoice. O microfone manual continua como alternativa.
2. A IA local precisa de modelo `.task` compatível com MediaPipe; o modelo não acompanha o pacote.
3. O perfil acústico experimental não deve ser usado para autenticar ou autorizar ações sensíveis.
4. A compilação Android e a validação no POCO X7 ainda dependem da execução do GitHub Actions e de testes no aparelho.

## Validação executada
A suíte `npm run test:all` é o teste de regressão exigido. O resultado deve ser anotado após execução no ambiente desta revisão; aprovação estática não substitui build Android nem teste físico.
