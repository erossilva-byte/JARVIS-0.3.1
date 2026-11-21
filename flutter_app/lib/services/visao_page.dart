import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/visao.dart';
import '../core/visao_estruturada.dart';
import '../ui_common.dart';
import 'consentimento_visao.dart';
import 'provider_service.dart';
import 'video_quadros.dart';
import 'visao_camera.dart';
import 'visao_imagem.dart';
import 'visao_service.dart';

enum OrigemImagem { galeria, camera }

typedef EscolherImagem = Future<ImagemParaAnalise?> Function(
    OrigemImagem origem);
typedef SalvarImagemGaleria = Future<void> Function(
    Uint8List bytes, String nome);
typedef SalvarVideoGaleria = Future<void> Function(String caminho);
typedef PrepararImagem = Future<ImagemParaAnalise> Function(
    Uint8List bytes, String nome);
typedef MedirImagem = Future<({int largura, int altura})> Function(
    Uint8List bytes);

class QuadroAnalisado {
  const QuadroAnalisado({
    required this.quadro,
    required this.imagem,
    required this.analise,
  });

  final QuadroVideo quadro;
  final ImagemParaAnalise imagem;
  final AnaliseVisao analise;
}

String _mimePorNome(String nome) {
  final minusculo = nome.toLowerCase();
  if (minusculo.endsWith('.png')) return 'image/png';
  if (minusculo.endsWith('.webp')) return 'image/webp';
  if (minusculo.endsWith('.jpg') || minusculo.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return 'application/octet-stream';
}

/// Abre o seletor do sistema para a galeria. A câmera ao vivo é interna.
Future<ImagemParaAnalise?> escolherImagemPadrao(OrigemImagem origem) async {
  final seletor = ImagePicker();
  final arquivo = await seletor.pickImage(
    source: origem == OrigemImagem.camera
        ? ImageSource.camera
        : ImageSource.gallery,
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
  const VisaoPage({
    super.key,
    this.analisador,
    this.escolher,
    this.camera,
    this.consentimentoInicial,
    this.salvarImagem,
    this.salvarVideo,
    this.prepararImagem,
    this.medirImagem,
    this.extratorQuadros,
  });

  final AnalisadorVisao? analisador;
  final EscolherImagem? escolher;
  final CameraVisao? camera;
  final bool? consentimentoInicial;
  final SalvarImagemGaleria? salvarImagem;
  final SalvarVideoGaleria? salvarVideo;
  final PrepararImagem? prepararImagem;
  final MedirImagem? medirImagem;
  final ExtratorQuadros? extratorQuadros;

  @override
  State<VisaoPage> createState() => _VisaoPageState();
}

class _VisaoPageState extends State<VisaoPage> with WidgetsBindingObserver {
  late final AnalisadorVisao analisador =
      widget.analisador ?? VisaoService(secrets: PlatformSecretStore());
  late final CameraVisao camera = widget.camera ?? CameraAoVivo();
  late final EscolherImagem escolher = widget.escolher ?? escolherImagemPadrao;
  late final PrepararImagem preparar = widget.prepararImagem ?? _prepararPadrao;
  late final MedirImagem medir = widget.medirImagem ?? dimensoesImagem;
  late final SalvarImagemGaleria salvarImagem =
      widget.salvarImagem ?? _salvarImagemPadrao;
  late final SalvarVideoGaleria salvarVideo =
      widget.salvarVideo ?? salvarVideoNaGaleria;
  late final ExtratorQuadros extratorQuadros =
      widget.extratorQuadros ?? ExtratorQuadrosAndroid();
  final pergunta = TextEditingController();

  ImagemParaAnalise? imagem;
  AnaliseVisao? analise;
  int? objetoSelecionado;
  int larguraImagem = 1;
  int alturaImagem = 1;
  String? provedor;
  bool carregandoProvedor = true;
  bool carregandoConsentimento = true;
  bool consentimento = false;
  bool analisando = false;
  bool salvando = false;
  bool cameraAberta = false;
  bool abrindoCamera = false;
  bool capturando = false;
  bool gravando = false;
  bool analisandoVideo = false;
  double zoom = 1;
  String? videoPath;
  int videoDuracaoMs = 0;
  int progressoVideo = 0;
  List<QuadroAnalisado> quadros = const [];
  DateTime? _videoInicio;
  String? erro;
  String? erroVideo;
  String? aviso;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consultarProvedor();
    unawaited(_carregarConsentimento());
  }

  Future<void> _carregarConsentimento() async {
    final valor = widget.consentimentoInicial ?? await ConsentimentoVisao.ler();
    if (!mounted) return;
    setState(() {
      consentimento = valor;
      carregandoConsentimento = false;
    });
  }

  Future<void> _definirConsentimento(bool valor) async {
    setState(() => consentimento = valor);
    await ConsentimentoVisao.salvar(valor);
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

  Future<ImagemParaAnalise> _prepararPadrao(Uint8List bytes, String nome) =>
      prepararImagemParaEnvio(bytes, nome: nome);

  Future<void> _salvarImagemPadrao(Uint8List bytes, String nome) =>
      salvarImagemNaGaleria(bytes, nome: nome);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (cameraAberta) {
        unawaited(_fecharCamera());
      }
    }
  }

  Future<void> _abrirCamera() async {
    if (!consentimento) {
      setState(() => erro =
          'Autorize o envio de imagens para a análise antes de abrir a câmera. A autorização fica salva e pode ser revogada.');
      return;
    }
    setState(() {
      abrindoCamera = true;
      erro = null;
      aviso = null;
    });
    await camera.inicializar();
    if (!mounted) return;
    setState(() {
      abrindoCamera = false;
      cameraAberta = camera.disponivel;
      zoom = camera.zoom;
      erro = camera.disponivel ? null : camera.erro;
      if (camera.disponivel) {
        imagem = null;
        analise = null;
        objetoSelecionado = null;
      }
    });
  }

  Future<void> _fecharCamera() async {
    await camera.liberar();
    if (!mounted) return;
    setState(() {
      cameraAberta = false;
      gravando = false;
      capturando = false;
    });
  }

  Future<void> _tirarFoto() async {
    if (capturando || gravando) return;
    setState(() {
      capturando = true;
      erro = null;
    });
    try {
      final bytes = await camera.tirarFoto();
      await camera.liberar();
      if (!mounted) return;
      setState(() => cameraAberta = false);
      await _receberBytes(bytes, 'foto.jpg', analisarAutomaticamente: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    } finally {
      if (mounted) setState(() => capturando = false);
    }
  }

  Future<void> _escolherGaleria() async {
    setState(() {
      erro = null;
      aviso = null;
    });
    try {
      final escolhida = await escolher(OrigemImagem.galeria);
      if (escolhida == null) return;
      await _receberBytes(escolhida.bytes, escolhida.nome,
          mime: escolhida.mime);
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    }
  }

  Future<void> _receberBytes(
    Uint8List bytes,
    String nome, {
    String mime = 'image/jpeg',
    bool analisarAutomaticamente = false,
  }) async {
    final recusa = validarImagemVisao(bytes, mime);
    if (recusa != null) throw StateError(recusa);
    final preparada = await preparar(bytes, nome);
    final dimensoes = await medir(preparada.bytes);
    if (!mounted) return;
    setState(() {
      imagem = preparada;
      larguraImagem = dimensoes.largura;
      alturaImagem = dimensoes.altura;
      analise = null;
      objetoSelecionado = null;
      erro = null;
      cameraAberta = false;
    });
    if (analisarAutomaticamente && consentimento && provedor != null) {
      await _analisar();
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
      aviso = null;
      analise = null;
      objetoSelecionado = null;
    });
    try {
      final texto =
          await analisador.analisar(imagem: escolhida, pergunta: pergunta.text);
      final lida = interpretarAnaliseVisao(texto);
      if (lida.vazia) {
        throw StateError(
            'O provedor não devolveu uma descrição da imagem. Tente de novo.');
      }
      if (!mounted) return;
      setState(() {
        analisando = false;
        analise = lida;
        if (!lida.estruturada || !lida.temObjetosComCaixa) {
          aviso =
              'A resposta não trouxe caixas de objetos; a análise aparece como texto, sem balões.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        analisando = false;
        erro = _mensagem(e);
      });
    }
  }

  bool get podeAnalisarVideo =>
      videoPath != null &&
      consentimento &&
      !analisandoVideo &&
      provedor != null;

  Future<void> _analisarVideo() async {
    final caminho = videoPath;
    if (caminho == null || !consentimento || analisandoVideo) return;
    setState(() {
      analisandoVideo = true;
      erroVideo = null;
      erro = null;
      aviso = null;
      quadros = const [];
      progressoVideo = 0;
    });
    try {
      final extraido = await extratorQuadros.extrair(caminho, maximo: 6);
      if (!mounted) return;
      setState(() => videoDuracaoMs = extraido.duracaoMs);
      final resultados = <QuadroAnalisado>[];
      var falhas = 0;
      for (var i = 0; i < extraido.quadros.length; i++) {
        if (!mounted) return;
        setState(() => progressoVideo = i + 1);
        final quadro = extraido.quadros[i];
        try {
          final preparada = await preparar(
            quadro.bytes,
            'quadro-${i + 1}.jpg',
          );
          final texto = await analisador.analisar(
            imagem: preparada,
            pergunta: pergunta.text,
          );
          final lida = interpretarAnaliseVisao(texto);
          if (lida.vazia) {
            throw StateError('O provedor não descreveu este quadro.');
          }
          resultados.add(QuadroAnalisado(
            quadro: quadro,
            imagem: preparada,
            analise: lida,
          ));
          if (!mounted) return;
          setState(() => quadros = List.unmodifiable(resultados));
        } catch (_) {
          falhas++;
        }
      }
      if (!mounted) return;
      if (resultados.isEmpty) {
        throw StateError('Nenhum quadro pôde ser analisado. Tente de novo.');
      }
      setState(() {
        analisandoVideo = false;
        aviso = falhas == 0
            ? '${resultados.length} quadros analisados. Toque em um instante para ver os balões.'
            : '${resultados.length} quadros analisados; $falhas não puderam ser lidos.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        analisandoVideo = false;
        erroVideo = _mensagem(e);
      });
    }
  }

  void _mostrarQuadro(int indice) {
    if (indice < 0 || indice >= quadros.length) return;
    final item = quadros[indice];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Quadro ${item.quadro.tempo}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${item.analise.objetos.length} objeto(s)',
                      style: const TextStyle(color: muted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .42,
                child: _ImagemComBaloes(
                  bytes: item.imagem.bytes,
                  analise: item.analise,
                  largura: item.quadro.largura,
                  altura: item.quadro.altura,
                  onObjeto: _detalhar,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(item.analise.textoExibicao,
                  style: const TextStyle(fontSize: 13, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _alternarGravacao() async {
    if (capturando) return;
    setState(() => erro = null);
    try {
      if (!gravando) {
        await camera.iniciarVideo();
        if (!mounted) return;
        _videoInicio = DateTime.now();
        setState(() => gravando = true);
        return;
      }
      final caminho = await camera.pararVideo();
      final duracao = DateTime.now()
          .difference(_videoInicio ?? DateTime.now())
          .inMilliseconds;
      if (!mounted) return;
      setState(() {
        gravando = false;
        videoPath = caminho;
        videoDuracaoMs = duracao;
        quadros = const [];
        erroVideo = null;
        progressoVideo = 0;
      });
      await salvarVideo(caminho);
      if (!mounted) return;
      setState(() => aviso =
          'Vídeo salvo na galeria. Toque em “Analisar quadros” para ver a linha do tempo.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        gravando = false;
        erro = _mensagem(e);
      });
    }
  }

  Future<void> _alternarFlash() async {
    try {
      await camera.alternarFlash();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    }
  }

  Future<void> _definirZoom(double valor) async {
    setState(() => zoom = valor);
    try {
      await camera.definirZoom(valor);
    } catch (_) {
      // O zoom pode não existir em câmeras virtuais; não interrompe a captura.
    }
  }

  Future<void> _salvar({required bool comBaloes}) async {
    final escolhida = imagem;
    if (escolhida == null || salvando) return;
    setState(() {
      salvando = true;
      erro = null;
      aviso = null;
    });
    try {
      final bytes = comBaloes && analise != null
          ? await imagemComBaloes(bytes: escolhida.bytes, analise: analise!)
          : escolhida.bytes;
      await salvarImagem(
          bytes, comBaloes ? 'jarvis-visao-baloes' : 'jarvis-visao');
      if (!mounted) return;
      setState(() => aviso = comBaloes
          ? 'Imagem com os balões salva na galeria.'
          : 'Imagem salva na galeria.');
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = _mensagem(e));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  void _detalhar(ObjetoVisao objeto) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(objeto.rotulo,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            if (objeto.confianca != null) ...[
              const SizedBox(height: 4),
              Text('Confiança informada: ${(objeto.confianca! * 100).round()}%',
                  style: const TextStyle(color: muted, fontSize: 11)),
            ],
            const SizedBox(height: 12),
            Text(
              (objeto.detalhe ?? '').trim().isEmpty
                  ? 'O modelo não detalhou este objeto.'
                  : objeto.detalhe!,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pessoas aparecem apenas como “Pessoa”. O app não reconhece rosto nem identifica quem está na imagem.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _mensagem(Object e) {
    final texto = e
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
    if (texto.contains('SocketException') ||
        texto.contains('ClientException')) {
      return 'Não foi possível alcançar o provedor. Verifique a conexão.';
    }
    return texto;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.analisador == null) analisador.fechar();
    unawaited(camera.liberar());
    pergunta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão'),
        actions: [
          if (cameraAberta)
            IconButton(
              tooltip: 'Fechar câmera',
              onPressed: _fecharCamera,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('VISÃO SEGURA',
              style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text(
            'Câmera ao vivo para descrever objetos, ler textos e apontar onde cada coisa está. '
            'A foto é analisada uma vez; o app não guarda a imagem e não faz reconhecimento facial.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          _cartaoConsentimento(),
          if (carregandoConsentimento) ...[
            const SizedBox(height: 6),
            const Text('Carregando sua autorização…',
                style: TextStyle(color: muted, fontSize: 10.5)),
          ],
          const SizedBox(height: 14),
          if (cameraAberta) ...[
            _previaCamera(colors),
            const SizedBox(height: 10),
            _controlesCamera(),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('abrir-camera'),
                    onPressed: abrindoCamera ? null : _abrirCamera,
                    icon: abrindoCamera
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera_rounded, size: 18),
                    label: Text(abrindoCamera ? 'Abrindo…' : 'Abrir câmera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('escolher-galeria'),
                    onPressed: analisando ? null : _escolherGaleria,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Galeria'),
                  ),
                ),
              ],
            ),
          ],
          if (imagem != null) ...[
            const SizedBox(height: 14),
            _imagemComBaloes(colors),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('salvar-foto'),
                    onPressed:
                        salvando ? null : () => _salvar(comBaloes: false),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Salvar foto'),
                  ),
                ),
                if (analise?.temObjetosComCaixa == true) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('salvar-baloes'),
                      onPressed:
                          salvando ? null : () => _salvar(comBaloes: true),
                      icon: const Icon(Icons.label_important_outline_rounded,
                          size: 17),
                      label: const Text('Salvar com balões'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${imagem!.nome} · ${(imagem!.tamanho / 1024).toStringAsFixed(0)} kB · '
              '$larguraImagem×$alturaImagem',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
          if (videoPath != null) ...[
            const SizedBox(height: 14),
            _videoCard(),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: pergunta,
            enabled: !analisando && !analisandoVideo,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'O que você quer saber sobre a imagem? (opcional)',
              hintText: 'Ex.: descreva a cena e leia os textos.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (carregandoProvedor)
            const Text('Verificando provedor com visão…',
                style: TextStyle(color: muted, fontSize: 11))
          else if (provedor == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC66D).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Nenhum provedor com visão está configurado. Cadastre a chave do Gemini, Groq, '
                'Mistral ou OpenRouter em Provedores de IA. A câmera e o salvamento continuam funcionando.',
                style: TextStyle(
                    color: Color(0xFFFFC66D), fontSize: 11, height: 1.4),
              ),
            )
          else
            Text('Análise por $provedor.',
                style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('analisar-imagem'),
            onPressed: podeAnalisar ? _analisar : null,
            icon: analisando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.visibility_rounded, size: 18),
            label: Text(analisando ? 'Analisando…' : 'Analisar imagem'),
          ),
          if (analisando) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 6),
            const Text(
                'O provedor está descrevendo a imagem. Isso pode levar alguns segundos.',
                style: TextStyle(color: muted, fontSize: 10.5)),
          ],
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Text(aviso!,
                style: const TextStyle(
                    color: Color(0xFFFFC66D), fontSize: 11.5, height: 1.4)),
          ],
          if (erro != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.error.withValues(alpha: .25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(erro!,
                      style: TextStyle(
                          color: colors.error, fontSize: 12, height: 1.4)),
                  if (imagem != null)
                    TextButton(
                      onPressed: analisando ? null : _analisar,
                      child: const Text('Tentar de novo'),
                    ),
                ],
              ),
            ),
          ],
          if (analise != null) ...[
            const SizedBox(height: 16),
            _resultado(colors),
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

  Widget _cartaoConsentimento() {
    return Container(
      key: const ValueKey('consentimento-visao'),
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cyan.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: cyan, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Autorizo enviar esta imagem ao provedor de IA selecionado.',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A autorização fica salva nas configurações e vale para as próximas fotos. '
                  'Você pode revogar a qualquer momento. O app não guarda a foto e não mantém cópia.',
                  style: TextStyle(fontSize: 10.5, color: muted, height: 1.35),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey('switch-consentimento'),
            value: consentimento,
            onChanged: carregandoConsentimento ? null : _definirConsentimento,
          ),
        ],
      ),
    );
  }

  Widget _previaCamera(ColorScheme colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              camera.construirPreview(),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gravando ? 'GRAVANDO' : 'CÂMERA AO VIVO',
                    style: TextStyle(
                      color: gravando ? colors.error : cyan,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (capturando)
                Container(
                  color: Colors.black.withValues(alpha: .45),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlesCamera() {
    final temOutraCamera = camera.totalCameras > 1;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              key: const ValueKey('trocar-camera'),
              tooltip: 'Trocar câmera',
              onPressed: gravando || !temOutraCamera
                  ? null
                  : () async {
                      try {
                        await camera.alternarCamera();
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (mounted) setState(() => erro = _mensagem(e));
                      }
                    },
              icon: const Icon(Icons.cameraswitch_rounded),
            ),
            IconButton(
              key: const ValueKey('flash-camera'),
              tooltip: 'Flash',
              onPressed: gravando || !camera.temFlash ? null : _alternarFlash,
              icon: Icon(camera.flashLigado
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded),
            ),
            FilledButton(
              key: const ValueKey('capturar-foto'),
              onPressed: capturando || gravando ? null : _tirarFoto,
              style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18)),
              child: const Icon(Icons.camera_alt_rounded),
            ),
            IconButton(
              key: const ValueKey('gravar-video'),
              tooltip: gravando ? 'Parar gravação' : 'Gravar vídeo',
              onPressed: capturando ? null : _alternarGravacao,
              icon: Icon(
                  gravando ? Icons.stop_circle_rounded : Icons.videocam_rounded,
                  color: gravando ? const Color(0xFFFF8A80) : null),
            ),
            IconButton(
              key: const ValueKey('fechar-camera'),
              tooltip: 'Fechar câmera',
              onPressed: gravando ? null : _fecharCamera,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.zoom_out_rounded, size: 17, color: muted),
            Expanded(
              child: Slider(
                key: const ValueKey('zoom-camera'),
                value: zoom.clamp(1.0, camera.zoomMax),
                min: 1,
                max: camera.zoomMax <= 1 ? 1.01 : camera.zoomMax,
                onChanged: gravando ? null : (valor) => _definirZoom(valor),
              ),
            ),
            const Icon(Icons.zoom_in_rounded, size: 17, color: muted),
          ],
        ),
        if (camera.erro != null)
          Text(camera.erro!,
              style: const TextStyle(color: Color(0xFFFFC66D), fontSize: 10.5)),
        const Text(
          'O vídeo é gravado e salvo na galeria. Depois de parar, use “Analisar quadros” para ver até 6 instantes com balões.',
          style: TextStyle(color: muted, fontSize: 10, height: 1.35),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _imagemComBaloes(ColorScheme colors) => _ImagemComBaloes(
        bytes: imagem!.bytes,
        analise: analise,
        largura: larguraImagem,
        altura: alturaImagem,
        analisando: analisando,
        onObjeto: _detalhar,
      );

  Widget _videoCard() {
    final path = videoPath;
    if (path == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cyan.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_file_rounded, color: cyan, size: 20),
              const SizedBox(width: 8),
              const Text('VÍDEO GRAVADO',
                  style: TextStyle(
                      color: cyan,
                      fontSize: 9,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(formatarTempoVideo(videoDuracaoMs),
                  style: const TextStyle(color: muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quadros.isEmpty
                ? 'O vídeo foi salvo na galeria. A análise usa até 6 quadros distribuídos na duração.'
                : '${quadros.length} quadros analisados. Toque em um instante para abrir a imagem com balões.',
            style: const TextStyle(color: muted, fontSize: 10.5, height: 1.35),
          ),
          const SizedBox(height: 9),
          FilledButton.icon(
            key: const ValueKey('analisar-video'),
            onPressed: podeAnalisarVideo ? _analisarVideo : null,
            icon: analisandoVideo
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.timeline_rounded, size: 17),
            label: Text(analisandoVideo
                ? 'Analisando quadro $progressoVideo…'
                : 'Analisar quadros'),
          ),
          if (analisandoVideo) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 4),
            const Text('Cada quadro é enviado separadamente ao provedor.',
                style: TextStyle(color: muted, fontSize: 9.5)),
          ],
          if (erroVideo != null) ...[
            const SizedBox(height: 8),
            Text(erroVideo!,
                style: const TextStyle(
                    color: Color(0xFFFF8A80), fontSize: 11, height: 1.35)),
          ],
          for (var i = 0; i < quadros.length; i++) ...[
            const SizedBox(height: 7),
            InkWell(
              key: ValueKey('quadro-$i'),
              borderRadius: BorderRadius.circular(9),
              onTap: () => _mostrarQuadro(i),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: SizedBox(
                        width: 82,
                        height: 58,
                        child: Image.memory(
                          quadros[i].imagem.bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF0B1420)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(quadros[i].quadro.tempo,
                              style: const TextStyle(
                                  color: cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            quadros[i].analise.resumo.trim().isEmpty
                                ? 'Quadro analisado'
                                : quadros[i].analise.resumo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, height: 1.3),
                          ),
                          Text(
                            '${quadros[i].analise.objetos.length} objeto(s) · toque para ver',
                            style: const TextStyle(color: muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: muted, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultado(ColorScheme colors) {
    final atual = analise!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Análise',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          if (atual.resumo.trim().isNotEmpty)
            SelectableText(atual.resumo,
                style: const TextStyle(fontSize: 13, height: 1.45)),
          if (atual.objetos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < atual.objetos.length; i++)
                  ActionChip(
                    label: Text(atual.objetos[i].rotulo,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () => _detalhar(atual.objetos[i]),
                  ),
              ],
            ),
          ],
          if (atual.textoLegivel.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText('Texto legível: ${atual.textoLegivel.join(' · ')}',
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ImagemComBaloes extends StatelessWidget {
  const _ImagemComBaloes({
    required this.bytes,
    required this.analise,
    required this.largura,
    required this.altura,
    required this.onObjeto,
    this.analisando = false,
  });

  final Uint8List bytes;
  final AnaliseVisao? analise;
  final int largura;
  final int altura;
  final ValueChanged<ObjetoVisao> onObjeto;
  final bool analisando;

  @override
  Widget build(BuildContext context) {
    final proporcao = largura <= 0 || altura <= 0 ? 4 / 3 : largura / altura;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: proporcao,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final baloes = analise == null
                ? const <BalaoVisao>[]
                : layoutBaloesVisao(
                    analise!.objetos,
                    largura: constraints.maxWidth,
                    altura: constraints.maxHeight,
                  );
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF0B1420),
                    child: Center(
                      child: Text(
                          'Não foi possível mostrar a prévia, mas a análise pode continuar.',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ),
                if (baloes.any((b) => b.linha != null))
                  IgnorePointer(
                    child: CustomPaint(painter: _LinhasGuiaPainter(baloes)),
                  ),
                for (final balao in baloes)
                  if (!balao.semCaixa)
                    Positioned(
                      key: ValueKey('posicao-balao-${balao.indice}'),
                      left: (balao.x / 100) * constraints.maxWidth -
                          balao.largura / 2,
                      top: (balao.y / 100) * constraints.maxHeight -
                          balao.altura / 2,
                      child: _Balao(
                        key: ValueKey('balao-${balao.indice}'),
                        objeto: analise!.objetos[balao.indice],
                        colisao: balao.colisao,
                        onTap: () => onObjeto(analise!.objetos[balao.indice]),
                      ),
                    ),
                if (analisando)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: .45),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Analisando a imagem…'),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Balao extends StatelessWidget {
  const _Balao({
    super.key,
    required this.objeto,
    required this.colisao,
    required this.onTap,
  });

  final ObjetoVisao objeto;
  final bool colisao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colisao ? const Color(0xFFFFC66D) : cyan,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  objeto.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF041018),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (objeto.confianca != null) ...[
                const SizedBox(width: 4),
                Text('${(objeto.confianca! * 100).round()}%',
                    style: const TextStyle(
                        color: Color(0xFF041018), fontSize: 8.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhasGuiaPainter extends CustomPainter {
  _LinhasGuiaPainter(this.baloes);

  final List<BalaoVisao> baloes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cyan.withValues(alpha: .72)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final balao in baloes) {
      final linha = balao.linha;
      if (linha == null) continue;
      canvas.drawLine(
        Offset(linha.x1 / 100 * size.width, linha.y1 / 100 * size.height),
        Offset(linha.x2 / 100 * size.width, linha.y2 / 100 * size.height),
        paint,
      );
      canvas.drawCircle(
        Offset(linha.x2 / 100 * size.width, linha.y2 / 100 * size.height),
        2.5,
        Paint()..color = cyan,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinhasGuiaPainter oldDelegate) =>
      oldDelegate.baloes != baloes;
}
