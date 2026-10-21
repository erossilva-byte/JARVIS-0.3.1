# Implementação de perfil, voz e reconhecimento do usuário — 1.4.1

## Implementado nesta rodada
- Campo separado para o nome do usuário e para o tratamento (ex.: nome “Eros”, tratamento “senhor”).
- O prompt da IA recebe o nome cadastrado e mantém o tratamento escolhido.
- Voz padrão tenta escolher uma voz com nome associado a masculino; se não existir, prioriza pt-BR e usa pitch inicial 0,75. O botão “Usar voz masculina preferencial” repete essa seleção.
- O processo de build aceita ZIP de fontes com `package.json` na raiz ou dentro de uma pasta.
- O plugin de IA local usa o tipo `androidx.activity.result.ActivityResult` e fixa MediaPipe 0.10.14 para a cadeia Java 17 / Gradle 8.2.

## Limites que permanecem explícitos
- Os motores de TTS nem sempre informam o gênero da voz; a seleção pelo nome é heurística. A voz final deve ser testada no POCO X7 e depende das vozes instaladas no Android.
- Reconhecimento de fala (transcrever palavras) já existe; identificação biométrica do falante (confirmar que a voz é do proprietário) ainda não foi ativada. Isso exige um modelo de verificação de falante, gravação de amostras de cadastro, comparação de embeddings e calibração contra falsos positivos. Não deve ser usado como autenticação de ações sensíveis.
- A palavra de ativação “Jarvis” continua usando Porcupine e uma AccessKey Picovoice. A chave é necessária para o SDK; não é correto declarar que existe wake word local sem chave até que outro motor e seu modelo offline sejam integrados e testados. A alternativa deve ser gratuita e funcionar em Android, sem capturar áudio contínuo via serviço de reconhecimento genérico.
- A IA local só funciona quando o usuário importa um modelo `.task` compatível com MediaPipe. O APK não inclui modelo e a compatibilidade com modelos/uso de RAM precisa de teste físico.
- A compilação do APK e a instalação no POCO X7 ainda dependem de execução do workflow do GitHub Actions e teste real. Os testes estáticos não substituem essa validação.

## Teste de aceitação depois do build
1. Instalar o APK debug e verificar permissões de microfone/notificações/contatos.
2. Cadastrar nome e tratamento, salvar, fechar e reabrir o app; confirmar persistência e uso nas respostas.
3. Testar voz escolhida e alternativas em Configurações do Android > Texto para fala.
4. Importar um modelo MediaPipe oficialmente compatível e testar inferência, RAM, temperatura e tempo de resposta.
5. Validar a palavra de ativação com chave Picovoice; medir consumo, interferência em música e reinício do serviço.
6. Fazer testes de falha de internet, ausência de chaves e permissões negadas.
