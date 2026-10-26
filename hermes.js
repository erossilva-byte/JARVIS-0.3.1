/* J.A.R.V.I.S. Nova — Hermes Agent: o núcleo de processamento de linguagem e decisão.
 *
 * TODO turno do assistente passa por aqui. O Hermes recebe o texto (vindo da fala ou do
 * teclado), escolhe a rota mais rápida e mais barata que resolve o pedido e devolve uma
 * decisão já validada para o aplicativo executar. As rotas, nesta ordem:
 *
 *   1. habilidade própria do Hermes — saudação/briefing diário, autodiagnóstico do sistema
 *      e status do próprio núcleo. Resposta imediata, no aparelho, com a personalidade do app;
 *   2. comando no aparelho (hora, clima, apps, mídia, volume, lembretes, lanterna...) —
 *      resolvido sem gastar cota de IA nenhuma;
 *   3. IA (nuvem com reservas → modelo local → cérebro local básico), quando nada acima resolveu.
 *
 * O arquivo não toca no DOM e não conhece o aplicativo: tudo o que ele precisa (falar,
 * ler e gravar preferências, consultar o clima, buscar notícias, rodar o diagnóstico,
 * resolver comandos locais) é injetado por app.js em Hermes.instalar(). Assim o mesmo
 * núcleo roda no APK, no desktop e num teste em Node.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.Hermes = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const VERSAO = '1.0.0';
  const NOME = 'Hermes Agent';

  /* ---------- Texto ---------- */
  const semAcento = (t) => String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  // Mesma normalização do aplicativo: pontuação sai, sobra texto plano em minúsculas —
  // assim "Bom dia, Jarvis!" casa com a mesma regra de "bom dia jarvis".
  const norm = (t) => semAcento(t).toLowerCase().replace(/[^a-z0-9: ]+/g, ' ').replace(/\s+/g, ' ').trim();
  // Divide um texto em frases para o briefing falado não virar um parágrafo.
  const frases = (t) => (String(t || '').replace(/\s+/g, ' ').match(/[^.!?]+[.!?]*/g) || []).map((s) => s.trim()).filter(Boolean);
  const primeirasFrases = (t, n) => frases(t).slice(0, Math.max(1, n || 2)).join(' ').trim();
  // Junta nomes em linguagem falada: "a, b e c".
  const listar = (itens) => itens.length <= 1 ? (itens[0] || '') : itens.slice(0, -1).join(', ') + ' e ' + itens[itens.length - 1];
  const porExtenso = (n) => ['nenhuma', 'uma', 'duas', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove', 'dez'][n] || String(n);
  function periodo(d) { const h = (d || new Date()).getHours(); return h < 6 ? 'Boa madrugada' : h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite'; }

  /* ---------- Tom do turno: pressa e assunto sensível ----------
   * O tom vale para o prompt da IA (app.js) e para as frases próprias do aplicativo.
   * Nunca é motivo para recusar ajuda: só muda a intensidade do humor e a extensão.
   */
  const RX_SENSIVEL = /\b(urgente|urgencia|emergencia|socorro|acidente|incendio|infarto|choque|ambulancia|hospital|medico|medica|remedio|doente|dor |febre|depress|suicid|ameaca|assalt|roubaram|me roubaram|medo de|crise|luto|morte|morreu|grave|graves|polici|delegacia|advogad|perdido no)\b/;
  const RX_PRESSA = /\b(rapido|rapida|pressa|agora ja|depressa|resuma|resumido|resumidamente|breve|curto|sem rodeios|to com pressa|correndo|em um minuto|na lata)\b/;

  /* ---------- Telemetria: prova de qual rota resolveu cada turno ---------- */
  const estado = { desde: Date.now(), turnos: 0, rotas: {}, falhas: {}, ultimaRota: '', ultimoTexto: '', somaMs: 0 };
  function contar(rota, ms) {
    estado.turnos++;
    estado.rotas[rota] = (estado.rotas[rota] || 0) + 1;
    estado.ultimaRota = rota;
    if (Number.isFinite(ms) && ms >= 0) estado.somaMs += ms;
  }
  function contarFalha(rota, erro) {
    const chave = rota + ': ' + String((erro && erro.message) || erro || 'erro').slice(0, 80);
    estado.falhas[chave] = (estado.falhas[chave] || 0) + 1;
  }

  /* ---------- Sistema de tempo e de diagnóstico ---------- */
  function diaDeHoje(d) {
    const x = d || new Date();
    const p = (n) => String(n).padStart(2, '0');
    return x.getFullYear() + '-' + p(x.getMonth() + 1) + '-' + p(x.getDate());
  }
  // Frase do clima pronta para ser falada (números por extenso onde a voz tropeça).
  function tempoFalado(c) {
    if (!c || !Number.isFinite(Number(c.temp))) return 'Não consegui consultar a temperatura agora';
    let s = Number(c.temp) + ' graus em ' + (c.cidade || 'sua cidade') + ', com ' + (c.ceu || 'tempo indefinido');
    const chuva = Number(c.chuvaProx);
    if (Number.isFinite(chuva) && chuva >= 40) s += ' e ' + chuva + '% de chance de chuva nas próximas horas';
    if (Number.isFinite(Number(c.max)) && Number.isFinite(Number(c.min))) s += '. Máxima de ' + c.max + ' e mínima de ' + c.min;
    return s;
  }
  // Resumo falado do diagnóstico: o que passou, o que está pendente e o que falhou.
  function resumoDiagnostico(itens, opcoes) {
    const o = opcoes || {};
    const t = o.tratamento || 'senhor';
    const lista = Array.isArray(itens) ? itens.filter((i) => i && i.nome) : [];
    if (!lista.length) return 'Não recebi os resultados das verificações, ' + t + '. Tente novamente.';
    const falhas = lista.filter((i) => i.estado === 'fail');
    const avisos = lista.filter((i) => i.estado === 'warn');
    const total = porExtenso(lista.length);
    if (!falhas.length && !avisos.length) {
      return 'Verificação concluída, ' + t + ': foram ' + total + ' checagens e todas passaram — reconhecimento de voz, síntese, IA local, rede e permissões respondendo.';
    }
    const partes = [];
    if (falhas.length) partes.push(porExtenso(falhas.length) + ' com falha: ' + listar(falhas.map((i) => i.nome)));
    if (avisos.length) partes.push(porExtenso(avisos.length) + ' em atenção: ' + listar(avisos.map((i) => i.nome)));
    const primeiro = (falhas[0] || avisos[0] || {});
    const detalhe = primeiro.detalhe ? ' ' + String(primeiro.detalhe).slice(0, 180) : '';
    return 'Verificação concluída, ' + t + ': ' + total + ' checagens, ' + listar(partes) + '.' + detalhe;
  }

  /* ---------- Habilidades próprias do núcleo ----------
   * Cada habilidade decide sozinha quando é o caso de agir (quando) e o que fazer
   * (executar). Nenhuma delas chama a IA: são respostas imediatas, locais e com o
   * mesmo tom do resto do aplicativo.
   */
  const RX_SAUDACAO = /^(?:bom dia|boa tarde|boa noite|boa madrugada|oi|ola|opa|e ai|eae|salve)(?: (?:jarvis|nova))?(?: (?:tudo bem|tudo bom|beleza|como vai|como esta))?$/;
  // "diagnóstico do segundo plano" e "diagnóstico da escuta" continuam sendo o comando
  // nativo já existente: aqui só entra o diagnóstico geral do sistema.
  const RX_DIAG_ESPECIFICO = /\b(segundo plano|escuta|ativacao por voz|microfone)\b/;
  const RX_DIAGNOSTICO = /^(?:(?:jarvis|por favor|pf) )?(?:(?:faca|faz|executa|execute|executar|roda|rodar|inicia|iniciar|pode (?:fazer|rodar|executar)) (?:um |o )?)?(?:autodiagnostico|diagnostico(?: completo| geral| do sistema)?|checagem(?: geral)?|verificacao(?: geral)?|teste dos sistemas|verificar o sistema|verifique o sistema|checar o sistema|checa o sistema|como (?:esta|estao) os sistemas|status dos sistemas|tudo funcionando)$/;
  const RX_NUCLEO = /^(?:status|estado) (?:do )?(?:nucleo|hermes|agente|jarvis)$|^como (?:esta|ta|vai) (?:o )?(?:nucleo|hermes)$|^qual (?:e )?(?:o )?(?:motor|nucleo) (?:de )?(?:voce|do jarvis)$|^relatorio do nucleo$/;

  const habilidades = [
    {
      id: 'saudacao',
      nome: 'Saudação e briefing diário',
      ajuda: 'Cumprimenta com a temperatura atual e as notícias mais recentes na primeira conversa do dia.',
      quando: (n) => RX_SAUDACAO.test(n),
      async executar(texto, H) {
        const cap = H.cap;
        const t = cap.trat ? cap.trat() : 'senhor';
        const hoje = diaDeHoje(cap.agora ? cap.agora() : new Date());
        const ligado = cap.ler('briefing_auto', '1') === '1';
        const primeiro = ligado && cap.ler('briefing_dia', '') !== hoje;
        const abertura = periodo(cap.agora ? cap.agora() : new Date()) + ', ' + t + '.';
        if (!primeiro) {
          const curto = cap.frase ? cap.frase('saudacaoCurta') : 'Em que posso ajudar?';
          await cap.falar(abertura + ' ' + curto);
          return { briefing: false, falado: abertura + ' ' + curto };
        }
        // Primeira conversa do dia: temperatura e manchetes em paralelo (o app já deixou
        // o clima em cache na abertura, então normalmente chega na hora).
        cap.gravar('briefing_dia', hoje);
        if (cap.offline && cap.offline()) {
          const fala = abertura + ' O modo offline está ativo, então não vou buscar previsão do tempo nem notícias de agora.';
          await cap.falar(fala);
          if (cap.registrar) cap.registrar('hermes', 'briefing diário em modo offline');
          return { briefing: true, offline: true, falado: fala };
        }
        const pedidos = [];
        if (typeof cap.clima === 'function') pedidos.push(cap.clima(0));
        if (typeof cap.noticias === 'function') pedidos.push(cap.noticias());
        const resultados = await Promise.allSettled(pedidos);
        const climaR = cap.clima ? resultados[0] : null;
        const noticiasR = cap.noticias ? resultados[cap.clima ? 1 : 0] : null;
        const clima = climaR && climaR.status === 'fulfilled' ? climaR.value : null;
        const noticias = noticiasR && noticiasR.status === 'fulfilled' ? noticiasR.value : null;
        if (climaR && climaR.status === 'rejected' && cap.registrar) cap.registrar('erro', 'briefing: clima indisponível');
        if (noticiasR && noticiasR.status === 'rejected' && cap.registrar) cap.registrar('erro', 'briefing: notícias indisponíveis');
        let fala = abertura + ' ' + tempoFalado(clima) + '.';
        const manchetes = noticias && noticias.fala ? primeirasFrases(noticias.fala, 2) : '';
        if (manchetes) fala += ' Nas notícias de agora: ' + manchetes;
        else fala += ' Não consegui confirmar as notícias de agora; confira a conexão se quiser o resumo completo.';
        const fecho = cap.frase ? cap.frase('briefingFecho') : '';
        if (fecho) fala += ' ' + fecho;
        const links = (noticias && Array.isArray(noticias.links)) ? noticias.links : undefined;
        await cap.falar(fala, false, undefined, links);
        if (cap.registrar) cap.registrar('hermes', 'briefing diário entregue');
        return { briefing: true, falado: fala, links: links || [] };
      }
    },
    {
      id: 'diagnostico',
      nome: 'Autodiagnóstico do sistema',
      ajuda: 'Confere reconhecimento de voz, síntese, IA local, rede e permissões e reporta o resultado.',
      quando: (n) => RX_DIAGNOSTICO.test(n) && !RX_DIAG_ESPECIFICO.test(n),
      async executar(texto, H) {
        const cap = H.cap;
        const t = cap.trat ? cap.trat() : 'senhor';
        if (typeof cap.diagnosticoSistema !== 'function') throw new Error('O diagnóstico do sistema não está disponível nesta plataforma.');
        const r = await cap.diagnosticoSistema();
        const itens = (r && r.itens) || [];
        const resumo = resumoDiagnostico(itens, { tratamento: t });
        await cap.falar(resumo);
        if (cap.registrar) cap.registrar('hermes', 'autodiagnóstico: ' + itens.length + ' checagens');
        return { itens, resumo, falado: resumo };
      }
    },
    {
      id: 'nucleo',
      nome: 'Status do núcleo',
      ajuda: 'Diz qual motor está decidindo as respostas e como os turnos foram resolvidos.',
      quando: (n) => RX_NUCLEO.test(n),
      async executar(texto, H) {
        const cap = H.cap;
        const t = cap.trat ? cap.trat() : 'senhor';
        const rel = H.relatorio();
        const humor = cap.frase ? cap.frase('nucleoFecho') : '';
        const fala = rel + (humor ? ' ' + humor : '');
        await cap.falar(fala);
        return { falado: fala, fala, relatorio: rel, tratamento: t };
      }
    }
  ];

  /* ---------- Validar a decisão que veio da IA ----------
   * O modelo responde em JSON com "fala" e "acao". Aqui a resposta é conferida antes de
   * qualquer coisa acontecer: ação inventada, indisponível nesta plataforma ou argumento
   * com formato errado são descartados, e a fala nunca sai vazia. Isso evita anunciar
   * ("abrindo tal app...") algo que não será executado.
   */
  function validarDecisao(obj, ctx) {
    const c = ctx || {};
    const acoes = c.acoes || {};
    const disponiveisLista = Array.isArray(c.disponiveis) ? c.disponiveis : [];
    let fala = obj && typeof obj.fala === 'string' ? obj.fala.trim() : '';
    let acao = null;
    let aviso = '';
    const nome = obj && obj.acao && typeof obj.acao.nome === 'string' ? obj.acao.nome : '';
    if (nome) {
      const conhecida = Object.prototype.hasOwnProperty.call(acoes, nome);
      const disponivel = !disponiveisLista.length || disponiveisLista.indexOf(nome) >= 0;
      if (conhecida && disponivel) {
        const args = obj.acao.args && typeof obj.acao.args === 'object' && !Array.isArray(obj.acao.args) ? obj.acao.args : {};
        acao = { nome, args };
      } else {
        aviso = 'acao-invalida: ' + nome;
        if (!fala) fala = c.frase ? c.frase('acaoIndisponivel') : 'Essa ação não está disponível nesta plataforma.';
      }
    }
    if (!fala) {
      fala = c.textoBruto ? String(c.textoBruto).trim().slice(0, 600) : '';
      if (!fala) { fala = c.frase ? c.frase('respostaVazia') : 'Não consegui formular uma resposta agora. Pode repetir de outra forma?'; aviso = aviso || 'fala-vazia'; }
    }
    return { fala, acao, aviso };
  }

  /* ---------- O núcleo ---------- */
  const Hermes = {
    versao: VERSAO,
    nome: NOME,
    pelasRotas: ['hermes', 'local', 'ia'],
    cap: {},
    habilidades: habilidades,

    /**
     * Liga o núcleo às capacidades do aplicativo. Só o que for passado existe: cada
     * habilidade confere antes de usar, então um teste em Node roda com meia dúzia delas.
     */
    instalar(capacidades) {
      Object.assign(this.cap, capacidades || {});
      return this;
    },
    norm, semAcento, primeirasFrases, periodo, diaDeHoje, resumoDiagnostico, tempoFalado,

    // Tom do turno: pressa e assunto sensível. Sempre disponível, até sem app instalado.
    tom(texto) {
      const n = norm(texto);
      return { serio: RX_SENSIVEL.test(n), pressa: RX_PRESSA.test(n) };
    },

    /** Decide a rota sem executar nada. Devolve null quando o turno é para a IA. */
    planejar(texto) {
      const n = norm(texto);
      if (!n) return null;
      for (const h of this.habilidades) {
        try { if (h.quando(n, texto)) return { rota: 'hermes:' + h.id, habilidade: h }; }
        catch (e) { /* habilidade quebrada não pode derrubar o turno */ }
      }
      return null;
    },

    /**
     * Rota do turno: habilidade própria → comando no aparelho → IA.
     * Devolve { rota, tratado }: quando tratado é false, quem responde é a IA (chamar()).
     */
    async despachar(texto, opcoes) {
      const o = opcoes || {};
      const t0 = Date.now();
      const plano = this.planejar(texto);
      if (plano && !o.semHabilidades) {
        try {
          const resultado = await plano.habilidade.executar(texto, this);
          const ms = Date.now() - t0;
          contar(plano.rota, ms);
          return { rota: plano.rota, tratado: true, habilidade: plano.habilidade.id, resultado, ms };
        } catch (e) {
          contarFalha(plano.rota, e);
          if (this.cap.registrar) this.cap.registrar('erro', 'habilidade ' + plano.habilidade.id + ': ' + ((e && e.message) || e));
          // Cai para o próximo degrau: o usuário não pode ficar sem resposta por causa disso.
        }
      }
      if (typeof this.cap.comandoLocal === 'function') {
        try {
          if (await this.cap.comandoLocal(texto)) {
            const ms = Date.now() - t0;
            contar('local', ms);
            return { rota: 'local', tratado: true, ms };
          }
        } catch (e) {
          contarFalha('local', e);
          if (this.cap.registrar) this.cap.registrar('erro', 'comando local: ' + ((e && e.message) || e));
        }
      }
      const ms = Date.now() - t0;
      contar('ia', ms);
      return { rota: 'ia', tratado: false, ms };
    },

    validarDecisao,

    metricas() {
      const rotas = Object.assign({}, estado.rotas);
      const local = (rotas['local'] || 0);
      const proprias = Object.keys(rotas).filter((k) => k.indexOf('hermes:') === 0).reduce((s, k) => s + rotas[k], 0);
      const ia = rotas['ia'] || 0;
      return {
        versao: VERSAO, turnos: estado.turnos, rotas,
        proprias, local, ia,
        noAparelho: proprias + local,
        mediaMs: estado.turnos ? Math.round(estado.somaMs / estado.turnos) : 0,
        ultimaRota: estado.ultimaRota, ultimoTexto: estado.ultimoTexto,
        falhas: Object.assign({}, estado.falhas),
        rodando: Math.round((Date.now() - estado.desde) / 1000)
      };
    },
    zerarMetricas() { estado.turnos = 0; estado.rotas = {}; estado.falhas = {}; estado.somaMs = 0; estado.ultimaRota = ''; estado.desde = Date.now(); },
    anotarTexto(texto) { estado.ultimoTexto = String(texto || '').slice(0, 120); },

    /** Linha falada sobre o próprio núcleo — usada nos Ajustes e no status por voz. */
    relatorio() {
      const m = this.metricas();
      if (!m.turnos) return 'Núcleo ' + NOME + ' ' + VERSAO + ' pronto: ainda não resolvi nenhum pedido nesta sessão.';
      const pct = Math.round((m.noAparelho / m.turnos) * 100);
      const detalhe = m.mediaMs ? ' Resposta média em ' + (m.mediaMs / 1000).toFixed(1).replace('.', ',') + ' segundos.' : '';
      const ult = m.ultimaRota ? ' A última rota foi ' + m.ultimaRota + '.' : '';
      return 'Núcleo ' + NOME + ' ' + VERSAO + ': ' + m.turnos + ' turnos nesta sessão, ' + pct + '% resolvidos no próprio aparelho (' + m.proprias + ' pelas minhas habilidades e ' + m.local + ' por comando local).' + detalhe + ult;
    }
  };

  return Hermes;
});
