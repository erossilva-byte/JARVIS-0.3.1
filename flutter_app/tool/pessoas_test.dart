import 'dart:io';

import 'package:jarvis_nova/core/pessoas.dart';

Pessoa pessoa(
  String nome, {
  String id = 'p1',
  String apelido = '',
  String relacao = '',
  String contatos = '',
  String preferencias = '',
  String observacoes = '',
  String compromissos = '',
  String historico = '',
  bool consentimento = true,
}) =>
    Pessoa(
      id: id,
      nome: nome,
      apelido: apelido,
      relacao: relacao,
      contatos: contatos,
      preferencias: preferencias,
      observacoes: observacoes,
      compromissos: compromissos,
      historico: historico,
      consentimento: consentimento,
      criadaEm: DateTime(2026, 11, 15),
      atualizadaEm: DateTime(2026, 11, 15),
    );

void main() {
  // 1. Nome é obrigatório e consentimento é obrigatório
  assert(validarPessoa(pessoa('   ')) != null, 'nome vazio deveria falhar');
  assert(validarPessoa(pessoa('Ana', consentimento: false)) != null, 'sem consentimento deveria falhar');
  assert(validarPessoa(pessoa('Ana')) == null, 'ficha mínima deveria valer');

  // 2. Campos são limpos e cortados sem inventar conteúdo
  final limpa = pessoa('<b>Ana</b>\u0007', observacoes: 'x' * 2500).sanitizada();
  assert(!limpa.nome.contains('<') && !limpa.nome.contains('>'), 'tags não removidas');
  assert(!limpa.nome.contains('\u0007'), 'caractere de controle não removido');
  assert(limpa.observacoes.length == 2000, 'limite de observações: ${limpa.observacoes.length}');
  assert(pessoa('Ana').sanitizada().relacao.isEmpty, 'campo vazio virou algo');

  // 3. JSON preserva todos os campos e o consentimento
  final cheia = pessoa(
    'Ana',
    apelido: 'Aninha',
    relacao: 'irmã',
    contatos: '+55 11 99999-0000',
    preferencias: 'café sem açúcar',
    observacoes: 'gosta de azul',
    compromissos: 'consulta dia 20',
    historico: 'almoço em outubro',
  );
  final volta = pessoasDeJson(jsonDePessoas([cheia])).single;
  assert(volta.nome == 'Ana' && volta.apelido == 'Aninha' && volta.relacao == 'irmã', 'campos perdidos');
  assert(volta.contatos == cheia.contatos && volta.historico == cheia.historico, 'campos sensíveis perdidos');
  assert(volta.consentimento, 'consentimento perdido');
  assert(pessoasDeJson('não é json').isEmpty, 'JSON inválido deveria virar lista vazia');
  assert(pessoasDeJson(jsonDePessoas([pessoa('Sem id', id: '')])).isEmpty, 'ficha sem id deveria ser descartada');

  // 4. Nomes parecidos nunca são fundidos nem escolhidos sozinhos
  final lista = [
    pessoa('Ana', id: 'a', apelido: 'Aninha'),
    pessoa('Ana Paula', id: 'b'),
    pessoa('Carlos', id: 'c', apelido: 'Cadu'),
  ];
  final ambiguo = resolverPessoa(lista, 'an');
  assert(ambiguo.tipo == TipoResolucaoPessoa.ambiguo, 'parcial deveria ser ambíguo');
  assert(ambiguo.candidatos.length == 2, 'candidatos errados');
  assert(ambiguo.perfil == null, 'ambiguidade não pode escolher sozinha');
  assert(resolverPessoa(lista, 'Ana Paula').tipo == TipoResolucaoPessoa.exato, 'nome exato não resolvido');
  assert(resolverPessoa(lista, 'cadu').tipo == TipoResolucaoPessoa.exato, 'apelido exato não resolvido');
  assert(resolverPessoa(lista, 'zzz').tipo == TipoResolucaoPessoa.nenhum, 'desconhecido virou alguém');
  assert(resolverPessoa(lista, '   ').tipo == TipoResolucaoPessoa.nenhum, 'vazio resolveu alguém');
  final doisJoao = [pessoa('João', id: 'j1'), pessoa('João', id: 'j2')];
  assert(resolverPessoa(doisJoao, 'João').tipo == TipoResolucaoPessoa.ambiguo, 'dois João fundidos');

  // 5. Busca por nome/apelido sem acento e sem caixa
  assert(buscarPessoas(lista, 'ANINHA').length == 1, 'busca por apelido falhou');
  assert(buscarPessoas(lista, 'ana').length == 2, 'busca parcial falhou');
  assert(buscarPessoas([pessoa('José', id: 'z')], 'jose').length == 1, 'acento atrapalhou');

  // 6. Descrição só com o que foi cadastrado
  assert(descreverPessoa(pessoa('Ana')) == 'Ana — nenhuma informação além do nome.', 'descrição inventou algo');
  final descricao = descreverPessoa(cheia);
  assert(descricao.contains('Aninha') && descricao.contains('café sem açúcar'), 'dados reais não apareceram');
  assert(!descricao.contains('99999'), 'telefone não deveria ir para a descrição falada');

  // 7. Última interação vem do que o usuário escreveu, nunca deduzida
  assert(ultimaInteracao(pessoa('Ana')) == null, 'interação inventada');
  assert(ultimaInteracao(pessoa('Ana', historico: 'primeira\n\nsegunda interação')) == 'segunda interação', 'última errada');

  // 8. Contexto da IA: só nome/apelido/relação/preferências, limitado a 12
  final sensivel = pessoa(
    'Ana',
    apelido: 'Aninha',
    relacao: 'irmã',
    preferencias: 'café',
    contatos: '+55 11 99999-0000',
    observacoes: 'segredo',
    compromissos: 'consulta',
    historico: 'almoço',
  );
  final contexto = contextoPessoas([sensivel]);
  assert(contexto.contains('Ana') && contexto.contains('irmã'), 'dados básicos ausentes');
  assert(!contexto.contains('99999'), 'contato vazou para a IA');
  assert(!contexto.contains('segredo'), 'observações vazaram para a IA');
  assert(!contexto.contains('almoço') && !contexto.contains('consulta'), 'histórico/compromisso vazou para a IA');
  final muitos = [for (var i = 1; i <= 14; i++) pessoa('Pessoa $i', id: 'p$i')];
  assert(contextoPessoas(muitos).split('\n').length == 12, 'contexto sem limite');

  // 9. Limpeza não mexe em id nem em consentimento
  final mantida = cheia.sanitizada();
  assert(mantida.id == cheia.id && mantida.consentimento, 'sanitizar perdeu id/consentimento');

  stdout.writeln('OK: pessoas — validação, consentimento, ambiguidade, descrição sem invenção e contexto seguro');
}
