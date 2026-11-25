# Bloco 124 — roteiro do PC e status unificado

**Versão:** 1.101.0+110100
**Data:** 25 de novembro de 2026

## O que existe hoje no PC

- App Electron completo em `platforms/desktop/main.js` (648 linhas), `index.html`
  (1543 linhas) e os módulos JS da raiz. Versão 1.46.0, instalador via
  `electron-builder` (`dist:win`, `dist:linux`, `dist:mac`).
- `status_pc` real: carga de CPU por tempos do `os.cpus()`, RAM livre/total,
  disco via `statfs`, sistema e tempo ligado.
- Painel “Status do celular” no `index.html`, com ação `status_dispositivo` que
  escolhe o adaptador (`status_pc` no desktop, canal nativo no Android).
- Testes próprios: `tests/test_status_dispositivo_desktop.js`,
  `tests/test_pc_windows.py`, `tests/test_pc_arquivos.js`, `tests/test_pc_cad.js`.

Ou seja: o “Status do PC e do Celular” que o pedido cita já existia em parte no
PC; o que faltava era uma regra única de apresentação e um caminho declarado
para o pareamento.

## O que foi entregue nesta etapa

1. **`docs/ROTEIRO-PC.md`** — sete etapas com entregável e critério de aceite:
   base de produção e status unificado; status dos dois lados no app do PC;
   pareamento PC ↔ celular; memória e pessoas; segurança; voz e segundo plano;
   empacotamento e teste em PC real. Inclui a decisão de manter o Electron por
   ora e reavaliar no fim da Etapa 3.
2. **`lib/core/status_plataforma.dart`** — modelo único para os dois lados:
   - lê o formato Android (`bateria`, `temperatura`, `uptimeMin`, `conexao`,
     `modelo`) e o do Electron (`cpu`, `ramTotal`, `ramLivre`, `discoTotal`,
     `discoLivre`, `uptime` em texto, `aparelho`);
   - títulos “Status do PC” e “Status do celular”;
   - formata memória e disco como “8 GB de 16 GB em uso (50%)”, bateria com
     “(carregando)”, temperatura com vírgula e uptime em min/h/dia(s);
   - campo ausente não vira zero: a linha some e `semDados` denuncia o vazio.
3. **Teste puro** `tool/status_plataforma_test.dart`, com o mapa do PC, o do
   celular, mapa nulo, mapa inútil, campo único, memória só com total e os
   quatro formatos de uptime.
4. **Contrato** `tests/test_bloco_124.py`, que confere as sete etapas do
   roteiro, os campos lidos no modelo, os campos entregues por `status_pc` no
   Electron (para o PC não regredir) e os registros de versão.

## Verificações feitas

- `dart run tool/status_plataforma_test.dart` — OK.
- `python3 tests/test_bloco_124.py` — OK.
- `flutter analyze`, `flutter test`, suíte Python inteira e pré-checagens.

## O que não foi feito (e o que vem depois)

- Nenhuma linha do app Electron mudou de comportamento: a Etapa 1 só cria a
  regra compartilhada e o roteiro.
- A Etapa 2 é a que coloca as duas seções no painel do PC, com “sem conexão” no
  lado do celular até o pareamento existir.
- Nada foi executado em PC físico: o `status_pc` foi conferido por leitura e
  contrato, e o modelo por teste puro.
