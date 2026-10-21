# Relatório de revisão — J.A.R.V.I.S. Nova 1.2.9

## Alterações
- Integração do SDK `ai.picovoice:porcupine-android:4.0.2` no patch Gradle.
- A AccessKey Picovoice salva no cofre seguro é passada ao plugin nativo ao iniciar a escuta.
- Com AccessKey: Porcupine usa a palavra integrada `JARVIS`; sem chave: openWakeWord usa `HEY_JARVIS`.
- Atualização de rótulos e mensagens para corresponder ao detector ativo.
- Reforço das instruções da interface para salvar humor/estilo e interpretar a prévia como ilustrativa.
- Atualização da versão para 1.2.9 / versionCode 1209 e do nome do artefato do workflow.

## Limites conhecidos
- A validação inicial da AccessKey pode exigir conexão com a internet. A detecção de wake word é local depois de inicializado.
- O detector `JARVIS` integrado é a palavra padrão do Porcupine; não equivale a um modelo personalizado em português.
- A API pode rejeitar a chave, a conta pode atingir limites, e a mensagem de erro deverá ser verificada no aparelho.
- Não foi possível confirmar um build Gradle real neste ambiente. O GitHub Actions precisa resolver a dependência e compilar.
- Não foram realizados testes físicos de bateria, falsos disparos, funcionamento com tela bloqueada ou concorrência do microfone.
- O prompt de personalidade influencia respostas online; não transforma modelos offline/nativos em uma IA com capacidades idênticas.

## Próximos testes obrigatórios
1. Executar workflow e confirmar APK gerado.
2. Testar AccessKey válida e inválida; testar sem chave.
3. Testar ativação “Jarvis” e “Hey Jarvis”, música, ruído e tela bloqueada.
4. Comparar as mesmas perguntas com humor 0%, 50%, 100% e estilos formal, amigável, técnico e equilibrado em cada provedor configurado.
5. Verificar persistência das opções após fechar e reabrir o app.
