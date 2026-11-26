# J.A.R.V.I.S. Nova no Linux

O app do PC é Electron e roda no Linux com o mesmo código do Windows: arquivos,
CAD, projetista, memória em Markdown, fichas, voz, pareamento com o celular e
atualização assinada. Este documento diz como instalar, o que depende de pacote
do sistema e o que ainda não foi medido.

## Instalar

Três formas, todas geradas pela esteira `release-pc.yml`. Escolha a que o seu
sistema aceita:

- **tar.gz** (funciona em qualquer distro, sem instalar nada no sistema):
  ```bash
  tar -xzf JARVIS-Nova-1.111.0-x64.tar.gz
  cd JARVIS-Nova-1.111.0-x64 && ./jarvis-nova
  ```
- **deb** (Debian/Ubuntu) — `sudo apt install ./JARVIS-Nova-1.111.0-amd64.deb`.
- **AppImage** (um arquivo só, sem `sudo` e sem instalar biblioteca) —
  `chmod +x JARVIS-Nova-1.111.0-x86_64.AppImage` e execute (duplo clique também
  abre, depois do `chmod +x`).

O AppImage publicado traz um **runtime estático**: o FUSE de que ele precisa para
montar o próprio conteúdo vai embutido no arquivo, então o `libfuse.so.2` do
sistema deixou de ser obrigatório. A montagem usa o `fusermount3` que já vem no
`fuse3` das instalações de desktop; onde nem ele existir, o mesmo arquivo abre
com `APPIMAGE_EXTRACT_AND_RUN=1` (extrai para um temporário e roda). O `tar.gz`
continua publicado para quem prefere uma pasta a um único arquivo.

### Erros conhecidos ao abrir

| Mensagem | Causa | O que fazer |
|----------|-------|-------------|
| `dlopen(): error loading libfuse.so.2` / "AppImages require FUSE to run" | arquivo **antigo**, baixado antes do runtime estático | baixe o AppImage de novo: o pacote atual não carrega `libfuse.so.2`. Para abrir o antigo: `tar.gz`, `sudo apt install libfuse2t64` (Ubuntu 24.04) / `libfuse2` (22.04 e anteriores), ou `APPIMAGE_EXTRACT_AND_RUN=1 ./JARVIS-Nova-1.111.0-x86_64.AppImage` |
| `Cannot mount AppImage` / `mount failed: Operation not permitted` | sistema sem `fusermount3` ou container sem permissão de montagem | `APPIMAGE_EXTRACT_AND_RUN=1 ./JARVIS-Nova-1.111.0-x86_64.AppImage` |
| `The SUID sandbox helper binary was found, but is not configured correctly` | distro com *unprivileged user namespaces* restrito (AppArmor no Ubuntu 24.04) | `JARVIS_SEM_SANDBOX=1 ./jarvis-nova` (o sandbox do Chromium fica desligado; use só se precisar) |
| `libva error: …/iHD_drv_video.so init failed` e a janela não abre | aceleração de GPU com driver Intel antigo | já é o padrão: a GPU vem desligada no Linux; `JARVIS_GPU=1` religa |
| `Permission denied` | o AppImage foi baixado sem permissão de execução | `chmod +x` no arquivo |

Para compilar na própria máquina:

```bash
npm ci
npm run dist:linux        # AppImage (runtime estático) + deb + tar.gz em dist/
npm run dist:linux:dir    # só a pasta descompactada, para testar rápido
```

## O que cada recurso precisa no Linux

| Recurso | Precisa de | Sem isso |
|---------|-----------|----------|
| Tocar/pausar, próxima, anterior | `playerctl` | o app recusa e diz `sudo apt install playerctl` |
| Volume e mudo | `pactl` (pulseaudio-utils) ou `wpctl` (PipeWire) | o app recusa e diz qual instalar |
| Bloquear a tela | `loginctl` (systemd) | erro do sistema aparece na resposta |
| Desligar com 30 s de aviso | `shutdown` (`systemd-logind`) | idem |
| Cofre de chaves (PIN, chaves de API) | `safeStorage` do Electron com um armazenamento do sistema: `gnome-keyring`/`kwallet` | **o cofre recusa gravar** em vez de salvar em texto claro |
| Voz e escuta no PC | microfone pelo WebAudio do Chromium | a tela diz que não achou o microfone |

Em sessão sem keyring (SSH, Wayland minimalista), o Electron pode cair no
armazenamento `basic_text`, que é texto claro. O app detecta isso
(`safeStorage.isEncryptionAvailable()`) e **não grava** segredo nenhum nesse
caso — é o mesmo comportamento do Windows sem DPAPI.

## O que muda em relação ao Windows

- **Sem teclas multimídia**: no Windows o app injeta a tecla; no Linux usa
  `playerctl`, que fala com o player ativo em vez de simular teclado.
- **Instalador**: `.AppImage`/`.deb`/`.tar.gz` em vez de NSIS/portátil. A
  atualização assinada (`atualizacao.json`) é do pacote Windows; no Linux a
  troca é manual (baixar o pacote novo por cima).
- **Certificado de código**: não há assinatura de pacote no Linux; o AppImage
  não pede permissão especial e o `.deb` só avisa quando vem de fora do
  repositório.

## Limites declarados

- **Nada foi executado em uma área de trabalho Linux real** neste ambiente de
  desenvolvimento: o build e os testes são de regra e de empacotamento, sem
  janela, sem áudio e sem keyring de verdade. O roteiro de campo
  (`docs/TESTE-PC-FISICO.md`) continua pendente, agora com uma linha a mais para
  Linux.
- O `.deb` usa o e-mail de exemplo `jarvis@exemplo.local` como maintainer:
  troque antes de distribuir.
- Sem auto-atualização no Linux; sem integração com a bandeja do sistema além do
  que o Electron já faz sozinho.
