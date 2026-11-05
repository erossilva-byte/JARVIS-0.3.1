/* J.A.R.V.I.S. Nova — Jogos (1.43.0)
 * Oito jogos de texto com estado explícito e RNG injetável: a mesma interface serve ao chat,
 * ao painel e aos testes. Nenhum jogo aposta dinheiro real ou sai do aparelho.
 */
(function (raiz) {
  'use strict';
  const J = {};

  function rngPadrao() { return Math.random(); }
  function sorteio(rng, max) { return Math.floor(rng() * max); }
  function embaralhar(lista, rng) {
    const a = [...lista];
    for (let i = a.length - 1; i > 0; i--) { const j = sorteio(rng, i + 1); const t = a[i]; a[i] = a[j]; a[j] = t; }
    return a;
  }
  const normal = (t) => String(t || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();

  /* ---------- Blackjack ---------- */
  const NAIPES = ['♠', '♥', '♦', '♣'];
  const CARTAS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  function valorCarta(c) { return c === 'A' ? 11 : ['J', 'Q', 'K'].includes(c) ? 10 : Number(c); }
  function pontos(mao) {
    let total = mao.reduce((s, c) => s + valorCarta(c), 0);
    let ases = mao.filter((c) => c === 'A').length;
    while (total > 21 && ases > 0) { total -= 10; ases--; }
    return total;
  }
  function criarBlackjack(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const baralho = embaralhar(NAIPES.flatMap((n) => CARTAS.map((c) => ({ c, n }))), rng);
    const puxar = () => baralho.pop();
    const jogador = [puxar().c, puxar().c];
    const banca = [puxar().c, puxar().c];
    const jogo = { tipo: 'blackjack', jogador, banca, estado: 'jogando', mensagem: 'Sua vez: pedir ou parar.' };
    function fim(msg) { jogo.estado = 'fim'; jogo.mensagem = msg; return retrato(); }
    function retrato() {
      return {
        tipo: 'blackjack', jogador: [...jogador], banca: jogo.estado === 'jogando' ? [banca[0], '?'] : [...banca],
        pontosJogador: pontos(jogador), pontosBanca: jogo.estado === 'jogando' ? null : pontos(banca),
        estado: jogo.estado, resultado: jogo.resultado || null, mensagem: jogo.mensagem,
      };
    }
    jogo.acao = (a) => {
      if (jogo.estado === 'fim') return retrato();
      const acao = normal(a);
      if (acao === 'pedir' || acao === 'carta' || acao === 'hit') {
        jogador.push(puxar().c);
        if (pontos(jogador) > 21) { jogo.resultado = 'derrota'; return fim('Estourou com ' + pontos(jogador) + '. A banca leva.'); }
        if (pontos(jogador) === 21) { jogo.estado = 'fim'; jogo.resultado = 'vitoria'; return fim('21! Vitória.'); }
        jogo.mensagem = 'Você tem ' + pontos(jogador) + '. Pedir ou parar?';
        return retrato();
      }
      if (acao === 'parar' || acao === 'stand' || acao === 'ficar') {
        while (pontos(banca) < 17) banca.push(puxar().c);
        const p = pontos(jogador), b = pontos(banca);
        if (b > 21 || p > b) { jogo.resultado = 'vitoria'; return fim('Banca fez ' + b + '. Você venceu com ' + p + '.'); }
        if (p === b) { jogo.resultado = 'empate'; return fim('Empate em ' + p + '.'); }
        jogo.resultado = 'derrota'; return fim('Banca fez ' + b + ' e você ' + p + '.');
      }
      jogo.mensagem = 'Ação inválida. Use pedir ou parar.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Jogo da velha ---------- */
  function criarVelha(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const tab = new Array(9).fill(null);
    const jogo = { tipo: 'velha', tabuleiro: tab, estado: 'jogando' };
    const linhas = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    function vencedor(t) {
      for (const [a, b, c] of linhas) if (t[a] && t[a] === t[b] && t[a] === t[c]) return t[a];
      return t.every(Boolean) ? 'velha' : null;
    }
    function ia() {
      const livres = tab.map((v, i) => v === null ? i : -1).filter((i) => i >= 0);
      const tentar = (marca) => {
        for (const i of livres) { const copia = [...tab]; copia[i] = marca; if (vencedor(copia) === marca) return i; }
        return -1;
      };
      let i = tentar('O'); if (i < 0) i = tentar('X');
      if (i < 0 && tab[4] === null) i = 4;
      if (i < 0) { const cantos = [0, 2, 6, 8].filter((k) => tab[k] === null); if (cantos.length) i = cantos[sorteio(rng, cantos.length)]; }
      if (i < 0) i = livres[sorteio(rng, livres.length)];
      return i;
    }
    function retrato() {
      return { tipo: 'velha', tabuleiro: [...tab], estado: jogo.estado, vencedor: jogo.vencedor || null, mensagem: jogo.mensagem || '' };
    }
    jogo.jogar = (casa) => {
      if (jogo.estado !== 'jogando') return retrato();
      const i = Number(casa);
      if (!Number.isInteger(i) || i < 1 || i > 9 || tab[i - 1]) { jogo.mensagem = 'Casa inválida ou ocupada. Escolha de 1 a 9.'; return retrato(); }
      tab[i - 1] = 'X';
      let v = vencedor(tab);
      if (!v) { tab[ia()] = 'O'; v = vencedor(tab); }
      if (v) { jogo.estado = 'fim'; jogo.vencedor = v; jogo.mensagem = v === 'velha' ? 'Deu velha.' : v === 'X' ? 'Você venceu.' : 'A máquina venceu.'; }
      else jogo.mensagem = 'Sua vez.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Ligue 4 ---------- */
  function criarLigue4(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const colunas = 7, linhas = 6;
    const grade = Array.from({ length: linhas }, () => new Array(colunas).fill(null));
    const jogo = { tipo: 'ligue4', colunas, linhas, estado: 'jogando' };
    function soltar(col, marca) {
      for (let l = linhas - 1; l >= 0; l--) if (!grade[l][col]) { grade[l][col] = marca; return l; }
      return -1;
    }
    function vence(marca) {
      const dirs = [[0,1],[1,0],[1,1],[1,-1]];
      for (let l = 0; l < linhas; l++) for (let c = 0; c < colunas; c++) {
        if (grade[l][c] !== marca) continue;
        for (const [dl, dc] of dirs) {
          let k = 1;
          while (k < 4) {
            const nl = l + dl * k, nc = c + dc * k;
            if (nl < 0 || nl >= linhas || nc < 0 || nc >= colunas || grade[nl][nc] !== marca) break;
            k++;
          }
          if (k === 4) return true;
        }
      }
      return false;
    }
    function retrato() {
      return { tipo: 'ligue4', grade: grade.map((l) => [...l]), estado: jogo.estado, vencedor: jogo.vencedor || null, mensagem: jogo.mensagem || '' };
    }
    jogo.jogar = (coluna) => {
      if (jogo.estado !== 'jogando') return retrato();
      const c = Number(coluna) - 1;
      if (!Number.isInteger(c) || c < 0 || c >= colunas || grade[0][c]) { jogo.mensagem = 'Coluna inválida ou cheia (1 a 7).'; return retrato(); }
      soltar(c, 'X');
      if (vence('X')) { jogo.estado = 'fim'; jogo.vencedor = 'X'; jogo.mensagem = 'Você venceu.'; return retrato(); }
      const livres = [0,1,2,3,4,5,6].filter((k) => !grade[0][k]);
      if (!livres.length) { jogo.estado = 'fim'; jogo.vencedor = 'velha'; jogo.mensagem = 'Empate.'; return retrato(); }
      const escolha = livres[sorteio(rng, livres.length)];
      soltar(escolha, 'O');
      if (vence('O')) { jogo.estado = 'fim'; jogo.vencedor = 'O'; jogo.mensagem = 'A máquina venceu.'; return retrato(); }
      jogo.mensagem = 'Sua vez.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Forca ---------- */
  const PALAVRAS_FORCA = ['jarvis', 'reator', 'planeta', 'circuito', 'energia', 'estrela', 'memoria', 'sistema'];
  function criarForca(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const palavra = ((opts && opts.palavra) || PALAVRAS_FORCA[sorteio(rng, PALAVRAS_FORCA.length)]).toLowerCase();
    const jogo = { tipo: 'forca', palavra, tentativas: [], erros: 0, maxErros: 6, estado: 'jogando' };
    function retrato() {
      const exibida = [...palavra].map((c) => jogo.tentativas.includes(c) ? c : '_').join(' ');
      return { tipo: 'forca', exibida, tentativas: [...jogo.tentativas], erros: jogo.erros, maxErros: 6, estado: jogo.estado, mensagem: jogo.mensagem || '', palavra: jogo.estado === 'fim' ? palavra : undefined };
    }
    jogo.jogar = (letra) => {
      if (jogo.estado !== 'jogando') return retrato();
      const c = normal(letra).replace(/[^a-z]/g, '').slice(0, 1);
      if (!c) { jogo.mensagem = 'Diga uma letra.'; return retrato(); }
      if (jogo.tentativas.includes(c)) { jogo.mensagem = 'Você já tentou essa letra.'; return retrato(); }
      jogo.tentativas.push(c);
      if (!palavra.includes(c)) jogo.erros++;
      if (palavra.split('').every((l) => jogo.tentativas.includes(l))) { jogo.estado = 'fim'; jogo.mensagem = 'Acertou: ' + palavra + '.'; }
      else if (jogo.erros >= 6) { jogo.estado = 'fim'; jogo.mensagem = 'Enforcou. A palavra era ' + palavra + '.'; }
      else jogo.mensagem = palavra.includes(c) ? 'Boa: tem ' + c + '.' : 'Não tem ' + c + '.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Pedra, papel e tesoura ---------- */
  function criarPPT(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const opcoes = ['pedra', 'papel', 'tesoura'];
    const jogo = { tipo: 'ppt', pontos: { voce: 0, maquina: 0 }, rodadas: 0, estado: 'jogando' };
    function retrato() {
      return { tipo: 'ppt', pontos: { ...jogo.pontos }, rodadas: jogo.rodadas, estado: jogo.estado, ultima: jogo.ultima || null, mensagem: jogo.mensagem || '' };
    }
    jogo.jogar = (escolha) => {
      if (jogo.estado !== 'jogando') return retrato();
      const e = normal(escolha);
      if (!opcoes.includes(e)) { jogo.mensagem = 'Escolha pedra, papel ou tesoura.'; return retrato(); }
      const m = opcoes[sorteio(rng, 3)];
      const ganha = { pedra: 'tesoura', papel: 'pedra', tesoura: 'papel' };
      let r = 'empate';
      if (ganha[e] === m) { jogo.pontos.voce++; r = 'voce'; }
      else if (ganha[m] === e) { jogo.pontos.maquina++; r = 'maquina'; }
      jogo.rodadas++;
      jogo.ultima = { voce: e, maquina: m, resultado: r };
      if (jogo.pontos.voce === 3 || jogo.pontos.maquina === 3) {
        jogo.estado = 'fim';
        jogo.mensagem = jogo.pontos.voce === 3 ? 'Você venceu a melhor de cinco.' : 'A máquina levou a melhor de cinco.';
      } else jogo.mensagem = r === 'voce' ? 'Você ganhou a rodada (' + e + ' vence ' + m + ').' : r === 'maquina' ? 'Máquina ganhou (' + m + ' vence ' + e + ').' : 'Empate: os dois escolheram ' + e + '.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Adivinha o número ---------- */
  function criarAdivinha(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const alvo = 1 + sorteio(rng, 100);
    const jogo = { tipo: 'adivinha', alvo, chutes: [], max: 7, estado: 'jogando' };
    function retrato() {
      return { tipo: 'adivinha', chutes: [...jogo.chutes], restantes: jogo.max - jogo.chutes.length, estado: jogo.estado, mensagem: jogo.mensagem || '', alvo: jogo.estado === 'fim' ? alvo : undefined };
    }
    jogo.jogar = (n) => {
      if (jogo.estado !== 'jogando') return retrato();
      const v = Number(n);
      if (!Number.isInteger(v) || v < 1 || v > 100) { jogo.mensagem = 'Chute um número inteiro de 1 a 100.'; return retrato(); }
      jogo.chutes.push(v);
      if (v === alvo) { jogo.estado = 'fim'; jogo.mensagem = 'Acertou em ' + jogo.chutes.length + ' tentativa(s)! Era ' + alvo + '.'; }
      else if (jogo.chutes.length >= jogo.max) { jogo.estado = 'fim'; jogo.mensagem = 'Acabaram as tentativas. Era ' + alvo + '.'; }
      else jogo.mensagem = v < alvo ? 'É maior que ' + v + '.' : 'É menor que ' + v + '.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Termo (Wordle) ---------- */
  const PALAVRAS_TERMO = ['pedra', 'livro', 'noite', 'praia', 'verde', 'sonho', 'campo', 'vento', 'festa', 'tempo'];
  function criarTermo(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const palavra = ((opts && opts.palavra) || PALAVRAS_TERMO[sorteio(rng, PALAVRAS_TERMO.length)]).toLowerCase();
    const jogo = { tipo: 'termo', tentativas: [], max: 6, estado: 'jogando' };
    function avaliar(chute) {
      const restante = palavra.split('');
      const marcas = new Array(5).fill('ausente');
      for (let i = 0; i < 5; i++) if (chute[i] === palavra[i]) { marcas[i] = 'certa'; restante[i] = null; }
      for (let i = 0; i < 5; i++) {
        if (marcas[i] === 'certa') continue;
        const k = restante.indexOf(chute[i]);
        if (k >= 0) { marcas[i] = 'presente'; restante[k] = null; }
      }
      return marcas;
    }
    function retrato() {
      return { tipo: 'termo', tentativas: jogo.tentativas.map((t) => ({ palavra: t.palavra, marcas: [...t.marcas] })), restantes: jogo.max - jogo.tentativas.length, estado: jogo.estado, mensagem: jogo.mensagem || '', palavra: jogo.estado === 'fim' ? palavra : undefined };
    }
    jogo.jogar = (chute) => {
      if (jogo.estado !== 'jogando') return retrato();
      const c = normal(chute).replace(/[^a-z]/g, '');
      if (c.length !== 5) { jogo.mensagem = 'A palavra precisa ter 5 letras.'; return retrato(); }
      const marcas = avaliar(c);
      jogo.tentativas.push({ palavra: c, marcas });
      if (c === palavra) { jogo.estado = 'fim'; jogo.mensagem = 'Acertou!'; }
      else if (jogo.tentativas.length >= jogo.max) { jogo.estado = 'fim'; jogo.mensagem = 'Acabou. A palavra era ' + palavra + '.'; }
      else jogo.mensagem = 'Tente outra palavra.';
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  /* ---------- Roleta ---------- */
  const VERMELHOS = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
  function criarRoleta(opts) {
    const rng = (opts && opts.rng) || rngPadrao;
    const jogo = { tipo: 'roleta', saldo: (opts && Number.isFinite(opts.saldo)) ? opts.saldo : 100, historico: [] };
    function retrato() {
      return { tipo: 'roleta', saldo: jogo.saldo, historico: [...jogo.historico], mensagem: jogo.mensagem || '' };
    }
    jogo.jogar = (aposta) => {
      const a = aposta || {};
      const valor = Number(a.valor);
      if (!Number.isFinite(valor) || valor <= 0 || valor > jogo.saldo) { jogo.mensagem = 'Aposta inválida para o saldo de ' + jogo.saldo + ' fichas.'; return retrato(); }
      const tipo = normal(a.tipo);
      if (!['vermelho', 'preto', 'par', 'impar', 'numero'].includes(tipo)) { jogo.mensagem = 'Aposte em vermelho, preto, par, ímpar ou número.'; return retrato(); }
      if (tipo === 'numero' && (!Number.isInteger(Number(a.numero)) || Number(a.numero) < 0 || Number(a.numero) > 36)) { jogo.mensagem = 'Número precisa estar entre 0 e 36.'; return retrato(); }
      const n = sorteio(rng, 37);
      let ganhou = false, multiplicador = 0;
      if (tipo === 'numero') { ganhou = Number(a.numero) === n; multiplicador = 36; }
      else if (tipo === 'vermelho') { ganhou = VERMELHOS.includes(n); multiplicador = 2; }
      else if (tipo === 'preto') { ganhou = n !== 0 && !VERMELHOS.includes(n); multiplicador = 2; }
      else if (tipo === 'par') { ganhou = n !== 0 && n % 2 === 0; multiplicador = 2; }
      else { ganhou = n % 2 === 1; multiplicador = 2; }
      jogo.saldo += ganhou ? valor * (multiplicador - 1) : -valor;
      jogo.historico.unshift({ numero: n, aposta: tipo, valor, ganhou });
      jogo.historico = jogo.historico.slice(0, 10);
      jogo.mensagem = 'Deu ' + n + ' (' + (n === 0 ? 'verde' : VERMELHOS.includes(n) ? 'vermelho' : 'preto') + '). ' +
        (ganhou ? 'Você ganhou ' + (valor * (multiplicador - 1)) + ' fichas.' : 'Você perdeu ' + valor + ' fichas.');
      return retrato();
    };
    jogo.estadoAtual = retrato;
    return jogo;
  }

  const TIPOS = {
    blackjack: criarBlackjack, velha: criarVelha, ligue4: criarLigue4, forca: criarForca,
    ppt: criarPPT, adivinha: criarAdivinha, termo: criarTermo, roleta: criarRoleta,
  };
  J.tipos = () => Object.keys(TIPOS);
  J.criar = (tipo, opts) => {
    const t = normal(tipo).replace(/\s+/g, '');
    const chave = TIPOS[t] ? t : t === 'jogodavelha' ? 'velha' : t === 'liguequatro' ? 'ligue4'
      : t === 'pedrapapeltesoura' ? 'ppt' : t === 'wordle' ? 'termo' : t === 'forca' ? 'forca' : null;
    if (!chave) return null;
    return TIPOS[chave](opts || {});
  };
  J.ajuda = () => [
    'blackjack: pedir ou parar',
    'velha: casa de 1 a 9',
    'ligue4: coluna de 1 a 7',
    'forca: uma letra',
    'ppt: pedra, papel ou tesoura',
    'adivinha: número de 1 a 100',
    'termo: palavra de 5 letras',
    'roleta: vermelho, preto, par, ímpar ou número',
  ];

  raiz.JogosJarvis = J;
  if (typeof module !== 'undefined' && module.exports) module.exports = J;
})(typeof window !== 'undefined' ? window : globalThis);
