/// Calibragem da palavra de ativação (“Jarvis”), espelhando o detector nativo.
///
/// O Android guarda a sensibilidade (0–100) e a converte em limiar acústico do
/// KWS. Os números daqui precisam bater com `JarvisKwsEngine.limiarPara` e
/// `JarvisKwsEngine.pontuacaoPalavra`; o contrato
/// `tests/test_sensibilidade_ativacao_flutter.py` confere os dois lados.
class AtivacaoSensibilidade {
  const AtivacaoSensibilidade._();

  static const int minima = 0;
  static const int maxima = 100;

  /// Mesmo padrão do serviço Android: o valor que já era usado quando a
  /// sensibilidade era fixa no código.
  static const int padrao = 75;

  /// Passo do controle na tela.
  static const int passo = 5;

  static int segura(int valor) {
    if (valor < minima) return minima;
    if (valor > maxima) return maxima;
    return valor;
  }

  /// Arredonda para o passo do controle, dentro da faixa.
  static int comPasso(int valor) {
    final s = segura(valor);
    final arredondado = ((s / passo).round()) * passo;
    return segura(arredondado);
  }

  /// Limiar do modelo para a sensibilidade escolhida. Menor = acorda mais fácil.
  static double limiar(int valor) {
    final s = segura(valor);
    if (s >= 85) return 0.20;
    if (s >= 70) return 0.25;
    if (s >= 45) return 0.33;
    if (s >= 20) return 0.42;
    return 0.50;
  }

  /// Pontuação das palavras-chave, como no motor nativo.
  static double pontuacaoPalavra(int valor) {
    final s = segura(valor);
    if (s >= 85) return 2.0;
    if (s >= 70) return 1.8;
    return 1.5;
  }

  static String rotulo(int valor) {
    final s = segura(valor);
    if (s >= 85) return 'Máxima';
    if (s >= 70) return 'Alta';
    if (s >= 45) return 'Média';
    if (s >= 20) return 'Baixa';
    return 'Mínima';
  }

  /// Explica, em uma frase, o efeito prático do valor. Sem promessa de acerto:
  /// mais sensibilidade acorda mais fácil e também dispara mais por engano.
  static String descricao(int valor) {
    final s = segura(valor);
    if (s >= 85) {
      return 'Acorda com a pronúncia mais distante do modelo, inclusive falando '
          'baixo. Em ambiente com conversa pode disparar sozinha.';
    }
    if (s >= 70) {
      return 'Equilíbrio recomendado para uso normal: reconhece “Jarvis” falado '
          'de perto sem abrir demais o detector.';
    }
    if (s >= 45) {
      return 'Precisa de pronúncia mais clara e sem ruído por perto. Bom para '
          'quem recebe muitos disparos por engano.';
    }
    if (s >= 20) {
      return 'Bastante rígida: só acorda com “Jarvis” bem pronunciado e próximo '
          'do microfone.';
    }
    return 'Mínima: quase não acorda. Use apenas se o detector estiver '
        'disparando com o aparelho em silêncio.';
  }

  static String resumo(int valor) =>
      '$rotulo · limiar ${limiar(valor).toStringAsFixed(2)}';
}
