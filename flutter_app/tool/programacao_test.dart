import 'dart:io';

import 'package:jarvis_nova/core/programacao.dart';

void main() {
  // 1. As cinco tarefas existem, com rótulo e regra próprios.
  assert(TarefaCodigo.values.length == 5, 'tarefas demais ou de menos');
  final rotulos = TarefaCodigo.values.map((t) => t.rotulo).toList();
  assert(rotulos.toSet().length == rotulos.length, 'rótulo de tarefa repetido');
  assert(TarefaCodigo.criar.exigePedido && !TarefaCodigo.criar.usaCodigo,
      'criar exige pedido e não exige código');
  assert(TarefaCodigo.analisar.usaCodigo && !TarefaCodigo.analisar.exigePedido,
      'analisar exige código e não exige pedido');
  assert(TarefaCodigo.modificar.usaCodigo && TarefaCodigo.modificar.exigePedido,
      'modificar precisa do código e do que mudar');
  assert(TarefaCodigo.explicarErro.usaCodigo && TarefaCodigo.explicarErro.usaErro,
      'explicar erro precisa do código e da mensagem');
  assert(TarefaCodigo.prompt.geraPrompt && !TarefaCodigo.prompt.usaCodigo,
      'o prompt é montado sem código');

  // 2. Linguagens: id único, extensão e etiqueta de cerca.
  assert(linguagensCodigo.length >= 16, 'lista de linguagens curta demais');
  final ids = linguagensCodigo.map((l) => l.id).toList();
  assert(ids.toSet().length == ids.length, 'id de linguagem repetido');
  for (final linguagem in linguagensCodigo) {
    assert(linguagem.nome.isNotEmpty, 'linguagem ${linguagem.id} sem nome');
    assert(linguagem.extensao.isNotEmpty,
        'linguagem ${linguagem.id} sem extensão');
  }
  assert(linguagemDe('python').nome == 'Python', 'linguagemDe errou');
  assert(linguagemDe('inventada').id == 'outro',
      'linguagem desconhecida não caiu em “outro”');

  // 3. Validação: cada tarefa recusa o que falta, com motivo em português.
  final criarVazio = PedidoCodigo(
      tarefa: TarefaCodigo.criar, linguagem: linguagemDe('dart'));
  assert(validarPedidoCodigo(criarVazio) != null, 'criar sem pedido passou');
  final criarOk = PedidoCodigo(
      tarefa: TarefaCodigo.criar,
      linguagem: linguagemDe('dart'),
      pedido: 'um contador de linhas');
  assert(validarPedidoCodigo(criarOk) == null, 'criar com pedido foi recusado');
  final analisarSemCodigo = PedidoCodigo(
      tarefa: TarefaCodigo.analisar, linguagem: linguagemDe('python'));
  assert(validarPedidoCodigo(analisarSemCodigo) != null,
      'analisar sem código passou');
  final analisarOk = PedidoCodigo(
      tarefa: TarefaCodigo.analisar,
      linguagem: linguagemDe('python'),
      codigo: 'print(1)');
  assert(validarPedidoCodigo(analisarOk) == null,
      'analisar com código foi recusado');
  final erroSemMensagem = PedidoCodigo(
      tarefa: TarefaCodigo.explicarErro,
      linguagem: linguagemDe('python'),
      codigo: 'print(1)');
  assert(validarPedidoCodigo(erroSemMensagem) != null,
      'explicar erro sem mensagem passou');
  final erroOk = PedidoCodigo(
      tarefa: TarefaCodigo.explicarErro,
      linguagem: linguagemDe('python'),
      codigo: 'print(1)',
      erro: 'NameError: name x is not defined');
  assert(validarPedidoCodigo(erroOk) == null,
      'explicar erro completo foi recusado');
  final grande = PedidoCodigo(
      tarefa: TarefaCodigo.analisar,
      linguagem: linguagemDe('python'),
      codigo: 'x' * (limiteCodigoCaracteres + 1));
  assert(validarPedidoCodigo(grande)!.contains('$limiteCodigoCaracteres'),
      'pedido acima do limite não diz o limite');
  final promptVazio = PedidoCodigo(
      tarefa: TarefaCodigo.prompt, linguagem: linguagemDe('dart'));
  assert(validarPedidoCodigo(promptVazio) != null,
      'prompt sem objetivo passou');
  final promptOk = PedidoCodigo(
      tarefa: TarefaCodigo.prompt,
      linguagem: linguagemDe('dart'),
      pedido: 'salvar notas em Markdown');
  assert(validarPedidoCodigo(promptOk) == null, 'prompt com objetivo recusado');

  // 4. O pedido ao provedor carrega a instrução, o código e o erro.
  final mensagens = mensagensDeCodigo(PedidoCodigo(
    tarefa: TarefaCodigo.explicarErro,
    linguagem: linguagemDe('python'),
    codigo: 'print(1)',
    erro: 'NameError',
  ));
  assert(mensagens.length == 2, 'esperava sistema + usuário');
  assert(mensagens.first['role'] == 'system', 'primeira mensagem não é sistema');
  final sistema = mensagens.first['content']!;
  assert(sistema.contains('JARVIS'), 'instrução sem o papel do JARVIS');
  assert(sistema.contains('terminal'), 'instrução não declara a falta de terminal');
  assert(sistema.contains('não'), 'instrução sem a recusa de execução');
  final usuario = mensagens.last['content']!;
  assert(usuario.contains('```python'), 'código sem cerca de linguagem: $usuario');
  assert(usuario.contains('print(1)'), 'código não foi enviado');
  assert(usuario.contains('NameError'), 'mensagem de erro não foi enviada');
  assert(usuario.contains('Linguagem: Python'), 'linguagem não foi dita');
  assert(!mensagensDeCodigo(promptOk).last['content']!.contains('```'),
      'pedido sem código não deveria levar cerca');
  final comPersonalidade = mensagensDeCodigo(criarOk, personalidade: 'Fale curto.');
  assert(comPersonalidade.first['content']!.startsWith('Fale curto.'),
      'personalidade não entrou na instrução');

  // 5. Extração de blocos: dois blocos, cerca sem linguagem e bloco cortado.
  const resposta = 'Explico assim:\n\n```dart\nvoid main() {}\n```\n\n'
      'E o teste:\n\n```\nmain();\n```\n';
  final blocos = extrairBlocos(resposta);
  assert(blocos.length == 2, 'esperava 2 blocos, achei ${blocos.length}');
  assert(blocos.first.linguagem == 'dart', 'linguagem do primeiro bloco errada');
  assert(blocos.first.codigo == 'void main() {}', 'código do primeiro bloco');
  assert(blocos.last.linguagem.isEmpty, 'cerca sem linguagem virou linguagem');
  assert(blocos.last.linhas == 1, 'contagem de linhas errada');
  final cortada = extrairBlocos('Segue:\n```python\nprint("oi")\n');
  assert(cortada.length == 1, 'bloco sem fechamento não foi extraído');
  assert(cortada.first.codigo.contains('print'), 'bloco cortado perdeu o código');
  assert(extrairBlocos('sem código aqui').isEmpty, 'inventou bloco sem cerca');

  // 6. Explicação e área de código.
  final explicacao = explicacaoSemCodigo(resposta);
  assert(!explicacao.contains('void main'), 'a explicação reteve o código');
  assert(explicacao.contains('Explico assim'), 'a explicação perdeu o texto');
  assert(codigoParaArea(resposta) == 'void main() {}',
      'a área de código não recebeu o primeiro bloco');
  assert(codigoParaArea('texto puro') == 'texto puro',
      'sem bloco, a área deve receber a resposta');

  // 7. Nome do arquivo na pasta isolada, sem sobrescrever.
  assert(nomeArquivoDeCodigo(linguagemDe('python')) == 'codigo_python',
      'nome base errado');
  assert(
      nomeArquivoDeCodigo(linguagemDe('python'),
          existentes: ['codigo_python.txt']) ==
      'codigo_python_2',
      'colisão não gerou sufixo');
  assert(
      nomeArquivoDeCodigo(linguagemDe('python'),
          existentes: ['codigo_python.txt', 'codigo_python_2.txt']) ==
      'codigo_python_3',
      'segunda colisão não gerou sufixo');

  // 8. O prompt local: linguagem, objetivo, restrição e formato.
  final prompt = promptDeCodigo(linguagemDe('kotlin'), 'ler sensores',
      restricoes: 'sem biblioteca externa');
  for (final termo in [
    'Kotlin',
    'ler sensores',
    'sem biblioteca externa',
    'três crases',
    'não diga que executou',
  ]) {
    assert(prompt.contains(termo), 'prompt sem “$termo”');
  }
  final generico = promptDeCodigo(linguagemDe('outro'), 'somar dois números');
  assert(generico.contains('linguagem adequada'),
      'prompt sem linguagem não pediu a adequada');

  // 9. Os limites dizem o que não existe.
  final limites = limitesProgramacao.join(' ').toLowerCase();
  for (final termo in ['sandbox', 'terminal', 'provedor', 'chave', 'txt']) {
    assert(limites.contains(termo), 'limite ausente: $termo');
  }

  stdout.writeln('OK: ${TarefaCodigo.values.length} tarefas, '
      '${linguagensCodigo.length} linguagens, validação, blocos, prompt e '
      '${limitesProgramacao.length} limites conferidos');
}
