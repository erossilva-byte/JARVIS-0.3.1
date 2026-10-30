# CAD no celular — o que roda de verdade

O celular é o ambiente de **criação, reparo, validação e preparação**. O CAD de
verdade abre no computador. Nada aqui depende de assinatura, nuvem ou serviço pago.

## O que roda no Android (JavaScript puro, dentro do app)

| Operação | Como | Validação feita no aparelho |
|---|---|---|
| Criar projeto por frase | `cad_projeto.js` ▸ `criarDeTexto` (primitivas, dimensões, unidades) | parser do `cad.js` + malha |
| Criar por formulário | painel Arquivos ▸ Criar `.cad` | reabre o arquivo salvo |
| Analisar | `validar` ▸ dimensões, posição, tipo, unidade, duplicata, escala, malha | volume, área, caixa envolvente, arestas abertas |
| Reparar | `reparar` ▸ completa/limita campos, remove duplicata exata, revalida | reabre no parser; original intacto, versão nova |
| Exportar | DXF, STL (binário/ASCII), 3MF, STEP, IFC, `.cad` | cada arquivo é **reaberto pelo leitor correspondente** |
| Script OpenSCAD | `gerarScad` com escala convertida para mm | chaves/parênteses/terminadores; **não executa** |
| Pacote para o PC | ZIP com projeto, trocas, `.scad`, relatório, instruções | CRC do ZIP e reabertura dos formatos |
| Histórico | arquivos `.cad` no cofre local do app | listagem, análise, download, exclusão |

O `.cad` do aplicativo é **JSON próprio e documentado**. Não é o `.cad` do CADe SIMU,
não é DWG e não abre no AutoCAD.

## O que depende do computador

- **Abrir/editar** projeto em AutoCAD, LibreCAD, FreeCAD, Fusion, SolidWorks ou slicer.
- **Compilar** o `.scad` no OpenSCAD (o app só gera e confere a sintaxe).
- **Render/booleanas B-rep** (furos reais, chanfros, fillets): o núcleo atual trabalha com
  primitivas facetadas; não há kernel OCC/FreeCAD embutido.
- **DWG, IGES/IGS, 3DM, FCStd, RVT/RFA, `.cad` do CADe SIMU**: sem leitor/escritor livre.
  Para DWG, exporte DXF e converta no software de destino.

## Transferência

1. **Pacote `.zip`** (botão no painel): projeto + DXF + STL + STEP + `.scad` + relatório.
2. **Compartilhar** pelo Android quando o WebView oferece `navigator.share` com arquivo;
   caso contrário, o pacote é baixado pelo download do navegador.
3. **Wi-Fi/USB**: o ZIP baixado pode ser copiado por cabo, Google Drive ou pasta de rede —
   o app não abre soquete nem servidor local.

## Limites declarados

- STL não carrega unidade: o relatório registra a unidade do projeto, o arquivo não.
- STEP/IFC são exportados como **sólido facetado** (sem histórico paramétrico).
- Malha aberta é avisada, não "consertada": fechar buraco exigiria reconstrução de
  superfície, que não é feita aqui.
- O reparo não altera geometria válida: só campos inválidos e duplicata exata.
