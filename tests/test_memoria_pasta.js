// Cofre em pasta no PC (1.105.0): leitura e gravação de Markdown de verdade.
//
// Exercita `platforms/desktop/memoria_pasta.js` numa pasta temporária, com um
// seletor de pastas simulado: escolher, listar, recusar caminho que sai da
// pasta, gravar subpasta, sincronizar nos dois sentidos e preservar conflito.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const PASTA = require(path.join(__dirname, '..', 'platforms', 'desktop', 'memoria_pasta.js'));
const MEM = require(path.join(__dirname, '..', 'memoria_regras.js'));

const raiz = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-pasta-'));
const cofrePasta = path.join(raiz, 'Obsidian');
const dados = path.join(raiz, 'dados');
fs.mkdirSync(cofrePasta, { recursive: true });

let escolhida = null;
const dialogo = {
  showOpenDialog: async () => {
    if (escolhida === null) return { canceled: true, filePaths: [] };
    return { canceled: false, filePaths: [escolhida] };
  }
};
const cofre = PASTA.criarCofre({ dirDados: dados, dialogo: dialogo });

function nota(titulo, texto, extra) {
  return Object.assign({
    id: 'n-' + titulo.toLowerCase().replace(/\s+/g, '-'),
    titulo: titulo,
    texto: texto,
    tema: 'projetos',
    tags: ['teste'],
    importancia: 1,
    criado: Date.now(),
    atualizado: Date.now(),
    usos: 0
  }, extra || {});
}

(async () => {
  // 1. Sem pasta escolhida: recusa honesta, sem inventar sucesso.
  const vazio = cofre.listarNotas();
  assert.equal(vazio.ok, false, 'listou sem pasta escolhida');
  assert.ok(/pasta/i.test(vazio.erro), vazio.erro);
  assert.equal(cofre.pastaAtual().pasta, null, 'pasta apareceu sem escolha');

  // 2. Cancelar o seletor não grava pasta.
  const cancelado = await cofre.escolher();
  assert.equal(cancelado.ok, true);
  assert.equal(cancelado.cancelado, true);
  assert.equal(cofre.pastaAtual().pasta, null, 'cancelar virou pasta conectada');

  // 3. Escolher a pasta grava a lembrança em userData.
  escolhida = cofrePasta;
  const escolha = await cofre.escolher();
  assert.equal(escolha.ok, true);
  assert.equal(escolha.pasta.caminho, cofrePasta);
  assert.ok(fs.existsSync(path.join(dados, 'memoria-pasta.json')), 'pasta não foi lembrada');

  // 4. Gravação cria subpasta e o arquivo, no formato do celular.
  const escrito = cofre.escreverNota('Memoria/Motor.md', MEM.escreverMarkdown(nota('Motor', 'ligação em estrela-triângulo', { id: 'n123' })));
  assert.equal(escrito.ok, true, escrito.erro);
  const salvo = fs.readFileSync(path.join(cofrePasta, 'Memoria', 'Motor.md'), 'utf8');
  assert.ok(salvo.indexOf('---\nid: n123\ntitulo: Motor\ntema: projetos\n') === 0, 'frontmatter fora do formato: ' + salvo);

  // 5. Caminho que sai da pasta, arquivo que não é .md e caminho absoluto são recusados.
  assert.equal(cofre.escreverNota('../fora.md', 'x').ok, false, 'aceitou caminho com ..');
  assert.equal(cofre.escreverNota('/etc/passwd.md', 'x').ok, false, 'aceitou caminho absoluto');
  assert.equal(cofre.escreverNota('nota.txt', 'x').ok, false, 'aceitou arquivo que não é .md');
  assert.ok(!fs.existsSync(path.join(raiz, 'fora.md')), 'gravou fora da pasta');

  // 6. Leitura recursiva: acha .md, ignora o resto e respeita a pasta escolhida.
  fs.writeFileSync(path.join(cofrePasta, 'solto.txt'), 'não é nota');
  fs.mkdirSync(path.join(cofrePasta, 'Oficina'), { recursive: true });
  fs.writeFileSync(path.join(cofrePasta, 'Oficina', 'Bancada.md'), 'texto da bancada');
  const leitura = cofre.listarNotas();
  assert.equal(leitura.ok, true, leitura.erro);
  const caminhos = leitura.notas.map((n) => n.caminho).sort();
  assert.deepEqual(caminhos, ['Memoria/Motor.md', 'Oficina/Bancada.md'], 'leitura não encontrou os arquivos certos');
  assert.ok(leitura.ignoradas >= 1, 'arquivo que não é .md não foi contado como ignorado');

  // 7. Sincronização: nota local nova vira arquivo; arquivo novo vira nota.
  const localNova = nota('Portão', 'motor de 1/4 de CV no portão');
  const primeira = cofre.sincronizar([localNova]);
  assert.equal(primeira.ok, true, primeira.erro);
  assert.ok(fs.existsSync(path.join(cofrePasta, 'portao.md')), 'nota local não virou arquivo');
  assert.ok(primeira.recebidas.indexOf('Oficina/Bancada.md') >= 0, 'arquivo novo não foi recebido');
  const recebida = primeira.notas.filter((n) => n.caminho === 'Oficina/Bancada.md')[0];
  assert.ok(recebida, 'nota recebida fora da lista final');
  assert.equal(recebida.titulo, 'Bancada', 'título não veio do arquivo');
  assert.ok(recebida.hashSincronizado, 'hash não gravado na nota recebida');
  const portao = primeira.notas.filter((n) => n.id === localNova.id)[0];
  assert.equal(portao.caminho, 'portao.md', 'caminho não voltou para a nota local');
  assert.equal(portao.hashSincronizado, MEM.hashConteudo('motor de 1/4 de CV no portão'));

  // 8. Segunda sincronização sem mudanças não escreve nada.
  const segunda = cofre.sincronizar(primeira.notas);
  assert.equal(segunda.enviadas.length, 0, 'reenviou arquivo sem mudança');
  assert.equal(segunda.recebidas.length, 0, 'reimportou arquivo sem mudança');
  assert.ok(segunda.iguais >= 2, 'iguais não foram contados: ' + segunda.resumo);

  // 9. Mudança na pasta é recebida na terceira sincronização.
  fs.writeFileSync(path.join(cofrePasta, 'portao.md'), MEM.escreverMarkdown(nota('Portão', 'motor de 1/2 de CV, trocado', { id: localNova.id })));
  const terceira = cofre.sincronizar(segunda.notas);
  assert.equal(terceira.recebidas.length, 1, 'mudança na pasta não foi recebida: ' + terceira.resumo);
  const atualizada = terceira.notas.filter((n) => n.id === localNova.id)[0];
  assert.equal(atualizada.texto, 'motor de 1/2 de CV, trocado');

  // 10. Conflito: as duas mudaram e nada é sobrescrito.
  const localMudou = terceira.notas.map((n) => n.id === localNova.id
    ? Object.assign({}, n, { texto: 'motor de 1/3 de CV, versão do PC' }) : n);
  fs.writeFileSync(path.join(cofrePasta, 'portao.md'), MEM.escreverMarkdown(nota('Portão', 'motor de 3/4 de CV, versão do Obsidian', { id: localNova.id })));
  const quarta = cofre.sincronizar(localMudou);
  assert.ok(quarta.conflitos.length >= 1, 'conflito não foi sinalizado: ' + quarta.resumo);
  const agoraLocal = quarta.notas.filter((n) => n.id === localNova.id)[0];
  assert.equal(agoraLocal.texto, 'motor de 1/3 de CV, versão do PC', 'conflito sobrescreveu a versão do PC');
  const noDisco = fs.readFileSync(path.join(cofrePasta, 'portao.md'), 'utf8');
  assert.ok(/3\/4 de CV, versão do Obsidian/.test(noDisco), 'conflito sobrescreveu a versão da pasta');

  // 11. Desconectar não apaga nada na pasta.
  const antes = fs.readdirSync(cofrePasta).sort();
  assert.equal(cofre.esquecer().ok, true);
  assert.equal(cofre.pastaAtual().pasta, null, 'pasta continuou conectada depois de esquecer');
  assert.deepEqual(fs.readdirSync(cofrePasta).sort(), antes, 'desconectar mexeu nos arquivos');

  console.log('memoria_pasta: escolher, gravar, ler, sincronizar e preservar conflito — OK');
})()
  .catch((erro) => {
    console.error(erro);
    process.exitCode = 1;
  })
  .finally(() => {
    fs.rmSync(raiz, { recursive: true, force: true });
  });
