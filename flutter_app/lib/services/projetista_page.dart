import 'package:material_ui/material_ui.dart';

import '../core/circuito.dart';
import '../core/projetista.dart';
import '../ui_common.dart';
import 'circuito_page.dart';

/// Circuito por prompt: a pessoa descreve, o projetista monta e o simulador
/// confere.
///
/// A tela não desenha por conta própria: ela pede `montarProjetoDe` no núcleo
/// puro e só oferece o botão do simulador quando a simulação fechou. Quando não
/// fecha, mostra o motivo e o que o projetista sabe montar.
class ProjetistaPage extends StatefulWidget {
  const ProjetistaPage({super.key, this.textoInicial = ''});

  final String textoInicial;

  @override
  State<ProjetistaPage> createState() => _ProjetistaPageState();
}

class _ProjetistaPageState extends State<ProjetistaPage> {
  late final TextEditingController campo =
      TextEditingController(text: widget.textoInicial);
  ResultadoProjeto? resultado;

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  void _montar() {
    setState(() => resultado = montarProjetoDe(campo.text));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          appBar: AppBar(
              title: const Text('Circuito por prompt',
                  style: TextStyle(fontSize: 15))),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            const Eyebrow('DESCREVA O CIRCUITO'),
            const SizedBox(height: 8),
            const Text('Do texto ao esquema',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w300)),
            const SizedBox(height: 7),
            const Text(
                'Diga tensão, carga e o que deve acontecer. O JARVIS monta o '
                'circuito e roda a simulação antes de entregar; se não fechar, '
                'ele diz o motivo em vez de desenhar errado.',
                style: TextStyle(color: muted, height: 1.5, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('projetista-campo'),
              controller: campo,
              minLines: 2,
              maxLines: 4,
              onSubmitted: (_) => _montar(),
              decoration: const InputDecoration(
                  labelText: 'Pedido',
                  hintText: 'lâmpada de 12 V e 5 W com interruptor'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('projetista-montar'),
              onPressed: _montar,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Montar circuito'),
            ),
            const SizedBox(height: 16),
            if (resultado != null) ..._resultado(resultado!),
            const SizedBox(height: 18),
            const Eyebrow('EXEMPLOS'),
            const SizedBox(height: 6),
            for (final exemplo in exemplosDePedido)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: panel,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    title: Text(exemplo,
                        style: const TextStyle(fontSize: 11.5, color: muted)),
                    trailing:
                        const Icon(Icons.north_west_rounded, size: 16, color: cyan),
                    onTap: () {
                      setState(() {
                        campo.text = exemplo;
                        resultado = montarProjetoDe(exemplo);
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: 10),
            const Text(
                'Limites: o simulador é de corrente contínua; trifásico, '
                'transistor, CI e o .cad nativo do CADeSIMU não são montados '
                'aqui.',
                style: TextStyle(color: muted, fontSize: 10.5, height: 1.4)),
          ]));

  List<Widget> _resultado(ResultadoProjeto projeto) {
    if (!projeto.ok) {
      return [
        Container(
          key: const ValueKey('projetista-motivo'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF211A10),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFFFC66D).withValues(alpha: .22))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.report_rounded, color: Color(0xFFFFC66D)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Não montei este circuito',
                      style: TextStyle(
                          color: Color(0xFFFFC66D),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(projeto.motivo,
                      style: const TextStyle(
                          color: muted, fontSize: 11, height: 1.45)),
                ])),
          ]),
        ),
      ];
    }
    final circuito = projeto.circuito!;
    final simulado = circuito.simular();
    return [
      Container(
        key: const ValueKey('projetista-resultado'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cyan.withValues(alpha: .22))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(projeto.titulo,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(projeto.explicacao,
              style: const TextStyle(color: muted, fontSize: 11.5, height: 1.45)),
          const SizedBox(height: 8),
          Text(
              '${circuito.elementos.length} trecho(s) · '
              '${simulado.calculado ? 'simulação fechada' : 'simulação falhou'} · '
              '${formatarNumero(simulado.potenciaTotal)} W no total',
              key: const ValueKey('projetista-simulacao'),
              style: const TextStyle(color: cyan, fontSize: 11)),
          for (final aviso in projeto.avisos)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: muted),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(aviso,
                        style: const TextStyle(
                            color: muted, fontSize: 10.5, height: 1.4))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const ValueKey('projetista-abrir'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CircuitoPage(inicial: projeto.circuito))),
        icon: const Icon(Icons.science_outlined),
        label: const Text('Abrir no simulador'),
      ),
    ];
  }
}
