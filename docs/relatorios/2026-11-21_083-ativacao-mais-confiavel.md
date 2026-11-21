# 083 — palavra de ativação mais confiável, com sensibilidade na tela

**Versão:** 1.70.0+17000 · **Data:** 2026-11-21 · **Bloco:** 083
**Pedido:** “O detector às vezes não me ouve quando eu chamo ‘Jarvis’. Deixe a
palavra de ativação mais confiável, com sensibilidade ajustável na tela.”

## 1. O relato e o que ele significava

“Às vezes não me ouve” é a descrição de três problemas diferentes que estavam no
código, não no microfone:

| O que o usuário sente | O que estava acontecendo |
|---|---|
| Fala “Jarvis” e nada acontece | o limiar do detector era **fixo em 0,25** (sensibilidade 75) e só existia na tela antiga do app desktop; no app Flutter não havia controle nenhum |
| Aumentar não melhorava muito | o limiar tinha **três faixas**: tudo entre 45 e 69 caía no mesmo 0,33 e tudo acima de 70 no mesmo 0,25 |
| “Ele morreu, só voltou quando abri o app” | qualquer erro do motor chamava `stopSelf()`; sem comando em curso, ninguém religava o detector |
| “Acordou, mas ficou surdo um tempo” | depois de abrir a tela, o detector só voltava em **35 s** se a tela não devolvesse o microfone |

Nenhuma das causas é permissão nem microfone quebrado: por isso reinstalar ou
trocar de aparelho não resolvia.

## 2. O que mudou no detector

- **Cinco faixas de limiar** (`JarvisKwsEngine.limiarPara`), de 0,50 na mínima a
  0,20 na máxima, e a pontuação das palavras-chave acompanha (1,5 → 1,8 → 2,0).
  Subir a sensibilidade agora abre o detector de verdade.
- **O padrão continua 75** — quem já usava não percebe mudança de comportamento
  até mexer no controle.
- **Sensibilidade gravada no aparelho** (`jarvis_kws`), lida pelo serviço a cada
  início do motor, sem depender de o app estar aberto.
- **Falha do motor não desliga mais a escuta**: até três tentativas com espera
  crescente (2 s, 4 s, 6 s, limitada a 15 s). Só depois disso o serviço se encerra,
  e o aviso mostra o motivo.
- **Vigia de 20 s**: se o motor morrer em silêncio (JNI, captura, fabricante),
  o serviço religa o detector sozinho — mas nunca durante um comando nem nos 20 s
  seguintes a uma ativação.
- **Rearme em 8 s** em vez de 35 s: a tela já assume o microfone e o serviço
  bloqueia o religamento enquanto o comando está ativo, então a espera longa não
  era mais necessária.

## 3. O que foi feito

### Android (Kotlin/Java)
- `KwsForegroundService.kt`: `sensibilidadeDe()`, `definirSensibilidade()`,
  ação `ACTION_REINICIAR`, `falhasMotor` + `atrasoFalha()`, `iniciarVigia()` /
  `pararVigia()`, `REARM_DELAY_MS = 8_000L` e o motor recebendo a sensibilidade
  escolhida em vez do literal `75`.
- `MainActivity.kt`: métodos `sensibilidade` e `definirSensibilidade` no canal
  `com.jarvis.nova/kws`, e o diagnóstico devolvendo `sensibilidade` e `limiar`.
- `JarvisKwsEngine.java`: `limiarPara()`, `pontuacaoPalavra()`, `limiar()` e o
  construtor guardando a sensibilidade usada.

### Flutter
- `core/ativacao_sensibilidade.dart`: faixa, passo, limiar, pontuação, rótulos e
  descrição — modelo puro, espelhando o Java.
- `services/kws_bridge.dart`: `KwsStatus.sensibilidade`/`limiar` e
  `definirSensibilidade()`, que grava e relê o estado.
- `services/kws_controller.dart`: ação de ajuste e valor atual expostos à tela.
- `services/kws_settings_page.dart`: controle deslizante 0–100% em passos de 5,
  com rótulo, explicação, limiar em uso e confirmação depois de gravar.

### Testes e documentação
- `tool/ativacao_sensibilidade_test.dart` (puro, 7 grupos).
- `test/kws_sensibilidade_page_test.dart` (widget: mostra, grava, confirma).
- `test/kws_controller_test.dart`: gravação, leitura de volta e limite de faixa.
- `tests/test_sensibilidade_ativacao_flutter.py`: contrato estático novo,
  incluindo a paridade dos pares sensibilidade→limiar entre Dart e Java.
- Versão, `CHANGELOG.md`, `docs/INVENTARIO_DE_FUNCOES.md` e trava de versão dos
  contratos anteriores atualizadas.

## 4. Evidência

Comandos executados neste bloco, com o resultado obtido no fechamento:

| Verificação | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `dart run tool/ativacao_sensibilidade_test.dart` | aprovado (7 grupos puros) |
| `flutter test test/kws_sensibilidade_page_test.dart test/kws_controller_test.dart` | 13 testes aprovados |
| `flutter test` (suíte inteira) | `+196: All tests passed!` |
| `python3 tests/test_sensibilidade_ativacao_flutter.py` | contrato aprovado |
| `python3 tests/test_kws_pipeline.py` | aprovado (trocada a trava do 75 fixo pela sensibilidade escolhida) |
| `npm run test:all` | `EXIT_TEST_ALL=0` |
| `flutter build apk --release --target-platform android-arm64` | APK de 117 825 900 bytes |

APK release arm64: `JARVIS-Nova-1.70.0-ativacao.apk`,
SHA-256 `8e4a49d718e33460f4816e848458357d72f6fc8269d6202f9651856f2be20d1a`,
disponível em https://files.catbox.moe/p5zmul.apk.

Os limites de sensibilidade continuam: mais sensibilidade = mais falsos disparos
(presos por teste onde dá, medidos no aparelho onde não dá).

## 5. Como usar

1. Abra **Voz e palavra de ativação**.
2. Ligue a palavra de ativação.
3. Use **Teste de ativação · 20 segundos** e fale “Jarvis” cinco vezes.
4. Se acordou menos de cinco vezes, suba a sensibilidade um passo (5%) e repita.
5. Se acordou sozinho com a TV ou conversa por perto, desça um passo.
6. A partir de 85% o detector aceita pronúncia bem distante do modelo — é a faixa
   para quem fala baixo, ao custo de mais disparos por engano.

## 6. Não verificado

- **Nenhum aparelho físico foi usado.** Voz real, sotaque, distância do microfone,
  ruído de casa e o número de acertos por sensibilidade continuam sem medição.
- O modelo KWS é treinado em inglês; a sensibilidade aumenta a tolerância, mas não
  corrige a fonética do modelo.
- HyperOS pode matar o serviço em primeiro plano apesar do vigia; a recuperação
  depende do Android religar o serviço (`START_STICKY`).
- O tempo real de recuperação após uma falha do motor não foi medido.

## 7. Fechamento

O que dá para afirmar sem aparelho: a sensibilidade deixou de ser fixa, o limiar
tem cinco faixas conferidas nos dois lados (Dart e Java), o ajuste é gravado e
religado na hora, e o detector não fica mais surdo após uma falha do motor. O que
só o aparelho diz: quantas vezes o “Jarvis” é ouvido em cada faixa.
