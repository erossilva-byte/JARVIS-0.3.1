## 1.7.0 — 2026-10-23
- **Motor da palavra de ativação escolhível** em Ajustes ▸ Voz: `Automático` (Porcupine quando há AccessKey, senão Android), `Android (grátis)` e `Porcupine`. A escolha fica em `JarvisPrefs`, sobrevive ao reinício e o serviço a respeita; se o Porcupine estiver selecionado sem chave, o app avisa em vez de cair calado no outro detector. Trocar o motor com a escuta ligada reinicia o detector na hora.
- **Sherpa-ONNX avaliado e descartado com medição, não por opinião.** O modelo oficial `sherpa-onnx-kws-zipformer-gigaspeech-3.3M` (Apache 2.0, int8 ≈ 5,4 MB, AAR de 50 MB) foi executado aqui: reconhece “Jarvis”/“Hey Jarvis” em inglês, mas em português acertou 1 de 4 frases com limiar 0,10 e 0 de 4 no limiar padrão (0,25) — mesmo com voz masculina brasileira. O `hey_jarvis` do openWakeWord é treinado em inglês e o modelo é **CC BY-NC-SA** (não comercial). Por isso a 1.7.0 não embute 50 MB de engine que erraria a sua pronúncia: o motor gratuito continua sendo o reconhecedor do Android, agora selecionável e diagnosticável.
- **Voz estilo filme.** Perfis prontos em Ajustes ▸ Voz — `JARVIS do filme` (tom 0,60 e velocidade 0,90), `Ultra grave` (0,50/0,85) e `Padrão` — que ajustam tom e cadência de uma vez, sem travar o ajuste fino dos sliders. A busca por voz masculina ganhou nomes britânicos e brasileiros (Arthur, George, James, Joaquim, Duarte…).
- **Sinal do HUD:** duas notas curtas antes de cada resposta falada, opcional (desligado por padrão). É gerado por WebAudio, sem arquivo de áudio, e nunca impede a fala.
- **Comandos de voz:** “voz do filme”, “voz ultra grave”, “voz normal”, “liga/desliga o sinal do HUD”.
- **Mídia pelo player de verdade.** `controleMidia` passou a usar a sessão de mídia do Android (`MediaSessionManager`), que funciona com Spotify e YouTube Music; o envio de teclas virou fallback para quem não deu acesso às notificações. Antes só existiam as teclas, que o Android moderno ignora na maioria dos aparelhos. Novo `midiaAtual` responde app, faixa e artista.
- **Spotify:** novo `tocarNoSpotify` abre a busca (`spotify:search:`), as curtidas (`spotify:collection`) ou o player, com fallback para o player web. Comandos: “toca Evidências”, “toca Bohemian Rhapsody no Spotify”, “abre minhas curtidas”, “o que está tocando”, além de pausar/continuar/próxima/anterior. O app diz com clareza que o Spotify não aceita iniciar a faixa sozinho — o toque no resultado é seu.
- Versão 1.7.0 (versionCode 1700), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.6.0.

## 1.6.0 — 2026-10-22
- **Escuta que sobrevive ao app fechado e ao reinício.** O estado desejado saiu do `localStorage` e foi para `JarvisPrefs` (armazenamento privado), com a AccessKey do Porcupine cifrada em AES/GCM no Android Keystore. O serviço voltou a ser `START_STICKY`: ao ser reiniciado sem comando, lê o estado e retoma com o mesmo detector. Se o Keystore for invalidado, a chave é descartada em vez de cair para texto puro.
- **Vigia de recuperação (`JarvisWatchdog`).** Alarme inexato (`setAndAllowWhileIdle`) a cada 15 minutos reinicia o serviço quando o fabricante o encerra; o alarme concede a isenção que o Android 12+ exige para subir um serviço de microfone a partir do fundo. Também é agendado em `onTaskRemoved`, na falha do serviço e ~20 s após o boot (o Android 14+ bloqueia microfone direto do BOOT_COMPLETED).
- **Auto-rearme de 9 s** quando o Android bloqueia a abertura da tela na ativação, para a escuta não ficar muda até o próximo alarme — respeitando a pausa pedida pela interface.
- **Notificação acionável:** botões “Ouvir agora” (abre o app e começa a ouvir, mesmo com o processo morto, via `JarvisOuvirReceiver`) e “Parar”.
- **Diagnóstico do segundo plano** em Ajustes ▸ Voz: microfone, notificações, isenção de bateria, sobreposição, acesso às notificações, serviço/detector, última ativação, último erro e dica do fabricante — cada linha com o botão que resolve. Comandos: “Jarvis, diagnóstico do segundo plano” e “por que a escuta parou”.
- **Teste da palavra de ativação (20 s)** que conta acertos sem abrir o app, com resumo de calibração e falsos positivos.
- **Atalho de início automático por fabricante** (Xiaomi, Samsung, Motorola, Huawei, Oppo/Realme/OnePlus, Vivo, Asus), com fallback para as informações do app.
- **Lembretes de tarefas:** prazo agenda aviso às 09:00 do dia pelo agendador persistente; concluir ou excluir cancela.
- **Removido o checkbox “Serviço em segundo plano”**, que podia parar o serviço com a escuta ligada — uma das causas de a ativação morrer em silêncio.
- Versão 1.6.0 (versionCode 1600), mesmo pacote e mesma assinatura de CI da 1.5.1.

## 1.5.0 — 2026-10-21
- Código-fonte movido para a raiz do repositório (fim do ZIP obrigatório) e removidos relatórios/checklists/auditorias obsoletos, `__pycache__` e LEIA-MEs duplicados. O workflow continua compatível com `JARVIS-NOVA-*-fonte.zip`.
- **Palavra de ativação sem Picovoice:** detector livre no `JarvisBackgroundPlugin` — sessões curtas do `SpeechRecognizer` do Android (preferindo o reconhecimento no dispositivo do Android 12+, offline) com backoff progressivo e pausa durante música; Porcupine continua sendo o detector preferido quando há AccessKey. A interface deixa de exigir AccessKey para escutar e informa qual detector está ativo.
- **Reconhecimento do dono:** após a ativação, o perfil acústico (3 amostras) é comparado com quem falou; sem correspondência ele recusa com humor e volta a esperar “Jarvis”. Controle em Ajustes ▸ Voz (experimental, não é autenticação).
- **Novas ações:** lanterna (permissão de câmera), brilho (Modificar configurações), painel de notificações/quick settings com fallback honesto, volume por stream e percentual, e-mail pelo app do aparelho, fechar app pela tela de detalhes, versão instalada e atualização; novos apps Configurações/Galeria/Play/Relógio com fallback por fabricante; comandos rápidos correspondentes.
- **Atualizador (Atualizador + ApkProvider + release no GitHub):** plugin `JarvisUpdate` consulta o release mais novo, baixa o APK para `files/updates/`, verifica SHA-256 quando o GitHub informa o digesto e instala via FileProvider com `REQUEST_INSTALL_PACKAGES`; aba “Atualização” na interface; workflow `release-apk.yml` publica o APK por tag `v*`; assinatura de CI fixa em `ci/debug.keystore` para manter a atualização por cima viável.
- **Cérebro local básico:** sem chave e sem modelo `.task`, hora/data/contas/versão/comandos ainda respondem (chip “IA: local básica”) nos três fallbacks (sem chave, APIs falhando e modo offline).
- **Humor:** piadas próprias por comando, saudação variada conforme o nível de humor e bordões discretos, suspensos em assuntos sensíveis.
- **Interface:** central de comando lateral (telas largas), dashboard com medidores de bateria/RAM/armazenamento, tira de comandos rápidos no celular, marca central e varredura no HUD, acabamento sci-fi (cantos acesos e scanline sutil).
- Testes: suíte ampliada com `tests/test_novos_recursos.py` (34 verificações); versão 1.5.0/versionCode 1500 em `VERSAO.json`, `package.json` e workflows. Compilação Android e testes físicos das funções novas permanecem pendentes de validação.

## 1.5.0 — HUD refinado — 2026-10-21
- Núcleo central no estilo reator: centro escuro com aro aceso, coroa pontilhada, anel interno girando em sentido inverso e marca “JARVIS” legível sobre o miolo.
- Grade radial de 30 setores, eixos cardinais com arco de canto e anel duplo de marcas (finas + quatro marcas fortes).
- Satélites luminosos orbitando em duas velocidades opostas, mantendo a varredura de arco na borda.
- Telemetria curta em volta do anel (AUDIO / LINK / SYS / CORE) e subtítulo de versão dentro do núcleo; escondidas em telas estreitas ou baixas.
- Cores continuam reagindo ao estado (ouvindo/processando/falando) via `--rgb`, e todas as animações novas respeitam `prefers-reduced-motion`.

## 1.5.0 — revisão de correções — 2026-10-21
- Detector livre agora pausa **durante chamadas telefônicas e VoIP** (antes só a mídia pausava), devolvendo o microfone ao usuário e retomando a escuta sozinho quando a chamada termina.
- Instalador do atualizador deixa de recusar instalação por engano em Android 11+: `resolveActivity` retornava nulo sem `<queries>`; foi adicionada a visibilidade da intent `application/vnd.android.package-archive` e o código passa a tratar somente `ActivityNotFoundException`.
- Corrigido “deste origem” → “desta origem” na mensagem de permissão de instalação.
- `JarvisService` não lança mais NPE quando o pacote não expõe intent de lançamento.
- Pedido de notificação só é feito com Activity disponível (evita crash ao iniciar em segundo plano).
- Fala de “verificar atualização” mostra o tamanho do APK em MB (antes exibia um `build ?` sem sentido).
- Interface explica que o detector livre mantém o microfone em uso e o indicador verde do Android visível, e que chamadas têm prioridade.

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

## 1.5.1 — 2026-10-22

- **Segundo plano real:** a detecção da palavra “Jarvis” foi movida do plugin (que morria junto da
  Activity) para o `JarvisService`, com notificação de estado, ponte `JarvisWakeBus`, parada
  explicada por falha e tentativa de reabrir o app quando o nome é chamado.
- **Atualizador:** `/releases/latest` com 404 deixou de ser tratado como erro de conexão; há busca
  na lista de releases, mensagens por código HTTP (401/403/404) e botão “Ver releases no navegador”.
- **Reconhecimento de voz:** `EXTRA_PREFER_OFFLINE` só é usado no modo local; troca automática entre
  reconhecedor local e de rede (códigos 12/13/14, sem rede) e mensagens específicas. Sem chave de
  transcrição, o Android é usado direto, sem gravar duas vezes. O detector livre para com explicação
  depois de falhas seguidas, em vez de repetir em silêncio.
- **Perfil acústico:** vetor de 6 características calculado apenas sobre quadros com fala, DFT
  corrigida (bins pares não são mais ignorados) e comparação por distância normalizada. Silêncio e
  ruído são recusados; a exigência de voz passou a vir desligada (limiar 60%).
- **Medidor de áudio:** a barra passou a usar escala em decibéis; antes `rms * 6` saturava em
  100% com qualquer som acima de 0,17, então o medidor não distinguia voz de ruído.
- **Ajustes:** botões “Impedir suspensão pela bateria” e “Permitir abrir na tela”; permissão
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` no manifesto.
- Versão 1.5.1 (versionCode 1501), mesmo pacote e mesma assinatura de CI da 1.5.0.

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
