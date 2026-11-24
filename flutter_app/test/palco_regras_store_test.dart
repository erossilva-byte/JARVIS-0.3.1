import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/palco.dart';
import 'package:jarvis_nova/services/palco_regras_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('guarda as regras e relê no próximo abre', () async {
    SharedPreferences.setMockInitialValues({});
    final loja = await PalcoRegrasStore.abrir();
    expect(loja.carregar().capaVideo.altura, RegrasPalco.padrao.capaVideo.altura);

    final novas = RegrasPalco.padrao.comRegra(MolduraPalco.capaVideo,
        const RegraMoldura(altura: 0.5, cabeInteira: true));
    expect(await loja.salvar(novas), isTrue);

    final outra = await PalcoRegrasStore.abrir();
    final lidas = outra.carregar();
    expect(lidas.capaVideo.altura, 0.5);
    expect(lidas.capaVideo.cabeInteira, isTrue);
    expect(lidas.capaLarga.altura, RegrasPalco.padrao.capaLarga.altura);
  });

  test('texto estragado não quebra: volta ao padrão', () async {
    SharedPreferences.setMockInitialValues(
        {PalcoRegrasStore.chave: 'isto não é json'});
    final loja = await PalcoRegrasStore.abrir();
    expect(loja.carregar().capaLarga.altura,
        RegrasPalco.padrao.capaLarga.altura);
  });

  test('voltar ao padrão grava os valores originais', () async {
    SharedPreferences.setMockInitialValues({});
    final loja = await PalcoRegrasStore.abrir();
    await loja.salvar(RegrasPalco.padrao.comRegra(MolduraPalco.capaNoticia,
        const RegraMoldura(altura: 0.6, cabeInteira: true)));
    expect(await loja.voltarAoPadrao(), isTrue);
    final lidas = (await PalcoRegrasStore.abrir()).carregar();
    expect(lidas.capaNoticia.altura, RegrasPalco.padrao.capaNoticia.altura);
    expect(lidas.capaNoticia.cabeInteira, isFalse);
  });
}
