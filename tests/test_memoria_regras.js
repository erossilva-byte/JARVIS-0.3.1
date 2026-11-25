// Regras da memória no PC (1.105.0): o mesmo teste de regra do celular, em JS.
//
// Portado de `flutter_app/tool/memoria_sync_test.dart` e da parte de busca e
// orçamento de `core/memoria_busca.dart`: aqui ficam travados busca com motivo,
// orçamento de contexto, citação e o plano de sincronização que nunca apaga nada.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const MEM = require(path.join(__dirname, '..', 'memoria_regras.js'));

let t = 0;
function em(dias) { return Date.UTC(2026, 10, 1) + dias * 86400000; }
function nota(titulo, texto, extra) {
  return Object.assign({
    id: titulo.toLowerCase().replace(/\s+/g, '-'),
    titulo: titulo,
    texto: texto,
    tema: 'contextos',
    tags: [],
    importancia: 1,
    criadaEm: em(0),
    atualizadaEm: em(0),
    usos: 0
  }, extra || {});
}
function local(titulo, texto, extra) {
  return nota(titulo, texto, Object.assign({ id: 'local-' + titulo.toLowerCase().replace(/\s+/g, '-') }, extra || {}));
}
function remoto(caminho, conteudo) { return { caminho: caminho, conteudo: conteudo }; }

/* ---------- 1. Busca: termo no título vence, com motivo explícito ---------- */
{
  const notas = [
    nota('Café da manhã', 'prefiro café coado sem açúcar', { tema: 'gostos', tags: ['cafe'] }),
    nota('Força de atuação', 'atuador de 12 V no portão da garagem', { tema: 'projetos' }),
    nota('Viagem', 'passagens para o litoral em janeiro', { tema: 'contextos' })
  ];
  const achados = MEM.buscarNotas(notas, 'café', { agora: em(1) });
  assert.ok(achados.length >= 1, 'busca não encontrou nada');
  assert.equal(achados[0].nota.titulo, 'Café da manhã', 'nota certa não veio primeiro');
  assert.ok(/título/.test(achados[0].motivo), 'motivo sem o título: ' + achados[0].motivo);
  assert.ok(achados[0].pontuacao > 0 && achados[0].pontuacao <= 1, 'pontuação fora do intervalo');

  // Consulta sem termo devolve a lista, sem inventar relevância.
  const semConsulta = MEM.buscarNotas(notas, 'de a o', { agora: em(1) });
  assert.equal(semConsulta.length, 3, 'consulta vazia deveria listar as notas');
  assert.equal(semConsulta[0].motivo, 'lista, sem consulta', 'motivo da lista mudou');
}

/* ---------- 2. Busca não despeja nota sem relação (colisão de hash) ---------- */
{
  const notas = [
    nota('Portão', 'o motor do portão é de 1/4 de CV', { tema: 'projetos' }),
    nota('Receita', 'bolo de cenoura com cobertura de chocolate', { tema: 'gostos' })
  ];
  const achados = MEM.buscarNotas(notas, 'portão', { agora: em(1) });
  assert.equal(achados.length, 1, 'busca trouxe nota sem relação: ' + achados.map((a) => a.nota.titulo));
  assert.equal(achados[0].nota.titulo, 'Portão');
}

/* ---------- 3. Sinônimo fechado encontra a nota ---------- */
{
  const notas = [nota('Projeto do app', 'o programa do projeto Atlas', { tema: 'projetos' })];
  const achados = MEM.buscarNotas(notas, 'aplicativo', { agora: em(1) });
  assert.equal(achados.length, 1, 'sinônimo fechado não encontrou a nota');
}

/* ---------- 4. Orçamento: corta por caracteres e diz o que foi usado ---------- */
{
  const notas = [
    nota('Projeto Atlas', 'x'.repeat(900), { tema: 'projetos', atualizadaEm: em(1) }),
    nota('Projeto Atlas 2', 'y'.repeat(900), { tema: 'projetos', atualizadaEm: em(0) })
  ];
  const curto = MEM.contextoRelevante(notas, 'projeto atlas', { orcamento: 400, limite: 3, agora: em(2) });
  assert.ok(curto.texto.length <= 400, 'orçamento estourado: ' + curto.texto.length);
  assert.equal(curto.caracteres, curto.texto.length, 'contagem de caracteres errada');
  assert.ok(curto.usados.length >= 1, 'nenhuma nota usada');
  assert.ok(curto.texto.indexOf('Projeto Atlas') >= 0, 'título não entrou no bloco');

  // Pergunta sem relação: contexto vazio, e não o cofre inteiro.
  const semRelacao = MEM.contextoRelevante(notas, 'qual a capital da França?', { orcamento: 1600, agora: em(2) });
  assert.equal(semRelacao.texto, '', 'mandou nota sem relação para o prompt');
  assert.equal(semRelacao.usados.length, 0);

  // Sem consulta não há contexto.
  assert.equal(MEM.contextoRelevante(notas, '   ', { agora: em(2) }).texto, '');
}

/* ---------- 5. Citação: título + tema + caminho, sem inventar ---------- */
{
  const usada = nota('Motor do portão', 'ligação em estrela-triângulo', { tema: 'projetos', caminho: 'Memoria/Motor.md' });
  const lista = MEM.citacoes([usada]);
  assert.equal(lista.length, 1);
  assert.equal(lista[0].referencia, 'Motor do portão — Projetos', 'referência errada');
  const linha = MEM.linhaCitacoes([usada]);
  assert.ok(linha.indexOf('Fonte: Motor do portão — Projetos') === 0, linha);
  assert.ok(linha.indexOf('Memoria/Motor.md') > 0, 'caminho da nota não citado');
  assert.equal(MEM.linhaCitacoes([]), '', 'citação vazia deveria ser vazia');
}

/* ---------- 6. Markdown no formato do celular: ida e volta ---------- */
{
  const original = nota('Café', 'prefiro café sem açúcar', {
    id: 'n123', tema: 'gostos', tags: ['cafe', 'manha'], importancia: 2,
    criadaEm: em(0), atualizadaEm: em(3)
  });
  const md = MEM.escreverMarkdown(original);
  assert.ok(md.indexOf('---\nid: n123\ntitulo: Café\ntema: gostos\n') === 0, 'frontmatter fora do formato do celular:\n' + md);
  assert.ok(md.indexOf('tags: [cafe, manha]') > 0, 'tags não gravadas');
  assert.ok(md.indexOf('importancia: 2') > 0, 'importância não gravada');
  assert.ok(md.indexOf('criada: 2026-11-01T00:00:00.000Z') > 0, 'data de criação não gravada');
  assert.ok(md.indexOf('atualizada: 2026-11-04T00:00:00.000Z') > 0, 'data de atualização não gravada');
  assert.ok(md.endsWith('\n\nprefiro café sem açúcar\n'), 'corpo do Markdown errado');

  const lido = MEM.lerMarkdown(md);
  assert.equal(lido.titulo, 'Café');
  assert.equal(lido.texto, 'prefiro café sem açúcar');
  assert.equal(lido.extras.tema, 'gostos');
  assert.equal(lido.extras.id, 'n123');

  // `---` no corpo não pode cortar o texto.
  const comSeparador = MEM.lerMarkdown('---\ntitulo: Com separador\ntema: gostos\n---\n\nantes\n\n---\n\ndepois\n');
  assert.ok(/antes/.test(comSeparador.texto) && /depois/.test(comSeparador.texto), 'separador cortou a nota');
  // Sem frontmatter, o título vem do cabeçalho ou do nome do arquivo.
  assert.equal(MEM.lerMarkdown('# Nota solta\n\ntexto', { tituloReserva: 'Arquivo' }).titulo, 'Nota solta');
  assert.equal(MEM.lerMarkdown('texto puro', { tituloReserva: 'Arquivo' }).titulo, 'Arquivo');
}

/* ---------- 7. Hash estável e sensível ---------- */
{
  assert.equal(MEM.hashConteudo('abc'), MEM.hashConteudo('abc'));
  assert.notEqual(MEM.hashConteudo('abc'), MEM.hashConteudo('abd'));
  assert.ok(MEM.hashConteudo('').length === 16, 'hash vazio deveria ter 16 caracteres');
}

/* ---------- 8. Plano de sincronização (os 13 casos do celular) ---------- */
{
  const quando = { agora: em(14) };

  // 1. Só na pasta: vira nota local, com caminho e hash.
  const importado = MEM.planejarSincronizacao([], [remoto('Oficina/Motor.md', 'Ligação em estrela-triângulo.')], quando);
  assert.equal(importado.recebidas.length, 1, 'arquivo novo da pasta não importado');
  assert.equal(importado.recebidas[0].nota.titulo, 'Motor', 'título não veio do arquivo');
  assert.equal(importado.recebidas[0].caminho, 'Oficina/Motor.md', 'caminho errado');
  assert.equal(importado.recebidas[0].nota.hashSincronizado, MEM.hashConteudo('Ligação em estrela-triângulo.'), 'hash não gravado');

  // 2. Só no local: vira arquivo novo com nome seguro.
  const enviado = MEM.planejarSincronizacao([local('Bancada de testes', 'Texto local.')], [], quando);
  assert.equal(enviado.envios.length, 1, 'nota local nova não enviada');
  assert.equal(enviado.envios[0].caminho, 'bancada-de-testes.md', 'nome de arquivo errado');
  assert.equal(enviado.envios[0].novo, true, 'deveria ser arquivo novo');
  assert.ok(enviado.envios[0].conteudo.indexOf('titulo: Bancada de testes') > 0, 'Markdown sem frontmatter');

  // 3. Iguais dos dois lados: nada a fazer.
  const iguais = MEM.planejarSincronizacao(
    [local('Motor', 'mesmo texto', { caminho: 'Motor.md', hashSincronizado: MEM.hashConteudo('mesmo texto') })],
    [remoto('Motor.md', 'mesmo texto')], quando
  );
  assert.equal(iguais.envios.length + iguais.recebidas.length + iguais.marcar.length + iguais.conflitos.length, 0, 'plano não deveria ter ação');
  assert.equal(iguais.iguais, 1, 'igual não contado');

  // 4. Local novo com mesmo conteúdo de arquivo existente: só adota caminho.
  const adota = MEM.planejarSincronizacao([local('Motor', 'mesmo texto')], [remoto('Motor.md', 'mesmo texto')], quando);
  assert.equal(adota.envios.length + adota.recebidas.length, 0, 'conteúdo igual gerou escrita');
  assert.equal(adota.marcar.length, 1, 'caminho não foi adotado');

  // 5. Local mudou, pasta continua na versão sincronizada: envia.
  const localMudou = MEM.planejarSincronizacao(
    [local('Motor', 'texto novo', { caminho: 'Motor.md', hashSincronizado: MEM.hashConteudo('texto antigo') })],
    [remoto('Motor.md', 'texto antigo')], quando
  );
  assert.equal(localMudou.envios.length, 1, 'alteração local não enviada');
  assert.equal(localMudou.envios[0].caminho, 'Motor.md');
  assert.equal(localMudou.conflitos.length, 0, 'alteração local virou conflito');

  // 6. Pasta mudou, local continua na versão sincronizada: recebe.
  const recebeu = MEM.planejarSincronizacao(
    [local('Motor', 'texto antigo', { caminho: 'Motor.md', hashSincronizado: MEM.hashConteudo('texto antigo') })],
    [remoto('Motor.md', 'texto novo do Obsidian')], quando
  );
  assert.equal(recebeu.recebidas.length, 1, 'alteração remota não recebida');
  assert.equal(recebeu.recebidas[0].nota.texto, 'texto novo do Obsidian');
  assert.equal(recebeu.envios.length, 0, 'receber não deveria enviar');
  assert.equal(recebeu.recebidas[0].nota.hashSincronizado, MEM.hashConteudo('texto novo do Obsidian'));

  // 7. Os dois mudaram: conflito, nada é sobrescrito.
  const conflito = MEM.planejarSincronizacao(
    [local('Motor', 'local novo', { caminho: 'Motor.md', hashSincronizado: MEM.hashConteudo('base') })],
    [remoto('Motor.md', 'remoto novo')], quando
  );
  assert.equal(conflito.envios.length + conflito.recebidas.length, 0, 'conflito não pode escrever');
  assert.equal(conflito.conflitos.length, 1, 'conflito não sinalizado');
  assert.equal(conflito.conflitos[0].local.texto, 'local novo', 'conflito sem a cópia local');

  // 8. Nunca sincronizada e diferente: conflito, não sobrescreve.
  const semBase = MEM.planejarSincronizacao(
    [local('Motor', 'local', { caminho: 'Motor.md' })], [remoto('Motor.md', 'remoto')], quando
  );
  assert.equal(semBase.conflitos.length, 1, 'diferença sem base deveria ser conflito');
  assert.equal(semBase.envios.length, 0, 'não pode enviar por cima de arquivo não sincronizado');

  // 9. Arquivo sumiu da pasta: nota fica, registrada como ausente.
  const sumiu = MEM.planejarSincronizacao(
    [local('Motor', 'texto', { caminho: 'Motor.md', hashSincronizado: MEM.hashConteudo('texto') })], [], quando
  );
  assert.equal(sumiu.ausentesNaPasta.length, 1, 'ausência não registrada');
  assert.equal(sumiu.envios.length, 0, 'ausência não pode recriar nem apagar');

  // 10. Mesmo título em caminhos diferentes: conflito em vez de duplicar.
  const mesmoTitulo = MEM.planejarSincronizacao(
    [local('Motor', 'texto local')], [remoto('Outra pasta/Motor.md', 'texto remoto')], quando
  );
  assert.equal(mesmoTitulo.recebidas.length, 0, 'duplicou nota de mesmo título');
  assert.equal(mesmoTitulo.conflitos.length, 1, 'mesmo título deveria ser conflito');

  // 11. Caminho duplicado na leitura: usa um e reporta.
  const duplicado = MEM.planejarSincronizacao([], [remoto('A.md', 'um'), remoto('A.md', 'dois')], quando);
  assert.equal(duplicado.caminhosDuplicados[0], 'A.md', 'duplicata não reportada');
  assert.equal(duplicado.recebidas.length, 1, 'duplicata foi importada duas vezes');

  // 12. Caixa do nome do arquivo: `motor.md` encontra `Motor.md` sem duplicar.
  const caixa = MEM.planejarSincronizacao([local('Motor', 'mesmo texto')], [remoto('Motor.md', 'mesmo texto')], quando);
  assert.equal(caixa.marcar.length + caixa.envios.length + caixa.recebidas.length, 1, 'nome em caixa diferente não encontrou o arquivo');

  // 13. Frontmatter diferente, corpo igual: nada a escrever.
  const comFrontmatter = MEM.planejarSincronizacao(
    [local('Motor', 'corpo', { caminho: 'Motor.md', hashSincronizado: MEM.hashConteudo('corpo') })],
    [remoto('Motor.md', '---\ntitulo: Motor\natualizada: 2030-01-01\n---\ncorpo')], quando
  );
  assert.equal(comFrontmatter.envios.length + comFrontmatter.recebidas.length, 0, 'frontmatter diferente gerou escrita');
}

/* ---------- 9. Leitura da pasta: um arquivo por nota, mantendo o tema ---------- */
{
  const lido = MEM.lerMarkdown('---\nid: x1\ntitulo: Portão\ntema: projetos\ntags: [casa, motor]\nimportancia: 3\n---\n\nmotor de 1/4');
  assert.equal(lido.extras.importancia, '3');
  assert.equal(MEM.nomeSemExtensao('Oficina/Motor.md'), 'Motor');
  assert.equal(MEM.caminhoParaTitulo('Bancada de testes'), 'bancada-de-testes.md');
  assert.equal(MEM.caminhoParaTitulo('!!!'), 'nota.md', 'título vazio deveria virar nota.md');
  const importado = MEM.importarMarkdowns(
    [{ nome: 'Motor.md', conteudo: '---\ntitulo: Motor\ntema: projetos\n---\n\nligação' }],
    [], { agora: em(5) }
  );
  assert.equal(importado.adicionadas.length, 1, 'importação simples falhou');
  assert.equal(importado.adicionadas[0].tema, 'projetos', 'tema perdido na importação');
  assert.equal(importado.adicionadas[0].texto, 'ligação', 'corpo perdido na importação');
}

console.log('memoria_regras: busca, orçamento, citação, Markdown e sincronização — OK');
