/// Hermes Agent — o plano antes da execução.
///
/// O núcleo web já tinha o Hermes escolhendo rota e delegando por agente. Aqui
/// está a parte que se pode provar sem rede: dado um pedido, qual agente
/// responde e em que passos o trabalho se decompõe. A execução de cada passo é
/// feita pela tela, com o provedor configurado — este arquivo não fala com a
/// rede e não afirma que algo foi executado.
library;

import 'agentes.dart';

/// Um passo do plano: o que fazer e quem faz.
class PassoHermes {
  const PassoHermes({
    required this.agente,
    required this.titulo,
    required this.instrucao,
  });

  final AgenteEspecializado agente;
  final String titulo;

  /// O que o passo pede, em uma frase — vai junto do pedido ao provedor.
  final String instrucao;
}

/// Plano completo: rota, passos e o limite declarado.
class PlanoHermes {
  const PlanoHermes({
    required this.pedido,
    required this.rota,
    required this.passos,
    required this.aviso,
  });

  final String pedido;
  final AgenteEspecializado rota;
  final List<PassoHermes> passos;

  /// Limite ou cuidado que acompanha este tipo de pedido.
  final String aviso;

  /// Pedido de elétrica/eletrônica: pode ser montado no projetista local.
  bool get eletrico => rota.id == 'engenharia' || rota.id == 'eletronica';

  /// Quantos passos o plano tem.
  int get total => passos.length;
}

const _avisoEletrico = 'O esquema sai do simulador local, em corrente contínua; '
    'o .cad nativo do CADeSIMU não é gerado, porque o formato é proprietário.';
const _avisoConversa = 'Sem provedor configurado, o plano aparece e a execução '
    'diz que falta a chave — nada é inventado.';

/// Monta o plano do pedido. Determinístico: o mesmo texto dá o mesmo plano.
PlanoHermes planejarPedido(String pedido) {
  final texto = pedido.trim();
  final rota = agenteDe(texto);

  if (rota.id == 'eletronica' || rota.id == 'engenharia') {
    return PlanoHermes(
      pedido: texto,
      rota: rota,
      aviso: _avisoEletrico,
      passos: [
        PassoHermes(
          agente: agentePorId('engenharia'),
          titulo: 'Fixar o pedido',
          instrucao: 'Diga tensão, carga, o que liga e desliga e em quanto tempo. '
              'Se faltar dado, pergunte antes de desenhar.',
        ),
        PassoHermes(
          agente: agentePorId('engenharia'),
          titulo: 'Dimensionar',
          instrucao: 'Calcule corrente, resistência e proteção com os valores '
              'informados. Mostre a conta.',
        ),
        PassoHermes(
          agente: agentePorId('eletronica'),
          titulo: 'Montar o esquema',
          instrucao: 'Monte o circuito no simulador do aparelho e confira a '
              'netlist gerada.',
        ),
        PassoHermes(
          agente: agentePorId('eletronica'),
          titulo: 'Validar',
          instrucao: 'Rode a simulação e relate curto, componente queimado ou '
              'aviso elétrico. Não declare pronto sem a simulação fechar.',
        ),
      ],
    );
  }

  if (rota.id == 'programacao') {
    return PlanoHermes(
      pedido: texto,
      rota: rota,
      aviso: 'Este APK não executa código: o plano produz texto e revisão, não '
          'teste rodando no aparelho.',
      passos: [
        PassoHermes(
          agente: rota,
          titulo: 'Entender o alvo',
          instrucao: 'Delimite o que o código deve fazer e o que não deve.',
        ),
        PassoHermes(
          agente: rota,
          titulo: 'Propor a solução',
          instrucao: 'Escreva a solução completa, com os casos de erro.',
        ),
        PassoHermes(
          agente: rota,
          titulo: 'Revisar',
          instrucao: 'Aponte o que pode falhar e o teste que provaria o '
              'contrário.',
        ),
      ],
    );
  }

  if (rota.id == 'visao') {
    return PlanoHermes(
      pedido: texto,
      rota: rota,
      aviso: 'A imagem só sai do aparelho com o seu consentimento registrado.',
      passos: [
        PassoHermes(
          agente: rota,
          titulo: 'Descrever o quadro',
          instrucao: 'Diga o que está visível, sem adivinhar o que está fora '
              'do enquadramento.',
        ),
        PassoHermes(
          agente: rota,
          titulo: 'Responder a pergunta',
          instrucao: 'Responda só o que a imagem mostra; o que não aparece, '
              'diga que não aparece.',
        ),
      ],
    );
  }

  if (rota.id == 'arquivos' || rota.id == 'memoria' || rota.id == 'pessoas') {
    return PlanoHermes(
      pedido: texto,
      rota: rota,
      aviso: 'Os dados ficam no aparelho; nada é enviado sem a sua chave.',
      passos: [
        PassoHermes(
          agente: rota,
          titulo: 'Localizar o dado',
          instrucao: 'Procure o arquivo, a nota ou a ficha certa pelo nome e '
              'pelo assunto.',
        ),
        PassoHermes(
          agente: rota,
          titulo: 'Responder ou gravar',
          instrucao: 'Devolva o que encontrou ou grave o que foi pedido, dizendo '
              'onde ficou.',
        ),
      ],
    );
  }

  return PlanoHermes(
    pedido: texto,
    rota: rota,
    aviso: _avisoConversa,
    passos: [
      PassoHermes(
        agente: rota,
        titulo: 'Classificar o pedido',
        instrucao: 'Diga em uma frase o que a pessoa quer e o que falta saber.',
      ),
      PassoHermes(
        agente: rota,
        titulo: 'Responder',
        instrucao: 'Responda curto, em português do Brasil, sem inventar dado.',
      ),
    ],
  );
}

/// Texto do plano para a tela e para a fala.
String resumoPlano(PlanoHermes plano) {
  final passos = plano.passos
      .asMap()
      .entries
      .map((e) => '${e.key + 1}. ${e.value.titulo} (${e.value.agente.nome})')
      .join(' · ');
  return 'Rota: ${plano.rota.nome}. ${plano.total} passo'
      '${plano.total == 1 ? '' : 's'}: $passos. ${plano.aviso}';
}

/// Mensagens para o provedor executando um passo.
List<Map<String, String>> mensagensDoPasso(
  PlanoHermes plano,
  PassoHermes passo, {
  String personalidade = '',
}) {
  final sistema = [
    if (personalidade.trim().isNotEmpty) personalidade.trim(),
    instrucaoDoAgente(passo.agente),
  ].join('\n\n');
  return [
    {'role': 'system', 'content': sistema},
    {
      'role': 'user',
      'content': 'Pedido original: ${plano.pedido}\n\n'
          'Passo ${plano.passos.indexOf(passo) + 1} de ${plano.total} — '
          '${passo.titulo}: ${passo.instrucao}\n\n'
          'Responda só este passo, em texto curto.',
    },
  ];
}
