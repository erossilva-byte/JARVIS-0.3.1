import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../ui_common.dart';
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
  int tamanho = 112;
  int intervalo = 7;
  String aviso = '';

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
        tamanho = estado.tamanho.clamp(72, 160);
        intervalo = (estado.intervalo / 1000).round().clamp(4, 12);
        carregando = false;
        aviso = '';
      });
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
              tamanho: tamanho, intervalo: intervalo * 1000)
          : await NucleoControle.parar();
      if (!mounted) return;
      setState(() {
        ativo = estado.ativo;
        permissao = estado.permissao;
        if (ligar && !estado.ativo) {
          aviso = estado.motivo == 'sem_permissao'
              ? 'Para o núcleo aparecer por cima dos outros apps, autorize '
                  '“Exibir sobre outros apps”.'
              : 'Não consegui mostrar o núcleo neste aparelho.';
        } else {
          aviso = '';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui falar com o serviço do núcleo.');
    }
  }

  Future<void> _aplicarConfiguracao() async {
    if (!ativo) return;
    try {
      final estado = await NucleoControle.iniciar(
          tamanho: tamanho, intervalo: intervalo * 1000);
      if (!mounted) return;
      setState(() => ativo = estado.ativo);
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso = 'Não consegui aplicar o novo tamanho.');
    }
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
                ativo
                    ? 'Ativo · teletransporta a cada ~$intervalo s'
                    : 'Desligado',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
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
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const ValueKey('nucleo-teleportar'),
              onPressed: ativo ? _teleportar : null,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Teletransportar agora'),
            ),
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
