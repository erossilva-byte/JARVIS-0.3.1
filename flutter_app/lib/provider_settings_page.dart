import 'package:material_ui/material_ui.dart';
import 'services/provider_service.dart';
import 'ui_common.dart';

class ProviderSettingsPage extends StatefulWidget {
  const ProviderSettingsPage({super.key, this.service});

  /// Injetável para teste; em produção usa o cofre seguro do aparelho.
  final ProviderService? service;

  @override
  State<ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<ProviderSettingsPage> {
  late final ProviderService service =
      widget.service ?? ProviderService(secrets: PlatformSecretStore());
  final Map<String, TextEditingController> fields = {};
  final Map<String, bool> configured = {};
  final Map<String, String?> modelos = {};
  final Map<String, String> messages = {};
  final Set<String> busy = {};
  @override
  void initState() {
    super.initState();
    for (final p in aiProviders) {
      fields[p.id] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    for (final p in aiProviders) {
      try {
        final value = await service.isConfigured(p.id);
        final escolhido = await service.modeloEscolhido(p.id);
        if (mounted) {
          setState(() {
            configured[p.id] = value;
            modelos[p.id] = escolhido;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => messages[p.id] =
              'Armazenamento seguro indisponível nesta plataforma.');
        }
      }
    }
  }

  Future<void> _save(AiProvider p) async {
    final value = fields[p.id]!.text;
    if (value.trim().isEmpty) {
      setState(() => messages[p.id] = 'Informe a chave antes de salvar.');
      return;
    }
    setState(() => busy.add(p.id));
    try {
      await service.saveKey(p.id, value);
      fields[p.id]!.clear();
      if (mounted) {
        setState(() {
          configured[p.id] = true;
          messages[p.id] =
              'Chave armazenada no cofre seguro. Teste a conexão para validar o acesso.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => messages[p.id] =
            e.toString().replaceFirst('Invalid argument(s): ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => busy.remove(p.id));
      }
    }
  }

  Future<void> _test(AiProvider p) async {
    setState(() {
      busy.add(p.id);
      messages[p.id] = 'Testando conexão…';
    });
    try {
      final result = await service.testConnection(p.id);
      if (mounted) {
        setState(() => messages[p.id] = result.ok
            ? 'Conexão confirmada. Modelo: ${result.model}'
            : result.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy.remove(p.id));
      }
    }
  }

  Future<void> _alternarZeroKey(AiProvider p, bool ativo) async {
    setState(() => busy.add(p.id));
    try {
      await service.definirZeroKey(ativo);
      if (!mounted) return;
      setState(() {
        configured[p.id] = ativo;
        messages[p.id] = ativo
            ? 'Zero-Key ativado: só é usado quando nenhum provedor com chave responde.'
            : 'Zero-Key desligado: nenhuma pergunta sai do aparelho sem uma chave sua.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => messages[p.id] =
            'Não foi possível guardar essa escolha no aparelho.');
      }
    } finally {
      if (mounted) {
        setState(() => busy.remove(p.id));
      }
    }
  }

  Future<void> _abrirModelos(AiProvider p) async {
    setState(() {
      busy.add(p.id);
      messages[p.id] = 'Consultando a lista de modelos do ${p.name}…';
    });
    List<ModeloDoProvedor> lista;
    try {
      lista = await service.descobrirModelos(p.id);
    } on ProviderException catch (e) {
      if (mounted) setState(() => messages[p.id] = e.message);
      return;
    } catch (_) {
      if (mounted) {
        setState(() => messages[p.id] =
            'Falha inesperada ao listar os modelos. O padrão continua valendo.');
      }
      return;
    } finally {
      if (mounted) setState(() => busy.remove(p.id));
    }
    if (!mounted) return;
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (_) => _SeletorDeModelos(
          provedor: p.name, modelos: lista, atual: modelos[p.id]),
    );
    if (escolhido == null || !mounted) return;
    try {
      await service.escolherModelo(p.id, escolhido.isEmpty ? null : escolhido);
      if (!mounted) return;
      setState(() {
        modelos[p.id] = escolhido.isEmpty ? null : escolhido;
        messages[p.id] = escolhido.isEmpty
            ? 'Modelo voltou ao padrão do app.'
            : 'Modelo escolhido: $escolhido. O teste de conexão confirma se a sua chave alcança esse modelo.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => messages[p.id] =
            'Não foi possível guardar o modelo escolhido no aparelho.');
      }
    }
  }

  Future<void> _voltarAoPadrao(AiProvider p) async {
    try {
      await service.escolherModelo(p.id, null);
      if (!mounted) return;
      setState(() {
        modelos[p.id] = null;
        messages[p.id] = 'Modelo voltou ao padrão do app.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => messages[p.id] =
            'Não foi possível guardar o modelo escolhido no aparelho.');
      }
    }
  }

  Future<void> _remove(AiProvider p) async {
    setState(() => busy.add(p.id));
    try {
      await service.removeKey(p.id);
      if (mounted) {
        setState(() {
          configured[p.id] = false;
          messages[p.id] = 'Chave removida do cofre seguro.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => messages[p.id] =
            'Não foi possível remover a chave do armazenamento seguro.');
      }
    } finally {
      if (mounted) {
        setState(() => busy.remove(p.id));
      }
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                const Text('Provedores de IA', style: TextStyle(fontSize: 15))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Eyebrow('PRIORIDADE DE ROTEAMENTO'),
          const SizedBox(height: 7),
          const Text(
              'Groq é o provedor principal. Os demais ficam disponíveis como alternativas configuradas individualmente. O Zero-Key fica por último: só responde quando nenhum provedor com chave está disponível.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.5)),
          const SizedBox(height: 14),
          for (final provider in aiProviders) ...[
            Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 11),
                decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: provider.id == 'groq'
                            ? cyan.withValues(alpha: .4)
                            : Colors.white12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(provider.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700))),
                        Text(
                            configured[provider.id] == true
                                ? 'CONFIGURADO'
                                : 'SEM CHAVE',
                            style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 1,
                                color: configured[provider.id] == true
                                    ? const Color(0xFF64E6B1)
                                    : muted))
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          'Modelo em uso: ${modelos[provider.id] ?? provider.model}'
                          '${modelos[provider.id] == null ? ' (padrão do app)' : ' (escolhido)'}',
                          key: ValueKey('modelo-atual-${provider.id}'),
                          style: const TextStyle(fontSize: 9, color: muted)),
                      const SizedBox(height: 10),
                      if (provider.semChave) ...[
                        Row(children: [
                          const Expanded(
                              child: Text('Usar sem chave (serviço público)',
                                  style: TextStyle(fontSize: 11))),
                          Switch(
                              key: const ValueKey('zerokey-ativar'),
                              value: configured[provider.id] == true,
                              onChanged: busy.contains(provider.id)
                                  ? null
                                  : (valor) => _alternarZeroKey(provider, valor)),
                        ]),
                        const Text(
                            'A pergunta e o histórico recente da conversa saem do aparelho para um serviço público, sem cadastro e identificados apenas pelo IP. O limite é de cerca de uma resposta a cada 45 segundos e pode falhar. Sem este botão ligado, nada sai sem uma chave sua.',
                            style: TextStyle(
                                fontSize: 10, height: 1.45, color: muted)),
                        const SizedBox(height: 10),
                      ] else ...[
                        TextField(
                            controller: fields[provider.id],
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                                hintText: 'Cole a chave de API',
                                hintStyle: const TextStyle(fontSize: 11),
                                filled: true,
                                fillColor: bg,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11))),
                        const SizedBox(height: 10),
                      ],
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        if (!provider.semChave)
                          FilledButton.tonal(
                              onPressed: busy.contains(provider.id)
                                  ? null
                                  : () => _save(provider),
                              child: const Text('Salvar chave')),
                        OutlinedButton(
                            onPressed: busy.contains(provider.id) ||
                                    configured[provider.id] != true
                                ? null
                                : () => _test(provider),
                            child: const Text('Testar conexão')),
                        OutlinedButton(
                            key: ValueKey('modelos-${provider.id}'),
                            onPressed: busy.contains(provider.id) ||
                                    configured[provider.id] != true
                                ? null
                                : () => _abrirModelos(provider),
                            child: const Text('Ver modelos')),
                        if (modelos[provider.id] != null)
                          TextButton(
                              onPressed: busy.contains(provider.id)
                                  ? null
                                  : () => _voltarAoPadrao(provider),
                              child: const Text('Usar padrão')),
                        if (!provider.semChave)
                          TextButton(
                              onPressed: busy.contains(provider.id) ||
                                      configured[provider.id] != true
                                  ? null
                                  : () => _remove(provider),
                              child: const Text('Remover')),
                      ]),
                      if (messages[provider.id] != null) ...[
                        const SizedBox(height: 7),
                        Text(messages[provider.id]!,
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.4,
                                color: messages[provider.id]!
                                            .contains('confirmada') ||
                                        messages[provider.id]!
                                            .contains('armazenada') ||
                                        messages[provider.id]!
                                            .contains('removida') ||
                                        messages[provider.id]!
                                            .contains('ativado') ||
                                        messages[provider.id]!
                                            .contains('desligado') ||
                                        messages[provider.id]!
                                            .contains('Modelo escolhido') ||
                                        messages[provider.id]!
                                            .contains('Modelo voltou')
                                    ? const Color(0xFF64E6B1)
                                    : const Color(0xFFFFC66D)))
                      ],
                    ])),
          ],
          const FootnoteText(
              'As chaves nunca são exibidas novamente nem incluídas em logs. A lista de modelos manda só a chave ao provedor, nunca a conversa. O teste envia uma solicitação mínima e pode gerar cobrança de tokens.'),
        ]),
      );
}

/// Janela de escolha do modelo: filtra a lista que o provedor devolveu.
/// Devolve o id escolhido, `''` para voltar ao padrão, ou `null` se fechar.
class _SeletorDeModelos extends StatefulWidget {
  const _SeletorDeModelos(
      {required this.provedor, required this.modelos, this.atual});
  final String provedor;
  final List<ModeloDoProvedor> modelos;
  final String? atual;

  @override
  State<_SeletorDeModelos> createState() => _SeletorDeModelosState();
}

class _SeletorDeModelosState extends State<_SeletorDeModelos> {
  final busca = TextEditingController();
  String filtro = '';

  @override
  void dispose() {
    busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final termo = filtro.trim().toLowerCase();
    final visiveis = [
      for (final m in widget.modelos)
        if (termo.isEmpty ||
            m.id.toLowerCase().contains(termo) ||
            (m.nome ?? '').toLowerCase().contains(termo))
          m,
    ].take(300).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                Expanded(
                    child: Text('Modelos do ${widget.provedor}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18)),
              ])),
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                  'A lista vem do provedor. Ela não garante que a sua chave alcança todos os modelos; o teste de conexão é que confirma.',
                  style: TextStyle(fontSize: 10, height: 1.45, color: muted))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                  key: const ValueKey('modelos-busca'),
                  controller: busca,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (valor) => setState(() => filtro = valor),
                  decoration: InputDecoration(
                      hintText: 'Filtrar por nome',
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11)))),
          const SizedBox(height: 8),
          Expanded(
              child: ListView.builder(
            itemCount: visiveis.length + 1,
            itemBuilder: (context, indice) {
              if (indice == 0) {
                return ListTile(
                  key: const ValueKey('modelo-padrao'),
                  dense: true,
                  title: const Text('Usar o padrão do app',
                      style: TextStyle(fontSize: 12)),
                  subtitle: const Text('Descarta a escolha guardada neste provedor',
                      style: TextStyle(fontSize: 9, color: muted)),
                  trailing: widget.atual == null
                      ? const Icon(Icons.check, size: 18, color: cyan)
                      : null,
                  onTap: () => Navigator.pop(context, ''),
                );
              }
              final modelo = visiveis[indice - 1];
              final atual = modelo.id == widget.atual;
              return ListTile(
                key: ValueKey('modelo-${modelo.id}'),
                dense: true,
                title: Text(modelo.id,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: atual ? cyan : null)),
                subtitle: modelo.nome == null || modelo.nome == modelo.id
                    ? null
                    : Text(modelo.nome!,
                        style: const TextStyle(fontSize: 9, color: muted)),
                trailing:
                    atual ? const Icon(Icons.check, size: 18, color: cyan) : null,
                onTap: () => Navigator.pop(context, modelo.id),
              );
            },
          )),
        ]),
      ),
    );
  }
}
