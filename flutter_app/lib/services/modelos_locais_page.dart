import 'package:material_ui/material_ui.dart';

import '../provider_settings_page.dart';
import '../ui_common.dart';

/// Modelos locais: o que existe no aparelho e o que falta.
///
/// Este APK não embarca motor de inferência de texto. Em vez de deixar o módulo
/// no aviso genérico de auditoria, a tela declara o que roda offline hoje e o
/// que seria preciso para rodar um modelo de linguagem sem internet.
class ModelosLocaisPage extends StatelessWidget {
  const ModelosLocaisPage({super.key});

  static const _rodamOffline = <String>[
    'A fala de resposta (TTS do aparelho, com os perfis de timbre).',
    'A palavra de ativação (sherpa-onnx, modelo inglês empacotado no APK).',
    'O simulador de circuitos e o projetista por prompt.',
    'A memória, a busca local e as fichas de pessoas.',
    'Os utilitários: IMC, conversões, base numérica e QR Code.',
  ];

  static const _faltam = <String>[
    'Um runtime de modelo de texto (llama.cpp ou equivalente) compilado para '
        'Android.',
    'Os pesos do modelo baixados e verificados por hash — são centenas de MB.',
    'Uma tela de escolha de modelo com o tamanho e o consumo de RAM de cada um.',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
          appBar: AppBar(
              title: const Text('Modelos locais',
                  style: TextStyle(fontSize: 15))),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            const Eyebrow('ESTADO REAL'),
            const SizedBox(height: 8),
            const Text('Sem motor local neste APK',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
            const SizedBox(height: 7),
            const Text(
                'O catálogo citava modelos locais, mas este build responde pelo '
                'provedor de IA que você configurar. Nada aqui baixa modelo nem '
                'promete operação offline com texto.',
                key: ValueKey('modelos-locais-estado'),
                style: TextStyle(color: muted, height: 1.5, fontSize: 12)),
            const SizedBox(height: 16),
            const Eyebrow('JÁ RODA SEM INTERNET'),
            const SizedBox(height: 6),
            for (final item in _rodamOffline)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_rounded, size: 15, color: Color(0xFF64E6B1)),
                  const SizedBox(width: 7),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              color: muted, fontSize: 11, height: 1.45))),
                ]),
              ),
            const SizedBox(height: 16),
            const Eyebrow('O QUE FALTA PARA UM MODELO LOCAL'),
            const SizedBox(height: 6),
            for (final item in _faltam)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.block_rounded, size: 15, color: Color(0xFFFFC66D)),
                  const SizedBox(width: 7),
                  Expanded(
                      child: Text(item,
                          key: const ValueKey('modelos-locais-limite'),
                          style: const TextStyle(
                              color: muted, fontSize: 11, height: 1.45))),
                ]),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('modelos-locais-provedores'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ProviderSettingsPage())),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Configurar provedor de IA'),
            ),
          ]));
}
