# Assinatura do pacote do PC

O instalador do Windows tem **duas assinaturas diferentes**, e as duas importam:

| Assinatura | Quem confere | O que prova | Situação hoje |
|---|---|---|---|
| Certificado de código (Authenticode) no `.exe` | Windows / SmartScreen | que o executável veio de quem diz (e reduz o aviso azul) | **não existe**: o release sai sem certificado |
| Assinatura Ed25519 do manifesto de atualização | o próprio JARVIS | que o pacote de atualização é oficial e não foi alterado | implementada e testada |

Este documento explica as duas e o que falta em cada uma.

## 1. Certificado de código do instalador

Sem certificado, o Windows mostra o aviso do SmartScreen ("aplicativo não
reconhecido") e o usuário precisa clicar em "Mais informações → Executar assim
mesmo". O release atual avisa isso na descrição — não esconde.

Caminhos possíveis, em ordem de custo:

1. **Azure Trusted Signing** (~US$ 10/mês): assinatura na nuvem, chave nunca sai
   do serviço, funciona no GitHub Actions com um service principal.
2. **Certificado EV em token/HSM** (~US$ 300–500/ano): reputação imediata no
   SmartScreen, mas exige hardware ou serviço de assinatura remota.
3. **Certificado OV em arquivo `.pfx`**: o mais barato, porém a chave privada
   fica em arquivo — precisa de cofre e senha em segredo do CI.

Para ligar no `electron-builder` (quando houver um dos três), o bloco no
`package.json` é:

```jsonc
"win": {
  "signAndEditExecutable": true,
  "signtoolOptions": {
    "certificateFile": "C:\\caminho\\certificado.pfx",  // ou publisherName no caso do Trusted Signing
    "certificatePassword": "${env.CSC_KEY_PASSWORD}"
  }
}
```

No GitHub Actions, os segredos vão em `CSC_LINK` (base64 do `.pfx`) e
`CSC_KEY_PASSWORD`; o workflow hoje define `CSC_IDENTITY_AUTO_DISCOVERY=false`
justamente para não tentar assinar sem certificado. Enquanto não houver
certificado, **não** mude isso: um build "meio assinado" é pior que um build
declaradamente sem assinatura.

## 2. Chave de atualização (Ed25519)

Esta é a assinatura que o app confere sozinho, e é ela que a Etapa 7 pede.

- **Chave privada**: fica fora do repositório e do app. Neste ambiente de
  trabalho ela foi gerada em `.chaves-dev/` (ignorado pelo Git). Guarde-a em
  cofre/pendrive; se perder, é preciso gerar outra e publicar uma versão com a
  nova chave pública.
- **Chave pública**: embutida em `platforms/desktop/atualizacao-publica.pem`.
  Digital atual: `21d3ab0265453838422735feb7e368cd…`.
- **Manifesto assinado** (`atualizacao.json`) cobre: aplicativo, canal, versão,
  nome do arquivo, tamanho, SHA-256, data, versão mínima e notas. A assinatura é
  sobre o JSON canônico (chaves em ordem, sem espaços).

Gerar um par novo (quando a chave atual for comprometida):

```bash
node tools/chave_atualizacao.js ~/chaves-jarvis
cp ~/chaves-jarvis/atualizacao-publica.pem platforms/desktop/atualizacao-publica.pem
```

Assinar um pacote já gerado pelo `electron-builder`:

```bash
node tools/assinar_atualizacao.js \
  --pasta dist \
  --chave ~/chaves-jarvis/atualizacao-privada.pem \
  --versao 1.108.0 \
  --canal estavel \
  --notas notas-da-versao.txt
```

Saída: `dist/atualizacao.json` e `dist/atualizacao.json.sig`. Publique os dois
junto com o `.exe` no release.

A ferramenta **recusa** assinar artefato menor que 20 MB (o stub que o
`electron-builder` deixa quando falha no meio) e confere a assinatura com a
própria chave antes de gravar — assinar errado e descobrir só na hora de
atualizar seria pior.

### Esteira de release (GitHub Actions)

O workflow `release-pc.yml` assina o pacote sozinho, sem chave no repositório:

1. **`Conferir a versão da tag e a chave de assinatura`** (só em tag): exige que
   `vX.Y.Z` seja igual à versão do `package.json` e que o segredo exista. Sem
   segredo, o release **para** com a mensagem
   `Falta o segredo CHAVE_ATUALIZACAO_PRIVADA`.
2. **`Assinar o manifesto de atualização`**: escreve a chave em
   `$RUNNER_TEMP` com `umask 077` e `chmod 600`, gera as notas a partir do
   `CHANGELOG.md`, roda `tools/assinar_atualizacao.js` e grava
   `dist/atualizacao.json` + `dist/atualizacao.json.sig`.
3. **`Conferir a assinatura com a chave pública do app`**: roda
   `tools/conferir_atualizacao.js dist` — verifica com a chave **embutida no
   app**, não com a que acabou de assinar. Se as duas não forem o mesmo par, o
   release para antes de publicar.
4. **`Apagar a chave privada do disco do runner`** (`if: always()`): apaga o
   arquivo temporário e as notas mesmo se alguma etapa falhar.

Depois disso, `atualizacao.json` e `atualizacao.json.sig` entram nos artefatos do
build e são anexados ao release junto do `Setup.exe`, do portátil e dos
`.sha256`.

Para configurar: **Settings ▸ Secrets and variables ▸ Actions ▸ New repository
secret**, nome `CHAVE_ATUALIZACAO_PRIVADA`, valor = conteúdo inteiro do arquivo
`atualizacao-privada.pem` (incluindo as linhas `BEGIN/END`). O GitHub mascara o
valor nos logs; a esteira nunca imprime a chave.

Se a chave for rotacionada, publique primeiro uma versão com a **nova chave
pública** no repositório; releases antigos assinados com a chave velha passam a
ser recusados, e é isso que se quer.

### O que o app faz com isso

O botão **Ajustes ▸ Informações ▸ Conferir atualização baixada…** abre a pasta
escolhida, lê o manifesto, a assinatura e o instalador, e só então decide. Ele
**não baixa nada** e **não instala nada**: devolve o texto do que conferiu e os
passos de aplicação e de reversão.

Recusas possíveis, com o motivo na tela:

| Motivo | Quando |
|---|---|
| `sem-chave` | a chave pública não está no pacote |
| `sem-assinatura` | o `.sig` não veio |
| `assinatura-invalida` | manifesto alterado ou chave de outra pessoa |
| `hash` | o instalador não é o que o manifesto descreve |
| `tamanho` | o arquivo foi truncado ou trocado |
| `mesma-versao` | o pacote é o que já está instalado |
| `mais-antiga` | tentativa de rebaixar |
| `versao-minima` | salto grande que exige uma intermediária |

### Versão do pacote Windows × versão do app

Até a 1.107.0 o pacote do PC se identificava como 1.46.0 enquanto o Flutter já
estava em 1.108.0. Isso foi unificado: `package.json`, `VERSAO.json` e a
constante `VERSAO_APP` no `app.js` declaram **1.108.0**, com `versionCode`
**110800**, igual ao `pubspec.yaml` (`1.108.0+110800`). O painel Sobre mostra essa
versão e as notas dela.

A regra que fica: **subir a versão do app é subir os quatro juntos** —
`pubspec.yaml`, `package.json`, `VERSAO.json` (version e versionCode) e
`VERSAO_APP`. O contrato de versão (`tests/test_v1_46_0.py`) lê o `VERSAO.json`
e falha se algum ficar para trás.

## 3. O que continua faltando (declarado)

- Nenhum certificado de código foi comprado: o `.exe` continua sem assinatura
  Authenticode, e o aviso do SmartScreen continua aparecendo.
- Nenhum instalador foi gerado neste ambiente (não há Windows nem
  `electron-builder` instalado). O que foi provado é a verificação: um pacote
  sintético de 21 MB, assinado com a chave de desenvolvimento, passa; com um
  byte diferente, é recusado.
- A reversão de atualização é um roteiro manual, não automática: o desinstalador
  do NSIS não tem retorno confiável por linha de comando em toda versão do
  Windows, e apagar a pasta de dados do usuário sem aviso seria pior.
