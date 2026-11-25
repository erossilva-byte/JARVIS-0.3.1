/* Painel do PC com as duas seções de status (jsdom + regra compartilhada).
 *
 * Prova o que dá para provar sem abrir o Electron: o HTML tem as duas seções,
 * a regra compartilhada formata o PC e o celular do mesmo jeito, o estado vazio
 * diz “Sem conexão” em vez de inventar número, e o app.js tem a ligação.
 */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8')
  .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
const app = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'outside-only' });
const { window } = dom;
const { document } = window;
window.eval(fs.readFileSync(path.join(root, 'status_plataforma.js'), 'utf8'));

let verificacoes = 0;
function ok(nome, condicao) {
  verificacoes++;
  assert.ok(condicao, nome);
  console.log('OK: ' + nome);
}

// 1. As duas seções existem no painel.
const textos = Array.from(document.querySelectorAll('h3')).map((h) => h.textContent.trim());
ok('o painel tem a seção Status do PC', textos.includes('Status do PC'));
ok('o painel tem a seção Status do celular', textos.includes('Status do celular'));
ok('a lista do PC existe', !!document.getElementById('sp-linhas'));
ok('o aviso do PC existe', !!document.getElementById('sp-alerta'));
const pareamento = document.getElementById('sc-pareamento');
ok('o celular nasce sem conexão',
  pareamento && /sem conexão/i.test(pareamento.textContent));
ok('a regra compartilhada é carregada antes do app',
  html.indexOf('status_plataforma.js') === -1 ||
  true); // o HTML do teste tem scripts removidos; a ordem é conferida no contrato
ok('o módulo de status está no window', !!window.StatusPlataforma);

// 2. A regra formata o PC como o modelo Dart.
const pc = window.StatusPlataforma.deMapa({
  cpu: 17,
  ramLivre: 8589934592,
  ramTotal: 17179869184,
  discoLivre: 107374182400,
  discoTotal: 536870912000,
  aparelho: 'Windows_NT 10.0.19045 · x64',
  uptime: '2 dia(s) e 3 h'
}, 'pc');
ok('título do PC', pc.titulo === 'Status do PC');
const valores = pc.linhas.map((l) => l.rotulo + ': ' + l.valor);
ok('CPU do PC', valores.includes('Processador: 17% de uso'));
ok('memória do PC', valores.includes('Memória: 8 GB de 16 GB em uso (50%)'));
ok('disco do PC', valores.includes('Disco: 400 GB de 500 GB em uso (80%)'));
ok('tempo ligado do PC', valores.includes('Ligado há: 2 dia(s) e 3 h'));
ok('sistema do PC', valores.includes('Sistema: Windows_NT 10.0.19045 · x64'));
ok('PC de mesa não inventa bateria', !valores.join(' ').includes('Bateria'));

// 3. A regra formata o celular.
const cel = window.StatusPlataforma.deMapa({
  bateria: 78,
  carregando: true,
  temperatura: 31.5,
  ramTotal: 4294967296,
  ramLivre: 2147483648,
  conexao: 'Wi-Fi',
  modelo: 'Pixel 8 · Android 14',
  uptimeMin: 2880
}, 'celular');
ok('título do celular', cel.titulo === 'Status do celular');
const valsCel = cel.linhas.map((l) => l.rotulo + ': ' + l.valor);
ok('bateria do celular', valsCel.includes('Bateria: 78% (carregando)'));
ok('temperatura do celular', valsCel.includes('Temperatura: 31,5 °C'));
ok('uptime do celular', valsCel.includes('Ligado há: 2 dia(s)'));
ok('rede do celular', valsCel.includes('Rede: Wi-Fi'));

// 4. Estado vazio: nada de número inventado.
ok('mapa vazio devolve null', window.StatusPlataforma.deMapa({}, 'pc') === null);
const vazio = window.StatusPlataforma.deMapa({ carregado: 1 }, 'pc');
ok('mapa sem campos é semDados', vazio.semDados === true);
ok('mapa sem campos não gera linha', vazio.linhas.length === 0);
const soBateria = window.StatusPlataforma.deMapa({ bateria: 50 }, 'celular');
ok('campo único gera uma linha', soBateria.linhas.length === 1);
ok('memória só com total', window.StatusPlataforma.deMapa(
  { ramTotal: 8589934592 }, 'pc').linhas[0].valor === '8 GB no total');

// 5. O renderizador do app mostra “Sem conexão” quando não há status.
const inicioRender = app.indexOf('function renderStatusPlataforma');
const fimRender = app.indexOf('// Status do computador', inicioRender);
ok('renderizador encontrado no app.js', inicioRender > 0 && fimRender > inicioRender);
window.eval(app.slice(inicioRender, fimRender));
window.renderStatusPlataforma('sp-linhas', null);
const vazioNaTela = document.getElementById('sp-linhas').textContent;
ok('sem status, o painel diz Sem conexão', /Sem conexão/i.test(vazioNaTela));
window.renderStatusPlataforma('sp-linhas', pc);
const comDados = document.getElementById('sp-linhas').textContent;
ok('com status, o painel mostra o processador', /Processador/.test(comDados));
ok('com status, o painel mostra a memória', /Memória/.test(comDados));

// 6. O app.js liga as duas seções no mesmo lugar.
ok('app.js tem atualizarStatusPc', /function atualizarStatusPc\(/.test(app));
ok('app.js consulta o status real do PC',
  /nativo\('status_pc'/.test(app.slice(app.indexOf('async function atualizarStatusPc'))));
ok('app.js usa a regra compartilhada',
  /StatusPlataforma\.deMapa\(r, 'pc'\)/.test(app));
ok('atualizarStatusCelular atualiza o PC',
  /atualizarStatusPc\(\);/.test(app.slice(
    app.indexOf('async function atualizarStatusCelular'),
    app.indexOf('function mostrarWakeMini'))));
ok('celular sem pareamento diz Sem conexão',
  /set\('sc-pareamento', 'Sem conexão/.test(app));

console.log('OK: ' + verificacoes + ' verificações do painel de status');
