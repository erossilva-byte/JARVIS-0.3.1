// Teste de comportamento (não apenas estático) do diagnóstico do segundo plano:
// extrai as funções novas de app.js e as executa com um DOM mínimo simulado.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const app = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const ini = app.indexOf('const OEM_DICA');
const fim = app.indexOf('/* ---------- Ajustes ---------- */');
if (ini < 0 || fim < 0 || fim <= ini) throw new Error('não localizei o bloco de diagnóstico');
const fonte = app.slice(ini, fim);

function el(tag = 'div') {
  const e = {
    tag, filhos: [], textContent: '', className: '', style: {}, dataset: {}, hidden: false,
    appendChild(f) { this.filhos.push(f); return f; },
    setAttribute() {}, addEventListener() {}
  };
  return e;
}

const nos = { 'bg-diag': el(), 'bg-resumo': el('output'), 'bg-diag-status': el('p') };
const texto = (e) => String(e.textContent || '') + e.filhos.map(texto).join(' ');
const document = {
  getElementById: (id) => nos[id] || null,
  createElement: (t) => el(t)
};

let ultimaFala = '';
const ctx = {
  document,
  console,
  plataforma: 'android',
  ehAndroid: true,
  nativo: async () => ({ info: 'aberto' }),
  registrar: () => {},
  plug: () => ({
    diagnosticoEscuta: async () => ({
      mic: true, notificacoes: false, bateriaLivre: false, sobreposicao: true,
      acessoNotificacoes: false, servico: true, escutando: true,
      detector: 'picovoice-porcupine', desejada: true, chaveSalva: true,
      ultimoErro: '', ultimoEvento: Date.now() - 60000,
      fabricante: 'Xiaomi', modelo: 'Redmi', android: '14', testeAtivo: false,
      restricaoOem: 'xiaomi'
    })
  })
};
vm.createContext(ctx);
vm.runInContext(fonte, ctx);

(async () => {
  const r = await ctx.diagnosticoSegundoPlano(false);
  const linhas = nos['bg-diag'].filhos;
  const classes = linhas.map((l) => l.className);
  const ok = [];
  ok.push(['renderiza uma linha por verificação', linhas.length === 8]);
  ok.push(['marca microfone ok', classes.includes('diag-row ok')]);
  ok.push(['marca notificações como falha', classes.includes('diag-row fail')]);
  ok.push(['marca acesso a notificações como aviso', classes.includes('diag-row warn')]);
  ok.push(['resumo conta pendências', nos['bg-resumo'].textContent === '2 pendência(s)']);
  ok.push(['resumo fala o que falta', /notificações/.test(r.resumo) && /bateria/.test(r.resumo)]);
  ok.push(['pede ajuste do fabricante', /Xiaomi/.test(linhas.map(texto).join(' ')) && /Início automático/.test(texto(nos['bg-diag']))]);
  ok.push(['cada linha tem texto explicativo', linhas.every((l) => texto(l).trim().length > 8)]);

  // Sem pendências: resumo "pronto" e fala positiva.
  ctx.plug = () => ({
    diagnosticoEscuta: async () => ({
      mic: true, notificacoes: true, bateriaLivre: true, sobreposicao: true,
      acessoNotificacoes: true, servico: true, escutando: true,
      detector: 'android-sem-chave', desejada: true, chaveSalva: false,
      ultimoErro: '', ultimoEvento: Date.now(), fabricante: 'Samsung',
      modelo: 'SM', android: '13', testeAtivo: false, restricaoOem: 'samsung'
    })
  });
  vm.runInContext('plug = ' + ctx.plug.toString(), ctx);
  const r2 = await ctx.diagnosticoSegundoPlano(false);
  ok.push(['tudo certo mostra pronto', nos['bg-resumo'].textContent === 'pronto']);
  ok.push(['fala confirma detector', /reconhecimento do Android/.test(r2.resumo)]);

  let falhas = 0;
  for (const [nome, passou] of ok) {
    console.log((passou ? 'OK: ' : 'FALHA: ') + nome);
    if (!passou) falhas++;
  }
  // Lembrete de tarefa: id estável e distinto por tarefa.
  const trecho = app.slice(app.indexOf('function idAvisoTarefa'), app.indexOf('async function agendarAvisoTarefa'));
  vm.runInContext(trecho, ctx);
  const a = ctx.idAvisoTarefa({ id: 'abc' }), b = ctx.idAvisoTarefa({ id: 'abc' }), c = ctx.idAvisoTarefa({ id: 'abd' });
  const okId = a === b && a !== c && a >= 1000 && a < 91000;
  console.log((okId ? 'OK: ' : 'FALHA: ') + 'identificador de lembrete estável');
  if (!okId) falhas++;
  if (falhas) process.exit(1);
  console.log('Diagnóstico do segundo plano validado em DOM simulado.');
})();
