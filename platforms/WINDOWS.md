# J.A.R.V.I.S. Nova no Windows — camada PC

Este documento descreve **o que a versão de PC faz, o que ela não faz e como isso foi
verificado**. Ele acompanha a versão 1.21.5: o núcleo é o mesmo do Android, e a camada
`platforms/desktop` é a única parte específica de computador.

## 1. Arquitetura: um núcleo, três arquivos de PC

```
raiz (compartilhado — roda igual no Android, no PC e no navegador)
  index.html  style.css  app.js  hermes.js  memoria.js  plataforma.js
  orbita.js   cad.js                       <- CAD: parser, malha, DXF/STL/3MF/STEP/IFC
  pc.js                                    <- interface do PC (não liga fora do Electron)
platforms/desktop
  main.js          janela, IPC, cofre de chaves, Obsidian, captura de tela
  arquivos.js      motor de arquivos (detecção por assinatura, prévias, backup, diff)
  cad_pc.js        CAD do PC (identificar, geometria, criar, versionar, exportar)
  preload.js       ponte segura: só `jarvisNative.run(acao, args)`
```

Por que assim:

- **`cad.js` não foi duplicado.** Um `.cad` criado no PC abre no Android e vice-versa,
  porque a geometria, a malha e os exportadores são os mesmos arquivos. A camada de PC
  apenas lê o disco e entrega geometria para o canvas.
- **`arquivos.js` e `cad_pc.js` são Node puro, sem `require('electron')`.** Isso permite
  rodar os testes de verdade (`node tests/test_pc_arquivos.js`) fora da janela — e é o
  que garante que o que foi testado é o mesmo código que o app usa.
- **`pc.js` não existe no Android na prática:** ele retorna na primeira linha quando
  `window.jarvisNative` não está presente. O painel e o botão nascem com `hidden`.

O que veio do Android sem reescrita: personalidade e humor (Hermes), memória por tópicos,
cofre do Obsidian, provedores de IA e cofre de chaves (no PC, `safeStorage` do sistema),
diagnóstico com estados reais, núcleo 3D e a matriz CAD.

O que é só do PC: leitura/gravação de arquivos reais, visualizador CAD em canvas,
exportação para disco, tarefas sequenciais e o diagnóstico do computador.

## 2. Motor de arquivos (`platforms/desktop/arquivos.js`)

Formato identificado por **assinatura de bytes**, não pela extensão. Uma imagem PNG
renomeada para `.txt` continua sendo imagem — e o teste cobre exatamente isso.

| Família | Como é lido | O que a interface mostra |
| --- | --- | --- |
| Texto, código, MD, JSON, YAML, XML, LOG | UTF-8, até 2 MB | editor com "Salvar com backup" |
| CSV/TSV | parser com aspas e separador detectado | tabela, primeiras 40 linhas |
| PNG, JPEG, GIF, WebP, BMP, SVG | cabeçalho + bytes | imagem inline (PNG informa largura × altura) |
| PDF | `%PDF-x`, contagem de `/Type /Page` | metadados e nº de páginas — **sem renderizar páginas** |
| DOCX | ZIP → `word/document.xml` → texto | parágrafos extraídos (somente leitura) |
| XLSX | ZIP → `workbook.xml` + planilhas | nomes das planilhas e contagem de células |
| PPTX | ZIP → `ppt/slides/*.xml` | contagem de slides |
| ZIP/ODF | tabela central do ZIP | lista de entradas e tamanho descomprimido |
| CAD | delega ao `cad_pc.js` | atalho para a aba CAD |
| Binário desconhecido | assinatura + heurística de bytes de controle | recusa: "não é texto, não exibo nem edito" |

Operações implementadas de verdade:

- **listar** com tipo detectado por arquivo (até 500 itens);
- **ler** com prévia por formato (limite de 32 MB por arquivo);
- **salvar** com cópia `nome.bak-<data>` e troca atômica (`tmp` + `rename`);
- **comparar** dois arquivos por bloco (prefixo comum, linhas removidas/adicionadas);
- **pesquisar** texto em arquivos de até 2 MB, até 4 níveis de profundidade;
- **converter** apenas os pares que existem: `csv→json`, `json→csv`, `md→html`,
  `html→txt`, `txt→md`. Qualquer outro par é recusado com a lista do que existe;
- **organizar** por tipo em subpastas, sempre em duas etapas: plano (nada muda) e
  aplicação; nunca sobrescreve arquivo homônimo;
- **criar pasta**, **mover** (recusa destino existente) e **apagar** (só pela lixeira do
  sistema, via `shell.trashItem`).

Todas as funções resolvem o caminho dentro da pasta do usuário (`app.getPath('home')`).
`~/../../etc` e `/etc` são recusados antes de qualquer acesso ao disco.

## 3. CAD do PC (`platforms/desktop/cad_pc.js`)

### Matriz por formato

| Formato | Identifica | Abre/visualiza | Cria | Edita (nova versão) | Exporta | Limitação real |
| --- | --- | --- | --- | --- | --- | --- |
| `.cad` CadSimu | sim | sim, malha 3D | sim | **sim** (posição, dimensões, raio, altura, nome) | sim | — |
| DXF (ASCII) | sim | sim, linhas por camada | sim | não | sim | não edito entidade a entidade; sem hachura, bloco ou cota |
| STL (binário/ASCII) | sim | sim, malha com profundidade | sim | não | sim | sem unidades no arquivo; malha facetada |
| 3MF | sim | não no painel | sim | não | sim | visualização pelo `.cad` de origem |
| STEP (ISO 10303-21) | sim | entidades e referências | sim | não | sim | sem kernel B-rep: não converto STEP em malha |
| IFC | sim | esquema e elementos | sim | não | sim | não reconstruo geometria BIM completa |
| DWG | sim (`AC10xx`) | **não** | não | não | não | binário proprietário (ODA/RealDWG) |
| FCStd | sim (ZIP) | **não** | não | não | não | árvore paramétrica exige FreeCAD |
| RVT / RFA | sim (OLE) | **não** | não | não | não | formato proprietário do Revit |

### O que o visualizador faz

- **2D (DXF):** lê `LINE`, `LWPOLYLINE`, `POLYLINE` (com `VERTEX`), `CIRCLE` e `3DFACE`;
  desenha os segmentos com ajuste automático de escala; arrastar move, roda dá zoom.
- **3D (`.cad`, STL):** mesma malha que o app exporta; projeção com rotação/inclinação,
  pintura por profundidade (algoritmo do pintor) e fundo escuro do tema.
- **Propriedades:** contagem de triângulos/segmentos, volume, área, malha fechada,
  camadas, objetos e unidades.

### Regras de integridade

- criar valida o documento **antes** de gravar e **reabre** depois de gravar;
- alterar sempre gera `nome-v2.cad` (ou o próximo livre) e só confirma depois de reabrir;
  o original é lido de novo no teste para provar que não mudou;
- exportar valida por reabertura e devolve as **perdas** da conversão (ex.: STL sem
  unidades e sem nomes de objetos);
- edição inválida (objeto inexistente, dimensão zero) é recusada **antes** de gravar.

## 4. Tarefas e diagnóstico

**Tarefas** são sequências de passos já permitidos (`listar`, `procurar`, `organizar`,
`converter`, `pasta`, `identificar`, `abrir`, `exportar`). O processo principal confere
cada passo contra uma lista branca, executa em ordem, **para no primeiro erro** e devolve
relatório por passo. Cancelar interrompe antes do próximo passo. Não existe "executar
comando": o pior efeito de um passo é o de uma ação isolada.

**Diagnóstico do PC** (`diag_pc`) verifica: versão instalada, núcleos e memória livre,
espaço em disco, provedores com chave no cofre do sistema (nomes, nunca valores), cofre
do Obsidian (existência, notas, permissão de escrita), motores de arquivo e CAD, presença
de FreeCAD/LibreCAD/Inkscape/LibreOffice e as últimas falhas registradas nesta sessão.
Estados: `ok`, `aviso`, `erro`, `nao_configurado`, `nao_verificado`. O que não foi
possível medir aparece como não verificado — nunca como aprovado.

## 5. Segurança

- o renderer nunca envia comando de shell nem escolhe ação fora da lista branca;
- toda escrita/leitura fica dentro da pasta do usuário (validada em cada chamada);
- exclusão usa a lixeira do sistema; não há `rm`/`unlink` direto de arquivo do usuário;
- sobrescrita exige confirmação explícita (`sobrescrever`) e, quando acontece, deixa
  `.bak-<data>`;
- chaves de API continuam no cofre cifrado do SO (`safeStorage`), 0600, sem valor
  exposto no diagnóstico nem nos logs;
- o painel é somente leitura para formatos que o app não edita (PDF, DOCX, XLSX, PPTX).

## 6. Testes — o que rodou e o que não rodou

Executado neste ambiente (Linux, Node 24, sem display):

| Verificação | Resultado |
| --- | --- |
| `node tests/test_pc_arquivos.js` | 19 verificações, todas passando |
| `node tests/test_pc_cad.js` | 12 verificações, todas passando |
| `python3 tests/test_pc_windows.py` | contrato entre motores, IPC, painel, build e docs |
| `npm run test:all` | suíte completa do projeto |
| `node --check` nos três arquivos novos | sintaxe válida |

**Não testado por falta de ambiente:**

- janela Electron real (exigiria display; o visualizador foi validado por geometria, não
  por screenshot);
- abrir/arrastar com mouse e roda de zoom na prática;
- leitura de DOCX/XLSX/PPTX reais (a extração foi validada pela estrutura ZIP, não por
  arquivos do Office de amostra);
- seleção de pasta do Obsidian no diálogo nativo do Windows;
- execução do instalador NSIS em máquina Windows limpa.

Nada disso deve ser lido como aprovado: são pendências explícitas.

## 7. Compilar e instalar

```bash
npm ci                 # dependências do lockfile
npm start              # abre a janela em modo desenvolvimento
npm run dist:win       # instalador NSIS em dist/
```

- **Instalador:** `dist/J.A.R.V.I.S. Nova <versão>.exe` (NSIS, por usuário).
- **Pasta portátil:** `dist/win-unpacked/` — roda sem instalar.
- **Dados do usuário:** `%APPDATA%/jarvis-nova` (chaves cifradas e cofre autorizado).
  Atualizar por cima preserva esses arquivos; desinstalar não os apaga.
- **Sem dependências silenciosas:** o app não instala FreeCAD, LibreCAD ou LibreOffice.
  Se existirem, o diagnóstico os detecta; se não, os formatos que dependem deles são
  recusados com explicação (FCStd, RVT/RFA, DWG).

### Diferenças em relação ao Android

| Recurso | Android | Windows |
| --- | --- | --- |
| Modelo local `.task` (MediaPipe) | sim | não (o MediaPipe GenAI é nativo do Android) |
| Voz | motor nativo + segundo plano | motor do Chromium embutido, sem escuta em segundo plano |
| Câmera/visão | câmera do aparelho | captura de tela; câmera depende do dispositivo |
| Notificações/lembretes do sistema | sim | não |
| Obsidian | pacote `.md` (sem acesso a pasta) | pasta real escolhida no diálogo |
| Arquivos do sistema | seleção pontual (SAF) | pasta do usuário com painel completo |
