# Checklist de teste físico — POCO X7

- [ ] Instala e abre sem crash; confirma versão 1.4.2.
- [ ] Nome e tratamento persistem após fechar/reabrir.
- [ ] Testar vozes pt-BR disponíveis; confirmar qual soa masculina; verificar tom e velocidade.
- [ ] Permitir microfone; testar transcrição manual em ambiente silencioso e com ruído.
- [ ] Cadastrar três amostras do perfil acústico; comparar com a própria voz e com outra pessoa; registrar falsos positivos/falsos negativos. Não usar para segurança.
- [ ] Apagar o perfil acústico e confirmar que o status retorna a “nenhuma amostra”.
- [ ] Sem AccessKey Picovoice: botão manual funciona e interface informa que wake word contínua está indisponível.
- [ ] Com AccessKey válida: ativação “Jarvis”, tela bloqueada, pausa/retomada, ruído e bateria; verificar que escuta inicia apenas quando ativada.
- [ ] Importar modelo MediaPipe `.task` conhecido como compatível; testar inferência, RAM, aquecimento e latência; apagar modelo.
- [ ] Ativar modo offline e confirmar que chamadas de API não são feitas; testar hora/data/alarmes/comandos locais.
- [ ] Testar notificações, alarmes após reinicialização, permissões, chamadas e ações que exigem confirmação.
- [ ] Conferir uso de bateria após 15 e 60 minutos; verificar que a escuta pode ser desligada.
