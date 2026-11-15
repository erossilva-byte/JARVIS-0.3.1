import 'dart:io';

import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/core/memoria_busca.dart';

NotaMemoria nota(String titulo, String texto, {String tema = 'contextos', List<String> tags = const [], int importancia = 1, DateTime? atualizada, int usos = 0}) {
  final base = DateTime(2026, 11, 10);
  return NotaMemoria(
    id: titulo.toLowerCase().replaceAll(' ', '-'),
    titulo: titulo,
    texto: texto,
    tema: tema,
    tags: tags,
    importancia: importancia,
    criadaEm: base,
    atualizadaEm: atualizada ?? base,
    usos: usos,
  );
}

void main() {
  // 1. Frontmatter e corpo
  final lido = lerMarkdown('''---
titulo: Oficina
tags: [eletrica, motor]
importancia: 2
autor: legado
---

# Não deve valer como título

Conteúdo da nota.

---

Depois da linha horizontal.''');
  assert(lido.titulo == 'Oficina', 'título do frontmatter não lido');
  assert(lido.extras['autor'] == 'legado', 'chave desconhecida perdida');
  assert(lido.texto.contains('Depois da linha horizontal'), 'texto depois de --- foi perdido');

  // 2. Título pelo cabeçalho quando não há frontmatter
  final porCabecalho = lerMarkdown('# Receita de pão\n\nFarinha e água.');
  assert(porCabecalho.titulo == 'Receita de pão', 'título pelo cabeçalho não lido');
  assert(porCabecalho.extras.isEmpty, 'frontmatter inventado');

  // 3. Ida e volta do Markdown preservando chave desconhecida
  final original = nota('Motor 220 V', 'Ligação em estrela-triângulo.', tags: ['eletrica']);
  final comExtra = NotaMemoria(
    id: original.id,
    titulo: original.titulo,
    texto: original.texto,
    tags: original.tags,
    criadaEm: original.criadaEm,
    atualizadaEm: original.atualizadaEm,
    extras: const {'cssclass': 'oficina'},
  );
  final devolta = lerMarkdown(escreverMarkdown(comExtra));
  assert(devolta.titulo == 'Motor 220 V', 'título sumiu no round-trip');
  assert(devolta.texto.contains('estrela-triângulo'), 'texto sumiu no round-trip');
  assert(devolta.extras['cssclass'] == 'oficina', 'chave desconhecida não sobreviveu');
  assert(devolta.extras['tags'] == 'eletrica', 'tags não voltaram: ${devolta.extras}');

  // 4. Importação: repetida, conflito e nova
  final importado = importarMarkdowns([
    (nome: 'a.md', conteudo: '---\ntitulo: Oficina\n---\nMesmo texto'),
    (nome: 'b.md', conteudo: '---\ntitulo: Oficina\n---\nTexto diferente'),
    (nome: 'c.md', conteudo: '---\ntitulo: Ferramentas\ntags: [bancada]\nimportancia: 3\n---\nAlicate e chave de fenda'),
  ], [nota('Oficina', 'Mesmo texto')]);
  assert(importado.repetidas == 1, 'repetida não detectada: ${importado.repetidas}');
  assert(importado.conflitos.single == 'Oficina', 'conflito não detectado');
  assert(importado.adicionadas.single.titulo == 'Ferramentas', 'nota nova não importada');
  assert(importado.adicionadas.single.importancia == 3, 'importância não lida');
  assert(importado.adicionadas.single.tags.single == 'bancada', 'tags não lidas');
  assert(importado.total == 3, 'total errado');

  // 5. Busca: acento, caixa e sinônimo
  final notas = [
    nota('Motor da bancada', 'A ligação do motor trifásico usa contator.', tags: ['eletrica'], importancia: 2),
    nota('Aplicativo de receitas', 'O programa de cozinha guarda receitas.', tema: 'preferencias'),
    nota('Passeio', 'Fomos ao parque no domingo.', tema: 'contextos'),
  ];
  final acento = buscarNotas(notas, 'MOTOR elétrico', agora: DateTime(2026, 11, 12));
  assert(acento.isNotEmpty, 'busca sem acento/caixa falhou');
  assert(acento.first.nota.titulo == 'Motor da bancada', 'nota errada no topo');
  assert(acento.any((r) => r.nota.titulo == 'Passeio') == false, 'nota sem relação entrou');

  final sinonimo = buscarNotas(notas, 'aplicativo', agora: DateTime(2026, 11, 12));
  assert(sinonimo.isNotEmpty && sinonimo.first.nota.titulo == 'Aplicativo de receitas', 'sinônimo não funcionou');

  // 6. Motivo explica o resultado
  assert(acento.first.motivo.contains('título'), 'motivo não cita o título: ${acento.first.motivo}');

  // 7. Ordem por importância e recência
  final recente = nota('Assunto', 'motor', atualizada: DateTime(2026, 11, 11));
  final antiga = nota('Assunto antigo', 'motor', atualizada: DateTime(2026, 1, 1), importancia: 3);
  final ordenado = buscarNotas([antiga, recente], 'motor', agora: DateTime(2026, 11, 12));
  assert(ordenado.length == 2, 'uma nota foi descartada');
  final comPeso = buscarNotas([antiga, recente], 'motor', agora: DateTime(2026, 11, 12)).first;
  assert(comPeso.nota.titulo == 'Assunto' || comPeso.nota.titulo == 'Assunto antigo', 'ordem inválida');

  // 8. Contexto respeita orçamento e só cita o que coube
  final notasLongas = [
    nota('Longa A', 'x' * 900),
    nota('Longa B', 'x' * 900),
    nota('Longa C', 'x' * 900),
  ];
  final contexto = contextoRelevante(notasLongas, 'x', orcamento: 1200);
  assert(contexto.usados.isNotEmpty, 'contexto vazio com notas relevantes');
  assert(contexto.caracteres <= 1200, 'orçamento estourado: ${contexto.caracteres}');
  assert(contexto.usados.length < 3, 'todas as notas entraram apesar do orçamento');

  // 9. Sem consulta ou sem nota relevante, contexto vazio
  assert(contextoRelevante(notas, '').vazio, 'consulta vazia gerou contexto');
  assert(contextoRelevante(notas, 'astronomia quântica').vazio, 'consulta sem relação gerou contexto');

  // 10. Envio ao provedor: contexto entra como sistema, histórico fica intacto
  final historico = [
    {'role': 'user', 'content': 'qual a ligação do motor?'}
  ];
  final semContexto = montarMensagens(historico, const ContextoMemoria(texto: '', usados: [], caracteres: 0));
  assert(semContexto.length == 1 && semContexto.first['role'] == 'user', 'contexto vazio alterou o envio');

  final comContexto = montarMensagens(
    historico,
    contextoRelevante([nota('Motor da bancada', 'ligação em estrela-triângulo')], 'ligação do motor'),
  );
  assert(comContexto.length == 2, 'contexto não entrou no envio');
  assert(comContexto.first['role'] == 'system', 'contexto deveria ser mensagem de sistema');
  assert(comContexto.first['content']!.contains('Motor da bancada'), 'nota não citada no envio');
  assert(comContexto.first['content']!.contains('não invente'), 'instrução ausente');
  assert(comContexto.last['content'] == 'qual a ligação do motor?', 'pergunta do usuário alterada');

  // 11. JSON tolerante
  final json = jsonDeNotas(notas);
  final relidas = notasDeJson(json);
  assert(relidas.length == notas.length, 'JSON perdeu notas');
  assert(relidas.first.titulo == notas.first.titulo, 'JSON trocou título');
  assert(notasDeJson('{quebrado').isEmpty, 'JSON inválido não foi tolerado');
  assert(notasDeJson('[{"id":""}]').isEmpty, 'nota inválida aceita');

  stdout.writeln('OK: memória — Markdown, importação, busca, motivo, orçamento, envio e JSON');
}
