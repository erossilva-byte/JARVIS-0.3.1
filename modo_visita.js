/* J.A.R.V.I.S. Nova — Modo de visita no PC.
 *
 * Porte de `core/modo_visita.dart` do celular. O modo de visita é o app aberto
 * com o **PIN de coação**, diferente do PIN principal: ele não mostra as
 * conversas, a memória, as fichas, os arquivos nem as chaves do dono. Nada é
 * apagado; tudo volta ao entrar com o PIN principal.
 *
 * As respostas são locais: nenhuma pergunta sai do computador, porque qualquer
 * texto enviado a um provedor levaria junto o contexto de quem é o dono.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.ModoVisita = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var NOME_PROMPT = 'Modo de visita';

  var PROMPT = '\nVocê está no ' + NOME_PROMPT + ' do JARVIS, em um computador sem dados configurados. ' +
    'Responda em português do Brasil, em no máximo três frases, com tom cordial e neutro. ' +
    'Nunca mencione o dono do computador, conversas anteriores, memória, fichas de pessoas, ' +
    'arquivos, localização, compromissos ou chaves de provedor. Se pedirem algo pessoal, diga ' +
    'que este computador não tem dados configurados e ofereça ajuda geral. Não invente fatos, ' +
    'não finja ter acesso a nada e não peça senhas. Se a pergunta for sobre o próprio JARVIS, ' +
    'diga apenas que é um assistente e que os recursos dependem de configuração.\n';

  var BOAS_VINDAS = 'Bom dia. Eu sou o JARVIS. Este computador ainda não tem um provedor de ' +
    'inteligência configurado.';

  var AJUSTES = [
    ['Provedor de IA', 'Nenhum configurado'],
    ['Conversas', 'Nenhuma guardada'],
    ['Memória', 'Vazia'],
    ['Pessoas', 'Nenhuma ficha'],
    ['Arquivos e cofre', 'Nenhum arquivo'],
    ['Palavra de ativação', 'Desligada']
  ];

  var LIMITES = [
    'O modo de visita não apaga nada: as conversas, a memória e as fichas continuam ' +
      'no computador e voltam com o PIN principal.',
    'Ele esconde o conteúdo, não o criptografa de novo. Com acesso técnico ao ' +
      'computador, os dados reais ainda podem ser encontrados.',
    'Fechar e reabrir o aplicativo volta ao bloqueio normal; o modo de visita não ' +
      'fica “ligado” entre sessões.',
    'Nada é enviado à internet no modo de visita: nenhuma pergunta sai do computador.',
    'Quem conhece os dois PINs não é protegido por ele.'
  ];

  var DIAS = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira',
    'sexta-feira', 'sábado', 'domingo'];
  var MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
    'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

  function hora(quando) {
    var h = String(quando.getHours()).padStart(2, '0');
    var m = String(quando.getMinutes()).padStart(2, '0');
    return h + ' horas e ' + m + ' minutos';
  }

  function data(quando) {
    return DIAS[quando.getDay() === 0 ? 6 : quando.getDay() - 1] + ', ' +
      quando.getDate() + ' de ' + MESES[quando.getMonth()] + ' de ' + quando.getFullYear();
  }

  /** Resposta local, sem rede, sem provedor e sem dado de quem é o dono. */
  function respostaVisita(pergunta, opcoes) {
    var texto = String(pergunta == null ? '' : pergunta).trim().toLowerCase();
    if (!texto) return 'Pode perguntar. Neste computador eu respondo só o básico.';
    var quando = (opcoes && opcoes.agora) || new Date();
    if (/que horas|hora agora/.test(texto)) return 'Agora são ' + hora(quando) + '.';
    if (/que dia|data de hoje|hoje é/.test(texto)) return 'Hoje é ' + data(quando) + '.';
    if (/^(oi|olá|ola)\b/.test(texto) || /bom dia|boa tarde|boa noite/.test(texto)) {
      return 'Olá. Em que posso ajudar?';
    }
    if (/quem é você|seu nome/.test(texto)) return 'Sou o JARVIS, um assistente neste computador.';
    if (/culinária|culinaria|receita/.test(texto)) {
      return 'Sobre culinária eu não tenho um provedor de inteligência configurado aqui. ' +
        'Este computador ainda não foi ajustado para isso.';
    }
    return 'Neste computador eu ainda não tenho um provedor de inteligência configurado, ' +
      'então não consigo responder isso. Tudo o que é seu segue guardado.';
  }

  /** O que a tela de ajustes do modo de visita mostra — sempre vazio. */
  function ajustes() {
    return AJUSTES.map(function (par) { return { nome: par[0], valor: par[1] }; });
  }

  return {
    NOME_PROMPT: NOME_PROMPT,
    PROMPT: PROMPT,
    BOAS_VINDAS: BOAS_VINDAS,
    AJUSTES: AJUSTES,
    LIMITES: LIMITES,
    respostaVisita: respostaVisita,
    ajustes: ajustes
  };
});
