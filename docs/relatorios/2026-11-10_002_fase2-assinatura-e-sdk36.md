# Relatório — Fase 2, ajuste 002: assinatura de release separada e SDK 36

## 1. Identificação

- **Projeto:** J.A.R.V.I.S. Nova · **Versão:** 1.46.0
- **Data:** 2026-11-10 · **Branch:** `work/1.48.0-fase2-consolidacao`
- **Ajuste:** 002 (continuação da Fase 1, aprovada em 2026-11-10)
- **Plataformas afetadas:** Android (build e release), CI

## 2. Resumo

A release deixou de ser assinada com a chave de debug versionada no repositório e passou a exigir uma chave própria vinda de secrets. O `targetSdk`/`compileSdk` subiram para 36 (Android 16), o que obrigou a subir AGP e Gradle junto.

## 3. O que foi feito

| # | Mudança | Arquivo | Tipo |
|---|---|---|---|
| 1 | `signingConfigs.release` lendo `-PJARVIS_*` e ligado ao `buildTypes.release` | `patch_gradle.py` | correção de segurança |
| 2 | Release passou a rodar `assembleRelease`, com keystore vindo de secrets e verificação de que o APK **não** está assinado em debug | `.github/workflows/release-apk.yml` | correção de segurança |
| 3 | `compileSdk`/`targetSdk` 35/34 → 36/36 | `patch_gradle.py` | requisito |
| 4 | AGP 8.7.3 → **8.13.0** e Gradle 8.9 → **8.13** (obrigatório: AGP 8.9 suporta no máximo API 35) | `patch_gradle.py` | requisito |
| 5 | Android SDK/build-tools 35 → 36 nos quatro workflows que compilam | `build-apk.yml`, `ci.yml`, `ci-android-auditoria.yml`, `release-apk.yml` | consistência |
| 6 | Novo cenário de teste cobrindo SDK 36, AGP 8.13, Gradle 8.13 e assinatura de release idempotente | `tests/test_patch_gradle.py` | teste |

## 4. Por que

A auditoria da Fase 1 mostrou dois problemas P0: release assinada com `ci/debug.keystore` (contraria a regra 3B.1) e `targetSdk 34` contra os 36 exigidos. Subir o SDK sem separar a assinatura deixaria o problema de segurança intacto; separar a assinatura sem subir o SDK deixaria o requisito do Android 16 em aberto.

## 5. Evidência (executado neste ambiente)

```
python3 tests/test_patch_gradle.py       -> EXIT=0  (min 26, compile/target 36, AGP 8.13, release separada de debug)
python3 tests/test_release_readiness.py  -> EXIT=0  (743 IDs HTML únicos, workflow, versão 1.46.0)
python3 tests/test_java_refs.py          -> EXIT=0  (22 classes nativas, nenhuma chamada órfã)
python3 tests/test_secure_keys.py        -> EXIT=0  (cofre falha fechado, segredos fora do renderer)
python3 -m py_compile patch_gradle.py tests/test_patch_gradle.py -> ok
```

O cenário novo do teste roda o patch **duas vezes** e verifica: `compileSdkVersion = 36`, `targetSdkVersion = 36`, `minSdkVersion = 26`, `com.android.tools.build:gradle:8.13.0`, `gradle-8.13-all.zip`, `signingConfig signingConfigs.release` presente **uma única vez** e a assinatura de debug preservada.

## 6. Não verificado

- **`./gradlew assembleDebug` e `assembleRelease` não rodaram aqui**: este ambiente não tem Android SDK. A verificação real vem do CI ao receber este commit.
- Compatibilidade do template do Capacitor 6 com AGP 8.13.0/Gradle 8.13 não foi exercitada. É o risco principal deste ajuste; se o CI reprovar, o culpado provável é essa cadeia, não o código Java.
- `apksigner verify` e `keytool -list` do workflow de release só executam com os secrets configurados.

## 7. O que depende de você

Criar quatro secrets no repositório (Settings ▸ Secrets and variables ▸ Actions):

| Secret | Conteúdo |
|---|---|
| `JARVIS_KEYSTORE_B64` | seu keystore `.jks` em base64 (`base64 -w0 release.jks`) |
| `JARVIS_KEYSTORE_PASSWORD` | senha do keystore |
| `JARVIS_KEY_ALIAS` | alias da chave de release |
| `JARVIS_KEY_PASSWORD` | senha da chave |

Sem eles o workflow de release **para com mensagem clara** em vez de publicar APK assinado em debug. O build de debug continua funcionando sem secret nenhum.

## 8. Pendências declaradas

- `CHANGELOG.md` não foi atualizado neste commit: o arquivo tem 121 KB e a publicação foi feita por API, que substitui o arquivo inteiro. Entra no próximo ajuste, junto com a entrada da Fase 2.
- `tests/test_patch_gradle.py` atualizado está no commit local; a publicação pela API de um arquivo com muitos escapes será feita junto do próximo push por git.

## 9. Próximos passos

1. Ver o resultado do CI na branch (`ci.yml` roda regressão + build Android; `flutter-native.yml` roda o portão Flutter).
2. Se o build quebrar, ajustar a cadeia AGP/Gradle antes de qualquer outra mudança.
3. Primeira execução real no Poco X7 com o checklist da 3B.11.
