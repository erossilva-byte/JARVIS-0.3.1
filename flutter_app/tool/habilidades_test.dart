import 'dart:io';

import 'package:jarvis_nova/core/conversa.dart';
import 'package:jarvis_nova/core/habilidades.dart';
import 'package:jarvis_nova/core/memoria_busca.dart';

const _revisar = '''---
nome: Revisar texto
descricao: Corrige sem mudar o sentido.
gatilhos: revisar texto, corrigir texto
---

1. Leia tudo antes.
2. Corrija ortografia.
''';

const _fecharMes = '''# Fechar o mês

Confira as contas fixas e o saldo.
''';

void main() {
  // 1. O caminho só é habilidade dentro de Skills/ ou Habilidades/.
  assert(caminhoDeHabilidade('Skills/revisar-texto.md'), 'Skills deveria valer');
  assert(caminhoDeHabilidade('Projetos/Skills/fechar-mes.md'),
      'pasta de habilidades em qualquer nível deveria valer');
  assert(caminhoDeHabilidade('habilidades/exemplo/x.md'),
      'minúsculas deveriam valer');
  assert(!caminhoDeHabilidade('Diario/2026-11-21.md'),
      'nota comum não é habilidade');
  assert(!caminhoDeHabilidade('Skills.md'),
      'arquivo na raiz não é habilidade');

  // 2. Frontmatter vira nome, descrição e gatilhos; o corpo é o passo a passo.
  final revisarLida = lerHabilidade(_revisar, origem: 'Skills/revisar-texto.md');
  assert(revisarLida != null, 'habilidade válida foi recusada');
  final revisar = revisarLida!;
  assert(revisar.nome == 'Revisar texto', 'nome do frontmatter perdido');
  assert(revisar.descricao.contains('sem mudar o sentido'), 'descrição perdida');
  assert(revisar.gatilhos.contains('revisar texto'), 'gatilho perdido');
  assert(revisar.instrucoes.contains('Leia tudo antes'), 'passos perdidos');
  assert(!revisar.instrucoes.contains('nome:'), 'frontmatter vazou para o corpo');

  // 3. Sem frontmatter, o título do Markdown vira nome e o arquivo é a reserva.
  final fecharLido = lerHabilidade(_fecharMes, origem: 'Skills/fechar-mes.md');
  assert(fecharLido != null, 'Markdown sem frontmatter foi recusado');
  final fechar = fecharLido!;
  assert(fechar.nome == 'Fechar o mês', 'título do Markdown perdido');
  assert(fechar.origem == 'Skills/fechar-mes.md', 'origem perdida');

  // 4. Corpo vazio e arquivo fora da pasta não entram.
  assert(lerHabilidade('---\nnome: Vazia\n---\n\n', origem: 'Skills/v.md') == null,
      'habilidade sem passos deveria ser recusada');
  final varias = habilidadesDosArquivos([
    (caminho: 'Skills/revisar-texto.md', conteudo: _revisar),
    (caminho: 'Diario/hoje.md', conteudo: _fecharMes),
    (caminho: 'Skills/fechar-mes.md', conteudo: _fecharMes),
    (caminho: 'Skills/revisar-copia.md', conteudo: _revisar),
  ]);
  assert(varias.length == 2, 'arquivos fora da pasta ou repetidos entraram');
  assert(varias.first.nome == 'Revisar texto', 'ordem da leitura mudou');

  // 5. A pergunta ativa só a habilidade que casa.
  final porGatilho =
      habilidadesQueCasam(varias, 'Jarvis, pode revisar texto do contrato?');
  assert(porGatilho.length == 1, 'gatilho não isolou a habilidade');
  assert(porGatilho.single.nome == 'Revisar texto', 'habilidade errada');
  final porNome = habilidadesQueCasam(varias, 'quero fechar mes hoje');
  assert(porNome.single.nome == 'Fechar o mês', 'nome não ativou a habilidade');
  assert(habilidadesQueCasam(varias, 'que horas são').isEmpty,
      'pergunta sem relação ativou habilidade');
  assert(habilidadesQueCasam(varias, '   ').isEmpty,
      'pergunta vazia ativou habilidade');

  // 6. O bloco entra no pedido como instrução, com nome e passos.
  final bloco = blocoHabilidades(porGatilho);
  assert(bloco.contains('## Revisar texto'), 'bloco sem o nome');
  assert(bloco.contains('Passos:'), 'bloco sem os passos');
  assert(bloco.contains('Leia tudo antes'), 'bloco sem o conteúdo');
  assert(blocoHabilidades(const []).isEmpty, 'bloco vazio deveria ser vazio');

  // 7. Truncamento protege a cota do provedor.
  final enorme = Habilidade(
      nome: 'Enorme',
      instrucoes: List<String>.filled(400, 'passo').join(' '),
      origem: 'Skills/enorme.md');
  assert(blocoHabilidades([enorme]).length <= limiteBlocoHabilidades + 1,
      'bloco passou do limite');
  final lido = lerHabilidade(
      '---\nnome: Grande\n---\n${List<String>.filled(600, 'passo').join(' ')}',
      origem: 'Skills/grande.md');
  assert(lido!.instrucoes.length <= limiteInstrucoes + 1,
      'instruções passaram do limite');

  // 8. A montagem da conversa coloca o bloco como sistema e preserva o histórico.
  final mensagens = montarMensagens(
    [
      {'role': 'user', 'content': 'revisar texto'},
    ],
    const ContextoMemoria(texto: '', usados: [], caracteres: 0),
    personalidade: 'Tom direto.',
    habilidades: bloco,
  );
  assert(mensagens.first['role'] == 'system', 'falta sistema');
  assert(mensagens.any((m) => m['content'] == bloco),
      'bloco de habilidades não entrou no pedido');
  assert(mensagens.last['content'] == 'revisar texto', 'histórico perdido');

  // 9. A origem usada fica registrada na mensagem e sobrevive ao JSON.
  final mensagem = MensagemConversa(
      autor: 'assistant', texto: 'Segui a habilidade.', habilidades: const ['Revisar texto']);
  assert(mensagem.paraJson()['habilidades'] != null,
      'habilidades não foram salvas');
  final voltou = MensagemConversa.deJson(mensagem.paraJson());
  assert(voltou!.habilidades.single == 'Revisar texto',
      'habilidades perdidas na releitura');

  stdout.writeln(
      'OK: habilidades — caminho, frontmatter, casamento, bloco, limites e registro');
}
