/// Situação real de cada módulo do catálogo — texto puro, sem Flutter.
///
/// O catálogo listava 25 módulos e a tela de 24 deles mostrava o mesmo aviso
/// âmbar de auditoria, inclusive nos que já tinham tela pronta. Isso
/// confundia duas coisas diferentes: “não existe” e “existe e abre”. Aqui cada
/// módulo tem um estado e uma frase própria, e o motivo de ausência diz o que
/// falta de verdade — sem prometer ponte que não foi compilada.
library;

/// O que a pessoa encontra ao abrir o módulo.
enum EstadoModulo {
  /// Tem tela funcionando neste APK.
  pronto,

  /// Parte funciona e parte depende de algo declarado no detalhe.
  parcial,

  /// Não existe neste APK; o detalhe diz exatamente o que falta.
  ausente,
}

/// Tela que o módulo abre, quando abre alguma.
///
/// Fica em enum (e não em Widget) para o contrato poder ser testado sem
/// aparelho e para [pages.dart] decidir a rota.
enum TelaModulo {
  nenhuma,
  provedores,
  hermes,
  agentes,
  modelosLocais,
  habilidades,
  kws,
  visao,
  arquivos,
  cadesimu,
  projetoPorPrompt,
  timbre,
  vozExterna,
  gestos,
  tarefas,
  seguranca,
  android,
  segundoPlano,
  atualizacoes,
}

class SituacaoModulo {
  const SituacaoModulo({
    required this.nome,
    required this.estado,
    required this.titulo,
    required this.detalhe,
    this.tela = TelaModulo.nenhuma,
    this.onde = '',
  });

  /// Nome igual ao do catálogo — é a chave da tabela.
  final String nome;
  final EstadoModulo estado;

  /// Frase curta do cartão de estado.
  final String titulo;

  /// O que funciona, o que não funciona e por quê.
  final String detalhe;

  /// Tela aberta pelo botão principal; [TelaModulo.nenhuma] quando não há.
  final TelaModulo tela;

  /// Onde a tela mora, quando ela existe fora deste módulo (gaveta, outra aba).
  final String onde;
}

/// Rótulo curto do estado, para o cartão.
String rotuloEstado(EstadoModulo estado) {
  switch (estado) {
    case EstadoModulo.pronto:
      return 'Funciona neste aparelho';
    case EstadoModulo.parcial:
      return 'Funciona em parte';
    case EstadoModulo.ausente:
      return 'Não existe neste APK';
  }
}

/// A tabela dos 25 módulos do catálogo, na mesma ordem de `catalog.dart`.
const situacoesModulos = <SituacaoModulo>[
  SituacaoModulo(
    nome: 'Hermes Agent',
    estado: EstadoModulo.pronto,
    titulo: 'Plano local e execução pelo provedor',
    detalhe: 'O Hermes escolhe o agente do domínio, decompõe o pedido em passos '
        'e mostra o plano antes de executar. A execução usa o provedor de IA que '
        'você configurou; sem chave, o plano aparece e a tela diz que falta a '
        'chave, em vez de fingir que respondeu.',
    tela: TelaModulo.hermes,
  ),
  SituacaoModulo(
    nome: 'Provedores de IA',
    estado: EstadoModulo.pronto,
    titulo: 'Chaves no cofre do aparelho',
    detalhe: 'Cadastro, teste e remoção de chave, com escolha de modelo por '
        'provedor. A chave fica no armazenamento seguro e nunca volta para a '
        'tela.',
    tela: TelaModulo.provedores,
  ),
  SituacaoModulo(
    nome: 'Modelos locais',
    estado: EstadoModulo.ausente,
    titulo: 'Sem motor de modelo local neste APK',
    detalhe: 'Não há llama.cpp, GGUF nem pesos empacotados: este build responde '
        'pelo provedor configurado. A tela mostra o que o aparelho tem e o que '
        'falta para operar offline; nada é baixado sem você mandar.',
    tela: TelaModulo.modelosLocais,
  ),
  SituacaoModulo(
    nome: 'Agentes especializados',
    estado: EstadoModulo.pronto,
    titulo: '12 agentes com roteamento por domínio',
    detalhe: 'Cada pedido cai no agente do domínio — eletrônica, engenharia, '
        'arquivos, memória, visão, dispositivo e os demais. A tela lista os '
        'domínios e mostra para onde o texto que você digitar vai.',
    tela: TelaModulo.agentes,
  ),
  SituacaoModulo(
    nome: 'Memória semântica',
    estado: EstadoModulo.pronto,
    titulo: 'Notas e busca no aparelho',
    detalhe: 'A memória grava notas locais e a busca recupera por assunto. A '
        'tela fica na gaveta, em Memória.',
    onde: 'Gaveta → Memória',
  ),
  SituacaoModulo(
    nome: 'Obsidian',
    estado: EstadoModulo.parcial,
    titulo: 'Cofre lido e gravado; sincronização tem tela própria',
    detalhe: 'Ler e gravar o cofre do Obsidian funciona pela pasta escolhida. A '
        'sincronização automática, os conflitos e os backups de conflito ficam '
        'na gaveta, em Memória → Sincronização e Conflitos.',
    onde: 'Gaveta → Memória → Sincronização',
  ),
  SituacaoModulo(
    nome: 'Habilidades em Markdown',
    estado: EstadoModulo.pronto,
    titulo: 'Skills/*.md carregadas do aparelho',
    detalhe: 'Os procedimentos em Markdown são lidos da pasta do app e entram no '
        'pedido quando casam com a pergunta.',
    tela: TelaModulo.habilidades,
  ),
  SituacaoModulo(
    nome: 'Voz e KWS',
    estado: EstadoModulo.pronto,
    titulo: 'Fala, timbre e palavra de ativação',
    detalhe: 'A voz fala no aparelho, o timbre tem três perfis, a palavra de '
        'ativação aceita frases em português e existe a voz externa por ID. O '
        'detector acústico continua sendo um modelo inglês: isso está escrito na '
        'tela.',
    tela: TelaModulo.kws,
  ),
  SituacaoModulo(
    nome: 'Visão e OCR',
    estado: EstadoModulo.pronto,
    titulo: 'Câmera, imagem e texto na tela',
    detalhe: 'A câmera e a imagem escolhida são analisadas com o seu '
        'consentimento; o OCR roda sobre o quadro enviado.',
    tela: TelaModulo.visao,
  ),
  SituacaoModulo(
    nome: 'Arquivos',
    estado: EstadoModulo.pronto,
    titulo: 'Pasta isolada do app',
    detalhe: 'Criar, ler e converter arquivos de texto dentro da pasta do app. '
        'Nada é executado: arquivo é dado, não programa.',
    tela: TelaModulo.arquivos,
  ),
  SituacaoModulo(
    nome: 'Programação (sem execução)',
    estado: EstadoModulo.ausente,
    titulo: 'Execução de código não disponível',
    detalhe: 'Não há sandbox, terminal ou permissão para rodar programas. Esta '
        'interface não executa código; os arquivos de texto ficam em Arquivos, na '
        'pasta isolada do app.',
  ),
  SituacaoModulo(
    nome: 'CADeSIMU e elétrica',
    estado: EstadoModulo.pronto,
    titulo: 'Importar, simular e criar por prompt',
    detalhe: 'O importador lê o .cad em somente leitura, o simulador calcula '
        'tensão e corrente dos esquemas montados e o projetista monta um circuito '
        'a partir do seu texto. O .cad nativo do CADeSIMU continua não sendo '
        'gerado: é formato proprietário.',
    tela: TelaModulo.cadesimu,
  ),
  SituacaoModulo(
    nome: 'Avatar 3D',
    estado: EstadoModulo.ausente,
    titulo: 'Holograma em 2D, sem modelo 3D',
    detalhe: 'A tela desenha o holograma do núcleo em 2D. Não há malha 3D nem '
        'renderizador 3D neste APK; um avatar articulado exigiria um modelo e um '
        'motor de renderização que não estão aqui.',
  ),
  SituacaoModulo(
    nome: 'Perfis de timbre',
    estado: EstadoModulo.pronto,
    titulo: 'Grave, natural e ágil',
    detalhe: 'Três perfis de tom e ritmo da voz do aparelho, gravados e valendo '
        'também com o app fechado.',
    tela: TelaModulo.timbre,
  ),
  SituacaoModulo(
    nome: 'Gestos e modo noturno',
    estado: EstadoModulo.pronto,
    titulo: 'Virar para calar e voz baixa',
    detalhe: 'Virar o celular cala a fala e o modo noturno baixa o volume da voz '
        'sem silenciar o assistente.',
    tela: TelaModulo.gestos,
  ),
  SituacaoModulo(
    nome: 'Pessoas e contexto',
    estado: EstadoModulo.pronto,
    titulo: 'Fichas de pessoas no aparelho',
    detalhe: 'Fichas com nome, tratamento e contexto, guardadas localmente e '
        'usadas na conversa. A tela fica na gaveta, em Pessoas.',
    onde: 'Gaveta → Pessoas',
  ),
  SituacaoModulo(
    nome: 'Tarefas e rotinas',
    estado: EstadoModulo.pronto,
    titulo: 'Tarefas que sobrevivem ao fechamento',
    detalhe: 'Tarefas com prazo, lembrete na agenda do aparelho e rotinas '
        'guardadas no aparelho.',
    tela: TelaModulo.tarefas,
  ),
  SituacaoModulo(
    nome: 'Segurança e privacidade',
    estado: EstadoModulo.pronto,
    titulo: 'Bloqueio, PIN e biometria',
    detalhe: 'Tela de bloqueio com PIN, biometria do aparelho e modos que exigem '
        'mais de um fator. O PIN não é guardado em texto puro.',
    tela: TelaModulo.seguranca,
  ),
  SituacaoModulo(
    nome: 'Android e dispositivos',
    estado: EstadoModulo.pronto,
    titulo: 'Comandos, aparelho e acessibilidade',
    detalhe: 'Comandos do Android, central do aparelho, leitura de tela por '
        'acessibilidade e voz com o app fechado.',
    tela: TelaModulo.android,
  ),
  SituacaoModulo(
    nome: 'Pareamento Windows',
    estado: EstadoModulo.ausente,
    titulo: 'Falta o canal autenticado',
    detalhe: 'Não existe pareamento neste APK: falta o canal autenticado entre '
        'celular e computador, com chave trocada, expiração e revogação. Sem '
        'isso, nada de controle remoto.',
  ),
  SituacaoModulo(
    nome: 'Controle do Windows',
    estado: EstadoModulo.ausente,
    titulo: 'Depende do pareamento',
    detalhe: 'Só faz sentido depois do pareamento autenticado, que ainda não '
        'existe. Não há atalho que finja controlar o computador.',
  ),
  SituacaoModulo(
    nome: 'ESP32 e Home Assistant',
    estado: EstadoModulo.ausente,
    titulo: 'Sem ponte HTTP/MQTT',
    detalhe: 'Não há cliente HTTP nem MQTT para automação residencial neste '
        'build, e nenhum dispositivo é anunciado como conectado.',
  ),
  SituacaoModulo(
    nome: 'Backup e restauração',
    estado: EstadoModulo.parcial,
    titulo: 'Backup de conflito; pacote completo ainda não',
    detalhe: 'A memória guarda backup antes de sobrescrever em conflito. Exportar '
        'e restaurar tudo — preferências, pessoas, tarefas e cofre — ainda não '
        'tem tela.',
    onde: 'Gaveta → Memória → Conflitos',
  ),
  SituacaoModulo(
    nome: 'Atualizações',
    estado: EstadoModulo.pronto,
    titulo: 'Versão, integridade e download',
    detalhe: 'Confere a versão instalada, o hash do pacote e conduz a atualização '
        'pelo APK assinado.',
    tela: TelaModulo.atualizacoes,
  ),
  SituacaoModulo(
    nome: 'Personalização',
    estado: EstadoModulo.pronto,
    titulo: 'Tratamento, humor e voz',
    detalhe: 'Tratamento, humor e preferências de fala. A tela fica na gaveta, em '
        'Personalidade.',
    onde: 'Gaveta → Personalidade',
  ),
];

/// Situação do módulo pelo nome; módulo desconhecido não promete nada.
SituacaoModulo situacaoDe(String nome) {
  for (final situacao in situacoesModulos) {
    if (situacao.nome == nome) return situacao;
  }
  return SituacaoModulo(
    nome: nome,
    estado: EstadoModulo.ausente,
    titulo: 'Módulo fora da tabela de estado',
    detalhe: 'Este módulo não tem situação declarada. Nada aqui afirma que ele '
        'esteja conectado ou operacional.',
  );
}

/// Quantos módulos existem em cada estado — usado na central e nos testes.
Map<EstadoModulo, int> contagemPorEstado([Iterable<String>? nomes]) {
  final conta = {for (final e in EstadoModulo.values) e: 0};
  final alvos = nomes ?? situacoesModulos.map((s) => s.nome);
  for (final nome in alvos) {
    final estado = situacaoDe(nome).estado;
    conta[estado] = conta[estado]! + 1;
  }
  return conta;
}
