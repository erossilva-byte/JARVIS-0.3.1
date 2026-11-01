/* J.A.R.V.I.S. Nova 1.33.0 — camada de navegação por áreas.
 *
 * Este arquivo NÃO substitui os painéis existentes: ele organiza o acesso a eles e
 * aplica os modos de interface. Toda ação real continua em app.js, que registra
 * window.JarvisNavegacao.acao(nome). Se o app.js ainda não carregou, o clique é
 * ignorado com uma mensagem visível, em vez de fingir que a ação funcionou.
 */
(function (raiz, doc) {
  'use strict';

  var CHAVE_MODO = 'jv_modo_interface';
  var MODO_PADRAO = 'completo';
  var MODOS = {
    completo: {
      nome: 'Completo',
      icone: '◎',
      desc: 'Núcleo, painéis e todos os recursos.'
    },
    discreto: {
      nome: 'Discreto',
      icone: '◌',
      desc: 'Interface reduzida; menos distração visual.'
    },
    silencioso: {
      nome: 'Silencioso',
      icone: '◍',
      desc: 'As respostas aparecem em texto, sem fala.'
    },
    holografico: {
      nome: 'Holográfico',
      icone: '◇',
      desc: 'Camada visual 3D mais intensa e luminosa.'
    }
  };

  var AREAS = [
    {
      id: 'inicio', nome: 'Início', icone: '◎',
      desc: 'Núcleo, status, conversa e atividades.',
      acoes: [
        { rot: 'Conversa', acao: 'conversa', desc: 'Abrir o histórico e o campo de comando.' },
        { rot: 'Atividades e tarefas', acao: 'tarefas', desc: 'Ver o que está em andamento e o que foi concluído.' },
        { rot: 'Registro de ações', acao: 'log', desc: 'Auditar operações, erros e decisões recentes.' },
        { rot: 'Status do celular', acao: 'celular', desc: 'Bateria, RAM, armazenamento e conexões.' },
        { rot: 'Parar tudo', acao: 'parar', desc: 'Interromper fala, câmera, automação e tarefas.', perigo: true }
      ]
    },
    {
      id: 'ia', nome: 'Inteligência artificial', icone: '◈',
      desc: 'Provedores, modelos, agentes e diagnóstico.',
      acoes: [
        { rot: 'Provedores e chaves', acao: 'config-ia', desc: 'Groq, Cerebras, Mistral e Gemini.' },
        { rot: 'Modelos locais', acao: 'config-ia', desc: 'Importar e testar um modelo MediaPipe .task.' },
        { rot: 'JARVIS Core', acao: 'core', desc: 'Agentes, contexto, projetos, saúde e habilidades.' },
        { rot: 'Diagnóstico dos provedores', acao: 'config-diagnostico', desc: 'Verificar rede, chaves e resposta real.' }
      ]
    },
    {
      id: 'voz', nome: 'Voz e microfone', icone: '◉',
      desc: 'Reconhecimento, síntese, ativação e áudio.',
      acoes: [
        { rot: 'Reconhecimento e VAD', acao: 'config-voz', desc: 'Sensibilidade, microfone, teste de ruído e modo contínuo.' },
        { rot: 'Síntese e voz neural', acao: 'config-voz', desc: 'Perfis, tom, velocidade e vozes offline.' },
        { rot: 'Palavra de ativação', acao: 'config-voz', desc: 'Detector próprio e escuta em segundo plano.' },
        { rot: 'Identificação de locutor', acao: 'pessoas', desc: 'Perfis de pessoas e autorização de voz.' },
        { rot: 'Microfone e diagnóstico', acao: 'sistema', desc: 'Entrada selecionada, nível, pico e clipes.' }
      ]
    },
    {
      id: 'automacao', nome: 'Automação', icone: '⚡',
      desc: 'Rotinas, tarefas, acessibilidade e histórico.',
      acoes: [
        { rot: 'Rotinas', acao: 'config-rotinas', desc: 'Criar e revisar automações por gatilho.' },
        { rot: 'Tarefas', acao: 'tarefas', desc: 'Lista local de tarefas e prazos.' },
        { rot: 'Acessibilidade Android', acao: 'acessibilidade', desc: 'Ler tela, clicar, digitar, rolar e parar.' },
        { rot: 'Tarefas persistentes', acao: 'sistema', desc: 'Checkpoints, retomada e etapas incertas.' },
        { rot: 'Histórico de execuções', acao: 'log', desc: 'Ver o que foi executado e o que falhou.' }
      ]
    },
    {
      id: 'memoria', nome: 'Memória', icone: '◫',
      desc: 'Notas, pessoas, preferências e Obsidian.',
      acoes: [
        { rot: 'Memória conectada', acao: 'memoria', desc: 'Notas por tema, busca e espaço usado.' },
        { rot: 'Pessoas', acao: 'pessoas', desc: 'Perfis, rostos e identificação autorizada.' },
        { rot: 'Preferências e Obsidian', acao: 'config-memoria', desc: 'Cofre local, memória pessoal e backup.' },
        { rot: 'Histórico de conversas', acao: 'conversa', desc: 'Retomar o contexto da conversa.' }
      ]
    },
    {
      id: 'ferramentas', nome: 'Ferramentas e arquivos', icone: '▧',
      desc: 'Arquivos, CAD, documentos e ferramentas locais.',
      acoes: [
        { rot: 'Arquivos e CAD', acao: 'arquivos', desc: 'Abrir arquivos, projetos e pacotes CAD.' },
        { rot: 'Desenvolvimento', acao: 'dev', desc: 'Receber, analisar, corrigir e exportar arquivos.' },
        { rot: 'Ferramentas do núcleo', acao: 'sistema', desc: 'Calculadora, conversões, senha, JSON, SHA-256 e datas.' },
        { rot: 'Tradução e análise', acao: 'conversa', desc: 'Usar a IA ou os recursos locais no chat.' }
      ]
    },
    {
      id: 'dispositivos', nome: 'Dispositivos', icone: '▣',
      desc: 'Android, câmera, computador e informações.',
      acoes: [
        { rot: 'Celular', acao: 'celular', desc: 'Status, conexões e atalhos do Android.' },
        { rot: 'Visão e câmera', acao: 'visao', desc: 'Sessão de câmera, objetos e texto.' },
        { rot: 'Computador', acao: 'pc', desc: 'Arquivos, CAD, tarefas e diagnóstico no Electron.' },
        { rot: 'Informações', acao: 'info', desc: 'Aparelho, clima e manchetes.' },
        { rot: 'Notificações e contatos', acao: 'config-privacidade', desc: 'Acessos especiais e nomes no contexto.' }
      ]
    },
    {
      id: 'seguranca', nome: 'Segurança e privacidade', icone: '▣',
      desc: 'Permissões, PIN, confirmações e emergência.',
      acoes: [
        { rot: 'Segurança', acao: 'config-seguranca', desc: 'PIN, biometria, modo seguro e bloqueio.' },
        { rot: 'Privacidade', acao: 'config-privacidade', desc: 'Histórico, contatos e dados no aparelho.' },
        { rot: 'Registro auditável', acao: 'log', desc: 'Ações, negações e erros.' },
        { rot: 'Parar tudo', acao: 'parar', desc: 'Encerrar operações em andamento.', perigo: true }
      ]
    },
    {
      id: 'personalizacao', nome: 'Personalização', icone: '◇',
      desc: 'Modos, aparência, personalidade e voz.',
      acoes: [
        { rot: 'Modos de uso', acao: 'config-personalizacao', desc: 'Completo, discreto, silencioso e holográfico.' },
        { rot: 'Aparência e núcleo', acao: 'config-voz', desc: 'HUD, plasma, órbita e redução de efeitos.' },
        { rot: 'Personalidade e humor', acao: 'config-ia', desc: 'Nome, tratamento, humor e estilo.' },
        { rot: 'Voz e prosódia', acao: 'config-voz', desc: 'Perfil, tom, velocidade e voz neural.' }
      ]
    },
    {
      id: 'sistema', nome: 'Sistema e diagnóstico', icone: '⌘',
      desc: 'Serviços, bateria, logs, testes e atualização.',
      acoes: [
        { rot: 'Central do sistema', acao: 'sistema', desc: 'Ferramentas, tarefas, acessibilidade e traces.' },
        { rot: 'Diagnóstico', acao: 'config-diagnostico', desc: 'Executar verificações reais por área.' },
        { rot: 'Atualização', acao: 'config-atualizacao', desc: 'Consultar releases e checksum.' },
        { rot: 'Registro', acao: 'log', desc: 'Últimas operações e falhas.' }
      ]
    }
  ];

  var modoAtual = MODO_PADRAO;

  function lerModo() {
    try {
      var v = raiz.localStorage && raiz.localStorage.getItem(CHAVE_MODO);
      return MODOS[v] ? v : MODO_PADRAO;
    } catch (e) { return MODO_PADRAO; }
  }

  function salvarModo(nome) {
    try { raiz.localStorage.setItem(CHAVE_MODO, nome); } catch (e) { /* armazenamento indisponível */ }
  }

  function pintarBotoesModo() {
    var botoes = doc.querySelectorAll('[data-modo]');
    for (var i = 0; i < botoes.length; i++) {
      var ativo = botoes[i].getAttribute('data-modo') === modoAtual;
      botoes[i].classList.toggle('ativo', ativo);
      botoes[i].setAttribute('aria-pressed', ativo ? 'true' : 'false');
    }
    var st = doc.getElementById('modo-status');
    if (st) st.textContent = MODOS[modoAtual].nome + ' · ' + MODOS[modoAtual].desc;
  }

  function aplicarModo(nome, opcoes) {
    if (!MODOS[nome]) nome = MODO_PADRAO;
    modoAtual = nome;
    if (doc.body) {
      doc.body.setAttribute('data-modo', nome);
      doc.body.classList.toggle('modo-discreto', nome === 'discreto');
      doc.body.classList.toggle('modo-silencioso', nome === 'silencioso');
      doc.body.classList.toggle('modo-holografico', nome === 'holografico');
    }
    pintarBotoesModo();
    if (nome === 'silencioso' && raiz.JarvisNavegacao && typeof raiz.JarvisNavegacao.silenciar === 'function') {
      try { raiz.JarvisNavegacao.silenciar(); } catch (e) { /* fala já encerrada */ }
    }
    if (!opcoes || opcoes.salvar !== false) salvarModo(nome);
    try {
      raiz.dispatchEvent(new CustomEvent('jarvis:modo', { detail: { modo: nome } }));
    } catch (e) { /* navegador sem CustomEvent */ }
    var aviso = doc.getElementById('modo-aviso');
    if (aviso) aviso.textContent = MODOS[nome].nome + ': ' + MODOS[nome].desc;
  }

  function el(tag, classe, texto) {
    var n = doc.createElement(tag);
    if (classe) n.className = classe;
    if (texto != null) n.textContent = texto;
    return n;
  }

  function montarGrade() {
    var grade = doc.getElementById('areas-grid');
    if (!grade || grade.getAttribute('data-pronto') === '1') return;
    grade.textContent = '';
    AREAS.forEach(function (area) {
      var b = el('button', 'area-card');
      b.type = 'button';
      b.setAttribute('data-area', area.id);
      b.setAttribute('aria-label', area.nome + ': ' + area.desc);
      var topo = el('span', 'area-card-topo');
      topo.appendChild(el('span', 'area-card-icone', area.icone));
      topo.appendChild(el('span', 'area-card-nome', area.nome));
      topo.appendChild(el('span', 'area-card-seta', '›'));
      b.appendChild(topo);
      b.appendChild(el('span', 'area-card-desc', area.desc));
      b.appendChild(el('span', 'area-card-meta', area.acoes.length + ' acesso(s)'));
      b.addEventListener('click', function () { abrirArea(area.id); });
      grade.appendChild(b);
    });
    grade.setAttribute('data-pronto', '1');
  }

  function montarDetalhe(area) {
    var caixa = doc.getElementById('areas-detalhe');
    if (!caixa) return;
    caixa.textContent = '';
    var topo = el('div', 'areas-detalhe-topo');
    var voltar = el('button', 'areas-voltar', '‹ Áreas');
    voltar.type = 'button';
    voltar.setAttribute('data-area-voltar', '1');
    voltar.addEventListener('click', function () { abrirArea(''); });
    topo.appendChild(voltar);
    var titulo = el('div');
    titulo.appendChild(el('p', 'eyebrow', 'J.A.R.V.I.S. NOVA · ÁREA'));
    titulo.appendChild(el('h3', '', area.icone + ' ' + area.nome));
    titulo.appendChild(el('p', 'dica', area.desc));
    topo.appendChild(titulo);
    caixa.appendChild(topo);

    var lista = el('div', 'areas-acoes');
    area.acoes.forEach(function (a) {
      var b = el('button', 'area-acao' + (a.perigo ? ' perigo' : ''));
      b.type = 'button';
      b.setAttribute('data-area-acao', a.acao);
      b.appendChild(el('b', '', a.rot));
      b.appendChild(el('small', '', a.desc));
      b.appendChild(el('span', 'area-acao-seta', '›'));
      b.addEventListener('click', function () { acao(a.acao); });
      lista.appendChild(b);
    });
    caixa.appendChild(lista);

    if (area.id === 'personalizacao') {
      var modos = el('div', 'modos-uso modos-areas');
      modos.setAttribute('role', 'group');
      modos.setAttribute('aria-label', 'Modo de uso');
      Object.keys(MODOS).forEach(function (id) {
        var m = MODOS[id];
        var b = el('button', 'modo-btn');
        b.type = 'button';
        b.setAttribute('data-modo', id);
        b.setAttribute('aria-pressed', 'false');
        b.appendChild(el('span', '', m.icone));
        b.appendChild(el('b', '', m.nome));
        b.appendChild(el('small', '', m.desc));
        b.addEventListener('click', function () { aplicarModo(id); });
        modos.appendChild(b);
      });
      caixa.appendChild(modos);
    }
  }

  function abrirArea(id) {
    var inicio = doc.getElementById('areas-inicio');
    var detalhe = doc.getElementById('areas-detalhe');
    if (!inicio || !detalhe) return;
    var area = null;
    for (var i = 0; i < AREAS.length; i++) if (AREAS[i].id === id) area = AREAS[i];
    if (!area) {
      inicio.hidden = false;
      detalhe.hidden = true;
      detalhe.textContent = '';
      return;
    }
    montarDetalhe(area);
    inicio.hidden = true;
    detalhe.hidden = false;
    if (detalhe.scrollIntoView) detalhe.scrollIntoView({ block: 'start', behavior: 'smooth' });
  }

  function acao(nome) {
    var st = doc.getElementById('areas-status');
    if (!raiz.JarvisNavegacao || typeof raiz.JarvisNavegacao.acao !== 'function') {
      if (st) st.textContent = 'O núcleo ainda está carregando. Tente novamente em alguns segundos.';
      return false;
    }
    try {
      var resultado = raiz.JarvisNavegacao.acao(nome);
      if (resultado === false) {
        if (st) st.textContent = 'Este recurso não está disponível nesta plataforma ou ainda não foi implementado.';
        return false;
      }
      if (st) st.textContent = 'Acesso solicitado: ' + nome + '.';
      return true;
    } catch (erro) {
      if (st) st.textContent = 'Não foi possível abrir este recurso: ' + ((erro && erro.message) || erro);
      return false;
    }
  }

  function init() {
    montarGrade();
    aplicarModo(lerModo(), { salvar: false });

    // Cada controle recebe sua própria ação. Isso evita depender de bubbling global
    // em WebView Android e mantém os botões dinâmicos funcionais após re-renderização.
    var modos = doc.querySelectorAll('[data-modo]');
    for (var i = 0; i < modos.length; i++) {
      (function (botao) {
        botao.addEventListener('click', function () {
          aplicarModo(botao.getAttribute('data-modo'));
        });
      })(modos[i]);
    }
    var atalhos = doc.querySelectorAll('[data-abrir-areas]');
    for (var j = 0; j < atalhos.length; j++) {
      atalhos[j].addEventListener('click', function () {
        if (raiz.JarvisNavegacao && typeof raiz.JarvisNavegacao.abrirAreas === 'function') {
          raiz.JarvisNavegacao.abrirAreas();
        } else {
          var status = doc.getElementById('areas-status');
          if (status) status.textContent = 'O núcleo de navegação ainda está inicializando. Tente novamente.';
        }
      });
    }
    raiz.addEventListener('jarvis:modo', function (e) {
      if (!e || !e.detail || !MODOS[e.detail.modo]) return;
      var st = doc.getElementById('modo-status');
      if (st) st.textContent = MODOS[e.detail.modo].nome + ' · ' + MODOS[e.detail.modo].desc;
    });
  }

  raiz.JarvisModos = {
    aplicar: aplicarModo,
    atual: function () { return modoAtual; },
    modos: MODOS,
    areas: AREAS
  };
  raiz.JarvisAreas = { abrir: abrirArea, lista: AREAS };

  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})(window, document);
