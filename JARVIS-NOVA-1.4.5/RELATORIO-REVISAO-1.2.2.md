# J.A.R.V.I.S. Nova 1.2.2 — revisão de desenvolvimento

## Base e escopo
Base: fonte 1.2.1 derivada da 1.2.0. Esta entrega adiciona importação explícita de contatos do Android e mantém atalhos existentes para abrir aplicativos, incluindo WhatsApp. Não foi gerado APK nesta revisão.

## Alterações
- Novo método nativo `JarvisUtil.listarContatos`, consultando nome e número via `ContactsContract`.
- Permissão `READ_CONTACTS` declarada, solicitada em tempo de execução apenas quando o usuário toca em “Importar contatos do Android”.
- A tela pede confirmação antes de importar, limita a leitura a 500 entradas por execução, não substitui contatos já cadastrados e guarda os registros na lista local do app.
- Nomes/números importados não são anexados automaticamente ao prompt da IA; o controle existente de compartilhamento de nomes continua desativado por padrão.
- A abertura do WhatsApp já existe como atalho nativo. Envio de mensagens não é automatizado: a composição/revisão pelo usuário permanece, reduzindo o risco de envio acidental.
- Atualizados versão, changelog, teste de versão e workflow de CI para 1.2.2.

## Palavra de ativação — não concluída
A palavra de ativação de baixo consumo semelhante ao “Ok Google” ainda não foi implementada. O código-base utiliza Android `SpeechRecognizer` para a escuta experimental, que não deve ser descrita como detector de palavra dedicado nem como solução comprovadamente eficiente em bateria. Não habilitei essa abordagem por padrão. A próxima etapa exige escolher/integrar um detector local apropriado, avaliar licença e compatibilidade, e testar em aparelho real.

## Segurança e limitações
- Não adicionadas permissões para ler SMS diretamente, fazer chamadas silenciosas, controlar outras apps por acessibilidade ou contornar as proteções do Android.
- A lista importada fica no armazenamento local do aplicativo; revise e apague os contatos que não desejar manter.
- A importação lê até 500 entradas de telefone, não todos os campos do catálogo.
- O Android pode impedir abrir apps inexistentes ou restringir ações em segundo plano.

## Testes desta revisão
- JavaScript: `node --check app.js`, `main.js`, `apps.js`.
- Validador estático do projeto: `python3 tests/validate_project.py`.
- Scripts Python: `python3 -m py_compile ...`.
- Não executados nesta sessão: compilação Android/Java via Gradle, testes instrumentados, instalação e testes físicos, bateria, wake word, chamadas e envio real de SMS/WhatsApp. Portanto, esta fonte não é certificada como livre de erros e não deve ser tratada como APK final.
