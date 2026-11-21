# Ajuste 091 — assinatura de release permanente

Data: 2026-11-21 · Versão: 1.77.0+17700 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido

Guiar a geração de uma chave de release permanente para o JARVIS, fora do
repositório, e configurar o build para assinar o APK com ela via `key.properties`
local.

## 2. O que estava errado

- O `build.gradle.kts` do runner Flutter dizia “Signing with the debug keys for
  now”. O APK saía assinado com a chave de debug da máquina que compilou.
- Chave de debug é gerada por máquina: comparando os certificados, o APK do
  ajuste 090 tinha `36B0:75A6…` e o keystore que o repositório usa no CI
  (`ci/debug.keystore`) tem `04E0:4712…`. Duas assinaturas diferentes.
- Resultado prático: o Android recusa instalar uma versão por cima de outra com
  assinatura diferente (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Sem chave fixa,
  **nenhuma atualização** — nem manual, nem OTA — instala preservando dados.

## 3. O que foi feito

### Build lendo key.properties

- **`tool/prepare_android_sistema.py`** passou a aplicar, de forma idempotente, o
  bloco de assinatura no `build.gradle.kts` (que nasce do `flutter create` e não
  entra no controle de versão).
- O build procura o arquivo nesta ordem: **`JARVIS_KEY_PROPERTIES`** (caminho
  completo), **`flutter_app/android/key.properties`**, **`~/.jarvis/key.properties`**.
  As propriedades `-PstoreFile/-PstorePassword/-PkeyAlias/-PkeyPassword` completam
  o que faltar, para o CI reaproveitar os secrets `JARVIS_KEYSTORE_*` que o build
  antigo já usa.
- **`signingConfigs.create("release")`** usa o keystore do projeto;
  `buildTypes.release` assina com ele. Sem chave, o build de release **para** com
  uma mensagem que diz o que criar e onde ler o guia. A saída de emergência é
  explícita: `JARVIS_PERMITIR_DEBUG=true`, que assina em debug e não distribui.
- Nada de segredo no repositório: `.gitignore` passou a recusar `key.properties`,
  `*.jks` e `*.keystore` (mantendo só a exceção histórica `ci/debug.keystore`).

### Guia e conferência

- **`docs/GUIA-ASSINATURA-RELEASE.md`**: gerar com `keytool` (RSA 4096, validade
  ~27 anos, alias), onde guardar e como fazer backup, criar o `key.properties`,
  compilar, conferir, a desinstalação única obrigatória por causa dos APKs
  antigos, e os quatro secrets do CI.
- **`tool/verificar_assinatura.py`**: lê o certificado e o SHA-256 do APK com
  `apksigner`, compara com `certificadoSha256` do key.properties e reprova
  (`--exigir-release`) APK assinado em debug.
- **`flutter_app/key.properties.example`**: modelo com os campos obrigatórios e
  sem senha real.

### Esteira do GitHub Actions

O APK que se distribui passou a ter esteira própria:
`.github/workflows/flutter-release-apk.yml`, disparada à mão, que compila
`flutter build apk --release --target-platform android-arm64` e assina com a
chave do projeto. A chave entra por quatro secrets (`JARVIS_KEYSTORE_B64`,
`JARVIS_KEYSTORE_PASSWORD`, `JARVIS_KEY_ALIAS`, `JARVIS_KEY_PASSWORD`),

decodificada para `$RUNNER_TEMP/jarvis-release.jks`, conferida com `keytool -list`
(alias e senha) e exposta ao build por um `key.properties` temporário apontado em
`JARVIS_KEY_PROPERTIES`, com `storeFile` absoluto. Faltando qualquer secret, o job
para antes de compilar: nada de cair na chave de debug.

O passo de identidade Android (`com.jarvis.nova`, rótulo, `MainActivity`) saiu do
corpo do workflow de validação e virou `flutter_app/tool/prepare_android_identidade.py`,
usado pelas duas esteiras — antes o mesmo script Python estava embutido no YAML e
corria o risco de divergir. Depois do build, o mesmo verificador do bloco
(`tool/verificar_assinatura.py --exigir-release`) reprova assinatura de debug, e o
SHA-256 é publicado junto do APK no artefato da execução.

## 4. Evidência

- **Build sem chave reprova**, como projetado:
  `flutter build apk --release` → código 1 com “APK de release sem chave de
  assinatura. Crie key.properties…”.
- **Build com chave assina de verdade**: gerei um keystore **descartável** em
  `/tmp` (fora do repositório) e um `key.properties` temporário, e o
  `apksigner verify --print-certs` mostrou
  `CN=JARVIS Release Test, O=Jarvis, C=BR` — ou seja, não é mais a chave de
  debug. O APK desse teste foi descartado.
- `python3 tool/verificar_assinatura.py …` mostra certificado e SHA-256 e avisa
  quando a assinatura é de debug.
- Contrato novo `tests/test_assinatura_release.py` em `npm run test:all`:
  exige o bloco de assinatura no preparo do Android, a ordem de procura do
  `key.properties`, a recusa de debug, o guia, o modelo sem segredo, o
  `.gitignore` e a ausência de keystore versionado fora da exceção do CI.
- `flutter analyze` limpo e suíte do app passando (mudança só de build/doc, os
  226 testes seguem verdes).

## 5. Arquivos

- `flutter_app/tool/prepare_android_sistema.py`: bloco de assinatura idempotente.
- `flutter_app/tool/verificar_assinatura.py` (novo).
- `flutter_app/key.properties.example` (novo).
- `docs/GUIA-ASSINATURA-RELEASE.md` (novo).
- `.gitignore`, `package.json`, `CHANGELOG.md`, `docs/INVENTARIO_DE_FUNCOES.md`.
- `tests/test_assinatura_release.py` (novo).
- `.github/workflows/flutter-release-apk.yml` (novo): esteira do APK assinado.
- `flutter_app/tool/prepare_android_identidade.py` (novo) e
  `.github/workflows/flutter-native.yml`: identidade Android compartilhada.

## 6. Não verificado

- **A chave real é sua**: não existe APK de release assinado com ela nesta
  sessão, e não deve existir — a chave não passa por aqui. O primeiro APK
  assinado de verdade só pode sair da sua máquina (ou do CI com os secrets).
- **A instalação por cima não foi testada em aparelho**: a regra de assinatura é
  do Android, mas a atualização real (com os dados preservados) depende de um
  aparelho.
- **A desinstalação única é inevitável** para quem já tem os APKs antigos: a
  assinatura muda, e o Android não tem como migrar isso. Faça a sincronização do
  cofre/memória antes.
- Se o `key.properties` ficar em `flutter_app/android/`, ele está fora do
  controle de versão por dois motivos (o `.gitignore` e a pasta `android/`
  gerada); ainda assim, a recomendação é mantê-lo em `~/.jarvis/`.
- **A esteira não rodou no GitHub**: ela só executa com os secrets cadastrados e
  um disparo manual (ou push autorizado), o que não aconteceu nesta sessão. O que
  foi verificado aqui é o YAML e o contrato `tests/test_assinatura_release.py`
  (secrets exigidos, base64, `RUNNER_TEMP`, `--exigir-release`, artefato) — não a
  execução real.
- Nada foi commitado nem enviado.
