import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/visao.dart';
import '../ui_common.dart';
import 'provider_service.dart';
import 'visao_service.dart';

enum OrigemImagem { galeria, camera }

typedef EscolherImagem = Future<ImagemParaAnalise?> Function(OrigemImagem origem);

String _mimePorNome(String nome) {
  final minusculo = nome.toLowerCase();
  if (minusculo.endsWith('.png')) return 'image/png';
  if (minusculo.endsWith('.webp')) return 'image/webp';
  if (minusculo.endsWith('.jpg') || minusculo.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

/// Abre o seletor do sistema. A câmera só é acionada por toque; nada é lido em segundo plano.
Future<ImagemParaAnalise?> escolherImagemPadrao(OrigemImagem origem) async {
  final seletor = ImagePicker();
  final arquivo = await seletor.pickImage(
    source: origem == OrigemImagem.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 82,
  );
  if (arquivo == null) return null;
  final bytes = await arquivo.readAsBytes();
  return ImagemParaAnalise(
    bytes: Uint8List.fromList(bytes),
    mime: arquivo.mimeType ?? _mimePorNome(arquivo.name),
    nome: arquivo.name,
  );
}

class VisaoPage extends StatefulWidget {
  const VisaoPage({super.key, this.analisador, this.escolher});

  final AnalisadorVisao? analisador;
  final EscolherImagem? escolher;

  @override
  State<VisaoPage> createState() => _VisaoPageState();
}

class _VisaoPageState extends State<VisaoPage> {
  late final AnalisadorVisao analisador =
      widget.analisador ?? VisaoService(secrets: PlatformSecretStore());
  late final EscolherImagem escolher = widget.escolher ?? escolherImagemPadrao;
  final pergunta = TextEditingController();

  ImagemParaAnalise? imagem;
  String? provedor;
  bool carregandoProvedor = true;
  bool consentimento = false;
  bool analisando = false;
  String? resultado;
  String? erro;

  @override
  void initState() {
    super.initState();
    _consultarProvedor();
  }

  Future<void> _consultarProvedor() async {
    String? nome;
    try {
      nome = await analisador.provedorAtual();
    } catch (_) {
      nome = null;
    }
    if (!mounted) return;
    setState(() {
      provedor = nome;
      carregandoProvedor = false;
    });
  }

  Future<void> _escolher(OrigemImagem origem) async {
    setState(() => erro = null);
    try {
      final escolhida = await escolher(origem);
      if (escolhida == null) return;
      final recusa = validarImagemVisao(escolhida.bytes, escolhida.mime);
      if (recusa != null) {
        if (!mounted) return;
        setState(() => erro = recusa);
        return;
      }
      if (!mounted) return;
      setState(() {
        imagem = escolhida;
        consentimento = false;
        resultado = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = 'Não foi possível abrir a imagem: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  bool get podeAnalisar =>
      imagem != null && consentimento && !analisando && provedor != null;

  Future<void> _analisar() async {
    final escolhida = imagem;
    if (escolhida == null || !consentimento || analisando) return;
    setState(() {
      analisando = true;
      erro = null;
      resultado = null;
    });
    try {
      final texto = await analisador.analisar(imagem: escolhida, pergunta: pergunta.text);
      if (!mounted) return;
      setState(() {
        analisando = false;
        resultado = texto;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        analisando = false;
        erro = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  void dispose() {
    if (widget.analisador == null) analisador.fechar();
    pergunta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Visão de imagem')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('IMAGEM ESCOLHIDA POR VOCÊ', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text(
            'A imagem só é enviada depois da sua autorização. O app não guarda a foto, não '
            'identifica pessoas e não faz reconhecimento facial.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('escolher-galeria'),
                  onPressed: analisando ? null : () => _escolher(OrigemImagem.galeria),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Galeria'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('escolher-camera'),
                  onPressed: analisando ? null : () => _escolher(OrigemImagem.camera),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Câmera'),
                ),
              ),
            ],
          ),
          if (imagem != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imagem!.bytes,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Não foi possível mostrar a prévia, mas a análise pode continuar.'),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${imagem!.nome} · ${(imagem!.tamanho / 1024).toStringAsFixed(0)} kB',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: pergunta,
            enabled: !analisando,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'O que você quer saber sobre a imagem? (opcional)',
              hintText: 'Ex.: descreva a cena e leia os textos.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const ValueKey('consentimento-visao'),
            value: consentimento,
            onChanged: analisando ? null : (valor) => setState(() => consentimento = valor ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Autorizo enviar esta imagem ao provedor de IA selecionado.', style: TextStyle(fontSize: 12)),
            subtitle: const Text(
              'O provedor recebe a imagem apenas para esta análise. O app não mantém cópia.',
              style: TextStyle(fontSize: 10.5, color: muted, height: 1.35),
            ),
          ),
          if (carregandoProvedor)
            const Text('Verificando provedor com visão…', style: TextStyle(color: muted, fontSize: 11))
          else if (provedor == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC66D).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Nenhum provedor com visão está configurado. Cadastre a chave do Gemini, Groq, '
                'Mistral ou OpenRouter em Provedores de IA. Análise por modelo local ainda não existe.',
                style: TextStyle(color: Color(0xFFFFC66D), fontSize: 11, height: 1.4),
              ),
            )
          else
            Text('Análise por $provedor.', style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('analisar-imagem'),
            onPressed: podeAnalisar ? _analisar : null,
            icon: analisando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.visibility_rounded, size: 18),
            label: Text(analisando ? 'Analisando…' : 'Analisar imagem'),
          ),
          if (erro != null) ...[
            const SizedBox(height: 12),
            Text(erro!, style: TextStyle(color: colors.error, fontSize: 12, height: 1.4)),
          ],
          if (resultado != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Análise', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  SelectableText(resultado!, style: const TextStyle(fontSize: 13, height: 1.45)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Sem reconhecimento facial, sem identificação de pessoas e sem armazenamento da imagem. '
            'Textos e objetos são descritos pelo que está visível; se algo estiver ilegível, a '
            'resposta deve dizer que não sabe.',
            style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
