# J.A.R.V.I.S. Nova 1.2.6 — revisão da base 1.2.5

## Escopo

Esta revisão foi construída a partir do arquivo-fonte original `JARVIS-NOVA-1.2.5-fonte(1).zip`. A identidade independente `com.jarvis.nova` foi preservada. O objetivo foi reaproveitar recursos existentes, não reescrever o aplicativo do zero.

## Alterações implementadas

- Substituição da integração Porcupine/Picovoice por openWakeWord Android, com o modelo integrado `HEY_JARVIS` e sem AccessKey para detectar a palavra.
- A transcrição completa continua começando somente após o gatilho de ativação; a escuta por palavra-chave é opt-in e permanece desligada por padrão.
- Indicador compacto com núcleo animado quando a ativação é detectada.
- Nova aba **Celular**: bateria, estado de carregamento, temperatura reportada pela bateria, armazenamento interno total/livre/percentual usado, estimativa de RAM, conectividade e modelo/versão Android.
- Alertas simples para armazenamento usado a partir de 80%/90%, bateria até 15%, temperatura reportada a partir de 42 °C e sinal de pouca RAM do sistema.
- Atalhos para configurações Android, bateria e armazenamento.
- Histórico local do último aplicativo iniciado pelo próprio JARVIS (não tenta espionar apps abertos pelo usuário fora do JARVIS).
- Links oficiais para cadastrar chaves Groq, Cerebras, Mistral e Gemini, com aviso de que cotas gratuitas variam e não são ilimitadas.
- Ampliada a lista de atalhos de apps comuns, mantendo abertura via intents/APIs Android disponíveis.
- Atualização do validador, da versão e do workflow de compilação.

## Limites conhecidos e decisões de segurança

- O modelo `Hey Jarvis` fornecido pela integração está descrito como inglês; a precisão com fala em português, ruído e música não está comprovada. O acionamento por “Jarvis” sozinho não é garantido por esse modelo.
- A licença do modelo pré-treinado openWakeWord é CC BY-NC-SA 4.0; avaliar a licença antes de distribuir ou monetizar o app. O código e o modelo têm licenças distintas.
- A detecção local ainda precisa do microfone ativo enquanto está habilitada; isso não equivale a microfone fisicamente desligado. O Android pode restringir execução em segundo plano, principalmente com a tela bloqueada.
- Temperatura apresentada é a que o Android reporta para a bateria; não é uma leitura térmica de CPU/GPU.
- O JARVIS não obtém acesso irrestrito à tela de outros aplicativos. Automação de interface exige uma solução específica de acessibilidade, autorização explícita do usuário, testes por aplicativo e salvaguardas. Esta revisão não ativa uma permissão de acessibilidade silenciosamente.
- Mensagens e chamadas são encaminhadas para intents/telas oficiais de revisão. O app não envia mensagem nem inicia chamada sensível sem a confirmação exigida no fluxo atual.
- O acesso a “último app aberto” fora do JARVIS exigiria permissão especial de uso de apps. Esta revisão registra apenas o último app que o próprio JARVIS tentou iniciar.

## Verificações realizadas

- `npm run test:all`: aprovado.
- Sintaxe JavaScript (`node --check`): aprovada.
- Validador estático HTML/identidade/recursos: aprovado, 139 IDs únicos.
- Compilação dos scripts Python de patch: aprovada.
- ZIP final: será validado com `unzip -t`.

## Ainda pendente

Não foi executado um build Gradle real nesta sessão e não existe APK confirmado por esta revisão. O workflow do GitHub Actions precisa compilar a fonte e o APK deve ser instalado/testado em um aparelho Android antes de ser considerado pronto.
