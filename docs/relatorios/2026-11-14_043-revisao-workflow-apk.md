# Ajuste 043 — revisão do workflow do APK (2026-11-14)

## Por que

O workflow gerava o APK e publicava o artefato, mas nada provava que atalhos, widget e
compartilhamento entravam no pacote. Também havia uma suposição não testada: a preparação do
runner funcionar sobre o runner realmente gerado pelo `flutter create`.

## O que foi revisado

### Simulação fiel da preparação

Copiei o `flutter_app`, rodei `flutter create --platforms=android` como o CI faz, apliquei a
troca de identificador do workflow e executei, em sequência, `prepare_android_kws.py` e
`prepare_android_sistema.py` (com assets KWS de mentira, só para o script aceitar):

- o runner foi gerado sem tocar no `android/MainActivity.kt` do repositório;
- os dois scripts rodaram sobre o runner real e o manifesto ficou com serviço KWS, receptor do
  widget, meta-data de atalhos, `MAIN`, `SEND` e as três ações;
- o Gradle ficou com a dependência do sherpa-onnx.

### Etapas novas no workflow

1. **Testar a preparação** (`python3 ../tests/test_sistema_android.py`) logo depois de aplicar a
   integração, no job Android. É o mesmo teste de runner falso da suíte.
2. **Conferir o APK** depois do build: o pacote precisa conter `res/xml/shortcuts.xml`,
   `res/xml/jarvis_widget_info.xml` e `res/layout/jarvis_widget.xml`; o manifesto precisa citar
   `JarvisWidgetProvider`, `android.app.shortcuts`, `ACAO_VOZ` e `ACTION_SEND`; os atalhos
   precisam citar as três ações; e o código (todos os `classes*.dex`) precisa conter as ações e o
   canal `com.jarvis.nova/sistema`. Usa `aapt2` quando existe e cai para `strings` quando não.
3. A publicação do artefato continua depois da conferência, com `if-no-files-found: error`.

### Defeitos encontrados na revisão

- O fallback do `aapt2` quebrava com `set -euo pipefail` quando o SDK não estava no ambiente: o
  `ls` sem correspondência derrubava o passo. Corrigido com `|| true` e uso de `ANDROID_HOME` ou
  `ANDROID_SDK_ROOT`.
- A conferência do código olhava só `classes.dex`; agora junta todos os `classes*.dex`.
- `colors.xml` poderia colidir com um arquivo do template; renomeado para `jarvis_cores.xml`.
- O `pubspec.yaml` não declarava a versão mínima de Flutter exigida pelo `material_ui`; agora
  declara `flutter: ">=3.47.0"`.

## Verificação

```
python3 tests/test_workflow_flutter.py  → workflow atual OK + 5 defeitos sintéticos detectados
python3 tests/test_sistema_android.py   → 5 casos, OK (inclusive rodando de flutter_app/)
bash verify_apk.sh (extraído do YAML)   → APK falso completo passa; sem atalhos, sem receptor
                                          e sem canal no dex falham
flutter analyze                         → No issues found!
npm run verificar                       → 4 de 4 etapas, 2.372 verificações
```

O teste do workflow é calibrado: remove a preparação, a conferência, uma marca do APK, o
`if-no-files-found` ou troca a ordem de compilar/conferir, e cada mutação reprova.

## Limites

- Nenhum APK foi compilado nesta máquina (sem Android SDK); a primeira compilação real é no CI.
  O que está provado aqui é que a preparação funciona no runner gerado e que a conferência do
  pacote aceita um APK completo e recusa um incompleto.
- O widget e os atalhos ainda não foram vistos funcionando num aparelho.
- A conferência lê nomes no APK; ela não abre o app nem exercita a folha de compartilhamento.
