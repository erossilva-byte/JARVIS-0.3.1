# J.A.R.V.I.S. Nova 1.4.3

Esta revisão melhora a apresentação em telas estreitas, painéis de configurações, orientação horizontal, áreas seguras do Android e acessibilidade.

## Palavra de ativação
Porcupine foi mantido como opção atual porque a alternativa sherpa-onnx exige integração e modelo de keyword spotting apropriado; não foi encontrada uma combinação pronta e testada para “Jarvis” em português que permita remover a dependência com segurança. Configure a AccessKey nas definições de voz. Sem ela, use o microfone manual.

## Gerar APK
1. Envie o conteúdo deste pacote à raiz do repositório.
2. Abra GitHub Actions e execute o workflow `Build e testes do J.A.R.V.I.S. Nova 1.4.3`.
3. Baixe o artefato `JARVIS-Nova-1.4.3-APK` se o job terminar com sucesso.
4. Instale e teste no POCO X7; não declare a versão pronta apenas com testes estáticos.
