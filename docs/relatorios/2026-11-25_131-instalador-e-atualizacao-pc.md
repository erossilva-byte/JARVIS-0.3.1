# 131 — Instalador, atualização assinada e roteiro de PC físico (Etapa 7)

**Data:** 25/11/2026 · **Versão:** 1.108.0+110800 · **Bloco:** 131

## O que a Etapa 7 pedia

- instalador assinado, atualização com verificação de assinatura, versão e
  changelog no app;
- roteiro de teste em PC físico: instalar, parear, ouvir, falar, reiniciar,
  atualizar e desinstalar sem deixar lixo;
- aceite: instalador gerado e instalado em máquina limpa, atualização aplicada e
  revertida, relatório com o que foi medido.

## O ponto de partida, sem enfeite

Antes deste bloco o PC **não tinha** nenhum caminho de atualização: o release
gerava `Setup.exe` e portátil, o workflow avisava em letras claras que o
executável **não era assinado digitalmente**, e não havia como o app conferir um
pacote. Também não existia identificação de "versão instalada" nem notas da
versão dentro do app.

Nenhuma das duas assinaturas do Windows existia: nem o certificado Authenticode
(que precisa ser comprado), nem uma assinatura de atualização verificável pelo
app. A segunda é a que este bloco resolve.

## O que foi entregue

### `atualizacao_pc.js` — regras da atualização

- **Assinatura Ed25519** sobre o JSON canônico do manifesto (chaves em ordem,
  sem espaços): mudar versão, arquivo, tamanho, SHA-256, canal ou notas
  invalida a assinatura;
- **hash e tamanho do arquivo** conferidos contra o manifesto — assinatura
  válida de outro arquivo não passa;
- **sem rebaixamento**: versão igual ou mais antiga é recusada, e existe versão
  mínima para saltos grandes;
- **falha fecha**: sem criptografia, sem chave pública, sem assinatura ou sem
  hash calculado, o resultado é recusa com motivo;
- **plano de aplicação e reversão** em passos escritos, com o instalador
  anterior guardado pelo usuário;
- **notas da versão** extraídas do `CHANGELOG.md` do próprio pacote.

### Ferramentas de release (não vão no app)

- `tools/chave_atualizacao.js` gera o par Ed25519, grava a privada com 0600 e
  **não sobrescreve** chave existente;
- `tools/assinar_atualizacao.js` monta e assina `atualizacao.json` +
  `.sig`, recusa artefato menor que 20 MB (stub do `electron-builder`) e confere
  a assinatura com a própria chave antes de gravar.

### Ligação no app

- `platforms/desktop/main.js`: ações `atualizacao_info`, `atualizacao_verificar`
  (lê a pasta escolhida, a assinatura e o instalador, calcula o SHA-256 e
  decide) e `novidades_app` (lê o CHANGELOG do pacote e devolve o bloco da
  versão instalada).
- **Informações ▸ Sobre e atualização**: versão instalada, se há chave de
  atualização, notas da versão e o botão "Conferir atualização baixada…". No
  celular o bloco diz que a atualização do computador é feita no PC.
- O app **não baixa e não instala** sozinho; ele confere e mostra os passos.

### Documentação

- `docs/ASSINATURA-PC.md`: as duas assinaturas, como ligar o certificado no
  `electron-builder`, o fluxo da chave de atualização, a tabela de recusas e o
  que continua faltando.
- `docs/TESTE-PC-FISICO.md`: o roteiro de campo em sete etapas (instalação,
  pareamento, ouvir/falar, reiniciar, atualização/reversão, desinstalação,
  medições), com o que anotar em cada passo.

### Esteira de release

O `release-pc.yml` passou a assinar o pacote: lê a chave do segredo
`CHAVE_ATUALIZACAO_PRIVADA`, grava em `$RUNNER_TEMP` com permissão 0600, assina o
manifesto com as notas tiradas do `CHANGELOG`, confere o resultado com a chave
pública embutida no app e só então anexa `atualizacao.json` e `.sig` ao release,
ao lado do instalador e do portátil. Numa tag sem o segredo, o release para com
mensagem clara; a chave temporária é apagada do runner com `if: always()`.

Os comandos do passo foram executados aqui, fora do Actions, com a chave de
desenvolvimento: assinatura gerada, conferência aprovada com a chave embutida,
conferência recusada com chave estranha e pacote alterado recusado. **O workflow
em si não rodou** — não há Windows nem runner do GitHub neste ambiente.

## Verificação executada

Assinatura e verificação de verdade, com um pacote sintético de 21.000.000 de
bytes (zeros) e a chave de desenvolvimento embutida no app:

| Caso | Resultado |
|---|---|
| pacote assinado, hash e tamanho batendo | **aceito**: "assinatura e hash conferem" |
| SHA-256 trocado (um byte diferente) | recusado: *"o pacote está corrompido ou foi trocado"* |
| mesma versão instalada | recusado: *"nada a fazer"* |
| chave pública de outra pessoa | recusado: *"não é oficial"* |

SHA-256 do arquivo de demonstração: `861d40305a831d2fc3adc1efbe1abe27a8e72bdaa4b88ae9d96d7275d9d8421e`.
Digital da chave pública embutida: `21d3ab0265453838422735feb7e368cd…`.

`node tests/test_atualizacao_pc.js` cobre 60 verificações: JSON canônico,
comparação de versões (inclusive `1.108.0-beta` não sendo maior), manifesto
inválido campo a campo, assinatura determinística, troca de chave, manifesto
alterado, hash e tamanho divergentes, rebaixamento, versão mínima, canal, plano
de reversão, notas do CHANGELOG e a ferramenta de ponta a ponta (gera chaves,
assina, verifica, recusa chave existente). A suíte inteira (Node e Python)
rodou antes do commit.

## O que **não** foi feito — e isso é o essencial desta etapa

- **Nenhum instalador foi gerado.** Este ambiente não tem Windows nem
  `electron-builder`; os 21 MB do teste são sintéticos, não um NSIS compilado.
- **Nenhum certificado de código foi comprado.** O `.exe` continua sem
  assinatura Authenticode e o SmartScreen continua avisando. As três opções
  (Azure Trusted Signing, EV, OV) estão documentadas, com o bloco de
  configuração — falta a compra e a chave.
- **A máquina limpa não foi usada.** Não houve instalação, atualização real nem
  reversão: isso é o roteiro de `docs/TESTE-PC-FISICO.md`, para quem tiver o
  hardware.
- **A chave de atualização é de desenvolvimento**, gerada neste ambiente:
  privada em `.chaves-dev/` (ignorada pelo Git), pública no repositório. Antes
  de distribuir, gere outra e publique a nova pública numa versão.
- **O app não se atualiza sozinho** — por decisão: baixar e executar instalador
  sem o usuário escolher é o tipo de conveniência que não combina com o resto do
  projeto. O fluxo é: baixar do release, conferir no app, rodar o instalador.
- **Revertemos nada na prática**: o plano de reversão é roteiro, não botão.
- **Duas trilhas de versão**: na entrega deste bloco o pacote Windows ainda se
  identificava como 1.46.0. Isso foi unificado logo depois: `package.json`,
  `VERSAO.json` e `VERSAO_APP` estão em 1.108.0, versionCode 110800, e o teste
  de versão passou a ler o metadado em vez de fixar o número antigo.

Com isso a Etapa 7 fica **implementada e não aprovada**: as regras e o caminho
de conferência estão prontos e testados; a aprovação depende de Windows, de
certificado e da execução do roteiro de campo.
