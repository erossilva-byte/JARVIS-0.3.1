# Ajuste 089 — perguntas no segundo plano com o app fechado

Data: 2026-11-21 · Versão: 1.75.1+17501 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido

O usuário chamou o JARVIS pelo segundo plano e perguntou “como está tudo,
Jarvis” e “Jarvis, me fale sobre culinária no geral”. Em vez da resposta, o
aviso da imagem: “Não consegui consultar a IA agora. O app precisa estar aberto
e com um provedor configurado; abra o JARVIS e pergunte de novo.”

## 2. O que estava errado

- A ponte do ajuste 085 levava a pergunta ao Flutter por um `MethodChannel`, mas
  só existia **enquanto o motor do app estava vivo**. Com o app encerrado (ou
  descartado pelo Android em segundo plano), ninguém atendia o canal e a ponte
  devolvia `null`.
- Com `null`, o serviço falava sempre a mesma frase — inclusive quando havia
  provedor configurado e internet boa. O usuário não tinha como saber que o
  problema era o app estar fechado, e a função simplesmente não existia fora da
  tela.
- O aviso já era honesto (nada de resposta inventada), mas inútil: mandar abrir
  o app para perguntar por voz derrota o segundo plano.

## 3. O que foi feito

### Motor sem tela no serviço

- **`main.dart` ganhou a entrada `mainFundo`** (`@pragma('vm:entry-point')`):
  inicializa os plugins e liga a mesma `PonteIaFundo`, sem `runApp` e sem tela.
- **`JarvisPonteIa.kt`** agora sobe um **motor sem tela** quando o canal do app
  não existe: `FlutterEngine(contexto)` + `DartEntrypoint(
  "package:jarvis_nova/main.dart", "mainFundo")`. É o mesmo `ProviderService`,
  as mesmas chaves do cofre seguro e a mesma personalidade — nenhuma chave ou
  endpoint foi copiado para o Kotlin.
- **Espera sem adivinhação**: o Dart leva alguns instantes para registrar o
  atendimento. A ponte tenta de novo a cada 300 ms por até 12 s e só então
  desiste com `indisponivel`, em vez de mandar a pergunta para o vazio.
- **Memória contida**: o motor sem tela é desligado após 3 minutos sem
  perguntas, quando o app volta a atender (o motor do app assume) e no
  `onDestroy` do serviço. Sem isso, a palavra de ativação manteria um segundo
  motor de ~50 MB ligado 24 h por dia.
- **Prazo total de 50 s** (12 s de subida + 35 s de provedor) antes de avisar que
  demorou demais.

### Resposta honesta, agora com motivo

- `sem_provedor` → “Nenhum provedor de IA está configurado. Abra o JARVIS,
  cadastre a chave do provedor e pergunte de novo.”
- `tempo` → “O provedor de IA demorou demais para responder. Tente de novo em
  instantes.”
- Falha de rede/canal → “Não consegui consultar a IA agora. Verifique a conexão
  e tente de novo em instantes.”

A frase “O app precisa estar aberto” saiu do código: deixou de ser verdade como
regra geral.

## 4. Evidência

- `flutter analyze` → limpo.
- `flutter test` → suíte do app passando, incluindo o novo
  `test/ponte_ia_fundo_test.dart` (sem chave, a ponte sinaliza `sem_provedor`).
- Contrato novo `tests/test_fundo_motor.py` em `npm run test:all`: exige a
  entrada `mainFundo`, o motor sem tela, a espera pelo canal, o desligamento por
  ociosidade e no fim do serviço, as três frases de motivo, a ausência de chaves
  e de rede no Kotlin e nenhuma permissão nova.
- Contrato do ajuste 085 atualizado para o novo prazo da ponte.
- APK release arm64: `JARVIS-Nova-1.75.1-segundo-plano.apk`, 117 973 948 bytes,
  SHA-256 `549f5024649549db9d25ddf920f70c2aebac6921e7d38b0b3213334aaa1ee0fc`
  (https://files.catbox.moe/787tge.apk).

## 5. Arquivos

- `flutter_app/lib/main.dart`: entrada `mainFundo`.
- `flutter_app/android/JarvisPonteIa.kt`: motor sem tela, espera pelo canal,
  motivos de falha e desligamento ocioso.
- `flutter_app/android/KwsForegroundService.kt`: contexto na ponte, frases por
  motivo e `JarvisPonteIa.encerrar()` no fim do serviço.
- `flutter_app/test/ponte_ia_fundo_test.dart` (novo).
- `tests/test_fundo_motor.py` (novo), `tests/test_resposta_qualquer_modo_flutter.py`
  ajustado, `package.json`.

## 6. Não verificado

- **Nenhum aparelho físico nesta sessão**: não medi o tempo de subida do motor
  sem tela (esperado entre 1 e 4 s), o consumo extra de memória enquanto ele
  está vivo, nem o comportamento do HyperOS ao matar o serviço.
- O motor sem tela usa os mesmos plugins do app; se o Android negar o cofre
  seguro nesse contexto, a resposta será `sem_provedor` mesmo com chave
  cadastrada — isso não pôde ser testado sem aparelho.
- As habilidades em Markdown continuam dependendo do SAF da tela; no motor sem
  tela elas são ignoradas (a resposta usa só provedor e personalidade).
- Nada foi commitado nem enviado.
