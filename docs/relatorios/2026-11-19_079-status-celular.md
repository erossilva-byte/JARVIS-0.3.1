# Ajuste 079 — status do celular e localização do aparelho (Fase 14)

## 1. Identificação

- **Versão:** 1.66.0+16600
- **Data:** 2026-11-19
- **Branch:** `work/1.48.0-fase2-consolidacao`
- **Commit:** não houve commit (trabalho local, sem autorização de push)
- **Artefato:** `JARVIS-Nova-1.66.0-status.apk` (arm64, release, 117 760 080 bytes)
- **SHA-256:** `8a698a22c6fc0645c53efa03f3903a9391e0d0d1e95581004f7ca4336141d93e`
- **Download:** https://files.catbox.moe/2t8o8o.apk
- **Plataformas afetadas:** Android (Flutter/Dart e Kotlin). Windows não foi tocado.

## 2. Resumo do ajuste

A **Central do aparelho** virou uma tela de status completa: **bateria, memória,
armazenamento, rede e tempo ligado** já existiam; agora ela também mostra as
**notificações** que o Android entregou ao JARVIS e a **localização do aparelho**,
lida na hora em que o usuário pede. O JARVIS também responde ao comando
**“onde estou”** com endereço aproximado, coordenadas, precisão e idade da
leitura — sem inventar endereço quando o Android não tem um.

## 3. O que foi feito

| Módulo | Tipo | Motivo | Arquivo |
|---|---|---|---|
| Localização nativa | nova função | `LocationManager` do Android, permissão checada, ponto novo com limite de 20 s, último conhecido como reserva | `JarvisLocalizacao.kt` |
| Endereço aproximado | nova função | `Geocoder` do próprio aparelho, fora da thread principal, marcado como aproximado | `JarvisLocalizacao.kt` |
| Canal do aparelho | melhoria | `localizacaoEstado`, `localizacao` e permissão `localizacao` (fina + aproximada) | `JarvisAparelho.kt`, `lib/services/aparelho_service.dart` |
| Comando falado | nova função | “onde estou”, “me diga onde estou”, “minha localização atual” | `lib/core/comandos_android.dart`, `JarvisComandos.kt` |
| Resposta do comando | melhoria | Frase honesta com lugar, coordenadas, precisão e idade | `lib/services/comandos_android_service.dart`, `lib/core/localizacao.dart` |
| Modelo puro | nova função | Estado dos provedores, validação de coordenadas, rótulos e frase | `lib/core/localizacao.dart` |
| Tela de status | melhoria | Seções de notificações e localização, botões de autorizar, ver, ouvir e limpar | `lib/services/dispositivo_page.dart` |
| Manifesto e preparação | melhoria | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` e cópia do Kotlin novo | `AndroidManifest.xml`, `tool/prepare_android_sistema.py` |

Regras de honestidade aplicadas:

- **Nada de localização sem permissão.** Sem autorização, a resposta diz o que
  falta e onde autorizar; não há coordenada de chute.
- **GPS desligado também é explicado**, e a leitura só acontece com um provedor
  ativo.
- **Precisão e idade sempre visíveis**; leitura com mais de 60 s é marcada como
  “último ponto conhecido”, e o endereço só aparece se o `Geocoder` do Android
  devolver um.
- **Coordenadas fora do planeta são recusadas** no Dart (`-90..90`, `-180..180`).
- **Sem armazenamento e sem envio:** a localização não é guardada nem sai do app;
  o `Geocoder` pode usar a rede do próprio Android e isso está escrito na tela.
- **Nenhuma dependência nova**, nenhum Google Play Services, nenhuma WebView.
- O comando **não intercepta perguntas**: “onde fica Paris?”, “como chegar no
  centro?” e “por que a localização está desligada?” continuam na conversa.

## 4. Evidência

| Prova | Comando | Resultado |
|---|---|---|
| Análise estática | `flutter analyze` | Limpo, sem issues |
| Núcleo da localização | `dart run tool/localizacao_test.dart` | Aprovado (12 grupos) |
| Comandos Android | `dart run tool/comandos_android_test.dart` | Aprovado (7 grupos, com o comando novo) |
| Tela de status | `flutter test test/dispositivo_page_test.dart` | 7 testes aprovados (4 novos) |
| Suíte Flutter | `flutter test` | **186 testes aprovados** (inclui os 7 de `dispositivo_page_test.dart` e os 4 novos) |
| Contrato do bloco | `python3 tests/test_status_celular_flutter.py` | Aprovado |
| Contratos de versão | `test_engenharia_flutter.py`, `test_fundo_flutter.py`, `test_tarefas_flutter.py`, `test_seguranca_flutter.py` | Todos aprovados |
| APK release arm64 | `flutter build apk --release --target-platform android-arm64` | Construído (117 760 080 bytes); só instalação e uso no aparelho ficaram fora |

O que **não** foi provado: GPS real, autorização de localização, `Geocoder` com
e sem internet, notificações do HyperOS e o comando falado — nada disso roda sem
o aparelho físico.

## 5. Limites conhecidos

- **Sem aparelho.** Nada deste bloco foi instalado no Poco X7. Precisão real,
  tempo até o primeiro ponto, comportamento do HyperOS com a permissão
  “somente ao usar o app” e o endereço aproximado continuam **não verificados**.
- **Localização só com o app aberto.** O comando falado no segundo plano não
  inclui “onde estou”; fazer isso exigiria serviço em primeiro plano com tipo
  `location`, o que é outro bloco.
- **A leitura é um ponto, não um rastro.** Não há histórico nem mapa.
- **Notificações continuam só em memória** (80 itens) e dependem do acesso
  especial do Android; se o processo reiniciar, a lista recomeça.
- **Sem geocodificação reversa garantida:** sem internet, o Android pode não
  devolver endereço; a tela então mostra apenas as coordenadas.
- **Bateria, memória e rede são o retrato do momento**, sem histórico nem
  comparação com outros apps.

## 6. Riscos

- **Privacidade:** coordenada é dado sensível. Mitigação aplicada: leitura só
  por ação explícita, sem gravação, sem envio, com aviso na tela e no CHANGELOG.
- **Permissão negada para sempre:** se o usuário marcar “não perguntar de novo”,
  o pedido do app não abre mais o diálogo; a mensagem devolvida pelo Android é
  mostrada como está e a tela continua explicando o que falta.
- **Provedor sem resposta:** o limite de 20 s evita travar a tela; depois disso a
  resposta é o último ponto conhecido ou a explicação de que nada chegou.

## 7. Próximo passo sugerido

Instalar o APK no Poco X7 e conferir, nesta ordem: (1) as quatro linhas de status
com os mesmos números de Configurações → Bateria/Memória; (2) autorizar o acesso
a notificações e ver uma notificação real aparecer; (3) negar a permissão de
localização e conferir o texto; (4) autorizar, ligar o GPS e comparar a
coordenada com um app de mapas; (5) dizer “onde estou” e ouvir a resposta.
