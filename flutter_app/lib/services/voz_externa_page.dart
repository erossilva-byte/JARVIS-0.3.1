import 'package:material_ui/material_ui.dart';

import '../core/voz_externa.dart';
import '../ui_common.dart';
import 'voz_externa_service.dart';

/// Voz externa: o ID, a chave e o botão de teste.
///
/// A tela fala a verdade em três estados — sem chave, chave cadastrada mas voz
/// desligada, e voz ligada. A chave é escrita no cofre do aparelho e nunca é
/// relida para a tela.
class VozExternaPage extends StatefulWidget {
  const VozExternaPage({super.key, this.servico});

  final VozExternaService? servico;

  @override
  State<VozExternaPage> createState() => _VozExternaPageState();
}

class _VozExternaPageState extends State<VozExternaPage> {
  late final VozExternaService _servico = widget.servico ?? VozExternaService();
  final campoId = TextEditingController();
  final campoChave = TextEditingController();
  String id = idVozPadrao;
  bool ativa = false;
  bool temChave = false;
  String status = '';
  bool ocupado = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final atual = await _servico.id();
    final ligada = await _servico.ativa();
    final chave = await _servico.lerChave();
    if (!mounted) return;
    setState(() {
      id = atual;
      campoId.text = atual;
      ativa = ligada;
      temChave = chave != null;
      status = resumoVozExterna(atual, ativa: ligada, temChave: chave != null);
    });
  }

  @override
  void dispose() {
    campoId.dispose();
    campoChave.dispose();
    super.dispose();
  }

  Future<void> _salvarId() async {
    await _servico.gravarId(campoId.text);
    await _carregar();
  }

  Future<void> _salvarChave() async {
    final texto = campoChave.text.trim();
    if (texto.isEmpty) {
      setState(() => status = 'Cole a chave do serviço para salvar.');
      return;
    }
    await _servico.gravarChave(texto);
    campoChave.clear();
    await _carregar();
    if (!mounted) return;
    setState(() => status = 'Chave salva no cofre do aparelho. Ela não volta '
        'para a tela.');
  }

  Future<void> _alternar(bool valor) async {
    await _servico.definirAtiva(valor);
    await _carregar();
  }

  Future<void> _testar() async {
    setState(() {
      ocupado = true;
      status = 'Gerando o áudio…';
    });
    final resultado = await _servico.gerar(
        'Bom dia. Eu sou o JARVIS. Esta é a voz externa configurada.');
    if (!mounted) return;
    if (!resultado.ok) {
      setState(() {
        ocupado = false;
        status = resultado.erro ?? 'Não foi possível gerar o áudio.';
      });
      return;
    }
    final tocou = await _servico.tocar(resultado.audio!);
    if (!mounted) return;
    setState(() {
      ocupado = false;
      status = tocou
          ? 'Áudio gerado e tocado neste aparelho.'
          : 'Áudio gerado (${resultado.audio!.length} bytes), mas este aparelho '
              'não tocou: o canal de voz do Android não respondeu.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          appBar: AppBar(
              title: const Text('Voz externa (ID)',
                  style: TextStyle(fontSize: 15))),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            const Eyebrow('VOZ EXTERNA'),
            const SizedBox(height: 8),
            const Text('Uma voz por ID',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
            const SizedBox(height: 7),
            Text(resumoVozExterna(id, ativa: ativa, temChave: temChave),
                key: const ValueKey('voz-externa-resumo'),
                style: const TextStyle(color: muted, height: 1.5, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('voz-id-campo'),
              controller: campoId,
              decoration: InputDecoration(
                  labelText: 'ID de voz',
                  hintText: idVozPadrao,
                  helperText: 'Padrão do app: $idVozPadrao'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('voz-id-salvar'),
              onPressed: _salvarId,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Salvar ID'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('voz-chave-campo'),
              controller: campoChave,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                  labelText: 'Chave do serviço ($nomeServicoVoz)',
                  helperText: temChave
                      ? 'Já existe uma chave salva no cofre.'
                      : 'Sem chave, nada é gerado.'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('voz-chave-salvar'),
              onPressed: _salvarChave,
              icon: const Icon(Icons.key_rounded, size: 18),
              label: const Text('Salvar chave'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('voz-externa-ativa'),
              value: ativa,
              onChanged: _alternar,
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar esta voz nas respostas',
                  style: TextStyle(fontSize: 12.5)),
              subtitle: const Text(
                  'Desligada, o JARVIS fala com a voz do aparelho.',
                  style: TextStyle(color: muted, fontSize: 10.5)),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('voz-externa-testar'),
              onPressed: ocupado ? null : _testar,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: Text(ocupado ? 'Testando…' : 'Testar voz'),
            ),
            const SizedBox(height: 12),
            if (status.isNotEmpty)
              Text(status,
                  key: const ValueKey('voz-externa-status'),
                  style: const TextStyle(color: cyan, fontSize: 11, height: 1.45)),
            const SizedBox(height: 18),
            const Eyebrow('O QUE ISSO MUDA'),
            const SizedBox(height: 6),
            for (final limite in limitesVozExterna)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: muted),
                  const SizedBox(width: 7),
                  Expanded(
                      child: Text(limite,
                          key: const ValueKey('voz-externa-limite'),
                          style: const TextStyle(
                              color: muted, fontSize: 10.5, height: 1.45))),
                ]),
              ),
          ]));
}
