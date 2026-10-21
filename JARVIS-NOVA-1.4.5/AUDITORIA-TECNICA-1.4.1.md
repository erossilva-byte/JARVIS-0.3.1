# Auditoria técnica — J.A.R.V.I.S. Nova 1.4.1

## Testes executados
`npm run test:all` passou nesta cópia. Foram validados sintaxe JS, rotas de voz, IDs HTML, patches Gradle, prontidão do workflow, armazenamento seguro de chaves, personalidade e contrato do plugin de IA local.

## Alterações
- Versão `1.4.1`, `versionCode 1401`.
- Nome do usuário separado de como o assistente deve tratá-lo; o prompt usa ambos corretamente.
- Voz masculina preferencial com fallback explícito para voz pt-BR e pitch 0,75; gênero inferido pelo nome da voz, não por metadado padronizado.
- Workflow aceita pacote de fonte com `package.json` na raiz ou dentro de pasta e nomeia o artefato 1.4.1.
- Plugin MediaPipe importa `androidx.activity.result.ActivityResult` e a dependência é fixada em 0.10.14 para tentar evitar incompatibilidade de bytecode com Java 17. A compilação real continua sendo o teste definitivo.

## Bloqueios e estado real
1. **IA local:** integração de inferência existe no código; depende de modelo `.task` compatível e build bem-sucedido. Não é uma IA local pronta de fábrica, nem substitui os provedores online automaticamente sem modelo.
2. **Palavra de ativação sem chave:** ainda não resolvida. O detector atual é Porcupine e exige AccessKey. A chave é obtida pelo portal Picovoice; para remover esse requisito é necessário integrar outro motor/modelo offline gratuito e medir consumo e falsos acionamentos. Não substituímos por reconhecimento contínuo genérico, pois isso pode drenar bateria e interferir com música.
3. **Validação física/APK:** não executada nesta cópia. É necessário rodar GitHub Actions e instalar no POCO X7.
4. **Identificação pessoal pela voz:** ainda não implementada. Transcrição de fala já existe, mas não prova a identidade do falante. A próxima implementação precisa de modelo de speaker embeddings/verification, cadastro local de várias amostras, limiar calibrado e aviso de que não é uma trava de segurança.

## Resultado
**Testes estáticos: aprovados. APK: pendente. Teste físico: pendente.** Não declarar versão pronta para uso diário antes desses dois últimos passos.
