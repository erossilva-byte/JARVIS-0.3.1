import 'package:material_ui/material_ui.dart';

import '../core/arquivos.dart';
import '../ui_common.dart';
import 'abrir_sandbox.dart';
import 'arquivo_sandbox.dart';

/// Arquivos de texto na pasta privada do app.
///
/// Não abre pasta externa, não executa código e não envia conteúdo para a rede. A tela diz isso e
/// não oferece botão que finja o contrário.
class ArquivosPage extends StatefulWidget {
  const ArquivosPage({super.key, this.sandbox, this.abrir});

  final ArquivoSandbox? sandbox;
  final Future<ArquivoSandbox> Function()? abrir;

  @override
  State<ArquivosPage> createState() => _ArquivosPageState();
}

class _ArquivosPageState extends State<ArquivosPage> {
  final nome = TextEditingController();
  final conteudo = TextEditingController();

  ArquivoSandbox? sandbox;
  List<ArquivoResumo> arquivos = const [];
  bool carregando = true;
  bool editando = false;
  bool novo = false;
  bool salvando = false;
  String? nomeAtual;
  String original = '';
  String? erro;
  String? erroPasta;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    try {
      sandbox = widget.sandbox ?? await (widget.abrir ?? abrirSandboxPadrao)();
      await _recarregar();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erroPasta = 'A pasta isolada de arquivos não está disponível neste aparelho.';
      });
    }
  }

  Future<void> _recarregar() async {
    final atual = sandbox;
    if (atual == null) return;
    final lista = await atual.listar();
    if (!mounted) return;
    setState(() {
      arquivos = lista;
      carregando = false;
    });
  }

  bool get alterado =>
      editando && (conteudo.text != original || (novo && nome.text.trim().isNotEmpty));

  Future<bool> _confirmarDescarte() async {
    if (!alterado) return true;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('O texto que não foi salvo será perdido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Continuar editando')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Descartar')),
        ],
      ),
    );
    return descartar ?? false;
  }

  Future<void> _abrir([ArquivoResumo? resumo]) async {
    if (alterado && !await _confirmarDescarte()) return;
    final atual = sandbox;
    if (atual == null) return;
    try {
      final texto = resumo == null ? '' : await atual.ler(resumo.nome);
      if (!mounted) return;
      setState(() {
        editando = true;
        novo = resumo == null;
        nomeAtual = resumo?.nome;
        original = texto;
        erro = null;
      });
      nome.text = resumo?.nome ?? '';
      conteudo.text = texto;
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    }
  }

  Future<void> _sairDoEditor() async {
    if (!await _confirmarDescarte()) return;
    if (!mounted) return;
    setState(() {
      editando = false;
      erro = null;
    });
  }

  String _mensagem(Object e) => e
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _salvar() async {
    final atual = sandbox;
    if (atual == null || salvando) return;
    final validado = novo ? validarNomeArquivo(nome.text) : NomeArquivo.ok(nomeAtual!);
    if (!validado.valido) {
      setState(() => erro = validado.erro);
      return;
    }
    final erroTexto = validarConteudoArquivo(conteudo.text);
    if (erroTexto != null) {
      setState(() => erro = erroTexto);
      return;
    }
    if (novo && arquivos.any((a) => a.nome.toLowerCase() == validado.nome!.toLowerCase())) {
      setState(() => erro = 'Já existe um arquivo com esse nome. Renomeie antes de salvar.');
      return;
    }
    setState(() {
      salvando = true;
      erro = null;
    });
    try {
      if (novo) {
        await atual.criar(validado.nome!, conteudo.text);
        nomeAtual = validado.nome;
        novo = false;
      } else {
        await atual.gravar(nomeAtual!, conteudo.text);
      }
      await _recarregar();
      if (!mounted) return;
      setState(() {
        salvando = false;
        original = conteudo.text;
      });
      nome.text = nomeAtual ?? '';
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo salvo na pasta isolada.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        salvando = false;
        erro = _mensagem(e);
      });
    }
  }

  Future<void> _renomear() async {
    final atual = sandbox;
    final antigo = nomeAtual;
    if (atual == null || antigo == null) return;
    final resposta = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoNome(inicial: antigo),
    );
    if (resposta == null || !mounted) return;
    final validado = validarNomeArquivo(resposta);
    if (!validado.valido) {
      setState(() => erro = validado.erro);
      return;
    }
    if (validado.nome!.toLowerCase() == antigo.toLowerCase()) return;
    try {
      await atual.renomear(antigo, validado.nome!);
      if (!mounted) return;
      setState(() {
        nomeAtual = validado.nome;
        nome.text = validado.nome!;
        erro = null;
      });
      await _recarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo renomeado.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    }
  }

  Future<void> _apagar() async {
    final atual = sandbox;
    final alvo = nomeAtual;
    if (atual == null || alvo == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Apagar este arquivo?'),
        content: Text('“$alvo” será removido da pasta isolada. Não há lixeira.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await atual.apagar(alvo);
      if (!mounted) return;
      setState(() {
        editando = false;
        nomeAtual = null;
        original = '';
        erro = null;
      });
      nome.clear();
      conteudo.clear();
      await _recarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo apagado.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    }
  }

  @override
  void dispose() {
    nome.dispose();
    conteudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !editando,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _sairDoEditor();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editando ? (nomeAtual ?? 'Novo arquivo') : 'Arquivos'),
          actions: [
            if (editando) ...[
              IconButton(
                key: const ValueKey('salvar-arquivo'),
                tooltip: 'Salvar arquivo',
                onPressed: salvando ? null : _salvar,
                icon: salvando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
              ),
              if (!novo) ...[
                IconButton(
                  key: const ValueKey('renomear-arquivo'),
                  tooltip: 'Renomear arquivo',
                  onPressed: _renomear,
                  icon: const Icon(Icons.drive_file_rename_outline_rounded),
                ),
                IconButton(
                  key: const ValueKey('apagar-arquivo'),
                  tooltip: 'Apagar arquivo',
                  onPressed: _apagar,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ],
        ),
        body: _corpo(colors),
      ),
    );
  }

  Widget _corpo(ColorScheme colors) {
    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (erroPasta != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(erroPasta!, style: TextStyle(color: colors.error, fontSize: 13, height: 1.45)),
      );
    }
    if (editando) return _editor(colors);
    return _lista(colors);
  }

  Widget _lista(ColorScheme colors) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('PASTA ISOLADA DO APP', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text(
            'Só arquivos de texto (.txt) criados aqui. Sem acesso a Downloads, à pasta do Obsidian '
            'ou a outras pastas, e nada é enviado para a rede.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('novo-arquivo'),
            onPressed: () => _abrir(),
            icon: const Icon(Icons.note_add_rounded, size: 18),
            label: const Text('Novo arquivo'),
          ),
          const SizedBox(height: 14),
          if (arquivos.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(Icons.folder_open_rounded, color: Color(0xFF55DFFF), size: 28),
                  SizedBox(height: 9),
                  Text('Nenhum arquivo ainda.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(height: 5),
                  Text(
                    'Crie o primeiro texto. Ele fica neste aparelho, nesta pasta, e pode ser apagado a qualquer momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            )
          else
            for (final arquivo in arquivos)
              Card(
                color: colors.surfaceContainerHighest.withValues(alpha: .25),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: ValueKey('arquivo-${arquivo.nome}'),
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF55DFFF)),
                  title: Text(arquivo.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${arquivo.tamanhoLegivel}${arquivo.modificadoEm == null ? '' : ' · ${_data(arquivo.modificadoEm!)}'}',
                    style: const TextStyle(fontSize: 10.5, color: muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                  onTap: () => _abrir(arquivo),
                ),
              ),
          const SizedBox(height: 16),
          const Text(
            'Execução de código não existe nesta tela: não há sandbox de código, terminal nem '
            'permissão para rodar programas. O recorte desta fase é arquivo de texto isolado.',
            style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
          ),
        ],
      );

  Widget _editor(ColorScheme colors) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (novo)
            TextField(
              key: const ValueKey('nome-arquivo'),
              controller: nome,
              enabled: !salvando,
              decoration: const InputDecoration(
                labelText: 'Nome do arquivo',
                hintText: 'nota',
                helperText: 'A extensão .txt é acrescentada se faltar.',
                border: OutlineInputBorder(),
              ),
            )
          else
            Text(nomeAtual ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('conteudo-arquivo'),
            controller: conteudo,
            enabled: !salvando,
            minLines: 12,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Texto',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (erro != null) ...[
            const SizedBox(height: 10),
            Text(erro!, style: TextStyle(color: colors.error, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: salvando ? null : _sairDoEditor,
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Voltar à lista'),
              ),
              const Spacer(),
              const Text('Salva no aparelho', style: TextStyle(color: muted, fontSize: 10)),
            ],
          ),
        ],
      );

  String _data(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes $hora:$minuto';
  }
}


/// Diálogo com controlador próprio: descartá-lo fora do diálogo derrubava o foco durante a
/// animação de saída.
class _DialogoNome extends StatefulWidget {
  const _DialogoNome({required this.inicial});

  final String inicial;

  @override
  State<_DialogoNome> createState() => _DialogoNomeState();
}

class _DialogoNomeState extends State<_DialogoNome> {
  late final TextEditingController controlador = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Renomear arquivo'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Novo nome'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controlador.text), child: const Text('Renomear')),
        ],
      );
}
