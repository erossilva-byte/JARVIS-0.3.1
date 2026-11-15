import 'dart:io';

import 'package:jarvis_nova/core/memoria_busca.dart';
import 'package:jarvis_nova/core/personalidade.dart';

void main() {
  // 1. Nível padrão e leitura tolerante.
  const padrao = Personalidade();
  assert(padrao.nivel == NivelHumor.equilibrado, 'padrão deveria ser equilibrado');
  assert(padrao.humorLigado, 'equilibrado deveria permitir humor');
  assert(!const Personalidade(nivel: NivelHumor.discreto).humorLigado, 'discreto não deveria ter humor');
  assert(nivelHumorDe('avancado') == NivelHumor.avancado, 'nome do nível não lido');
  assert(nivelHumorDe(null) == NivelHumor.equilibrado, 'nível ausente deveria cair no padrão');
  assert(nivelHumorDe('inventado') == NivelHumor.equilibrado, 'nível inválido deveria cair no padrão');

  // 2. JSON preserva o nível e não guarda mais nada.
  final personalidade = const Personalidade(nivel: NivelHumor.avancado);
  final voltou = Personalidade.deJson(personalidade.paraJson());
  assert(voltou.nivel == NivelHumor.avancado, 'nível não sobreviveu ao JSON');
  assert(personalidade.paraJson().length == 1, 'personalidade não deveria guardar outro dado');

  // 3. Tom do turno: sensível vence pressa.
  assert(tomDoTurno('estou com dor no peito') == TomDoTurno.sensivel, 'saúde não detectada');
  assert(tomDoTurno('meu pai morreu ontem') == TomDoTurno.sensivel, 'luto não detectado');
  assert(tomDoTurno('perdi o dinheiro do aluguel') == TomDoTurno.sensivel, 'dinheiro perdido não detectado');
  assert(tomDoTurno('preciso disso urgente, tenho pressa') == TomDoTurno.comPressa, 'pressa não detectada');
  assert(tomDoTurno('me explica esse código') == TomDoTurno.comum, 'pergunta comum virou especial');

  // 4. Discreto: personalidade sem piada.
  final discreto = estiloDoTurno(
    const Personalidade(nivel: NivelHumor.discreto),
    'meu computador está lento',
  );
  assert(discreto.prompt.contains('PERSONALIDADE'), 'discreto perdeu a personalidade');
  assert(discreto.prompt.contains('sem piadas'), 'discreto deveria proibir piada');
  assert(discreto.angulo == null, 'discreto não deveria receber ângulo de humor');

  // 5. Equilibrado e avançado exigem estilo, com limites explícitos.
  final equilibrado = estiloDoTurno(const Personalidade(), 'meu computador está lento');
  assert(equilibrado.prompt.contains('PERSONALIDADE OBRIGATÓRIA'), 'equilibrado sem regra obrigatória');
  assert(equilibrado.prompt.contains('nunca com a pessoa'), 'falta limite contra piada com a pessoa');
  assert(equilibrado.prompt.contains('não copie falas'), 'falta proibição de imitar filmes');
  assert(equilibrado.prompt.contains('A informação vem antes da graça'), 'falta ordem informação/humor');
  assert(equilibrado.angulo != null, 'equilibrado deveria receber um ângulo');

  final avancado = estiloDoTurno(const Personalidade(nivel: NivelHumor.avancado), 'meu computador está lento');
  assert(avancado.prompt.contains('Sarcasmo seco'), 'avançado sem sarcasmo');
  assert(avancado.prompt.contains('variando o alvo'), 'avançado sem variação de alvo');

  // 6. Assunto sensível suspende o humor mesmo no nível máximo.
  final sensivel = estiloDoTurno(
    const Personalidade(nivel: NivelHumor.avancado),
    'minha mãe está no hospital',
  );
  assert(sensivel.tom == TomDoTurno.sensivel, 'hospital não marcou o tom');
  assert(sensivel.prompt.contains('Humor zero'), 'sensível não zerou o humor');
  assert(!sensivel.prompt.contains('Ângulo de humor'), 'sensível não deveria receber ângulo');
  assert(sensivel.angulo == null, 'sensível não deveria devolver ângulo');

  // 7. Pressa encurta, sem virar piada.
  final pressa = estiloDoTurno(
    const Personalidade(nivel: NivelHumor.avancado),
    'preciso disso urgente, tenho pressa',
  );
  assert(pressa.prompt.contains('o usuário tem pressa'), 'pressa não informada ao modelo');
  assert(!pressa.prompt.contains('Ângulo de humor'), 'pressa não deveria ganhar ângulo no prompt');

  // 8. Ângulo não repete o que já foi usado.
  final primeiro = sugerirAngulo(const Personalidade(), 'meu computador está lento', semente: 3);
  assert(primeiro != null, 'deveria sugerir ângulo');
  final segundo = sugerirAngulo(
    const Personalidade(),
    'meu computador está lento',
    recentes: [primeiro!],
    semente: 3,
  );
  assert(segundo != null && segundo != primeiro, 'ângulo repetido na mesma conversa');
  assert(sugerirAngulo(const Personalidade(), '') == null, 'texto vazio não deveria ter ângulo');
  assert(sugerirAngulo(const Personalidade(), 'estou com dor no peito') == null,
      'assunto sensível não deveria ter ângulo');

  // 9. O estilo entra como primeira mensagem de sistema, antes do histórico.
  final mensagens = montarMensagens(
    [
      {'role': 'user', 'content': 'oi'},
    ],
    const ContextoMemoria(texto: '', usados: [], caracteres: 0),
    personalidade: equilibrado.prompt,
  );
  assert(mensagens.first['role'] == 'system', 'personalidade não é mensagem de sistema');
  assert(mensagens.first['content'] == equilibrado.prompt, 'prompt de personalidade alterado');
  assert(mensagens.last['content'] == 'oi', 'histórico não ficou depois da personalidade');

  stdout.writeln('OK: personalidade — níveis, tom sensível, pressa, limites e prompt na conversa');
}
