# Relatório de implementação — J.A.R.V.I.S. Nova 1.3.1

## Implementado nesta etapa
- Plugin nativo `JarvisLocalAIPlugin` com importação de arquivo `.task`, cópia para armazenamento privado, status, geração local e exclusão do modelo.
- Inferência real por `com.google.mediapipe:tasks-genai:0.10.27`, com execução em executor de fundo.
- Interface de configurações com botões Importar, Testar e Apagar modelo, mensagens de estado e aviso de compatibilidade.
- Fallback para IA local quando não há chave/API utilizável e tentativa de IA local no modo offline depois dos comandos locais rápidos.
- Testes estáticos dedicados e integração do plugin no workflow de build.

## Limites importantes
- O modelo não é incluído no APK; o usuário deve obter legalmente um modelo empacotado como `.task` e compatível com MediaPipe LLM Inference. GGUF não é compatível diretamente.
- A API MediaPipe LLM Inference está em manutenção; a documentação oficial recomenda migração para LiteRT-LM. Esta etapa é uma prova de conceito para validar o fluxo no Android.
- Ainda não houve build Gradle nem teste em aparelho nesta execução. Não declarar APK pronto antes de GitHub Actions verde e teste físico.

## Testes esperados
1. `npm run test:all`
2. `npx cap add android`, cópia do plugin, patch Gradle e `./gradlew assembleDebug` no CI.
3. Importar modelo `.task`, testar resposta, desligar internet e testar conversa offline.
4. Verificar falha com modelo inválido, falta de espaço, ausência de RAM e cancelamento do seletor.
