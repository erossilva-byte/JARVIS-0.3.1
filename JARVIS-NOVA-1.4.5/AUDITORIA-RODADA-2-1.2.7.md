# Auditoria técnica — rodada 2 — J.A.R.V.I.S. Nova 1.2.7

Data: 2026-10-16
Base: fonte `JARVIS-NOVA-1.2.7-status-auto.zip`/árvore de trabalho correspondente.

## Resultado automatizado

`npm run test:all`: APROVADO nesta rodada. Foram aprovados `node --check` para `app.js`, `main.js` e `apps.js`; teste de rotas de voz do WhatsApp; validação estrutural do projeto; testes dos patches Gradle; validação de prontidão; compilação sintática dos scripts Python. O HTML tem 149 IDs únicos. O teste específico da tela de status confirma a existência da atualização automática a cada 5 segundos, pausa de consulta quando a página está oculta e texto explicativo na interface. O pacote ZIP anterior também passou por verificação de integridade.

## Matriz de funções: o que a fonte permite afirmar

| Função | Estado nesta auditoria | Limite / próximo teste |
|---|---|---|
| Tela de status do aparelho | Implementada no código; atualização automática configurada | Leitura real de bateria, temperatura, armazenamento, RAM e rede precisa ser validada em aparelho; a atualização é a cada 5 s enquanto o painel está visível |
| Proteção de ícones / layout | Há regras CSS e teste estático para preservar o botão Configurações e reorganizar cabeçalho | Testar visualmente em diferentes larguras, com teclado aberto e diferentes densidades |
| Chaves Groq/Cerebras/Mistral/Gemini | Campos e fluxo de armazenamento presentes | Testar chaves reais, limites/cotas, indisponibilidade e fallback ponta a ponta; teste estático não confirma respostas dos provedores |
| Chave Picovoice | Campo para guardar/apagar chave presente | **Não ativa Porcupine**; a própria interface informa que o motor não está integrado. O detector usado continua sendo openWakeWord |
| Palavra de ativação | Integração openWakeWord e controles presentes para “Hey Jarvis” | Não é “Jarvis” isolado garantido. Ainda falta teste em aparelho com tela bloqueada, ruído, falsos acionamentos, reinício e consumo de bateria |
| Voz / transcrição | TTS e caminho de transcrição Android implementados | Reconhecimento local depende do suporte/idioma no dispositivo; testar velocidade, tom, cancelamento e permissões fisicamente |
| Modo offline | Há alternância e comandos locais; caminho Android pede transcrição somente local quando disponível | Pesquisa web e IA em nuvem não funcionam offline. Se o reconhecimento local não estiver disponível, o comando por voz falha e deve-se digitar |
| Tarefas | CRUD local e filtros implementados | Prazos das tarefas não agendam notificação automática em segundo plano |
| Alarmes / temporizadores | Há implementação nativa separada | Testar permissões de alarmes exatos, reinício do aparelho, notificações e fabricantes diferentes |
| Rotinas | Editor e validação de ações presentes | Testar execução real de cada tipo de ação e as permissões associadas |
| WhatsApp | Roteamento de abertura de conversa e preparação de fluxo testados | Não envia mensagem, áudio ou inicia chamadas silenciosamente; é necessária interação/confirmacão no WhatsApp |
| Contatos, SMS, notificações, mídia e abertura de apps | Há pontos de integração na fonte | Não validados ponta a ponta; dependem de permissões Android, apps instalados e políticas do sistema |
| Memória/contexto | Controles locais para memória e contexto presentes | Testar persistência após fechar/reabrir, apagar dados e verificar exatamente o que é enviado a cada provedor |

## Achados e riscos restantes

1. A aprovação de `npm run test:all` não é um teste funcional completo; a maioria das verificações é estática e cobre invariantes selecionados.
2. O detector de ativação e o serviço de microfone precisam de ensaio em dispositivo real, especialmente com tela bloqueada e restrições de bateria do fabricante.
3. O campo Picovoice pode ser confundido com integração ativa; a interface atual explica que a chave só é armazenada, não usada pelo motor.
4. A atualização do status foi adicionada à fonte após o APK de referência existente. O APK antigo não deve ser considerado como contendo essa atualização até uma nova compilação bem-sucedida do workflow.
5. Não foi possível comprovar aqui chamadas reais aos provedores, notificações do sistema, chamadas/SMS, comportamento do WhatsApp, medição de bateria nem compatibilidade visual em um aparelho físico.

## Conclusão

**A fonte passa nos testes automatizados executados, mas não é correto afirmar que todas as funções estão funcionando em produção.** Algumas são implementadas com dependências externas; outras têm limitações explícitas; e várias exigem validação no Android real. Para certificar a versão, é necessário gerar um APK novo a partir desta fonte e executar os testes físicos descritos acima.
