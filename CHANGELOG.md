## 1.23.1 — 2026-10-30

## Correções de inicialização, diagnóstico e anexos no chat

- **`store is not defined` corrigido na causa.** A camada visual da 1.23.0 acrescentou um bloco no fim do
  `app.js`, depois do `})();` que fecha o IIFE — ali `store` não existe e a inicialização abortava. O bloco
  voltou para dentro do IIFE; a opção "Reduzir efeitos visuais" lê, aplica e persiste de novo.
- **Diagnóstico sem texto vertical.** O cabeçalho do cartão era um flex sem quebra e sem largura mínima no
  nome: em painel estreito o nome virava uma letra por linha. Agora o selo de estado não encolhe, o nome tem
  `min-width` legível e o conjunto quebra em duas linhas; `min-width:0` em toda a cadeia de flex/grid.
- **Anexos no chat (real).** Botão de clipe no rodapé, `<input type=file multiple>` (SAF no Android, diálogo
  do Windows no Electron), lista com nome/tipo/tamanho e remoção, leitura de texto por `FileReader` com limite
  de 40 mil caracteres por arquivo e envio do conteúdo dentro do mesmo pedido da IA.
- **Limites ditos na tela:** imagem é encaminhada ao painel Visão; binário não é lido como texto.
- **Não incluído nesta revisão:** geração de `.cad` do CADe SIMU (formato proprietário, sem especificação
  pública), automação de aplicativos/janelas do Windows e alarme do Windows (o desktop não tem motor de alarme).
- **Verificação:** suíte completa verde (1091 → 1100 verificações com o teste desta revisão).

## 1.23.0 — 2026-10-29

## Reformulação visual holográfica

- **Núcleo com profundidade 3D real.** No estilo HUD o disco usa `preserve-3d`: halo em −16 px, aro em
  +14 px, marca em +34 px e telemetria em +26 px. Com ponteiro fino o conjunto inclina
  (`rotateX(6deg) rotateY(-8deg)`) e as camadas se deslocam — paralaxe verdadeira, não sombra.
- **Painéis como porta holográfica.** Entrada com `perspective(1100px) rotateY(-8deg)` pela borda
  direita, brilho ciano projetado e scrim com dissolve (desfoque acima de 700 px de largura).
- **Superfícies padronizadas.** Ajustes, diagnóstico, pessoas, memória, voz, arquivos e Visão usam o
  mesmo vidro em diagonal, filete de luz superior e elevação de 2 px no hover.
- **Retorno ao toque.** Botões afundam 1 px com escala 0.986 e halo curto; abas ativas recebem brilho
  próprio, sem "pulo" seco.
- **Estados reais.** Varredura de 1 px no balão "formulando", confirmação verde no diagnóstico OK e
  pulso de borda no diagnóstico com falha. Nada anima sem o estado correspondente.
- **Reduzir efeitos visuais.** Opção em Ajustes ▸ Voz ▸ Aparência do núcleo, persistida em
  `efeitos_visuais`; desliga tilt, brilhos em movimento e animações longas. Independente de
  `prefers-reduced-motion`, que continua valendo por si.
- **Desempenho.** Só `transform`, `opacity` e `box-shadow`; `content-visibility` nas listas longas;
  entrada mais curta abaixo de 420 px; desfoque desligado em `(update:slow)`. Nenhuma dependência nova.
- **Nada de lógica foi tocado.** Telas, textos, permissões, integrações, os três estilos de núcleo e o
  sistema de animação da 1.21.5 permanecem como estavam.
- **Correção que segue no pacote:** o motor de arquivos do PC resolve caminhos com barra invertida do
  Windows (o "Organizar" não movia nada), coberto por teste de regressão.
- **Verificação:** suíte completa verde (1060 verificações) antes do empacotamento; APK conferido por
  hash dentro de `assets/public`. Sem validação visual em aparelho físico ou emulador.

## 1.22.0 — 2026-10-29

## Visão 2.0 e cadastro de pessoas

- **Balões sem sobreposição.** O posicionamento saiu do `app.js` para `visao.js`, que calcula
  colisão, margem e linha-guia. O teste `test_visao_nova.js` coloca 10 objetos no mesmo ponto e
  prova que nenhum balão cobre outro; objetos colados na borda continuam dentro da imagem.
- **Balão interrompe a fala.** Tocar num balão corta o TTS nativo, a síntese do navegador e a voz
  neural antes de falar o detalhe. A fala antiga não continua depois da escolha e a análise geral
  pode ser retomada pelo botão "Voltar à análise geral".
- **Texto da análise** em painel próprio, com rolagem, cópia e o texto do balão selecionado; o
  resultado é preservado ao alternar entre balões e ao reabrir o painel.
- **Imagens da galeria/arquivo** entram pelo mesmo caminho da câmera, com redução para 1024 px,
  limite de 16 MB e mensagens claras para formato inválido ou falha de leitura.
- **Vídeos MP4/WebM/MOV** com pré-visualização, até 9 quadros extraídos por canvas, análise
  quadro a quadro com timestamp, progresso real, cancelamento e lista clicável que volta ao
  momento correspondente. O áudio não é analisado e isso é dito na tela.
- **Cadastro de pessoas** (`pessoas.js` + painel próprio): nome obrigatório, apelido, relação,
  descrição, preferências, observações e contato opcional; busca por nome/apelido sem acento,
  perfis nunca fundidos, ambiguidade respondida com pergunta, exportação JSON e exclusão com
  confirmação. O contato não entra no contexto da IA; nome, apelido, relação e preferências só
  entram se a opção estiver ligada.
- **Diagnóstico** passa a listar os dois módulos novos entre os componentes do pacote.
- **Testes:** `test_visao_nova.js` (8 grupos), `test_pessoas.js` (10 grupos) e
  `test_v1_22_0.py` (contrato de interface, versão, scripts, CSS e ausência de chaves).

## Limitações desta revisão

- Não houve compilação de APK nem execução em aparelho físico neste ambiente: o JDK e o Android
  SDK não estão instalados. Os testes são estáticos e de núcleo (Node/Python).
- A análise de vídeo depende de um provedor com visão configurado e envia um quadro por vez; não
  há análise de áudio nem transcrição de fala do vídeo.
- O indicador de fala fora do aplicativo por notificação/sobreposição não foi implementado nesta
  revisão; a fala continua sendo interrompida pelos controles do app e pelo botão Parar.

## 1.21.5 — 2026-10-29

## Camada Windows (PC) — 1.21.5

Expansão do J.A.R.V.I.S. Nova para computador, sobre o mesmo núcleo do Android.

- **Painel ▸ Computador** (só no Electron): abas Arquivos, CAD, Tarefas e Diagnóstico.
  O botão e o painel nascem escondidos; `pc.js` só age quando existe `window.jarvisNative`.
- **Motor de arquivos do PC** (`platforms/desktop/arquivos.js`): formato detectado por
  assinatura de bytes, prévia por tipo (tabela para CSV, imagem inline, texto extraído de
  DOCX, planilhas de XLSX, metadados de PDF), gravação atômica com backup `.bak-<data>`,
  comparação por bloco, pesquisa textual, conversões reais (csv↔json, md→html, html→txt,
  txt→md) e organização em duas etapas (plano e aplicação).
- **CAD do PC** (`platforms/desktop/cad_pc.js`): identifica DXF, STL, 3MF, STEP, IFC,
  `.cad`, DWG, FCStd e OLE pelo conteúdo; visualiza DXF em linhas/camadas e malha 3D;
  cria, altera em nova versão (nunca sobrescreve o original) e exporta com validação por
  reabertura e lista de perdas. DWG, RVT/RFA e FCStd são recusados com o motivo.
- **Tarefas sequenciais** com lista branca de passos, relatório por passo, parada no
  primeiro erro e cancelamento.
- **Diagnóstico do PC**: versão, memória, disco, provedores com chave (só nomes), cofre do
  Obsidian, ferramentas CAD instaladas e falhas recentes — com estados reais, incluindo
  "não verificado".
- Nada disso muda o Android: versão e `versionCode` continuam 1.21.5 / 10215.


### Cofre do Obsidian num único lugar (correção real)

- O bloco do cofre era um `<section class="grupo">` **sem `data-category`**: a navegação de abas só
  mostra/esconde seções marcadas, então ele não aparecia em Ajustes ▸ Memória. Agora é um cartão
  **dentro** da aba Memória, ao lado da memória pessoal.
- **Um só ponto de seleção**: removido o campo de texto “Caminho do cofre (PC)”, que duplicava a
  escolha. A pasta vem sempre do seletor do sistema (SAF no Android, diálogo nativo no PC) e o
  caminho salvo é lido do armazenamento, não de um input paralelo.
- Selo de estado do vínculo (`conectado`, `falta a pasta`, `desligado`, `sem pasta aqui`) e resumo com
  quantidade de `.md`, leitura/escrita e existência de `Memoria/`.

### Diagnóstico agrupado por área

- Resultados organizados em seis grupos — aplicativo e pacote, IA, voz e áudio, memória e dados,
  permissões e sistema, rede — com contagem e **pior estado** em cada cabeçalho.
- Cada linha mantém estado, descrição, impacto, como resolver, atalho para a aba certa e horário;
  os textos longos e o estado interno ficam em **Detalhes técnicos** recolhível.
- Botão “Abrir registro de erros” leva ao painel de registro a partir do diagnóstico.

### Interface e animações

- Sistema único de movimento: `--jv-dur-1/2/3`, `--jv-ease` e três keyframes compartilhados
  (`jv-surge`, `jv-surge-x`, `jv-painel`) usados por seções, painéis, abas, cartões e linhas do
  diagnóstico — entrada em cascata curta, sem efeitos independentes competindo.
- Superfícies unificadas (borda, vidro, sombra) em cartões de IA, painel, status e diagnóstico;
  selos de estado com cor por severidade.
- Estados reais continuam mandando na animação: `thinking` pulsa o HUD, `listening` e `speaking`
  escalonam as ondas; nada anima quando a atividade não existe.
- `prefers-reduced-motion` desliga animações e transições.

### Modelos `.task`

- Bloco “Onde baixar modelos `.task` compatíveis” na aba IA com links verificados: repositório
  oficial `litert-community/Gemma3-1B-IT`, coleção LiteRT Community, documentação do MediaPipe LLM
  Inference e Gemma no Kaggle.
- Lista completa com nomes de arquivo conferidos, tamanho, licença e limites de RAM em
  `MODELOS-IA-LOCAL.md`. O `.task` é binário: nenhum link é inserido dentro do modelo.

## 1.21.4 — 2026-10-29

### Obsidian em Ajustes ▸ Memória

- O bloco do cofre saiu do painel avulso e passou a viver **dentro da aba Memória dos Ajustes**,
  abaixo da memória pessoal: ativar/desativar, escolher a pasta do cofre (SAF no Android, diálogo
  nativo no PC), testar o vínculo, enviar e trazer as notas por tópico, organizar e desconectar.
- Ao abrir a aba, o app **consulta o estado real do cofre** (`cofreStatus`) em vez de mostrar
  “sem vínculo” até você tocar em testar. O painel Memória ganhou o atalho
  “Abrir Memória nos Ajustes”.
- A gravação continua um arquivo por tópico em `Memoria/`, sem apagar notas fora dessa pasta e
  sem duplicar a extensão `.md`.

### Diagnóstico

- Nova verificação **Erros recentes**: lê o registro do próprio app e conta as falhas das
  últimas 24 h, com orientação para abrir o Registro de ações.

### Tela de bloqueio

- Ajuste moderado, sem mudar a identidade: núcleo um pouco menor, grade e brilho mais discretos,
  arcos mais finos, títulos e espaçamentos mais equilibrados e botões alinhados.

## 1.21.3 — 2026-10-29

### Tela de bloqueio

- Redesenho completo em linguagem holográfica: núcleo com **quatro arcos SVG** em rotações
  diferentes, varredura horizontal, grade e brilho de fundo, relógio e data em tempo real,
  indicador de estado do sistema, **pontos de PIN** que acompanham a digitação, tremor curto
  no PIN errado e saída animada ao desbloquear.
- Continua **opcional** (Ajustes ▸ Segurança), não substitui o bloqueio do Android e mantém o
  que já existia: PIN com hash SHA-256, biometria/credencial do aparelho pelo plugin
  `JarvisSeguranca`, código de recuperação, atraso progressivo após erro e `prefers-reduced-motion`.
- O relógio e os pontos são atualizados só enquanto a tela está aberta; o intervalo é limpo ao
  fechar, e a animação de saída dura 260 ms para não atrasar o desbloqueio.

### Diagnóstico real

- Sete estados explícitos — **Operacional, Aviso, Falha, Não configurado, Desativado, Não
  aplicável e Não verificado** — em vez de tudo virar “ok/warn”. Recurso opcional desligado
  não aparece mais como defeito, e o que não pôde ser conferido não aparece como sucesso.
- Cada item mostra **impacto**, **como resolver**, **atalho para o ajuste** e **horário** da
  verificação; o topo resume a execução (falhas, avisos, total e duração).
- Novas verificações de verdade: módulos carregados do pacote, identidade do pacote em execução
  (e “não verificado” quando roda no navegador), escrita/leitura/remoção de uma chave de teste
  no armazenamento, configurações realmente salvas, estado do cofre do Obsidian, rotinas e o
  serviço de escuta em segundo plano.
- Integridade, assinatura e conteúdo do `.apk` ficam onde pertencem: na compilação, não na tela.
  O diagnóstico em execução diz isso explicitamente em vez de afirmar que o pacote está íntegro.

## 1.21.2 — 2026-10-29

### Auditoria de runtime

- **Apagar chave deixou de falhar em silêncio.** O handler de `#c-apagar-<provedor>` chamava
  `gravarChave()` sem `try/catch`; quando o cofre seguro não estava disponível (navegador
  comum, ou falha do cofre no Android/desktop), o clique virava promessa rejeitada sem dono —
  o botão parecia não fazer nada e nenhum aviso aparecia. Agora a falha é registrada, dita ao
  usuário no chat e a lista de chaves é atualizada mesmo assim.
- **Instalação reproduzível.** O `package-lock.json` estava fora de sincronia com o
  `package.json` (faltavam as dependências do empacotador Windows) e `npm ci` recusava
  instalar. O lockfile foi regenerado sem alterar as versões declaradas; `npm ci` voltou a
  funcionar a partir de um diretório limpo.

### Verificação desta versão

- Harness de runtime em DOM real (jsdom): carrega `index.html` e os scripts na mesma ordem do
  app, percorre as 12 abas, clica nos 167 botões, confere abertura/fechamento dos painéis, a
  rolagem do painel de configurações e a persistência do interruptor do cofre.
- Nenhuma exceção, nenhuma promessa rejeitada e nenhum botão inerte no caminho exercitado.
- `npm run test:all` completo, incluindo o teste desta versão.

## 1.21.1

- **Vínculo com o Obsidian**: o interruptor "Usar o cofre como memória conectada" agora grava o estado, reflete na conversa e avisa quando ainda falta escolher a pasta (antes não tinha handler nenhum).
- **Escrita SAF sem nome duplicado**: se o provedor do Android criar `Gostos.md.md`, o arquivo é renomeado para o nome exato — a segunda sincronização reaproveita a nota em vez de criar outra.
- **Cancelar o seletor** de pasta deixou de aparecer como falha de conexão.

## 1.21.0 — 2026-10-29

### Obsidian: cofre de verdade

- Android: novo caminho **SAF** em `JarvisUtilPlugin` — `escolherCofre`, `cofreStatus`,
  `cofreListar`, `cofreLer`, `cofreEscrever` e `esquecerCofre`, com permissão persistente
  (`takePersistableUriPermission`). O app lê e grava só dentro da pasta escolhida e só em
  `Memoria/`; nada é apagado e nenhuma nota sua fora dessa pasta é tocada.
- PC: `escolher_cofre` no diálogo nativo; a pasta fica autorizada no processo principal e
  os comandos `cofre_*` recusam caminho fora dela.
- Ajustes ▸ Memória: ativar/desativar o cofre, escolher pasta, testar vínculo, enviar e
  trazer notas, organizar por tópicos, desconectar e ver a última operação. O `.md`
  avulso continua disponível como alternativa.

### Memória por tópicos

- Dez tópicos, cada um com um arquivo: `Memoria/Gostos.md`, `Preferencias.md`,
  `Projetos.md`, `Objetivos.md`, `Estudos.md`, `Dispositivos.md`, `Rotinas.md`,
  `Conversas importantes.md`, `Pesquisas.md`, `Contextos.md`, com frontmatter (título,
  tema, data, número de notas, origem) e uma seção `##` por nota.
- `anexarAoTopico()` classifica o assunto pelas palavras, atualiza a nota existente com
  data em vez de duplicar e preserva o histórico.
- A importação entende as seções `##`, então exportar e trazer de volta não cria lixo.
- `contextoRelevante()` pontua título, tags e corpo e usa o tema provável da pergunta;
  só o que casa entra no prompt. Sem correspondência, o prompt diz que não há registro —
  e o assistente não inventa lembrança.

### Núcleo 3D

- Quarto anel orbital, varredura holográfica vertical e opacidade dos anéis ligada à
  energia do estado (idle, ouvindo, pensando, falando, erro).
- Paletas `processing` e `error` com apelidos em português, sem alocação por quadro.

### Correções de auditoria

- O bloqueio opcional agora reflete o estado salvo ao abrir Ajustes ▸ Segurança.
- Tópicos novos aparecem nos chips e no seletor de nova nota; o painel mostra o arquivo
  correspondente no cofre.

## 1.20.0 — 2026-10-28

### Corrigido na raiz

- **`Cannot access 'MEM' before initialization`**: o bloco que monta o painel de Memória executava
  `renderMemoria()` e `memTemaAtual()` em nível de topo **antes** de `const MEM`, declarada ~1.000 linhas
  abaixo. O app.js inteiro abortava na zona morta temporal e as ligações seguintes (Ajustes, diagnóstico,
  memória, arquivos) nunca aconteciam — o app seguia "funcionando" só com o que já tinha sido ligado.
  As declarações de `MEM`/`PC` passaram para o topo, junto da detecção de plataforma, com `MEM_ESTADO`
  explícito e verificação no diagnóstico.

### IA local (MediaPipe) protegida

- Pré-checagem antes de qualquer chamada nativa: arquivo presente, legível, tamanho plausível e cabeçalho
  ZIP (`PK`) ou flatbuffer (`TFL3`). Modelo truncado ou que não é modelo deixa de chegar ao interpretador,
  que morria com `interpreter_ != nullptr` / `LlmInferenceEngine_CreateSession`.
- Trava de sessão única (`gerando`) e liberação no `finally`: duas gerações concorrentes criavam dois
  interpretadores.
- Erros distinguem memória esgotada, mensagem do modelo e falha nativa; a nuvem continua funcionando.

### Diagnóstico real

- Novas verificações: memória conectada (notas/temas/espaço), armazenamento do app, estado da abertura,
  horário de início e duração. O diagnóstico deixa de esconder a causa quando um módulo não carrega.

### Bloqueio opcional do aplicativo

- Ajustes ▸ Segurança: ativar bloqueio ao abrir (desligado por padrão), PIN de 4 a 8 dígitos com hash,
  biometria/credencial do aparelho pelo `BiometricPrompt`, teste de biometria, código de recuperação
  mostrado uma vez e atraso progressivo após erros. Rebloqueia após 2 minutos fora.
- Nunca substitui o bloqueio do Android e nunca inutiliza o app: o PIN sempre desbloqueia e a recuperação
  apaga o PIN e desativa o bloqueio.

### Windows

- Workflow `release-pc.yml`: instala dependências, roda a suíte, empacota com electron-builder (NSIS +
  portátil) e anexa ao release da tag. O mesmo código web dos dois pacotes.

## 1.19.1

- **Modo Visão acessível de verdade.** O painel existia, mas a aba ficava na barra lateral, que é `display:none`
  abaixo de 960 px — no celular só dava para abrir por voz. Agora ele tem **aba na barra lateral**, **ícone de olho
  no cabeçalho** (mesmo componente de Tarefas e Configurações) e **atalho no card CONVERSA E INFORMAÇÕES**; qualquer
  caminho marca a aba como ativa. O teste da versão exige os três pontos.

## 1.19.0

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

## 1.18.0

- **Núcleo 3D estourado em branco: corrigido no celular e no PC.** O shader calculava
  `gl_PointSize = aSize * (250 / profundidade)`. Com a câmera a 5,4 unidades e até 2.100 partículas
  em blending aditivo, cada sprite saía com ~150 px e o HUD virava um quadrado branco (o da captura),
  com custo de preenchimento que travava o aparelho. O tamanho agora considera o pixel ratio real e
  fica limitado a 22 px, com brilho aditivo menor.
- **Contexto WebGL não é mais roubado pelo teste de suporte.** Pedir `getContext` no próprio canvas
  fazia o Three.js herdar uma cena opaca (alpha desligado); o teste passou a usar um canvas descartável.
- **Animação que não congelava mais:** perda de contexto tratada (`webglcontextlost`/`restored`),
  `ResizeObserver` e orientação recalculam o tamanho, e um vigia de 1,5 s inicia a animação mesmo
  quando o `IntersectionObserver` não acusa visibilidade.
- **Borda quadrada do brilho:** o canvas ganhou máscara radial no CSS, então o brilho fica dentro do
  círculo do HUD em telas pequenas e grandes.
- **Auditoria do APK:** `startForeground()` com segunda tentativa mínima (fim do
  `ForegroundServiceDidNotStartInTimeException`), estado estático do player limpo no `onDestroy`,
  `minSdkVersion` 26 coerente com o `build.gradle` e `android:usesCleartextTraffic="false"`.
- **Versão 1.18.0** (versionCode 10180).

## 1.17.0

- **Crash do núcleo 3D corrigido.** O construtor gravava `this.nivel = 0` (número) por cima do método
  `nivel(v)` do protótipo; `NucleoOrbita.nivel()` estourava com `TypeError: instancia.nivel is not a function`. O valor passou a viver em `audioNivel`, a fachada confere o tipo antes de chamar e existe
  `NucleoOrbita.diagnostico()` para Ajustes.
- **Núcleo Órbita em 3D real.** Cena WebGL com Three.js empacotado (`vendor/`, sem CDN): partículas com
  shader próprio, três anéis em planos diferentes, miolo em arame e brilho aditivo.
- **Mais fluido, sem mudar a aparência.** Nada de alocação por quadro (cores compartilhadas com os
  materiais), antialias desligado em telas 2x, `setDrawRange` e pixel ratio adaptativos quando o FPS
  cai, pausa por `IntersectionObserver`/`visibilitychange`, contexto liberado ao trocar de estilo e
  fallback Canvas 2D.
- **Arquivos `.cad` do CadSimu.** O núcleo cria, valida e analisa arquivos `.cad` (formato documentado
  `CadSimu CAD`, v1), com erros claros para JSON inválido, objeto/tipo/número errado e versão futura;
  os arquivos ficam num cofre local com teto e podem ser baixados ou apagados. Por voz: “crie um
  arquivo cad de uma caixa 100 por 60 por 20” e “analise o cad peça-1”.
- **Versão 1.17.0** (versionCode 10170) com testes atualizados.

## 1.16.0

- **Crash do serviço em primeiro plano corrigido.** O Android encerrava o processo com
  `ForegroundServiceDidNotStartInTimeException` (`com.jarvis.nova/.JarvisService`) porque os caminhos
  de parar, pausar e de microfone não autorizado retornavam de `onStartCommand` sem chamar
  `startForeground()`. Agora o serviço se promove no `onCreate` e no topo do `onStartCommand`, e o tipo
  é `microphone` só com RECORD_AUDIO concedida (senão `dataSync`, declarado no manifesto).
- **Núcleo Órbita.** Adaptação do visualizador enviado para o app: esfera de partículas com três anéis,
  núcleo pulsante e paletas por estado, em Canvas 2D — sem Three.js, sem CDN, dentro da CSP. Convive com
  HUD e plasma em Ajustes ▸ Voz, com prévia e troca imediata; pausa com a tela oculta.
- **Memória conectada (estilo Obsidian).** Cofre local com temas (gostos, pesquisas, projetos,
  contextos, rotinas, mensagens), busca, criação por voz ou painel, edição, exclusão com PIN, backup e
  importação, deduplicação e controle de espaço (240 notas / 512 kB, liberar espaço, esvaziar).
- **Humor brasileiro com níveis.** Personalidade, tratamento e exemplos de referência; níveis Discreto,
  Equilibrado e Avançado; humor suspenso em assunto sério e nunca antes da tarefa.
- **Multiplataforma.** `plataforma.js` centraliza detecção, capacidades e chamadas nativas; layout
  adapta celular e computador; no desktop, status do PC e arquivos (listar, ler, criar, apagar para a
  lixeira, abrir pastas) restritos à pasta do usuário.
- **Testes.** `tests/test_v1_16_0.py` roda os módulos de verdade e cobre crash, órbita, memória, humor e
  desktop.

## 1.13.0 — 2026-10-27
O detector de ativação passou a ser nosso, as respostas passaram a ser roteadas e o assistente ganhou olhos.

- **Picovoice removido por completo.** Saíram a dependência `ai.picovoice:porcupine-android`, os imports e o `PorcupineManager` do serviço, o cofre da AccessKey em `JarvisPrefs` (com o AES/GCM que só existia para ela), o campo e o botão da chave na tela, o nome `picovoice` do cofre do desktop e as menções no patch do Gradle e nos workflows. Nada de SDK de palavra de ativação entra no APK — e nenhum áudio sai do aparelho.
- **`JarvisAtivacao.java` (novo): o detector próprio.** Três degraus, todos locais: variantes conhecidas (26 formas medidas em transcrições reais com voz brasileira, incluindo “já vi”, “javis”, “charvis”, “garvis”), distância de edição pequena para tolerar sotaque e vogal trocada, e comparação pelo esqueleto consonantal (“ch”/“sh”/“x” viram “j”, “z” vira “s”, vogais saem — “charvis” e “jarvis” chegam ao mesmo “jrvs”). As formas toleradas só valem na família “jarv-” (J inicial **e** a letra “v”), e é isso que impede “jardim”, “jardineiro” e “jargão” de acordar o assistente. `Hermes.ativacao` roda as mesmas regras no WebView e o teste da versão compara as duas listas, para não divergirem.
- **Latência da ativação.** O detector confere **todas** as hipóteses devolvidas e o resultado **parcial** já vale: o assistente é chamado antes de a frase terminar, em vez de esperar o silêncio. Os reinícios entre sessões caíram (350 ms depois de fala, 700 ms em silêncio), a sessão continua longa (5 s mínimos, 1,6 s de silêncio tolerado) e o reconhecedor no dispositivo é preferido quando existe.
- **Calibragem e porteiro de ruído.** `JarvisPrefs.sensibilidade` (0–100) e `JarvisPrefs.variantes` (palavras extras) são lidos a cada sessão: mudar o slider vale na hora, sem reiniciar o serviço. A sensibilidade vira tolerância (0/1/2 letras), aceitação de parcial, mínimo de caracteres e **piso de voz**; `onRmsChanged` alimenta esse piso e transcrição que aparece com som baixo demais (televisão, conversa ao fundo) é descartada com contagem própria — `JarvisPrefs.rejeitadas`, exibida no diagnóstico.
- **Roteador de motores de IA (`Hermes.planejarIA`).** Cada provedor tem nota por tipo de tarefa (rápida, conversa, raciocínio, pesquisa, visão), ajustada pela latência medida no aparelho (`registrarLatencia`, média móvel 70/30), por falhas recentes e por indisponibilidade (cota/erro → pausa). A ordem devolvida é a fila de tentativas: o primeiro responde, os seguintes são o fallback automático. O roteador também escolhe o **modelo** (modelo forte em raciocínio, modelo que enxerga em visão) e o **tempo-limite** por tarefa. `chamar()` passou a usar essa fila em vez da ordem fixa do arquivo.
- **Visão pela câmera, com balões.** Painel novo (`#painel-visao`): câmera ao vivo no WebView (o Capacitor já trata a permissão de câmera do WebChromeClient, e o manifesto já declara `CAMERA`), captura de **um** quadro em JPEG 1024 px, envio ao provedor que reconhece imagens na ordem do roteador (Gemini → Groq `llama-4-scout` → Mistral `pixtral`) e desenho de **balões** nas caixas normalizadas devolvidas pelo modelo; sem caixa válida, o objeto vira botão em lista. Tocar no balão fala o detalhe (`Hermes.visao.descrever`, com o tom do turno). Fechar o painel — ou mandar o app para segundo plano — desliga a câmera na hora. Por voz: “o que você está vendo”, “analise isso”, “reconheça esse objeto”, “leia isso”.
- **Diagnóstico integrado maior.** Entraram câmera (permissão, dispositivo e caminho de visão), motores de IA (quem tem chave, latência medida de cada um e a última escolha do roteador) e a calibragem da ativação com os descartes por ruído; a fala de resumo do núcleo passou a citar as checagens de verdade.
- **Área de mensagens.** Balão de carregamento “formulando” com três pontos animados (removido na primeira fala, anunciado a leitor de tela), espaçamento e contraste ajustados, `scroll-padding` no fim da lista e rolagem que só acompanha quando você já está no fim. A navegação lateral com um item a mais passou a rolar sem cortar atalho.
- **Personalidade.** O prompt de sistema descreve o humor como “sarcasmo seco, irônico e levemente debochado, sempre educado no fundo”, com limites explícitos (nunca rude, nunca sobre pessoas/aparência/religião/tragédia, nunca duas piadas seguidas, suspenso por completo em assunto sensível) e duas frases próprias novas (`visaoSemObjeto`, `roteadorTroca`), que passam pelo mesmo portão de humor.
- **Versão 1.13.0 (versionCode 10130)**, mesmo pacote e mesma assinatura: instalável por cima da 1.12.0 e atualizável pelo próprio app.

## 1.15.0

- **Núcleo em plasma, opcional.** Ajustes ▸ Voz ganhou “Aparência do núcleo”, com dois estilos: o
  **HUD técnico** de sempre (anéis, marcas e grades do painel) e o **plasma**, um anel de energia
  irregular esverdeado girando devagar em volta de um miolo pequeno — o desenho pedido na imagem de
  referência. A escolha vale na hora, fica salva no aparelho e a abertura (splash) nasce com o
  mesmo estilo, para não piscar entre as telas. No estilo plasma os rótulos técnicos do HUD saem de
  cena e sobra o núcleo com a marca.
- **Animação própria do núcleo, em camadas.** Quatro filamentos giram em velocidades diferentes
  enquanto a forma de cada um se deforma (é isso que dá o contorno irregular, com cara de plasma, e
  não um círculo perfeito), uma névoa e o miolo respiram fora de fase e um ponto central pulsa. O
  conjunto reage ao **nível real do microfone**, pela mesma medida que alimenta as ondas de voz:
  quando você fala, o anel cresce e os filamentos ficam mais vivos; no silêncio ele volta ao
  repouso. Com a tela fora de vista a animação pausa (bateria) e, com `prefers-reduced-motion`, o
  CSS reduz tudo a uma fração de milissegundo.
- **Prévia na própria tela de ajustes.** Ao lado do seletor há uma miniatura que muda junto com a
  escolha, para conferir o estilo antes de sair da configuração.


## 1.14.0

- **Escuta contínua pela transcrição da Groq.** Além do detector próprio, o app pode ouvir com o
  microfone aberto: o áudio é cortado em pedaços de 2,5 s e cada pedaço vai para a transcrição da
  Groq (Whisper); o texto volta e **as mesmas regras de fonética do núcleo** decidem se a palavra de
  ativação foi dita. Um porteiro de ruído medido no microfone descarta trecho sem voz dirigida ao
  aparelho antes de gastar cota. `Hermes.transcricaoGroq.erro` traduz o que a API responde em
  mensagem clara: limite de uso (HTTP 429) espera e tenta de novo, chave recusada (401/403) avisa e
  não insiste, áudio grande demais, serviço fora do ar, falta de rede e permissão de microfone negada
  também têm texto próprio. Limites ditos na própria tela: roda com o app aberto, exige chave,
  consome cota e envia áudio para fora — por isso é opcional e desligado por padrão, e o detector do
  Android continua sendo o caminho de segundo plano, sem chave e sem áudio saindo do aparelho.
- **Variações de pronúncia ampliadas.** A lista de variantes ganhou as formas curtas que o usuário
  dita rápido — “jerves”, “gerves”, “garves”, “jaive”, “jaives”, “jaivi” — e continua idêntica no
  Java (`JarvisAtivacao`) e no JavaScript (`Hermes.ativacao`), com teste comparando as duas.
- **Menu Informações.** Nova tela com bateria, memória, armazenamento, conexão, aparelho, temperatura
  da bateria, clima da cidade configurada e as manchetes do momento (com os links das fontes). Abre
  pelo card da central, pela barra lateral e por voz (“Jarvis, informações”). Cada linha é consulta
  real ao aparelho; o que falhou aparece dito, sem “tudo certo” inventado.
- **Conversa em tela própria e histórico inteiro.** O chat saiu do menu principal, onde o espaço era
  curto e o fim das mensagens ficava cortado: a conversa tem a tela dela, com altura cheia e rolagem
  completa. Junto disso, a área de mensagens deixou de usar clip de pintura e limite de altura em
  `dvh`, e a rolagem ganhou uma segunda passada depois do layout (link e fonte que mudam a altura
  não cortam mais a última fala).
- **Mensagens e falas não se repetem.** `Hermes.eco.unico` é o portão único: a mesma fala e o mesmo
  balão não saem duas vezes em sequência (com registro do descarte). Era o sintoma de dois caminhos
  disparando o mesmo turno — o usuário via a resposta duas vezes e ouvia a fala repetida.
- **Conjunto de animações coeso.** Verificação do sistema (usada no diagnóstico, no menu Informações
  e na abertura), ondas de voz que reagem ao microfone enquanto ele ouve e enquanto o assistente
  fala, entrada animada ao trocar de categoria do painel, destaque do HUD por estado e transições
  entre central e conversa. Tudo com `prefers-reduced-motion` respeitado.

## 1.12.0 — 2026-10-26
O núcleo Hermes Agent entra como motor único de linguagem e decisão, e o assistente ganhou a rotina de abertura do dia.
- **Núcleo Hermes (hermes.js).** Todo turno passa por um só lugar, com as rotas declaradas em ordem: habilidade própria do núcleo → comando resolvido no aparelho → IA. O arquivo não toca no DOM nem conhece o aplicativo: `Hermes.instalar()` recebe falar, ler/gravar preferências, clima, notícias, diagnóstico e o resolvedor de comandos locais. Consequência prática: "bom dia" deixou de gastar uma chamada de IA e resposta local não depende mais da nuvem.
- **Telemetria de rota.** O núcleo conta quantos turnos cada rota resolveu (`Hermes.metricas()`), e isso aparece no diagnóstico integrado e no comando de voz "status do núcleo": dá para ver, com número, quanto é resolvido no aparelho e quanto vai para a IA.
- **Decisão da IA validada.** A resposta do modelo passa por `Hermes.validarDecisao()` antes de virar ação: ação inventada, desconhecida ou indisponível nesta plataforma é descartada (e a fala recebe uma frase honesta do próprio app), em vez de o assistente anunciar algo que não será executado. Argumentos com formato errado viram `{}`.
- **Briefing diário no "bom dia".** Na primeira saudação do dia ele fala a temperatura atual (Open-Meteo, já em cache desde a abertura) **e** as manchetes do momento, com clima e notícias buscados em paralelo; se um dos dois falhar, a fala sai com o que existe e diz o que não conseguiu confirmar. Depois disso, cumprimenta curto. Em modo offline avisa e não consulta nada. Chave `briefing_auto` liga/desliga.
- **Autodiagnóstico por voz.** "Verifique o sistema", "faça um diagnóstico completo" ou "como estão os sistemas" rodam as checagens e respondem falando: núcleo Hermes (versão, turnos e proporção resolvida no aparelho), reconhecimento de voz, síntese (com voz neural quando baixada), IA local, rede/CORS, chaves configuradas e permissão de microfone pelo lado nativo. O resumo falado é montado pelo núcleo (`resumoDiagnostico`), com as pendências e o primeiro detalhe útil. O diagnóstico da escuta em segundo plano continua no seu comando próprio.
- **Abertura com reconhecimento de voz.** O app abre com a animação do núcleo (anéis, barra de progresso e etapas reais). Com perfil de voz cadastrado e a conferência ligada, a animação não termina até reconhecer quem falou: ao confirmar, ela conclui e libera as demais opções do app. Sem perfil — ou com o reconhecimento desabilitado — roda apenas a animação inicial e libera. Ninguém fica preso: há "continuar sem reconhecer", limite de 25 segundos e um comando por voz libera a tela na hora. A conferência da abertura não fala em voz alta (a própria animação explica o que está acontecendo) e continua valendo uma vez por sessão.
- **Fluidez das animações.** As camadas do HUD passam a ser compostas na GPU (`transform`/`will-change`) e as mudanças de estado usam apenas transform/opacity, que não forçam relayout; a tela de abertura e o reconhecimento respeitam `prefers-reduced-motion`.
- **Humor por contexto, no código.** As frases próprias do aplicativo ganharam novas variantes (resposta vazia, saudação curta, fecho do briefing, fecho do núcleo) e continuam passando pelo mesmo portão: humor do slider ≥ 40%, sem pressa e sem assunto sensível. O tom do turno agora é do núcleo (`Hermes.tom`), usado tanto pelo prompt da IA quanto pelas frases do app.
- **Comandos rápidos novos** na central: "Bom dia" e "Diagnóstico".
- Versão 1.12.0 (versionCode 10120), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.11.0 e é atualizável pelo próprio app.

## 1.11.0 — 2026-10-25
Revisão de fluidez e de comportamento, sem mexer na arquitetura: os plugins nativos, os provedores de IA e os comandos continuam os mesmos.
- **A resposta passa a ser falada antes de terminar de chegar.** O app lê o corpo da resposta em streaming (SSE): assim que o campo `"fala"` fecha no JSON parcial, ele começa a falar enquanto a IA ainda gera o resto. O caminho normal de antes continua existindo como fallback — provedor sem streaming, corpo sem leitor, rede caindo ou resposta vazia voltam para `postChat` com todos os tratamentos de erro de sempre, e nada é pausado por engano; provedor que recusa o formato não é tentado de novo a cada pergunta.
- **Pré-aquecimento que nunca tinha sido ligado.** `aquecer()` (abre a conexão com a API enquanto você ainda fala) existia desde a 1.9 mas não era chamado em lugar nenhum. Agora ele roda na ativação, na transcrição e no comando digitado, junto com o aquecimento mudo do motor de voz do Android — a primeira resposta deixa de pagar DNS, TLS e a inicialização do TTS.
- **O gravador não trava mais o app.** `gravar()` usava um executor async dentro de `new Promise`: se o `AudioContext` ou o `MediaRecorder` falhasse depois de o microfone abrir, o erro se perdia e a promessa ficava pendurada para sempre em "ouvindo". Agora a falha vira `reject`, libera microfone, contexto e gravação, e o app segue.
- **Humor que reage ao contexto, no código.** `tomDoTurno()` classifica cada pergunta como comum, **com pressa** ou **sensível/urgente** (saúde, segurança, emergência). O resultado entra no prompt ("CONTEXTO DO TURNO") e nas frases próprias do app: com pressa a resposta vai direto ao ponto e sem humor; em assunto sensível o humor some mesmo com o slider no máximo — inclusive na piada.
- **Frases próprias com variação.** `FRASES` + `fraseApp()` concentram o texto fixo do aplicativo num ponto só, com rotação para não repetir a mesma frase em chamadas seguidas e escolha entre a variante seca e a com humor conforme a configuração e o contexto.
- **Sessão longa não cresce sem fim.** O histórico guarda no máximo 120 mensagens em memória (o prompt usa as últimas 8) e a lista de vozes do Android é cacheada com janela de reteste, em vez de uma chamada nativa por pedaço falado.
- **Voltar ao app religa a ativação na hora.** Se a escuta deveria estar ligada e o Android a encerrou no fundo, o `visibilitychange` reabre o detector em vez de esperar o próximo alarme do vigia (15 min).
- **Código morto removido.** `JarvisWatchdog.garantir()`, `JarvisService.pararTeste()` e os métodos de plugin `pausarEscuta`, `pararTesteEscuta` e `statusEscuta` não tinham nenhum chamador.
- Versão 1.11.0 (versionCode 10110), mesma assinatura de CI: instala por cima da 1.10.1.

## 1.10.1 — 2026-10-25
Revisão do segundo plano. Nada de funcionalidade nova: são os defeitos que impediam a escuta de continuar viva e o player de rodar sem derrubar o processo.
- **Player de música derrubava o processo em alguns comandos.** "Pausar", "próxima" e "parar" chamavam `startForegroundService()`, mas o serviço tratava o comando sem chamar `startForeground()` — o Android encerra o processo com `ForegroundServiceDidNotStartInTimeException`. Agora toda ação promove o serviço a primeiro plano e, sem player, ele encerra em vez de ficar pendurado.
- **O "tenta de novo em 8 s" do vigia nunca acontecia.** `JarvisWatchdog.agendar()` usava o mesmo `PendingIntent` do alarme periódico, então cada agendamento sobrescrevia o anterior: fechar o app pelos recentes caía no ciclo de 15 minutos. O alarme rápido ganhou request code próprio (`90211`) e `cancelar()` limpa os dois.
- **Escuta presa em "Escuta em espera" ao fechar o app no meio de um comando.** A interface pausa a escuta para gravar o comando; se ela morresse antes de religar (app fechado pelos recentes, WebView morto), o serviço continuava vivo e o vigia não fazia nada, porque só reinicia serviço parado. Agora `onTaskRemoved` retoma a escuta na hora e ainda agenda a recuperação rápida.
- **Falha fatal deixava primeiro plano e notificação para sempre.** Sem escuta e com o app fechado ninguém religava, mas o serviço seguia em primeiro plano. Ele agora sai sozinho depois de dois minutos se ninguém religar.
- **Lembretes não voltavam depois de reiniciar o celular.** `JarvisAlarmScheduler.restaurar()` abortava no Android 12+ sem `SCHEDULE_EXACT_ALARM`, mas `setAlarmClock()` é isento dessa permissão (é tratado como alarme do usuário). A checagem saiu e a restauração volta a acontecer.
- **Interface e serviço discordavam quando o Android recusava o primeiro plano.** O plugin agora desfaz `desejaOuvir` e cancela o vigia quando o serviço não sobe, e o app não desliga mais a ativação por uma falha temporária de primeiro plano — ele avisa e tenta de novo em 20 s.
- **Evento "a escuta parou" com o app fechado** agora também desliga a chave na interface, em vez de abrir o app dizendo "ligado" com o microfone já liberado.
- Versão 1.10.1 (versionCode 10101), mesma assinatura de CI: instala por cima da 1.10.0.

## 1.10.0 — 2026-10-25
- **Personalidade num único ponto.** O tom do assistente passou a viver no objeto `PERSONALIDADE` (app.js): identidade, papel, traços, lealdade, tratamento, conversa, humor e limites. O prompt de sistema da nuvem e o do modelo local são montados a partir dele, então mudar o jeito do J.A.R.V.I.S. é editar um bloco — sem mexer na palavra de ativação, no perfil de voz ou nos comandos. O texto agora diz o que se espera dele: **formal, espirituoso e leal**, com humor seco e respeito formal sem servilismo.
- **A voz agora é conferida em voz alta, e vem ligada.** Com um perfil cadastrado (3 amostras) a conferência já começa ativa; dá para desmarcar. Na ativação, ele **fala** “Analisando sua voz, senhor. Um instante.”, só depois grava os 4 segundos e compara com o perfil salvo; se não reconhecer, recusa com uma frase e volta a esperar “Jarvis”.
- **Menos cobrança para o usuário.** Além do botão de desligar a escuta, a conferência de voz passou a ser exigida **uma vez por sessão** — no primeiro acesso e depois de ligar o celular (o `JarvisBootReceiver` avança o token em `JarvisPrefs`). Quem quiser em toda ativação troca em Ajustes ▸ Voz, no seletor “Quando conferir a voz”.
- **“Ligue para X” liga de verdade.** Antes o app montava `tel:` e caía no discador. Agora `JarvisUtilPlugin.ligar` usa `Intent.ACTION_CALL` com a permissão `CALL_PHONE` (pedida na hora), completando a chamada; se o Android negar ou o aparelho não tiver telefonia, abre o discador e **diz** que a ligação não foi completada, em vez de dar a entender que ligou.
- **“Coloque a música This I Love” começa a tocar.** A ação `tocar_musica` procura o arquivo na biblioteca do aparelho (`MediaStore`, ignorando acentos, pontuação e a ordem das palavras, com tolerância a erro de transcrição) e inicia a reprodução num **serviço em primeiro plano** com notificação, controles de tela bloqueada e `MediaSession` — continua tocando com o app fechado. As ações “pausar/continuar/próxima/anterior” passam a obedecer esse player antes de tentar a sessão de mídia do Android. Se a faixa **não existe no aparelho**, o app abre a busca de um app de streaming e diz com todas as letras que ali é preciso tocar no resultado: nenhum aplicativo de streaming aceita iniciar uma faixa sem conta autenticada, então prometer isso seria mentira.
- **O comando de voz de música deixou de abrir só a busca.** “Toca aquela música”, “coloca a música …” e “põe a faixa …” agora limpam o artigo e o substantivo do pedido (“a música”) e vão para o player local.
- **Economia em segundo plano.** Com o app fora da tela, o reconhecimento do WebView é encerrado e a fala em andamento é cancelada; quem continua escutando é só o serviço nativo, esperando a palavra de ativação. Nada de microfone aberto à toa.
- **Uma exceção não fecha mais o app.** `window.onerror` e `unhandledrejection` viraram um aviso no chat e uma linha no registro (até três avisos, para não virar enxurrada). A IA local, antes de carregar o modelo, confere a memória livre e transforma um `OutOfMemoryError` nativo — que fechava o processo sem explicação — em mensagem com o número de MB que faltam.
- **Permissões novas, todas justificadas:** `CALL_PHONE` (completar a ligação), `READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE` até o Android 12 (achar a música no aparelho) e `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (tocar com o app fechado). O player só lê áudio; nenhum arquivo é enviado para fora.
- Versão 1.10.0 (versionCode 10100), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.9.0.

## 1.9.0 — 2026-10-24
- **Voz neural no próprio aparelho (offline, sem chave).** O APK passou a embarcar o **sherpa-onnx 1.13.8** (Next-gen Kaldi, Apache-2.0): um AAR de ~50 MB com ONNX Runtime e espeak-ng compilados, baixado no build e conferido por SHA-256 (`baixar_sherpa.py`). Os **modelos de voz não vão dentro do APK** — somariam 200 MB por atualização. Cada voz é baixada uma vez, extraída para o armazenamento privado do app e depois usada sem internet; dá para apagar quando quiser.
- **Três vozes, com número medido e não com promessa.** Rodei as três neste mesmo sherpa-onnx, sintetizando “Boa noite, senhor. Todos os sistemas estão operacionais”:
  - **Cadu** (`vits-piper-pt_BR-cadu-medium`, 67 MB, 22,05 kHz, licença CC0): voz masculina brasileira, frequência fundamental mediana **127 Hz** (a mais grave das brasileiras) e **RTF 0,06** — ou seja, ~17× mais rápida que o tempo real nesta máquina. É a recomendada.
  - **Faber** (`vits-piper-pt_BR-faber-medium`, 67 MB, CC0): timbre mais claro, **155 Hz**, mesmo RTF. Fica como alternativa para quem achar a Cadu grave demais.
  - **Kokoro** (`kokoro-int8-multi-lang-v1_0`, 132 MB, Apache-2.0, 24 kHz): as vozes britânicas masculinas do Kokoro-82M. Medido: `bm_fable` **129 Hz**, `bm_george` **145 Hz**, `bm_lewis` **86 Hz**; **RTF 1,2–1,5** nesta máquina, isto é, mais lento que o tempo real — por isso a interface diz que essa voz é para respostas curtas e que num celular ela demora alguns segundos. É o timbre mais parecido com o do filme, mas **só fala inglês**.
- **O que não deu para fazer com o Kokoro, dito na cara.** `en-gb` **não existe** no espeak-ng empacotado com este modelo: com `lang=en-gb` a síntese volta **vazia** (testado). Com `lang=en` funciona, então o sotaque é americano e o timbre britânico vem do falante. O app usa `en` e explica isso na tela.
- **Tom e cadência ajustáveis.** O slider “Profundidade da voz neural” (0,70–1,10, padrão 0,90) reamostra o áudio gerado: abaixo de 1,00 a fala fica mais grave **e** mais lenta, que é exatamente a cadência arrastada do J.A.R.V.I.S. do cinema. A voz Piper já sai de fábrica com o `length_scale` neutro; o “peso” vem do tom.
- **Download com progresso, cancelamento e limpeza.** Barra com MB baixados/total, aviso de extração, botão de apagar a voz e “Liberar memória” (descarta o modelo da RAM sem apagar o arquivo). Falha de rede apaga o que ficou pela metade para não deixar um modelo corrompido no aparelho.
- **Queda automática para o TTS do Android.** Se o motor não estiver no aparelho, se a voz não estiver baixada ou se a síntese falhar, a resposta sai pela voz do sistema e o registro guarda o motivo. A voz neural nunca é obrigatória: o seletor começa em “Desligada — usar a voz do Android”.
- **Por que o detector de palavra-chave do sherpa-onnx continua desligado.** O único modelo público de KWS do projeto é o `kws-zipformer-gigaspeech` (17 MB), treinado em inglês; a 1.7.0 mediu **1 de 4** acertos em “Jarvis” falado em português e nenhum no limiar padrão. Além disso a palavra precisa ser codificada à mão em tokens BPE (`▁JA R VI S`) e um segundo laço de microfone brigaria com o detector atual. Então ele fica **opcional e fora**, com o motivo escrito na própria aba Voz — em vez de um botão que promete e não entrega.
- **APK maior, e por quê.** As bibliotecas nativas (arm64-v8a + armeabi-v7a) somam ~53 MB. Para não crescer mais, `abiFilters` corta as ABIs de emulador (x86/x86_64), que nenhum aparelho real usa. A assinatura de CI é a mesma: instala por cima da 1.8.0.
- Versão 1.9.0 (versionCode 1900), mesmo pacote `com.jarvis.nova`.

## 1.8.0 — 2026-10-24
- **Por que a palavra de ativação “não detectava” (causa medida, não suposição).** Rodei o Vosk de português com voz masculina brasileira (Piper Faber, 12 frases com “Jarvis” e 8 sem): a frase inteira é transcrita, mas “Jarvis” sai como **“já vi”**, **“aviso”**, **“javis”** ou **“charvis”** — a palavra não existe no vocabulário do transcritor. O detector grátis do Android usa esse mesmo tipo de transcritor, então ele abria o microfone, não achava a palavra e fechava. O laço não estava “quebrado”; o motor é que era surdo ao nome.
- **Detector grátis mais tolerante.** Agora pede **5 hipóteses** ao Android e confere **todas** (a palavra costuma aparecer numa delas), aceita mais variantes fonéticas (`javis`, `jarvy`, `jarves`, `charves`, `jar vis`…) e usa **sessões de até 15 s** com mais silêncio tolerado. Isso também acaba com o “pisca-pisca” do ícone de microfone, que antes abria e fechava a cada 200 ms.
- **Fim do religa-e-falha.** Quando a escuta falhava de forma fatal (idioma offline ausente, permissão negada, rede), o vigia continuava religando a cada 15 minutos para falhar de novo — microfone ligando e desligando sem nunca responder. Agora a falha desliga a preferência e cancela o vigia; só você religa.
- **Botão “Desligar escuta em segundo plano”** em Ajustes ▸ Voz, além do toggle do topo e do botão da notificação (agora “Desligar escuta”). Ele encerra o serviço, solta o microfone e cancela o vigia — nada volta sozinho. “Pausar” continua sendo a pausa momentânea.
- **A voz salva não muda mais sozinha.** A escolha era recalculada a cada abertura do app e podia trocar quando o motor de voz mudava. Agora é fixada; só é substituída se a voz realmente não estiver mais instalada, com aviso no registro. Se você escolher uma voz de outro idioma, o texto é falado nesse idioma em vez de misturar voz e idioma.
- **Perfil “Jarvis completo”** (tom 0,55 e velocidade 0,88) e busca de voz masculina ampliada (nomes brasileiros e britânicos, além de `pt_BR-faber`, `pt_BR-cadu` e `pt_BR-jeff`). A aba Voz explica como instalar uma voz masculina brasileira offline via Piper/SherpaTTS — é o caminho honesto para um timbre mais próximo do filme, porque o app não inventa um timbre que o motor do aparelho não tenha.
- **IA mais conversadora e com mais humor.** O prompt ganhou regras explícitas de fio da conversa, pergunta de esclarecimento quando o pedido é ambíguo, explicação causa/efeito, pesquisa com fontes primárias e o que não foi confirmado, e opinião própria. O humor seco/irônico entra a partir de 40% e fica mais afiado em 70%+. “Respostas curtas” deixou de vir ligado por padrão (era o que deixava tudo em 1 frase e sem personalidade).
- **Substitutos do Picovoice pesquisados e não embarcados, com motivo.** `sherpa-onnx`: o runtime Android tem KWS, mas **não existe modelo oficial de português** (só chinês, inglês e zh-en) — testado antes, erra a pronúncia brasileira. `openWakeWord`: treinado em inglês e os pesos prontos são **CC BY-NC-SA** (não comercial). `Voicute`: modelo “Jarvis” em inglês, download de modelo customizado é pago. `DaVoice`: modelo `.dm` licenciado pelo fornecedor, preço não público. `Rhino`/`Cheetah`: são intent/STT, não wake word, e também pedem AccessKey. Sem modelo pt-BR livre e confiável, embarcar 50 MB de engine que erra a palavra seria pior que dizer isso com clareza.
- Versão 1.8.0 (versionCode 1800), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.7.2.

## 1.7.2 — 2026-10-23
- **“Baixar e instalar” consertado.** O erro `Failed to find configured root that contains /data/data/com.jarvis.nova/files/updates/jarvis-update.apk` vinha de **dois** `FileProvider` com a mesma authority: o template do Capacitor já declara um apontando para `@xml/file_paths` (sem `files/`), e o patch adicionava outro. O Android ficava com o do template e recusava o APK baixado. `patch_manifest.py` agora remove qualquer `FileProvider` existente e deixa **um só**, apontando para `@xml/jarvis_paths` (`files-path updates/`), com teste de regressão em `tests/test_fileprovider.py`.
- Quem está na 1.5.1 precisa instalar esta versão uma vez pelo release (o botão interno ainda está quebrado nessa versão); da 1.7.2 em diante a atualização pelo app funciona.
- Versão 1.7.2 (versionCode 1702).

## 1.7.1 — 2026-10-23
- **Assinatura de release agora é fixa de verdade.** O workflow copiava `ci/debug.keystore` para `~/.android/debug.keystore`, mas o Gradle não usava esse arquivo em todos os casos: cada build de CI gerava uma chave de debug nova e as releases 1.6.0 (`40f8280e…`) e 1.7.0 (`b45d3f43…`) saíram com assinaturas diferentes entre si — o Android recusaria a atualização por cima. `patch_gradle.py` passou a declarar `signingConfigs.debug` apontando para `ci/debug.keystore` com as credenciais do keystore, e um teste garante que isso não se perca. Verificado com `HOME` limpo, sem `~/.android/debug.keystore`: o APK sai com o certificado `04e04712…`, o mesmo do app já instalado.
- Versão 1.7.1 (versionCode 1701). Nada de comportamento mudou em relação à 1.7.0.

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
