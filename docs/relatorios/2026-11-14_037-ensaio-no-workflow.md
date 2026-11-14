# Ajuste 037 — ensaio do patch dentro do GitHub Actions (2026-11-14)

## Por que

O ensaio do patch (ajuste 036) só rodava na máquina de desenvolvimento. No GitHub, o
workflow compila o que está no repositório; quando o código chega como patch — o caminho
usado porque a integração recusa arquivos grandes — nada garantia que o patch aplicava antes
de a compilação começar.

## O que mudou

### 1. Modo `--aplicar` no ensaio

`ci/rehearsal_gate_a.py` ganhou o modo usado pelo CI:

- confere o patch com `git apply --check`;
- aplica no checkout;
- roda `ci/preflight_android.py` no código resultante e reprova se a pré-checagem reprovar.

O modo local (sem `--aplicar`) continua igual: exporta o `HEAD`, aplica numa cópia e compara
byte a byte com a árvore de trabalho.

### 2. Passo em todos os workflows que compilam

Novo passo "Ensaio do patch antes da compilação", colocado antes de qualquer uso do código:

| Workflow | Onde entra | Por quê |
|---|---|---|
| `build-apk.yml` | depois de extrair o `.zip` de fontes | o patch entra por cima do que veio no zip |
| `ci.yml` — `regressao` | antes de validar pacote | a suíte precisa rodar no código patcheado |
| `ci.yml` — `android-build` | antes de montar `www` | o APK precisa sair do código patcheado |
| `release-apk.yml` | antes de instalar dependências | release assinada não pode sair de código diferente |

O passo procura `*.patch` na raiz do repositório e usa o último em ordem alfabética, o mesmo
critério do `.zip` de fontes que o projeto já usa. Se não houver patch, escreve
`Nenhum patch na raiz: compilando o código do repositório.` e segue — o fluxo normal não muda.

`build-apk.yml` também passou a disparar quando um `.patch` é enviado para a raiz
(`paths: '*.patch'`).

`ci-android-auditoria.yml` ficou de fora de propósito: ele compila o APK de auditoria da
linha de base (1.45.0), não o código em desenvolvimento; aplicar o patch ali mudaria o que a
auditoria compara.

## Verificação

- YAML dos quatro workflows conferido com `python3 -c "import yaml; ..."` (sintaxe válida).
- Teste do modo `--aplicar` num checkout limpo do `HEAD`, com o código já patcheado:
  patch válido → exit 0 e mensagem `Gate A (CI): patch aplicado no checkout ... pré-checagem
  aprovada`.
- Teste negativo: patch que cita arquivo inexistente → exit 1 com
  `o patch não aplica no checkout`.
- `npm run verificar` e o ensaio local continuam exit 0 (ver relatório 036 e execução final).

## Limites

O passo usa o Python do runner, que já é configurado antes dele em todos os workflows. O
ensaio não compila: ele só garante que o patch aplica e que a pré-checagem estática passa. A
compilação de verdade continua sendo o critério do Gate A. Se um patch for gerado contra um
commit diferente do que está no repositório, o passo reprova com o erro do `git apply` — é o
comportamento desejado, mas significa que o patch precisa ser regenerado depois de cada
commit que toque os mesmos arquivos.
