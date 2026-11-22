import 'dart:io';

import 'package:jarvis_nova/core/conversa.dart';
import 'package:jarvis_nova/core/memoria_busca.dart';
import 'package:jarvis_nova/core/pessoas.dart';

Pessoa pessoa(
  String nome, {
  String apelido = '',
  String relacao = '',
  String contatos = '',
  String preferencias = '',
  String observacoes = '',
  String compromissos = '',
  String historico = '',
}) =>
    Pessoa(
      id: nome.toLowerCase(),
      nome: nome,
      apelido: apelido,
      relacao: relacao,
      contatos: contatos,
      preferencias: preferencias,
      observacoes: observacoes,
      compromissos: compromissos,
      historico: historico,
      consentimento: true,
      criadaEm: DateTime(2026, 11, 15),
      atualizadaEm: DateTime(2026, 11, 15),
    );

void main() {
  final ana = pessoa(
    'Ana',
    apelido: 'Aninha',
    relacao: 'irmã',
    contatos: '+55 11 99999-0000',
    preferencias: 'café sem açúcar',
    observacoes: 'segredo de família',
    compromissos: 'consulta dia 20',
    historico: 'almoçamos em outubro',
  );
  final anaPaula = pessoa('Ana Paula', relacao: 'prima');
  final carlos = pessoa('Carlos', apelido: 'Cadu', relacao: 'colega');

  // 1. Pessoa citada: entra só o bloco seguro
  final bloco = blocoPessoasParaConsulta([ana, carlos], 'quem é a Ana?');
  assert(bloco.contains('Nome: Ana'), 'nome não foi enviado');
  assert(bloco.contains('Apelido: Aninha'), 'apelido não foi enviado');
  assert(bloco.contains('Relação: irmã') && bloco.contains('café sem açúcar'), 'dados autorizados ausentes');
  assert(!bloco.contains('99999'), 'telefone vazou para a conversa');
  assert(!bloco.contains('segredo'), 'observações vazaram para a conversa');
  assert(!bloco.contains('consulta dia 20'), 'compromisso vazou para a conversa');
  assert(!bloco.contains('almoçamos'), 'histórico vazou para a conversa');
  assert(bloco.contains('não invente'), 'sem instrução contra invenção');

  // 2. Nome desconhecido: manda dizer que não encontrou
  final desconhecida = blocoPessoasParaConsulta([ana, carlos], 'quem é a Maria?');
  assert(desconhecida.contains('nenhuma ficha'), 'não instruiu ausência');
  assert(desconhecida.contains('Diga que não encontrou'), 'não instruiu a dizer que não encontrou');
  assert(!desconhecida.contains('Ana'), 'misturou pessoa não citada');

  // 3. Ambiguidade: pergunta em vez de escolher
  final ambiguo = blocoPessoasParaConsulta([ana, anaPaula, carlos], 'quem é Ana?');
  assert(ambiguo.contains('mais de uma ficha'), 'ambiguidade não sinalizada');
  assert(ambiguo.contains('Ana') && ambiguo.contains('Ana Paula'), 'candidatos ausentes');
  assert(ambiguo.contains('Pergunte qual'), 'não pediu desambiguação');

  // 4. Nome completo vence o primeiro nome
  final completo = blocoPessoasParaConsulta([ana, anaPaula], 'o que você sabe sobre Ana Paula?');
  assert(completo.contains('Nome: Ana Paula'), 'nome completo não teve prioridade');
  assert(!completo.contains('Apelido: Aninha'), 'trouxe a Ana errada');

  // 5. Apelido resolve
  final apelido = blocoPessoasParaConsulta([ana, carlos], 'me fala do Cadu');
  assert(apelido.contains('Nome: Carlos'), 'apelido não resolveu');

  // 6. Conversa que não é sobre pessoa não recebe bloco
  assert(blocoPessoasParaConsulta([ana], 'qual a capital da França?') == '', 'bloco entrou sem motivo');

  // 7. Sem fichas e com pergunta de pessoa: ausência explícita
  final vazio = blocoPessoasParaConsulta([], 'quem é o João?');
  assert(vazio.contains('nenhuma ficha'), 'sem fichas não instruiu ausência');

  // 8. Montagem das mensagens: pessoas como mensagem de sistema, histórico intacto
  const historico = [
    {'role': 'user', 'content': 'quem é a Ana?'},
  ];
  final mensagens = montarMensagens(historico, const ContextoMemoria(texto: '', usados: [], caracteres: 0), pessoas: bloco);
  assert(mensagens.length == 2, 'mensagem de pessoas não entrou');
  assert(mensagens.first['role'] == 'system' && mensagens.first['content'] == bloco, 'bloco no lugar errado');
  assert(mensagens.last['content'] == 'quem é a Ana?', 'histórico alterado');

  // 9. Sem bloco, a montagem continua igual à anterior
  final semPessoas = montarMensagens(historico, const ContextoMemoria(texto: '', usados: [], caracteres: 0));
  assert(semPessoas.length == 1, 'montagem antiga mudou');

  // 10. Contexto estruturado: tipo e nomes acompanham o bloco
  final estruturado = contextoPessoasParaConsulta([ana, carlos], 'quem é a Ana?');
  assert(estruturado.tipo == TipoContextoPessoas.detalhe, 'tipo detalhe errado');
  assert(estruturado.nomes.length == 1 && estruturado.nomes.single == 'Ana', 'nome usado não registrado');
  final ambiguoStruct = contextoPessoasParaConsulta([ana, anaPaula], 'quem é Ana?');
  assert(ambiguoStruct.tipo == TipoContextoPessoas.ambiguo && ambiguoStruct.nomes.length == 2, 'ambiguidade não estruturada');
  final ausenteStruct = contextoPessoasParaConsulta([ana], 'quem é a Maria?');
  assert(ausenteStruct.tipo == TipoContextoPessoas.ausente && ausenteStruct.nomes.isEmpty, 'ausência não estruturada');
  final nenhumStruct = contextoPessoasParaConsulta([ana], 'qual a capital da França?');
  assert(nenhumStruct.tipo == TipoContextoPessoas.nenhum && nenhumStruct.vazio, 'contexto vazio deveria ser nenhum');

  // 11. A conversa guarda e devolve o bloco exato e as fichas citadas
  final conversa = Conversa(id: 'c1', titulo: 'Teste', criadaEm: DateTime(2026, 11, 15), atualizadaEm: DateTime(2026, 11, 15));
  conversa.adicionar(MensagemConversa(autor: 'user', texto: 'quem é a Ana?'));
  conversa.adicionar(MensagemConversa(
    autor: 'assistant',
    texto: 'A Ana é sua irmã.',
    fichas: estruturado.nomes,
    contextoPessoas: estruturado.bloco,
  ));
  final relida = Conversa.deJson(conversa.paraJson());
  assert(relida != null, 'conversa não voltou do JSON');
  final volta = relida!;
  assert(volta.mensagens.last.fichas.single == 'Ana', 'ficha não persistiu');
  assert(volta.mensagens.last.contextoPessoas == estruturado.bloco, 'bloco enviado não persistiu');
  final antiga = Conversa.deJson({
    'id': 'c2',
    'titulo': 'Antiga',
    'criadaEm': DateTime(2026, 11, 15).toIso8601String(),
    'mensagens': [
      {'autor': 'assistant', 'texto': 'sem contexto'},
    ],
  });
  assert(antiga!.mensagens.single.fichas.isEmpty && antiga.mensagens.single.contextoPessoas.isEmpty,
      'conversa antiga sem campos novos quebrou');

  stdout.writeln('OK: pessoas na conversa — bloco seguro, ausência explícita, ambiguidade e transparência');
}
