# 1.111.0 — Linux: o AppImage não abria por falta de FUSE

## O que falhou no uso real

O `.AppImage` publicado em `v1.111.0` não abre em Ubuntu 22.04 ou mais novo. O
erro não vem do app: o próprio runtime do AppImage morre antes de executar
qualquer linha do J.A.R.V.I.S.:

```
dlopen(): error loading libfuse.so.2

AppImages require FUSE to run.
You might still be able to extract the contents of this AppImage
if you run it with the --appimage-extract option.
```

O Ubuntu deixou de instalar o `libfuse2` por padrão a partir do 22.04 (o 24.04
usa o pacote `libfuse2t64`). Quem baixa o AppImage e dá dois cliques vê só essa
mensagem, e a correção anterior (GPU desligada, que resolveu o `libva error`)
não tem como ajudar: o processo do app nunca começa.

## Reprodução

```
$ ./JARVIS-Nova-1.111.0-x86_64.AppImage --version
dlopen(): error loading libfuse.so.2
AppImages require FUSE to run.
EXIT=1
```

O mesmo arquivo, extraído com `--appimage-extract`, chega ao binário
`squashfs-root/jarvis-nova` — prova de que o conteúdo está íntegro e só a
camada de montagem por FUSE está faltando.

## O que mudou

- `build.linux.target` agora tem três alvos: `AppImage`, `deb` e `tar.gz`.
  O `tar.gz` (`JARVIS-Nova-<versão>-<arch>.tar.gz`) extrai para uma pasta e roda
  com `./jarvis-nova`, sem FUSE, sem `sudo` e sem instalar nada no sistema.
- `release-pc.yml` empacota os três, exige mais de 20 MB em cada um (para não
  publicar stub) e confere por dentro do tar que existem `jarvis-nova` e
  `resources/app.asar`; os três vão para o artefato e para o release da tag.
- `platforms/LINUX.md` ganhou a tabela **Erros conhecidos ao abrir**, com a
  causa e a saída de cada um: `libfuse.so.2` (usar o `tar.gz`, instalar
  `libfuse2t64`/`libfuse2` ou rodar com `APPIMAGE_EXTRACT_AND_RUN=1`), sandbox
  do Chromium (`JARVIS_SEM_SANDBOX=1`), `libva error` (já é o padrão sem GPU) e
  `Permission denied` (`chmod +x`).
- `LEIA-ME.md` e `CHANGELOG.md` dizem quais pacotes existem e como sair do erro.

## Correção encontrada no caminho

`platforms/desktop/main.js` declarava **duas** funções `cofreDoPC`: a primeira
para o cofre de chaves (PIN e chaves de API, via `safeStorage`) e a segunda para
o cofre de memória em pasta. Em JavaScript a segunda declaração sobrescreve a
primeira, então `guardar_chave_segura` chamava o cofre de memória e estourava
`guardar is not a function` — ou seja, salvar chave de API no app do PC falhava
em Windows e Linux. A do cofre de memória virou `cofreMemoriaDoPC`, e
`tests/test_pc_linux.py` passou a exigir uma única `function cofreDoPC(`.

## Verificação

- `python3 tests/test_pc_linux.py` — contrato atualizado (três alvos, esteira,
  documentação de FUSE e o nome único dos cofres).
- `node --check platforms/desktop/main.js`.
- `npx electron-builder --linux AppImage deb tar.gz` local, com conferência do
  conteúdo do `tar.gz`.

## O que não foi testado aqui

Esta máquina é Ubuntu 24.04 sem `sudo`, sem `libfuse2`, sem `libnss3` e sem
servidor gráfico: o AppImage não pode ser montado nem a janela pode ser aberta
aqui. O que foi medido é a falha de FUSE (acima), o conteúdo dos pacotes e as
regras da esteira. Abrir o app numa área de trabalho Linux de verdade continua
pendente, agora nos três formatos.
