import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/voz_externa.dart';
import 'provider_service.dart';

/// Preferências da voz externa: o ID e se ela está ligada.
///
/// Nem o ID nem a chave são segredo de cofre: o ID é preferência e a chave vai
/// para o `SecretStore` (armazenamento seguro da plataforma).
abstract interface class VozExternaStore {
  Future<String> id();
  Future<void> gravarId(String id);
  Future<bool> ativa();
  Future<void> definirAtiva(bool ativa);
}

const chaveVozExternaId = 'jarvis.voz.externa.id';
const chaveVozExternaAtiva = 'jarvis.voz.externa.ativa';

/// Chave do serviço dentro do `PlatformSecretStore` (`jarvis.ai.<chave>`).
const chaveSegredoVozExterna = 'vozExterna';

class PreferencesVozExterna implements VozExternaStore {
  @override
  Future<String> id() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString(chaveVozExternaId);
      return normalizarIdVoz(salvo);
    } catch (_) {
      return idVozPadrao;
    }
  }

  @override
  Future<void> gravarId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chaveVozExternaId, normalizarIdVoz(id));
  }

  @override
  Future<bool> ativa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(chaveVozExternaAtiva) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> definirAtiva(bool ativa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(chaveVozExternaAtiva, ativa);
  }
}

/// Resultado de uma tentativa de falar com a voz externa.
class ResultadoVozExterna {
  const ResultadoVozExterna({this.audio, this.erro});

  final Uint8List? audio;
  final String? erro;

  bool get ok => audio != null && erro == null;
}

/// Fala pelo serviço de voz usando o ID escolhido.
///
/// A chave vem do armazenamento seguro e nunca é devolvida à tela. Quando falta
/// chave, a chamada nem sai: devolve o motivo em texto, e a voz do aparelho
/// continua sendo usada.
class VozExternaService {
  VozExternaService({
    http.Client? cliente,
    SecretStore? segredos,
    VozExternaStore? loja,
    MethodChannel canal = const MethodChannel('com.jarvis.nova/voz'),
  })  : _cliente = cliente ?? http.Client(),
        _segredos = segredos ?? PlatformSecretStore(),
        _loja = loja ?? PreferencesVozExterna(),
        _canal = canal;

  final http.Client _cliente;
  final SecretStore _segredos;
  final VozExternaStore _loja;
  final MethodChannel _canal;

  Future<String?> lerChave() async {
    try {
      final valor = await _segredos.read(chaveSegredoVozExterna);
      return valor == null || valor.trim().isEmpty ? null : valor.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> gravarChave(String chave) =>
      _segredos.write(chaveSegredoVozExterna, chave.trim());

  Future<void> apagarChave() => _segredos.delete(chaveSegredoVozExterna);

  Future<String> id() => _loja.id();

  Future<bool> ativa() => _loja.ativa();

  Future<void> definirAtiva(bool ativa) => _loja.definirAtiva(ativa);

  Future<void> gravarId(String id) => _loja.gravarId(id);

  /// Gera o áudio do texto com o ID configurado.
  Future<ResultadoVozExterna> gerar(String texto) async {
    final limpo = texto.trim();
    if (limpo.isEmpty) {
      return const ResultadoVozExterna(erro: 'Não há texto para falar.');
    }
    final chave = await lerChave();
    if (chave == null) {
      return const ResultadoVozExterna(
          erro: 'Falta a chave do serviço de voz. A voz do aparelho continua '
              'valendo até você cadastrar a chave.');
    }
    final id = await _loja.id();
    if (!idVozValido(id)) {
      return const ResultadoVozExterna(
          erro: 'O ID de voz não tem formato válido (16 a 40 letras, números, '
              'hífen ou sublinhado).');
    }
    try {
      final resposta = await _cliente
          .post(
            Uri.parse(urlVozExterna(id)),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode(corpoVozExterna(limpo)),
          )
          .timeout(const Duration(seconds: 30));
      if (resposta.statusCode == 200 && resposta.bodyBytes.isNotEmpty) {
        return ResultadoVozExterna(audio: resposta.bodyBytes);
      }
      switch (resposta.statusCode) {
        case 401:
        case 403:
          return const ResultadoVozExterna(
              erro: 'A chave foi recusada pelo serviço de voz.');
        case 402:
        case 429:
          return const ResultadoVozExterna(
              erro: 'A cota do serviço de voz acabou ou está limitada agora.');
        case 422:
          return const ResultadoVozExterna(
              erro: 'O serviço recusou o pedido: confira o ID de voz.');
        default:
          return ResultadoVozExterna(
              erro: 'O serviço respondeu ${resposta.statusCode} '
                  'e não devolveu áudio.');
      }
    } catch (e) {
      return ResultadoVozExterna(
          erro: 'Sem resposta do serviço de voz: ${_motivo(e)}');
    }
  }

  /// Toca o MP3 pelo canal de voz do Android.
  ///
  /// Devolve `false` quando o canal não existe (desktop, teste) ou quando o
  /// MediaPlayer recusou — quem chamou decide se volta para a voz do aparelho.
  Future<bool> tocar(Uint8List audio) async {
    try {
      final pasta = await getTemporaryDirectory();
      final arquivo = File('${pasta.path}/jarvis_voz_externa.mp3');
      await arquivo.writeAsBytes(audio, flush: true);
      final falou = await _canal
          .invokeMethod<bool>('falarAudio', {'caminho': arquivo.path});
      return falou == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _motivo(Object erro) {
    final texto = erro.toString();
    if (texto.contains('TimeoutException')) return 'tempo esgotado';
    if (texto.contains('SocketException')) return 'aparelho sem rede';
    return 'falha de rede';
  }
}
