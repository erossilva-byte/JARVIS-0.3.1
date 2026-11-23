import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/programacao.dart';
import '../ui_common.dart';
import 'abrir_sandbox.dart';
import 'arquivo_sandbox.dart';
import 'provider_service.dart';

/// Modo programação: criar, analisar, modificar e explicar código, montar um
/// prompt de pedido e guardar o resultado como texto.
///
/// A tela não executa nada. A resposta vem do provedor de IA configurado; o
/// prompt de código é montado no aparelho e funciona sem chave. O que aparece
/// é texto — quem confere e cola no editor é a pessoa.
class ProgramacaoPage extends StatefulWidget {
  const ProgramacaoPage({super.key, this.responder, this.sandbox, this.abrir});

  /// Injetável no teste: recebe as mensagens e devolve a resposta.
  final Future<String> Function(List<Map<String, String>> mensagens)? responder;

  final ArquivoSandbox? sandbox;
  final Future<ArquivoSandbox> Function()? abrir;

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  final campoPedido = TextEditingController();
  final campoCodigo = TextEditingController();
  final campoErro = TextEditingController();
  final campoRestricoes = TextEditingController();

  TarefaCodigo tarefa = TarefaCodigo.criar;
  LinguagemCodigo linguagem = linguagensCodigo.first;
  String resposta = '';
  String? erroTela;
  String status = '';
  bool ocupado = false;
  bool salvando = false;
  ArquivoSandbox? sandbox;
  List<BlocoCodigo> blocos = const [];

  @override
  void dispose() {
    campoPedido.dispose();
    campoCodigo.dispose();
    campoErro.dispose();
    campoRestricoes.dispose();
    super.dispose();
  }

  PedidoCodigo get _pedido => PedidoCodigo(
        tarefa: tarefa,
        linguagem: linguagem,
        pedido: campoPedido.text,
        codigo: campoCodigo.text,
        erro: campoErro.text,
      );

  void _trocarTarefa(TarefaCodigo nova) {
    setState(() {
      tarefa = nova;
      erroTela = null;
      resposta = '';
      blocos = const [];
      status = '';
    });
  }

  Future<String> _enviarAoProvedor(List<Map<String, String>> mensagens) async {
    final injetado = widget.responder;
    if (injetado != null) return injetado(mensagens);
    final provedor = ProviderService(secrets: PlatformSecretStore());
    final escolhido = await provedor.firstConfiguredProvider();
    if (escolhido == null) {
      throw const ProviderException(
          'Nenhum provedor de IA está configurado. Cadastre uma chave em '
          'Provedores de IA — o prompt de código, esse, é montado aqui e '
          'funciona sem chave.');
    }
    return provedor.complete(escolhido.id, mensagens);
  }

  Future<void> _executar() async {
    if (ocupado) return;
    final pedido = _pedido;
    final recusa = validarPedidoCodigo(pedido);
    if (recusa != null) {
      setState(() {
        erroTela = recusa;
        resposta = '';
        blocos = const [];
      });
      return;
    }
    setState(() {
      erroTela = null;
      resposta = '';
      blocos = const [];
      status = '';
    });

    if (tarefa.geraPrompt) {
      final texto = promptDeCodigo(
        linguagem,
        campoPedido.text,
        restricoes: campoRestricoes.text,
      );
      setState(() {
        resposta = texto;
        blocos = const [];
        status = 'Prompt montado no aparelho. Nada foi enviado ao provedor.';
      });
      return;
    }

    setState(() => ocupado = true);
    try {
      final texto = await _enviarAoProvedor(mensagensDeCodigo(pedido));
      if (!mounted) return;
      setState(() {
        ocupado = false;
        resposta = texto.trim();
        blocos = extrairBlocos(texto);
        status = 'Resposta recebida. Nada foi executado nem testado aqui.';
      });
    } catch (falha) {
      if (!mounted) return;
      setState(() {
        ocupado = false;
        erroTela = falha is ProviderException
            ? falha.message
            : 'A consulta parou: $falha';
      });
    }
  }

  Future<void> _copiar(String texto, [String rotulo = 'Texto copiado.']) async {
    if (texto.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    setState(() => status = rotulo);
  }

  Future<void> _colarNaArea() async {
    final dados = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = dados?.text ?? '';
    if (!mounted || texto.isEmpty) {
      if (mounted) setState(() => status = 'A área de transferência está vazia.');
      return;
    }
    campoCodigo.text = texto;
    setState(() => status = 'Código colado na área de código.');
  }

  Future<ArquivoSandbox?> _abrirSandbox() async {
    if (sandbox != null) return sandbox;
    try {
      sandbox = widget.sandbox ?? await (widget.abrir ?? abrirSandboxPadrao)();
      return sandbox;
    } catch (_) {
      if (mounted) {
        setState(() => erroTela =
            'A pasta isolada de arquivos não está disponível neste aparelho.');
      }
      return null;
    }
  }

  Future<void> _salvar(String texto) async {
    if (salvando) return;
    if (texto.trim().isEmpty) {
      setState(() => status = 'Não há código para salvar.');
      return;
    }
    setState(() {
      salvando = true;
      erroTela = null;
    });
    final atual = await _abrirSandbox();
    if (atual == null) {
      if (mounted) setState(() => salvando = false);
      return;
    }
    try {
      final existentes = (await atual.listar()).map((a) => a.nome);
      final nome = nomeArquivoDeCodigo(linguagem, existentes: existentes);
      await atual.criar(nome, texto);
      if (!mounted) return;
      setState(() {
        salvando = false;
        status = 'Código salvo em Arquivos como $nome.txt (pasta isolada do app).';
      });
    } catch (falha) {
      if (!mounted) return;
      setState(() {
        salvando = false;
        erroTela = falha
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gerandoPrompt = tarefa.geraPrompt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programação', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Eyebrow('MODO PROGRAMAÇÃO'),
          const SizedBox(height: 8),
          const Text('Do pedido ao código',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
          const SizedBox(height: 7),
          const Text(
            'Criar, analisar, modificar e explicar erro, com uma área de código '
            'para colar e conferir. O JARVIS devolve texto; nada roda neste '
            'aparelho.',
            style: TextStyle(color: muted, height: 1.5, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Eyebrow('O QUE FAZER'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final valor in TarefaCodigo.values)
                ChoiceChip(
                  key: ValueKey('programacao-tarefa-${valor.name}'),
                  label: Text(valor.rotulo,
                      style: const TextStyle(fontSize: 11)),
                  selected: tarefa == valor,
                  onSelected: (_) => _trocarTarefa(valor),
                  selectedColor: cyan.withValues(alpha: .20),
                  labelStyle: TextStyle(
                      color: tarefa == valor ? cyan : muted,
                      fontSize: 11),
                  side: BorderSide(
                    color: tarefa == valor
                        ? cyan.withValues(alpha: .55)
                        : Colors.white12,
                  ),
                  backgroundColor: panel,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(tarefa.descricao,
              key: const ValueKey('programacao-tarefa-descricao'),
              style: const TextStyle(color: muted, fontSize: 10.5, height: 1.4)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('programacao-linguagem'),
            initialValue: linguagem.id,
            dropdownColor: panel,
            decoration: const InputDecoration(
              labelText: 'Linguagem',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final item in linguagensCodigo)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.nome, style: const TextStyle(fontSize: 12)),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() => linguagem = linguagemDe(id));
            },
          ),
          const SizedBox(height: 14),
          if (!gerandoPrompt && tarefa.usaCodigo) ...[
            _areaDeCodigo(),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const ValueKey('programacao-pedido'),
            controller: campoPedido,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: gerandoPrompt
                  ? 'Objetivo do código'
                  : tarefa.usaCodigo
                      ? 'O que você quer que aconteça'
                      : 'O que o código deve fazer',
              hintText: gerandoPrompt
                  ? 'uma planilha que soma horas trabalhadas'
                  : 'um script que renomeia fotos pela data',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          if (gerandoPrompt) ...[
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('programacao-restricoes'),
              controller: campoRestricoes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Restrições (opcional)',
                hintText: 'sem biblioteca externa, roda no celular',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (tarefa.usaErro) ...[
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('programacao-erro'),
              controller: campoErro,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
              decoration: const InputDecoration(
                labelText: 'Mensagem de erro',
                hintText: 'TypeError: cannot read property ...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('programacao-enviar'),
            onPressed: ocupado ? null : _executar,
            icon: Icon(
              gerandoPrompt ? Icons.edit_note_rounded : Icons.auto_awesome_rounded,
            ),
            label: Text(
              ocupado
                  ? 'Consultando…'
                  : gerandoPrompt
                      ? 'Montar prompt'
                      : 'Pedir ao JARVIS',
            ),
          ),
          if (erroTela != null) ...[
            const SizedBox(height: 12),
            Text(erroTela!,
                key: const ValueKey('programacao-erro-tela'),
                style: const TextStyle(
                    color: Color(0xFFFFC66D), fontSize: 11, height: 1.45)),
          ],
          if (resposta.isNotEmpty) ...[
            const SizedBox(height: 16),
            _resposta(),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(status,
                key: const ValueKey('programacao-status'),
                style: const TextStyle(color: cyan, fontSize: 11, height: 1.45)),
          ],
          const SizedBox(height: 16),
          _limites(),
        ],
      ),
    );
  }

  Widget _areaDeCodigo() {
    final linhas = campoCodigo.text.trim().isEmpty
        ? 0
        : campoCodigo.text.trim().split('\n').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('ÁREA DE CÓDIGO'),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('programacao-codigo'),
          controller: campoCodigo,
          minLines: 8,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'cole o código aqui',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '$linhas linha${linhas == 1 ? '' : 's'} · '
              '${campoCodigo.text.length} caracteres',
              key: const ValueKey('programacao-contador'),
              style: const TextStyle(color: muted, fontSize: 10),
            ),
            const Spacer(),
            TextButton.icon(
              key: const ValueKey('programacao-colar'),
              onPressed: _colarNaArea,
              icon: const Icon(Icons.content_paste_rounded, size: 16),
              label: const Text('Colar', style: TextStyle(fontSize: 10.5)),
            ),
            TextButton.icon(
              key: const ValueKey('programacao-limpar'),
              onPressed: () {
                campoCodigo.clear();
                setState(() {});
              },
              icon: const Icon(Icons.backspace_outlined, size: 16),
              label: const Text('Limpar', style: TextStyle(fontSize: 10.5)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resposta() {
    final explicacao = explicacaoSemCodigo(resposta);
    final paraSalvar = codigoParaArea(resposta);
    return Container(
      key: const ValueKey('programacao-resposta'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cyan.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('RESPOSTA'),
          if (explicacao.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              explicacao,
              style: const TextStyle(fontSize: 11.5, height: 1.5),
            ),
          ],
          for (var i = 0; i < blocos.length; i++) ...[
            const SizedBox(height: 10),
            Container(
              key: ValueKey('programacao-bloco-$i'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF03080F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cyan.withValues(alpha: .16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code_rounded, size: 13, color: cyan),
                      const SizedBox(width: 6),
                      Text(
                        blocos[i].linguagem.isEmpty
                            ? 'código'
                            : blocos[i].linguagem,
                        style: const TextStyle(color: cyan, fontSize: 10),
                      ),
                      const Spacer(),
                      Text('${blocos[i].linhas} linhas',
                          style:
                              const TextStyle(color: muted, fontSize: 9.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      blocos[i].codigo,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        key: ValueKey('programacao-copiar-$i'),
                        onPressed: () => _copiar(
                            blocos[i].codigo, 'Código copiado.'),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copiar',
                            style: TextStyle(fontSize: 10.5)),
                      ),
                      TextButton.icon(
                        key: ValueKey('programacao-usar-$i'),
                        onPressed: () {
                          campoCodigo.text = blocos[i].codigo;
                          setState(() => status =
                              'Código colocado na área de código.');
                        },
                        icon: const Icon(Icons.input_rounded, size: 15),
                        label: const Text('Usar na área',
                            style: TextStyle(fontSize: 10.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('programacao-copiar-resposta'),
                onPressed: () => _copiar(resposta, 'Resposta copiada.'),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Copiar resposta',
                    style: TextStyle(fontSize: 10.5)),
              ),
              OutlinedButton.icon(
                key: const ValueKey('programacao-salvar'),
                onPressed: salvando ? null : () => _salvar(paraSalvar),
                icon: const Icon(Icons.save_alt_rounded, size: 16),
                label: Text(
                  salvando ? 'Salvando…' : 'Salvar em Arquivos',
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Salvar grava um .txt na pasta isolada do app. O arquivo não vira '
            'programa e não é executado por ninguém.',
            style: TextStyle(color: muted, fontSize: 9.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _limites() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: panel.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LIMITES DESTE MODO',
                style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.3,
                    color: cyan,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final limite in limitesProgramacao)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: muted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        limite,
                        key: const ValueKey('programacao-limite'),
                        style: const TextStyle(
                            color: muted, fontSize: 10.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
