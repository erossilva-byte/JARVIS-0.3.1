# 060 — Fase 10B (1ª etapa): comandos Android de baixo risco

**Data:** 2026-11-17 · **Versão:** 1.48.1 · **Branch:** `work/1.48.0-fase2-consolidacao` · **Plataforma:** Android

## Resumo

O Jarvis passou a entender **lanterna, volume, abrir app e alarme** por texto ou voz e a executar
esses comandos **no próprio aparelho**, sem chave de IA e sem internet. O caminho é um registro
fechado de quatro ações; o app não recebe intents arbitrárias, shell ou código. A resposta só sai
depois de conferir o estado quando o Android permite conferir.

## O que foi feito

| Módulo | Tipo | Alteração |
|---|---|---|
| `lib/core/comandos_android.dart` | nova função | Registro de ações com risco/permissão e interpretador local em Dart puro. Reconhece “ligar/desligar/alternar lanterna”, “volume 50”, “30% de volume”, “aumentar/diminuir”, “silenciar”, “abrir <app>” e “alarme 7:30”. Perguntas (“como…”, “por que…”) e valores inválidos não são capturados. |
| `android/JarvisComandos.kt` | nova função | Canal `com.jarvis.nova/comandos`. Lanterna por `CameraManager` com callback de confirmação; volume por `AudioManager` relido; app por `queryIntentActivities` + `getLaunchIntentForPackage`; alarme por `AlarmClock.ACTION_SET_ALARM` com UI aberta. |
| `lib/services/comandos_android_service.dart` | ponte | Traduz o comando para o método nativo, trata ausência da ponte e erros com mensagem em português. |
| `lib/services/comandos_android_page.dart` | nova tela | “Android e dispositivos ▸ Abrir comandos do Android”: campo, exemplos, resultado e registro de ações. |
| `lib/services/voice_conversation_page.dart` | integração | O comando local é tentado **antes** de exigir provedor; a resposta entra na conversa e é falada. Limite de cinco comandos seguidos. |
| `tool/prepare_android_sistema.py` | build | Copia `JarvisComandos.kt`, registra no `MainActivity` e declara a consulta de apps com ícone no manifesto. |

## Segurança e limites aplicados

- Quatro métodos nomeados; nenhuma execução de código, shell ou intent fornecida pela IA.
- Sem `SEND_SMS`, `CALL_PHONE`, `WRITE_SETTINGS`, acessibilidade, `MANAGE_EXTERNAL_STORAGE`, root,
  ADB ou Shizuku.
- Volume de mídia apenas; Não Perturbe não é alterado.
- Alarme abre o relógio com `EXTRA_SKIP_UI=false`; o usuário confirma.
- App ambíguo devolve as opções em vez de escolher; app inexistente informa o motivo.
- “Abrir arquivo/pasta/conversa/memória/ajustes/CAD” não é capturado como abertura de app.
- A abertura de app e de alarme **não é declarada como verificada na tela**: o Android não devolve
  um recibo confiável de que a janela abriu. A mensagem diz que a abertura foi enviada.

## Testes executados

| Verificação | Resultado |
|---|---|
| `dart run tool/comandos_android_test.dart` | 6 grupos aprovados |
| `flutter test test/comandos_android_page_test.dart` | 4 testes aprovados |
| `python3 tests/test_comandos_android.py` | OK |
| `flutter analyze` | Sem problemas |
| Compilação do APK (Gradle/Kotlin) | Aprovada — APK 1.48.1 (155,8 MB) compilado; `versionName='1.48.1'` e `versionCode='14801'` conferidos com `aapt2 dump badging` |

## Não verificado

- **Aparelho físico:** a lanterna real, o volume real, a lista de apps instalados e o relógio não
  foram exercitados. O teste prova o contrato e a compilação, não o comportamento do Poco X7.
- **Fabricantes:** alguns Androids exigem que a tela esteja ligada para a lanterna; o app devolve
  erro se o callback não confirmar, mas isso não foi visto em aparelho.
- **Nome de app:** a consulta de pacotes depende da visibilidade do Android 11+; a consulta
  `MAIN/LAUNCHER` foi declarada, mas a lista real não foi medida.
- **Voz:** o comando falado depende do reconhecimento que já existe; não foi ouvido.

## Próximos passos da Fase 10B

1. Testar no Poco X7 com roteiro e registrar os quatro comandos, incluindo erros de permissão.
2. Segunda etapa: brilho (WRITE_SETTINGS), timer, abrir painel de Wi-Fi/Bluetooth e pesquisa web.
3. Só depois: SMS/ligações com confirmação alta, contatos e desambiguação real.
4. Fechar apps e automação de interface continuam parciais e dependem de acessibilidade opcional da
   Fase 10C; não serão prometidos antes disso.
