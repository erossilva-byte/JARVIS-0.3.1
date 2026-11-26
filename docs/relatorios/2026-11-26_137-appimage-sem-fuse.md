# AppImage que abre sem instalar nada (runtime estático)

Data: 2026-11-26 · Bloco 137 · Versão do app: 1.111.0 (sem bump)

## O pedido

"Prefiro continuar usando o AppImage. Quero que ele abra sem eu precisar
instalar nada no sistema, nem o libfuse2."

O bloco 136 tinha resolvido o Linux publicando um `tar.gz`, que roda sem FUSE.
Só que isso empurrava a pessoa para outro formato: o AppImage continuava morrendo
com `dlopen(): error loading libfuse.so.2`.

## O que descobri testando o Arquivo de verdade

O AppImage publicado nesta versão foi baixado de novo e aberto neste ambiente
(Ubuntu 24.04, sem `libfuse2`):

```
$ ./JARVIS-Nova-1.111.0-x86_64.AppImage --version
dlopen(): error loading libfuse.so.2
AppImages require FUSE to run.
```

O erro vem do **runtime** do AppImage (os primeiros ~188 kB do arquivo), não do
app: o runtime antigo que o electron-builder 25 embute carrega `libfuse.so.2` do
sistema para montar o squashfs. Nenhuma linha do Jarvis chega a rodar — por isso
a correção de GPU do bloco 135 não tinha como ajudar.

## A correção

O projeto AppImage publica um runtime com `libfuse` e `squashfuse` ligados
**estaticamente** dentro do próprio binário: o FUSE vai junto com o arquivo e o
sistema não precisa ter nada. Foi o que fiz:

- `ci/appimage_sem_fuse.py` (novo) pega o AppImage gerado pelo electron-builder,
  mede onde o squashfs começa (`--appimage-offset`), e reescreve o arquivo como
  `runtime estático + mesmo squashfs`, byte a byte. Depois confere: o offset tem
  de ser o do runtime novo, e `AppRun` e `resources/app.asar` têm de sair do
  arquivo pelo `--appimage-extract`.
- O runtime é fixado por versão e **sha256**
  (`runtime-x86_64`, release `20251108` do `AppImage/type2-runtime`,
  `2fca8b44…260d`, 944 632 bytes) e fica em cache; `--runtime CAMINHO` usa um
  arquivo já baixado, sem rede.
- `npm run dist:linux` passou a rodar o script depois do electron-builder e
  `release-pc.yml` ganhou a etapa "Trocar o runtime do AppImage pelo estático",
  antes da conferência de tamanho e do anexo ao release.
- `platforms/LINUX.md`: o AppImage volta a ser o caminho mais curto (um arquivo,
  sem `sudo`, sem instalar biblioteca); a tabela de erros separa "arquivo antigo"
  (o `libfuse.so.2`) de "sem `fusermount3`" (`--appimage-extract-and-run`).
- `tests/test_pc_linux.py` passou a exigir o script, o sha256 fixado, a etapa na
  esteira e as frases novas da documentação.

## Medições neste ambiente

| Passo | Resultado |
|-------|-----------|
| Runtime estático baixado e conferido | 944 632 bytes, sha256 bate |
| AppImage reembalado com o runtime novo | offset 944 632 (antes 188 392) |
| `--appimage-extract` do pacote reembalado | `AppRun` (2 352 B) e `app.asar` saem íntegros |
| Abrir o pacote reembalado | **não** aparece mais `dlopen(): error loading libfuse.so.2`; o runtime chega a tentar a montagem e para em `mount failed: Operation not permitted` |

O último item é limite do container, não do pacote: aqui não existe permissão de
montagem (nem `/dev/fuse` utilizável por namespace), e ele usa o `fusermount3`
que já vem no `fuse3` de qualquer desktop. Em área de trabalho Linux real a
montagem é o caminho normal. **A janela do app não foi aberta**: este ambiente
não tem servidor gráfico nem `libnss3`/`libgtk-3`.

## Alternativas que continuam valendo

- `tar.gz` e `.deb` seguem publicados no mesmo release.
- Onde nem `fusermount3` existir, `APPIMAGE_EXTRACT_AND_RUN=1 ./JARVIS-Nova-…AppImage`
  extrai para um temporário e roda.

## O que não mudou

- Versão continua 1.111.0: os ~50 contratos que fixam `1.111.0+111100` seguem
  válidos e o AppImage do mesmo release foi substituído (`--clobber`).
- O conteúdo do app no squashfs é o mesmo; só o runtime embutido mudou.
- Windows continua bloqueado pela falta do segredo `CHAVE_ATUALIZACAO_PRIVADA`.
