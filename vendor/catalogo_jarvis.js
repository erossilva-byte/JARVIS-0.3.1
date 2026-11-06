/* J.A.R.V.I.S. Nova — Catálogo de capacidades (dados da Central de Comandos).
 *
 * Traduz o catálogo do documento de referência (76 seções, 8 projetos) para o que ESTE
 * aplicativo faz. Cada item tem um estado declarado e uma ação real: abrir um painel que
 * existe, rodar um comando que o núcleo resolve, ou assumir que ainda não existe.
 *
 * Regra de honestidade: nada aqui é marcado como pronto sem uma ação que funcione de fato.
 * Item sem ação é marcado como 'falta' e diz o que seria necessário.
 *
 * Estados:
 *   pronto   funciona agora, com o app configurado
 *   offline  funciona sem internet e sem chave (módulo utilitarios.js)
 *   chave    depende de uma chave de IA configurada em IA Core
 *   aparelho depende do aparelho (câmera, microfone, segundo plano, Android)
 *   pc       só existe na versão de computador (Electron)
 *   falta    ainda não implementado neste aplicativo
 *
 * Arquivo de dados puro: roda em Node (testes) e no navegador/WebView do app.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisCatalogo = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const VERSAO = '1.0.0';

  const ESTADOS = {
    pronto: { rotulo: 'Funciona agora', curto: 'pronto', cor: '#3ddc97' },
    offline: { rotulo: 'Sem internet', curto: 'offline', cor: '#4aa8ff' },
    chave: { rotulo: 'Depende de chave', curto: 'chave', cor: '#ffc857' },
    aparelho: { rotulo: 'Depende do aparelho', curto: 'aparelho', cor: '#a78bfa' },
    pc: { rotulo: 'Só no computador', curto: 'pc', cor: '#17c8ff' },
    falta: { rotulo: 'Ainda não tem', curto: 'falta', cor: '#7b8a99' }
  };

  // p = painel do app que abre (data-lat), c = comando que o núcleo resolve,
  // a = ação de interface (deck | parar | log | config), n = o que falta / o que fazer.
  const AREAS = [
    {
      id: 'ia', nome: 'Inteligência', icone: '◈', painel: 'ia',
      resumo: 'Conversa, planos de várias etapas e agentes.',
      itens: [
        { t: 'Conversar por texto', e: 'pronto', d: 'Chat na tela, com histórico da sessão.', p: 'central' },
        { t: 'Conversar por voz', e: 'pronto', d: 'Você fala e ele responde em voz.', p: 'voz' },
        { t: 'Perguntas gerais à IA', e: 'chave', d: 'Groq, Cerebras, Mistral ou Gemini.', p: 'ia', n: 'Configure a chave em IA Core.' },
        { t: 'Planos de várias etapas', e: 'pronto', d: 'Divide o pedido, executa passo a passo e mostra recibo.', p: 'ia' },
        { t: 'Agentes especializados', e: 'pronto', d: 'Pesquisador, arquivos, agenda e outros.', p: 'ia' },
        { t: 'Recuperar conversa anterior', e: 'pronto', d: 'Memória por tópicos e resumo da sessão.', p: 'memoria' },
        { t: 'Trocar de provedor quando falha', e: 'pronto', d: 'Alterna entre os provedores configurados.', p: 'ia' },
        { t: 'Modelo local no aparelho', e: 'aparelho', d: 'Arquivo .task carregado no próprio celular.', p: 'ia', n: 'Só no Android, com o modelo instalado.' },
        { t: 'Escolher modelo pela complexidade', e: 'falta', d: 'Roteamento automático por custo e latência.', n: 'Hoje o provedor é escolhido nas configurações.' },
        { t: 'Executar código como solução', e: 'falta', d: 'REPL ou CodeAct dentro do app.', n: 'Exigiria um sandbox de execução isolado.' }
      ]
    },
    {
      id: 'voz', nome: 'Voz', icone: '◉', painel: 'voz',
      resumo: 'Escuta, fala e interrupção.',
      itens: [
        { t: 'Falar as respostas', e: 'pronto', d: 'Voz neural no aparelho.', p: 'voz' },
        { t: 'Palavra de ativação', e: 'pronto', d: 'Diga "Jarvis" para acordar.', p: 'voz' },
        { t: 'Detectar início e fim da fala', e: 'pronto', d: 'VAD: espera você terminar antes de responder.', p: 'voz' },
        { t: 'Interromper a fala', e: 'pronto', d: 'Cala o assistente na hora.', a: 'parar' },
        { t: 'Escolher a voz', e: 'pronto', d: 'Vozes diferentes por perfil.', p: 'voz' },
        { t: 'Testar o microfone', e: 'pronto', d: 'Mostra se o áudio está chegando.', p: 'voz' },
        { t: 'Conversa contínua', e: 'pronto', d: 'Continua escutando depois de responder.', p: 'voz' },
        { t: 'Escuta em segundo plano', e: 'aparelho', d: 'Serviço Android com notificação.', p: 'voz' },
        { t: 'Não ouvir a própria voz', e: 'pronto', d: 'Ignora o áudio que ele mesmo emite.', p: 'voz' },
        { t: 'Outros idiomas', e: 'aparelho', d: 'Depende do motor de voz instalado.', p: 'voz' },
        { t: 'Transcrição em nuvem', e: 'chave', d: 'Alternativa ao motor local.', p: 'voz', n: 'Precisa de provedor de voz configurado.' }
      ]
    },
    {
      id: 'visao', nome: 'Visão', icone: '⌖', painel: 'visao',
      resumo: 'Câmera, imagens e captura de tela.',
      itens: [
        { t: 'Câmera ao vivo', e: 'aparelho', d: 'Painel com a imagem do aparelho.', p: 'visao' },
        { t: 'Analisar uma foto', e: 'chave', d: 'Envia a imagem para o modelo.', p: 'visao' },
        { t: 'Descrever imagem', e: 'chave', d: 'Resumo do que aparece.', p: 'visao' },
        { t: 'Identificar objetos', e: 'chave', d: 'Reconhecimento por modelo.', p: 'visao' },
        { t: 'Ler texto em imagem', e: 'falta', d: 'OCR no aparelho.', n: 'Não há modelo de OCR embutido.' },
        { t: 'Capturar a tela do PC', e: 'pc', d: 'Print da tela para análise ou arquivo.', p: 'pc' },
        { t: 'Gestos com as mãos', e: 'falta', d: 'Controle por câmera (palma, joinha, pinça).', n: 'Precisa de MediaPipe e calibração.' },
        { t: 'Gerar imagens', e: 'falta', d: 'Criar imagem a partir de descrição.', n: 'Exigiria serviço de geração e chave própria.' }
      ]
    },
    {
      id: 'android', nome: 'Celular', icone: '▰', painel: 'celular',
      resumo: 'Aplicativos, alarmes e controles do aparelho.',
      itens: [
        { t: 'Abrir aplicativos', e: 'pronto', d: 'WhatsApp, YouTube, Maps e outros cadastrados.', p: 'celular' },
        { t: 'Lanterna', e: 'pronto', d: 'Liga e desliga pelo comando.', p: 'celular' },
        { t: 'Volume do aparelho', e: 'pronto', d: 'Ajusta o volume de mídia.', p: 'celular' },
        { t: 'Brilho da tela', e: 'aparelho', d: 'Depende da permissão de configurações.', p: 'celular' },
        { t: 'Alarmes e lembretes', e: 'pronto', d: 'Agenda no sistema e toca na hora.', p: 'tarefas' },
        { t: 'Ler notificações', e: 'aparelho', d: 'Exige permissão de acesso a notificações.', a: 'config' },
        { t: 'Chamadas e SMS', e: 'pronto', d: 'Prepara a chamada ou a mensagem.', p: 'celular' },
        { t: 'Mapas e rotas', e: 'pronto', d: 'Abre o destino no Google Maps.', p: 'celular' },
        { t: 'Música', e: 'pronto', d: 'Reproduz e controla faixas.', p: 'celular' },
        { t: 'Status do celular', e: 'pronto', d: 'Bateria, rede e armazenamento.', p: 'celular' },
        { t: 'Controlar outros apps pela tela', e: 'falta', d: 'Clicar em botões de aplicativos de terceiros.', n: 'Exige serviço de acessibilidade; o Android restringe e pode bloquear.' },
        { t: 'Controle de televisão', e: 'falta', d: 'Android TV por rede.', n: 'Exigiria ADB sem fio e pareamento.' }
      ]
    },
    {
      id: 'pc', nome: 'Computador', icone: '▣', painel: 'pc',
      resumo: 'Arquivos, CAD e estado da máquina.',
      itens: [
        { t: 'Ler e editar arquivos', e: 'pc', d: 'Só dentro da sua pasta de usuário.', p: 'pc' },
        { t: 'Organizar e converter arquivos', e: 'pc', d: 'Plano antes de aplicar, com backup.', p: 'pc' },
        { t: 'CAD: abrir e exportar', e: 'pc', d: 'DXF, STL, 3MF, STEP, IFC e .cad.', p: 'pc' },
        { t: 'Status do computador', e: 'pc', d: 'CPU, memória, disco e tempo ligado.', p: 'pc' },
        { t: 'Captura de tela', e: 'pc', d: 'Salva a tela em arquivo.', p: 'pc' },
        { t: 'Cofre do Obsidian', e: 'pc', d: 'Notas em Markdown na pasta que você escolher.', p: 'pc' },
        { t: 'Travar ou desligar', e: 'pc', d: 'Com confirmação antes.', p: 'pc' },
        { t: 'Área de transferência', e: 'pc', d: 'Lê e copia texto.', p: 'pc' },
        { t: 'Abrir programas', e: 'pc', d: 'Lista branca de aplicativos cadastrados.', p: 'pc' },
        { t: 'Tarefas de várias etapas', e: 'pc', d: 'Executa passos permitidos e relata cada um.', p: 'pc' },
        { t: 'Controlar janelas e mouse', e: 'falta', d: 'Mover janelas, clicar e digitar por você.', n: 'Exigiria permissão de acessibilidade do sistema.' },
        { t: 'Ligar o PC pelo celular', e: 'falta', d: 'Wake-on-LAN.', n: 'Precisa da placa de rede com WoL ativa e da rede certa.' }
      ]
    },
    {
      id: 'memoria', nome: 'Memória', icone: '◫', painel: 'memoria',
      resumo: 'O que ele lembra e quem ele reconhece.',
      itens: [
        { t: 'Notas por tópico', e: 'pronto', d: 'Grava o que importa e consulta depois.', p: 'memoria' },
        { t: 'Buscar na memória', e: 'pronto', d: 'Procura por assunto nas notas.', p: 'memoria' },
        { t: 'Pessoas conhecidas', e: 'pronto', d: 'Cadastro com nome e rosto.', p: 'pessoas' },
        { t: 'Reconhecer a voz do dono', e: 'pronto', d: 'Confirma quem está falando.', p: 'pessoas' },
        { t: 'Apagar uma memória', e: 'pronto', d: 'Remove o que não deve mais ser usado.', p: 'memoria' },
        { t: 'Resumo ao encerrar a sessão', e: 'pronto', d: 'Fecha o dia com o que foi tratado.', p: 'memoria' },
        { t: 'Perguntar sobre documentos', e: 'falta', d: 'RAG sobre seus arquivos.', n: 'Exige indexação de documentos.' },
        { t: 'Busca por significado', e: 'falta', d: 'Busca vetorial, não só por palavra.', n: 'Exigiria modelo de embeddings.' },
        { t: 'Sincronizar celular e PC', e: 'falta', d: 'A mesma memória nos dois.', n: 'Hoje dá para exportar e importar .md.' }
      ]
    },
    {
      id: 'produtividade', nome: 'Produtividade', icone: '▤', painel: 'tarefas',
      resumo: 'Tarefas, rotinas e agenda.',
      itens: [
        { t: 'Lista de tarefas', e: 'pronto', d: 'Criar, concluir e remover.', p: 'tarefas' },
        { t: 'Rotinas automáticas', e: 'pronto', d: 'Sequências disparadas por horário ou comando.', p: 'rotinas' },
        { t: 'Planos com etapas', e: 'pronto', d: 'Objetivo grande dividido em passos.', p: 'ia' },
        { t: 'Agenda e calendário', e: 'falta', d: 'Compromissos com sincronização.', n: 'Não há integração com calendário externo.' },
        { t: 'Briefing matinal', e: 'falta', d: 'Resumo do dia ao acordar.', n: 'Depende de agenda e notícias integradas.' },
        { t: 'Modo foco', e: 'falta', d: 'Silenciar e concentrar por um período.', n: 'Não implementado.' },
        { t: 'Trello', e: 'falta', d: 'Quadros, listas e cartões.', n: 'Exigiria token da API do Trello.' },
        { t: 'E-mail', e: 'falta', d: 'Ler e resumir mensagens.', n: 'Exigiria OAuth do provedor de e-mail.' },
        { t: 'Atalhos de teclado', e: 'pronto', d: 'Ctrl+K abre a Central; Esc fecha.', a: 'deck' }
      ]
    },
    {
      id: 'pesquisa', nome: 'Pesquisa', icone: 'ⓘ', painel: 'info',
      resumo: 'Clima, manchetes e fontes.',
      itens: [
        { t: 'Clima e previsão', e: 'pronto', d: 'Open-Meteo, sem chave.', p: 'info' },
        { t: 'Manchetes do momento', e: 'pronto', d: 'Notícias na tela de informações.', p: 'info' },
        { t: 'Consultar Wikipédia', e: 'pronto', d: 'Resumo de verbetes.', p: 'info' },
        { t: 'Buscar na web', e: 'chave', d: 'Abre a pesquisa e resume com o modelo.', p: 'ia', n: 'O resumo precisa de chave de IA.' },
        { t: 'Notícias por assunto', e: 'falta', d: 'Filtrar por tema e acompanhar.', n: 'Exigiria fonte de notícias por tema.' },
        { t: 'Comparar preços', e: 'falta', d: 'Produtos lado a lado.', n: 'Depende de serviço de preços.' },
        { t: 'Esportes', e: 'falta', d: 'Placar, tabela e horários.', n: 'Depende de fonte esportiva.' },
        { t: 'Monitorar um assunto', e: 'falta', d: 'Avisar quando houver novidade.', n: 'Exigiria verificações agendadas com fonte.' }
      ]
    },
    {
      id: 'utilitarios', nome: 'Utilitários', icone: '∑', painel: 'central',
      resumo: 'Contas, conversões, QR e jogos — tudo sem internet.',
      itens: [
        { t: 'Calcular IMC', e: 'offline', d: 'Com a classificação da OMS para adultos.', c: 'calcule meu IMC, 80 kg e 1,80 m' },
        { t: 'Converter unidades', e: 'offline', d: 'Comprimento, massa, volume, velocidade, tempo e dados.', c: 'converta 10 km para milhas' },
        { t: 'Converter temperatura', e: 'offline', d: 'Celsius, Fahrenheit e Kelvin.', c: 'converta 30 celsius para fahrenheit' },
        { t: 'Bases numéricas', e: 'offline', d: 'Decimal, binário e hexadecimal.', c: 'converta 10 decimal para binário' },
        { t: 'Gerar QR Code', e: 'offline', d: 'Desenhado no aparelho, sem internet.', c: 'gere um QR Code de jarvis nova' },
        { t: 'Piadas', e: 'offline', d: 'Vinte e quatro, originais.', c: 'me conta uma piada' },
        { t: 'Curiosidades', e: 'offline', d: 'Vinte e quatro fatos curtos.', c: 'conte uma curiosidade' },
        { t: 'Jogo da velha', e: 'offline', d: 'Ele joga para ganhar e para bloquear.', c: 'jogo da velha' },
        { t: 'Adivinhação', e: 'offline', d: 'Número de 1 a 100 com dicas.', c: 'adivinhe um número' },
        { t: 'Pedra, papel e tesoura', e: 'offline', d: 'Partida única, resultado na hora.', c: 'jogue pedra papel tesoura' },
        { t: 'Dados e moeda', e: 'offline', d: 'Um ou dois dados; cara ou coroa.', c: 'jogue um dado' },
        { t: 'Sortear número', e: 'offline', d: 'Sorteio dentro da faixa que você pedir.', c: 'sorteie um número de 1 a 60' },
        { t: 'Metabolismo basal', e: 'falta', d: 'Gasto calórico em repouso.', n: 'Não implementado ainda.' },
        { t: 'Conversão de moedas', e: 'falta', d: 'Real, dólar, euro.', n: 'Exige cotação do dia; inventar número seria pior.' },
        { t: 'Senhas aleatórias', e: 'falta', d: 'Gerador com regras.', n: 'Não implementado ainda.' },
        { t: 'Equações e matrizes', e: 'falta', d: 'Resolver e fatorar.', n: 'Não implementado ainda.' }
      ]
    },
    {
      id: 'seguranca', nome: 'Segurança', icone: '⌘', painel: 'diagnostico',
      resumo: 'Chaves, confirmações e diagnóstico.',
      itens: [
        { t: 'Cofre de chaves cifrado', e: 'pronto', d: 'Chaves guardadas pelo próprio sistema.', p: 'ia' },
        { t: 'Confirmar antes de agir', e: 'pronto', d: 'Ações sensíveis pedem confirmação.', p: 'ia' },
        { t: 'Lista branca de ações no PC', e: 'pc', d: 'O app não executa comando de sistema livre.', p: 'pc' },
        { t: 'Registro de ações', e: 'pronto', d: 'Histórico do que foi feito.', a: 'log' },
        { t: 'Diagnóstico do sistema', e: 'pronto', d: 'Mostra o que está configurado e o que falta.', p: 'diagnostico' },
        { t: 'Interromper tudo', e: 'pronto', d: 'Para fala, câmera e tarefas.', a: 'parar' },
        { t: 'Desfazer a última ação', e: 'falta', d: 'Reverter arquivos e ajustes.', n: 'Arquivos já têm backup .bak; falta o desfazer geral.' },
        { t: 'Permissões do Android', e: 'pronto', d: 'Veja o que está concedido.', a: 'config' }
      ]
    },
    {
      id: 'dev', nome: 'Desenvolvimento', icone: '▦', painel: 'dev',
      resumo: 'Analisar, explicar e corrigir código.',
      itens: [
        { t: 'Analisar arquivo ou projeto', e: 'pronto', d: 'Recebe, analisa e organiza.', p: 'dev' },
        { t: 'Explicar código', e: 'chave', d: 'Explicação em linguagem simples.', p: 'dev' },
        { t: 'Corrigir código', e: 'chave', d: 'Aponta e sugere a correção.', p: 'dev' },
        { t: 'Exportar pacote do projeto', e: 'pronto', d: 'Gera o pacote para levar embora.', p: 'dev' },
        { t: 'Executar código', e: 'falta', d: 'Rodar Python ou JavaScript.', n: 'Exigiria sandbox; o app não executa código.' },
        { t: 'REPL persistente', e: 'falta', d: 'Sessão de código que guarda estado.', n: 'Não implementado.' }
      ]
    },
    {
      id: 'interface', nome: 'Interface', icone: '◎', painel: 'config',
      resumo: 'HUD, temas e atalhos.',
      itens: [
        { t: 'Central de Comandos', e: 'pronto', d: 'Esta tela: tudo o que o app faz em um lugar.', a: 'deck' },
        { t: 'Busca em tudo', e: 'pronto', d: 'Procura por nome, assunto e comando.', a: 'deck' },
        { t: 'Atalho Ctrl+K / ⌘K', e: 'pronto', d: 'Abre a Central de qualquer lugar.', a: 'deck' },
        { t: 'Layout para celular e PC', e: 'pronto', d: 'Gaveta no celular, painel em colunas no PC.', a: 'deck' },
        { t: 'Núcleo 3D e HUD', e: 'pronto', d: 'Anel, órbita e animação.', p: 'central' },
        { t: 'Temas e cor de destaque', e: 'pronto', d: 'Ajustes de aparência.', a: 'config' },
        { t: 'Painéis por área', e: 'pronto', d: 'Uma tela por assunto.', p: 'central' },
        { t: 'Avatar com sincronia labial', e: 'falta', d: 'Rosto animado que acompanha a fala.', n: 'Temos o núcleo 3D, não um rosto falante.' },
        { t: 'Gestos na tela', e: 'falta', d: 'Arrastar cartões e reordenar.', n: 'Não implementado.' }
      ]
    }
  ];

  const semAcento = (t) => String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const norm = (t) => semAcento(t).toLowerCase().replace(/\s+/g, ' ').trim();

  // Lista achatada, útil para busca e contagem.
  function todos() {
    const saida = [];
    AREAS.forEach((a) => a.itens.forEach((it) => {
      saida.push({
        t: it.t, e: it.e, d: it.d, p: it.p, c: it.c, a: it.a, n: it.n,
        area: a.id, areaNome: a.nome, icone: a.icone
      });
    }));
    return saida;
  }

  function porArea(id) {
    const a = AREAS.find((x) => x.id === id);
    return a ? a.itens.slice() : [];
  }

  function contar() {
    const c = {};
    Object.keys(ESTADOS).forEach((k) => { c[k] = 0; });
    todos().forEach((it) => { c[it.e] = (c[it.e] || 0) + 1; });
    return c;
  }

  function buscar(termo) {
    const q = norm(termo);
    const lista = todos();
    if (!q) return lista;
    const partes = q.split(' ');
    return lista.filter((it) => {
      const alvo = norm(it.t + ' ' + it.d + ' ' + it.areaNome + ' ' + (it.n || '') + ' ' + (it.c || ''));
      return partes.every((p) => alvo.indexOf(p) >= 0);
    });
  }

  // O que a plataforma atual consegue rodar de fato.
  function estadoNaPlataforma(estado, plataforma) {
    if (estado === 'pc' && plataforma !== 'pc') return 'falta';
    return estado;
  }

  return {
    VERSAO: VERSAO,
    ESTADOS: ESTADOS,
    AREAS: AREAS,
    todos: todos,
    porArea: porArea,
    contar: contar,
    buscar: buscar,
    estadoNaPlataforma: estadoNaPlataforma,
    normalizar: norm
  };
});
