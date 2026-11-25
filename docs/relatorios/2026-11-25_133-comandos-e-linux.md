# Bloco 133 — comandos novos e app do PC no Linux

## O que foi entregue

### Duas ações novas no canal PC → celular

- `abrir_conversa` — abre a conversa por voz no celular, pelo mesmo `AbrirTela`
  que a voz usa.
- `iniciar_escuta` — chama o controlador da palavra de ativação e só responde
  “ok” quando o detector confirma que está escutando; erro do detector volta
  como motivo, não como sucesso vazio.

As duas não levam argumento: `argumentos` com qualquer campo é recusado com 422
(`${'não leva argumento'}`). Token, protocolo, prazo de 60 s, `id` de uso único,
lista fechada e teto de 20 por minuto continuam valendo.

### App do PC no Linux

- `build.linux` com AppImage e `.deb`, `executableName`, nome de artefato com
  versão e arquitetura, mantenedor e entradas de menu.
- Job próprio `linux` na esteira `release-pc.yml`: `ubuntu-latest`, `npm ci`,
  `electron-builder --linux AppImage deb`, conferência de 20 MB por artefato,
  upload como `jarvis-nova-linux` e anexo ao release quando a execução é por tag.
- Mídia e volume deixaram de ser exclusividade do Windows: `playerctl` para
  tocar/pausar/avançar, `pactl` ou `wpctl` para volume e mudo; sem a ferramenta o
  app recusa dizendo qual pacote instalar.
- `platforms/LINUX.md`: instalação, dependências por recurso, o que muda em
  relação ao Windows e limites.

## Testes (o que rodou de verdade)

- `flutter_app/tool/comando_remoto_test.dart`: catálogo novo, recusa de argumento
  em ação sem argumento, e o serviço real recebendo `abrir_conversa` e
  `iniciar_escuta` em 127.0.0.1. Verde com o SDK do Flutter desta máquina.
- `tests/test_comando_remoto.js`: cliente do PC contra celular falso; as duas
  ações novas executam, chegam sem argumento e argumento sobrando é recusado
  antes de qualquer rede. Verde.
- `tests/test_bloco_132.py`: compara a lista de ações do Dart com a do JS (agora
  três) e cobra as duas na documentação. Verde.
- `tests/test_pc_linux.py`: alvos de pacote, mantenedor com e-mail, job da
  esteira, alternativas de mídia/volume e os limites da documentação. Verde.
- **Pacote Linux gerado aqui**: `electron-builder --linux AppImage deb` saiu com
  código 0 — `JARVIS-Nova-1.110.0-x86_64.AppImage` (105 MB) e
  `JARVIS-Nova-1.110.0-amd64.deb` (72 MB).

## Limites declarados

- **O app não foi aberto no Linux.** Este ambiente não tem `libnss3` nem área de
  trabalho: o executável descompactado para no carregamento das bibliotecas do
  Chromium. O que está provado é que o empacotamento fecha e produz artefatos do
  tamanho esperado — não que a janela abre, o áudio toca ou o keyring responde.
- **Nada foi executado em aparelho Android nem em PC Windows.**
- `iniciar_escuta` depende do detector do Android (sherpa-onnx) estar saudável
  naquele aparelho; sem ele o comando falha e o PC recebe o motivo.
- O `.deb` usa `jarvis@exemplo.local` como mantenedor: trocar antes de
  distribuir.
