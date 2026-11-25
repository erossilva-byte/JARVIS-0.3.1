/* J.A.R.V.I.S. Nova — Cofre em pasta no PC.
 *
 * O celular usa o seletor de pastas do Android (SAF). No PC o caminho é o mesmo
 * em espírito: o usuário escolhe uma pasta do Obsidian, o aplicativo lê e grava
 * arquivos `.md` nela, e o formato é o mesmo das notas do celular.
 *
 * Regras de segurança:
 *  - só arquivos `.md`, sempre dentro da pasta escolhida (caminho relativo
 *    conferido contra `..` e contra link que saia da pasta);
 *  - nada é apagado: a sincronização só cria ou reescreve o arquivo da própria
 *    nota, e conflito não sobrescreve nenhum dos lados;
 *  - leitura tem teto de arquivos e de bytes, para uma pasta enorme não travar
 *    a janela;
 *  - a pasta escolhida fica lembrada num JSON pequeno em `userData`.
 *
 * Este módulo roda no processo principal do Electron; a regra de sincronização
 * vem de `memoria_regras.js`, a mesma testada em Node.
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const MEM = require('../../memoria_regras.js');

const LIMITE_ARQUIVOS = 400;
const LIMITE_CONTEUDO = 200 * 1024;

function normalizarCaminho(caminho) {
  return String(caminho == null ? '' : caminho).replace(/\\/g, '/')
    .split('/').filter((parte) => parte.length > 0).join('/');
}

function criarCofre(opcoes) {
  const o = opcoes || {};
  const dirDados = o.dirDados || '';
  const arquivoConfig = path.join(dirDados, 'memoria-pasta.json');
  const dialogo = o.dialogo || null;

  function lerConfig() {
    try {
      const dados = JSON.parse(fs.readFileSync(arquivoConfig, 'utf8'));
      if (dados && typeof dados.caminho === 'string' && dados.caminho) return dados;
    } catch (erro) { /* primeira vez ou arquivo inválido */ }
    return null;
  }

  function gravarConfig(dados) {
    fs.mkdirSync(dirDados, { recursive: true });
    const temporario = arquivoConfig + '.tmp';
    fs.writeFileSync(temporario, JSON.stringify(dados, null, 2), 'utf8');
    fs.renameSync(temporario, arquivoConfig);
  }

  /** Pasta configurada, conferindo se ela ainda existe e é uma pasta. */
  function pastaAtual() {
    const cfg = lerConfig();
    if (!cfg) return { ok: true, pasta: null };
    let existe = false;
    try { existe = fs.statSync(cfg.caminho).isDirectory(); } catch (erro) { existe = false; }
    if (!existe) {
      return {
        ok: false,
        pasta: { caminho: cfg.caminho, nome: path.basename(cfg.caminho), existe: false },
        erro: 'A pasta escolhida não está mais acessível. Escolha a pasta do Obsidian de novo.'
      };
    }
    return { ok: true, pasta: { caminho: cfg.caminho, nome: path.basename(cfg.caminho), existe: true } };
  }

  async function escolher() {
    if (!dialogo || typeof dialogo.showOpenDialog !== 'function') {
      return { ok: false, erro: 'O seletor de pastas só existe no aplicativo do PC.' };
    }
    const escolha = await dialogo.showOpenDialog({
      title: 'Escolha a pasta do Obsidian',
      properties: ['openDirectory', 'createDirectory']
    });
    if (escolha.canceled || !escolha.filePaths || !escolha.filePaths.length) {
      return { ok: true, pasta: null, cancelado: true };
    }
    const caminho = escolha.filePaths[0];
    gravarConfig({ caminho: caminho, escolhidaEm: new Date().toISOString() });
    return { ok: true, pasta: { caminho: caminho, nome: path.basename(caminho), existe: true } };
  }

  function esquecer() {
    try { fs.rmSync(arquivoConfig, { force: true }); } catch (erro) { /* já não havia */ }
    return { ok: true };
  }

  function raiz() {
    const estado = pastaAtual();
    if (!estado.ok || !estado.pasta || !estado.pasta.existe) {
      return { ok: false, erro: (estado && estado.erro) || 'Nenhuma pasta escolhida ainda. Escolha a pasta do Obsidian primeiro.' };
    }
    return { ok: true, caminho: estado.pasta.caminho };
  }

  /** Caminho absoluto de uma nota da pasta, recusando tudo que saia dela. */
  function resolver(caminhoRelativo) {
    const estado = raiz();
    if (!estado.ok) return estado;
    const bruto = String(caminhoRelativo == null ? '' : caminhoRelativo)
      .replace(/\\/g, '/');
    // Caminho absoluto (POSIX ou com letra de unidade) não é relativo à pasta:
    // recusar é mais honesto do que reescrever o caminho por conta própria.
    if (bruto.startsWith('/') || /^[A-Za-z]:/.test(bruto)) {
      return { ok: false, erro: 'Use o caminho da nota dentro da pasta escolhida, sem caminho absoluto.' };
    }
    const relativo = normalizarCaminho(caminhoRelativo);
    if (!relativo || relativo.split('/').some((parte) => parte === '..' || parte === '.')) {
      return { ok: false, erro: 'Caminho de nota inválido.' };
    }
    if (relativo.toLowerCase().slice(-3) !== '.md') {
      return { ok: false, erro: 'Só notas .md entram no cofre.' };
    }
    const absoluto = path.resolve(estado.caminho, relativo);
    const base = path.resolve(estado.caminho) + path.sep;
    if (!absoluto.startsWith(base)) {
      return { ok: false, erro: 'A nota tentou sair da pasta escolhida.' };
    }
    return { ok: true, absoluto: absoluto, relativo: relativo, raiz: estado.caminho };
  }

  function varrer(diretorio, base, saida, estado) {
    let entradas = [];
    try { entradas = fs.readdirSync(diretorio, { withFileTypes: true }); } catch (erro) { return; }
    for (const entrada of entradas) {
      if (saida.notas.length + saida.truncadas >= LIMITE_ARQUIVOS) return;
      if (entrada.name.startsWith('.') || entrada.name === 'node_modules') continue;
      const completo = path.join(diretorio, entrada.name);
      if (entrada.isDirectory()) {
        varrer(completo, base, saida, estado);
        continue;
      }
      if (!entrada.name.toLowerCase().endsWith('.md')) { saida.ignoradas++; continue; }
      let texto = '';
      try {
        const info = fs.statSync(completo);
        if (info.size > LIMITE_CONTEUDO) { saida.truncadas++; continue; }
        texto = fs.readFileSync(completo, 'utf8');
      } catch (erro) {
        saida.ignoradas++;
        continue;
      }
      const relativo = normalizarCaminho(path.relative(base, completo));
      saida.notas.push({ nome: entrada.name, caminho: relativo, conteudo: texto });
    }
  }

  function listarNotas() {
    const estado = raiz();
    if (!estado.ok) return estado;
    const saida = { ok: true, notas: [], ignoradas: 0, truncadas: 0 };
    varrer(estado.caminho, estado.caminho, saida, {});
    saida.notas.sort((a, b) => a.caminho.localeCompare(b.caminho, 'pt-BR'));
    return saida;
  }

  function escreverNota(caminhoRelativo, conteudo) {
    const alvo = resolver(caminhoRelativo);
    if (!alvo.ok) return alvo;
    try {
      fs.mkdirSync(path.dirname(alvo.absoluto), { recursive: true });
      const temporario = alvo.absoluto + '.tmp';
      fs.writeFileSync(temporario, String(conteudo == null ? '' : conteudo), 'utf8');
      fs.renameSync(temporario, alvo.absoluto);
      return { ok: true, caminho: alvo.relativo };
    } catch (erro) {
      return { ok: false, erro: 'Não foi possível gravar ' + alvo.relativo + ': ' + (erro && erro.message ? erro.message : erro) };
    }
  }

  /**
   * Concilia o cofre local (enviado pelo renderer) com a pasta, nos dois
   * sentidos. Devolve a lista final de notas do PC para o renderer gravar.
   */
  function sincronizar(notasLocais) {
    const leitura = listarNotas();
    if (!leitura.ok) return leitura;
    const locais = Array.isArray(notasLocais) ? notasLocais : [];
    const plano = MEM.planejarSincronizacao(locais, leitura.notas, { agora: Date.now() });
    const falhas = [];
    const porId = new Map();

    locais.forEach((nota) => { if (nota && nota.id) porId.set(nota.id, nota); });

    for (const envio of plano.envios) {
      const escrita = escreverNota(envio.caminho, envio.conteudo);
      if (!escrita.ok) { falhas.push(escrita.erro); continue; }
      const nota = envio.nota;
      if (nota && nota.id) {
        porId.set(nota.id, Object.assign({}, nota, {
          caminho: envio.caminho,
          hashSincronizado: MEM.hashConteudo(String(nota.texto || '').trim())
        }));
      }
    }

    for (const recebida of plano.recebidas) {
      const nota = recebida.nota;
      if (!nota) continue;
      const existente = porId.get(nota.id);
      porId.set(nota.id, existente ? Object.assign({}, existente, nota) : nota);
    }

    for (const nota of plano.marcar) {
      if (!nota || !nota.id) continue;
      const caminho = nota.caminho || MEM.caminhoParaTitulo(nota.titulo);
      porId.set(nota.id, Object.assign({}, nota, {
        caminho: caminho,
        hashSincronizado: MEM.hashConteudo(String(nota.texto || '').trim())
      }));
    }

    const notas = Array.from(porId.values());
    return {
      ok: true,
      notas: notas,
      resumo: MEM.resumoPlano(plano),
      enviadas: plano.envios.map((e) => e.caminho),
      recebidas: plano.recebidas.map((r) => r.caminho),
      marcadas: plano.marcar.map((n) => n.caminho || MEM.caminhoParaTitulo(n.titulo)),
      conflitos: plano.conflitos.map((c) => ({
        titulo: (c.local && c.local.titulo) || (c.remoto && c.remoto.caminho) || 'nota',
        caminho: (c.remoto && c.remoto.caminho) || '',
        motivo: c.motivo
      })),
      ausentes: plano.ausentesNaPasta.map((n) => n.titulo),
      caminhosDuplicados: plano.caminhosDuplicados.slice(),
      iguais: plano.iguais,
      falhas: falhas
    };
  }

  return {
    pastaAtual: pastaAtual,
    escolher: escolher,
    esquecer: esquecer,
    listarNotas: listarNotas,
    escreverNota: escreverNota,
    sincronizar: sincronizar
  };
}

module.exports = { criarCofre: criarCofre, normalizarCaminho: normalizarCaminho, LIMITE_ARQUIVOS: LIMITE_ARQUIVOS };
