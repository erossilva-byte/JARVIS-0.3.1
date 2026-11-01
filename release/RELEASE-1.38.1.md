# J.A.R.V.I.S. Nova 1.38.1

**Auditoria corretiva: cancelamento, Visão, roteador e senha.**

## Arquivos

- `jarvis-nova-1.38.1-10381.apk` — APK Android (debug/CI, assinatura v2).
- `jarvis-nova-1.38.1-10381.apk.sha256` — checksum do APK.
- `JARVIS-Nova-1.38.1-fonte.zip` — código-fonte, testes, documentação e projeto Android (sem `node_modules`, builds e APKs antigos).
- `JARVIS-Nova-1.38.1-release.zip` — APK + checksum + relatórios e LEIA-ME.

- Tamanho: 81195283 bytes.
- SHA-256: `28a87cb3ec4eaa6d890047406c481190ff8868d080391ce679a0cf832ca8af5b`.
- `aapt`: `com.jarvis.nova`, 1.38.1, versionCode 10381, minSdk 26, targetSdk 34, compileSdk 35.
- Assinatura v2 conferida com `apksigner`.

## O que mudou

- Tarefa cancelada durante a última etapa não pode mais virar `concluida`; a etapa fica incerta e a trava é liberada no `finally`.
- Removidas as declarações duplicadas da Visão 2.0; reabrir o painel limpa a análise anterior.
- Roteador descarta provedores desconhecidos/duplicados e não estoura com lista inválida.
- Gerador de senha com sorteio uniforme e sem viés de módulo.
- Preparação de ação com exceção devolve falha explícita, em vez de escapar sem recibo.
- GitHub Actions: testes movidos para depois da geração/patch do Android; `patch_gradle.py` agora fixa `minSdk 26`, `compileSdk 35` e `targetSdk 34` no `variables.gradle` gerado. O workflow de build aceita `JARVIS-Nova-*-fonte.zip` e `JARVIS-NOVA-*-fonte.zip`. A falha da `v1.38.0` era `android/app/build.gradle` ausente.

## Limitações declaradas

O APK não foi instalado nem executado em aparelho físico. Microfone, wake word, notificações, câmera, acessibilidade, segundo plano e avatar em tela real continuam pendentes de validação no Poco X7. Chaves de IA e modelo `.task` reais, Windows, ESP32 e Home Assistant não foram testados. O APK é debug/CI, não uma build de produção.
