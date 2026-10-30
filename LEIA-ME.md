# J.A.R.V.I.S. Nova 1.31.0

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

