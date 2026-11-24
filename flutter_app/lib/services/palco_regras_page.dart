import 'package:material_ui/material_ui.dart';

import '../core/palco.dart';
import '../ui_common.dart';

/// Nome na tela para cada moldura do palco.
String rotuloDaMoldura(MolduraPalco tipo) => switch (tipo) {
      MolduraPalco.capaLarga => 'Foto larga',
      MolduraPalco.retratoAlto => 'Foto em pé',
      MolduraPalco.quadrada => 'Foto quase quadrada',
      MolduraPalco.capaVideo => 'Vídeo',
      MolduraPalco.capaNoticia => 'Notícia',
      MolduraPalco.semImagem => 'Sem imagem',
    };

IconData iconeDaMoldura(MolduraPalco tipo) => switch (tipo) {
      MolduraPalco.capaLarga => Icons.landscape_rounded,
      MolduraPalco.retratoAlto => Icons.height_rounded,
      MolduraPalco.quadrada => Icons.crop_square_rounded,
      MolduraPalco.capaVideo => Icons.play_circle_outline_rounded,
      MolduraPalco.capaNoticia => Icons.newspaper_rounded,
      MolduraPalco.semImagem => Icons.image_not_supported_outlined,
    };

/// Prévia da moldura, desenhada no próprio aparelho.
///
/// Nada é pedido à rede: o retângulo é um desenho (gradiente + ícone), então a
/// prévia funciona sem internet e não baixa nada.
class PreviaMoldura extends StatelessWidget {
  const PreviaMoldura({
    super.key,
    required this.tipo,
    required this.regra,
    this.alturaTela,
  });

  final MolduraPalco tipo;
  final RegraMoldura regra;
  final double? alturaTela;

  double get proporcao => switch (tipo) {
        MolduraPalco.retratoAlto => 3 / 4,
        MolduraPalco.quadrada => 1,
        _ => 16 / 9,
      };

  @override
  Widget build(BuildContext context) {
    final tela = alturaTela ?? MediaQuery.sizeOf(context).height;
    final altura = (tela * regra.alturaLimitada).clamp(80.0, 260.0);
    return Container(
      key: const ValueKey('previa-caixa'),
      height: altura,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1725),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cyan.withValues(alpha: .35)),
      ),
      child: regra.cabeInteira
          ? Center(
              child: AspectRatio(
                aspectRatio: proporcao,
                child: _Desenho(tipo: tipo),
              ),
            )
          : _Desenho(tipo: tipo),
    );
  }
}

class _Desenho extends StatelessWidget {
  const _Desenho({required this.tipo});

  final MolduraPalco tipo;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF12304A), Color(0xFF1D4A66)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconeDaMoldura(tipo), color: cyan, size: 26),
              const SizedBox(height: 6),
              Text(
                'prévia desenhada',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 9.5,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Editor das regras de enquadramento: altura e recorte por tipo de mídia,
/// mais os limiares que classificam a foto. Devolve [RegrasPalco] ao salvar.
class PalcoRegrasPage extends StatefulWidget {
  const PalcoRegrasPage({super.key, required this.regras});

  final RegrasPalco regras;

  @override
  State<PalcoRegrasPage> createState() => _PalcoRegrasPageState();
}

class _PalcoRegrasPageState extends State<PalcoRegrasPage> {
  static const _tipos = [
    MolduraPalco.capaLarga,
    MolduraPalco.retratoAlto,
    MolduraPalco.quadrada,
    MolduraPalco.capaVideo,
    MolduraPalco.capaNoticia,
  ];

  late RegrasPalco atual = widget.regras;
  MolduraPalco tipo = MolduraPalco.capaLarga;

  RegraMoldura get regra => atual.regraDe(tipo);

  bool get _eImagem => tipo != MolduraPalco.capaVideo &&
      tipo != MolduraPalco.capaNoticia;

  void _mudarAltura(double valor) => setState(() {
        atual = atual.comRegra(tipo, regra.copiarCom(altura: valor));
      });

  void _mudarRecorte(bool inteira) => setState(() {
        atual = atual.comRegra(tipo, regra.copiarCom(cabeInteira: inteira));
      });

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regras do palco', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          const Eyebrow('PALCO · ENQUADRAMENTO'),
          const SizedBox(height: 7),
          const Text('Você decide como a mídia aparece',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w300)),
          const SizedBox(height: 6),
          const Text(
            'Cada tipo de mídia tem a sua regra: quanto da tela ocupa e se '
            'mostra a imagem inteira ou recorta para preencher. A prévia abaixo '
            'é desenhada no aparelho — funciona sem internet e não baixa nada.',
            style: TextStyle(color: muted, height: 1.5, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rotuloDaMoldura(tipo)} · '
                  '${(regra.alturaLimitada * 100).round()}% da tela · '
                  '${regra.cabeInteira ? 'inteira' : 'recortada'}',
                  key: const ValueKey('previa-legenda'),
                  style: const TextStyle(fontSize: 11, color: cyan),
                ),
                const SizedBox(height: 8),
                PreviaMoldura(
                  key: const ValueKey('previa-moldura'),
                  tipo: tipo,
                  regra: regra,
                  alturaTela: tela.height,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final opcao in _tipos)
                ChoiceChip(
                  key: ValueKey('regra-tipo-${opcao.name}'),
                  avatar: Icon(iconeDaMoldura(opcao), size: 15),
                  label: Text(rotuloDaMoldura(opcao)),
                  selected: tipo == opcao,
                  onSelected: (_) => setState(() => tipo = opcao),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Altura: ${(regra.alturaLimitada * 100).round()}% da tela',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const ValueKey('regra-altura'),
            value: regra.alturaLimitada,
            min: RegraMoldura.alturaMinima,
            max: RegraMoldura.alturaMaxima,
            divisions: 47,
            label: '${(regra.alturaLimitada * 100).round()}%',
            onChanged: _mudarAltura,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('regra-recorte'),
                label: const Text('Preencher (recorta)'),
                selected: !regra.cabeInteira,
                onSelected: (_) => _mudarRecorte(false),
              ),
              ChoiceChip(
                key: const ValueKey('regra-inteira'),
                label: const Text('Mostrar inteira'),
                selected: regra.cabeInteira,
                onSelected: (_) => _mudarRecorte(true),
              ),
            ],
          ),
          if (_eImagem) ...[
            const SizedBox(height: 18),
            const Text('Quando a foto é larga ou em pé',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Capa larga a partir de '
              '${atual.limiarLargo.toStringAsFixed(1)}:1 — em pé até '
              '${atual.limiarEstreito.toStringAsFixed(2)}:1. Entre os dois, a '
              'foto usa a moldura quase quadrada.',
              style: const TextStyle(color: muted, fontSize: 10.5, height: 1.4),
            ),
            Slider(
              key: const ValueKey('regra-limiar-largo'),
              value: atual.limiarLargo,
              min: RegrasPalco.limiarLargoMinimo,
              max: RegrasPalco.limiarLargoMaximo,
              divisions: 28,
              label: '${atual.limiarLargo.toStringAsFixed(1)}:1',
              onChanged: (valor) =>
                  setState(() => atual = atual.copiarCom(limiarLargo: valor)),
            ),
            Slider(
              key: const ValueKey('regra-limiar-estreito'),
              value: atual.limiarEstreito,
              min: RegrasPalco.limiarEstreitoMinimo,
              max: RegrasPalco.limiarEstreitoMaximo,
              divisions: 45,
              label: '${atual.limiarEstreito.toStringAsFixed(2)}:1',
              onChanged: (valor) =>
                  setState(() => atual = atual.copiarCom(limiarEstreito: valor)),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('regra-salvar'),
            onPressed: () => Navigator.of(context).pop(atual),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salvar regras'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('regra-padrao'),
            onPressed: () => setState(() => atual = RegrasPalco.padrao),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Voltar ao padrão'),
          ),
          const SizedBox(height: 14),
          const Text(
            'As regras valem para o palco deste aparelho e ficam guardadas '
            'aqui. A altura nunca passa de 62% da tela; a prévia mostra o '
            'tamanho relativo, não o tamanho exato em centímetros.',
            style: TextStyle(color: muted, fontSize: 10, height: 1.45),
          ),
        ],
      ),
    );
  }
}
