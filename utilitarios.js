/* J.A.R.V.I.S. Nova — Utilitários: IMC, conversões, piadas, curiosidades, QR Code e jogos.
 *
 * Módulo puro (sem DOM obrigatório, sem rede, sem dependência nova), no mesmo estilo dos
 * outros módulos: a lógica roda em Node para os testes e no WebView do Android dentro do app.
 *
 * Como ele entra no aplicativo sem mexer no app.js:
 *   o app resolve comandos locais por Hermes.cap.comandoLocal (o `comandoRapido` do app.js).
 *   Este arquivo troca essa capacidade por uma versão que primeiro chama o resolvedor
 *   original e só depois tenta os comandos daqui. Nada do que já funcionava muda de
 *   comportamento; o que era "não entendi" passa a ter resposta local.
 *
 * O carregamento é tolerante: se o app ainda não instalou as capacidades do Hermes (script
 * antes do app.js), a instalação é adiada para DOMContentLoaded e para duas redes de
 * segurança. Se já instalou (script depois do app.js), instala na hora.
 *
 * O que é real:
 * - IMC com a classificação da OMS para adultos;
 * - conversões de temperatura, comprimento, massa, volume, velocidade, tempo e dados;
 * - QR Code gerado de verdade: codificação byte, correção de erro nível L, versões 1 a 10,
 *   Reed-Solomon em GF(256), padrões de localização, temporização, alinhamento e formato.
 *   O resultado é conferido no teste por um decodificador independente;
 * - jogos com estado próprio (jogo da velha e adivinhação) e sorteios sem estado.
 *
 * O que NÃO é real: conversão de moedas. Câmbio exige serviço externo e cotação do dia;
 * inventar um número seria pior do que dizer que não faz.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisUtilitarios = api;

  /* Instalação no aplicativo. Só vale quando o app já publicou as capacidades do Hermes:
   * trocar o resolvedor antes disso faria o app.js sobrescrever tudo com o original. */
  function instalarNoApp() {
    try { api.instalar(raiz && raiz.Hermes); } catch (e) { /* o app segue sem os utilitários */ }
  }
  if (raiz) {
    const hermes = raiz.Hermes;
    const pronto = hermes && hermes.cap && typeof hermes.cap.comandoLocal === 'function';
    if (pronto) {
      instalarNoApp();
    } else if (raiz.document && typeof raiz.document.addEventListener === 'function') {
      raiz.document.addEventListener('DOMContentLoaded', instalarNoApp, { once: true });
    }
    if (typeof raiz.setTimeout === 'function') {
      raiz.setTimeout(instalarNoApp, 1500);
      raiz.setTimeout(instalarNoApp, 5000);
    }
  }
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const VERSAO = '1.0.0';
  const NOME = 'Utilitários';

  /* ------------------------------------------------------------------ texto */
  const semAcento = (t) => String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const norm = (t) => semAcento(t).toLowerCase().replace(/\s+/g, ' ').trim();
  const numero = (s) => Number(String(s).replace(/\s/g, '').replace(',', '.'));
  const RAIZ_JARVIS = /^(?:jarvis|jarves|jervis|gervis|garvis|charvis|jarbis|jarvez|jarvs|jarvi)\b\s*/;
  const limpar = (t) => norm(t).replace(RAIZ_JARVIS, '').replace(/[!?]+$/g, '').trim();
  // Números em português, com vírgula ou ponto.
  const RX_NUM = /\d+(?:[.,]\d+)?/g;

  function formatar(v, casas) {
    const n = Number(v);
    if (!Number.isFinite(n)) return '—';
    const c = casas == null ? 2 : casas;
    let s = n.toFixed(c);
    if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '');
    return s.replace('.', ',');
  }

  /* ------------------------------------------------------------------ IMC */
  // Classificação da OMS para adultos. Abaixo de 18 anos o IMC não se interpreta assim;
  // por isso a resposta avisa em vez de afirmar.
  function imc(pesoKg, alturaM) {
    const p = Number(pesoKg), a = Number(alturaM);
    if (!(p > 0) || !(a > 0)) return null;
    const valor = p / (a * a);
    let classe;
    if (valor < 18.5) classe = 'abaixo do peso';
    else if (valor < 25) classe = 'peso normal';
    else if (valor < 30) classe = 'sobrepeso';
    else if (valor < 35) classe = 'obesidade grau 1';
    else if (valor < 40) classe = 'obesidade grau 2';
    else classe = 'obesidade grau 3';
    return { valor: valor, classe: classe, peso: p, altura: a };
  }

  // Aceita "80 kg e 1,80 m", "1,80 m 80 kg", "imc 180 cm 80" e afins.
  function extrairImc(texto) {
    const n = limpar(texto);
    const mPeso = /(\d+(?:[.,]\d+)?)\s*(kg|quilos?|quilo)\b/.exec(n);
    const mAlt = /(\d+(?:[.,]\d+)?)\s*(cm|centimetros?|centimetro|m|metros?|metro)\b/.exec(n);
    let peso = mPeso ? numero(mPeso[1]) : null;
    let altura = mAlt ? numero(mAlt[1]) : null;
    if (altura != null && /cm|centimetro/.test(mAlt[2])) altura = altura / 100;
    if (peso == null || altura == null) {
      const nums = (n.match(RX_NUM) || []).map(numero);
      if (peso == null && altura == null && nums.length >= 2) {
        if (nums[1] <= 2.5) { peso = nums[0]; altura = nums[1]; }
        else if (nums[0] <= 2.5) { altura = nums[0]; peso = nums[1]; }
        else { peso = nums[0]; altura = nums[1] > 30 ? nums[1] / 100 : nums[1]; }
      } else if (peso == null && nums.length) {
        const cand = nums.find((x) => x >= 20 && x <= 400);
        if (cand != null) peso = cand;
      } else if (altura == null && nums.length) {
        const cand = nums.find((x) => x > 0 && x <= 2.5);
        if (cand != null) altura = cand;
      }
    }
    if (!(peso > 0) || !(altura > 0)) return null;
    return { peso: peso, altura: altura };
  }

  /* ------------------------------------------------------------ conversões */
  // Cada unidade guarda quanto vale em relação à base do grupo.
  const GRUPOS = {
    comprimento: { base: 'm', unidades: { mm: 0.001, milimetro: 0.001, cm: 0.01, centimetro: 0.01, m: 1, metro: 1, km: 1000, quilometro: 1000, pol: 0.0254, polegada: 0.0254, pe: 0.3048, jarda: 0.9144, milha: 1609.344 } },
    massa: { base: 'g', unidades: { mg: 0.001, miligrama: 0.001, g: 1, grama: 1, kg: 1000, quilo: 1000, quilograma: 1000, t: 1000000, tonelada: 1000000, libra: 453.59237, lb: 453.59237, onca: 28.349523125, oz: 28.349523125 } },
    volume: { base: 'l', unidades: { ml: 0.001, mililitro: 0.001, l: 1, litro: 1, m3: 1000, galao: 3.785411784, xicara: 0.24 } },
    velocidade: { base: 'm/s', unidades: { 'm/s': 1, 'km/h': 1 / 3.6, kmh: 1 / 3.6, mph: 0.44704, 'milha por hora': 0.44704, no: 0.514444, nos: 0.514444 } },
    tempo: { base: 's', unidades: { s: 1, seg: 1, segundo: 1, min: 60, minuto: 60, h: 3600, hora: 3600, dia: 86400, semana: 604800 } },
    dados: { base: 'byte', unidades: { byte: 1, bytes: 1, b: 1, kb: 1024, mb: 1048576, gb: 1073741824, tb: 1099511627776 } }
  };
  const CANONICO = { c: 'c', celsius: 'c', centigrado: 'c', centigrados: 'c', f: 'f', fahrenheit: 'f', k: 'k', kelvin: 'k' };

  function canonizarGrupo(grupo, unidade) {
    const u = norm(unidade).replace(/\.$/, '').trim();
    if (Object.prototype.hasOwnProperty.call(grupo.unidades, u)) return u;
    // "quilometros por hora" e "km por hora" caem em km/h
    const semPor = u.replace(/\s*por\s*hora$/, '/h').replace(/\s+/g, '');
    if (Object.prototype.hasOwnProperty.call(grupo.unidades, semPor)) return semPor;
    const curto = u.slice(0, 5);
    for (const chave of Object.keys(grupo.unidades)) {
      if (chave === u || chave.slice(0, 5) === curto) return chave;
    }
    return null;
  }

  function temperatura(valor, de, para) {
    const v = Number(valor);
    const emC = de === 'c' ? v : de === 'f' ? (v - 32) * 5 / 9 : v - 273.15;
    return para === 'c' ? emC : para === 'f' ? emC * 9 / 5 + 32 : emC + 273.15;
  }

  // Devolve { valor, de, para, texto } ou null quando as unidades não combinam.
  function converter(valor, de, para) {
    const v = Number(valor);
    if (!Number.isFinite(v)) return null;
    const a = norm(de), b = norm(para);
    const ca = CANONICO[a], cb = CANONICO[b];
    if (ca && cb) {
      const r = temperatura(v, ca, cb);
      return { valor: r, de: ca, para: cb, texto: formatar(v, 2) + ' °' + ca.toUpperCase() + ' = ' + formatar(r, 2) + ' °' + cb.toUpperCase() };
    }
    for (const nome of Object.keys(GRUPOS)) {
      const grupo = GRUPOS[nome];
      const ua = canonizarGrupo(grupo, a), ub = canonizarGrupo(grupo, b);
      if (ua && ub) {
        const r = (v * grupo.unidades[ua]) / grupo.unidades[ub];
        return { valor: r, de: ua, para: ub, grupo: nome, texto: formatar(v, 3) + ' ' + ua + ' = ' + formatar(r, 3) + ' ' + ub };
      }
    }
    return null;
  }

  // Extrai "10 km para milhas", "5 kg em libras", "30 c para f".
  function extrairConversao(texto) {
    const n = limpar(texto);
    const m = /(-?\d+(?:[.,]\d+)?)\s*([a-z][a-z/ ]{0,20}?)\s*(?:para|pra|em|->|=>)\s*([a-z][a-z/ ]{0,20})/.exec(n);
    if (!m) return null;
    return { valor: numero(m[1]), de: m[2].trim(), para: m[3].trim() };
  }

  /* ------------------------------------------------------- bases numéricas */
  function baseNumerica(valor, de, para) {
    const v = String(valor).trim();
    let n;
    if (de === 'bin') { if (!/^[01]+$/.test(v)) return null; n = parseInt(v, 2); }
    else if (de === 'hex') { if (!/^[0-9a-f]+$/i.test(v)) return null; n = parseInt(v, 16); }
    else { if (!/^\d+$/.test(v)) return null; n = parseInt(v, 10); }
    if (!Number.isFinite(n)) return null;
    const s = para === 'bin' ? n.toString(2) : para === 'hex' ? n.toString(16).toUpperCase() : String(n);
    return { valor: n, texto: s };
  }

  function extrairBase(texto) {
    const n = limpar(texto);
    const m = /(?:^|[^\d])(\d+)\s*(?:de\s+)?(binario|binaria|bin|hexadecimal|hex|decimal)\s*(?:para|pra|em)\s*(binario|binaria|bin|hexadecimal|hex|decimal)/.exec(n);
    if (!m) return null;
    const mapa = { binario: 'bin', binaria: 'bin', bin: 'bin', hexadecimal: 'hex', hex: 'hex', decimal: 'dec' };
    return { valor: m[1], de: mapa[m[2]], para: mapa[m[3]] };
  }

  /* -------------------------------------------------------------- conteúdo */
  // Piadas originais, curtas e sem alvo: o alvo é sempre a situação.
  const PIADAS = [
    'Meu código não tem bugs, tem funcionalidades que aparecem sozinhas.',
    'Passei tanto tempo procurando o erro que o erro começou a procurar um advogado.',
    'O Wi-Fi caiu, mas pelo menos caiu com estilo.',
    'Meu café tem duas configurações: forte e memória ruim.',
    'Alarme desligado, consciência ligada: é a pior combinação para segunda-feira.',
    'A impressora não funciona, mas ela faz um barulho de quem está se esforçando.',
    'Pedi para o assistente ser breve. Agora ele só responde com silêncio.',
    'Meu plano de treino tem sete dias de descanso e um de dúvida.',
    'O celular tem 128 GB e eu tenho 12 gavetas com cabo de carregador.',
    'Segunda-feira é a segunda-feira da semana.',
    'Troquei o teclado porque uma tecla falhava. Descobri que era eu chegando atrasado.',
    'A bateria dura o dia inteiro, desde que o dia tenha quatro horas.',
    'Meu autocorretor mudou "reunião" para "rebuliço". Não estava errado.',
    'Comprei um livro de organização e pus na pilha dos livros de organização.',
    'A nuvem caiu, mas ninguém mora lá.',
    'Meu empenho em desligar o computador é superado pelo botão de atualizar.',
    'Eu não atraso: eu chego com contexto extra.',
    'O melhor lugar para esconder um cabo é na frente de todo mundo.',
    'Genética explicaria muita coisa, mas a culpa de hoje é da umidade.',
    'Meu diário de sono tem uma única anotação: segunda-feira.',
    'O relógio do micro-ondas é o equipamento mais preciso da casa e ninguém usa.',
    'Existe vida após a morte porque o grupo da família continua postando.',
    'Tenho a mente aberta, o que explica a corrente de ar.',
    'Meu plano B é respirar fundo e usar o plano A de novo.'
  ];

  const CURIOSIDADES = [
    'Um raio pode chegar a 30 mil kelvin, cinco vezes mais quente que a superfície do Sol.',
    'O coração de uma baleia-azul pode pesar mais que um carro pequeno.',
    'Um dia em Vênus é mais longo que um ano em Vênus.',
    'A luz do Sol leva cerca de 8 minutos e 20 segundos para chegar aqui.',
    'Formigas não têm pulmões: trocam gás pela superfície do corpo.',
    'O mel praticamente não estraga; há potes comestíveis com milhares de anos.',
    'Um raio atinge o planeta cerca de cem vezes por segundo.',
    'O oceano cobre mais de 70% da superfície da Terra.',
    'O som viaja cerca de quatro vezes mais rápido na água que no ar.',
    'Neutrinos atravessam a Terra inteira como se ela fosse feita de fumaça.',
    'A ponta de um dedo identifica uma impressão digital diferente da de qualquer outra pessoa.',
    'Os ossos humanos são mais fortes que o concreto quando comparados por peso.',
    'Um relâmpago e um trovão são o mesmo evento; a diferença é a velocidade.',
    'A borracha é feita da seiva de uma árvore, a seringueira.',
    'O ferro do seu sangue veio de estrelas que explodiram antes do Sol nascer.',
    'O Telescópio Hubble já fotografou galáxias a mais de 13 bilhões de anos-luz.',
    'Formigas carregam várias vezes o próprio peso, mas param quando você olha.',
    'A Via Láctea tem cerca de 100 a 400 bilhões de estrelas.',
    'Água expande ao congelar; quase todo o resto encolhe.',
    'Um segundo não é fixo: desde 1967 ele é definido pelo átomo de césio.',
    'O maior deserto do mundo é a Antártida, porque deserto é ausência de precipitação.',
    'O cérebro usa cerca de 20% da energia do corpo, apesar de ser 2% do peso.',
    'O borrão de luz no céu de noite pode ter três mil anos e você está vendo o passado.',
    'Nuvens pesam toneladas e continuam flutuando porque o ar sob elas é mais denso.'
  ];

  const sortear = (arr, rnd) => arr[Math.floor((rnd || Math.random)() * arr.length)];
  const piada = (rnd) => sortear(PIADAS, rnd);
  const curiosidade = (rnd) => sortear(CURIOSIDADES, rnd);

  /* --------------------------------------------------------------- jogos */
  const ESTADO = { jogo: null };

  function velhaNovo() {
    ESTADO.jogo = { tipo: 'velha', casas: new Array(9).fill(null), fim: false };
    return ESTADO.jogo;
  }
  const LINHAS = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
  function vencedor(casas) {
    for (const l of LINHAS) {
      if (casas[l[0]] && casas[l[0]] === casas[l[1]] && casas[l[1]] === casas[l[2]]) return casas[l[0]];
    }
    return casas.every(Boolean) ? 'empate' : null;
  }
  function velhaTexto(casas) {
    const c = (i) => casas[i] || String(i + 1);
    return [0, 3, 6].map((i) => [c(i), c(i + 1), c(i + 2)].join(' | ')).join('   ·   ');
  }
  // O Jarvis (O) tenta ganhar, depois bloquear; senão centro, canto, lado.
  function velhaEscolha(casas, rnd) {
    const livres = casas.map((v, i) => (v ? -1 : i)).filter((i) => i >= 0);
    if (!livres.length) return -1;
    for (const marca of ['O', 'X']) {
      for (const i of livres) {
        const copia = casas.slice();
        copia[i] = marca;
        if (vencedor(copia) === marca) return i;
      }
    }
    if (livres.includes(4)) return 4;
    const cantos = [0, 2, 6, 8].filter((i) => livres.includes(i));
    if (cantos.length) return sortear(cantos, rnd);
    return sortear(livres, rnd);
  }
  function velhaJogar(pos, rnd) {
    const j = ESTADO.jogo;
    if (!j || j.tipo !== 'velha') return { erro: 'Nenhum jogo da velha em andamento. Diga "jogo da velha" para começar.' };
    if (j.fim) return { erro: 'Essa partida terminou. Diga "jogo da velha" para começar outra.' };
    const i = Number(pos) - 1;
    if (!(i >= 0 && i < 9)) return { erro: 'Escolha uma casa de 1 a 9.' };
    if (j.casas[i]) return { erro: 'A casa ' + (i + 1) + ' já está ocupada.' };
    j.casas[i] = 'X';
    let v = vencedor(j.casas);
    if (!v) {
      const escolha = velhaEscolha(j.casas, rnd);
      if (escolha >= 0) j.casas[escolha] = 'O';
      v = vencedor(j.casas);
    }
    const fim = Boolean(v);
    j.fim = fim;
    return { casas: j.casas.slice(), tabuleiro: velhaTexto(j.casas), resultado: v, fim: fim };
  }

  function adivinharNovo(rnd) {
    const alvo = Math.floor((rnd || Math.random)() * 100) + 1;
    ESTADO.jogo = { tipo: 'adivinha', alvo: alvo, tentativas: 0, fim: false };
    return ESTADO.jogo;
  }
  function adivinharChute(n) {
    const j = ESTADO.jogo;
    if (!j || j.tipo !== 'adivinha') return { erro: 'Nenhum jogo de adivinhação em andamento. Diga "adivinhe um número".' };
    if (j.fim) return { erro: 'Essa rodada terminou. Diga "adivinhe um número" para jogar de novo.' };
    const v = Number(n);
    if (!(v >= 1 && v <= 100)) return { erro: 'Chute um número de 1 a 100.' };
    j.tentativas++;
    if (v === j.alvo) { j.fim = true; return { certo: true, tentativas: j.tentativas, texto: 'Acertou! Era ' + j.alvo + ' em ' + j.tentativas + ' tentativa(s).' }; }
    return { certo: false, dica: v < j.alvo ? 'maior' : 'menor', tentativas: j.tentativas, texto: 'Não. O número é ' + (v < j.alvo ? 'maior' : 'menor') + ' que ' + v + '. Tentativa ' + j.tentativas + '.' };
  }

  const PPT = ['pedra', 'papel', 'tesoura'];
  function ppt(escolhaUsuario, rnd) {
    const eu = norm(escolhaUsuario);
    const jogador = PPT.find((x) => eu.indexOf(x) >= 0);
    if (!jogador) return null;
    const jarvis = sortear(PPT, rnd);
    const vence = { pedra: 'tesoura', papel: 'pedra', tesoura: 'papel' };
    const resultado = jogador === jarvis ? 'empate' : vence[jogador] === jarvis ? 'você ganhou' : 'eu ganhei';
    return { jogador: jogador, jarvis: jarvis, resultado: resultado };
  }

  function dado(quantidade, rnd) {
    const q = Math.max(1, Math.min(6, Number(quantidade) || 1));
    const r = rnd || Math.random;
    const valores = [];
    for (let i = 0; i < q; i++) valores.push(Math.floor(r() * 6) + 1);
    return { valores: valores, total: valores.reduce((a, b) => a + b, 0) };
  }
  function moeda(rnd) { return (rnd || Math.random)() < 0.5 ? 'cara' : 'coroa'; }
  function sortearInteiro(a, b, rnd) {
    const min = Math.min(Number(a), Number(b)), max = Math.max(Number(a), Number(b));
    if (!Number.isFinite(min) || !Number.isFinite(max)) return null;
    return Math.floor((rnd || Math.random)() * (max - min + 1)) + min;
  }

  /* ------------------------------------------------------------ QR Code */
  // Implementação própria, sem CDN: o APK precisa gerar QR sem internet.
  const QR_TOTAL = { 1: 26, 2: 44, 3: 70, 4: 100, 5: 134, 6: 172, 7: 196, 8: 242, 9: 292, 10: 346 };
  // [blocos, dados por bloco, correção por bloco] — nível L.
  const QR_BLOCOS = {
    1: [[1, 19, 7]], 2: [[1, 34, 10]], 3: [[1, 55, 15]], 4: [[1, 80, 20]], 5: [[1, 108, 26]],
    6: [[2, 68, 18]], 7: [[2, 78, 20]], 8: [[2, 97, 24]], 9: [[2, 116, 30]], 10: [[2, 68, 18], [2, 69, 18]]
  };
  const QR_CAPACIDADE = { 1: 17, 2: 32, 3: 53, 4: 78, 5: 106, 6: 134, 7: 154, 8: 192, 9: 230, 10: 271 };
  const QR_ALINHAMENTO = { 1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34], 7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50] };

  const GF_EXP = new Array(512), GF_LOG = new Array(256);
  (function tabelaGF() {
    let x = 1;
    for (let i = 0; i < 255; i++) {
      GF_EXP[i] = x;
      GF_LOG[x] = i;
      x <<= 1;
      if (x & 0x100) x ^= 0x11d;
    }
    for (let i = 255; i < 512; i++) GF_EXP[i] = GF_EXP[i - 255];
  })();
  const gmul = (a, b) => (a === 0 || b === 0 ? 0 : GF_EXP[GF_LOG[a] + GF_LOG[b]]);

  function geradorPolinomio(grau) {
    let poly = [1];
    for (let i = 0; i < grau; i++) {
      const proximo = new Array(poly.length + 1).fill(0);
      for (let j = 0; j < poly.length; j++) {
        proximo[j] ^= poly[j];
        proximo[j + 1] ^= gmul(poly[j], GF_EXP[i]);
      }
      poly = proximo;
    }
    return poly;
  }

  function correcao(dados, ecLen) {
    const gen = geradorPolinomio(ecLen);
    const resto = dados.concat(new Array(ecLen).fill(0));
    for (let i = 0; i < dados.length; i++) {
      const coef = resto[i];
      if (coef !== 0) for (let j = 0; j < gen.length; j++) resto[i + j] ^= gmul(gen[j], coef);
    }
    return resto.slice(dados.length);
  }

  function utf8(texto) {
    const s = String(texto == null ? '' : texto);
    const bytes = [];
    for (let i = 0; i < s.length; i++) {
      let c = s.charCodeAt(i);
      if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
        const d = s.charCodeAt(i + 1);
        if (d >= 0xdc00 && d <= 0xdfff) { c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00); i++; }
      }
      if (c < 0x80) bytes.push(c);
      else if (c < 0x800) bytes.push(0xc0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) bytes.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else bytes.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return bytes;
  }

  function bchFormato(dado) {
    let d = dado << 10;
    for (let i = 14; i >= 10; i--) if ((d >> i) & 1) d ^= 0x537 << (i - 10);
    return (((dado << 10) | d) ^ 0x5412) & 0x7fff;
  }
  function bchVersao(versao) {
    let d = versao << 12;
    for (let i = 17; i >= 12; i--) if ((d >> i) & 1) d ^= 0x1f25 << (i - 12);
    return ((versao << 12) | d) & 0x3ffff;
  }

  const mascarar = (mask, r, c) => {
    switch (mask) {
      case 0: return (r + c) % 2 === 0;
      case 1: return r % 2 === 0;
      case 2: return c % 3 === 0;
      case 3: return (r + c) % 3 === 0;
      case 4: return (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0;
      case 5: return ((r * c) % 2) + ((r * c) % 3) === 0;
      case 6: return (((r * c) % 2) + ((r * c) % 3)) % 2 === 0;
      default: return (((r + c) % 2) + ((r * c) % 3)) % 2 === 0;
    }
  };

  /* Monta a matriz do QR. Devolve { versao, tamanho, modulos[][] } ou null. */
  function qrMatriz(texto, opcoes) {
    const o = opcoes || {};
    const bytes = utf8(texto);
    let versao = 0;
    for (let v = 1; v <= 10; v++) {
      if (bytes.length <= QR_CAPACIDADE[v]) { versao = v; break; }
    }
    if (!versao) return null;
    const mascara = o.mascara == null ? 0 : o.mascara;
    const totalDados = QR_BLOCOS[versao].reduce((s, b) => s + b[0] * b[1], 0);

    /* --- fluxo de bits: modo byte + contagem + dados */
    const bits = [];
    const push = (valor, tamanho) => { for (let i = tamanho - 1; i >= 0; i--) bits.push((valor >> i) & 1); };
    push(0b0100, 4);
    push(bytes.length, versao <= 9 ? 8 : 16);
    bytes.forEach((b) => push(b, 8));
    const limite = totalDados * 8;
    for (let i = 0; i < 4 && bits.length < limite; i++) bits.push(0);
    while (bits.length % 8 !== 0) bits.push(0);
    const codewords = [];
    for (let i = 0; i < bits.length; i += 8) {
      let b = 0;
      for (let j = 0; j < 8; j++) b = (b << 1) | bits[i + j];
      codewords.push(b);
    }
    let alterna = true;
    while (codewords.length < totalDados) { codewords.push(alterna ? 0xec : 0x11); alterna = !alterna; }

    /* --- blocos + Reed-Solomon */
    const blocos = [];
    let cursor = 0;
    for (const [quantos, porBloco, ec] of QR_BLOCOS[versao]) {
      for (let i = 0; i < quantos; i++) {
        const dados = codewords.slice(cursor, cursor + porBloco);
        cursor += porBloco;
        blocos.push({ dados: dados, ec: correcao(dados, ec) });
      }
    }
    const fluxo = [];
    const maior = Math.max.apply(null, blocos.map((b) => b.dados.length));
    for (let i = 0; i < maior; i++) blocos.forEach((b) => { if (i < b.dados.length) fluxo.push(b.dados[i]); });
    const maiorEC = Math.max.apply(null, blocos.map((b) => b.ec.length));
    for (let i = 0; i < maiorEC; i++) blocos.forEach((b) => { if (i < b.ec.length) fluxo.push(b.ec[i]); });

    /* --- matriz vazia + padrões fixos */
    const tamanho = 17 + 4 * versao;
    const modulos = [];
    const reservado = [];
    for (let i = 0; i < tamanho; i++) { modulos.push(new Array(tamanho).fill(false)); reservado.push(new Array(tamanho).fill(false)); }
    const marcar = (r, c, valor) => { modulos[r][c] = Boolean(valor); reservado[r][c] = true; };

    function localizador(linha, coluna) {
      for (let r = -1; r <= 7; r++) {
        for (let c = -1; c <= 7; c++) {
          const rr = linha + r, cc = coluna + c;
          if (rr < 0 || cc < 0 || rr >= tamanho || cc >= tamanho) continue;
          const dentro = r >= 0 && r <= 6 && c >= 0 && c <= 6;
          const borda = r === 0 || r === 6 || c === 0 || c === 6;
          const centro = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          marcar(rr, cc, dentro && (borda || centro));
        }
      }
    }
    localizador(0, 0); localizador(0, tamanho - 7); localizador(tamanho - 7, 0);

    for (let i = 8; i < tamanho - 8; i++) { marcar(6, i, i % 2 === 0); marcar(i, 6, i % 2 === 0); }

    const alin = QR_ALINHAMENTO[versao] || [];
    for (const r of alin) {
      for (const c of alin) {
        const canto = (r === 6 && c === 6) || (r === 6 && c === tamanho - 7) || (r === tamanho - 7 && c === 6);
        if (canto) continue;
        for (let dr = -2; dr <= 2; dr++) {
          for (let dc = -2; dc <= 2; dc++) {
            const borda = Math.max(Math.abs(dr), Math.abs(dc));
            marcar(r + dr, c + dc, borda !== 1);
          }
        }
      }
    }

    // Reserva as áreas de formato e de versão antes de espalhar os dados.
    for (let i = 0; i < 9; i++) { reservado[8][i] = true; reservado[i][8] = true; }
    for (let i = 0; i < 8; i++) { reservado[8][tamanho - 1 - i] = true; reservado[tamanho - 1 - i][8] = true; }
    if (versao >= 7) {
      for (let i = 0; i < 6; i++) for (let j = 0; j < 3; j++) { reservado[i][tamanho - 11 + j] = true; reservado[tamanho - 11 + j][i] = true; }
    }

    /* --- dados em zigue-zague */
    let bit = 0;
    const totalBits = fluxo.length * 8;
    const lerBit = (i) => (fluxo[i >> 3] >> (7 - (i & 7))) & 1;
    for (let direita = tamanho - 1; direita >= 1; direita -= 2) {
      if (direita === 6) direita = 5;
      for (let vertical = 0; vertical < tamanho; vertical++) {
        for (let j = 0; j < 2; j++) {
          const coluna = direita - j;
          const subindo = ((direita + 1) & 2) === 0;
          const linha = subindo ? tamanho - 1 - vertical : vertical;
          if (reservado[linha][coluna]) continue;
          const valor = bit < totalBits ? Boolean(lerBit(bit)) : false;
          modulos[linha][coluna] = valor !== mascarar(mascara, linha, coluna);
          bit++;
        }
      }
    }

    /* --- formato e versão */
    const formato = bchFormato((1 << 3) | mascara); // nível L = 01
    for (let i = 0; i < 15; i++) {
      const mod = ((formato >> i) & 1) === 1;
      if (i < 6) modulos[i][8] = mod;
      else if (i < 8) modulos[i + 1][8] = mod;
      else modulos[tamanho - 15 + i][8] = mod;
      if (i < 8) modulos[8][tamanho - i - 1] = mod;
      else if (i < 9) modulos[8][15 - i] = mod;
      else modulos[8][14 - i] = mod;
    }
    modulos[tamanho - 8][8] = true;

    if (versao >= 7) {
      const info = bchVersao(versao);
      for (let i = 0; i < 18; i++) {
        const mod = ((info >> i) & 1) === 1;
        const a = tamanho - 11 + (i % 3), b = Math.floor(i / 3);
        modulos[b][a] = mod;
        modulos[a][b] = mod;
      }
    }

    return { versao: versao, tamanho: tamanho, modulos: modulos, mascara: mascara, nivel: 'L', bytes: bytes.length };
  }

  /* Desenha no canvas. Aceita HTMLCanvasElement ou qualquer objeto com getContext. */
  function desenharQR(matriz, canvas, opcoes) {
    if (!matriz || !canvas || typeof canvas.getContext !== 'function') return false;
    const o = opcoes || {};
    const quieta = o.quieta == null ? 4 : o.quieta;
    const escala = o.escala || Math.max(2, Math.floor(256 / (matriz.tamanho + quieta * 2)));
    const lado = (matriz.tamanho + quieta * 2) * escala;
    canvas.width = lado;
    canvas.height = lado;
    const ctx = canvas.getContext('2d');
    if (!ctx) return false;
    ctx.fillStyle = o.fundo || '#ffffff';
    ctx.fillRect(0, 0, lado, lado);
    ctx.fillStyle = o.frente || '#000000';
    for (let r = 0; r < matriz.tamanho; r++) {
      for (let c = 0; c < matriz.tamanho; c++) {
        if (matriz.modulos[r][c]) ctx.fillRect((c + quieta) * escala, (r + quieta) * escala, escala, escala);
      }
    }
    if (typeof o.aoDesenhar === 'function') o.aoDesenhar(canvas);
    return true;
  }

  /* ------------------------------------------------------------ integração */
  // Capacidades do aplicativo, injetadas por instalar().
  let cap = null;

  async function falar(texto, links) {
    if (cap && typeof cap.falar === 'function') return cap.falar(texto, false, null, links);
    return null;
  }

  // Painel simples para mostrar o QR. Estilo inline para não depender do CSS do app.
  function mostrarQR(matriz, texto) {
    if (typeof document === 'undefined') return false;
    const antigo = document.getElementById('utilitarios-qr');
    if (antigo) antigo.remove();
    const caixa = document.createElement('div');
    caixa.id = 'utilitarios-qr';
    caixa.style.cssText = 'position:fixed;inset:0;z-index:9999;display:flex;align-items:center;justify-content:center;background:rgba(0,10,18,.86);backdrop-filter:blur(4px);padding:16px;';
    const interno = document.createElement('div');
    interno.style.cssText = 'background:#07131c;border:1px solid #17c8ff;border-radius:16px;padding:16px;max-width:92vw;max-height:92vh;overflow:auto;text-align:center;box-shadow:0 0 32px rgba(23,200,255,.35);font-family:system-ui,sans-serif;color:#dff6ff;';
    const titulo = document.createElement('div');
    titulo.textContent = 'QR Code';
    titulo.style.cssText = 'font-weight:600;letter-spacing:.08em;font-size:.92rem;margin-bottom:10px;color:#17c8ff;';
    const canvas = document.createElement('canvas');
    canvas.style.cssText = 'width:min(78vw,320px);height:auto;border-radius:10px;display:block;margin:0 auto;';
    const rodape = document.createElement('div');
    rodape.textContent = texto.length > 120 ? texto.slice(0, 117) + '…' : texto;
    rodape.style.cssText = 'margin:10px auto 0;max-width:300px;font-size:.78rem;opacity:.8;word-break:break-all;';
    const fechar = document.createElement('button');
    fechar.textContent = 'Fechar';
    fechar.style.cssText = 'margin-top:12px;padding:8px 22px;border-radius:999px;border:1px solid #17c8ff;background:transparent;color:#17c8ff;font-size:.9rem;';
    fechar.addEventListener('click', () => caixa.remove());
    caixa.addEventListener('click', (e) => { if (e.target === caixa) caixa.remove(); });
    interno.appendChild(titulo); interno.appendChild(canvas); interno.appendChild(rodape); interno.appendChild(fechar);
    caixa.appendChild(interno);
    document.body.appendChild(caixa);
    desenharQR(matriz, canvas);
    return true;
  }

  /* ------------------------------------------------------------- comandos */
  // Devolve true quando assumiu o turno (já falou a resposta).
  async function comando(texto, opcoes) {
    const o = opcoes || {};
    const responder = typeof o.falar === 'function' ? o.falar : falar;
    const rnd = o.rnd || Math.random;
    const n = limpar(texto);
    if (!n) return false;

    /* IMC */
    if (/\bimc\b|indice de massa|\bmassa corporal\b/.test(n)) {
      const dados = extrairImc(n);
      if (!dados) { await responder('Me diga o peso em quilos e a altura em metros. Por exemplo: "calcule meu IMC, 80 quilos e 1,80 de altura".'); return true; }
      const r = imc(dados.peso, dados.altura);
      await responder('Seu IMC com ' + formatar(r.peso, 1) + ' quilos e ' + formatar(r.altura, 2) + ' metros dá ' + formatar(r.valor, 1) + ', que fica em ' + r.classe + ' pela referência da OMS para adultos. Se você tem menos de dezoito anos, atleta ou gestante, esse número não se interpreta assim.');
      return true;
    }

    /* base numérica antes das unidades, porque "10 decimal para binário" também tem número */
    const base = extrairBase(n);
    if (base) {
      const r = baseNumerica(base.valor, base.de, base.para);
      if (r) { await responder(base.valor + ' na base ' + base.de.toUpperCase() + ' é ' + r.texto + ' na base ' + base.para.toUpperCase() + '.'); return true; }
      await responder('Esse número não existe na base informada. Confira os dígitos e tente de novo.');
      return true;
    }

    /* conversão de unidades e temperatura */
    if (/(?:converta|converter|quanto e|quanto sao|transforme)\b/.test(n) || /\bpara\b|\bem\b/.test(n)) {
      const c = extrairConversao(n);
      if (c) {
        const r = converter(c.valor, c.de, c.para);
        if (r) { await responder(r.texto + '.'); return true; }
      }
    }

    /* piadas e curiosidades */
    if (/\b(?:piada|piadas|conta uma piada|me faz rir)\b/.test(n)) { await responder(piada(rnd)); return true; }
    if (/\b(?:curiosidade|curiosidades|fato curioso|fato aleatorio|me conta um fato)\b/.test(n)) { await responder(curiosidade(rnd)); return true; }

    /* QR Code */
    const mQr = /^(?:gere?|gerar|crie?|criar|faca|mostre?|mostrar|abra?)\s+(?:um\s+|o\s+)?(?:qr\s*-?\s*code|qrcode|codigo qr)\s*(?:de|do|da|para|com|:)?\s*(.*)$/.exec(n);
    if (mQr) {
      const conteudo = String(texto).replace(/^[\s\S]*?(?:qr\s*-?\s*code|qrcode|codigo qr)\s*(?:de|do|da|para|com|:)?\s*/i, '').trim();
      if (!conteudo) { await responder('Diga o conteúdo do QR Code. Por exemplo: "gere um QR Code de jarvis nova".'); return true; }
      const matriz = qrMatriz(conteudo);
      if (!matriz) { await responder('Esse texto é longo demais para um QR Code simples. Até duzentos e setenta caracteres eu consigo.'); return true; }
      const mostrou = mostrarQR(matriz, conteudo);
      await responder(mostrou
        ? 'Gerei o QR Code de ' + conteudo + '. Ele está na tela; toque em Fechar quando terminar.'
        : 'Gerei o QR Code de ' + conteudo + ', mas esta tela não consegue desenhá-lo.');
      return true;
    }

    /* jogo da velha */
    if (/\bjogo da velha\b|\bvelha\b/.test(n) && !/\b(?:marque|jogue|jogar|posicao|casa)\b/.test(n)) {
      const j = velhaNovo();
      await responder('Jogo da velha. Você é X e começa. Escolha uma casa de 1 a 9 dizendo "marque 5". Tabuleiro: ' + velhaTexto(j.casas));
      return true;
    }
    const mVelha = /(?:marque|marque a casa|jogue|jogar|posicao|casa)\s*(\d)\b/.exec(n);
    if (mVelha && ESTADO.jogo && ESTADO.jogo.tipo === 'velha') {
      const r = velhaJogar(mVelha[1], rnd);
      if (r.erro) { await responder(r.erro); return true; }
      if (r.resultado === 'X') { await responder('Você ganhou. Tabuleiro: ' + r.tabuleiro); return true; }
      if (r.resultado === 'O') { await responder('Eu ganhei. Tabuleiro: ' + r.tabuleiro); return true; }
      if (r.resultado === 'empate') { await responder('Empatou. Tabuleiro: ' + r.tabuleiro); return true; }
      await responder('Sua vez. Tabuleiro: ' + r.tabuleiro);
      return true;
    }

    /* adivinhação */
    if (/\badivinhe? (?:um )?numero\b|\bjogo de adivinhar\b/.test(n)) {
      adivinharNovo(rnd);
      await responder('Pensei em um número de 1 a 100. Diga "chute 50" para tentar.');
      return true;
    }
    const mChute = /(?:chute|chutar|tente|tentativa)\s*(\d{1,3})\b/.exec(n);
    if (mChute && ESTADO.jogo && ESTADO.jogo.tipo === 'adivinha') {
      const r = adivinharChute(mChute[1]);
      await responder(r.erro || r.texto);
      return true;
    }

    /* pedra, papel e tesoura */
    if (/\bpedra\b|\bpapel\b|\btesoura\b/.test(n) && /\b(?:pedra|papel|tesoura)\b.*\b(?:pedra|papel|tesoura)\b/.test(n + ' pedra papel tesoura')) {
      const r = ppt(n, rnd);
      if (r) { await responder('Eu escolhi ' + r.jarvis + ', você escolheu ' + r.jogador + ': ' + r.resultado + '.'); return true; }
    }

    /* dados, moeda e sorteio */
    if (/\b(?:jogue|role|joga|rola|lance)\s+(?:o\s+|os\s+|um\s+|dois\s+)?(?:dado|dados)\b|\bdado\b/.test(n)) {
      const q = /\b(?:dois|2)\b/.test(n) ? 2 : 1;
      const r = dado(q, rnd);
      await responder(q === 1 ? 'Deu ' + r.valores[0] + '.' : 'Deram ' + r.valores.join(' e ') + ', somando ' + r.total + '.');
      return true;
    }
    if (/\bcara ou coroa\b|\bjogue? uma moeda\b|\bjogar moeda\b/.test(n)) { await responder('Deu ' + moeda(rnd) + '.'); return true; }
    const mSorteio = /(?:sorteie|sorteia|sorteio|numero aleatorio)\D{0,15}(\d{1,4})\D{1,6}(\d{1,4})/.exec(n);
    if (mSorteio) {
      const r = sortearInteiro(mSorteio[1], mSorteio[2], rnd);
      await responder('Sorteei ' + r + '.');
      return true;
    }

    return false;
  }

  /* Troca o resolvedor local do aplicativo por um que inclui estes comandos.
   * O original roda primeiro: nada do que já funcionava muda de comportamento. */
  function instalar(hermes) {
    const alvo = hermes || (typeof window !== 'undefined' ? window.Hermes : null);
    if (!alvo || typeof alvo.instalar !== 'function') return false;
    if (alvo.__utilitariosInstalados) return true;
    const novo = Object.assign({}, alvo.cap || {});
    const anterior = typeof novo.comandoLocal === 'function' ? novo.comandoLocal : null;
    novo.comandoLocal = async (texto) => {
      if (anterior) {
        try { if (await anterior(texto)) return true; } catch (e) { /* segue para os utilitários */ }
      }
      try { return await comando(texto); } catch (e) { return false; }
    };
    alvo.instalar(novo);
    cap = alvo.cap || novo;
    alvo.__utilitariosInstalados = true;
    return true;
  }

  return {
    VERSAO: VERSAO,
    NOME: NOME,
    instalar: instalar,
    comando: comando,
    imc: imc,
    extrairImc: extrairImc,
    converter: converter,
    extrairConversao: extrairConversao,
    baseNumerica: baseNumerica,
    extrairBase: extrairBase,
    piada: piada,
    curiosidade: curiosidade,
    PIADAS: PIADAS,
    CURIOSIDADES: CURIOSIDADES,
    estadoJogo: () => ESTADO.jogo,
    velhaNovo: velhaNovo,
    velhaJogar: velhaJogar,
    velhaTexto: velhaTexto,
    vencedor: vencedor,
    adivinharNovo: adivinharNovo,
    adivinharChute: adivinharChute,
    ppt: ppt,
    dado: dado,
    moeda: moeda,
    sortearInteiro: sortearInteiro,
    qrMatriz: qrMatriz,
    desenharQR: desenharQR,
    mostrarQR: mostrarQR
  };
});
