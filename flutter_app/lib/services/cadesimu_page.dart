import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../ui_common.dart';
import 'cadesimu_cad.dart';
import 'circuito_page.dart';

class CadesimuPage extends StatefulWidget {
  const CadesimuPage({super.key, this.seletor = const SeletorCadAndroid()});

  final SeletorCad seletor;

  @override
  State<CadesimuPage> createState() => _CadesimuPageState();
}

class _CadesimuPageState extends State<CadesimuPage> {
  ArquivoCad? arquivo;
  DocumentoCad? documento;
  ResumoCad? resumo;
  String? erro;
  bool lendo = false;

  Future<void> _abrir() async {
    if (lendo) return;
    setState(() {
      lendo = true;
      erro = null;
    });
    try {
      final escolhido = await widget.seletor.escolher();
      if (!mounted) return;
      if (escolhido == null) {
        setState(() => lendo = false);
        return;
      }
      final doc = DocumentoCad.ler(escolhido.texto);
      if (doc.escrever() != escolhido.texto) {
        throw CadesimuErro(
            'A leitura não devolveu o arquivo original; nada foi alterado, mas o arquivo não foi aceito.');
      }
      setState(() {
        arquivo = escolhido;
        documento = doc;
        resumo = doc.resumo();
        lendo = false;
      });
    } on CadesimuErro catch (e) {
      if (mounted) setState(() => erro = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            erro = 'Não foi possível ler o arquivo .cad. Nada foi alterado.');
      }
    } finally {
      if (mounted) setState(() => lendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = resumo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CADeSIMU · leitura', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF211A10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFC66D).withValues(alpha: .25)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.visibility_outlined, color: Color(0xFFFFC66D)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Somente leitura. Esta tela mostra o inventário e a geometria do .cad; não edita, não simula e não gera netlist elétrica.',
                    style: TextStyle(color: muted, fontSize: 11, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('abrir-simulador-do-cad'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CircuitoPage()),
            ),
            icon: const Icon(Icons.science_outlined),
            label: const Text('Abrir simulador de circuitos'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('abrir-cad'),
            onPressed: lendo ? null : _abrir,
            icon: lendo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open_rounded),
            label: Text(lendo ? 'Lendo arquivo…' : 'Escolher arquivo .cad'),
          ),
          if (erro != null) ...[
            const SizedBox(height: 12),
            Text(erro!,
                style: const TextStyle(
                    color: Color(0xFFFF8A80), fontSize: 11.5, height: 1.45)),
          ],
          if (arquivo == null) ...[
            const SizedBox(height: 18),
            const Text(
              'O CADeSIMU guarda o desenho em texto ISO-8859-1. A leitura preserva os bytes originais e não envia o arquivo a nenhum provedor.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ],
          if (r != null && arquivo != null) ...[
            const SizedBox(height: 16),
            Text(arquivo!.nome,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
                '${arquivo!.tamanho} bytes · ${r.registros} registros · rodapé ${r.rodape ? 'presente' : 'ausente'}',
                style: const TextStyle(color: muted, fontSize: 10.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                _metrica('SÍMBOLOS', r.simbolos),
                const SizedBox(width: 8),
                _metrica('FIOS', r.fios),
                const SizedBox(width: 8),
                _metrica('JUNÇÕES', r.juncoes),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metrica('TEXTOS', r.textos.length),
                const SizedBox(width: 8),
                _metrica('REDES', r.redesGeometricas),
                const SizedBox(width: 8),
                _metrica('COM FIO', r.simbolosComFioNaOrigem),
              ],
            ),
            const SizedBox(height: 14),
            if (documento!.fios.isNotEmpty) ...[
              const Text('GEOMETRIA',
                  style: TextStyle(
                      color: cyan,
                      fontSize: 9,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Container(
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFF07111B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cyan.withValues(alpha: .18)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _CadPainter(documento!),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (r.textos.isNotEmpty) ...[
              const Text('TEXTOS DO DESENHO',
                  style: TextStyle(
                      color: cyan,
                      fontSize: 9,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              for (final texto in r.textos)
                Text('• $texto',
                    style: const TextStyle(fontSize: 11, height: 1.5)),
              const SizedBox(height: 12),
            ],
            const Text('SÍMBOLOS',
                style: TextStyle(
                    color: cyan,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            if (documento!.simbolos.isEmpty)
              const Text('Nenhum símbolo identificado.',
                  style: TextStyle(color: muted, fontSize: 11))
            else
              for (final s in documento!.simbolos.take(100))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 58,
                          child: Text('#${s.tipo}',
                              style:
                                  const TextStyle(color: cyan, fontSize: 10))),
                      Expanded(
                        child: Text(
                          s.rotulo.isEmpty ? '(sem rótulo)' : s.rotulo,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Text(
                        s.x == null || s.y == null
                            ? 'sem posição'
                            : '${s.x},${s.y}',
                        style: const TextStyle(color: muted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
            if (documento!.simbolos.length > 100)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Mostrando os primeiros 100 símbolos.',
                    style: TextStyle(color: muted, fontSize: 9.5)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metrica(String nome, int valor) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Text('$valor',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(nome,
                  style: const TextStyle(
                      color: muted, fontSize: 8, letterSpacing: 1)),
            ],
          ),
        ),
      );
}

class _CadPainter extends CustomPainter {
  _CadPainter(this.documento);
  final DocumentoCad documento;

  @override
  void paint(Canvas canvas, Size size) {
    final fios = documento.fios
        .where(
            (f) => f.x != null && f.y != null && f.x2 != null && f.y2 != null)
        .toList();
    if (fios.isEmpty) return;
    var minX = fios.first.x!.toDouble();
    var maxX = minX;
    var minY = fios.first.y!.toDouble();
    var maxY = minY;
    for (final f in fios) {
      minX = [minX, f.x!.toDouble(), f.x2!.toDouble()]
          .reduce((a, b) => a < b ? a : b);
      maxX = [maxX, f.x!.toDouble(), f.x2!.toDouble()]
          .reduce((a, b) => a > b ? a : b);
      minY = [minY, f.y!.toDouble(), f.y2!.toDouble()]
          .reduce((a, b) => a < b ? a : b);
      maxY = [maxY, f.y!.toDouble(), f.y2!.toDouble()]
          .reduce((a, b) => a > b ? a : b);
    }
    final largura = (maxX - minX).clamp(1, double.infinity);
    final altura = (maxY - minY).clamp(1, double.infinity);
    final escalaX = (size.width - 24) / largura;
    final escalaY = (size.height - 24) / altura;
    final escala = escalaX < escalaY ? escalaX : escalaY;
    final deslocX = (size.width - largura * escala) / 2;
    final deslocY = (size.height - altura * escala) / 2;
    Offset p(int x, int y) => Offset(
          deslocX + (x - minX) * escala,
          deslocY + (y - minY) * escala,
        );
    final paint = Paint()
      ..color = cyan.withValues(alpha: .85)
      ..strokeWidth = 1.2;
    for (final f in fios) {
      canvas.drawLine(p(f.x!, f.y!), p(f.x2!, f.y2!), paint);
    }
    final marcador = Paint()..color = const Color(0xFFFFC66D);
    for (final m in documento.registros.where((r) => r.tipo == 4001)) {
      if (m.x != null && m.y != null) {
        canvas.drawCircle(p(m.x!, m.y!), 2.2, marcador);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CadPainter old) => old.documento != documento;
}
