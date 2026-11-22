# Assinatura de release do JARVIS — chave permanente fora do repositório

O Android só instala uma atualização por cima de um app se o APK novo tiver **a
mesma assinatura** do instalado. A chave de debug é gerada por máquina e muda a
cada build em outro computador — por isso todo APK assinado em debug obriga o
usuário a desinstalar (e perder conversas, memória, fichas, cofre e PIN).

A partir daqui o build de release usa **key.properties**, com a chave guardada
fora do repositório. Sem chave, o build de release **para** em vez de gerar um
APK que não atualiza.

## 1. Gerar a chave (uma única vez)

Escolha uma pasta fora do repositório. Exemplo: `~/jarvis-release`.

```bash
mkdir -p ~/jarvis-release
cd ~/jarvis-release
keytool -genkeypair -v \
  -keystore jarvis-release.jks \
  -alias jarvis \
  -keyalg RSA -keysize 4096 -validity 10000
```

- `keytool` vem com o JDK 17 (`JAVA_HOME/bin/keytool`). No Windows, use o mesmo
  comando no PowerShell (ou `keytool.exe`), com aspas se o caminho tiver espaço.
- O programa pede **duas senhas**: a do keystore e a da chave (pode usar a
  mesma) e os dados do certificado (nome, organização, país; o que aparecer na
  tela de instalação).
- `-validity 10000` são ~27 anos. Não use validade curta: chave vencida também
  bloqueia atualização.
- Anote o **alias** (`jarvis` no exemplo). Ele é necessário no build.

Backup e guarda (o backup é obrigatório):

- `jarvis-release.jks` **e** as duas senhas no gerenciador de senhas;
- uma cópia do arquivo em outro lugar offline (pen drive, cofre);
- **nunca** no repositório, no chat, em e-mail ou em nuvem pública.

Perder a chave significa que nenhum APK futuro instala por cima: todo mundo teria
que desinstalar o JARVIS e perder os dados locais.

## 2. Criar o key.properties (fora do repositório)

```properties
storeFile=/home/SEU_USUARIO/jarvis-release/jarvis-release.jks
storePassword=SUA_SENHA_DO_KEYSTORE
keyAlias=jarvis
keyPassword=SUA_SENHA_DA_CHAVE
certificadoSha256=00:00:00:...:00
```

`storeFile` pode ser um caminho absoluto (recomendado) ou relativo à pasta
`flutter_app/android/app`. Os quatro campos são obrigatórios;
`certificadoSha256` é opcional e serve para a verificação automática.

Para obter a impressão digital que vai em `certificadoSha256`:

```bash
keytool -list -v -keystore ~/jarvis-release/jarvis-release.jks -alias jarvis \
  | grep -i "SHA256:"
```

No Windows, sem `grep`, rode só o `keytool -list -v ...` e copie a linha
`SHA256:`.

O build procura o arquivo nesta ordem:

1. variável de ambiente `JARVIS_KEY_PROPERTIES` (caminho completo do arquivo);
2. `flutter_app/android/key.properties`;
3. `~/.jarvis/key.properties`.

A opção 1 ou 3 mantém o segredo **fora da pasta do projeto** — é a recomendada.
As duas primeiras linhas do bloco de assinatura no `build.gradle.kts` mostram
essa ordem.

## 3. Compilar

```bash
cd flutter_app
flutter build apk --release --target-platform android-arm64
```

Sem chave, o build termina com:

> APK de release sem chave de assinatura. Crie key.properties com storeFile,
> storePassword, keyAlias e keyPassword … ou passe -PJARVIS_PERMITIR_DEBUG=true
> para um teste local.

Com a chave, o APK sai assinado pela sua chave. Para um teste local consciente
(sem publicar), existe a saída de emergência `JARVIS_PERMITIR_DEBUG=true` — o
APK sai assinado em debug e **não** serve para distribuir.

## 4. Conferir a assinatura

```bash
cd flutter_app
python3 tool/verificar_assinatura.py build/app/outputs/flutter-apk/app-release.apk --exigir-release
```

O script mostra o nome do certificado e o SHA-256 e falha quando o APK está
assinado em debug ou quando a impressão digital não confere com
`certificadoSha256` do key.properties. Guarde a impressão digital no relatório
de cada release: é ela que garante que o próximo APK atualiza por cima.

## 5. A troca obriga uma desinstalação (uma única vez)

Os APKs distribuídos até agora foram assinados com a chave de debug da máquina
que compilou. O primeiro APK assinado com a chave de release **não instala por
cima** desses: o Android recusa com `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

Antes de instalar o primeiro APK assinado de verdade:

1. faça a sincronização do cofre/memória que você usa (Obsidian ou pasta local);
2. exporte o que precisar (histórico, fichas, arquivos);
3. desinstale o JARVIS;
4. instale o APK de release assinado.

Daí em diante toda versão nova instala por cima, com os dados preservados, desde
que continue assinada pela mesma chave.

## 6. Build no GitHub Actions

A esteira do APK que se distribui é `.github/workflows/flutter-release-apk.yml`
(nome exibido: **APK de release assinado (Flutter)**). Ela roda por disparo
manual, compila `flutter build apk --release --target-platform android-arm64`,
assina com a chave dos secrets e publica o APK e o SHA-256 como artefato da
execução.

Ela usa quatro secrets do repositório:

| Secret | Conteúdo |
|---|---|
| `JARVIS_KEYSTORE_B64` | o `.jks` inteiro em base64 |
| `JARVIS_KEYSTORE_PASSWORD` | senha do keystore |
| `JARVIS_KEY_ALIAS` | alias da chave (`jarvis`) |
| `JARVIS_KEY_PASSWORD` | senha da chave |

### Cadastrar os secrets (uma vez)

1. Abra o repositório no GitHub → **Settings** → **Secrets and variables** →
   **Actions**.
2. Clique em **New repository secret** e crie um por um, com os nomes exatos da
   tabela (maiúsculas e `_` importam).
3. Para o primeiro, gere o base64 da sua chave **na sua máquina**:

   ```bash
   # Linux
   base64 -w0 ~/jarvis-release/jarvis-release.jks > keystore.b64

   # macOS (sem quebra de linha)
   base64 -i ~/jarvis-release/jarvis-release.jks | tr -d '\n' > keystore.b64
   ```

   No Windows (PowerShell):

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\jarvis-release\jarvis-release.jks")) | Set-Content -NoNewline keystore.b64
   ```

4. Abra o `keystore.b64`, copie **todo** o conteúdo (é uma linha só, longa) e
   cole no campo **Secret** de `JARVIS_KEYSTORE_B64`.
5. Repita para `JARVIS_KEYSTORE_PASSWORD`, `JARVIS_KEY_ALIAS` (`jarvis`) e
   `JARVIS_KEY_PASSWORD`.
6. Apague o `keystore.b64` da sua máquina depois de colar
   (`rm keystore.b64`) — ele é a sua chave em texto.
7. Rode a esteira: **Actions** → **APK de release assinado (Flutter)** →
   **Run workflow**. O log mostra o certificado e o SHA-256 conferidos; o APK
   fica em **Artifacts**.

Se algum secret faltar, o job para com uma mensagem dizendo qual — ele nunca cai
na chave de debug. O keystore decodificado vive em `$RUNNER_TEMP`, fora do
repositório, e é descartado no fim da execução; o `key.properties` temporário é
apontado por `JARVIS_KEY_PROPERTIES`, com `storeFile` absoluto.

O build do app Capacitor antigo (`release-apk.yml`) usa os mesmos quatro nomes e
passa as propriedades `-PstoreFile=… -PstorePassword=… -PkeyAlias=… -PkeyPassword=…`;
o `build.gradle.kts` do Flutter aceita as duas formas.

## 7. O que nunca entra no repositório

- `.jks`, `.keystore` (exceto `ci/debug.keystore`, que é só para artefatos de
  validação) e `key.properties`;
- senhas em texto em qualquer arquivo versionado;
- o conteúdo do keystore em base64 fora dos secrets.

O `.gitignore` do projeto já cobre esses nomes; o contrato
`tests/test_assinatura_release.py` reprova se algum deles aparecer versionado.

## 8. A esteira também publica o Release

Desde o ajuste 092, o mesmo job vai além do artefato: ele copia o APK para
`jarvis-nova-<versão>-arm64.apk`, gera o `sha256sum` desse nome e publica um
Release `android-v<versão>` com os dois arquivos (`gh release create`; se a tag
já existir, `gh release upload --clobber`). É de lá que o app se atualiza pela
tela **Atualizações**: o download só é oferecido depois de o SHA-256 bater.

Por isso a chave deixou de ser só requisito de build: **a atualização por cima
só é aceita pelo Android com a mesma chave do APK instalado**. Trocá-la obriga a
desinstalar antes — e apaga os dados do app.
