# Checklist — J.A.R.V.I.S. Nova 1.2.7

- [ ] Enviar `JARVIS-NOVA-1.2.7-fonte.zip` para a raiz do repositório.
- [x] Executar localmente `npm run test:all` (inclui teste do patch Gradle e prontidão do release).
- [x] Corrigir o escape de shell do comando de extração no workflow.
- [x] Verificar falha segura do cofre de chaves no Android e alinhar o rótulo da wake word.
- [x] Confirmar que GitHub Actions executa os testes estáticos.
- [x] Confirmar resolução da dependência openWakeWord/JitPack e compilação Gradle.
- [x] Patch Gradle define API mínima 26, exigida pela biblioteca de wake word.
- [ ] Instalar o APK debug no Android-alvo.
- [ ] Testar “Hey Jarvis” em ambiente silencioso e ruidoso, com tela ligada/bloqueada.
- [ ] Testar permissão, consumo de bateria, pause/resume e notificações do serviço.
- [ ] Testar humor/estilo após fechar e reabrir o app.
- [ ] Testar abertura da conversa WhatsApp com número internacional válido; confirmar que não envia nem chama automaticamente.
- [ ] Validar links de provedores e tratamento de chave inválida/limite de uso.
- [ ] Revisar licença CC BY-NC-SA 4.0 do modelo antes de distribuição comercial.

**Status atualizado em 2026-10-16:** testes estáticos aprovados; uma compilação debug anterior foi bem-sucedida. Esta fonte revisada corrige a resposta falada para bateria indisponível, então é necessário executar novamente o workflow para incluir essa última correção no APK. Continuam pendentes instalação e testes físicos em Android compatível (API 26+), especialmente wake word, permissões, consumo de bateria, alarmes e integrações com apps externos.
