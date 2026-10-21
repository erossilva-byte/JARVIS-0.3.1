# Relatório de revisão — J.A.R.V.I.S. Nova 1.2.7

## Base
Derivada exclusivamente do ZIP fonte 1.2.5 fornecido pelo usuário, mantendo a identidade independente `com.jarvis.nova`.

## Alterações nesta revisão
- Humor ajustável de 0 a 100%.
- Estilo de resposta: equilibrado, formal, amigável ou técnico.
- Preferências persistidas localmente e injetadas no prompt do assistente.
- Ação `abrir_conversa_whatsapp`, resolvida por contato cadastrado.
- Comando por voz para abrir chat e instrução explícita de que chamadas/áudio/envio devem ser concluídos e confirmados pelo usuário dentro do WhatsApp.
- Workflow e versão atualizados para 1.2.7.

## Itens ainda não concluídos
- Controle universal da tela/qualquer app: exige serviço de acessibilidade opcional, habilitação manual, análise de segurança e testes; não é uma permissão silenciosa nem garante compatibilidade com todos os apps.
- Envio automático de áudio, chamadas de voz/vídeo do WhatsApp: não implementados; o app não deve contornar a confirmação do usuário.
- Palavra de ativação “Jarvis” isolada em português: o modelo integrado detecta “Hey Jarvis” em inglês.
- Reconhecimento de último app aberto fora do JARVIS: não implementado porque exige acesso especial de uso de apps.
- Medição real de bateria, falsos acionamentos e comportamento com tela bloqueada: depende do aparelho.
- Build debug real concluído com sucesso no GitHub Actions em 2026-10-16; instalação e teste físico continuam pendentes.

## Verificação
Executar `npm run test:all`; aprovação estática não substitui compilação nem testes no dispositivo.


## Ajuste final pré-compilação

- O patch Gradle agora fixa `minSdkVersion 26`, requisito do detector openWakeWord Android (Android 8.0+).
- Adicionado teste automatizado de fumaça para o patch Gradle: verifica API mínima, dependência openWakeWord, repositório JitPack e idempotência em Gradle Groovy/Kotlin settings.
- A compilação Android real foi concluída com sucesso no GitHub Actions; o teste físico continua pendente.
