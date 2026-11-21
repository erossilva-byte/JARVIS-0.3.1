# Ajuste 077 — segundo plano de verdade (Fase 12)

## 1. Identificação

- **Versão:** 1.64.0+16400
- **Data:** 2026-11-19
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** `JARVIS-Nova-1.64.0-segundo-plano.apk` (arm64, release) — 117 627 604 bytes
- **SHA-256:** `8bbf6ce668555d7e6a035decd3fe504678420b23ddde67e09ae0e8f0e5417b5a`
- **Download (72 h):** https://litter.catbox.moe/yci18x.apk
- **Plataformas afetadas:** Android (Flutter/Dart e Kotlin). Windows não foi tocado.

## 2. Resumo do ajuste

Até aqui a palavra de ativação funcionava com o app fechado, mas **abria a tela**
para reconhecer o comando. Este ajuste inverte o caminho: com o modo sem tela
ligado, o serviço em primeiro plano escuta o comando, executa o que é de baixo
risco e responde falando, **sem abrir o app**. A tela mostra que ele está ativo
por uma notificação de alta prioridade e pelo estado real dentro do app.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivo |
|---|---|---|---|
| Interpretador e executor de fundo | nova função | Abrir app, lanterna, volume e alarme com registro fechado | `JarvisFundo.kt` |
| Escuta offline de comando | nova função | Comando curto sem abrir a tela, só reconhecedor do aparelho | `JarvisEscutaFundo.kt` |
| Canal do Flutter | nova função | Estado, switch do modo, autorização e teste por escrito | `JarvisFundoCanal.kt` |
| Serviço em primeiro plano | correção | Decide entre executar no fundo ou abrir a tela; fala a resposta | `KwsForegroundService.kt` |
| Aviso na tela | nova função | Canal de alta prioridade “JARVIS ativo” sobre outros apps | `KwsForegroundService.kt` |
| Núcleo do estado | nova função | Regras de “pronto”, pendências, resumo e idade da ação | `lib/core/fundo.dart` |
| Serviço Dart | nova função | Ponte com falha explícita fora do Android | `lib/services/fundo_service.dart` |
| Tela | nova função | Estado real, switch, autorização, pendências e teste | `lib/services/segundo_plano_page.dart` |
| Navegação | melhoria | “Android e dispositivos → Segundo plano” | `lib/pages.dart` |
| Manifesto e preparação | melhoria | `SYSTEM_ALERT_WINDOW` e cópia idempotente dos novos arquivos | `AndroidManifest.xml`, `tool/prepare_android_sistema.py`, `tool/prepare_android_kws.py` |

Regras de segurança mantidas:

- O comando por voz usa **somente** `createOnDeviceSpeechRecognizer` com
  `EXTRA_PREFER_OFFLINE`; não existe fallback de nuvem nem envio de áudio.
- Nada de shell, intent arbitrária ou execução de texto livre: o texto passa pelo
  mesmo registro fechado de quatro ações.
- Abrir app e abrir o alarme exigem `Settings.canDrawOverlays`; sem a
  autorização, a resposta diz o que falta em vez de falhar em silêncio.
- Volume é lido de volta depois de aplicado; app ausente e nome ambíguo têm
  respostas próprias.
- O modo antigo (abrir a tela) continua disponível com o switch desligado.

## 4. Evidência

| Prova | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | Limpo, sem issues |
| Núcleo do segundo plano | `dart run tool/fundo_test.dart` | Aprovado (6 grupos) |
| Teste de widget da tela | `flutter test test/segundo_plano_page_test.dart` | 5 testes aprovados |
| Suíte Flutter completa | `flutter test` | 174 testes aprovados |
| Contrato estático | `python3 tests/test_fundo_flutter.py` | Aprovado |
| Contratos anteriores | `test_tarefas_flutter`, `test_engenharia_flutter`, `test_visao_flutter` | Aprovados com a versão 1.64.0 |
| Compilação Kotlin | `flutter build apk --release --target-platform android-arm64` | `✓ Built … app-release.apk` |

O contrato estático confere, entre outros pontos, que o serviço consulta o modo
sem tela **antes** de tentar abrir a tela, que `podeAbrirApps` é checado **antes**
de `startActivity`, que não existe `createSpeechRecognizer` (versão que pode ir
para a nuvem) e que a permissão `SYSTEM_ALERT_WINDOW` está no manifesto e no
script de preparação.

## 5. Artefato

- `files/JARVIS-Nova-1.64.0-segundo-plano.apk` (arm64, release), 117 627 604 bytes
- SHA-256 `8bbf6ce668555d7e6a035decd3fe504678420b23ddde67e09ae0e8f0e5417b5a`
- Download temporário (72 h): https://litter.catbox.moe/yci18x.apk
- Conferido dentro do APK: `AndroidManifest.xml` declara `SYSTEM_ALERT_WINDOW`; o
  `classes.dex` contém a string `com.jarvis.nova/fundo` (canal registrado); o
  `libapp.so` contém o texto da tela “Segundo plano”. Os nomes de classe do
  Kotlin não aparecem porque o build de release os ofusca — comportamento
  esperado do R8, não ausência de código.

## 6. Não verificado

- **Nenhum teste em aparelho físico.** Não medi: detecção da palavra com o app
  fechado, abertura de app a partir do segundo plano com a autorização ligada,
  tempo de resposta do reconhecedor offline, comportamento com a tela apagada e
  funcionamento sob HyperOS.
- Não há como provar aqui que o Android aceita `startActivity` do serviço em
  todos os aparelhos, mesmo com “Exibir sobre outros apps” autorizado: a exceção
  é documentada, mas o fabricante pode restringir mais.
- A voz de resposta depende do mecanismo TTS instalado; o timbre não foi ouvido
  neste ambiente.
- O aviso de alta prioridade no modo Não Perturbe não foi observado.

## 7. Limitações declaradas na própria tela

- Reiniciar o aparelho não reinicia o serviço de microfone (restrição do
  Android); a escuta volta quando o app é aberto uma vez.
- Perguntas livres e conversa com IA continuam abrindo a tela.
- O reconhecimento é o offline pt-BR do Android; sem o pacote instalado, o
  JARVIS avisa em vez de usar a nuvem.

## 8. Artefato final

- Build: `flutter build apk --release --target-platform android-arm64` terminou
  com `✓ Built build/app/outputs/flutter-apk/app-release.apk (117.6MB)` em 92 s,
  sem erro — o que também comprova que os arquivos Kotlin novos compilam.
- `files/JARVIS-Nova-1.64.0-segundo-plano.apk` · 117 627 604 bytes ·
  SHA-256 `8bbf6ce668555d7e6a035decd3fe504678420b23ddde67e09ae0e8f0e5417b5a`
- https://litter.catbox.moe/yci18x.apk (72 h)
- Nada instalado nem executado no Poco X7: a instalação e o teste de voz com o
  app fechado continuam pendentes do usuário.
