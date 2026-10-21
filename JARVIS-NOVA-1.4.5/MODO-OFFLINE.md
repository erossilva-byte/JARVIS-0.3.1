# Modo Offline — J.A.R.V.I.S. Nova 1.1.0

## O que ele faz

Quando o modo offline está ativado, o J.A.R.V.I.S. bloqueia as chamadas às APIs de IA (Groq, Gemini, Cerebras e Mistral) no fluxo normal de conversa. Também bloqueia pesquisa/clima online e pula os testes de rede do diagnóstico. O indicador de estado muda para “Modo offline”.

### Comandos e recursos locais

- Informar hora e data.
- Criar, listar e cancelar alarmes, lembretes e temporizadores que usam o agendador local do Android.
- Executar rotinas já configuradas, desde que as ações da rotina não dependam de internet.
- Abrir aplicativos conhecidos, voltar à tela inicial e tentar reabrir aplicativos conhecidos por nome.
- Enviar comandos de mídia padrão (pausar, continuar, próxima faixa, faixa anterior) e ajustar o volume; o app de mídia precisa aceitar esses comandos.
- Consultar bateria, carregamento e tipo de conexão informado pelo Android.
- Abrir a agenda e abrir o editor de um evento pré-preenchido; o usuário precisa revisar e salvar o evento.
- Preparar SMS ou WhatsApp com contato cadastrado; o usuário revisa e confirma o envio dentro do aplicativo.
- Ler resumos recentes de notificações se o usuário concedeu acesso especial ao Jarvis. Responder só é possível quando a notificação oferece ação de resposta rápida compatível.
- Anunciar uma chamada quando o usuário ativou essa opção, concedeu acesso às notificações e o Android categoriza a notificação como chamada.
- Falar respostas usando o TTS instalado no aparelho.

## O que não funciona offline

- Respostas generativas complexas dos provedores de IA.
- Pesquisa na internet, clima atual e dados atualizados.
- Recursos externos dentro de apps que precisam de conexão.
- Reconhecimento de voz local se o aparelho não tiver um reconhecedor on-device e o pacote de idioma português disponível.

## Como usar

1. Abra Ajustes.
2. Entre em “Voz e microfone”.
3. Ative “Modo offline”. Também pode dizer “Jarvis, ativar modo offline” quando a escuta por voz local estiver disponível.
4. Para sair, desative o controle ou diga “Jarvis, desativar modo offline”.

## Privacidade e limites

- Em modo offline, o Jarvis não envia consultas de conversa às quatro APIs; o diagnóstico também não executa testes de rede.
- O reconhecimento de voz offline usa `SpeechRecognizer.createOnDeviceSpeechRecognizer` quando o Android o disponibiliza. A disponibilidade depende do aparelho, da versão do Android e dos pacotes de voz instalados.
- Se o reconhecimento local não existir, o modo offline deve avisar e não fazer fallback para reconhecimento online. O usuário ainda pode digitar comandos.
- Abertura de apps, envio de mensagens, ligações e notificações envolvem outros aplicativos Android; esses aplicativos podem usar a rede por conta própria.
- O Android não permite que um app comum force o encerramento de qualquer outro app. O comando de saída leva à tela inicial.
- O serviço de microfone não é reiniciado automaticamente no boot por padrão, pois versões recentes do Android restringem iniciar serviços de microfone a partir de um receiver de inicialização. Os alarmes persistentes são restaurados; talvez seja necessário abrir o Jarvis novamente para retomar a escuta.

O botão “Desligar escuta e apagar dados locais”, na Central de privacidade, para o serviço de escuta e remove histórico, memória, registros e resumos de notificações, mantendo chaves API e contatos.


## Alternância automática (v1.2.0)

A alternância automática observa os eventos de conectividade `online`/`offline` do ambiente. Quando o sistema reporta que a rede caiu, o app marca o modo offline e aborta a chamada de rede em andamento. Ao receber evento de retorno, ele volta ao modo online apenas se o modo offline tiver sido ativado automaticamente, sem sobrescrever a escolha manual. A detecção não é infalível quando o dispositivo permanece conectado ao Wi-Fi, mas perde acesso à internet. O modo offline manual continua disponível.
