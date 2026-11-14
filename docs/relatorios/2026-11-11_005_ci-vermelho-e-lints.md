# Relatório — Fase 2, ajuste 005: CI vermelho no head da matriz e correção dos lints

## 1. O que aconteceu

Depois de publicar a matriz de capacidades e a divisão do `main.dart`, o workflow Flutter
(`42934663035`) reprovou no head `42b29ec`. O `ci.yml` do mesmo head passou. A falha foi no passo
`flutter analyze`, nos dois jobs (`flutter-android` e `flutter-windows`), em ~5 segundos.

## 2. Diagnóstico

O `analysis_options.yaml` **não estava versionado** no `flutter_app/`, e o workflow gera os runners
nativos com `flutter create --project-name jarvis_nova --platforms=android,windows .`. Esse comando
cria o `analysis_options.yaml` com `include: package:flutter_lints/flutter.yaml` — ou seja, o CI
analisava com os lints recomendados enquanto o ambiente local analisava sem nenhum. Daí o
"No issues found!" aqui e o vermelho lá.

Reprodução fiel em `/tmp/ci_sim`: cópia da árvore publicada, `flutter create` igual ao workflow,
`flutter pub get`, `dart format lib test`, `flutter analyze` → 6 avisos:

```
info • unnecessary_brace_in_string_interps • lib/command_center.dart:133
info • use_key_in_widget_constructors    • lib/ui_common.dart (5 widgets públicos)
```

## 3. O que foi corrigido

| Arquivo | Mudança |
|---|---|
| `flutter_app/lib/command_center.dart` | `'${moduleCount} áreas…'` → `'$moduleCount áreas…'` |
| `flutter_app/lib/ui_common.dart` | `BrandMark`, `Eyebrow`, `ModuleTile`, `SettingCard` e `FootnoteText` passam a aceitar `super.key` |
| `flutter_app/analysis_options.yaml` | versionado com o mesmo conteúdo que o CI gerava, para o ambiente local não divergir do CI |

As regras **não** foram desligadas: o código foi ajustado à regra.

## 4. Evidência

No head `08239c1` (`work/1.48.0-fase2-consolidacao`):

- **CI de desenvolvimento** (run `42935565678`): **verde**.
- **Flutter native UI validation** (run `42935565711`): **verde** — `flutter-android` (formato, analyze, 26 testes, `flutter build apk --debug`, verificação do APK e publicação do artefato), `flutter-windows` (analyze, 26 testes, `flutter build windows`, artefato publicado) e o agregador `advance-gate` exigindo as duas plataformas.

Local, na árvore sincronizada com o remoto: `flutter analyze` → `No issues found!`; `flutter test` →
26 testes passando.

## 5. Não verificado

- Nada foi executado em aparelho; o KWS real segue sem teste de campo (Gate B aberto).
- O APK e o build Windows foram gerados pelo CI, mas não abertos aqui.
