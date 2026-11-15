import 'package:material_ui/material_ui.dart';

import '../core/pessoas.dart';
import '../ui_common.dart';
import 'pessoas_store.dart';

/// Fichas de pessoas: criar, editar, pesquisar, consultar e excluir — tudo local.
///
/// Não há foto, câmera, biometria nem reconhecimento facial nesta etapa. O app não completa
/// campo vazio nem deduz relação: o que não foi digitado aparece como não informado.
class PessoasPage extends StatefulWidget {
  const PessoasPage({super.key, required this.store});

  final PessoasStore store;

  @override
  State<PessoasPage> createState() => _PessoasPageState();
}

class _PessoasPageState extends State<PessoasPage> {
  List<Pessoa> pessoas = const [];
  String busca = '';
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await widget.store.listar();
    if (!mounted) return;
    setState(() {
      pessoas = lista;
      carregando = false;
    });
  }

  Future<void> _editar([Pessoa? pessoa]) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PessoaEditorPage(store: widget.store, pessoa: pessoa)),
    );
    if (salvou == true) await _carregar();
  }

  List<Pessoa> get visiveis => buscarPessoas(pessoas, busca);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas e contexto')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nova pessoa'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 15, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Fichas locais e criptografadas no aparelho. Sem foto, câmera ou reconhecimento facial; nada é enviado.',
                          style: TextStyle(fontSize: 10.5, height: 1.35, color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: TextField(
                    onChanged: (valor) => setState(() => busca = valor),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Buscar por nome ou apelido…',
                      helperText: 'Nomes parecidos não são fundidos nem escolhidos sozinhos.',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: pessoas.isEmpty
                      ? _vazio(colors)
                      : visiveis.isEmpty
                          ? Center(child: Text('Nenhuma ficha corresponde a “$busca”.'))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                              itemCount: visiveis.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (_, indice) => _cartao(visiveis[indice], colors),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _vazio(ColorScheme colors) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 90),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_alt_outlined, size: 40, color: colors.primary),
              const SizedBox(height: 12),
              const Text('Nenhuma ficha ainda', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Uma ficha guarda só o que você digitar e autorizar: nome, apelido, relação, contatos, '
                'preferências, anotações, compromissos e histórico. Nada é deduzido de conversas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: () => _editar(), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Criar primeira ficha')),
            ],
          ),
        ),
      );

  Widget _cartao(Pessoa pessoa, ColorScheme colors) {
    final inicial = pessoa.nome.trim().isEmpty ? '?' : pessoa.nome.trim().characters.first.toUpperCase();
    final detalhe = pessoa.relacao.isNotEmpty
        ? pessoa.relacao
        : pessoa.apelido.isNotEmpty
            ? 'Apelido: ${pessoa.apelido}'
            : 'Relação não informada';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _editar(pessoa),
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: colors.primary.withValues(alpha: 0.14),
          child: Text(inicial, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
        ),
        title: Text(pessoa.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          pessoa.apelido.isNotEmpty && pessoa.relacao.isNotEmpty ? '${pessoa.apelido} · $detalhe' : detalhe,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      ),
    );
  }
}

/// Criação e edição de uma ficha. Campo vazio continua vazio — o app não preenche nada.
class PessoaEditorPage extends StatefulWidget {
  const PessoaEditorPage({super.key, required this.store, this.pessoa});

  final PessoasStore store;
  final Pessoa? pessoa;

  @override
  State<PessoaEditorPage> createState() => _PessoaEditorPageState();
}

class _PessoaEditorPageState extends State<PessoaEditorPage> {
  late final Map<String, TextEditingController> campos = {
    for (final chave in const ['nome', 'apelido', 'relacao', 'contatos', 'preferencias', 'observacoes', 'compromissos', 'historico'])
      chave: TextEditingController(text: _valorInicial(chave)),
  };
  late bool consentimento = widget.pessoa?.consentimento ?? false;
  bool salvando = false;

  String _valorInicial(String chave) {
    final p = widget.pessoa;
    if (p == null) return '';
    return switch (chave) {
      'nome' => p.nome,
      'apelido' => p.apelido,
      'relacao' => p.relacao,
      'contatos' => p.contatos,
      'preferencias' => p.preferencias,
      'observacoes' => p.observacoes,
      'compromissos' => p.compromissos,
      _ => p.historico,
    };
  }

  @override
  void dispose() {
    for (final controlador in campos.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  Pessoa _montar() {
    final agora = DateTime.now();
    return Pessoa(
      id: widget.pessoa?.id ?? '',
      nome: campos['nome']!.text,
      apelido: campos['apelido']!.text,
      relacao: campos['relacao']!.text,
      contatos: campos['contatos']!.text,
      preferencias: campos['preferencias']!.text,
      observacoes: campos['observacoes']!.text,
      compromissos: campos['compromissos']!.text,
      historico: campos['historico']!.text,
      consentimento: consentimento,
      criadaEm: widget.pessoa?.criadaEm ?? agora,
      atualizadaEm: agora,
    );
  }

  Future<void> _salvar() async {
    if (salvando) return;
    setState(() => salvando = true);
    final resultado = await widget.store.salvar(_montar());
    if (!mounted) return;
    setState(() => salvando = false);
    if (!resultado.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _apagar() async {
    final pessoa = widget.pessoa;
    if (pessoa == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Excluir esta ficha?'),
        content: Text('“${pessoa.nome}” e tudo que está nela serão removidos deste aparelho. Não há como desfazer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true) return;
    final apagou = await widget.store.apagar(pessoa.id);
    if (!mounted) return;
    if (!apagou) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível excluir a ficha.')));
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _campo(String chave, String rotulo, {int linhas = 1, String? ajuda}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: campos[chave],
          maxLines: linhas,
          minLines: linhas > 1 ? 2 : 1,
          textCapitalization: chave == 'contatos' ? TextCapitalization.none : TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: rotulo,
            hintText: 'Não informado',
            helperText: ajuda,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pessoa == null ? 'Nova ficha' : 'Editar ficha'),
        actions: [
          IconButton(
            tooltip: 'Salvar ficha',
            onPressed: salvando ? null : _salvar,
            icon: const Icon(Icons.check_rounded),
          ),
          if (widget.pessoa != null)
            IconButton(tooltip: 'Excluir ficha', onPressed: _apagar, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            'Preencha só o que você sabe e tem autorização para guardar. Campos vazios ficam como '
            'não informados; o app não completa nem deduz nada.',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: muted),
          ),
          const SizedBox(height: 12),
          _campo('nome', 'Nome *'),
          _campo('apelido', 'Apelido'),
          _campo('relacao', 'Relação', ajuda: 'Como você conhece a pessoa (amiga, irmão, colega…).'),
          _campo('contatos', 'Contato autorizado', ajuda: 'Fica só neste aparelho e nunca entra no contexto da IA.'),
          _campo('preferencias', 'Preferências', linhas: 2),
          _campo('observacoes', 'Anotações', linhas: 3),
          _campo('compromissos', 'Compromissos', linhas: 2),
          _campo('historico', 'Histórico de interações', linhas: 3, ajuda: 'Escrito por você; o app não inventa interações.'),
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            child: CheckboxListTile(
              value: consentimento,
              onChanged: (valor) => setState(() => consentimento = valor ?? false),
              title: const Text('Tenho o consentimento desta pessoa', style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                'Dados de terceiros são sensíveis (LGPD). Confirme que a pessoa autorizou guardar estas informações.',
                style: TextStyle(fontSize: 10.5, height: 1.35),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: salvando ? null : _salvar,
            icon: const Icon(Icons.save_outlined),
            label: Text(salvando ? 'Salvando…' : 'Salvar ficha'),
          ),
          if (widget.pessoa != null) ...[
            const SizedBox(height: 8),
            Text(
              'Excluir remove a ficha inteira deste aparelho. Não há cópia na pasta do Obsidian: '
              'fichas de pessoas não são gravadas no cofre.',
              style: TextStyle(fontSize: 10, height: 1.4, color: muted),
            ),
          ],
          ],
        ),
      ),
    );
  }
}
