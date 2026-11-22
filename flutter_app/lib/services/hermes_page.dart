import 'package:material_ui/material_ui.dart';

import '../core/agentes.dart';
import '../core/hermes_plano.dart';
import '../ui_common.dart';
import '../services/provider_service.dart';
import 'projetista_page.dart';

/// Hermes Agent na tela: rota, plano e execução passo a passo.
///
/// O plano é local e determinístico; a execução usa o provedor de IA que a
/// pessoa configurou. Sem provedor, a tela mostra o plano e diz que falta a
/// chave — nunca finge uma resposta.
class HermesPage extends StatefulWidget {
  const HermesPage({super.key, this.responder});

  /// Injetável no teste: recebe as mensagens e devolve o texto do passo.
  final Future<String> Function(List<Map<String, String>> mensagens)? responder;

  @override
  State<HermesPage> createState() => _HermesPageState();
}

class _HermesPageState extends State<HermesPage> {
  final campo = TextEditingController();
  PlanoHermes? plano;
  final respostas = <int, String>{};
  String erro = '';
  bool executando = false;

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  void _planejar() {
    setState(() {
      plano = planejarPedido(campo.text);
      respostas.clear();
      erro = '';
    });
  }

  Future<String> _pedir(List<Map<String, String>> mensagens) async {
    final injetado = widget.responder;
    if (injetado != null) return injetado(mensagens);
    final provedor = ProviderService(secrets: PlatformSecretStore());
    final escolhido = await provedor.firstConfiguredProvider();
    if (escolhido == null) {
      throw const ProviderException(
          'Nenhum provedor de IA está configurado. Cadastre uma chave em '
          'Provedores de IA — o plano continua valendo sem ela.');
    }
    return provedor.complete(escolhido.id, mensagens);
  }

  Future<void> _executar() async {
    final atual = plano;
    if (atual == null || executando) return;
    setState(() {
      executando = true;
      erro = '';
      respostas.clear();
    });
    for (var i = 0; i < atual.passos.length; i++) {
      if (!mounted) return;
      try {
        final texto =
            await _pedir(mensagensDoPasso(atual, atual.passos[i]));
        if (!mounted) return;
        setState(() => respostas[i] = texto.trim());
      } catch (e) {
        if (!mounted) return;
        setState(() {
          erro = e is ProviderException
              ? e.message
              : 'A execução parou no passo ${i + 1}: $e';
        });
        break;
      }
    }
    if (!mounted) return;
    setState(() => executando = false);
  }

  @override
  Widget build(BuildContext context) {
    final atual = plano;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Hermes Agent', style: TextStyle(fontSize: 15))),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Eyebrow('PLANO ANTES DA EXECUÇÃO'),
          const SizedBox(height: 8),
          const Text('Um pedido, um agente, passos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
          const SizedBox(height: 7),
          const Text(
              'O Hermes classifica o pedido, escolhe o agente do domínio e '
              'decompõe o trabalho. Você vê o plano antes de qualquer chamada '
              'ao provedor.',
              style: TextStyle(color: muted, height: 1.5, fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('hermes-campo'),
            controller: campo,
            minLines: 2,
            maxLines: 4,
            onSubmitted: (_) => _planejar(),
            decoration: const InputDecoration(
                labelText: 'Pedido',
                hintText: 'monta um divisor de tensão de 12 V'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('hermes-planejar'),
            onPressed: _planejar,
            icon: const Icon(Icons.route_rounded),
            label: const Text('Montar plano'),
          ),
          if (atual != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cyan.withValues(alpha: .22))),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Agente: ${atual.rota.nome}',
                    key: const ValueKey('hermes-rota'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(atual.rota.dominio,
                    style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 10),
                for (var i = 0; i < atual.passos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ',
                              style: const TextStyle(
                                  color: cyan, fontSize: 11.5)),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    '${atual.passos[i].titulo} · '
                                    '${atual.passos[i].agente.nome}',
                                    style: const TextStyle(fontSize: 11.5)),
                                if (respostas.containsKey(i))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(respostas[i]!,
                                        key: ValueKey('hermes-resposta-$i'),
                                        style: const TextStyle(
                                            color: muted, fontSize: 11)),
                                  ),
                              ])),
                        ]),
                  ),
                const SizedBox(height: 4),
                Text(atual.aviso,
                    key: const ValueKey('hermes-aviso'),
                    style: const TextStyle(
                        color: muted, fontSize: 10.5, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('hermes-executar'),
              onPressed: executando ? null : _executar,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(executando ? 'Executando…' : 'Executar passos'),
            ),
            if (atual.eletrico) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('hermes-montar'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            ProjetistaPage(textoInicial: atual.pedido))),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Montar no projetista'),
              ),
            ],
          ],
          if (erro.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(erro,
                key: const ValueKey('hermes-erro'),
                style: const TextStyle(
                    color: Color(0xFFFFC66D), fontSize: 11, height: 1.45)),
          ],
        ]));
  }
}

/// Agentes especializados: quem existe, o que cada um cobre e para onde o
/// pedido digitado vai.
class AgentesPage extends StatefulWidget {
  const AgentesPage({super.key});

  @override
  State<AgentesPage> createState() => _AgentesPageState();
}

class _AgentesPageState extends State<AgentesPage> {
  final campo = TextEditingController();
  AgenteEspecializado? rota;

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          appBar: AppBar(
              title: const Text('Agentes especializados',
                  style: TextStyle(fontSize: 15))),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            const Eyebrow('DOMÍNIOS'),
            const SizedBox(height: 8),
            const Text('Doze agentes, um roteador',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
            const SizedBox(height: 7),
            Text(resumoDosAgentes(),
                style: const TextStyle(color: muted, height: 1.5, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('agentes-campo'),
              controller: campo,
              onChanged: (texto) =>
                  setState(() => rota = texto.trim().isEmpty ? null : agenteDe(texto)),
              decoration: const InputDecoration(
                  labelText: 'Testar o roteamento',
                  hintText: 'aumenta o volume do celular'),
            ),
            if (rota != null) ...[
              const SizedBox(height: 8),
              Text('Vai para: ${rota!.nome}',
                  key: const ValueKey('agentes-rota'),
                  style: const TextStyle(color: cyan, fontSize: 11.5)),
            ],
            const SizedBox(height: 16),
            for (final agente in agentesEspecializados)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(14)),
                  child:
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(agente.nome,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(agente.dominio,
                        style: const TextStyle(
                            color: muted, fontSize: 10.5, height: 1.4)),
                    const SizedBox(height: 5),
                    Text('ex.: ${agente.exemplos.first}',
                        style:
                            const TextStyle(color: muted, fontSize: 10)),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
                'O roteamento é por palavra-chave, na ordem do núcleo web. '
                'Ele escolhe a instrução que acompanha o pedido; não executa '
                'ferramenta nenhuma por conta própria.',
                style: TextStyle(color: muted, fontSize: 10.5, height: 1.4)),
          ]));
}
