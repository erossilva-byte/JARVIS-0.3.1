# J.A.R.V.I.S. Nova no Linux

O app do PC é Electron e roda no Linux com o mesmo código do Windows: arquivos,
CAD, projetista, memória em Markdown, fichas, voz, pareamento com o celular e
atualização assinada. Este documento diz como instalar, o que depende de pacote
do sistema e o que ainda não foi medido.

## Instalar

Duas formas, as duas geradas pela esteira `release-pc.yml`:

- **AppImage** — `chmod +x JARVIS-Nova-1.110.0-x86_64.AppImage` e execute.
  Não instala nada no sistema.
- **deb** (Debian/Ubuntu) — `sudo apt install ./JARVIS-Nova-1.110.0-amd64.deb`.

Para compilar na própria máquina:

```bash
npm ci
npm run dist:linux        # AppImage + deb em dist/
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
- **Instalador**: `.AppImage`/`.deb` em vez de NSIS/portátil. A atualização
  assinada (`atualizacao.json`) é do pacote Windows; no Linux a troca é manual
  (baixar o AppImage novo por cima).
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
