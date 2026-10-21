## 1.2.7 — auditoria final pré-repositório — 2026-10-16
- Corrigido escape do comando `find -exec` no workflow, que poderia interromper a extração da fonte no GitHub Actions.
- Ajustados os rótulos visuais para “Hey Jarvis”, correspondentes ao modelo openWakeWord configurado.
- O salvamento de novas chaves no Android agora falha de forma explícita se o cofre nativo não estiver disponível, em vez de gravar silenciosamente em texto puro.
- Chaves legadas em texto puro no Android são migradas para o cofre quando possível; se a migração falhar, a cópia insegura é removida e o usuário é avisado.
- Tornado idempotente o patch de versão Android e adicionados testes de prontidão de release.
- Build debug real concluído com sucesso no GitHub Actions em 2026-10-16; testes físicos continuam pendentes.

## 1.2.5 — 16/10/2026
- Corrigidas definições duplicadas de métodos Java no plugin nativo de ativação por voz.
- Validador agora procura assinaturas Java duplicadas.
- Workflow e metadados atualizados para versionCode 1205.
- Build Android e testes físicos continuam pendentes.

## 1.2.3 — 2026-10-15 (fonte em revisão; sem APK)

- Habilitada como opção manual a ativação experimental pela palavra “Jarvis”, usando o `SpeechRecognizer` do Android e podendo reconhecer a palavra seguida do comando.
- O modo permanece desligado por padrão e a interface explica que não é detector dedicado de baixo consumo.
- O serviço em primeiro plano só é iniciado para a escuta experimental quando a preferência de segundo plano está ativa; alarmes/lembretes continuam independentes.
- Removido o `PARTIAL_WAKE_LOCK` incondicional de até 12 horas, reduzindo consumo desnecessário quando a escuta não está ativa.
- Ajustados os textos da notificação, a declaração de tipo do serviço e a documentação para não sugerir reprodução de mídia nem eficiência de bateria não medida.
- Pendente: detector local dedicado (ex.: engine compatível/licença validada), execução robusta com processo encerrado/tela bloqueada, testes em dispositivos reais, bateria e conflito com música.

# Changelog

## 1.2.2 — 2026-10-15
- Adicionada importação explícita e consentida de contatos do Android para a lista local.
- A permissão READ_CONTACTS é solicitada apenas ao tocar em “Importar contatos do Android”.
- Importação limitada a 500 entradas por execução; números e nomes não são enviados automaticamente ao provedor de IA.
- Abertura do WhatsApp já existente via atalho nativo; mensagens continuam exigindo revisão/envio manual.
- Palavra de ativação dedicada de baixo consumo continua pendente; o SpeechRecognizer contínuo não é apresentado como detector equivalente ao “Ok Google”.


## 1.2.1 — 2026-10-15 (fonte em desenvolvimento; sem APK validado)

- Contatos: normaliza emojis, pontuação, acentos e letras repetidas em nomes ditados (ex.: “Biaa🩵🩵” pode corresponder a “Bia”). Correspondência por prefixo só é aceita quando há um único resultado; em casos ambíguos, não escolhe um contato automaticamente.
- Personalidade: instruções mais consistentes para competência, humor seco e ironia leve inspirados no arquétipo de assistente tecnológico; evita imitar falas de filmes e reduz humor em situações sensíveis.
- Bateria/rede: removidas chamadas extras de pré-aquecimento à API que ocorriam na inicialização e antes de iniciar a escuta.
- Privacidade/bateria: ativação experimental por fala desligada por padrão. O mecanismo atual continua baseado em `SpeechRecognizer` e não satisfaz o requisito de um detector dedicado de baixo consumo semelhante ao “Ok Google”.
- PENDENTE: integrar detector local de palavra-chave com modelo/licença verificados, áudio de baixa potência quando suportado, ciclo de vida Android e testes físicos. Não declarar essa função concluída nem gerar release até validar.
- Voz, calibração de microfone, chamadas, SMS/WhatsApp, notificações, alarmes, temporizadores, tarefas, rotinas, provedores de IA e diagnóstico já possuem partes implementadas na base 1.2.0; precisam de testes de regressão e validação por aparelho antes de serem considerados totalmente confiáveis.

## 1.2.0 — 2026-10-15 (patch de escuta; requer compilação e teste físico)

- Adicionada opção “Priorizar música e vídeos”: quando ativada, a escuta experimental da palavra “Jarvis” é suspensa enquanto o Android reporta reprodução de mídia e retomada quando ela termina. Durante a reprodução, o usuário deve tocar no microfone para dar um comando.
- Corrigido o agendamento de reinício da escuta para usar uma única tarefa pendente, evitando acumular reinícios concorrentes.
- Limitação conhecida: isto é uma proteção intermediária, não o comportamento completo do “Ok Google”. A detecção por palavra ainda usa `SpeechRecognizer`; para ativação por voz enquanto a música toca sem disputa de áudio, falta integrar um detector local de palavra-chave dedicado e validá-lo em aparelhos reais.
- O APK não foi recompilado nem testado em aparelho físico nesta alteração.

- Revalidação estática completa do pacote-fonte; testes automatizados e sintaxe JavaScript aprovados.
- Corrigida a inicialização da voz TTS no listener de notificações, que impedia o anúncio de chamadas.
- Adicionada verificação e solicitação de acesso especial para alarmes exatos no Android 12 ou posterior.
- A restauração de alarmes preserva lembretes válidos quando o sistema bloqueia temporariamente o agendamento e tenta restaurá-los novamente ao abrir o app.
- Adicionado `.gitignore` para excluir dependências locais, builds e cache Python do controle de versão.
- APK não foi compilado nem testado em aparelho físico neste ambiente.

## 1.1.0 — 2026-10-14 (código-fonte; APK depende de compilação/teste)

- Mantém Groq como prioridade e as opções de chave Gemini, Cerebras e Mistral existentes, com fallback já presente no projeto.
- Adiciona modo offline que bloqueia chamadas de IA e testes de rede; comandos locais continuam disponíveis.
- Usa reconhecimento de voz nativo em modo estritamente local quando o Android oferece esse recurso. Palavra de ativação offline exige reconhecimento on-device; se indisponível, a função não deve recorrer silenciosamente à rede.
- Adiciona comandos locais para pausar/retomar mídia, faixa seguinte/anterior, volume, status de bateria/conexão, sair para a tela inicial e reabrir aplicativos conhecidos.
- Adiciona composição de SMS com texto preparado; o usuário revisa e toca em enviar. Mensagens de WhatsApp continuam abrindo com texto preparado, sem envio silencioso.
- Adiciona leitura de até dez resumos de notificações recentes após autorização explícita do Android e tentativa de resposta rápida à última notificação que exponha RemoteInput.
- Adiciona anúncio opcional de chamadas apenas quando o Android classifica a notificação como chamada e o usuário ativa a opção.
- Adiciona abertura da agenda e criação de evento por meio do editor de calendário do Android, para revisão e salvamento pelo usuário.
- Mantém alarmes e lembretes persistentes, rotinas, memória configurável, diagnóstico e modo de conversa ampliada.
- Ações sensíveis continuam sujeitas ao modo seguro e à confirmação. O modo seguro pode bloquear ligações e mensagens até ser desligado em Ajustes; a confirmação permanece obrigatória.
- O encerramento forçado de outros apps não é oferecido: o comando de saída volta à tela inicial e o comando de retorno tenta reabrir o app conhecido.

### Limitações conhecidas a testar no aparelho

- A disponibilidade de reconhecimento local em português varia conforme versão do Android, serviço de voz e pacotes instalados.
- Leitura de notificações exige ativação manual do acesso especial. O conteúdo lido é apenas o que aparece na notificação, não o histórico completo de conversas.
- Resposta por voz só funciona se a notificação ativa fornecer ação de resposta rápida compatível.
- Anúncio de chamada depende de o aplicativo de telefone emitir notificação categorizada como chamada; fabricantes podem variar.
- Controles de mídia dependem do aplicativo de reprodução.
- O evento de calendário é aberto para revisão e precisa ser salvo pelo usuário.
- O Android pode impedir o reinício automático de serviço com microfone após reinicialização; alarmes são restaurados, mas o usuário pode precisar abrir o J.A.R.V.I.S. novamente para reativar escuta.
- Ainda não há validação física de chamadas, notificações, mídia, voz offline ou build Android nesta etapa.


## 1.2.4 — 16/10/2026
- Substituída a detecção contínua por `SpeechRecognizer` por um detector local dedicado Porcupine 4.0.2 para a palavra integrada JARVIS.
- O reconhecimento completo começa somente depois da palavra de ativação; o fluxo orienta o usuário a aguardar o bipe antes de falar o comando.
- Adicionado campo para AccessKey Picovoice com armazenamento no cofre nativo do Android quando disponível e ação para apagar a chave.
- Pausa opcional do detector durante música/vídeo para reduzir conflito de áudio.
- Refinada a personalidade: cortesia impecável, calma, humor seco e sarcasmo sutil e ocasional, sem reproduzir diálogos dos filmes.
- Incluída dependência nativa Porcupine no workflow de build e verificações estáticas específicas.
- Pendente: compilação Gradle no CI, validação com AccessKey, testes em aparelho Android e medição de bateria.


## 1.2.6 — evolução baseada na fonte 1.2.5

- Detector local openWakeWord sem AccessKey, com modelo “Hey Jarvis” (inglês); precisa de teste físico e verificação da licença do modelo antes de distribuição comercial.
- Mini-interface compacta de ativação ao detectar a palavra de ativação.
- Aba “Celular” com bateria, temperatura reportada pela bateria, armazenamento, RAM, conectividade, dados do aparelho e atalhos para configurações do Android.
- Avisos básicos quando armazenamento/bateria estão baixos ou a temperatura reportada está elevada.
- Links oficiais para cadastro de chaves de IA e avisos de cotas/limites.
- Mantidos os limites de segurança do Android: mensagens e chamadas não são enviadas silenciosamente e controle irrestrito de outros apps não é prometido.
- Build Gradle e validação em aparelho ainda pendentes.


## 1.2.7 — personalidade configurável e fluxo WhatsApp
- Corrigida a resposta falada do status do aparelho para não anunciar “Bateria: -1%” quando a leitura não está disponível.

- Adicionados controles de intensidade de humor e estilo de resposta (equilibrado, formal, amigável ou técnico).
- Preferências de personalidade são salvas localmente e usadas na instrução de sistema da IA.
- Adicionado comando para abrir a conversa do WhatsApp com um contato cadastrado.
- Comandos que mencionam chamada de voz/vídeo pelo WhatsApp abrem a conversa e explicam que o usuário precisa confirmar e tocar no controle de chamada dentro do WhatsApp; não há chamada silenciosa.
- Atualizados versão, validador e workflow de compilação para 1.2.7.
- Build debug confirmado como concluído com sucesso no GitHub Actions em 2026-10-16.
- Limitações mantidas explicitamente: “Hey Jarvis” em inglês; não há controle universal de qualquer app nem leitura automática do app em primeiro plano sem permissão especial. Testes físicos continuam pendentes.


## Ajuste de preparação do APK (1.2.7)

- Definida API mínima Android 26 no patch Gradle, necessária para openWakeWord Android.
- Adicionado teste automatizado de idempotência para dependência, JitPack e API mínima.
- Build debug confirmado como compilado com sucesso no GitHub Actions; a validação física continua pendente.

## Revisão incremental pós-1.2.7 — status rápido e Picovoice
- Adicionado atalho clicável “Status do celular” na tela principal para abrir diretamente o painel de estado.
- Painel de status agora separa a conexão ativa, Wi-Fi e dados móveis, além de bateria, temperatura da bateria, armazenamento com alertas, RAM, modelo/Android e último app iniciado pelo próprio JARVIS.
- Adicionado campo de AccessKey Picovoice com link oficial, instruções e opção para apagar; no Android, a chave é guardada pelo mesmo cofre nativo.
- Importante: guardar a AccessKey não ativa Picovoice. O detector desta versão continua sendo openWakeWord (“Hey Jarvis”); integração nativa Porcupine, modelo de wake word e testes em dispositivo são trabalhos separados.
- Testes estáticos `npm run test:all` aprovados após as mudanças. O APK existente não contém estas alterações; é necessária uma nova execução do GitHub Actions.


## 1.2.9 — integração de wake word e inteligência comportamental

- Integra SDK Porcupine Android 4.0.2 e usa a palavra integrada “Jarvis” quando há AccessKey.
- Mantém openWakeWord “Hey Jarvis” como fallback sem AccessKey.
- O estado visual e a orientação falada refletem qual detector está selecionado.
- Personalidade/humor têm prévia e orientação explícita para salvar as preferências.
- Build Android e testes de microfone/AccessKey ainda precisam ser confirmados no GitHub Actions e em aparelho físico.


## 1.3.0 — Base de segurança e configurações
- Desktop Electron: migração de chaves de API e Picovoice para o `safeStorage` do sistema operacional, com arquivo cifrado no diretório privado do aplicativo.
- Falha fechada se o cofre do sistema não estiver disponível; o app não grava novas chaves em texto puro no navegador comum.
- Migração de chaves legadas em texto puro: tenta protegê-las e remove a cópia antiga; se a proteção falhar, remove a cópia insegura e pede recadastro.
- Interface de AccessKey Picovoice esclarece que a chave é salva ao sair do campo, separadamente do botão geral de configurações.
- Adicionados testes estáticos para as regras de armazenamento de segredos.
- Ainda pendente: integração real de inferência de modelo de linguagem local no Android, build Android desta versão e validação em dispositivo físico.


## 1.3.1 — IA local Android experimental
- Adicionada integração nativa experimental com MediaPipe LLM Inference para gerar texto no próprio aparelho a partir de um modelo `.task` compatível importado pelo usuário.
- Adicionada tela de importação, teste e exclusão do modelo local. O modelo fica no armazenamento privado do aplicativo e não é incluído no APK.
- Adicionado fallback local quando nenhuma API está configurada ou quando os provedores configurados falham; o modo offline tenta o modelo local e mantém comandos locais como prioridade.
- A inferência local não recebe chaves de API. O runtime MediaPipe usado nesta etapa está em manutenção; avaliar migração para LiteRT-LM após prova de conceito e build real.
- Build Android e teste em aparelho ainda pendentes.

## 1.4.2 — 2026-10-20
- Adicionado perfil acústico experimental local, com captura iniciada pelo usuário, comparação indicativa e exclusão do vetor salvo.
- Melhorada a troca de modelo MediaPipe com arquivo temporário e tentativa de rollback.
- Workflow agora registra checksum e metadados de compilação no artefato.
- Criados auditoria técnica e checklist específico para validação no POCO X7.
- Limitações mantidas explícitas: Porcupine exige AccessKey; IA local depende de modelo .task compatível; perfil acústico não é autenticação biométrica; APK e dispositivo físico ainda precisam ser validados.
