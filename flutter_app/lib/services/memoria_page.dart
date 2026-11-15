import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/memoria.dart';
import '../core/memoria_busca.dart';
import '../ui_common.dart';
import 'cofre_saf.dart';
import 'conflitos_page.dart';
import 'memoria_store.dart';
import 'sincronizador.dart';

/// Cofre local: lista, busca lexical explicada, edição e importação de Markdown.
///
/// A tela diz o que é de verdade: nota local, busca por palavra, motivo do resultado e uma
/// sincronização com a pasta do Obsidian que nunca apaga nota — no pior caso, conflito. Ela roda
/// sozinha ao abrir o app e ao voltar para ele, em silêncio; o botão continua para o usuário ver o
/// resultado e resolver conflito.
class MemoriaPage extends StatefulWidget {
  const MemoriaPage({super.key, required this.store});

  final MemoriaStore store;

  @override
  State<MemoriaPage> createState() => _MemoriaPageState();
}

class _MemoriaPageState extends State<MemoriaPage> with WidgetsBindingObserver {
  List<NotaMemoria> notas = const [];
  String busca = '';
  bool carregando = true;
  PastaSaf? pasta;
  bool lendoPasta = false;
  bool sincronizando = false;
  String? ultimoResumo;
  int conflitosPendentes = 0;
  bool _emSegundoPlano = false;
  bool _autoEmAndamento = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
    _abrir();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Voltar ao app sincroniza de novo; só depois de realmente ter saído, para não repetir à toa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.paused || estado == AppLifecycleState.hidden) {
      _emSegundoPlano = true;
      return;
    }
    if (estado == AppLifecycleState.resumed && _emSegundoPlano) {
      _emSegundoPlano = false;
      _sincronizarAutomatico();
    }
  }

  Future<void> _abrir() async {
    await _carregarPasta();
    await _sincronizarAutomatico();
  }

  Future<void> _carregarPasta() async {
    final resultado = await CofreSaf.pastaAtual();
    if (!mounted) return;
    setState(() => pasta = resultado.valor);
  }

  /// Sincronização de fundo: sem diálogo nem aviso, só o estado do cartão mudando.
  Future<void> _sincronizarAutomatico() async {
    final conectada = pasta;
    if (!mounted || sincronizando || _autoEmAndamento) return;
    if (conectada == null || !conectada.podeEscrever) return;
    _autoEmAndamento = true;
    try {
      await _sincronizarPasta(silencioso: true);
    } finally {
      _autoEmAndamento = false;
    }
  }

  Future<void> _conectarPasta() async {
    final resultado = await CofreSaf.escolherPasta();
    if (!mounted) return;
    if (!resultado.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    final escolhida = resultado.valor;
    if (escolhida == null) return; // usuário cancelou
    setState(() => pasta = escolhida);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pasta conectada: ${escolhida.nome}')));
    await _sincronizarAutomatico();
  }

  Future<void> _importarPasta() async {
    if (lendoPasta) return;
    setState(() => lendoPasta = true);
    final leitura = await CofreSaf.listarNotas();
    if (!mounted) return;
    if (!leitura.ok) {
      setState(() => lendoPasta = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(leitura.erro!)));
      return;
    }
    final dados = leitura.valor!;
    final resultado = await widget.store.importar([
      for (final nota in dados.notas) (nome: nota.caminho, conteudo: nota.conteudo),
    ]);
    if (!mounted) return;
    setState(() => lendoPasta = false);
    await _carregar();
    if (!mounted) return;
    final partes = <String>[
      '${resultado.adicionadas.length} nova(s)',
      '${resultado.repetidas} repetida(s)',
      if (resultado.conflitos.isNotEmpty) '${resultado.conflitos.length} conflito(s) preservado(s)',
      if (dados.ignoradas > 0) '${dados.ignoradas} arquivo(s) ignorado(s)',
      if (dados.truncadas > 0) '${dados.truncadas} grande(s) recusado(s)',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pasta importada: ${partes.join(', ')}.')));
  }

  Future<void> _sincronizarPasta({bool silencioso = false}) async {
    if (sincronizando || pasta == null) return;
    if (!pasta!.podeEscrever) {
      if (silencioso) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A pasta está conectada só para leitura. Conecte de novo e permita editar para enviar notas.')),
      );
      return;
    }
    setState(() => sincronizando = true);
    final resultado = await Sincronizador(store: widget.store, cofre: const CofreSafGateway()).sincronizar();
    if (!mounted) return;
    setState(() {
      sincronizando = false;
      ultimoResumo = resultado.ok ? resultado.resumo : null;
      conflitosPendentes = resultado.plano.conflitos.length;
    });
    await _carregar();
    if (!mounted) return;
    if (!resultado.ok) {
      if (silencioso) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não sincronizou: ${resultado.erroGeral}')));
      return;
    }
    if (silencioso) return;
    if (resultado.plano.conflitos.isNotEmpty) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ConflitosPage(
            conflitos: resultado.plano.conflitos,
            store: widget.store,
            cofre: const CofreSafGateway(),
          ),
        ),
      );
      if (!mounted) return;
      // A tela pode ter resolvido parte dos conflitos: relê a pasta e atualiza o cartão sem aviso.
      await _sincronizarPasta(silencioso: true);
      return;
    }
    final aviso = resultado.falhas.isEmpty
        ? 'Sincronização: ${resultado.resumo}.'
        : 'Sincronização parcial: ${resultado.resumo}. Primeira falha: ${resultado.falhas.first}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
  }

  Future<void> _desconectarPasta() async {
    final resultado = await CofreSaf.esquecerPasta();
    if (!mounted) return;
    if (!resultado.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    setState(() => pasta = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pasta desconectada.')));
  }

  Future<void> _carregar() async {
    final lista = widget.store.listar();
    if (!mounted) return;
    setState(() {
      notas = lista;
      carregando = false;
    });
  }

  List<ResultadoMemoria> get resultados => busca.trim().isEmpty ? const [] : widget.store.buscar(busca, limite: 30);

  Future<void> _editar([NotaMemoria? nota]) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => NotaEditorPage(store: widget.store, nota: nota)),
    );
    if (salvou == true) await _carregar();
  }

  Future<void> _apagar(NotaMemoria nota) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Apagar nota?'),
        content: Text('“${nota.titulo}” será removida deste aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmar != true) return;
    await widget.store.apagar(nota.id);
    await _carregar();
  }

  Future<void> _copiarMarkdown(NotaMemoria nota) async {
    await Clipboard.setData(ClipboardData(text: escreverMarkdown(nota)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Markdown copiado.')));
  }

  Future<void> _importar() async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Importar Markdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cole o conteúdo de uma nota exportada do Obsidian. O frontmatter é lido; '
                'título repetido com texto diferente vira conflito e não sobrescreve nada.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 8,
              minLines: 5,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '---\ntitulo: …\n---'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, controller.text), child: const Text('Importar')),
        ],
      ),
    );
    if (texto == null || texto.trim().isEmpty) return;
    final resultado = await widget.store.importar([(nome: 'colado.md', conteudo: texto)]);
    await _carregar();
    if (!mounted) return;
    final partes = <String>[
      '${resultado.adicionadas.length} adicionada(s)',
      '${resultado.repetidas} repetida(s)',
      if (resultado.conflitos.isNotEmpty) '${resultado.conflitos.length} conflito(s) preservado(s)',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importação: ${partes.join(', ')}.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memória'),
        actions: [
          if (pasta == null)
            IconButton(
              tooltip: 'Conectar pasta do Obsidian',
              onPressed: _conectarPasta,
              icon: const Icon(Icons.folder_open_rounded),
            ),
          IconButton(tooltip: 'Importar Markdown', onPressed: _importar, icon: const Icon(Icons.file_download_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Nova nota'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (valor) => setState(() => busca = valor),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Buscar nas notas…',
                      helperText: 'Busca por palavra (sem embeddings neurais); o motivo aparece em cada resultado.',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                if (pasta != null) _cartaoPasta(colors),
                Expanded(
                  child: notas.isEmpty ? _vazio(colors) : busca.trim().isEmpty ? _lista(colors) : _resultados(colors),
                ),
              ],
            ),
    );
  }

  Widget _vazio(ColorScheme colors) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 90),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_outlined, size: 40, color: colors.primary),
              const SizedBox(height: 12),
              const Text('Nenhuma nota no cofre', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'As notas ficam neste aparelho. Você pode criar uma nota, colar um Markdown exportado do Obsidian '
                'ou, no Android, conectar a pasta do cofre pela permissão do sistema (SAF) e importar as notas dela.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(onPressed: _importar, icon: const Icon(Icons.file_download_outlined), label: const Text('Importar Markdown')),
                  OutlinedButton.icon(onPressed: _conectarPasta, icon: const Icon(Icons.folder_open_rounded), label: const Text('Conectar pasta do Obsidian')),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _cartaoPasta(ColorScheme colors) => Card(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_special_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pasta!.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          sincronizando
                              ? 'Sincronizando nos dois sentidos…'
                              : lendoPasta
                                  ? 'Lendo a pasta…'
                                  : !pasta!.podeEscrever
                                      ? 'Pasta conectada só para leitura · reconecte para enviar'
                                      : conflitosPendentes > 0
                                          ? 'Sincronizado · $conflitosPendentes conflito(s) pendente(s)'
                                          : ultimoResumo != null
                                              ? 'Sincronizado · $ultimoResumo'
                                              : 'Pasta do Obsidian conectada · permissão guardada pelo sistema',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Desconectar pasta',
                    onPressed: sincronizando ? null : _desconectarPasta,
                    icon: const Icon(Icons.link_off_rounded, size: 19),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: sincronizando || lendoPasta || !pasta!.podeEscrever ? null : _sincronizarPasta,
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text(sincronizando ? 'Sincronizando…' : 'Sincronizar'),
                    ),
                    TextButton(
                      onPressed: sincronizando || lendoPasta ? null : _importarPasta,
                      child: const Text('Importar notas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _lista(ColorScheme colors) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        itemCount: notas.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, indice) {
          if (indice == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Text('${notas.length} nota(s) · mais recentes primeiro', style: const TextStyle(color: muted, fontSize: 11)),
            );
          }
          return _cartao(notas[indice - 1], colors, motivo: null);
        },
      );

  Widget _resultados(ColorScheme colors) {
    final achados = resultados;
    if (achados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Text('Nenhuma nota corresponde a “$busca”.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      itemCount: achados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, indice) => _cartao(achados[indice].nota, colors, motivo: achados[indice].motivo),
    );
  }

  Widget _cartao(NotaMemoria nota, ColorScheme colors, {required String? motivo}) {
    final tema = temasMemoria[nota.tema] ?? nota.tema;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _editar(nota),
        isThreeLine: true,
        title: Row(
          children: [
            Expanded(child: Text(nota.titulo, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (nota.importancia >= 2) const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC66D)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(trecho(nota), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.35)),
            const SizedBox(height: 4),
            Text(
              motivo == null ? '$tema · ${nota.tags.isEmpty ? 'sem tags' : nota.tags.join(', ')}' : '$tema · $motivo',
              style: TextStyle(fontSize: 10, color: motivo == null ? muted : colors.primary),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Ações da nota',
          onSelected: (acao) {
            if (acao == 'editar') _editar(nota);
            if (acao == 'copiar') _copiarMarkdown(nota);
            if (acao == 'apagar') _apagar(nota);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'copiar', child: Text('Copiar Markdown')),
            PopupMenuItem(value: 'apagar', child: Text('Apagar')),
          ],
        ),
      ),
    );
  }
}

/// Editor de nota: título, corpo, tema, tags e importância.
class NotaEditorPage extends StatefulWidget {
  const NotaEditorPage({super.key, required this.store, this.nota});

  final MemoriaStore store;
  final NotaMemoria? nota;

  @override
  State<NotaEditorPage> createState() => _NotaEditorPageState();
}

class _NotaEditorPageState extends State<NotaEditorPage> {
  late final TextEditingController titulo = TextEditingController(text: widget.nota?.titulo ?? '');
  late final TextEditingController texto = TextEditingController(text: widget.nota?.texto ?? '');
  late final TextEditingController tags = TextEditingController(text: widget.nota?.tags.join(', ') ?? '');
  late String tema = widget.nota?.tema ?? 'contextos';
  late int importancia = widget.nota?.importancia ?? 1;
  String? erro;

  @override
  void dispose() {
    titulo.dispose();
    texto.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (titulo.text.trim().isEmpty || texto.text.trim().isEmpty) {
      setState(() => erro = 'Título e texto são obrigatórios.');
      return;
    }
    final agora = DateTime.now();
    final existente = widget.nota;
    final nota = existente == null
        ? NotaMemoria(
            id: agora.microsecondsSinceEpoch.toString(),
            titulo: titulo.text.trim(),
            texto: texto.text.trim(),
            tema: tema,
            tags: tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
            importancia: importancia,
            criadaEm: agora,
            atualizadaEm: agora,
          )
        : existente.copiarCom(
            titulo: titulo.text.trim(),
            texto: texto.text.trim(),
            tema: tema,
            tags: tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
            importancia: importancia,
            atualizadaEm: agora,
          );
    await widget.store.salvar(nota);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nota == null ? 'Nova nota' : 'Editar nota'),
        actions: [
          TextButton(onPressed: _salvar, child: const Text('Salvar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titulo,
            decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: texto,
            minLines: 8,
            maxLines: 20,
            decoration: const InputDecoration(labelText: 'Texto', alignLabelWithHint: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tags,
            decoration: const InputDecoration(labelText: 'Tags (separadas por vírgula)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: tema,
            decoration: const InputDecoration(labelText: 'Tema', border: OutlineInputBorder()),
            items: [for (final entrada in temasMemoria.entries) DropdownMenuItem(value: entrada.key, child: Text(entrada.value))],
            onChanged: (valor) => setState(() => tema = valor ?? 'contextos'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: importancia,
            decoration: const InputDecoration(labelText: 'Importância', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 0, child: Text('0 — passageira')),
              DropdownMenuItem(value: 1, child: Text('1 — normal')),
              DropdownMenuItem(value: 2, child: Text('2 — importante')),
              DropdownMenuItem(value: 3, child: Text('3 — essencial')),
            ],
            onChanged: (valor) => setState(() => importancia = valor ?? 1),
          ),
          if (erro != null) ...[
            const SizedBox(height: 12),
            Text(erro!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
