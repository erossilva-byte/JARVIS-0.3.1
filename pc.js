/* J.A.R.V.I.S. Nova — painel do computador (Electron: Windows, Linux e macOS).
 *
 * Só assume o controle quando o preload do Electron existe (`window.jarvisNative`).
 * No Android e no navegador este arquivo não faz nada: o painel e o botão da barra
 * lateral continuam escondidos.
 *
 * Regra de honestidade da interface: nada é marcado como concluído sem resposta real do
 * processo principal. Cada ação mostra o que voltou (caminho, bytes, validação) e os
 * erros aparecem como erro — nunca como sucesso silencioso.
 */
(function () {
  'use strict';
  var nativo = window.jarvisNative;
  if (!nativo || typeof nativo.run !== 'function') return;
  if (window.PcPainel) return;

  var el = function (id) { return document.getElementById(id); };
  var pedir = function (acao, args) { return nativo.run(acao, args || {}); };

  var estado = {
    caminho: '~',
    pai: '',
    arquivo: null,
    geo: null,
    vista: { escala: 1, ox: 0, oy: 0, giro: 0.7, incl: 0.45 },
    plano: null,
    arrastando: false
  };

  function kb(n) {
    var b = Number(n) || 0;
    if (b < 1024) return b + ' B';
    if (b < 1048576) return (b / 1024).toFixed(1).replace('.', ',') + ' kB';
    return (b / 1048576).toFixed(1).replace('.', ',') + ' MB';
  }
  function quando(ms) {
    if (!ms) return '';
    var d = new Date(ms);
    var hoje = new Date();
    var hora = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
    return d.toDateString() === hoje.toDateString() ? hora : d.toLocaleDateString('pt-BR') + ' ' + hora;
  }
  function status(id, texto, erro) {
    var alvo = el(id);
    if (!alvo) return;
    alvo.textContent = texto;
    alvo.classList.toggle('erro', !!erro);
  }
  function limpar(no) { while (no && no.firstChild) no.removeChild(no.firstChild); }
  function tag(nome, classe, texto) {
    var n = document.createElement(nome);
    if (classe) n.className = classe;
    if (texto != null) n.textContent = texto;
    return n;
  }

  /* ------------------------------- Abas ------------------------------- */
  function mostrarAba(nome) {
    ['arquivos', 'cad', 'tarefas', 'diagnostico'].forEach(function (a) {
      var sec = el('pcx-aba-' + a);
      if (sec) sec.hidden = a !== nome;
    });
    var abas = document.querySelectorAll('.pcx-aba');
    for (var i = 0; i < abas.length; i++) {
      var ativa = abas[i].dataset.pcxAba === nome;
      abas[i].classList.toggle('ativo', ativa);
      abas[i].setAttribute('aria-selected', ativa ? 'true' : 'false');
    }
    if (nome === 'cad' && !estado.geo) carregarFormatos().catch(function () {});
    if (nome === 'tarefas') renderHistorico();
  }

  /* ------------------------------ Arquivos ---------------------------- */
  async function listar(caminho) {
    status('pcx-arq-status', 'Lendo a pasta…');
    try {
      var r = await pedir('arq_listar', { caminho: caminho || estado.caminho });
      estado.caminho = r.relativo;
      estado.pai = r.pai;
      var campo = el('pcx-caminho');
      if (campo) campo.value = r.relativo;
      var org = el('pcx-org-pasta');
      if (org) org.textContent = r.relativo;
      var caixa = el('pcx-lista');
      limpar(caixa);
      if (!r.itens.length) caixa.appendChild(tag('p', 'dica', 'Pasta vazia.'));
      r.itens.forEach(function (item) {
        var b = tag('button', 'pcx-item' + (item.pasta ? ' pasta' : ''));
        b.type = 'button';
        b.appendChild(tag('span', 'pcx-item-nome', (item.pasta ? '▸ ' : '· ') + item.nome));
        var meta = item.pasta ? 'pasta' : (item.descricao || item.formato) + ' · ' + kb(item.bytes);
        b.appendChild(tag('span', 'pcx-item-meta', meta));
        b.onclick = function () {
          if (item.pasta) listar(item.caminho);
          else prever(item.caminho);
        };
        caixa.appendChild(b);
      });
      status('pcx-arq-status', r.itens.length + ' item(ns) em ' + r.relativo + '.');
      return r;
    } catch (e) {
      status('pcx-arq-status', 'Não consegui listar: ' + (e && e.message ? e.message : e), true);
      throw e;
    }
  }

  async function prever(caminho) {
    status('pcx-arq-status', 'Abrindo ' + caminho + '…');
    try {
      var r = await pedir('arq_ler', { caminho: caminho });
      estado.arquivo = r.relativo;
      var caixa = el('pcx-previa');
      limpar(caixa);
      var cab = tag('div', 'pcx-previa-topo');
      cab.appendChild(tag('b', '', r.nome));
      cab.appendChild(tag('span', 'pcx-selo', r.descricao));
      caixa.appendChild(cab);
      caixa.appendChild(tag('p', 'dica', r.resumo));

      if (r.imagem) {
        var img = document.createElement('img');
        img.src = r.imagem;
        img.alt = 'Prévia de ' + r.nome;
        img.className = 'pcx-imagem';
        caixa.appendChild(img);
      }
      if (r.tabela && r.tabela.linhas && r.tabela.linhas.length) {
        var tabela = tag('table', 'pcx-tabela');
        r.tabela.linhas.slice(0, 40).forEach(function (linha, i) {
          var tr = document.createElement('tr');
          linha.forEach(function (celula) {
            var td = document.createElement(i === 0 ? 'th' : 'td');
            td.textContent = celula;
            tr.appendChild(td);
          });
          tabela.appendChild(tr);
        });
        caixa.appendChild(tabela);
      }
      if (r.meta) {
        var pre = tag('pre', 'pcx-meta');
        pre.textContent = JSON.stringify(r.meta, null, 2);
        caixa.appendChild(pre);
      }
      if (typeof r.texto === 'string' && !r.tabela) {
        var area = document.createElement('textarea');
        area.className = 'pcx-editor';
        area.rows = 12;
        area.spellcheck = false;
        area.value = r.texto;
        area.readOnly = !r.editavel;
        caixa.appendChild(area);
        if (r.editavel) {
          var salvar = tag('button', 'primario', 'Salvar com backup');
          salvar.type = 'button';
          salvar.onclick = async function () {
            status('pcx-arq-status', 'Gravando…');
            try {
              // O hash vai junto: se outra janela/programa alterou o arquivo depois da
              // prévia, o processo principal recusa em vez de sobrescrever em silêncio.
              var g = await pedir('arq_salvar', { caminho: r.relativo, texto: area.value, backup: true, hashEsperado: r.hash });
              status('pcx-arq-status', 'Salvo em ' + g.relativo + ' (' + kb(g.bytes) + ')' + (g.backup ? '; cópia anterior em ' + g.backup : '') + '.');
              await prever(r.relativo);
            } catch (e) {
              status('pcx-arq-status', 'Não salvei: ' + (e && e.message ? e.message : e), true);
            }
          };
          caixa.appendChild(salvar);
        } else {
          caixa.appendChild(tag('p', 'dica', 'Somente leitura: este formato não é editado no painel.'));
        }
      }
      var acoes = tag('div', 'botoes');
      var sistema = tag('button', 'secundario', 'Abrir no sistema');
      sistema.type = 'button';
      sistema.onclick = function () {
        pedir('arq_abrir', { caminho: r.relativo }).catch(function (e) {
          status('pcx-arq-status', 'Não consegui abrir: ' + (e && e.message ? e.message : e), true);
        });
      };
      acoes.appendChild(sistema);
      var comparar = tag('button', 'secundario', 'Comparar…');
      comparar.type = 'button';
      comparar.onclick = function () {
        var campo = el('pcx-comparar-com');
        if (campo) campo.value = r.relativo;
        mostrarAba('arquivos');
        status('pcx-arq-status', 'Agora informe o outro arquivo em "Comparar com" e toque em Comparar.');
      };
      acoes.appendChild(comparar);
      var verificar = tag('button', 'secundario', 'Verificar integridade');
      verificar.type = 'button';
      verificar.onclick = async function () {
        status('pcx-arq-status', 'Conferindo a estrutura do arquivo…');
        try {
          var v = await pedir('arq_verificar', { caminho: r.relativo });
          status('pcx-arq-status', v.resumo, !v.ok);
        } catch (e) {
          status('pcx-arq-status', 'Não verifiquei: ' + (e && e.message ? e.message : e), true);
        }
      };
      acoes.appendChild(verificar);
      caixa.appendChild(acoes);
      status('pcx-arq-status', 'Prévia de ' + r.relativo + ' (' + kb(r.bytes) + ').');
    } catch (e) {
      status('pcx-arq-status', 'Não consegui abrir: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function comparar() {
    var campo = el('pcx-comparar-com');
    if (!estado.arquivo) { status('pcx-arq-status', 'Abra primeiro o arquivo de origem.', true); return; }
    var outro = campo ? campo.value.trim() : '';
    if (!outro) { status('pcx-arq-status', 'Informe o segundo arquivo para comparar.', true); return; }
    try {
      var r = await pedir('arq_comparar', { a: estado.arquivo, b: outro });
      var caixa = el('pcx-previa');
      limpar(caixa);
      caixa.appendChild(tag('b', '', 'Comparação: ' + r.a + ' ↔ ' + r.b));
      caixa.appendChild(tag('p', 'dica', r.resumo));
      var pre = tag('pre', 'pcx-meta');
      pre.textContent = r.blocos.map(function (b) {
        return (b.tipo === 'removida' ? '- ' : '+ ') + 'linha ' + b.linha + ': ' + b.texto;
      }).join('\n') || 'sem diferenças';
      caixa.appendChild(pre);
      status('pcx-arq-status', r.resumo);
    } catch (e) {
      status('pcx-arq-status', 'Não comparei: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function converter() {
    if (!estado.arquivo) { status('pcx-arq-status', 'Abra o arquivo que será convertido.', true); return; }
    var alvo = el('pcx-converter-alvo').value;
    try {
      var r = await pedir('arq_converter', { caminho: estado.arquivo, alvo: alvo });
      status('pcx-arq-status', 'Convertido para ' + r.relativo + ' (' + kb(r.bytes) + ')' + (r.perdas && r.perdas.length ? '; perdas: ' + r.perdas.join(' ') : '') + '.');
      await listar(estado.caminho);
    } catch (e) {
      status('pcx-arq-status', 'Não converti: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function organizar(aplicar) {
    status('pcx-arq-status', aplicar ? 'Movendo arquivos…' : 'Calculando o plano…');
    try {
      var r = await pedir('arq_organizar', { pasta: estado.caminho, aplicar: !!aplicar });
      estado.plano = r;
      var caixa = el('pcx-previa');
      limpar(caixa);
      caixa.appendChild(tag('b', '', aplicar ? 'Organização aplicada' : 'Plano de organização (nada foi movido)'));
      caixa.appendChild(tag('p', 'dica', r.resumo));
      var lista = tag('ul', 'pcx-plano');
      r.plano.slice(0, 80).forEach(function (p) {
        lista.appendChild(tag('li', '', p.acao === 'mover' ? p.arquivo + ' → ' + p.pasta + '/' : p.arquivo + ' (fica onde está)'));
      });
      caixa.appendChild(lista);
      if (aplicar && r.erros && r.erros.length) caixa.appendChild(tag('p', 'erro', 'Falhas: ' + r.erros.join('; ')));
      var botao = el('pcx-organizar-aplicar');
      if (botao) botao.disabled = !r.mover || aplicar;
      status('pcx-arq-status', r.resumo);
      if (aplicar) await listar(estado.caminho);
    } catch (e) {
      status('pcx-arq-status', 'Não organizei: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function novaPasta() {
    var nome = window.prompt('Nome da nova pasta em ' + estado.caminho, 'nova-pasta');
    if (!nome) return;
    try {
      var r = await pedir('arq_criar_pasta', { pasta: estado.caminho, nome: nome });
      status('pcx-arq-status', 'Pasta criada: ' + r.caminho);
      await listar(estado.caminho);
    } catch (e) {
      status('pcx-arq-status', 'Não criei a pasta: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function buscar() {
    var termo = el('pcx-busca').value.trim();
    if (termo.length < 2) { status('pcx-arq-status', 'Digite pelo menos 2 caracteres.', true); return; }
    status('pcx-arq-status', 'Pesquisando em ' + estado.caminho + '…');
    try {
      var r = await pedir('arq_pesquisar', { termo: termo, pasta: estado.caminho, limite: 60 });
      var caixa = el('pcx-previa');
      limpar(caixa);
      caixa.appendChild(tag('b', '', 'Pesquisa: "' + r.termo + '" em ' + r.pasta));
      caixa.appendChild(tag('p', 'dica', r.resumo));
      r.achados.forEach(function (a) {
        var b = tag('button', 'pcx-achado', a.caminho + ' · linha ' + a.linha);
        b.type = 'button';
        b.title = a.trecho;
        b.appendChild(tag('span', 'pcx-item-meta', a.trecho));
        b.onclick = function () { prever(a.caminho); };
        caixa.appendChild(b);
      });
      status('pcx-arq-status', r.resumo);
    } catch (e) {
      status('pcx-arq-status', 'A busca falhou: ' + (e && e.message ? e.message : e), true);
    }
  }

  /* -------------------------------- CAD -------------------------------- */
  async function abrirCad(caminho) {
    status('pcx-cad-status', 'Identificando o arquivo…');
    status('pcx-cad-exp-status', '');
    try {
      var info = await pedir('cad_identificar', { caminho: caminho });
      if (!info.aberto) {
        status('pcx-cad-status', 'Formato ' + info.formato + ' não é legível aqui: ' + info.obs, true);
        var props = el('pcx-cad-props');
        limpar(props);
        props.appendChild(tag('p', 'dica', info.descricao + ' · ' + info.obs));
        return;
      }
      var r = await pedir('cad_abrir', { caminho: caminho });
      if (!r.ok) { status('pcx-cad-status', r.erro, true); return; }
      estado.geo = r;
      el('pcx-cad-caminho').value = caminho;
      status('pcx-cad-status', r.resumo + (r.limitacoes && r.limitacoes.length ? ' Limitações: ' + r.limitacoes.join(' ') : ''));
      var p = el('pcx-cad-props');
      limpar(p);
      var dl = document.createElement('dl');
      [['Formato', r.formato.toUpperCase() + ' — ' + r.descricao],
       ['Arquivo', r.nome + ' (' + kb(r.bytes) + ')'],
       ['Geometria', r.geometria ? (r.geometria.tipo === '2d' ? r.geometria.segmentos.length + ' segmento(s)' : r.geometria.totalTriangulos + ' triângulo(s)') : 'sem geometria para desenhar']
      ].forEach(function (par) {
        dl.appendChild(tag('dt', '', par[0]));
        dl.appendChild(tag('dd', '', par[1]));
      });
      Object.keys(r.propriedades || {}).forEach(function (k) {
        var v = r.propriedades[k];
        if (v && typeof v === 'object') v = Array.isArray(v) ? v.length + ' item(ns)' : JSON.stringify(v).slice(0, 160);
        dl.appendChild(tag('dt', '', k));
        dl.appendChild(tag('dd', '', String(v)));
      });
      p.appendChild(dl);
      ajustarVista();
      desenhar();
    } catch (e) {
      status('pcx-cad-status', 'Não abri: ' + (e && e.message ? e.message : e), true);
    }
  }

  function ajustarVista() {
    var g = estado.geo && estado.geo.geometria;
    var cv = el('pcx-canvas');
    if (!g || !cv) return;
    var caixa = g.tipo === '3d' ? g.bbox.tamanho : [g.bbox.tamanho[0], g.bbox.tamanho[1]];
    var maior = Math.max(caixa[0] || 1, caixa[1] || 1, caixa[2] || 1);
    estado.vista.escala = Math.min(cv.width, cv.height) / (maior * 1.35);
    estado.vista.ox = 0;
    estado.vista.oy = 0;
    estado.vista.giro = 0.7;
    estado.vista.incl = 0.45;
  }

  function projetar(p, v) {
    var cy = Math.cos(v.giro), sy = Math.sin(v.giro);
    var cp = Math.cos(v.incl), sp = Math.sin(v.incl);
    var x = p[0] * cy - p[1] * sy;
    var y = p[0] * sy + p[1] * cy;
    var z = p[2] || 0;
    return [x, y * cp - z * sp, y * sp + z * cp];
  }

  function desenhar() {
    var cv = el('pcx-canvas');
    if (!cv) return;
    var ctx = cv.getContext('2d');
    if (!ctx) return;
    var largura = cv.width, altura = cv.height;
    ctx.clearRect(0, 0, largura, altura);
    ctx.fillStyle = '#04070d';
    ctx.fillRect(0, 0, largura, altura);
    var g = estado.geo && estado.geo.geometria;
    if (!g) {
      ctx.fillStyle = '#8ba3b7';
      ctx.font = '14px system-ui';
      ctx.fillText('Abra um .cad, DXF ou STL para ver o modelo.', 20, 32);
      return;
    }
    var v = estado.vista;
    var cx = largura / 2 + v.ox, cy = altura / 2 + v.oy;
    var centro = g.tipo === '3d'
      ? [(g.bbox.min[0] + g.bbox.max[0]) / 2, (g.bbox.min[1] + g.bbox.max[1]) / 2, (g.bbox.min[2] + g.bbox.max[2]) / 2]
      : [(g.bbox.min[0] + g.bbox.max[0]) / 2, (g.bbox.min[1] + g.bbox.max[1]) / 2, 0];
    ctx.lineWidth = 1;
    if (g.tipo === '2d') {
      var cores = ['#4cd7ff', '#7be3c0', '#ffd479', '#ff9fb2', '#b9a3ff', '#9ad0ff'];
      var porCamada = {};
      g.camadas.forEach(function (c, i) { porCamada[c] = cores[i % cores.length]; });
      ctx.beginPath();
      g.segmentos.forEach(function (s) {
        var a = projetar([s.x1 - centro[0], s.y1 - centro[1], 0], v);
        var b = projetar([s.x2 - centro[0], s.y2 - centro[1], 0], v);
        ctx.moveTo(cx + a[0] * v.escala, cy - a[1] * v.escala);
        ctx.lineTo(cx + b[0] * v.escala, cy - b[1] * v.escala);
      });
      ctx.strokeStyle = '#4cd7ff';
      ctx.globalAlpha = 0.85;
      ctx.stroke();
      ctx.globalAlpha = 1;
    } else {
      var verts = g.vertices;
      var faces = [];
      g.triangulos.forEach(function (t) {
        var a = projetar([verts[t[0] * 3] - centro[0], verts[t[0] * 3 + 1] - centro[1], verts[t[0] * 3 + 2] - centro[2]], v);
        var b = projetar([verts[t[1] * 3] - centro[0], verts[t[1] * 3 + 1] - centro[1], verts[t[1] * 3 + 2] - centro[2]], v);
        var c = projetar([verts[t[2] * 3] - centro[0], verts[t[2] * 3 + 1] - centro[1], verts[t[2] * 3 + 2] - centro[2]], v);
        faces.push({ a: a, b: b, c: c, z: (a[2] + b[2] + c[2]) / 3 });
      });
      faces.sort(function (x, y) { return x.z - y.z; });
      var minZ = faces.length ? faces[0].z : 0;
      var maxZ = faces.length ? faces[faces.length - 1].z : 1;
      faces.forEach(function (f) {
        var t = maxZ === minZ ? 0.5 : (f.z - minZ) / (maxZ - minZ);
        var luz = 30 + Math.round(t * 120);
        ctx.beginPath();
        ctx.moveTo(cx + f.a[0] * v.escala, cy - f.a[1] * v.escala);
        ctx.lineTo(cx + f.b[0] * v.escala, cy - f.b[1] * v.escala);
        ctx.lineTo(cx + f.c[0] * v.escala, cy - f.c[1] * v.escala);
        ctx.closePath();
        ctx.fillStyle = 'rgb(' + Math.round(luz * 0.35) + ',' + Math.round(luz * 0.85) + ',' + luz + ')';
        ctx.globalAlpha = 0.92;
        ctx.fill();
        ctx.globalAlpha = 0.25;
        ctx.strokeStyle = '#9ad0ff';
        ctx.stroke();
        ctx.globalAlpha = 1;
      });
    }
    var info = el('pcx-cad-info');
    if (info) {
      info.textContent = g.tipo === '2d'
        ? g.segmentos.length + ' segmento(s) · ' + (g.truncada ? 'parcial · ' : '') + 'arraste para deslocar, roda para zoom'
        : g.totalTriangulos + ' triângulo(s)' + (g.truncada ? ' (prévia parcial)' : '') + ' · arraste para girar, roda para zoom';
    }
  }

  async function criarCad() {
    var tipo = el('pcx-cad-tipo').value;
    var d1 = Number(el('pcx-cad-d1').value) || 0;
    var d2 = Number(el('pcx-cad-d2').value) || 0;
    var d3 = Number(el('pcx-cad-d3').value) || 0;
    var obj = tipo === 'caixa' ? { tipo: tipo, nome: 'base', posicao: [0, 0, 0], dimensoes: [d1, d2, d3] }
      : tipo === 'plano' ? { tipo: tipo, nome: 'plano', posicao: [0, 0, 0], dimensoes: [d1, d2] }
        : tipo === 'esfera' ? { tipo: tipo, nome: 'esfera', posicao: [0, 0, 0], raio: d1 }
          : { tipo: tipo, nome: tipo, posicao: [0, 0, 0], raio: d1, altura: d2 };
    status('pcx-cad-status', 'Criando e validando o arquivo…');
    try {
      var r = await pedir('cad_criar', {
        nome: el('pcx-cad-nome').value || 'peca-pc',
        pasta: estado.caminho === '~' ? '~/Jarvis' : estado.caminho,
        unidades: el('pcx-cad-unidades').value,
        objetos: [obj]
      });
      status('pcx-cad-status', 'Criado ' + r.nome + ' (' + r.objetos + ' objeto(s), ' + r.unidades + '); ' + r.validacao + '.');
      await abrirCad(r.arquivo);
      if (el('pcx-aba-arquivos') && !el('pcx-aba-arquivos').hidden) listar(estado.caminho).catch(function () {});
    } catch (e) {
      status('pcx-cad-status', 'Não criei: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function modificarCad() {
    var caminho = el('pcx-cad-caminho').value.trim();
    if (!caminho) { status('pcx-cad-status', 'Abra um .cad antes de alterar.', true); return; }
    var indice = Math.max(1, Number(el('pcx-cad-obj').value) || 1) - 1;
    var edicao = { indice: indice };
    var d1 = el('pcx-cad-novo-d1').value;
    var d2 = el('pcx-cad-novo-d2').value;
    var props = (estado.geo && estado.geo.propriedades && estado.geo.propriedades.objetosDetalhe) || [];
    var alvo = props[indice];
    if (!alvo) { status('pcx-cad-status', 'Este arquivo não tem objeto ' + (indice + 1) + ' para editar.', true); return; }
    if (alvo.dimensoes) {
      var dims = alvo.dimensoes.slice();
      if (d1) dims[0] = Number(d1);
      if (d2 && dims.length > 1) dims[1] = Number(d2);
      edicao.dimensoes = dims;
    } else if (alvo.raio != null) {
      if (d1) edicao.raio = Number(d1);
      if (d2 && alvo.altura != null) edicao.altura = Number(d2);
    }
    status('pcx-cad-status', 'Gerando nova versão…');
    try {
      var r = await pedir('cad_modificar', { caminho: caminho, edicoes: [edicao] });
      status('pcx-cad-status', 'Nova versão: ' + r.nome + ' (original ' + r.original + ' intacto). ' + r.validacao + '.');
      await abrirCad(r.arquivo);
    } catch (e) {
      status('pcx-cad-status', 'Não alterei: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function exportarCad() {
    var caminho = el('pcx-cad-caminho').value.trim();
    if (!caminho) { status('pcx-cad-exp-status', 'Abra um .cad antes de exportar.', true); return; }
    status('pcx-cad-exp-status', 'Exportando e reabrindo para validar…');
    try {
      var r = await pedir('cad_exportar', { caminho: caminho, formato: el('pcx-cad-formato').value });
      var v = r.validacao ? (r.validacao.ok === false ? 'validação falhou: ' + r.validacao.erro : 'reaberto com sucesso') : 'sem validação disponível';
      status('pcx-cad-exp-status', r.nome + ' (' + kb(r.bytes) + '), ' + v + '.' + (r.perdas && r.perdas.length ? ' Perdas: ' + r.perdas.join(' ') : ''));
    } catch (e) {
      status('pcx-cad-exp-status', 'Não exportei: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function carregarFormatos() {
    var caixa = el('pcx-cad-matriz');
    if (!caixa || caixa.childElementCount) return;
    var lista = await pedir('cad_formatos', {});
    var tabela = tag('table', 'pcx-tabela');
    var cab = document.createElement('tr');
    ['Formato', 'Lê', 'Gera', 'Edita', 'No PC'].forEach(function (t) { cab.appendChild(tag('th', '', t)); });
    tabela.appendChild(cab);
    lista.forEach(function (f) {
      var tr = document.createElement('tr');
      tr.appendChild(tag('td', '', f.nome));
      tr.appendChild(tag('td', '', f.le ? 'sim' : 'não'));
      tr.appendChild(tag('td', '', f.escreve ? 'sim' : 'não'));
      tr.appendChild(tag('td', '', f.edita ? 'sim' : 'não'));
      tr.appendChild(tag('td', 'pcx-nota', f.desktop));
      tabela.appendChild(tr);
    });
    caixa.appendChild(tabela);
  }

  /* ------------------------------ Tarefas ----------------------------- */
  function passosDe(texto) {
    return String(texto || '').split('\n').map(function (l) { return l.trim(); }).filter(Boolean).map(function (linha) {
      var partes = linha.split(/\s+/);
      var acao = partes[0].toLowerCase();
      var resto = partes.slice(1);
      if (acao === 'listar') return { acao: 'arq_listar', args: { caminho: resto[0] || '~' } };
      if (acao === 'procurar' || acao === 'pesquisar') return { acao: 'arq_pesquisar', args: { termo: resto[0] || '', pasta: resto[1] || '~' } };
      if (acao === 'organizar') return { acao: 'arq_organizar', args: { pasta: resto[0] || '~', aplicar: true } };
      if (acao === 'converter') return { acao: 'arq_converter', args: { caminho: resto[0] || '', alvo: resto[1] || '' } };
      if (acao === 'pasta') return { acao: 'arq_criar_pasta', args: { pasta: resto[0] || '~', nome: resto.slice(1).join(' ') } };
      if (acao === 'identificar') return { acao: 'cad_identificar', args: { caminho: resto[0] || '' } };
      if (acao === 'abrir') return { acao: 'cad_abrir', args: { caminho: resto[0] || '' } };
      if (acao === 'exportar') return { acao: 'cad_exportar', args: { caminho: resto[0] || '', formato: resto[1] || 'stl' } };
      throw new Error('Passo desconhecido: ' + acao + '. Use listar, procurar, organizar, converter, pasta, identificar, abrir ou exportar.');
    });
  }

  async function rodarTarefa() {
    var passos;
    try { passos = passosDe(el('pcx-tarefa-passos').value); }
    catch (e) { status('pcx-tarefa-relatorio', e.message, true); return; }
    if (!passos.length) { status('pcx-tarefa-relatorio', 'Escreva pelo menos um passo.', true); return; }
    status('pcx-tarefa-relatorio', 'Executando ' + passos.length + ' passo(s)…');
    try {
      var r = await pedir('tarefas_executar', { titulo: 'Tarefa do painel', passos: passos });
      var caixa = el('pcx-tarefa-relatorio');
      limpar(caixa);
      caixa.appendChild(tag('b', '', r.resumo));
      r.relatorio.forEach(function (p) {
        caixa.appendChild(tag('div', p.ok ? 'pcx-passo ok' : 'pcx-passo falha',
          (p.ok ? '✓ ' : '✕ ') + p.passo + '. ' + p.acao + (p.ok ? (p.resultado ? ' — ' + p.resultado : '') : ' — ' + p.erro)));
      });
      salvarHistorico(r);
    } catch (e) {
      status('pcx-tarefa-relatorio', 'A tarefa falhou: ' + (e && e.message ? e.message : e), true);
    }
  }

  function historico() {
    try { return JSON.parse(window.localStorage.getItem('jv_pc_tarefas') || '[]'); } catch (e) { return []; }
  }
  function salvarHistorico(r) {
    try {
      var lista = historico();
      lista.unshift({ titulo: r.titulo, resumo: r.resumo, quando: Date.now(), passos: r.passos, concluidos: r.concluidos });
      window.localStorage.setItem('jv_pc_tarefas', JSON.stringify(lista.slice(0, 12)));
      renderHistorico();
    } catch (e) { /* sem espaço */ }
  }
  function renderHistorico() {
    var caixa = el('pcx-tarefa-historico');
    if (!caixa) return;
    limpar(caixa);
    var lista = historico();
    if (!lista.length) { caixa.appendChild(tag('p', 'dica', 'Nenhuma tarefa executada ainda.')); return; }
    lista.forEach(function (t) {
      caixa.appendChild(tag('div', 'pcx-historico-item', quando(t.quando) + ' · ' + t.titulo + ' · ' + t.resumo));
    });
  }

  /* ---------------------------- Diagnóstico --------------------------- */
  async function rodarDiag() {
    status('pcx-diag-resumo', 'Verificando este computador…');
    try {
      var r = await pedir('diag_pc', {});
      status('pcx-diag-resumo', r.resumo);
      var caixa = el('pcx-diag-lista');
      limpar(caixa);
      var grupos = {};
      r.itens.forEach(function (i) { (grupos[i.grupo] = grupos[i.grupo] || []).push(i); });
      Object.keys(grupos).forEach(function (g) {
        caixa.appendChild(tag('h3', '', g));
        grupos[g].forEach(function (i) {
          var linha = tag('div', 'pcx-diag-item estado-' + i.estado);
          linha.appendChild(tag('b', '', i.nome));
          linha.appendChild(tag('span', 'pcx-selo', i.estado));
          linha.appendChild(tag('p', 'dica', i.detalhe));
          if (i.impacto) linha.appendChild(tag('p', 'pcx-impacto', 'Impacto: ' + i.impacto));
          if (i.acao) linha.appendChild(tag('p', 'pcx-impacto', 'Onde resolver: ' + i.acao));
          caixa.appendChild(linha);
        });
      });
    } catch (e) {
      status('pcx-diag-resumo', 'A verificação falhou: ' + (e && e.message ? e.message : e), true);
    }
  }

  async function copiarDiag() {
    var caixa = el('pcx-diag-lista');
    var texto = caixa ? caixa.innerText : '';
    if (!texto.trim()) { status('pcx-diag-resumo', 'Rode a verificação antes de copiar.', true); return; }
    try {
      await navigator.clipboard.writeText(texto);
      status('pcx-diag-resumo', 'Detalhes copiados.');
    } catch (e) {
      status('pcx-diag-resumo', 'Não consegui copiar: ' + (e && e.message ? e.message : e), true);
    }
  }

  /* ------------------------------ Ligação ----------------------------- */
  function ligar() {
    var botaoNav = document.querySelector('[data-lat="pc"]');
    if (botaoNav) botaoNav.hidden = false;
    var chip = el('pcx-plat');
    if (chip) chip.textContent = ({ win32: 'Windows', darwin: 'macOS', linux: 'Linux' }[nativo.platform] || 'desktop');

    document.querySelectorAll('.pcx-aba').forEach(function (b) {
      b.onclick = function () { mostrarAba(b.dataset.pcxAba); };
    });
    var pares = [
      ['pcx-atualizar', function () { listar(estado.caminho); }],
      ['pcx-subir', function () { if (estado.pai) listar(estado.pai); }],
      ['pcx-nova-pasta', novaPasta],
      ['pcx-buscar', buscar],
      ['pcx-comparar', comparar],
      ['pcx-converter', converter],
      ['pcx-organizar', function () { organizar(false); }],
      ['pcx-organizar-aplicar', function () { organizar(true); }],
      ['pcx-cad-abrir', function () { abrirCad(el('pcx-cad-caminho').value.trim()); }],
      ['pcx-cad-ajustar', function () { ajustarVista(); desenhar(); }],
      ['pcx-cad-exportar', exportarCad],
      ['pcx-cad-criar', criarCad],
      ['pcx-cad-modificar', modificarCad],
      ['pcx-tarefa-rodar', rodarTarefa],
      ['pcx-tarefa-cancelar', function () { pedir('tarefas_cancelar', {}).then(function () { status('pcx-tarefa-relatorio', 'Cancelamento solicitado; a tarefa para no próximo passo.'); }); }],
      ['pcx-diag-rodar', rodarDiag],
      ['pcx-diag-copiar', copiarDiag],
      ['pcx-fechar', function () { if (typeof fecharPaineis === 'function') fecharPaineis(); }]
    ];
    pares.forEach(function (par) {
      var b = el(par[0]);
      if (b) b.onclick = par[1];
    });
    var campo = el('pcx-caminho');
    if (campo) campo.onkeydown = function (ev) { if (ev.key === 'Enter') { ev.preventDefault(); listar(campo.value); } };

    var cv = el('pcx-canvas');
    if (cv) {
      cv.onpointerdown = function (ev) {
        estado.arrastando = true;
        cv.setPointerCapture(ev.pointerId);
        cv.dataset.ultimoX = ev.clientX;
        cv.dataset.ultimoY = ev.clientY;
      };
      cv.onpointermove = function (ev) {
        if (!estado.arrastando) return;
        var dx = ev.clientX - Number(cv.dataset.ultimoX || ev.clientX);
        var dy = ev.clientY - Number(cv.dataset.ultimoY || ev.clientY);
        cv.dataset.ultimoX = ev.clientX;
        cv.dataset.ultimoY = ev.clientY;
        var g = estado.geo && estado.geo.geometria;
        if (g && g.tipo === '3d') {
          estado.vista.giro += dx * 0.01;
          estado.vista.incl = Math.max(-1.4, Math.min(1.4, estado.vista.incl + dy * 0.01));
        } else {
          estado.vista.ox += dx;
          estado.vista.oy += dy;
        }
        desenhar();
      };
      cv.onpointerup = function () { estado.arrastando = false; };
      cv.onwheel = function (ev) {
        ev.preventDefault();
        estado.vista.escala = Math.max(0.02, Math.min(200, estado.vista.escala * (ev.deltaY < 0 ? 1.12 : 0.89)));
        desenhar();
      };
    }
  }

  function abrir() {
    mostrarAba('arquivos');
    if (typeof abrirPainel === 'function') abrirPainel('#painel-pc');
    if (!estado.ligado) {
      estado.ligado = true;
      listar('~').catch(function () {});
    }
  }

  window.PcPainel = { abrir: abrir, listar: listar, abrirCad: abrirCad, rodarDiag: rodarDiag };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ligar);
  else ligar();
})();
