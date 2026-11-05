# J.A.R.V.I.S. Nova 1.44.0

## 1.44.0 — Bloqueio com biometria, NFC e central própria

A tela de bloqueio opcional ganhou autenticação real: biometria forte do Android (nunca câmera comum), leitura NFC com UID guardado só como hash e modos combinados, incluindo duas etapas. Tudo é configurado em Ajustes ▸ Segurança, com tempo de inatividade, limite de tentativas, tags, histórico e restauração. O PIN passou a PBKDF2 com sal e o hash antigo migra sozinho. Sem biometria ou NFC, a tela diz isso e o PIN continua sendo a recuperação; nada foi testado em aparelho físico e o APK segue com assinatura debug/CI.

## 1.42.8 — Contexto visual da sessão

O Vision passou a lembrar o que foi analisado: perguntas como "ele é bom para corrida?" e "e quanto custa?" usam o mesmo objeto, sem repetir a foto. Marca e modelo só são afirmados com evidência legível; cada informação é marcada como confirmada, de loja ou estimada. Vários objetos podem ser selecionados e comparados, texto lido na imagem é tratado como dado (nunca instrução) e componentes técnicos são ligados à base elétrica e ao Projetista. Nada é salvo sem pedido explícito. Sem chave de IA, a precisão de identificação não foi medida.

## 1.42.7 — Base técnica elétrica e sequência de motores

O projetista ganhou uma base de engenharia própria (`eletrica.js`): componentes com terminais, função, limites e símbolo IEC; tabelas de ampacidade, contator, disjuntor e térmico; dimensionamento com memória de cálculo e conferência independente. Nova topologia monta dois motores em sequência, com o segundo entrando X segundos depois do primeiro. A segunda análise (`conferirObjetivo`) verifica se o projeto montado atende ao pedido, e a netlist permite exportar e reimportar o diagrama em texto. O `.cad` do CADeSIMU continua não sendo gerado nem aberto, e não há simulação elétrica.

O APK **1.44.0** (`jarvis-nova-1.44.0-10440.apk`) tem **81333564 bytes** e SHA-256 `6453e4a051fd4e388090382ffce2a798154e52b9ce1dd7acf5f3d006fca1cbc7`, compilado no GitHub Actions e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.44.0 . O pacote foi conferido por dentro (séries até 800 A, recusa fora da tabela, correções de iluminação/monofásico e HUD), mas **não foi instalado em aparelho físico**; a assinatura é debug/CI.

## 1.42.6 — Correção do pacote Android

O APK **1.42.5** foi publicado sem o `projetista.js`: o painel do projetista abria no Android, mas o módulo não existia no pacote e o recurso não funcionava. A 1.42.6 corrige o workflow de build e adiciona `tests/test_empacotamento.py`, que falha se qualquer script do `index.html` ficar fora do pacote Android ou da lista do Windows. A mesma verificação encontrou `pc.js` e `cad_projeto.js` fora do pacote Android desde versões anteriores (painel PC e reparo/exportação do CAD sem módulo no aparelho); os dois foram incluídos. Use esta versão no lugar da 1.42.5.

O APK **1.42.6** (`jarvis-nova-1.42.6-10426.apk`) tem **81273094 bytes** e SHA-256 `e0eae803b9d73de2207cfab52dd398bd5ce7eca19fb189eb67dd3a3f3c0b014d`, compilado no GitHub Actions e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.42.6 . Conferido por dentro: `projetista.js`, `pc.js` e `cad_projeto.js` presentes em `assets/public`. Ele **não foi instalado em aparelho físico** — toque, arrastar, microfone no aparelho e desempenho no Poco X7 seguem sem validação física, e o APK é assinado em debug/CI.

## 1.42.5 — Projetista elétrico editável

O painel **Arquivos ▸ Projetista elétrico** monta o circuito a partir de um pedido em português: partida direta, reversão, estrela-triângulo, compensadora, comando com selo, iluminação e CLP de nível. O projeto vem com componentes, pinos, fios numerados, sequência de operação e verificação estrutural (curto, terminal solto, bobina sem alimentação, falta de proteção, falta de intertravamento), com correção do que o motor sabe corrigir e relatório que separa o que foi verificado do que **não** foi.

Projetos existentes podem ser modificados (temporizador, remoção de componente, proteção, tensão de comando e troca de topologia), com histórico de versões, restauração e comparação estrutural. A vista usa símbolos IEC por tipo e os pinos podem ser religados tocando neles; o mesmo projetista responde no chat e na voz ("projetista: crie uma partida direta de 5 CV..."). O arquivo é o formato próprio `ProjetistaEletrico CAD` v1. O `.cad` nativo do CADeSIMU é proprietário: não é gerado nem aberto, e a simulação elétrica não é executada no aplicativo. Detalhes em [docs/PROJETISTA-ELETRICO.md](docs/PROJETISTA-ELETRICO.md).

## 1.42.4 — Editor de circuito no palco

O painel **Arquivos ▸ Montar circuito** virou editor: o palco desenha símbolos, terminais e fios. Arraste um componente para mover (a posição vai para o `.cad`), toque em dois terminais para ligar, toque no componente para selecionar e **Aplicar edição** (id/valor) ou **Apagar selecionado**. **Carregar .cad salvo** traz de volta o circuito do cofre para continuar editando.

Ressalva mantida: o formato é o **`CadSimu CAD` v1** deste projeto, com `x`/`y` opcionais; o `.cad` nativo do CADeSIMU é proprietário e **não** é gerado. A netlist continua servindo de entrada para simuladores de PC, e o celular não simula eletricamente.

O APK 1.42.4 tem **81222586 bytes** e SHA-256 `d0a331d65c704ec0c2d52d3007f8bf1d857b396680286f0898817cb70ee1eada`, compilado no GitHub Actions e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.42.4. Ele **não foi instalado em aparelho físico**: toque real, arrastar com o dedo e desempenho no Poco X7 continuam sem validação física.

## 1.42.3 — Montar circuito na interface e perguntar sobre a imagem

O painel **Arquivos** ganhou a seção **Montar circuito**: escolha o componente, informe id e valor, ligue os terminais (`V1.1` ↔ `R1.1`), valide, veja a netlist e salve o `.cad` — sem escrever JSON. O arquivo salvo leva a placa de 120×80×2 mm como geometria e o circuito validado; o cofre, a análise e o download continuam os mesmos.

Sobre o CADeSIMU, com transparência: o formato gravado é o **`CadSimu CAD` v1** documentado neste projeto (`docs/CAD-CIRCUITOS.md`). O `.cad` nativo do CADeSIMU é proprietário e **não** é gerado; a netlist é texto para simulador de PC. Isso está escrito no próprio painel, não escondido.

Na **Visão**, depois de qualquer análise, o campo **Perguntar sobre a análise** deixa você questionar a mesma imagem (“quantas portas aparecem?”) sem abrir a câmera de novo. A resposta entra no texto da análise e é falada.

O APK 1.42.3 tem **81218070 bytes** e SHA-256 `ca9803324a2cd919463d13719074a470d4ea9405e93b431ed23535ef62f90ffe`; foi compilado no GitHub Actions (JDK 21/Android SDK 35) e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.42.3, junto dos instaladores Windows `J.A.R.V.I.S.Nova.1.42.3.exe` e `Setup`. Ele **não foi instalado em aparelho físico**: microfone real, wake word, segundo plano e desempenho no Poco X7 continuam sem validação física.

## 1.42.2 — Circuitos elétricos no .cad e fluidez

O `.cad` agora aceita uma seção opcional de circuito elétrico: componentes com terminais, conexões entre terminais (`R1.1`), validação de verdade (id repetido, terminal inexistente, curto na fonte, componente solto, LED sem resistor, circuito sem fonte) e netlist pronta para o PC. Arquivos antigos continuam abrindo. O passo a passo e o exemplo estão em `docs/CAD-CIRCUITOS.md`.

O aplicativo também ficou mais leve: a busca da memória não re-renderiza a cada tecla, a vigilância da interface e as atividades do painel param com o app oculto, e os desfoques de fundo caros saíram dos chips e das mensagens. É ajuste medido no código e nos testes; o ganho em aparelho físico ainda não foi medido aqui.

O APK 1.42.2 tem **81.212.410 bytes** (81.212.410) e SHA-256 `e6b796a09bb10fb908c9efb3f7a59d683400e97a1a5d9181a9659d9929d97632`; foi compilado pelo release workflow com JDK 21/Android SDK 35 e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.42.2. O release também traz os instaladores Windows (`J.A.R.V.I.S.Nova.1.42.2.exe` e `Setup`). Ele **não foi instalado em aparelho físico**: microfone real, wake word, segundo plano e desempenho no Poco X7 continuam sem validação física.

## 1.42.1 — Auditoria de botões e correções honestas

Esta revisão varreu a interface inteira com clique de verdade (jsdom), não só leitura de código: 300 botões, 239 medidos depois de abrir cada painel e cada aba de Ajustes, zero exceções de clique. Dos 15 cliques que não mudavam nada, 13 eram comportamento correto (seletor de arquivo, atualização idempotente, aba já ativa, painel já aberto) e 2 eram falha: “Liberar memória” da voz neural ficava mudo sem o plugin JarvisVoz, e o microfone do núcleo voltava ao repouso sem explicar quando o ambiente não tem gravação. Os dois agora respondem com mensagem e têm teste de regressão (`tests/test_botoes_honestos.js`).

Também passaram a valer verificações novas em toda a rodada: toda ação das áreas tem caso no roteador de navegação, o HTML não tem IDs duplicados nem rótulos quebrados, e não existe `href="#"`, `onclick` inline ou handler vazio. Nada foi removido ou simulado; as funções, a identidade e o núcleo 3D seguem intactos.

O APK 1.42.1 tem **81.209.170 bytes** (81.209.170) e SHA-256 `506ee0a5c45919f095942f91b496a1fad1c00bc6c99038d15f730d68502ae013`; foi compilado pelo release workflow com JDK 21/Android SDK 35 e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.42.1. O release também traz os instaladores Windows (`J.A.R.V.I.S.Nova.1.42.1.exe` e `Setup`). Ele **não foi instalado em aparelho físico**: microfone real, wake word, toque, segundo plano, câmera e desempenho no Poco X7 continuam sem validação física.

## 1.42.0 — Voz: VAD/WAV, motor STT selecionável e métricas

Esta revisão fecha os problemas encontrados no caminho real de comando. A captura normal passou a usar o VAD testável e WAV PCM, com teto de 20 s, reamostragem para 16 kHz e aplicação dos controles de eco, supressão de ruído, AGC e filtro. O usuário escolhe entre Automático, Groq, Android e Android local; o fallback Android não acontece mais quando o motor Groq foi selecionado, e um parcial contendo apenas “Jarvis” não consome a ativação antes do comando.

O diagnóstico registra duração do áudio, bytes enviados, captura média e upload médio. O APK 1.42.0 tem **81,209,022 bytes** (81.209.022) e SHA-256 `f9b9adf6a55a35c59a6939971322f3fcbcbe76740342e30589b46074a7348455`; foi compilado pelo release workflow com JDK 21/Android SDK 35 e publicado em https://github.com/erossilva-byte/JARVIS-0.3.1/releases/tag/v1.42.0. Ele **não foi instalado em aparelho físico**: instalação, microfone, wake word, TTS, câmera, segundo plano, desempenho no Poco X7 e precisão acústica em PT-BR continuam sem validação física.

## 1.41.0 — Voz PT-BR: confiança, filtros, replay e diagnóstico

Esta revisão ataca o caminho real de voz, não só a interface. O reconhecedor do Android agora devolve a confiança e até cinco hipóteses alternativas; o app usa esses sinais para recusar comandos de ação abaixo de 45% e pedir repetição, sem inventar confiança quando o motor não a fornece. O Whisper da Groq continua sendo o motor de maior qualidade quando há chave e rede; o Android local/online continua sendo o fallback.

A captura normal ganhou um filtro high-pass de 85 Hz e um compressor suave antes do `MediaRecorder`; o perfil de locutor usa a mesma cadeia. O centroide do perfil passou a ponderar as amostras por SNR e duração, e um indício de reprodução agora impede a confirmação de identidade em vez de ser apenas exibido. Quando o WebView não oferece `MediaRecorder`, um caminho WAV PCM de emergência usa o VAD já existente.

Em Ajustes ▸ Voz há um teste de transcrição: você digita a frase esperada, grava, e o app mostra o reconhecido, o acerto por palavra (WER), a latência real e a confiança quando disponível. O histórico fica local e pode ser apagado. Não há taxa de acerto de campo nesta revisão: a suíte prova o contrato e o cálculo, não a acústica do seu aparelho.

O APK 1.41.0 tem **81.220.373 bytes** e SHA-256 `d05aab92eb158a27e50fcd249dc2ff64e89927aa8167371b07acc787e0b32953`; é debug/CI, compilado com Android SDK 35, build-tools 35.0.0, JDK 21 e Gradle 8.9. Os assets foram conferidos dentro do pacote: `app.js` com `VERSAO_APP = '1.41.0'`, `fala.js` 1.1.0, `audio_pcm.js` e `index.html` com os controles novos. O `aapt` confirma `com.jarvis.nova`, versionCode 10410, minSdk 26, targetSdk 34. Ele **não foi instalado em aparelho físico**; instalação, microfone, wake word, TTS, câmera, segundo plano e desempenho continuam sem validação física nesta máquina. A instalação, o microfone físico, a wake word, o TTS, a câmera, o segundo plano e o desempenho no Poco X7 continuam **sem validação física** nesta máquina.

## 1.40.0 — Núcleo protagonista, áreas corrigidas e abertura limpa

Esta revisão coloca o núcleo no centro do menu e remove a opção independente **Conversa**. O chat, o histórico, a transcrição, o microfone, os comandos digitados e as respostas faladas continuam funcionando; a transcrição virou uma tela secundária, aberta pelo botão próprio, pelo cartão de última resposta ou pelo cartão de acessos.

As **Áreas** foram corrigidas na origem: o `<body>` recebia `data-modo` e a delegação tratava qualquer clique como troca de modo, retornando antes da ação. O seletor agora aceita somente `.modo-btn[data-modo]`, o cartão tem listener direto e o clique em nó de texto da WebView sobe para o elemento. Os 10 cartões e as 44 ações são exercitados por `tests/test_interface_dom.js` (80 verificações em jsdom).

O **flash de abertura** vinha de `#boot` começar oculto, do menu aparecer e de o boot só iniciar 700 ms depois; o bloqueio ainda era aberto 520 ms depois de o boot sumir. Agora o boot nasce visível, o corpo nasce travado, o boot roda no primeiro ciclo e o bloqueio é montado antes de liberar o corpo.

Preservados Obsidian, bloqueio opcional, provedores, humor, voz, pessoas, perfis, memória, executores e confirmações. O APK 1.40.0 tem 81.404.118 bytes e SHA-256 `307245cfcde586f92dc4122d24a539996ad7be8afe237226da075b0c6796dffb`; é debug/CI e os assets foram conferidos dentro do pacote (app.js 1.40.0, index.html 1.40.0 e a correção de `.modo-btn[data-modo]`). Ele não foi instalado em aparelho físico. A instalação, o toque real no WebView, o microfone, a wake word, o TTS, a câmera, o segundo plano e o desempenho no Poco X7 continuam **sem validação física** nesta máquina.

## 1.39.0 — Raciocínio em etapas e personalidade adaptativa

Esta revisão acrescenta uma camada cognitiva determinística antes e depois da IA. Ela identifica intenção, complexidade, pressa, assunto sensível, referências e necessidade de pesquisa, cálculo ou ferramenta; monta um plano interno de cinco etapas; seleciona o histórico relevante; e verifica/revisa a fala contra respostas vazias, aberturas genéricas, repetição e alegação de execução não feita.

A personalidade ganhou três controles persistidos em Ajustes ▸ IA: profundidade, iniciativa e comportamento conversacional. Os três níveis de humor e os seis eixos existentes foram preservados. O Hermes, o Core, o catálogo de ferramentas, as confirmações, a memória, a voz, o avatar e o núcleo 3D não foram substituídos.

O módulo e os testes estão em `cognicao.js`, `tests/test_cognicao.js` e `tests/test_v1_39_0.py`; a arquitetura e as limitações estão em `docs/COGNICAO-1.39.0.md`. O APK 1.39.0 tem 81.202.290 bytes e SHA-256 `39341a23fc2bf16680ee89b74b9109799d6b08669755e53695a9241c81f3bcce`; é debug/CI, assinado com a chave de CI, e não foi instalado em aparelho físico.

## 1.38.1 — Auditoria corretiva

Esta revisão corrige quatro defeitos encontrados na auditoria: uma tarefa cancelada durante a última etapa podia terminar como concluída; a Visão 2.0 tinha declarações antigas duplicadas e não limpava a análise ao reabrir; a preparação de algumas ações podia lançar exceção sem resposta; e o gerador de senha usava módulo tendencioso. O roteador de IA também passou a descartar IDs de provedor desconhecidos. Não há recurso novo nem remoção de funcionalidade.

O APK 1.38.1 tem 81.195.283 bytes e SHA-256 `28a87cb3ec4eaa6d890047406c481190ff8868d080391ce679a0cf832ca8af5b`; é debug/CI e está descrito abaixo; a instalação, o microfone, a câmera, a acessibilidade, o segundo plano e o avatar em tela real continuam pendentes de validação no Poco X7. Esta é uma correção de engenharia, não uma declaração de teste de campo.

## 1.38.0 — Avatar 3D, plano persistente e executores

Esta revisão acrescenta um **avatar holográfico procedural** escolhível em Aparência do núcleo, desenhado localmente com Three.js e fallback em Canvas 2D. Os olhos piscam e a boca abre conforme a **amplitude real** da fala ou do microfone; não há modelo facial baixado nem visemas por fonema, e a interface diz isso.

O comando “planeje …” agora converte o plano validado em uma **tarefa persistente** do Sistema. Cada etapa tem checkpoint, pausa e retomada sem repetir etapa concluída; a etapa interna não pede confirmação duplicada, mas a ação real continua passando pelo `executarSeguro`. O Core ganhou executores de leitura para **voz**, **automação**, **atualização** e **planejamento**.

A auditoria de IA e o inventário do repertório estão em `docs/IA-1.38.0.md` e `docs/REPERTORIO-1.38.0.md`. O APK 1.38.0 foi compilado e conferido por hash/aapt (81196059 bytes; SHA-256 `3fbe237a672eca13f308a266c86e0503d13ddcfa54fdd4e75308bb0b8cae27ba`); **não foi instalado nem executado em aparelho físico nesta máquina**. Instalação, microfone, wake word, acessibilidade, segundo plano, notificações e avatar em tela real continuam pendentes de validação no Poco X7. Voz, câmera, Windows, ESP32/Home Assistant e inferência com chave/modelo reais não foram simulados.

## 1.37.0 — Retomada segura e pausa

Uma tarefa pausada por efeito incerto agora continua **sem reexecutar** a etapa que pode já ter sido disparada. Também é possível pausar manualmente entre etapas: a ferramenta em curso termina, mas a próxima não começa, e o checkpoint permanece. A tela de tarefas descreve corretamente o lembrete de prazo às 09:00 no Android.

Pausa não é cancelamento: ela não interrompe um efeito já iniciado. Voz, câmera, wake word, notificações, Windows, ESP32/Home Assistant e instalação em aparelho continuam dependendo de validação física.

## 1.36.0 — Aprendizado explícito

Esta revisão adiciona um módulo local de aprendizado que só registra instruções claras do usuário (“prefiro”, “evite”, “lembre”, “corrija”). Tudo é revisável em Memória, pode ser removido, desfeito, exportado ou apagado, e conteúdo sensível é recusado. O aprendizado entra no prompt como preferência de estilo, nunca como autorização para contornar segurança, permissões ou confirmações.

Aprendizado automático de hábitos, permissões por pessoa, canal autenticado Android↔Windows, ESP32/Home Assistant e reformulação visual completa continuam pendentes e não foram simulados.

## 1.35.0 — Confiabilidade, autodiagnóstico e recuperação

Esta revisão fortalece o Core sem remover a 1.34.0. Falhas agora têm causa provável, evidência e orientação; a delegação faz pré-checagem de dependências; componentes podem declarar uma recuperação segura, executada com timeout, rechecagem, espera e limite de tentativas. O automático só ocorre quando o próprio componente autoriza. Nada reinicia serviços Android nem contorna permissões.

O diagnóstico integrado mostra o Core, e o painel do Core mostra o histórico de recuperação. RAM JavaScript e bateria só aparecem quando a WebView fornece o dado; o uso de CPU não é inventado. A validação em aparelho físico, microfone, câmera, acessibilidade real, segundo plano, RAM, bateria e instalação continua pendente.

## 1.34.0 — Core, agentes e contexto

Esta revisão acrescenta o **JARVIS Core** sem remover a camada de áreas da 1.33.0. O Core registra 12 agentes descritivos, escolhe o agente por sinais explícitos, mantém último pedido/agente/decisões, gerencia projetos e tarefas e verifica resultados de forma conservadora. Sem executor registrado, a delegação devolve `nao_configurado` e não finge execução. O painel mostra status, agentes, projetos, saúde e habilidades; o watchdog diagnostica sem reiniciar serviços em loop.

O APK 1.34.0 mantém a instalação por cima quando usa a mesma assinatura de CI. A validação em aparelho físico, microfone, câmera, acessibilidade real, RAM, bateria e instalação continua pendente. MCP remoto, RAG vetorial, tutorial, visão de tela ampla, pareamento PC/TV/ESP32 e atualização modular não foram implementados; a classificação completa está em `docs/EVOLUCAO-1.34.0.md`.

## 1.33.0 — Auditoria, áreas e reconstrução da experiência

Esta revisão audita os 13 tópicos da evolução, organiza a interface em dez áreas, cria quatro modos de uso persistentes, conecta atividades reais à página inicial e faz o núcleo 3D reagir à execução de ferramentas. A auditoria completa está em `docs/AUDITORIA-1.33.0.md`; a limpeza está em `docs/LIMPEZA-1.33.0.md`. O APK 1.33.0 foi gerado e verificado por dentro; a instalação em aparelho físico continua pendente. O APK 1.32.0 permanece como referência.

## 1.32.0 — Núcleo operacional, ferramentas e acessibilidade

O `sistema.js` adiciona um catálogo de ferramentas com permissões, traces, tarefas com checkpoint e detecção de
injeção. A voz resolve calculadora, conversão, senha e status do núcleo sem chamar a nuvem. A nova central
**Sistema** mostra tudo isso. No Android, um AccessibilityService opt-in permite ler a tela, clicar por texto,
digitar, rolar e esperar — sempre com confirmação, campos de senha omitidos e botão **Parar tudo**.

O microfone ganhou seleção de entrada e um diagnóstico de 1,2 s que mede nível, ruído, pico e clipes sem gravar.
O que não foi possível validar aqui: aparelho físico, microfone real, wake word em segundo plano, TTS, automação
de UI e instalação do APK. O relatório de rastreabilidade está em `docs/AUDITORIA-1.33.0.md`.

## 1.31.2 — Consentimento e coerência

A confirmação de um plano agora mostra os **argumentos** de cada etapa (destinatário, texto, caminho), não só o nome da ação.
O resumo sem argumentos continua sendo usado em registros e testes. Também corrigi o texto de humor que dizia 70% quando o
padrão real sempre foi 90%.

## 1.31.1 — Correção de leitura

Uma consulta que responde “não encontrei” ou “sem permissão” não é mais tratada como efeito confirmado. A marcação
otimista de leitura agora perde para o texto de falha, e notificações/verificação de arquivo voltam a ficar `incerto`
em vez de `ok`. Isso evita que um plano avance sobre uma consulta que, na prática, não devolveu o dado.

## 1.31.0 — Planos multi-etapas supervisionados

Peça “planeje organizar minha tarde” (ou outro objetivo) e o app monta um plano de até seis etapas usando apenas
ferramentas que existem naquele aparelho. O plano é mostrado antes de executar e só começa depois da sua confirmação.

Cada etapa usa o recibo da 1.30.0. Se o efeito for confirmado, o plano avança. Se ficar **incerto** — por exemplo,
“abri o aplicativo” sem confirmação de que ele abriu —, o plano **pausa** e pergunta se você quer seguir. Falha,
bloqueio de segurança ou cancelamento interrompem o restante; nenhuma etapa seguinte roda escondida.

As ações continuam passando pelo `executarSeguro`, então risco, PIN, modo seguro, offline e confirmações sensíveis
seguem valendo. “Status do plano” mostra o resultado e “cancelar plano” interrompe o que estiver em curso.

**Limitação:** o planejamento depende do provedor de IA configurado. Sem chave e sem modelo local, o app informa que
não conseguiu montar o plano; não inventa etapas. A confirmação de efeito continua limitada ao que cada adaptador
Android devolve.

## 1.30.0 — Agentes especializados e recibos de execução

Toda ferramenta agora passa por um **recibo**: o app registra qual agente executou, quanto tempo levou e, principalmente,
se o **efeito foi confirmado**. Abrir um aplicativo, preparar uma mensagem ou solicitar uma chamada deixa o recibo como
**incerto** — ação disparada não é o mesmo que tarefa concluída. Falhas, bloqueios por segurança/offline e cancelamentos
também ficam registrados. O diagnóstico mostra a taxa de verificação e a distribuição dos estados.

O registro é deliberadamente mínimo: guarda o nome da ação e as **chaves** dos argumentos, nunca o texto da mensagem, o
telefone, o caminho do arquivo ou o conteúdo da memória. Os 80 recibos mais recentes ficam no armazenamento local.

Nove agentes classificam as ferramentas: conversa, pesquisa, dispositivo, arquivos, memória, pessoas, visão, computador e
sistema. Isso organiza a expansão futura sem substituir o roteamento do Hermes nem as habilidades existentes.

**Limitação:** a confirmação de efeito depende do que cada adaptador nativo devolve. Onde o Android só permite abrir um
app ou preparar uma mensagem, o recibo permanece honestamente **incerto**; não há como afirmar que o usuário concluiu a
ação sem uma API de leitura do estado final.

## 1.29.0 — Captura de fala e análise de referências

A captura de voz parou de gravar quatro segundos fixos. Um VAD local mantém **600 ms de pré-roll**, aprende o ruído da sala,
confirma fala com 160 ms de energia e encerra após 1,2 s de silêncio, com teto de segurança. Na prática: a primeira sílaba
não é cortada, o microfone fica aberto menos tempo e a resposta chega mais rápido. Vale para o cadastro de voz das pessoas,
a verificação na ativação e o teste de microfone.

O relatório `docs/ANALISE-REFERENCIAS.md` compara os oito repositórios pedidos — arquitetura Android, voz, segundo plano,
automação, interface, memória, agentes e licenças — e separa o que é adotável do que é apenas referência. Nenhum código foi
copiado; as ideias foram reimplementadas no núcleo próprio.

**Limitação:** sem microfone ou aparelho aqui, o VAD foi validado com sinais sintéticos. A naturalidade e os falsos positivos
em campo precisam ser medidos no Poco X7.

## 1.28.0 — Identificação de Pessoas

A aba **Pessoas** virou um sistema de identificação. Cada perfil tem foto com recorte (galeria ou câmera),
nome, apelido, nascimento com idade calculada, altura, profissão, relação, telefone, e-mail, endereço, cidade,
descrição, preferências, interesses, observações, contexto e até 12 campos personalizados.

**Voz por pessoa:** três a oito amostras guiadas passam pelo motor local (VAD, FFT/mel, pitch, formantes,
prosódia) e viram um vetor de 59 dimensões. Áudio curto, ruidoso ou saturado é recusado e o áudio bruto nunca
é guardado. A identificação compara todos os perfis autorizados com limiar e margem e responde **identificado**,
**não identificado** ou **inconclusivo** — uma voz desconhecida nunca é associada a um cadastro por chute.

**Privacidade:** consentimento separado e revogável para voz e referência visual; vetores cifrados em repouso
com AES-GCM (chave local, não Keystore); telefone, e-mail, endereço e biometria ficam fora do prompt da IA;
exportação sem biometria; histórico de alterações; exclusão de perfil apaga as referências. A referência
visual opcional usa hash de imagem e é declarada como semelhança, nunca prova de identidade.

**Configurações:** aba **Identificação** com ativar/desativar voz e rosto, limiar (mínimo seguro de 68%),
margem, qualidade mínima de fala e SNR, teste de microfone, teste de reconhecimento, gerenciamento de perfis
e exclusão de toda a biometria. O cadastro anterior é migrado na primeira abertura.

**Integração:** “quem está falando”, “quem é a Bia”, “quais pessoas estão cadastradas”, “identifique essa
pessoa” e “adicione uma nova pessoa” passam pelo cadastro real; a voz reconhecida na ativação entra no
contexto com os campos permitidos. Nada é alterado por suposição.

**Limitação honesta:** este ambiente não tem microfone, câmera nem aparelho. A captura real, a naturalidade
com vozes humanas e os falsos positivos em campo não foram medidos; os testes de voz usam sinais sintéticos.

## 1.26.0 — Reconhecimento de locutor

A voz do usuário agora tem um motor local de verdade: VAD, pitch, formantes e um vetor de 59 dimensões,
com cadastro guiado em três frases, consentimento, limiar ajustável e até cinco perfis. O resultado é
**compatível**, **diferente** ou **inconclusivo** — é indicação de locutor, não autenticação. O áudio
bruto nunca é guardado. A captura permite cancelamento de eco, supressão de ruído e AGC.


## 1.25.0 — Desenvolvimento de Arquivos

A aba **Dev. Arquivos** recebe texto, código e projetos `.zip`, analisa o conjunto (JSON, importações, duplicatas,
segredos, conflitos) e gera arquivos reais (PDF, DOCX, XLSX, CSV, JSON e ZIP). Correções mantêm o original na sessão,
e o histórico guarda as últimas operações. A comparação de voz agora responde **compatível**, **diferente** ou
**inconclusivo** — é indicação de timbre, não autenticação.


## O que mudou na 1.24.0

- **IA local corrigida na causa**: o runtime MediaPipe subiu de `0.10.14` para **`0.10.24`**. A versão antiga
  não entende Gemma 3 e abortava o processo ao abrir o `.task` — era isso que fechava o app ao testar ou enviar
  mensagem, embora o mesmo modelo abrisse no Google AI Edge Gallery.
- **Prompt dentro do contexto**: o modelo tem 2048 tokens e recebia o prompt completo da nuvem. Agora o caminho
  local usa persona condensada, histórico curto e teto de 6000 caracteres, com erro claro se passar.
- **Sem fechar a engine no meio da geração**: o `onDestroy` agenda o fechamento na mesma thread da inferência;
  respostas voltam para a UI thread; backend em CPU, sem delegate GPU.
- **Estados honestos**: importado ≠ validado ≠ testado ≠ pronto; "Testar modelo" mostra o tempo real e só então
  o status vira PRONTO. Novo botão **Descarregar** libera a RAM sem apagar o arquivo; GGUF renomeado é recusado
  antes de tocar no código nativo.

## O que mudou na 1.23.1

- **Erro de inicialização corrigido**: `store is not defined` não aparece mais; a opção de reduzir efeitos
  voltou a funcionar e fica salva.
- **Diagnóstico legível**: nome e etiqueta na horizontal, com quebra natural em telas estreitas.
- **Anexos no chat**: clipe no rodapé para escolher arquivos (Android e Windows), lista com nome, tipo e
  tamanho, remoção antes do envio e conteúdo de texto entregue à IA junto do pedido.
- **Ainda não incluído**: `.cad` do CADe SIMU, automação de janelas do Windows e alarme do Windows.

## O que mudou na 1.23.0

- **Visual holográfico com profundidade real**: o núcleo em HUD tem camadas em planos diferentes e inclina
  com o ponteiro; painéis entram em perspectiva e os cartões compartilham o mesmo vidro com brilho e elevação.
- **Transições e retorno ao toque consistentes**: entrada de painéis, dissolve do fundo, botões que afundam,
  varredura no carregamento e confirmação/alerta no diagnóstico — sempre ligados ao estado real.
- **Reduzir efeitos visuais**: opção em Ajustes ▸ Voz que desliga tilt, brilhos e animações longas, salva no
  aparelho; o app também respeita a redução de movimento do sistema.
- **Nada foi removido**: telas, funções, permissões e integrações continuam iguais; os três estilos de núcleo
  (HUD, plasma e órbita 3D) seguem disponíveis.

## O que mudou na 1.22.0

- **Visão 2.0**: balões sem sobreposição com linha-guia, texto copiável, imagem da galeria e
  análise de vídeo por quadros com timestamp, progresso e cancelamento. Tocar num balão corta a
  fala em curso antes de ler o detalhe.
- **Pessoas**: perfis locais separados, com busca, ambiguidade respondida por pergunta e
  exportação JSON. Nada de biometria; o contato não vai para a IA.
- **Diagnóstico** confere os dois módulos novos no pacote.
- **Testes**: `test_visao_nova.js`, `test_pessoas.js` e `test_v1_22_0.py` na suíte `npm run test:all`.

## O que mudou na 1.21.5

- **Cofre do Obsidian em um só lugar**: o bloco estava fora de qualquer aba (seção sem categoria), por isso
  não aparecia em Ajustes ▸ Memória. Agora é um cartão único na aba Memória, com selo de estado, escolha de
  pasta pelo seletor do sistema e **sem campo de caminho duplicado**.
- **Diagnóstico por área**: seis grupos com contagem e pior estado, detalhes técnicos recolhíveis e atalho
  para o registro de erros.
- **Animações unificadas**: um sistema de tempos e curvas para seções, painéis, abas, cartões e diagnóstico,
  com `prefers-reduced-motion` desligando tudo.
- **Modelos `.task`**: links oficiais verificados na aba IA e em `MODELOS-IA-LOCAL.md`.

## O que mudou na 1.21.4

- **Obsidian onde você procura**: a conexão com o cofre agora fica em **Ajustes ▸ Memória**, junto da memória
  pessoal — escolher pasta, testar vínculo, enviar/trazer notas por tópico e desconectar. A aba consulta o
  estado real do cofre ao abrir, e o painel Memória aponta para ela.
- **Diagnóstico** ganhou a verificação de **erros recentes** (últimas 24 h) lida do registro do app.
- **Tela de bloqueio** com ajuste moderado de escala, iluminação e espaçamento.

## O que mudou na 1.21.3

- **Tela de bloqueio holográfica**: núcleo com quatro arcos animados, varredura, grade de fundo, relógio e
  data ao vivo, estado do sistema, pontos de PIN e tremor no erro. Continua opcional, mantém hash SHA-256 do
  PIN, biometria do aparelho e código de recuperação, e respeita “reduzir movimento”.
- **Diagnóstico de verdade**: sete estados (Operacional, Aviso, Falha, Não configurado, Desativado, Não
  aplicável, Não verificado), com impacto, orientação, atalho para o ajuste e horário por item; resumo no topo.
- Novas checagens: módulos carregados do pacote, identidade do app em execução, persistência (grava, lê e
  apaga), configurações salvas, cofre do Obsidian, rotinas e serviço de escuta em segundo plano.

## O que mudou na 1.21.2

- **Auditoria de runtime**: o app foi carregado em DOM real (jsdom) na mesma ordem do APK, com as 12 abas
  percorridas e os 167 botões clicados. Nenhuma exceção, promessa rejeitada ou botão inerte no caminho exercitado.
- **Correção**: apagar uma chave de API falhava em silêncio quando o cofre seguro não existia (o clique gerava
  promessa rejeitada sem tratamento). Agora a falha é avisada no chat e registrada no log de ações.
- **Correção**: `package-lock.json` estava dessincronizado do `package.json` e `npm ci` recusava instalar.
  O lockfile foi regenerado sem trocar versões declaradas.

## O que mudou na 1.19.1

- **Modo Visão acessível de verdade.** O painel existia, mas a aba ficava na barra lateral, que é `display:none`
  abaixo de 960 px — no celular só dava para abrir por voz. Agora ele tem **aba na barra lateral**, **ícone de olho
  no cabeçalho** (mesmo componente de Tarefas e Configurações) e **atalho no card CONVERSA E INFORMAÇÕES**; qualquer
  caminho marca a aba como ativa. O teste da versão exige os três pontos.

## O que mudou na 1.19.0

- **Módulo CAD de intercâmbio (real, não simulado).** `cad.js` passou a ter uma malha única (`malha()`) e exportadores/leitores
  para **DXF R12** (planta em linhas + faces 3D), **STL** binário e ASCII, **3MF** (ZIP+XML), **STEP AP203** (sólido facetado)
  e **IFC4** (projeto, sítio, edifício, pavimento e elementos extrudados). Cada escritor **reabre o próprio arquivo** antes de
  entregar e informa avisos e perdas da conversão; DWG, RVT, RFA e FCStd são recusados com motivo (binário proprietário ou
  dependência do FreeCAD), em vez de produzir um arquivo que não abre.
- **Visão com sessão.** Frequência de 4/8/15 s, pausar/retomar, encerrar ao sair da tela, troca de câmera frontal/traseira e
  captura da tela do PC no computador. Um quadro por análise, nada gravado, nada em segundo plano; o resumo pode ser salvo na memória.
- **Obsidian conectado.** Notas exportadas como `.md` com frontmatter (um arquivo por nota) e vínculo com uma pasta real de cofre
  no computador — escrita idempotente, sem apagar nada. No Android o caminho é o pacote `.md`, porque o Obsidian não abre pastas do app.
- **Organização por plataforma.** `main.js` e `preload.js` saíram da raiz para `platforms/desktop/`; o núcleo web continua
  compartilhado na raiz e as fronteiras estão documentadas em `platforms/LEIA-ME.md`.
- **Bugs achados pelos próprios testes numéricos:** faces laterais do cilindro/cone nasciam invertidas (volume 67% e 100% errado)
  e os pólos da esfera/ápice do cone geravam vértices duplicados; a correção é orientação por volume assinado e fusão de coincidentes.


# J.A.R.V.I.S. Nova 1.18.0

Esta versão (1.18.0) conserta o Núcleo 3D no celular e no PC: o tamanho das partículas estava
~46x maior do que devia e saturava a tela em branco; agora o desenho respeita o pixel ratio, tem máscara
circular, recupera o contexto WebGL perdido e recalcula o tamanho quando o painel abre ou o aparelho gira.

Esta versão também corrige o erro “instancia.nivel is not a function” no núcleo 3D e permite criar e analisar arquivos `.cad` do CadSimu (formato documentado, validação com mensagens claras e cofre local).

Esta versão (1.17.0) leva o núcleo Órbita para 3D real, com partículas em shader e anéis na GPU, animação por delta time e fallback para Canvas 2D — mantendo a correção do crash do serviço em primeiro plano, a memória conectada, o humor brasileiro em três níveis e o adaptador multiplataforma.

Esta versão (1.16.0) corrige o crash do serviço em primeiro plano, acrescenta o núcleo Órbita, a memória conectada estilo Obsidian, o humor brasileiro em três níveis e o adaptador multiplataforma com controle do computador.

Esta versão (1.15.0) acrescenta o **estilo de núcleo em plasma** — um anel de energia irregular com
animação própria, no desenho da imagem de referência — escolhido em **Ajustes ▸ Voz ▸ Aparência do
núcleo**, ao lado do HUD técnico que continua sendo o padrão. A troca vale na hora, fica salva e a
abertura nasce com o mesmo estilo. A animação reage ao nível do microfone (como as ondas de voz),
pausa com a tela fora de vista e respeita “reduzir movimento” do sistema.


Esta versão (1.14.0) acrescenta a **escuta contínua pela transcrição da Groq** (opcional, com o app
aberto) ao detector próprio que já funcionava em segundo plano, o **menu Informações** com dados do
aparelho, clima e manchetes, a **conversa em tela própria** com o histórico inteiro e rolagem
correta, o fim das **mensagens e falas duplicadas** (portão de eco único no núcleo) e um **conjunto
de animações** que se combina entre as telas (verificação do sistema, ondas de voz e transições).

A escuta pela Groq exige a chave da Groq (Ajustes ▸ IA), roda com o aplicativo aberto, consome cota
de transcrição e envia o áudio para fora — ela é desligada por padrão. Em segundo plano quem ouve é
o detector do Android, sem chave e sem enviar áudio. Para ligá-la: Ajustes ▸ Voz ▸ “Ouvir pela
transcrição da Groq”. O botão “Testar a transcrição da Groq” grava 2,5 s, transcreve e diz se a
palavra de ativação foi reconhecida, sem executar nenhum comando.



## Novidades da 1.13.0 — detector próprio, motor roteado e visão pela câmera
- **Picovoice saiu do projeto.** Não há mais SDK de palavra de ativação, AccessKey nem
  dependência de terceiro para ouvir. A ativação é um **detector próprio**: o reconhecimento do
  Android transcreve em sessões curtas e as regras de fonética locais decidem — 26 variantes
  conhecidas (“javis”, “charvis”, “garvis”, “jarviz”…), tolerância a sotaque por distância de
  edição, comparação pelo esqueleto consonantal e tolerância que só vale para palavras da
  família “jarv-” (é o que impede “jardim” e “jargão” de acordar o assistente). As mesmas regras
  rodam no serviço (`JarvisAtivacao.java`) e no WebView (`Hermes.ativacao`), conferidas por teste.
- **Calibragem na mão do usuário.** Slider de sensibilidade (0–100) e campo de palavras extras
  (“nova”, um apelido, o seu jeito de falar). Mais sensível = aceita resultado parcial e responde
  antes de a frase terminar; menos sensível = exige a palavra quase perfeita, melhor com televisão
  ligada. Há ainda o **porteiro de ruído** por nível de áudio: transcrição que aparece com o som
  baixo demais é descartada, e o diagnóstico mostra quantas foram descartadas.
- **Roteador de motores de IA no núcleo.** `Hermes.planejarIA()` escolhe entre Groq, Cerebras,
  Mistral e Gemini por tipo de tarefa (conversa curta, raciocínio, pesquisa/atualidade, imagem),
  pela **latência realmente medida** no seu aparelho (média móvel), pelas falhas recentes e pela
  disponibilidade. O segundo colocado da fila é o fallback automático em erro, cota ou tempo
  esgotado, e cada tipo de tarefa tem seu tempo-limite (12 s para pergunta curta).
- **Câmera que reconhece objetos.** O painel **Visão** abre a câmera ao vivo; ao tocar em
  analisar, UM quadro é enviado ao provedor que enxerga imagens e cada objeto reconhecido ganha
  um **balão sobre a própria imagem** — toque no balão para ouvir o detalhe. Nada de vídeo
  contínuo e nada em segundo plano: fechar o painel desliga a câmera. Por voz: “o que você está
  vendo?”.
- **Diagnóstico ampliado.** Além de microfone, voz, IA local, rede e permissões, o diagnóstico
  agora confere **câmera**, **chaves** e **motores de IA** (com a latência medida de cada um e a
  última escolha do roteador). Continua disponível por voz: “verifique o sistema”.
- **Conversa mais legível.** A área de mensagens ganhou balão de carregamento animado (o estado
  explícito entre perguntar e ouvir), espaçamento consistente, melhor contraste e rolagem que não
  puxa a tela enquanto você lê acima.
- **Humor seco documentado.** O prompt de sistema agora descreve o sarcasmo seco, irônico e
  levemente debochado com limites explícitos: nunca rude, nunca sobre pessoas, aparência,
  religião ou tragédia, e suspenso por completo em assunto sensível ou urgente. As frases
  próprias do app ganharam variantes novas (visão sem resultado, troca de motor).
- Versão 1.13.0 (versionCode 10130), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI:
  instala por cima da 1.12.0 e é atualizável pelo próprio app.

## Novidades da 1.12.0 — Hermes no comando do dia
- **Núcleo Hermes Agent.** Toda resposta passa por um motor único, que decide a rota em ordem:
  habilidade própria do núcleo → comando resolvido no aparelho → IA. O núcleo é um arquivo só
  (`hermes.js`), sem DOM: o aplicativo injeta o que ele pode usar. "Bom dia" e os comandos do
  dia a dia deixaram de gastar chamada de IA.
- **Briefing diário.** No primeiro "bom dia" do dia ele fala a **temperatura atual** e as
  **manchetes do momento** (buscadas em paralelo); depois disso cumprimenta curto. Em modo
  offline avisa e não consulta nada.
- **Autodiagnóstico por voz.** "Verifique o sistema" confere núcleo, reconhecimento de voz,
  síntese (incluindo a voz neural, quando baixada), IA local, rede/CORS, chaves e permissão de
  microfone — e responde falando o que passou e o que está pendente.
- **Abertura com reconhecimento de voz.** A animação de inicialização só conclui e libera as
  demais opções do app quando reconhece a sua voz. Sem perfil cadastrado (ou com a conferência
  desligada), roda só a animação inicial. Há botão de continuar sem reconhecer e limite de 25
  segundos: a tela nunca fica presa.
- **Decisão conferida.** Se a IA inventar uma ação que não existe (ou que não funciona nesta
  plataforma), ela é descartada e a fala é ajustada — o assistente não anuncia o que não vai
  fazer.
- **Animação mais fluida.** As camadas do núcleo agora são compostas na GPU e as transições de
  estado usam só `transform`/`opacity`.

Versões anteriores: 1.11.0 (streaming, humor por contexto), 1.10.0 e 1.10.1 (segundo plano), 1.9.0 (voz neural).

## Novidades da 1.11.0 (histórico) — mais rápido e com humor de contexto
- **Resposta em streaming**: a fala começa assim que o texto falado está pronto, sem esperar a IA terminar de gerar o resto. Se o provedor não cooperar, o app volta ao pedido completo sozinho.
- **Menos espera**: a conexão com a IA e o motor de voz são aquecidos enquanto você ainda está falando.
- **Tom do turno**: com pressa ele responde curto e seco; em assunto sensível o humor desaparece.
- **Travamentos corrigidos**: falha ao abrir o microfone não deixa mais o app preso em "ouvindo", e voltar ao primeiro plano religa a ativação na hora.

Versões anteriores: 1.10.0 e 1.10.1 (correções do segundo plano).

## Correções da 1.10.1 — segundo plano estável

Revisão sem funcionalidade nova, só os defeitos que derrubavam ou travavam o serviço:
o player de música não promovia o serviço a primeiro plano (o Android matava o processo
ao pedir "pausar" sem faixa tocando); o alarme rápido do vigia era sobrescrito pelo
periódico; a escuta ficava em "espera" para sempre se o app fosse fechado no meio de um
comando; falha fatal mantinha notificação e primeiro plano eternos; lembretes não eram
restaurados após reiniciar no Android 12+; e interface/serviço discordavam quando o
Android recusava primeiro plano. Detalhes técnicos no `CHANGELOG.md`.

## Destaques da 1.10.0 — obedece de verdade e com personalidade própria

- **Personalidade num só lugar.** `PERSONALIDADE`, no topo do `app.js`, guarda identidade, papel,
  traços, lealdade, tratamento, conversa, humor e limites. O prompt de sistema (nuvem e modelo
  local) é montado a partir dele: mudar o jeito do J.A.R.V.I.S. é editar um bloco. A palavra de
  ativação não depende disso e continua funcionando igual.
- **A voz é analisada em voz alta.** Na ativação ele **fala** “Analisando sua voz, senhor. Um
  instante.”, grava 4 s depois da própria fala e compara com o perfil salvo — já vem ligada para quem tem perfil cadastrado. A conferência é
  exigida **uma vez por sessão** (primeiro acesso e depois de ligar o celular); há um seletor
  “Quando conferir a voz” para quem preferir em toda ativação.
- **“Ligue para X” completa a chamada.** `ACTION_CALL` com a permissão Telefone, pedida na hora.
  Sem permissão (ou em tablet sem telefonia), abre o discador e **diz** que não completou.
- **“Coloque a música This I Love” começa a tocar.** O app procura o arquivo na biblioteca do
  aparelho (MediaStore, sem acento e sem depender da ordem das palavras) e toca num serviço em
  primeiro plano, com notificação, controles de tela bloqueada e `MediaSession`. Não existindo o
  arquivo, abre a busca do streaming e avisa que ali o toque no resultado é seu — nenhum app de
  streaming inicia faixa sem conta autenticada, e fingir isso seria mentira.
- **Economia em segundo plano.** Fora da tela, o reconhecimento do WebView e a fala param; só o
  serviço nativo fica esperando “Jarvis”.
- **Exceção não fecha mais o app.** Erros de JavaScript viram aviso e registro; a IA local confere
  memória antes de carregar o modelo, transformando `OutOfMemoryError` em mensagem.

## Destaques da 1.9.0 — voz neural no próprio aparelho

O APK agora embarca o **sherpa-onnx 1.13.8** (Apache-2.0) com ONNX Runtime e espeak-ng. Os
modelos de voz **não** vão no pacote: você baixa a voz que quiser uma única vez, ela fica no
armazenamento privado do app e depois fala **sem internet e sem chave de API**.

| Voz | Tamanho | Timbre medido | Velocidade medida | Licença |
| --- | --- | --- | --- | --- |
| **Cadu** (Piper, pt-BR) | 67 MB | 127 Hz — masculina grave | RTF 0,06 (~17× tempo real) | CC0 |
| **Faber** (Piper, pt-BR) | 67 MB | 155 Hz — masculina clara | RTF 0,06 | CC0 |
| **Kokoro** (inglês) | 132 MB | bm_fable 129 Hz · bm_george 145 Hz | RTF 1,2–1,5 (mais lenta) | Apache-2.0 |

- **Slider “Profundidade da voz neural”** (0,70–1,10; padrão 0,90): abaixo de 1,00 a fala fica
  mais grave **e** mais lenta — a cadência do filme.
- **Sempre opcional:** o seletor começa em “Desligada”. Se o motor faltar, a voz não estiver
  baixada ou a síntese falhar, a resposta sai pela voz normal do Android.
- **Kokoro fala inglês.** `en-gb` não existe no espeak-ng empacotado (síntese volta vazia), então
  o app usa `en`: o timbre britânico vem do falante, o sotaque é americano.
- **Detector de palavra-chave do sherpa-onnx continua fora:** o único modelo público é em inglês
  (medido na 1.7.0: 1 de 4 acertos em português). A aba Voz explica isso na tela.
- **APK maior:** as bibliotecas nativas ARM somam ~53 MB (total ~72 MB). Nada além do APK é
  baixado até você escolher uma voz.

## Destaques da 1.8.0 — detector que entende o que o Android transcreve

Medi o problema em vez de adivinhar: com voz masculina brasileira, o transcritor de português
escreve “Jarvis” como **“já vi”**, **“aviso”**, **“javis”** ou **“charvis”** — o nome não existe no
vocabulário dele. O detector grátis agora pede 5 hipóteses, confere todas, aceita essas variantes e
usa sessões de até 15 s, o que também acaba com o microfone abrindo e fechando toda hora.

- **Botão “Desligar escuta em segundo plano”** em Ajustes ▸ Voz: encerra serviço, microfone e vigia.
- **A voz salva não muda sozinha** ao fechar e reabrir o app; só troca se a voz sair do aparelho.
- **Perfil “Jarvis completo”** (tom 0,55 / velocidade 0,88) e guia para instalar uma voz masculina
  brasileira offline (Piper/SherpaTTS, `pt_BR-faber` ou `pt_BR-cadu`).
- **IA mais conversadora e bem-humorada:** fio da conversa, pergunta de esclarecimento, pesquisa com
  fontes primárias e humor seco a partir de 40%.
- **Nenhum motor novo do Picovoice foi embarcado:** sherpa-onnx não tem modelo de português,
  openWakeWord tem pesos CC BY-NC-SA e DaVoice depende de modelo licenciado.


Assistente pessoal para Android (Capacitor + WebView), com versão desktop Electron opcional.
Aplicativo independente com `com.jarvis.nova`. O código-fonte fica **na raiz do repositório**
(o workflow ainda aceita `JARVIS-NOVA-*-fonte.zip` por compatibilidade).

## Instalar o J.A.R.V.I.S. no PC (Windows, macOS e Linux)

Pré-requisitos: **Node.js 20 ou mais novo** (https://nodejs.org) e, no Linux, as bibliotecas do
Electron (`libnss3`, `libgtk-3-0`, `libasound2`). O resto é baixado pelo npm.

```bash
git clone <url-do-repositório> jarvis-nova && cd jarvis-nova
npm install          # dependências (Electron incluído)
npm start            # abre o Jarvis no PC
npm run dist:win     # gera o instalador NSIS (.exe) em dist/
npm run dist:linux   # gera AppImage e .deb em dist/
npm run dist:mac     # gera .dmg (precisa ser rodado no macOS)
```

No PC o app abre em janela própria (Electron), usa a mesma interface e as mesmas funções do APK,
incluindo os estilos de núcleo HUD, plasma e órbita 3D. As chaves das IAs ficam no cofre do sistema
(`safeStorage`: DPAPI no Windows, Keychain no macOS, libsecret no Linux) — se o cofre não estiver
disponível, o app se recusa a gravar em texto puro. O microfone é liberado pelo Electron na primeira
vez; sem ele, o restante do app continua funcionando por texto.

## Correção da 1.7.2 — atualizador instalando de novo

O “Baixar e instalar” falhava com `Failed to find configured root that contains
/data/data/com.jarvis.nova/files/updates/jarvis-update.apk` porque existiam **dois** `FileProvider`
com a mesma authority — o do template do Capacitor (`@xml/file_paths`, sem `files/`) e o nosso.
Agora o patch remove os existentes e deixa um único apontando para `@xml/jarvis_paths`
(`files-path updates/`). Instale a 1.7.2 uma vez pelo release; depois o botão volta a funcionar.

## Correção da 1.7.1 — assinatura fixa

Release 1.6.0 e 1.7.0 saíram com assinaturas de debug diferentes entre si, porque o Gradle
do CI não usava o keystore copiado para `~/.android`. A 1.7.1 declara a assinatura em
`patch_gradle.py` (`signingConfigs.debug` → `ci/debug.keystore`), com teste de regressão, e foi
verificada com `HOME` limpo: certificado `04e04712…`, o mesmo do APK instalado. Se a instalação
da 1.7.1 for recusada, é porque a versão instalada veio de um daqueles releases antigos —
desinstale uma vez (perde os ajustes salvos) e, a partir da 1.7.1, as próximas instalam por cima.

## Destaques da 1.7.0 — voz de cinema, Spotify e detector escolhido à mão

- **Motor da palavra de ativação escolhível** em Ajustes ▸ Voz: `Automático`, `Android (grátis)`
  ou `Porcupine`. A escolha é gravada em `JarvisPrefs`, sobrevive ao reinício e o serviço a
  respeita — inclusive reiniciando o detector na hora se você trocar com a escuta ligada.
- **Por que o Sherpa-ONNX/openWakeWord não entraram:** o modelo oficial de KWS do sherpa-onnx foi
  testado aqui e reconhece “Jarvis” em inglês, mas erra a pronúncia em português (1 acerto em 4
  frases com limiar 0,10; nenhum no limiar padrão). O `hey_jarvis` do openWakeWord é treinado em
  inglês e tem licença **CC BY-NC-SA**, que não serve para distribuição comercial. Embutir 50 MB de
  engine que erra a sua fala seria piorar a ativação, então o motor gratuito segue sendo o
  reconhecedor do Android — que entende português e, no Android 12+, roda no dispositivo.
- **Voz estilo filme:** perfis `JARVIS do filme` (tom 0,60, velocidade 0,90) e `Ultra grave`
  (0,50/0,85), além do `Padrão`, no mesmo lugar em que ficam os sliders de ajuste fino.
- **Sinal do HUD:** duas notas curtas antes de cada resposta, opcionais (desligado por padrão).
- **Spotify e mídia:** pausar, continuar, próxima, anterior e volume agora vão pela sessão de
  mídia do Android (funciona com Spotify e YouTube Music); “o que está tocando” responde app,
  faixa e artista; “toca <música>” abre o Spotify na busca, e “abre minhas curtidas” vai direto
  para a biblioteca. Iniciar a faixa sozinho o Spotify não permite — o toque no resultado é seu.

## O que veio da 1.6.0 — segundo plano confiável

- **A escuta sobrevive ao app fechado, ao reinício do serviço e ao reinício do aparelho.**
  O estado desejado (“quero a palavra de ativação ligada”) saiu do `localStorage` e passou a
  viver em `JarvisPrefs`, com a AccessKey do Porcupine **cifrada no Android Keystore**. O serviço
  é `START_STICKY` e, ao ser reiniciado sem comando, retoma a escuta com o mesmo detector.
- **Vigia de recuperação (`JarvisWatchdog`).** Um alarme inexato (`setAndAllowWhileIdle`, sem
  exigir permissão de alarme exato) verifica a cada 15 minutos se o usuário quer a escuta e se o
  serviço está rodando; se o fabricante matou o serviço, ele é reiniciado — o alarme concede a
  isenção temporária que o Android 12+ exige para subir um serviço de microfone a partir do fundo.
  Também dispara depois de o app sair dos recentes (`onTaskRemoved`). No boot, a escuta volta por
  esse mesmo caminho (o Android 14+ não permite serviço de microfone direto do BOOT_COMPLETED).
- **Auto-rearme quando a tela não responde.** Se o Android bloquear a abertura da tela ao ouvir
  “Jarvis”, o serviço volta a ouvir depois de 9 s em vez de ficar mudo até o próximo alarme.
- **Notificação acionável.** A notificação persistente agora tem **“Ouvir agora”** (abre o app e
  já começa a ouvir, sem passar pelo detector) e **“Parar”**. O botão usa `JarvisOuvirReceiver`
  para marcar o pedido, então funciona mesmo com o processo morto.
- **Diagnóstico do segundo plano em Ajustes ▸ Voz.** Consulta real de microfone, notificações,
  otimização de bateria, sobreposição, acesso às notificações, serviço/detector, última ativação,
  último erro e dica específica do fabricante — cada linha com o botão que resolve o problema.
  Comando de voz: “Jarvis, diagnóstico do segundo plano” ou “por que a escuta parou”.
- **Teste da palavra de ativação.** Escuta 20 s, conta as ativações sem abrir o app e mostra o
  detector usado, para medir calibração e falsos positivos no seu aparelho.
- **Atalho de início automático por fabricante** (Xiaomi, Samsung, Motorola, Huawei, Oppo/Realme/
  OnePlus, Vivo, Asus), com fallback para as informações do app quando a tela não é exposta.
- **Lembretes de tarefas.** Tarefa com prazo agora agenda um aviso às 09:00 do dia do prazo,
  reaproveitando o agendador persistente dos alarmes; concluir ou excluir cancela o aviso.
- **Checkbox “Serviço em segundo plano” removido.** Ele podia desligar o serviço com a escuta
  ligada (uma das formas de a ativação parar em silêncio). O serviço agora segue a escuta.

## O que veio da 1.5.x

- **Palavra de ativação sem Picovoice:** sem AccessKey, o detector usa sessões curtas do
  reconhecimento do Android (no Android 12+ prefere o reconhecimento **no dispositivo**). Com
  AccessKey, o Porcupine é o detector preferido por gastar menos bateria.
- **Atualizador honesto:** `releases/latest` responde 404 quando o repositório não tem releases —
  o app procura na lista, explica o motivo real e oferece “Ver releases no navegador”. O APK
  baixado é conferido por SHA-256 quando o GitHub informa o digesto e instalado pelo FileProvider.
- **Reconhecimento de voz com fallback:** o modo offline não é mais forçado; há troca entre
  reconhecedor local e de rede nos códigos 12/13/14 e em falha de rede, com mensagem por código.
- **Perfil acústico recalibrado:** só quadros com fala entram no vetor, comparação por distância
  normalizada, silêncio recusado. A exigência “só obedeça à minha voz” vem desligada por padrão
  (experimental, não é autenticação).
- **Medidor de áudio em dB:** a barra saturava em 100% com qualquer som; agora vai de −60 dB a 0 dB.
- **Ações por voz:** lanterna, brilho, painel de notificações, volume por stream e percentual,
  e-mail, fechar app, versão instalada, verificar/atualizar, piada e apps novos.
- **Cérebro local básico**, humor configurável e central de comando com dashboard.

## Gerar APK

Faça push na `main` com os fontes na raiz (ou envie `JARVIS-NOVA-*-fonte.zip` na raiz). O workflow
`.github/workflows/build-apk.yml` fixa a assinatura de CI, executa `npm run test:all`, configura a
API mínima 26, baixa o AAR do sherpa-onnx (`baixar_sherpa.py`), aplica permissões/versão e compila o
APK debug (artefato `JARVIS-Nova-1.13.0-APK`).

Para **publicar um release** (o que o atualizador procura), crie uma tag `v1.13.0`: o workflow
`.github/workflows/release-apk.yml` compila, testa e publica o APK com checksum. Também é possível
executar o workflow manualmente pelo painel de Actions.

Passo a passo do build também em `TESTES.md` e `GUIA-ACESSOS-ANDROID.md` (permissões).

## Instalar e atualizar pelo próprio aparelho

1. Abra o release **v1.13.0** no GitHub pelo navegador do celular e baixe
   `jarvis-nova-1.13.0-10130.apk` (e, se quiser conferir, o `.sha256` ao lado).
2. Toque no arquivo baixado. O Android pede para permitir “instalar apps desconhecidos” para o
   navegador — autorize só para ele, instale e depois pode revogar.
3. Na primeira instalação ele pede microfone, notificações e contatos; a permissão **Telefone**
   (para completar a ligação) e **Música e áudio** (para achar as faixas) são pedidas na primeira
   vez que você usa cada comando, não na abertura.
4. Nas próximas versões, nem é preciso baixar à mão: diga **“Jarvis, verificar atualização”** e
   depois **“atualizar Jarvis”**. O app baixa do release, confere o SHA-256 e entrega o APK ao
   instalador do Android (é só confirmar a instalação).

> O APK **só instala por cima** se tiver a mesma assinatura. O CI usa sempre `ci/debug.keystore`,
> então todas as releases deste repositório compartilham o certificado `04e04712…` e atualizam
> sem apagar ajustes. Um build feito por você sem esse keystore tem outra assinatura e o Android
> vai recusar a atualização (é preciso desinstalar antes, perdendo os dados do app).

### Gerar a chave de assinatura (só se ainda não existir)

```bash
keytool -genkeypair -v -keystore ci/debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=JARVIS Nova, O=Jarvis, C=BR"
```

O `patch_gradle.py` já aponta a assinatura de debug para `ci/debug.keystore`; o workflow copia esse
arquivo para `~/.android/debug.keystore` antes de compilar. **Guarde o keystore** (e a senha) junto
do projeto: perder o arquivo significa não conseguir mais atualizar o app instalado. Para conferir a
assinatura de um APK: `keytool -printcert -jarfile app-debug.apk | grep SHA256`.

## Limites e privacidade

- O detector analisa áudio local enquanto estiver habilitado; o indicador de microfone do Android
  pode permanecer ativo. O detector livre consome mais bateria que o Porcupine.
- A AccessKey do Picovoice fica cifrada no Keystore. Se o Keystore for invalidado (restauração de
  backup ou troca de senha), a chave é descartada e o serviço volta ao detector livre — basta colar
  a chave de novo.
- O Android não concede controle irrestrito de outros apps: fechar é pela tela de detalhes,
  mensagens/e-mail/ligações passam por confirmação e o painel rápido usa uma API oculta que alguns
  fabricantes bloqueiam (nesse caso ele abre as Configurações e avisa).
- Perfil de voz é comparação de timbre, não biometria; não use para autorizar nada sensível.
- Temperatura significa a leitura que o sistema reporta para a bateria.
- O vigia usa alarme inexato: a recuperação pode levar até ~15 minutos. Ele não contorna a
  otimização de bateria nem o “início automático” — para isso existem os atalhos no diagnóstico.

## Estado real

- `npm run test:all`: sintaxe, validador do projeto, roteamento de voz, IA local, perfil de voz,
  cofre de chaves, responsividade, navegação por painéis, os 34 testes de recursos da 1.5.0, os 15
  da 1.8.0 e os **25 da 1.9.0** (`tests/test_v1_9_0.py`), que conferem o plugin nativo, o catálogo
  de vozes, as dependências de build, a extração segura do .tar.bz2 e o caminho de fala.
- **Build local da 1.9.0 verificado:** `assembleDebug` com JDK 17 + SDK 34 gerou 72.623.658 bytes
  (`sha256 56b48ff9…`), versão 1.9.0/1900, ABIs `arm64-v8a` e `armeabi-v7a`, com
  `JarvisVozPlugin`, `OfflineTts` e `BZip2CompressorInputStream` presentes no DEX. O APK do
  release é recompilado pelo CI com a chave de `ci/debug.keystore`.
- **Compilação Android real desta revisão concluída**: JDK 17 + Android SDK 34, `assembleDebug`
  gerou `app-debug.apk` (~18 MB) com `com.jarvis.nova`, minSdk 26, assinado com `ci/debug.keystore`.
- O release no GitHub ainda precisa ser criado (tag `v1.6.0`) para o atualizador encontrar o APK.

**Ainda precisa de teste em aparelho físico** (não é possível validar em CI): taxa de falso
positivo da palavra “Jarvis”, consumo de bateria com a tela bloqueada, comportamento do microfone
em segundo plano por fabricante (Xiaomi/Samsung/Motorola são os mais restritivos), recuperação do
serviço depois de o app ser removido dos recentes e depois de reiniciar o aparelho, “Ouvir agora”
na notificação e a instalação de atualização pelo FileProvider. O APK debug não substitui uma
versão de produção assinada para distribuição.


## 1.20.0 — correções críticas e bloqueio opcional

### Erro "Cannot access 'MEM' before initialization"

A causa era ordem de execução: o trecho que liga os botões do painel de Memória roda na carga do
`app.js` e chamava `renderMemoria()` antes de `const MEM` existir (zona morta temporal). Isso
interrompia o resto do arquivo — por isso Ajustes e Diagnóstico pareciam ter sumido. As declarações
de `MEM` e `PC` agora ficam no topo, ao lado da detecção de plataforma. Nada precisa ser feito pelo
usuário além de instalar esta versão.

### IA local (MediaPipe)

Antes de abrir o modelo, o app verifica tamanho e cabeçalho do `.task` (ZIP ou TFL3), impede duas
gerações ao mesmo tempo e devolve a causa do erro. Modelo inválido não chega mais ao código nativo
(que causava `SIGABRT`). Se a IA local falhar, os provedores em nuvem continuam atendendo.

Requisitos para a IA local: modelo `.task` compatível com MediaPipe `tasks-genai` 0.10.14, aparelho
`arm64-v8a` com RAM livre suficiente (o app exige ~256 MB além do tamanho do arquivo) e o modelo
importado em Ajustes ▸ IA.

### Bloqueio opcional (Ajustes ▸ Segurança)

1. Cadastre um PIN de 4 a 8 dígitos.
2. Marque "Pedir desbloqueio ao abrir o aplicativo".
3. Guarde o código de recuperação mostrado na tela (ele fica fora do telefone).

O bloqueio é do aplicativo, não do Android: não impede abrir outros apps e não substitui a tela de
bloqueio do sistema. Esqueceu o PIN? Use "Esqueci o PIN" e o código de recuperação: o PIN é apagado,
o bloqueio é desativado e você define outro. Sem o código, ainda é possível limpar os dados do app
nas configurações do Android — nenhum caminho deixa o aplicativo permanentemente inutilizável.

### Windows (PC)

O mesmo código web é empacotado com Electron. O workflow `release-pc.yml` gera:

- instalador NSIS (`J.A.R.V.I.S. Nova Setup <versão>.exe`);
- versão portátil (`J.A.R.V.I.S. Nova <versão>.exe`).

Para gerar localmente: `npm ci` e `npm run dist:win` (precisa de rede para baixar o Electron).

Funções equivalentes no PC: IA (chaves e roteador), voz, memória/Obsidian por arquivos Markdown,
tarefas/rotinas, arquivos, CAD, diagnóstico e bloqueio opcional. Câmera, biometria do aparelho,
notificações e serviços em segundo plano do Android dependem de APIs que não existem no desktop;
o app informa isso em vez de fingir que funcionam.


## 1.21.0 — Obsidian conectado de verdade

### Conectar o cofre

1. Abra **Ajustes ▸ Memória** e toque em **Escolher pasta do cofre**.
   - Android: abre o seletor de pastas do sistema; escolha a pasta do vault do Obsidian.
     O Android guarda a permissão, então não precisa escolher de novo a cada abertura.
   - PC: abre o diálogo nativo de pasta.
2. **Testar vínculo** mostra nome, quantidade de `.md`, leitura/escrita e se `Memoria/`
   já existe.
3. **Enviar notas por tópico** grava um arquivo por assunto em `Memoria/` dentro do vault.
4. **Trazer do cofre** importa os `.md` de volta para a memória interna (sem duplicar).
5. **Desconectar** remove só o vínculo; as notas continuam na pasta.

Se o cofre estiver em outro aparelho, use **Baixar .md** e **Importar .md** — não há
sincronização automática entre Android e Windows.

### Como a memória é organizada

Cada assunto vira um arquivo: `Memoria/Gostos.md`, `Preferencias.md`, `Projetos.md`,
`Objetivos.md`, `Estudos.md`, `Dispositivos.md`, `Rotinas.md`,
`Conversas importantes.md`, `Pesquisas.md`, `Contextos.md`. Cada nota aparece como uma
seção `##` com data, tags e origem. Anotar de novo o mesmo título acrescenta uma linha
datada em vez de criar outra nota.

Antes de responder, o J.A.R.V.I.S. consulta apenas as notas que têm relação com a
pergunta (título, tags, corpo e tema provável). Se não houver registro, ele diz que não
encontrou em vez de inventar.

### Limites conhecidos

- O acesso depende de a pasta continuar existindo e da permissão não ser revogada;
  o painel mostra o motivo quando o Android recusa.
- Escrever fora de `Memoria/` é bloqueado de propósito para não mexer nas suas notas.
- Nada é enviado a serviços externos: o cofre é lido e gravado localmente.
- O teste de SAF, biometria e 3D depende de aparelho físico; a suíte automatizada cobre
  a lógica, o parser, a coerência da interface e a compilação.
\n\n## 1.27.0 — Personalidade e voz

O humor agora é identidade, não enfeite: o prompt exige personalidade em toda resposta, os padrões subiram para 90%,
e um banco contextual sugere ângulos por assunto sem repetir. A IA local recebe as mesmas regras. A voz aplica
prosódia por frase (ironia mais grave, exclamação mais viva, pergunta com subida de tom). Em assunto sensível,
o humor é zerado.

