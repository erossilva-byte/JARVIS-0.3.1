import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/pessoas.dart';

/// Armazenamento local criptografado. A interface permite testar sem o plugin do aparelho.
abstract interface class ArmazenamentoSeguro {
  Future<String?> ler(String chave);

  Future<void> gravar(String chave, String valor);

  Future<void> apagar(String chave);
}

class ArmazenamentoSeguroDispositivo implements ArmazenamentoSeguro {
  const ArmazenamentoSeguroDispositivo({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> ler(String chave) => _storage.read(key: chave);

  @override
  Future<void> gravar(String chave, String valor) => _storage.write(key: chave, value: valor);

  @override
  Future<void> apagar(String chave) => _storage.delete(key: chave);
}

class ResultadoSalvarPessoa {
  const ResultadoSalvarPessoa.ok(this.pessoa) : erro = null;
  const ResultadoSalvarPessoa.falha(this.erro) : pessoa = null;

  final Pessoa? pessoa;
  final String? erro;

  bool get ok => erro == null;
}

/// Fichas de pessoas no armazenamento seguro do aparelho.
///
/// Sem foto, câmera, biometria ou reconhecimento facial nesta etapa: a identidade é o nome que o
/// usuário digita. Nada sai para a rede — não há importação de `http` neste arquivo.
class PessoasStore {
  PessoasStore(this._armazenamento, {DateTime Function()? agora}) : _agora = agora ?? DateTime.now;

  static const chave = 'jarvis.pessoas.v1';

  final ArmazenamentoSeguro _armazenamento;
  final DateTime Function() _agora;

  /// Relógio pode repetir (teste ou dois toques no mesmo microssegundo): a sequência garante id.
  int _sequencia = 0;

  static Future<PessoasStore> abrir() async => PessoasStore(const ArmazenamentoSeguroDispositivo());

  Future<List<Pessoa>> listar() async {
    final bruto = await _armazenamento.ler(chave);
    return ordenarPessoas(pessoasDeJson(bruto));
  }

  Future<ResultadoSalvarPessoa> salvar(Pessoa dados) async {
    final lista = await listar();
    final existente = dados.id.isEmpty ? null : lista.where((p) => p.id == dados.id).firstOrNull;
    final quando = _agora();
    var ficha = dados.sanitizada().copiarCom(
      criadaEm: existente?.criadaEm ?? quando,
      atualizadaEm: quando,
    );
    if (ficha.id.isEmpty) ficha = _comId(ficha, quando);

    final erro = validarPessoa(ficha);
    if (erro != null) return ResultadoSalvarPessoa.falha(erro);
    if (existente == null && lista.length >= limitePerfisPessoa) {
      return ResultadoSalvarPessoa.falha(
        'Limite de $limitePerfisPessoa perfis. Apague algum antes de criar outro.',
      );
    }

    final proxima = existente == null
        ? [...lista, ficha]
        : lista.map((p) => p.id == ficha.id ? ficha : p).toList();
    final tamanho = utf8.encode(jsonDePessoas(proxima)).length;
    if (tamanho > limiteBytesPessoas) {
      return const ResultadoSalvarPessoa.falha(
        'As fichas passaram do limite de 64 kB. Reduza anotações ou apague uma ficha.',
      );
    }
    try {
      await _armazenamento.gravar(chave, jsonDePessoas(proxima));
    } catch (_) {
      return const ResultadoSalvarPessoa.falha('Não foi possível gravar no armazenamento seguro deste aparelho.');
    }
    return ResultadoSalvarPessoa.ok(ficha);
  }

  Future<bool> apagar(String id) async {
    if (id.isEmpty) return false;
    final lista = await listar();
    final proxima = lista.where((p) => p.id != id).toList();
    if (proxima.length == lista.length) return false;
    try {
      await _armazenamento.gravar(chave, jsonDePessoas(proxima));
      return true;
    } catch (_) {
      return false;
    }
  }

  Pessoa _comId(Pessoa ficha, DateTime quando) => Pessoa(
        id: 'p_${quando.microsecondsSinceEpoch}_${_sequencia++}',
        nome: ficha.nome,
        apelido: ficha.apelido,
        relacao: ficha.relacao,
        contatos: ficha.contatos,
        preferencias: ficha.preferencias,
        observacoes: ficha.observacoes,
        compromissos: ficha.compromissos,
        historico: ficha.historico,
        consentimento: ficha.consentimento,
        criadaEm: ficha.criadaEm,
        atualizadaEm: ficha.atualizadaEm,
      );
}
