/* J.A.R.V.I.S. Nova — interface da aba Identificação de Pessoas.
 *
 * Toda a lógica de dados vive em identidade.js; aqui só há DOM. Dependências do
 * app.js são injetadas em iniciar() para não criar ordem implícita entre scripts.
 *
 * Privacidade na interface:
 *  - nenhuma foto, vetor ou áudio sai do aparelho;
 *  - consentimento é pedido em checkbox separado para voz e para referência visual;
 *  - a foto é reduzida para 320×320 antes de ser salva e o áudio nunca é guardado.
 */
(function (raiz) {
  'use strict';

  var IDENT = null;
  var deps = {
    capturarAmostraVoz: null, falar: null, registrar: null,
    store: null, tratar: function () { return 'senhor'; }
  };
  var estado = {
    editando: null, fotoPendente: null, rostoPendente: null,
    imagem: null, recorte: { zoom: 1, x: 0, y: 0 },
    amostras: 0, ocupado: false
  };
  var TAMANHO_FOTO = 320;
  var FRASES = [
    'Jarvis, esta é a minha voz e eu autorizo o cadastro neste aparelho.',
    'Hoje eu quero que você reconheça a minha voz sem depender de senha.',
    'Esta é a terceira amostra, falada com calma e à mesma distância do microfone.'
  ];

  function $(id) { return document.getElementById(id); }
  function motor() { return typeof VozMotor !== 'undefined' ? VozMotor : null; }
  function texto(el, valor) { if (el) el.textContent = valor == null ? '' : String(valor); }
  function status(msg, tipo) {
    var el = $('pessoa-status');
    if (el) { el.textContent = msg; el.dataset.estado = tipo || ''; }
  }
  function statusCfg(msg, tipo) {
    var el = $('idp-cfg-status');
    if (el) { el.textContent = msg; el.dataset.estado = tipo || ''; }
  }
  function statusVoz(msg, tipo) {
    var el = $('idp-voz-status');
    if (el) { el.textContent = msg; el.dataset.estado = tipo || ''; }
  }
  function statusRosto(msg, tipo) {
    var el = $('idp-rosto-status');
    if (el) { el.textContent = msg; el.dataset.estado = tipo || ''; }
  }
  function registrar(evento, detalhe) {
    try { if (deps.registrar) deps.registrar(evento, detalhe); } catch (e) { /* log é opcional */ }
  }
  function falar(textoFala) {
    try { if (deps.falar) deps.falar(textoFala, true); } catch (e) { /* voz é opcional */ }
  }
  function campo(id) { return $('pessoa-' + id); }
  function valor(id) { var el = campo(id); return el ? String(el.value || '').trim() : ''; }
  function preencher(id, v) { var el = campo(id); if (el) el.value = v == null ? '' : v; }

  var CAMPOS_FORM = ['nome', 'apelido', 'nascimento', 'alturaCm', 'profissao', 'relacao',
    'telefone', 'email', 'endereco', 'cidade', 'descricao', 'preferencias', 'interesses',
    'observacoes', 'contexto'];

  /* ---------------- cartões ---------------- */
  function iniciais(nome) {
    return String(nome || '?').trim().split(/\s+/).slice(0, 2).map(function (p) {
      return p.charAt(0).toUpperCase();
    }).join('') || '?';
  }
  function seloVoz(p) {
    if (p.consentimento && p.consentimento.voz && p.consentimento.voz.ok) {
      if (p.vozPronta) return { texto: 'voz pronta · ' + (p.amostras || 0) + ' amostras', tipo: 'ok' };
      if (p.amostras) return { texto: 'voz parcial · ' + p.amostras + '/3', tipo: 'warn' };
      return { texto: 'voz autorizada, sem amostras', tipo: 'warn' };
    }
    return { texto: 'voz não cadastrada', tipo: '' };
  }
  function cartao(p) {
    var art = document.createElement('article');
    art.className = 'idp-card';
    art.dataset.id = p.id;

    var foto = document.createElement('div');
    foto.className = 'idp-foto';
    if (p.foto) {
      var img = document.createElement('img');
      img.src = p.foto;
      img.alt = 'Foto de ' + p.nome;
      img.loading = 'lazy';
      foto.appendChild(img);
    } else {
      var ini = document.createElement('span');
      ini.className = 'idp-iniciais';
      ini.textContent = iniciais(p.nome);
      foto.appendChild(ini);
    }

    var corpo = document.createElement('div');
    corpo.className = 'idp-corpo';
    var nome = document.createElement('b');
    nome.className = 'idp-nome';
    nome.textContent = p.nome;
    corpo.appendChild(nome);
    if (p.apelido) {
      var ap = document.createElement('span');
      ap.className = 'idp-apelido';
      ap.textContent = '“' + p.apelido + '”';
      corpo.appendChild(ap);
    }
    var meta = document.createElement('small');
    meta.className = 'idp-meta';
    var anos = IDENT.idade(p.nascimento);
    meta.textContent = [p.relacao, p.profissao, anos != null ? anos + ' anos' : '', p.cidade]
      .filter(Boolean).join(' · ') || 'sem dados complementares';
    corpo.appendChild(meta);
    var selo = seloVoz(p);
    var badge = document.createElement('span');
    badge.className = 'idp-selo ' + selo.tipo;
    badge.textContent = selo.texto;
    corpo.appendChild(badge);

    var acoes = document.createElement('div');
    acoes.className = 'idp-acoes';
    var editar = document.createElement('button');
    editar.type = 'button'; editar.className = 'mini'; editar.textContent = 'editar';
    editar.onclick = function () { abrirEditor(p.id); };
    var ouvir = document.createElement('button');
    ouvir.type = 'button'; ouvir.className = 'mini'; ouvir.textContent = 'ouvir';
    ouvir.onclick = function () { falar(IDENT.descrever(p)); };
    var apagar = document.createElement('button');
    apagar.type = 'button'; apagar.className = 'mini perigo'; apagar.textContent = 'excluir';
    apagar.onclick = function () { excluir(p); };
    acoes.append(editar, ouvir, apagar);
    corpo.appendChild(acoes);

    art.append(foto, corpo);
    return art;
  }
  function renderLista() {
    var box = $('pessoa-lista');
    if (!box) return;
    box.textContent = '';
    var termo = ($('pessoa-busca') && $('pessoa-busca').value) || '';
    var lista = IDENT.buscar(termo);
    var total = IDENT.listar().length;
    status(total
      ? total + ' pessoa(s) cadastrada(s)' + (termo ? ' · ' + lista.length + ' no filtro' : '') + '. ' +
        (IDENT.resumo().comVoz ? IDENT.resumo().comVoz + ' com voz pronta.' : 'Nenhuma voz pronta ainda.')
      : 'Nenhuma pessoa cadastrada. Só o nome é obrigatório para começar.', total ? 'ok' : '');
    if (!lista.length) {
      var vazio = document.createElement('p');
      vazio.className = 'dica';
      vazio.textContent = total ? 'Nenhuma pessoa corresponde à busca.' : 'Toque em “Adicionar pessoa” para criar o primeiro perfil.';
      box.appendChild(vazio);
      return;
    }
    lista.forEach(function (p) { box.appendChild(cartao(p)); });
  }

  /* ---------------- foto e recorte ---------------- */
  function lerArquivo(file) {
    return new Promise(function (resolve, reject) {
      if (!file) return reject(new Error('Nenhum arquivo escolhido.'));
      if (!/^image\//.test(file.type || '')) return reject(new Error('Escolha um arquivo de imagem.'));
      if (file.size > 12 * 1024 * 1024) return reject(new Error('Imagem acima de 12 MB; escolha uma menor.'));
      var fr = new FileReader();
      fr.onerror = function () { reject(new Error('Não foi possível ler a imagem.')); };
      fr.onload = function () {
        var img = new Image();
        img.onerror = function () { reject(new Error('A imagem não pôde ser aberta.')); };
        img.onload = function () { resolve(img); };
        img.src = String(fr.result || '');
      };
      fr.readAsDataURL(file);
    });
  }
  function desenharRecorte() {
    var canvas = $('idp-foto-canvas');
    if (!canvas || !estado.imagem) return;
    var img = estado.imagem;
    canvas.width = TAMANHO_FOTO; canvas.height = TAMANHO_FOTO;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = '#050b14';
    ctx.fillRect(0, 0, TAMANHO_FOTO, TAMANHO_FOTO);
    var base = Math.max(TAMANHO_FOTO / img.width, TAMANHO_FOTO / img.height);
    var z = estado.recorte.zoom || 1;
    var w = img.width * base * z, h = img.height * base * z;
    var maxX = Math.max(0, (w - TAMANHO_FOTO) / 2), maxY = Math.max(0, (h - TAMANHO_FOTO) / 2);
    var x = (TAMANHO_FOTO - w) / 2 + estado.recorte.x * maxX;
    var y = (TAMANHO_FOTO - h) / 2 + estado.recorte.y * maxY;
    ctx.drawImage(img, x, y, w, h);
  }
  function dhashDoCanvas(canvas) {
    var c = document.createElement('canvas');
    c.width = 9; c.height = 8;
    var ctx = c.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(canvas, 0, 0, 9, 8);
    var dados;
    try { dados = ctx.getImageData(0, 0, 9, 8).data; } catch (e) { return ''; }
    var bits = '';
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        var i = (y * 9 + x) * 4;
        var a = 0.299 * dados[i] + 0.587 * dados[i + 1] + 0.114 * dados[i + 2];
        var j = (y * 9 + x + 1) * 4;
        var b = 0.299 * dados[j] + 0.587 * dados[j + 1] + 0.114 * dados[j + 2];
        bits += a > b ? '1' : '0';
      }
    }
    var hex = '';
    for (var k = 0; k < 64; k += 4) hex += parseInt(bits.slice(k, k + 4), 2).toString(16);
    return hex;
  }
  function aplicarRecorte() {
    var canvas = $('idp-foto-canvas');
    if (!canvas || !estado.imagem) { status('Escolha uma imagem antes de aplicar o recorte.', 'warn'); return; }
    var dataUrl = canvas.toDataURL('image/jpeg', 0.82);
    estado.fotoPendente = dataUrl;
    estado.rostoPendente = { dhash: dhashDoCanvas(canvas), aspecto: 1 };
    var preview = $('idp-foto-preview');
    if (preview) { preview.src = dataUrl; preview.hidden = false; }
    var vazio = $('idp-foto-vazio');
    if (vazio) vazio.hidden = true;
    status('Recorte aplicado. A foto só é gravada quando você salvar o perfil.', 'ok');
  }
  function limparFotoPendente() {
    estado.fotoPendente = null;
    estado.rostoPendente = null;
    estado.imagem = null;
    estado.recorte = { zoom: 1, x: 0, y: 0 };
    var canvas = $('idp-foto-canvas');
    if (canvas) { canvas.width = 1; canvas.height = 1; }
    var preview = $('idp-foto-preview');
    if (preview) { preview.src = ''; preview.hidden = true; }
    var vazio = $('idp-foto-vazio');
    if (vazio) vazio.hidden = false;
    ['idp-foto-zoom', 'idp-foto-x', 'idp-foto-y'].forEach(function (id) {
      var el = $(id); if (el) el.value = id === 'idp-foto-zoom' ? '1' : '0';
    });
    var rec = $('idp-foto-recorte');
    if (rec) rec.hidden = true;
  }
  async function escolherFoto(file) {
    try {
      var img = await lerArquivo(file);
      estado.imagem = img;
      estado.recorte = { zoom: 1, x: 0, y: 0 };
      var rec = $('idp-foto-recorte');
      if (rec) rec.hidden = false;
      desenharRecorte();
      status('Ajuste o recorte e toque em “Aplicar recorte”.', '');
    } catch (e) {
      status((e && e.message) || 'Imagem inválida.', 'fail');
    }
  }
  function ligarRecorte() {
    ['idp-foto-zoom', 'idp-foto-x', 'idp-foto-y'].forEach(function (id) {
      var el = $(id);
      if (!el) return;
      el.addEventListener('input', function () {
        estado.recorte.zoom = Number($('idp-foto-zoom') ? $('idp-foto-zoom').value : 1) || 1;
        estado.recorte.x = Number($('idp-foto-x') ? $('idp-foto-x').value : 0) || 0;
        estado.recorte.y = Number($('idp-foto-y') ? $('idp-foto-y').value : 0) || 0;
        desenharRecorte();
      });
    });
    var aplicar = $('idp-foto-aplicar');
    if (aplicar) aplicar.onclick = aplicarRecorte;
    var remover = $('idp-foto-remover');
    if (remover) remover.onclick = async function () {
      if (!estado.editando) { limparFotoPendente(); return; }
      if (typeof confirm === 'function' && !confirm('Remover a foto deste perfil? A referência visual também será apagada.')) return;
      var r = IDENT.removerFoto(estado.editando);
      if (!r.ok) { status(r.erro, 'fail'); return; }
      limparFotoPendente();
      renderLista();
      abrirEditor(estado.editando);
      status('Foto e referência visual removidas.', 'warn');
    };
    ['idp-foto-arquivo', 'idp-foto-camera'].forEach(function (id) {
      var el = $(id);
      if (el) el.addEventListener('change', function () {
        var f = el.files && el.files[0];
        el.value = '';
        if (f) escolherFoto(f);
      });
    });
  }

  /* ---------------- campos personalizados ---------------- */
  function linhaCampo(c, indice) {
    var div = document.createElement('div');
    div.className = 'idp-campo';
    var rot = document.createElement('b');
    rot.textContent = c.rotulo;
    var val = document.createElement('span');
    val.textContent = c.valor;
    var rm = document.createElement('button');
    rm.type = 'button'; rm.className = 'mini perigo'; rm.textContent = 'remover';
    rm.onclick = function () {
      if (!estado.editando) return;
      var p = IDENT.obter(estado.editando);
      if (!p) return;
      var campos = (p.campos || []).filter(function (_, i) { return i !== indice; });
      var r = IDENT.salvar({ id: p.id, campos: campos });
      if (!r.ok) { status(r.erro, 'fail'); return; }
      abrirEditor(p.id);
    };
    div.append(rot, val, rm);
    return div;
  }
  function renderCampos(p) {
    var box = $('idp-campos');
    if (!box) return;
    box.textContent = '';
    var lista = (p && p.campos) || [];
    if (!lista.length) {
      var vazio = document.createElement('p');
      vazio.className = 'dica';
      vazio.textContent = 'Nenhum campo personalizado. Ex.: “placa do carro”, “time do coração”.';
      box.appendChild(vazio);
    }
    lista.forEach(function (c, i) { box.appendChild(linhaCampo(c, i)); });
  }
  function adicionarCampo() {
    if (!estado.editando) { status('Salve o perfil antes de criar campos personalizados.', 'warn'); return; }
    var rotulo = $('idp-campo-rotulo'), valorEl = $('idp-campo-valor');
    var r = String(rotulo && rotulo.value || '').trim();
    var v = String(valorEl && valorEl.value || '').trim();
    if (!r || !v) { status('Preencha o nome e o valor do campo personalizado.', 'warn'); return; }
    var p = IDENT.obter(estado.editando);
    if (!p) return;
    var campos = (p.campos || []).concat([{ rotulo: r, valor: v }]);
    if (campos.length > 12) { status('Limite de 12 campos personalizados.', 'warn'); return; }
    var res = IDENT.salvar({ id: p.id, campos: campos });
    if (!res.ok) { status(res.erro, 'fail'); return; }
    if (rotulo) rotulo.value = '';
    if (valorEl) valorEl.value = '';
    renderCampos(res.perfil);
    renderHistorico(res.perfil);
    status('Campo “' + r + '” adicionado.', 'ok');
  }

  /* ---------------- voz ---------------- */
  function renderAmostras(p) {
    var box = $('idp-voz-amostras');
    if (!box) return;
    box.textContent = '';
    var n = (p && p.amostras) || 0;
    if (!n) {
      var vazio = document.createElement('p');
      vazio.className = 'dica';
      vazio.textContent = 'Nenhuma amostra. Grave três para liberar a identificação.';
      box.appendChild(vazio);
      return;
    }
    for (var i = 0; i < n; i++) {
      var item = document.createElement('div');
      item.className = 'idp-amostra';
      var b = document.createElement('b');
      b.textContent = 'Amostra ' + (i + 1);
      var rm = document.createElement('button');
      rm.type = 'button'; rm.className = 'mini perigo'; rm.textContent = 'apagar';
      rm.onclick = async function (indice) {
        var r = await IDENT.removerVoz(p.id, indice);
        if (!r.ok) { statusVoz(r.erro, 'fail'); return; }
        var atual = IDENT.obter(p.id);
        renderAmostras(atual);
        renderLista();
        statusVoz('Amostra apagada. Restam ' + r.amostras + '.', 'warn');
      }.bind(null, i);
      item.append(b, rm);
      box.appendChild(item);
    }
  }
  function atualizarBlocoVoz(p) {
    var cons = $('idp-consent-voz');
    var autorizado = !!(p && p.consentimento && p.consentimento.voz && p.consentimento.voz.ok);
    if (cons) cons.checked = autorizado;
    var pronto = !!(p && p.vozPronta);
    statusVoz(!p ? 'Salve o perfil antes de cadastrar a voz.'
      : autorizado
        ? (pronto ? 'Perfil de voz pronto com ' + p.amostras + ' amostras. A comparação é local e indicativa.' :
          'Autorização registrada. Grave ' + (3 - (p.amostras || 0)) + ' amostra(s) em ambiente silencioso.')
        : 'A pessoa ainda não autorizou o cadastro da voz neste aparelho.',
      autorizado ? (pronto ? 'ok' : 'warn') : '');
    var fr = $('idp-voz-frase');
    var n = (p && p.amostras) || 0;
    if (fr) fr.textContent = 'Frase ' + Math.min(n + 1, 3) + ' de 3: “' + FRASES[Math.min(n, 2)] + '”';
    var gravar = $('idp-voz-gravar');
    if (gravar) gravar.disabled = !p || !autorizado || n >= IDENT.LIMITE_AMOSTRAS;
    renderAmostras(p);
  }
  async function gravarVoz() {
    if (!estado.editando) { statusVoz('Salve o perfil antes de gravar.', 'warn'); return; }
    if (estado.ocupado) return;
    var p = IDENT.obter(estado.editando);
    if (!p) return;
    var cons = $('idp-consent-voz');
    if (!cons || !cons.checked) { statusVoz('Marque a autorização da pessoa antes de gravar.', 'warn'); return; }
    if (!deps.capturarAmostraVoz) { statusVoz('O microfone não está disponível nesta plataforma.', 'fail'); return; }
    var m = motor();
    if (!m) { statusVoz('O motor de voz não carregou.', 'fail'); return; }
    estado.ocupado = true;
    var botao = $('idp-voz-gravar');
    if (botao) botao.disabled = true;
    try {
      if (!(p.consentimento && p.consentimento.voz && p.consentimento.voz.ok)) {
        var c = IDENT.consentir(p.id, 'voz', 'Autorizo a comparação da minha voz com este perfil neste aparelho');
        if (!c.ok) throw new Error(c.erro);
        p = c.perfil;
      }
      statusVoz('Gravando: leia a frase em voz normal. Paro sozinho após 1,2 s de silêncio.', '');
      var audio = await deps.capturarAmostraVoz(4000);
      var analise = m.analisar(audio.samples, audio.sampleRate);
      var r = await IDENT.adicionarVoz(p.id, analise);
      if (!r.ok) { statusVoz(r.erro, 'fail'); return; }
      var atual = IDENT.obter(p.id);
      atualizarBlocoVoz(atual);
      renderLista();
      statusVoz(r.pronta
        ? 'Voz pronta com ' + r.amostras + ' amostras' + (r.cifrado ? ' (vetores cifrados no aparelho).' : ' (armazenamento local).')
        : 'Amostra ' + r.amostras + ' de 3 aceita. Leia a próxima frase.', r.pronta ? 'ok' : 'warn');
      registrar('identidade', 'amostra de voz de ' + p.nome + ' (' + r.amostras + ')');
    } catch (e) {
      statusVoz((e && e.message) || 'Não foi possível gravar a amostra.', 'fail');
    } finally {
      estado.ocupado = false;
      var p2 = estado.editando ? IDENT.obter(estado.editando) : null;
      if (botao) botao.disabled = !p2 || !(p2.consentimento && p2.consentimento.voz && p2.consentimento.voz.ok);
    }
  }
  async function testarVoz() {
    if (estado.ocupado) return;
    if (!deps.capturarAmostraVoz) { statusVoz('O microfone não está disponível.', 'fail'); return; }
    var m = motor();
    if (!m) { statusVoz('O motor de voz não carregou.', 'fail'); return; }
    if (!IDENT.perfisVoz().length) { statusVoz('Nenhuma pessoa tem perfil de voz autorizado.', 'warn'); return; }
    estado.ocupado = true;
    try {
      statusVoz('Gravando: fale normalmente e faça uma pausa curta ao final.', '');
      var audio = await deps.capturarAmostraVoz(4000);
      var analise = m.analisar(audio.samples, audio.sampleRate);
      var r = await IDENT.identificar(analise);
      if (r.estado === IDENT.ESTADOS.IDENTIFICADO) {
        statusVoz('IDENTIFICADO: ' + r.pessoa.nome + ' — confiança ' + r.confianca + '%. Comparação local, não é prova de identidade.', 'ok');
        falar('Reconheci ' + r.pessoa.nome + ', ' + deps.tratar() + '. Confiança de ' + r.confianca + ' por cento.');
      } else if (r.estado === IDENT.ESTADOS.NAO_IDENTIFICADO) {
        statusVoz('NÃO IDENTIFICADO — a voz não passou do limite de ' + Math.round(IDENT.config().limiar * 100) + '%.', 'warn');
        falar('Essa voz não corresponde a ninguém do cadastro.');
      } else {
        statusVoz('INCONCLUSIVO — ' + ((r.motivos || [])[0] || 'áudio insuficiente ou ambíguo') + ' Tente de novo em local silencioso.', 'warn');
        falar('Não consegui identificar a voz com segurança.');
      }
    } catch (e) {
      statusVoz((e && e.message) || 'Falha na comparação.', 'fail');
    } finally { estado.ocupado = false; }
  }

  /* ---------------- referência visual ---------------- */
  function atualizarBlocoRosto(p) {
    var cons = $('idp-consent-rosto');
    var autorizado = !!(p && p.consentimento && p.consentimento.rosto && p.consentimento.rosto.ok);
    if (cons) cons.checked = autorizado;
    var cfg = IDENT.config();
    statusRosto(!cfg.rosto
      ? 'Recurso desligado em Identificação e reconhecimento. Nada é comparado.'
      : !p || !p.foto
        ? 'Adicione uma foto para criar a referência visual.'
        : autorizado
          ? (p.rosto ? 'Referência visual criada. É semelhança de imagem, nunca prova de identidade.' : 'Autorização registrada; toque em “Criar referência visual”.')
          : 'A pessoa ainda não autorizou a referência visual.',
      cfg.rosto && autorizado ? 'ok' : '');
    var criar = $('idp-rosto-criar');
    if (criar) criar.disabled = !p || !p.foto || !autorizado || !cfg.rosto;
    var remover = $('idp-rosto-remover');
    if (remover) remover.disabled = !p || !p.rosto;
  }
  async function criarRosto() {
    if (!estado.editando) { statusRosto('Salve o perfil antes.', 'warn'); return; }
    var p = IDENT.obter(estado.editando);
    if (!p) return;
    var d = estado.rostoPendente;
    if (!d || !d.dhash) {
      var canvas = $('idp-foto-canvas');
      if (canvas && canvas.width > 1) d = { dhash: dhashDoCanvas(canvas), aspecto: 1 };
    }
    if (!d || !d.dhash) { statusRosto('A foto atual não gerou um descritor visual. Reaplique o recorte.', 'fail'); return; }
    var r = IDENT.definirRosto(p.id, d);
    if (!r.ok) { statusRosto(r.erro, 'fail'); return; }
    atualizarBlocoRosto(r.perfil);
    renderLista();
    statusRosto('Referência visual criada. Comparação aproximada, não biométrica.', 'ok');
  }

  /* ---------------- histórico ---------------- */
  function renderHistorico(p) {
    var box = $('idp-historico');
    if (!box) return;
    box.textContent = '';
    var lista = (p && p.historico) || [];
    if (!lista.length) {
      var v = document.createElement('p');
      v.className = 'dica';
      v.textContent = 'Sem alterações registradas.';
      box.appendChild(v);
      return;
    }
    lista.slice(0, 12).forEach(function (h) {
      var linha = document.createElement('div');
      linha.className = 'idp-hist';
      var quando = document.createElement('small');
      quando.textContent = new Date(h.em).toLocaleString('pt-BR');
      var oque = document.createElement('span');
      var rotulo = IDENT.ROTULO[h.campo] || h.campo;
      oque.textContent = rotulo + (h.de || h.para ? ': ' + (h.de || '∅') + ' → ' + (h.para || '∅') : '');
      linha.append(quando, oque);
      box.appendChild(linha);
    });
  }

  /* ---------------- editor ---------------- */
  function abrirEditor(id) {
    var p = id ? IDENT.obter(id) : null;
    estado.editando = p ? p.id : null;
    estado.fotoPendente = null;
    estado.rostoPendente = null;
    estado.imagem = null;
    CAMPOS_FORM.forEach(function (c) { preencher(c, p ? p[c] : ''); });
    atualizarIdade();
    var titulo = $('idp-editor-titulo');
    texto(titulo, p ? 'Editar ' + p.nome : 'Nova pessoa');
    var salvar = $('pessoa-salvar');
    if (salvar) salvar.textContent = p ? 'Salvar alterações' : 'Salvar pessoa';
    var excluir = $('idp-excluir');
    if (excluir) excluir.hidden = !p;
    var preview = $('idp-foto-preview');
    if (preview) {
      if (p && p.foto) { preview.src = p.foto; preview.hidden = false; }
      else { preview.src = ''; preview.hidden = true; }
    }
    var vazio = $('idp-foto-vazio');
    if (vazio) vazio.hidden = !!(p && p.foto);
    var rec = $('idp-foto-recorte');
    if (rec) rec.hidden = true;
    renderCampos(p);
    atualizarBlocoVoz(p);
    atualizarBlocoRosto(p);
    renderHistorico(p);
    var inicio = $('idp-inicio'), editor = $('idp-editor'), cfg = $('idp-config');
    if (inicio) inicio.hidden = true;
    if (cfg) cfg.hidden = true;
    if (editor) editor.hidden = false;
    var painel = $('painel-pessoas');
    if (painel) painel.scrollTop = 0;
  }
  function fecharEditor() {
    estado.editando = null;
    estado.fotoPendente = null;
    estado.rostoPendente = null;
    estado.imagem = null;
    var inicio = $('idp-inicio'), editor = $('idp-editor');
    if (editor) editor.hidden = true;
    if (inicio) inicio.hidden = false;
    renderLista();
  }
  function atualizarIdade() {
    var out = $('idp-idade');
    var anos = IDENT.idade(valor('nascimento'));
    if (out) out.value = anos == null ? '' : anos + ' anos';
  }
  async function salvarPerfil() {
    if (!valor('nome')) { status('Informe o nome ou uma identificação para a pessoa.', 'fail'); return; }
    var dados = { id: estado.editando || undefined };
    CAMPOS_FORM.forEach(function (c) { dados[c] = valor(c); });
    var r = IDENT.salvar(dados);
    if (!r.ok) { status(r.erro, 'fail'); return; }
    var id = r.perfil.id;
    estado.editando = id;
    if (estado.fotoPendente) {
      var f = IDENT.definirFoto(id, estado.fotoPendente);
      if (!f.ok) { status(f.erro, 'fail'); return; }
      if (estado.rostoPendente) {
        var consRosto = $('idp-consent-rosto');
        if (consRosto && consRosto.checked) {
          IDENT.consentir(id, 'rosto', 'Autorizo a comparação da minha fotografia com este perfil neste aparelho');
          IDENT.definirRosto(id, estado.rostoPendente);
        }
      }
      estado.fotoPendente = null;
    }
    var consVoz = $('idp-consent-voz');
    var atual = IDENT.obter(id);
    if (consVoz && consVoz.checked && !(atual.consentimento && atual.consentimento.voz && atual.consentimento.voz.ok)) {
      IDENT.consentir(id, 'voz', 'Autorizo a comparação da minha voz com este perfil neste aparelho');
    } else if (consVoz && !consVoz.checked && atual.consentimento && atual.consentimento.voz && atual.consentimento.voz.ok) {
      IDENT.revogarConsentimento(id, 'voz');
    }
    var consRosto2 = $('idp-consent-rosto');
    var atual2 = IDENT.obter(id);
    if (consRosto2 && consRosto2.checked && !(atual2.consentimento && atual2.consentimento.rosto && atual2.consentimento.rosto.ok)) {
      IDENT.consentir(id, 'rosto', 'Autorizo a comparação da minha fotografia com este perfil neste aparelho');
    } else if (consRosto2 && !consRosto2.checked && atual2.consentimento && atual2.consentimento.rosto && atual2.consentimento.rosto.ok) {
      IDENT.revogarConsentimento(id, 'rosto');
    }
    var final = IDENT.obter(id);
    status('Perfil de ' + final.nome + ' salvo neste aparelho.', 'ok');
    registrar('identidade', 'perfil salvo: ' + final.nome);
    renderLista();
    abrirEditor(id);
    status('Perfil de ' + final.nome + ' salvo. Agora você pode cadastrar a voz.', 'ok');
  }
  async function excluir(p) {
    if (!p) return;
    if (typeof confirm === 'function' && !confirm('Excluir o perfil de ' + p.nome + ', a foto e as referências biométricas? Isso não pode ser desfeito.')) return;
    var r = await IDENT.remover(p.id);
    if (!r.ok) { status(r.erro, 'fail'); return; }
    if (estado.editando === p.id) fecharEditor();
    renderLista();
    status('Perfil de ' + p.nome + ' e suas referências foram apagados.', 'warn');
    registrar('identidade', 'perfil apagado: ' + p.nome);
  }

  /* ---------------- configurações ---------------- */
  function aplicarConfigUI() {
    var c = IDENT.config();
    if ($('idp-cfg-voz')) $('idp-cfg-voz').checked = c.voz;
    if ($('idp-cfg-rosto')) $('idp-cfg-rosto').checked = c.rosto;
    if ($('idp-cfg-contexto')) $('idp-cfg-contexto').checked = c.contexto;
    if ($('idp-cfg-confirmar')) $('idp-cfg-confirmar').checked = c.confirmar;
    [['idp-cfg-limiar', c.limiar, 'idp-cfg-limiar-valor', '%'], ['idp-cfg-margem', c.margem, 'idp-cfg-margem-valor', '%'],
      ['idp-cfg-fala', c.falaMin, 'idp-cfg-fala-valor', ' s'], ['idp-cfg-snr', c.snrMin, 'idp-cfg-snr-valor', ' dB']]
      .forEach(function (t) {
        var el = $(t[0]); if (!el) return;
        el.value = String(t[1]);
        var out = $(t[2]);
        if (out) out.textContent = (t[3] === '%' ? Math.round(Number(t[1]) * 100) : Number(t[1])) + t[3];
      });
    statusCfg('Limiar mínimo seguro: 68%. Qualidade mínima: ' + c.falaMin.toFixed(1) + ' s e ' + c.snrMin + ' dB.', '');
    renderLista();
  }
  function salvarConfigUI() {
    var patch = {
      voz: $('idp-cfg-voz') ? $('idp-cfg-voz').checked : true,
      rosto: $('idp-cfg-rosto') ? $('idp-cfg-rosto').checked : false,
      contexto: $('idp-cfg-contexto') ? $('idp-cfg-contexto').checked : true,
      confirmar: $('idp-cfg-confirmar') ? $('idp-cfg-confirmar').checked : true,
      limiar: $('idp-cfg-limiar') ? Number($('idp-cfg-limiar').value) : undefined,
      margem: $('idp-cfg-margem') ? Number($('idp-cfg-margem').value) : undefined,
      falaMin: $('idp-cfg-fala') ? Number($('idp-cfg-fala').value) : undefined,
      snrMin: $('idp-cfg-snr') ? Number($('idp-cfg-snr').value) : undefined
    };
    if (deps.store) {
      deps.store.set('pessoas_contexto', patch.contexto ? '1' : '0');
    }
    var c = IDENT.salvarConfig(patch);
    aplicarConfigUI();
    statusCfg('Configurações salvas. Voz ' + (c.voz ? 'ativa' : 'desligada') + ', rosto ' +
      (c.rosto ? 'ativo' : 'desligado') + ', limiar ' + Math.round(c.limiar * 100) + '%.', 'ok');
  }
  async function testarMicrofone() {
    if (!deps.capturarAmostraVoz) { statusCfg('Microfone indisponível nesta plataforma.', 'fail'); return; }
    try {
      statusCfg('Gravando 3 segundos para medir o microfone…', '');
      var a = await deps.capturarAmostraVoz(3000);
      var m = motor();
      if (!m) throw new Error('O motor de voz não carregou.');
      var r = m.analisar(a.samples, a.sampleRate);
      var q = r.qualidade;
      statusCfg('Microfone: fala ' + q.falaSeg + ' s · SNR ' + q.snrDb + ' dB · clipping ' + q.clipping + '% · pitch ' + r.metricas.pitchHz + ' Hz. ' +
        (q.ok ? 'Qualidade aceitável para cadastro.' : 'Ajuste o ambiente: ' + q.problemas.join(' ')), q.ok ? 'ok' : 'warn');
    } catch (e) { statusCfg((e && e.message) || 'Falha ao testar o microfone.', 'fail'); }
  }
  async function testarReconhecimento() { await testarVoz(); }
  async function apagarBiometriaTudo() {
    var lista = IDENT.listar();
    if (!lista.length) { statusCfg('Nenhum perfil cadastrado.', 'warn'); return; }
    if (typeof confirm === 'function' && !confirm('Apagar voz e referência visual de ' + lista.length + ' perfil(is)? Nomes, fotos e informações continuam.')) return;
    for (var i = 0; i < lista.length; i++) { await IDENT.removerBiometria(lista[i].id); }
    aplicarConfigUI();
    statusCfg('Biometria apagada de ' + lista.length + ' perfil(is). O cadastro civil continua intacto.', 'warn');
    registrar('identidade', 'biometria apagada de todos os perfis');
  }
  function abrirConfigIdentidade() {
    if (deps.abrirConfig) { deps.abrirConfig(); return; }
    var inicio = $('idp-inicio'), editor = $('idp-editor');
    if (inicio) inicio.hidden = true;
    if (editor) editor.hidden = true;
    aplicarConfigUI();
  }
  function fecharConfigIdentidade() {
    var cfg = $('idp-config'), inicio = $('idp-inicio');
    if (cfg) cfg.hidden = true;
    if (inicio) inicio.hidden = false;
    renderLista();
  }

  /* ---------------- exportação/importação ---------------- */
  function exportarUI() {
    var textoJson = IDENT.exportar({ fotos: true, biometria: false });
    var saida = $('pessoa-exportacao');
    if (saida) { saida.hidden = false; saida.textContent = textoJson; }
    try {
      var blob = new Blob([textoJson], { type: 'application/json' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url; a.download = 'pessoas-jarvis.json';
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
      status('Exportação gerada sem biometria. Guarde o arquivo com cuidado: há dados pessoais.', 'ok');
    } catch (e) {
      status('Download indisponível; o JSON ficou visível para copiar.', 'warn');
    }
  }
  function importarUI(file) {
    if (!file) return;
    var fr = new FileReader();
    fr.onerror = function () { status('Não foi possível ler o arquivo.', 'fail'); };
    fr.onload = function () {
      var r = IDENT.importar(String(fr.result || ''));
      if (!r.ok) { status(r.erro, 'fail'); return; }
      renderLista();
      status(r.importados + ' perfil(is) importado(s); ' + r.ignorados + ' ignorado(s). Biometria nunca é importada.', 'ok');
    };
    fr.readAsText(file);
  }

  /* ---------------- navegação ---------------- */
  async function abrir() {
    if (!IDENT) { status('O módulo de identificação não carregou neste pacote.', 'fail'); return; }
    var painel = $('painel-pessoas');
    if (painel) painel.hidden = false;
    try {
      await IDENT.iniciar();
      if (typeof PessoasJarvis !== 'undefined' && PessoasJarvis && PessoasJarvis.listar) {
        var antigos = PessoasJarvis.listar();
        if (antigos.length) {
          var mig = IDENT.migrarDe(antigos);
          if (mig.migrados) status(mig.migrados + ' perfil(is) do cadastro anterior foram preservados.', 'ok');
        }
      }
    } catch (e) {
      status('Falha ao carregar o armazenamento: ' + ((e && e.message) || e), 'fail');
    }
    var inicio = $('idp-inicio'), editor = $('idp-editor'), cfg = $('idp-config');
    if (inicio) inicio.hidden = false;
    if (editor) editor.hidden = true;
    if (cfg) cfg.hidden = true;
    renderLista();
  }

  async function iniciar(dependencias) {
    deps = Object.assign(deps, dependencias || {});
    IDENT = (raiz && raiz.IdentidadeJarvis) ? raiz.IdentidadeJarvis : null;
    if (!IDENT) return;
    ligarRecorte();
    if ($('pessoa-busca')) $('pessoa-busca').addEventListener('input', renderLista);
    if ($('idp-novo')) $('idp-novo').onclick = function () { abrirEditor(null); };
    if ($('pessoa-salvar')) $('pessoa-salvar').onclick = function () { salvarPerfil(); };
    if ($('idp-cancelar')) $('idp-cancelar').onclick = fecharEditor;
    if ($('idp-excluir')) $('idp-excluir').onclick = function () { excluir(IDENT.obter(estado.editando)); };
    if ($('idp-campo-add')) $('idp-campo-add').onclick = adicionarCampo;
    if ($('idp-voz-gravar')) $('idp-voz-gravar').onclick = gravarVoz;
    if ($('idp-voz-testar')) $('idp-voz-testar').onclick = testarVoz;
    if ($('idp-voz-apagar')) $('idp-voz-apagar').onclick = async function () {
      if (!estado.editando) return;
      if (typeof confirm === 'function' && !confirm('Apagar todas as amostras de voz deste perfil?')) return;
      var r = await IDENT.removerVoz(estado.editando, null);
      if (!r.ok) { statusVoz(r.erro, 'fail'); return; }
      atualizarBlocoVoz(IDENT.obter(estado.editando));
      renderLista();
      statusVoz('Amostras apagadas. O perfil civil continua.', 'warn');
    };
    if ($('idp-rosto-criar')) $('idp-rosto-criar').onclick = criarRosto;
    if ($('idp-rosto-remover')) $('idp-rosto-remover').onclick = function () {
      if (!estado.editando) return;
      var r = IDENT.removerRosto(estado.editando);
      if (!r.ok) { statusRosto(r.erro, 'fail'); return; }
      atualizarBlocoRosto(r.perfil);
      renderLista();
      statusRosto('Referência visual removida.', 'warn');
    };
    if ($('idp-idade') && campo('nascimento')) campo('nascimento').addEventListener('input', atualizarIdade);
    if ($('idp-abrir-config')) $('idp-abrir-config').onclick = abrirConfigIdentidade;
    if ($('idp-cfg-fechar')) $('idp-cfg-fechar').onclick = fecharConfigIdentidade;
    ['idp-cfg-voz', 'idp-cfg-rosto', 'idp-cfg-contexto', 'idp-cfg-confirmar'].forEach(function (id) {
      var el = $(id); if (el) el.onchange = salvarConfigUI;
    });
    [['idp-cfg-limiar', 'idp-cfg-limiar-valor', '%'], ['idp-cfg-margem', 'idp-cfg-margem-valor', '%'],
      ['idp-cfg-fala', 'idp-cfg-fala-valor', ' s'], ['idp-cfg-snr', 'idp-cfg-snr-valor', ' dB']]
      .forEach(function (t) {
        var el = $(t[0]);
        if (!el) return;
        el.addEventListener('input', function () {
          var out = $(t[1]);
          if (out) out.textContent = (t[2] === '%' ? Math.round(Number(el.value) * 100) : Number(el.value)) + t[2];
        });
        el.addEventListener('change', salvarConfigUI);
      });
    if ($('idp-cfg-mic')) $('idp-cfg-mic').onclick = testarMicrofone;
    if ($('idp-cfg-testar')) $('idp-cfg-testar').onclick = testarReconhecimento;
    if ($('idp-cfg-apagar-bio')) $('idp-cfg-apagar-bio').onclick = apagarBiometriaTudo;
    if ($('idp-exportar')) $('idp-exportar').onclick = exportarUI;
    if ($('idp-importar')) $('idp-importar').onclick = function () { var el = $('idp-importar-arquivo'); if (el) el.click(); };
    if ($('idp-importar-arquivo')) $('idp-importar-arquivo').addEventListener('change', function () {
      var f = this.files && this.files[0]; this.value = ''; importarUI(f);
    });
    if ($('pessoa-fechar')) $('pessoa-fechar').onclick = function () {
      var painel = $('painel-pessoas'); if (painel) painel.hidden = true;
    };
    await IDENT.iniciar();
    aplicarConfigUI();
  }

  raiz.IdentidadeUI = {
    iniciar: iniciar, abrir: abrir, render: renderLista,
    abrirEditor: abrirEditor, fecharEditor: fecharEditor,
    abrirConfig: abrirConfigIdentidade,
    sincronizarConfig: aplicarConfigUI,
    estado: estado
  };
})(typeof window !== 'undefined' ? window : this);
