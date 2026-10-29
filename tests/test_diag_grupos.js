// Comportamento (não só aparência) do diagnóstico agrupado por área: extrai o bloco
// real de app.js e roda com um DOM mínimo, conferindo em qual grupo cada linha cai,
// a contagem/pior estado dos grupos e a ordem fixa das áreas.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const app = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const ini = app.indexOf('const DIAG_ESTADOS');
const fim = app.indexOf('async function testarRedeDiagnostico');
if (ini < 0 || fim < 0 || fim <= ini) throw new Error('não localizei o bloco do diagnóstico');
const fonte = app.slice(ini, fim);

function no(tag = 'div') {
  return {
    tag, className: '', textContent: '', dataset: {}, filhos: [], pai: null,
    appendChild(f) {
      const i = this.filhos.indexOf(f);
      if (i >= 0) this.filhos.splice(i, 1);
      this.filhos.push(f); f.pai = this; return f;
    },
    append(...novos) { novos.forEach((f) => this.appendChild(f)); },
    querySelector(sel) { const r = buscar(this, sel, true); return r.length ? r[0] : null; },
    querySelectorAll(sel) { return buscar(this, sel, false); }
  };
}
function casa(n, sel) {
  const m = sel.match(/^\[data-diag-cat="([^"]+)"\]$/);
  if (m) return n.dataset && n.dataset.diagCat === m[1];
  if (sel === '[data-diag-cat]') return !!(n.dataset && n.dataset.diagCat);
  const c = sel.replace(/^\./, '');
  return String(n.className || '').split(/\s+/).includes(c);
}
function buscar(raiz, sel, primeiro) {
  const achados = [];
  (function anda(n) {
    n.filhos.forEach((f) => {
      if (casa(f, sel)) achados.push(f);
      if (!(primeiro && achados.length)) anda(f);
    });
  })(raiz);
  return achados;
}
const raiz = no();
const ctx = {
  console,
  diagColetor: null,
  document: { createElement: (t) => no(t) },
  $: (sel) => (sel === '#c-diagnostico-result' ? raiz : null),
  registrar: () => {}
};
vm.createContext(ctx);
vm.runInContext(fonte, ctx);

const falhas = [];
const ok = (nome, cond) => { console.log((cond ? 'OK: ' : 'FALHA: ') + nome); if (!cond) falhas.push(nome); };
const grupo = (cat) => raiz.filhos.find((g) => g.dataset.diagCat === cat);
const linhas = (cat) => {
  const g = grupo(cat);
  if (!g) return [];
  const lista = g.filhos.find((f) => String(f.className).includes('diag-grupo-lista'));
  return lista ? lista.filhos : [];
};

ctx.diagLinha('ok', 'Chave Groq', 'Configurada.');
ctx.diagLinha('fail', 'Chave Gemini', 'Não configurada.');
ctx.diagLinha('warn', 'Permissão de microfone', 'Não consultada.');
ctx.diagLinha('ok', 'Cofre do Obsidian', 'Conectado.');
ctx.diagLinha('ok', 'Plataforma', 'android');
ctx.diagLinha('ok', 'Conexão e CORS', 'Respondeu.');
ctx.diagLinha('ok', 'Abertura do aplicativo', 'Concluída.');
ctx.diagLinha('warn', 'Erros recentes', 'x'.repeat(220));

ok('cada verificação cai na área certa', grupo('ia') && linhas('ia').length === 2 && linhas('voz').length === 1
  && linhas('memoria').length === 1 && linhas('sistema').length === 1 && linhas('rede').length === 1 && linhas('app').length === 2);
ok('nenhuma linha fora de um grupo', raiz.filhos.every((g) => g.dataset.diagCat));

vm.runInContext('diagFecharGrupos()', ctx);
const cont = (cat) => {
  const g = grupo(cat);
  const c = g.querySelector('.diag-grupo-contagem');
  return c ? c.textContent : '';
};
const textoDe = (n) => String(n.textContent || '') + n.filhos.map(textoDe).join(' ');
ok('contagem por área', cont('ia') === '2 itens · Falha' && cont('memoria') === '1 item · Operacional');
ok('pior estado marca o grupo', cont('voz') === '1 item · Aviso' && grupo('ia').dataset.diagPior === 'fail');
ok('grupos na ordem fixa das áreas',
  raiz.filhos.map((g) => g.dataset.diagCat).join(',') === 'app,ia,voz,memoria,sistema,rede');

const linhaLonga = linhas('app').find((l) => /Erros recentes/.test(textoDe(l)));
const detalhes = linhaLonga && linhaLonga.filhos.find((f) => String(f.className).includes('diag-tec'));
ok('detalhes técnicos recolhíveis em texto longo', !!detalhes && detalhes.filhos.some((f) => f.tag === 'summary'));
ok('linha curta não ganha detalhe extra', !linhas('memoria')[0].filhos.some((f) => String(f.className).includes('diag-tec')));

if (falhas.length) { console.log('\n' + falhas.length + ' verificação(ões) do diagnóstico agrupado falharam.'); process.exit(1); }
console.log('Diagnóstico agrupado por área validado em DOM simulado.');
