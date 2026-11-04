# Assinatura de release do APK

O APK publicado usa uma chave **privada de release**. A chave de debug que está em
`ci/debug.keystore` é pública (qualquer pessoa com o repositório tem o arquivo e a
senha `android`), então ela serve só para builds de desenvolvimento.

Sem os segredos abaixo, o workflow `.github/workflows/release-apk.yml` **falha de
propósito** em vez de publicar um APK assinado com a chave de debug.

## 1. Gerar a chave (uma única vez)

Precisa de um JDK (`keytool`). No Windows, o JDK 21 do Temurin serve.

```powershell
keytool -genkeypair -v `
  -keystore jarvis-release.jks `
  -alias jarvis `
  -keyalg RSA -keysize 4096 -validity 10000 `
  -storetype PKCS12
```

Guarde o arquivo `jarvis-release.jks` e a senha **fora do repositório** (gerenciador
de senhas + cópia offline). Se a chave ou a senha forem perdidas, não é possível
atualizar o app instalado: só reinstalando com uma chave nova.

## 2. Registrar os segredos no GitHub

```powershell
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("jarvis-release.jks"))
gh secret set ANDROID_KEYSTORE_BASE64 --repo erossilva-byte/JARVIS-0.3.1 --body $b64
gh secret set ANDROID_KEYSTORE_PASSWORD --repo erossilva-byte/JARVIS-0.3.1
gh secret set ANDROID_KEY_ALIAS --repo erossilva-byte/JARVIS-0.3.1
gh secret set ANDROID_KEY_PASSWORD --repo erossilva-byte/JARVIS-0.3.1
```

Os dois últimos pedem o valor no terminal (não fica no histórico). O alias padrão do
exemplo é `jarvis`.

## 3. Conferir antes de publicar

Rode o workflow manualmente no branch desejado:

```powershell
gh workflow run release-apk.yml --repo erossilva-byte/JARVIS-0.3.1 --ref feat/evolucao-1.42.0
gh run watch --repo erossilva-byte/JARVIS-0.3.1
```

O passo "Compilar APK de release assinado" roda `apksigner verify --print-certs` e
aborta se o certificado for `CN=Android Debug`. Em `workflow_dispatch` de branch o
release **não** é publicado (a publicação exige uma tag).

## 4. Build local com a mesma chave

Crie `android/app/keystore.properties` (ignorado pelo Git):

```properties
storeFile=/caminho/absoluto/jarvis-release.jks
storePassword=...
keyAlias=jarvis
keyPassword=...
```

Depois de `npx cap add android`, rode `python3 patch_gradle.py android/app/build.gradle`
e `./gradlew assembleRelease`.

## 5. Migração de quem já instalou o APK de debug

Um APK assinado com a chave de release **não instala por cima** de um APK assinado
com a chave de debug: o Android recusa com "app não instalado". O atualizador
(`JarvisUpdatePlugin`) agora detecta a troca de chave e explica isso antes de abrir
o instalador. A migração é feita uma vez:

1. Desinstalar o J.A.R.V.I.S. Nova (os dados locais são apagados).
2. Instalar o APK de release manualmente.
3. As próximas atualizações voltam a funcionar pelo próprio app.

## 6. Rotação

Se a chave vazar, gere outra e repita os passos 1–3. A troca também exige a
desinstalação descrita no passo 5. Para usar rotação de chave do Android
(`apksigner rotate`), é preciso configurar `--lineage`; não é o caso atual.
