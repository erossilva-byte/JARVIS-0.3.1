import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../ui_common.dart';
import 'consumo_nucleo.dart';
import 'medicao_nucleo.dart';
import 'nucleo_controle.dart';
import 'nucleo_previa.dart';

/// Liga o núcleo flutuante e ajusta tamanho e ritmo do teletransporte.
///
/// A janela é do Android, por cima dos outros apps. Esta tela não desenha o
/// núcleo no sistema: mostra a prévia e manda as escolhas para o serviço.
class NucleoPage extends StatefulWidget {
  const NucleoPage({super.key});

  @override
  State<NucleoPage> createState() => _NucleoPageState();
}

class _NucleoPageState extends State<NucleoPage> {
  bool carregando = true;
  bool ativo = false;
  bool permissao = false;
  bool pausado = false;
  bool economico = false;
  int tamanho = 112;
  int intervalo = 7;
  String aviso = '';
  MedicaoNucleo medicao = const MedicaoNucleo();
  ConsumoNucleo consumo = const ConsumoNucleo();

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_carregar));
  }

  Future<void> _carregar() async {
    try {
      final estado = await NucleoControle.estado();
      if (!mounted) return;
      setState(() {
        ativo = estado.ativo;
        permissao = estado.permissao;
        pausado = estado.pausado;
        economico = estado.economico;
        tamanho = estado.tamanho.clamp(72, 160);
        intervalo = (estado.intervalo / 1000).round().clamp(4, 12);
        carregando = false;
        aviso = '';
      });
      unawaited(_atualizarMedicao());
      unawaited(_atualizarConsumo());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        aviso = 'Este aparelho não expõe o núcleo flutuante.';
      });
    }
  }

  Future<void> _alternar(bool ligar) async {
    try {
      final estado = ligar
          ? await NucleoControle.iniciar(
              tamanho: tamanho,
              intervalo: intervalo * 1000,
              economico: economico)
          : await NucleoControle.parar();
      if (!mounted) return;
      setState(() {
        ativo = estado.ativo;
        permissao = estado.permissao;
        pausado = estado.pausado;
        economico = estado.economico;
        if (ligar && !estado.ativo) {
          aviso = estado.motivo == 'sem_permissao'
              ? 'Para o núcleo aparecer por cima dos outros apps, autorize '
                  '“Exibir sobre outros apps”.'
              : 'Não consegui mostrar o núcleo neste aparelho.';
        } else {
          aviso = '';
        }
      });
      unawaited(_atualizarMedicao());
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui falar com o serviço do núcleo.');
    }
  }

  Future<void> _aplicarConfiguracao() async {
    if (!ativo) return;
    try {
      final estado = await NucleoControle.iniciar(
          tamanho: tamanho, intervalo: intervalo * 1000, economico: economico);
      if (!mounted) return;
      setState(() {
        ativo = estado.ativo;
        pausado = estado.pausado;
      });
      unawaited(_atualizarMedicao());
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui aplicar o novo tamanho.');
    }
  }

  Future<void> _alternarPausa() async {
    final novo = !pausado;
    setState(() => pausado = novo);
    try {
      final estado = await NucleoControle.definirPausado(novo);
      if (!mounted) return;
      setState(() {
        pausado = estado.pausado;
        ativo = estado.ativo;
        aviso = '';
      });
      unawaited(_atualizarMedicao());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        pausado = !novo;
        aviso = 'Não consegui pausar o núcleo.';
      });
    }
  }

  Future<void> _alternarEconomico(bool ligar) async {
    setState(() => economico = ligar);
    try {
      final estado = await NucleoControle.definirEconomico(ligar);
      if (!mounted) return;
      setState(() {
        economico = estado.economico;
        ativo = estado.ativo;
      });
      unawaited(_atualizarMedicao());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        economico = !ligar;
        aviso = 'Não consegui mudar o modo econômico.';
      });
    }
  }

  Future<void> _atualizarMedicao() async {
    try {
      final nova = await NucleoControle.medicao();
      if (!mounted) return;
      setState(() => medicao = nova);
    } catch (_) {
      // Sem medição, a seção fica com o último valor; não vira erro da tela.
    }
  }

  Future<void> _zerarMedicao() async {
    try {
      final nova = await NucleoControle.zerarMedicao();
      if (!mounted) return;
      setState(() => medicao = nova);
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui zerar a medição.');
    }
  }

  String _textoDiferenca() {
    final diferenca = medicao.diferencaPercentual;
    if (diferenca == null) return 'Sem amostra dos dois modos ainda.';
    if (!medicao.conclusiva) {
      return 'Amostra curta: ainda não dá para concluir. Deixe o núcleo '
          'alguns segundos em cada modo.';
    }
    return 'Diferença medida: ${diferenca.toStringAsFixed(0)}% de quadros por '
        'segundo (negativo = menos no econômico). É redução de trabalho, não '
        'número de bateria.';
  }

  Future<void> _atualizarConsumo() async {
    try {
      final novo = await NucleoControle.consumo();
      if (!mounted) return;
      setState(() => consumo = novo);
    } catch (_) {
      // Sem leitura, fica a última amostra; não vira erro da tela.
    }
  }

  Future<void> _iniciarConsumo() async {
    try {
      final novo = await NucleoControle.iniciarConsumo();
      if (!mounted) return;
      setState(() {
        consumo = novo;
        aviso = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui iniciar a medição de consumo.');
    }
  }

  Future<void> _pararConsumo() async {
    try {
      final novo = await NucleoControle.pararConsumo();
      if (!mounted) return;
      setState(() => consumo = novo);
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui parar a medição de consumo.');
    }
  }

  Future<void> _zerarConsumo() async {
    try {
      final novo = await NucleoControle.zerarConsumo();
      if (!mounted) return;
      setState(() => consumo = novo);
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui zerar a medição de consumo.');
    }
  }

  String _textoAmostra(AmostraConsumo? amostra) {
    if (amostra == null) return 'sem amostra';
    final cpu = '${amostra.cpuMsPorSegundo.toStringAsFixed(1)} ms de CPU/s';
    final bateria = amostra.bateriaPorHora == null
        ? 'bateria sem queda medível'
        : '${amostra.bateriaPorHora!.toStringAsFixed(2)}%/h';
    final janela = '${(amostra.duracaoMs / 1000).toStringAsFixed(0)} s';
    final motivo = amostra.conclusiva ? '' : ' · ${amostra.motivoInconclusivo}';
    return '$cpu · $bateria · $janela$motivo';
  }

  String _textoDiferencaConsumo() {
    final diferenca = consumo.diferencaCpuPercentual;
    if (diferenca == null) {
      return 'Meça uma janela em cada modo para comparar.';
    }
    if (!consumo.comparacaoConclusiva) {
      return 'CPU: ${diferenca.toStringAsFixed(0)}% no econômico, mas alguma '
          'amostra não conclui — repita com janelas de pelo menos 20 s.';
    }
    return 'CPU: ${diferenca.toStringAsFixed(0)}% no econômico (negativo = '
        'menos trabalho).';
  }

  Future<void> _teleportar() async {
    try {
      final foi = await NucleoControle.teleportar();
      if (!mounted || foi) return;
      setState(() => aviso = 'O núcleo não está na tela.');
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui falar com o serviço do núcleo.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Núcleo flutuante', style: TextStyle(fontSize: 15)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Eyebrow('NÚCLEO FLUTUANTE'),
            const SizedBox(height: 8),
            const Text('Um núcleo 3D solto na tela',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
            const SizedBox(height: 7),
            const Text(
              'Como os mascotes de desktop: ele fica pequeno por cima dos '
              'outros apps, gira, brilha e some para reaparecer em outro ponto. '
              'A esfera é calculada no aparelho — não é vídeo nem imagem.',
              style: TextStyle(color: muted, height: 1.5, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF03080F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cyan.withValues(alpha: .18)),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: const NucleoPrevia(tamanho: 190),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prévia no app. No sistema ele aparece com o tamanho escolhido '
              'abaixo.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              key: const ValueKey('nucleo-ativo'),
              contentPadding: EdgeInsets.zero,
              value: ativo,
              onChanged: carregando ? null : _alternar,
              activeThumbColor: cyan,
              title: const Text('Mostrar sobre os outros apps',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                !ativo
                    ? 'Desligado'
                    : pausado
                        ? 'Ativo · pausado, parado neste ponto'
                        : 'Ativo · teletransporta a cada ~$intervalo s',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('nucleo-pausar'),
              onPressed: ativo ? _alternarPausa : null,
              icon: Icon(
                  pausado ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18),
              label: Text(pausado ? 'Retomar o núcleo' : 'Pausar o núcleo'),
            ),
            const SizedBox(height: 4),
            Text('Tamanho · $tamanho dp', style: const TextStyle(fontSize: 12)),
            Slider(
              key: const ValueKey('nucleo-tamanho'),
              value: tamanho.toDouble(),
              min: 72,
              max: 160,
              divisions: 22,
              activeColor: cyan,
              label: '$tamanho dp',
              onChanged: (valor) => setState(() => tamanho = valor.round()),
              onChangeEnd: (_) => unawaited(_aplicarConfiguracao()),
            ),
            Text('Teletransporte a cada $intervalo s',
                style: const TextStyle(fontSize: 12)),
            Slider(
              key: const ValueKey('nucleo-intervalo'),
              value: intervalo.toDouble(),
              min: 4,
              max: 12,
              divisions: 8,
              activeColor: cyan,
              label: '$intervalo s',
              onChanged: (valor) => setState(() => intervalo = valor.round()),
              onChangeEnd: (_) => unawaited(_aplicarConfiguracao()),
            ),
            SwitchListTile(
              key: const ValueKey('nucleo-economico'),
              contentPadding: EdgeInsets.zero,
              value: economico,
              onChanged: carregando ? null : _alternarEconomico,
              activeThumbColor: cyan,
              title:
                  const Text('Modo econômico', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                '20 quadros por segundo, brilho menor, para de desenhar com a '
                'tela apagada e teletransporta com o dobro do intervalo.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            const Eyebrow('MEDIÇÃO'),
            const SizedBox(height: 6),
            Text(
              'Normal · ${medicao.fpsNormal.toStringAsFixed(1)} quadros/s em '
              '${medicao.segundosNormais.toStringAsFixed(1)} s',
              key: const ValueKey('nucleo-medicao-normal'),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Econômico · ${medicao.fpsEconomico.toStringAsFixed(1)} quadros/s '
              'em ${medicao.segundosEconomicos.toStringAsFixed(1)} s',
              key: const ValueKey('nucleo-medicao-eco'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _textoDiferenca(),
              key: const ValueKey('nucleo-medicao-diferenca'),
              style: TextStyle(
                color: medicao.conclusiva ? cyan : muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('nucleo-medicao-zerar'),
                onPressed: () => unawaited(_zerarMedicao()),
                child: const Text('Zerar medição'),
              ),
            ),
            const SizedBox(height: 12),
            const Eyebrow('CONSUMO REAL'),
            const SizedBox(height: 6),
            const Text(
              'O Android não entrega energia por janela sobreposta. Medimos o CPU '
              'do processo e a variação da bateria do aparelho: serve para '
              'comparar os modos, não para prometer watts por núcleo.',
              key: ValueKey('nucleo-consumo-aviso'),
              style: TextStyle(color: muted, fontSize: 11, height: 1.45),
            ),
            if (consumo.medindo) ...[
              const SizedBox(height: 6),
              Text(
                'Medindo agora: '
                '${consumo.modoAtual == "economico" ? "econômico" : "normal"}. '
                'Pare para calcular.',
                key: const ValueKey('nucleo-consumo-medindo'),
                style: const TextStyle(color: cyan, fontSize: 12),
              ),
            ],
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                OutlinedButton(
                  key: const ValueKey('nucleo-consumo-iniciar'),
                  onPressed: ativo && !consumo.medindo
                      ? () => unawaited(_iniciarConsumo())
                      : null,
                  child: const Text('Iniciar medição'),
                ),
                OutlinedButton(
                  key: const ValueKey('nucleo-consumo-parar'),
                  onPressed:
                      consumo.medindo ? () => unawaited(_pararConsumo()) : null,
                  child: const Text('Parar'),
                ),
                TextButton(
                  key: const ValueKey('nucleo-consumo-zerar'),
                  onPressed: () => unawaited(_zerarConsumo()),
                  child: const Text('Zerar consumo'),
                ),
              ],
            ),
            Text(
              'Normal · ${_textoAmostra(consumo.normal)}',
              key: const ValueKey('nucleo-consumo-normal'),
              style: const TextStyle(fontSize: 11, height: 1.45),
            ),
            Text(
              'Econômico · ${_textoAmostra(consumo.economico)}',
              key: const ValueKey('nucleo-consumo-eco'),
              style: const TextStyle(fontSize: 11, height: 1.45),
            ),
            const SizedBox(height: 4),
            Text(
              _textoDiferencaConsumo(),
              key: const ValueKey('nucleo-consumo-diferenca'),
              style: TextStyle(
                color: consumo.comparacaoConclusiva ? cyan : muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const ValueKey('nucleo-teleportar'),
              onPressed: ativo && !pausado ? _teleportar : null,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Teletransportar agora'),
            ),
            if (pausado) ...[
              const SizedBox(height: 6),
              const Text(
                'Pausado: o núcleo continua visível e abre o app no toque, mas '
                'não gira nem troca de lugar. Retome para voltar ao movimento.',
                key: ValueKey('nucleo-pausado-aviso'),
                style: TextStyle(color: muted, fontSize: 11, height: 1.45),
              ),
            ],
            if (!permissao) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Falta uma autorização do Android: “Exibir sobre outros '
                      'apps”. Sem ela, o núcleo não pode ficar por cima de '
                      'nada.',
                      style: TextStyle(fontSize: 12, height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('nucleo-permissao'),
                      onPressed: () =>
                          unawaited(NucleoControle.abrirAjusteSobreposicao()),
                      child: const Text('Autorizar sobreposição'),
                    ),
                  ],
                ),
              ),
            ],
            if (aviso.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(aviso,
                  key: const ValueKey('nucleo-aviso'),
                  style: const TextStyle(
                      color: Color(0xFFFFB4A9), fontSize: 12, height: 1.45)),
            ],
            const SizedBox(height: 14),
            const Text(
              'O núcleo roda enquanto o JARVIS estiver em execução e gasta '
              'bateria: ele redesenha a esfera para girar. Toque nele para '
              'abrir o app; arraste para mudar de lugar.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.55),
            ),
          ],
        ),
      );
}
