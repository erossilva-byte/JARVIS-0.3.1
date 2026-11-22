# Ajuste 092 — atualização OTA conferida pelo SHA-256

Data: 2026-11-21 · Versão: 1.78.0+17800 · Branch: `work/1.77.0-bloco-091`

## 1. Pedido

Seguir com o bloco da atualização OTA: baixar o APK, conferir o SHA-256
publicado pela esteira e abrir o instalador do Android.

## 2. O que faltava

- **O app não tinha como receber atualização.** O módulo “Atualizações” do
  catálogo era só um cartão genérico, sem tela e sem fluxo.
- **O APK publicado só existia como artefato de execução.** Artefato do GitHub
  Actions exige login e expira em 14 dias — o app não consegue alcançá-lo, e
  ninguém baixa uma versão nova sem entrar no GitHub à mão.
- **O `.sha256` existia, mas não era usado por ninguém.** A esteira do ajuste 091
  gera o arquivo; faltava o consumidor que confere o digesto.
- **O APK antigo do Capacitor tinha atualizador em Java**
  (`JarvisUpdatePlugin.java`), mas ele não serve ao Flutter: a interface nativa
  não conversa com plugins do Capacitor.

## 3. O que foi feito

### Ponte Kotlin (`JarvisAtualizacao.kt`, canal `com.jarvis.nova/atualizacao`)

- Lista os releases publicados (`/releases?per_page=10`), ignora rascunhos e
  escolhe o primeiro com um `.apk` anexado — funciona com pré-release e sem
  `/latest`.
- Extrai a versão da tag, compara com a instalada em três números e devolve se há
  atualização, o motivo quando não há, tamanho, notas e as URLs do APK e do
  `.sha256`.
- **Baixar** lê primeiro o `.sha256` publicado, calcula o SHA-256 durante a cópia
  para `files/updates/jarvis-update.apk` e **apaga o arquivo** quando o digesto
  não confere. Sem `.sha256` publicável (nem digesto do GitHub), nada é baixado.
- Limite de sanidade de 400 MB, progresso a cada 5% por `EventChannel`
  (`com.jarvis.nova/atualizacao/eventos`).
- **Instalar** exige `canRequestPackageInstalls()`; sem autorização, abre a tela
  do Android para liberar a origem e explica que basta tocar de novo. O APK sai
  pelo FileProvider `com.jarvis.nova.fileprovider`, que expõe só `files/updates/`.
  Não existe instalação silenciosa: quem instala é o Android, com confirmação.
- Explica HTTP 403/404/401 sem chamar de “problema de conexão”.

### Tela nativa (`atualizacao_page.dart`)

Três cartões: versão instalada (com build e estado da autorização), release
publicado (versão, tamanho, aviso de que a esteira publicou o digesto) e o
download com o SHA-256 calculado; depois “Instalar atualização” e o resultado do
Android. O rodapé diz os limites: mesma assinatura, APK arm64, confirmação
obrigatória. Entra pela gaveta, pelo catálogo e pela busca.

### Preparo do Android (`prepare_android_sistema.py`)

- Copia `JarvisAtualizacao.kt`, registra no `MainActivity` e encerra o worker no
  `onDestroy`.
- Injeta `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />`
  e o `<provider>` do FileProvider com `@xml/jarvis_arquivos`
  (`<files-path path="updates/" />`).
- `verificar()` passa a reprovar o preparo sem o Kotlin, o provider, a permissão
  ou o recurso copiado.

### Esteira (`flutter-release-apk.yml`)

- `contents: write` só para publicar o Release.
- O APK é copiado para `jarvis-nova-<versão>-arm64.apk` e o `sha256sum` roda
  nesse nome, então o `.sha256` publicado aponta para o arquivo certo.
- Etapa nova: `gh release create android-v<versão>` com APK + `.sha256`; se a tag
  já existir, `gh release upload --clobber`. O artefato da execução continua sendo
  publicado para conferência.

## 4. O que muda na distribuição

| Antes | Agora |
|---|---|
| APK só como artefato de execução (login + 14 dias) | Release `android-v<versão>` com APK e `.sha256` |
| Atualização só por download manual no navegador | O app consulta, baixa e confere sozinho |
| Digesto publicado sem consumidor | Divergência apaga o arquivo e não oferece instalar |
| Instalação manual pelo gerenciador de arquivos | Instalador do Android aberto pelo FileProvider |

A chave de assinatura deixa de ser só requisito de build e passa a ser requisito
de distribuição: sem a mesma chave, o Android recusa a atualização por cima.

## 5. Verificação

- `flutter analyze` e `flutter test` no toolchain da sessão.
- `python3 tests/test_atualizacao_ota.py` e os contratos vizinhos
  (`test_sistema_android.py`, `test_assinatura_release.py`,
  `test_workflow_flutter.py`, `test_release_readiness.py`).
- O preparo do Android foi exercitado num runner falso, com manifesto XML válido
  ao final (o contrato monta o runner e roda o script).

## 6. Limites honestos

- **Nada foi compilado nem instalado em aparelho.** Não há Android SDK nem
  aparelho nesta sessão: não houve `flutter build apk`, nem instalação por cima,
  nem `INSTALL_FAILED_UPDATE_INCOMPATIBLE` observado.
- **Nenhum release existe ainda.** O fluxo foi escrito e contratado; a primeira
  atualização real depende de você rodar a esteira (com os quatro secrets) e de
  instalar o APK anterior assinado com a mesma chave.
- **Rate limit do GitHub:** sem autenticação, a consulta pública tem limite por
  IP; a tela mostra HTTP 403 em vez de fingir que está atualizada.
- O APK é arm64: aparelhos 32 bits não recebem esta atualização.
