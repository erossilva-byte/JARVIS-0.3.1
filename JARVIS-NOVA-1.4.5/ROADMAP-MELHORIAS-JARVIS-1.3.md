# Roadmap recomendado — J.A.R.V.I.S. Nova 1.3+

Este documento separa funções que já aparecem na fonte 1.2.5 de melhorias que ainda exigem implementação, integração ou teste. A presença de um controle na interface não comprova que o recurso funciona em todos os aparelhos.

## Já presentes na base e que precisam de regressão/teste real

- Palavra de ativação Porcupine com palavra integrada `JARVIS` e AccessKey configurável.
- Reconhecimento completo de fala separado do detector de palavra-chave.
- Preferência para pausar a detecção durante música/vídeo.
- Voz com controles de tom/velocidade, conversa ampliada e interrupção da fala.
- Configuração de provedores Groq, Gemini, Cerebras e Mistral, com lógica de fallback.
- Modo offline, comandos locais compatíveis, tarefas, alarmes, rotinas e diagnóstico.
- Memória e contexto configuráveis, limpeza do histórico e controles de privacidade.
- Pesquisa com links/fontes e sinalização quando a fonte não é validada independentemente.
- Ações Android para abrir aplicativos, mídia, notificações, agenda e contatos conforme permissões.
- Workflow GitHub Actions para tentar gerar APK debug.

## Prioridade P0 — antes de distribuir qualquer APK

1. Compilar com Gradle em CI e corrigir todos os erros reais de dependências, manifesto e código Java.
2. Testar a AccessKey real, primeira inicialização online e comportamento quando a chave for inválida/expirada.
3. Testar o ciclo completo: dizer “Jarvis” → bipe → comando → resposta → retorno à espera.
4. Testar o ciclo de vida do microfone com chamadas, Bluetooth, apps de música, alternância de apps, revogação de permissão e encerramento forçado.
5. Medir falso acionamento, falha de detecção e consumo de bateria em aparelhos reais.
6. Revisar armazenamento de chaves, logs, histórico e memória; nunca registrar segredos em logs nem incluir chaves no repositório.

## Prioridade P1 — tornar o assistente mais confiável

- Criar um estado único de serviço: desligado, iniciando, aguardando, ativado, ouvindo comando, falando, pausado, erro.
- Exibir uma notificação persistente com ação clara de pausar/parar, e manter a UI sincronizada com o estado real do serviço nativo.
- Implementar recuperação com tentativas limitadas e atraso progressivo, sem reiniciar o microfone indefinidamente.
- Diferenciar erro de rede, limite de API, chave inválida, ausência de reconhecimento offline e erro do detector.
- Implementar testes automatizados de parsing de comandos, rotinas, fallback de provedores, modo offline e confirmação de ações.
- Criar logs de diagnóstico exportáveis com opção de remover dados pessoais antes de compartilhar.
- Adicionar testes de acessibilidade, telas pequenas, escala de fonte, navegação por teclado e leitores de tela.

## Prioridade P2 — inteligência e experiência

- Preferências de personalidade ajustáveis: formalidade, humor, concisão e tratamento; humor reduzido em situações sérias.
- Contexto por conversa separado da memória persistente, com prévia do que será lembrado e botão para esquecer.
- Resumo de conversa longo para reduzir tokens e custo, com opção de desligar.
- Respostas de pesquisa com domínio, data, links originais e aviso explícito de dados sem confirmação independente.
- Fila de tarefas com estados, repetição, lembretes, prioridade e sincronização opcional.
- Rotinas com simulação antes de executar e confirmação explícita para ações de alto impacto.
- Métricas de latência de ativação e fala, sem armazenar áudio bruto por padrão.

## Prioridade P3 — multiplataforma e integrações

- Portar a ativação por voz para Windows com um backend nativo separado; não presumir que o plugin Android funciona no desktop.
- Sincronização opt-in entre dispositivos, com criptografia, gestão de dispositivos e opção de exclusão.
- Integrações de casa inteligente apenas após definir protocolos, permissões e modelo de segurança.
- Avaliar iOS separadamente; permissões de microfone em segundo plano e ativação contínua são diferentes das do Android.

## Critério de conclusão

Uma melhoria só deve ser marcada como concluída depois de: implementação no código, teste automatizado quando aplicável, build real, teste manual no dispositivo-alvo e atualização deste documento com resultados reproduzíveis. Não anunciar “sem erros” apenas com análise estática.


## Revisão 1.2.6 (em implementação)

- Ativação local openWakeWord “Hey Jarvis”.
- Indicador compacto quando a ativação é detectada.
- Painel do celular com bateria, temperatura da bateria, armazenamento, RAM e conexão.
- Atalhos para ajustes Android e links oficiais para chaves.
- Próximos passos: validar build, wake word, consumo e permissões em dispositivo real; depois evoluir fluxo de contatos/WhatsApp com revisão explícita antes de enviar.


## Revisão 1.2.7 — entregue no código-fonte, ainda não certificada em aparelho
- Humor configurável e estilo de resposta persistido.
- Comando para abrir conversa WhatsApp com contato cadastrado.
- Chamada de voz/vídeo e áudio continuam com confirmação/ação no WhatsApp.
- Controle universal de outros apps e identificação do app aberto externamente permanecem pendentes por dependerem de permissões especiais e APIs específicas.


## Etapa 1.3.0 — concluída no código-fonte, pendente de build
- [x] Cofre Android já existente mantido.
- [x] Cofre desktop com Electron `safeStorage`; falha fechada sem criptografia disponível.
- [x] Remoção de persistência de novas chaves em texto puro no navegador comum.
- [x] Instruções da AccessKey Picovoice alinhadas ao comportamento real de salvamento.
- [x] Testes estáticos para o fluxo de segredos.
- [ ] Compilação Android no GitHub Actions.
- [ ] Teste no aparelho de gravação, leitura, exclusão e migração de chaves.
- [ ] Implementar inferência LLM local no Android; não está incluída nesta etapa.


## Etapa 1.3.1 — integração experimental de IA local
- [x] Plugin Android para importar modelo `.task` compatível pelo seletor de documentos.
- [x] Guardar o modelo no diretório privado do app, limitar o tamanho e permitir exclusão.
- [x] Inferência local nativa em executor de fundo usando MediaPipe LLM Inference.
- [x] Interface de configurações para importar, testar e apagar o modelo.
- [x] Fallback local se nenhuma API estiver configurada ou se todas falharem; modo offline tenta inferência local.
- [ ] Build real no GitHub Actions e corrigir erros de API/dependência, se existirem.
- [ ] Validar modelo `.task` compatível, RAM, latência, temperatura e bateria em aparelho com 12 GB+ de RAM.
- [ ] Revisar migração futura para LiteRT-LM, recomendado pela documentação atual do Google AI Edge.
