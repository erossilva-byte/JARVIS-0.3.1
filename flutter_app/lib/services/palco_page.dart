import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/palco.dart';
import '../ui_common.dart';
import 'palco_regras_page.dart';
import 'palco_regras_store.dart';
import 'palco_service.dart';
import 'sistema_android.dart';

/// Função de busca injetável: os testes trocam a rede por uma lista.
typedef BuscadorPalco = Future<List<ItemPalco>> Function(PedidoPalco pedido);

/// Modo palco: pesquisa imagens, vídeos e notícias e mostra na tela.
///
/// As fontes não pedem chave (Wikimedia Commons, Google Notícias e
/// Dailymotion). O palco exibe a imagem, a capa do vídeo ou o título e o
/// resumo da notícia; o vídeo e a matéria abrem no navegador, porque este APK
/// não tem player nem leitor embutido. A tela nunca diz que achou algo sem
/// ter recebido a lista da fonte.
class PalcoPage extends StatefulWidget {
  const PalcoPage({super.key, this.buscar, this.pedidoInicial});

  /// Busca injetada nos testes; em produção usa [PalcoService].
  final BuscadorPalco? buscar;

  /// Pedido que abre a tela já pesquisando (usado pelo atalho do módulo).
  final PedidoPalco? pedidoInicial;

  @override
  State<PalcoPage> createState() => _PalcoPageState();
}

class _PalcoPageState extends State<PalcoPage> {
  final campo = TextEditingController();
  late final BuscadorPalco _buscar = widget.buscar ?? PalcoService().buscar;

  TipoPalco tipo = TipoPalco.imagem;
  List<ItemPalco> itens = const [];
  int atual = 0;
  bool carregando = false;
  String? erro;
  String? aviso;
  PedidoPalco? ultimoPedido;

  /// Regras de enquadramento escolhidas pelo usuário nesta sessão.
  RegrasPalco regras = RegrasPalco.padrao;

  @override
  void initState() {
    super.initState();
    unawaited(_carregarRegras());
    final inicial = widget.pedidoInicial;
    if (inicial != null) {
      campo.text = inicial.consulta;
      tipo = inicial.tipo;
      // Fora do primeiro build: a pesquisa chama setState.
      unawaited(Future<void>.microtask(() => _pesquisar(inicial)));
    }
  }

  Future<void> _carregarRegras() async {
    try {
      final lidas = (await PalcoRegrasStore.abrir()).carregar();
      if (!mounted) return;
      setState(() => regras = lidas);
    } catch (_) {
      // Sem armazenamento disponível, o palco segue com as regras padrão.
    }
  }

  Future<void> _abrirRegras() async {
    final escolhidas = await Navigator.of(context).push<RegrasPalco>(
      MaterialPageRoute(builder: (_) => PalcoRegrasPage(regras: regras)),
    );
    if (escolhidas == null || !mounted) return;
    setState(() => regras = escolhidas);
    try {
      final loja = await PalcoRegrasStore.abrir();
      final gravou = await loja.salvar(escolhidas);
      if (!mounted) return;
      setState(() => aviso = gravou
          ? 'Regras do palco salvas neste aparelho.'
          : 'As regras valem agora, mas o Android não confirmou a gravação.');
    } catch (_) {
      if (!mounted) return;
      setState(() => aviso =
          'As regras valem nesta sessão, mas não foi possível gravar aqui.');
    }
  }

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  Future<void> _pesquisar([PedidoPalco? pedido]) async {
    if (carregando) return;
    final texto = campo.text.trim();
    final consulta = pedido?.consulta ??
        (consultaDePalco(texto, tipo).isEmpty
            ? texto
            : consultaDePalco(texto, tipo));
    if (consulta.isEmpty) {
      setState(() {
        erro = 'Escreva o que quer ver no palco, por exemplo: '
            '“mostra fotos de motor trifásico”.';
        itens = const [];
      });
      return;
    }
    final pedidoFinal = pedido ?? PedidoPalco(consulta: consulta, tipo: tipo);
    setState(() {
      carregando = true;
      erro = null;
      aviso = null;
      itens = const [];
      atual = 0;
      ultimoPedido = pedidoFinal;
    });
    try {
      final achados = await _buscar(pedidoFinal);
      if (!mounted) return;
      setState(() {
        itens = achados;
        carregando = false;
      });
    } on PalcoException catch (falha) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = falha.message;
      });
    } catch (falha) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = 'A pesquisa falhou: '
            '${falha.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _abrirLink() async {
    if (itens.isEmpty) return;
    final item = itens[atual];
    final abriu = await SistemaAndroid.abrirUrl(item.url);
    if (!mounted) return;
    setState(() => aviso = abriu
        ? 'Abri ${item.url} no navegador.'
        : 'Não foi possível abrir o navegador neste aparelho. O link está '
            'abaixo e pode ser copiado.');
  }

  Future<void> _copiarLink() async {
    if (itens.isEmpty) return;
    final item = itens[atual];
    await Clipboard.setData(ClipboardData(text: item.url));
    if (!mounted) return;
    setState(() => aviso = 'Link copiado: ${item.url}');
  }

  void _selecionar(int indice) => setState(() {
        atual = indice;
        aviso = null;
      });

  @override
  Widget build(BuildContext context) {
    final item = itens.isEmpty ? null : itens[atual];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo palco', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          const Eyebrow('PALCO'),
          const SizedBox(height: 7),
          const Text('Trazer para a tela',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w300)),
          const SizedBox(height: 6),
          Text(
            'Peça uma imagem, um vídeo ou uma notícia. A pesquisa acontece '
            'agora, sem chave: imagens da Wikimedia Commons, notícias do '
            'Google Notícias e vídeos do Dailymotion.',
            style: const TextStyle(color: muted, height: 1.5, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final opcao in TipoPalco.values)
                ChoiceChip(
                  key: ValueKey('palco-tipo-${opcao.name}'),
                  label: Text(opcao.rotulo),
                  selected: tipo == opcao,
                  onSelected: (_) => setState(() {
                    tipo = opcao;
                    aviso = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('palco-campo'),
            controller: campo,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _pesquisar(),
            decoration: const InputDecoration(
              labelText: 'O que mostrar',
              hintText: 'motor trifásico, eleições, partida direta…',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('palco-pesquisar'),
            onPressed: carregando ? null : () => _pesquisar(),
            icon: Icon(carregando
                ? Icons.hourglass_top_rounded
                : Icons.travel_explore_rounded),
            label: Text(carregando ? 'Pesquisando…' : 'Pesquisar e mostrar'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('palco-regras'),
              onPressed: _abrirRegras,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Regras do palco'),
            ),
          ),
          if (carregando && ultimoPedido != null) ...[
            const SizedBox(height: 8),
            Text(descricaoDoPedido(ultimoPedido!),
                style: const TextStyle(color: muted, fontSize: 11)),
          ],
          if (erro != null) ...[
            const SizedBox(height: 12),
            _Cartao(
              chave: 'palco-erro',
              cor: const Color(0xFFFFC66D),
              icone: Icons.error_outline_rounded,
              titulo: 'A pesquisa não trouxe resultado',
              texto: erro!,
            ),
          ],
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Text(aviso!,
                key: const ValueKey('palco-aviso'),
                style: const TextStyle(color: cyan, fontSize: 11)),
          ],
          if (item != null) ...[
            const SizedBox(height: 14),
            _PalcoDeMidia(
                item: item, chave: 'palco-resultado', regras: regras),
            const SizedBox(height: 10),
            Text(item.titulo,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 4),
            Text(
              [item.fonte, item.detalhe].where((t) => t.isNotEmpty).join(' · '),
              style: const TextStyle(color: cyan, fontSize: 10.5),
            ),
            if (item.resumo.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(item.resumo,
                  style: const TextStyle(
                      color: muted, fontSize: 11.5, height: 1.5)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('palco-abrir-link'),
                    onPressed: linkSeguro(item.url) ? _abrirLink : null,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(item.tipo == TipoPalco.imagem
                        ? 'Abrir a página da imagem'
                        : 'Abrir no navegador'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('palco-copiar-link'),
                  onPressed: _copiarLink,
                  child: const Text('Copiar link'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.url,
                key: const ValueKey('palco-url'),
                style: const TextStyle(color: muted, fontSize: 10)),
            Text(item.tipo.comoExibe,
                style:
                    const TextStyle(color: muted, fontSize: 10, height: 1.4)),
            if (itens.length > 1) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('${atual + 1} de ${itens.length}',
                      style: const TextStyle(color: muted, fontSize: 11)),
                  const Spacer(),
                  TextButton.icon(
                    key: const ValueKey('palco-anterior'),
                    onPressed: atual > 0 ? () => _selecionar(atual - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Anterior'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('palco-proximo'),
                    onPressed: atual < itens.length - 1
                        ? () => _selecionar(atual + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Próximo'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < itens.length; i++)
                ListTile(
                  key: ValueKey('palco-item-$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  selected: i == atual,
                  leading: Icon(_iconeDoTipo(itens[i].tipo), size: 18),
                  title: Text(itens[i].titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
                  subtitle: Text(
                      [itens[i].fonte, itens[i].detalhe]
                          .where((t) => t.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(color: muted, fontSize: 9.5)),
                  onTap: () => _selecionar(i),
                ),
            ],
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                color: panel, borderRadius: BorderRadius.circular(14)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Limites do palco',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                SizedBox(height: 5),
                Text(
                  'A pesquisa usa três serviços públicos e depende da '
                  'internet do aparelho: fora do ar, a tela mostra o motivo em '
                  'vez de inventar resultado. Nada é baixado para a pasta do '
                  'app e nenhuma conta é criada. O vídeo não toca dentro do '
                  'APK; ele abre no navegador.',
                  style: TextStyle(color: muted, fontSize: 10.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconeDoTipo(TipoPalco tipo) => switch (tipo) {
      TipoPalco.imagem => Icons.image_outlined,
      TipoPalco.video => Icons.play_circle_outline_rounded,
      TipoPalco.noticia => Icons.newspaper_rounded,
    };

/// Área de exibição: imagem grande, capa de vídeo ou cartão de notícia.
class _PalcoDeMidia extends StatelessWidget {
  const _PalcoDeMidia({
    required this.item,
    required this.chave,
    this.regras = RegrasPalco.padrao,
  });

  final ItemPalco item;
  final String chave;
  final RegrasPalco regras;

  @override
  Widget build(BuildContext context) {
    final temImagem = item.miniatura.isNotEmpty;
    final moldura = molduraDoItem(item, regras: regras);
    final alturaTela = MediaQuery.sizeOf(context).height;
    return Container(
      key: ValueKey(chave),
      height: moldura.alturaEm(alturaTela),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1725),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyan.withValues(alpha: .22)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (temImagem)
            Image.network(
              item.miniatura,
              // Foto em pé fica inteira; capa larga preenche a caixa.
              fit: moldura.cabeInteira ? BoxFit.contain : BoxFit.cover,
              errorBuilder: (_, __, ___) => _semImagem(item),
              loadingBuilder: (_, filho, progresso) => progresso == null
                  ? filho
                  : const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            )
          else
            _semImagem(item),
          if (item.tipo == TipoPalco.video)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
        ],
      ),
    );
  }

  Widget _semImagem(ItemPalco item) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconeDoTipo(item.tipo), color: cyan, size: 30),
              const SizedBox(height: 8),
              Text(
                item.titulo,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      );
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.chave,
    required this.cor,
    required this.icone,
    required this.titulo,
    required this.texto,
  });

  final String chave;
  final Color cor;
  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey(chave),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withValues(alpha: .3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          color: cor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(texto,
                      style: const TextStyle(
                          color: muted, fontSize: 10.5, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}
