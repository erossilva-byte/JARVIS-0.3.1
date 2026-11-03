# Auditoria técnica — estado real do J.A.R.V.I.S. Nova

Data: 2026-11-03 · branch `feat/evolucao-1.42.0` · base: 1.42.4 (release publicada)

Este documento registra **o que foi verificado, como e com qual resultado**. Onde não houve
verificação, está escrito que não houve.

## 1. Método

1. Suíte completa do projeto (`npm run test:all`) — 2.107 verificações, EXIT 0 na base desta rodada.
2. Testes do projetista e da interface do projetista (jsdom com o app inteiro).
3. Verificação estática: ids duplicados no HTML, botões sem referência, funções duplicadas,
   capturas de erro vazias, padrões de segredo, marcadores TODO/FIXME, gravações de armazenamento.
4. Leitura dos módulos de arquivo: `platforms/desktop/arquivos.js`, `cad.js`, `pc.js`,
   `projetista.js`.
5. Contratos do repositório (`tests/test_v1_*.py`, `test_release_readiness.py`,
   `test_ui_responsive.py`, `test_novos_recursos.py`).

## 2. Resultado da verificação estática

| Verificação | Resultado |
| --- | --- |
| ids duplicados em `index.html` | nenhum |
| funções declaradas duas vezes em `app.js` | nenhuma |
| segredos/chaves em arquivos rastreados | nenhum (padrões `sk-`, `AIza`, `ghp_`, `api_key`) |
| TODO/FIXME em `app.js`, `cad.js`, `projetista.js`, `pc.js`, `platforms/desktop/arquivos.js` | nenhum |
| botões "sem handler" | 53 apontados, **todos falso positivo**: são tratados em `pc.js`, `interface.js`, `core_ui.js`, `identidade_ui.js`, `aprendizado_ui.js` |
| `catch` vazio em `app.js` | 78 — avaliados como intencionais (armazenamento indisponível, permissão negada), registrados como risco de diagnóstico |

## 3. Achados e classificação

### Crítico

Nenhum achado crítico confirmado nos caminhos exercitados pelos testes. Não houve corrupção de
dados, perda de arquivo nem falha de inicialização nos testes executados.

### Alto

Nenhum achado alto confirmado. **Ressalva obrigatória**: não há verificação em aparelho Android
físico, não há execução do aplicativo Windows neste ambiente e não há CADeSIMU instalado. Falhas
que só aparecem nesses ambientes não foram descartadas — apenas não foram observadas.

### Médio (corrigidos nesta rodada)

1. **Projeto elétrico não podia ser editado depois de criado.**
   Causa: o módulo só criava projeto novo a partir de pedido.
   Correção: `modificar(projeto, pedido)` em `projetista.js`, com apoio da interface
   (`#proj-mod` + `#proj-modificar`). Operações: adicionar temporizador com sinalização
   retardada, remover componente, adicionar proteção térmica, trocar tensão de comando e
   reconstruir como partida direta / reversão / estrela-triângulo / compensadora, preservando
   potência, tensões e emergência. O original não é alterado (clone antes de modificar) e a
   diferença é calculada.
2. **Salvar projeto sobrescrevia sem histórico.**
   Causa: registro local guardava apenas a versão atual.
   Correção: cada gravação empilha a anterior (até 5), com `versoes()`, `lerVersao()` e
   `restaurar()`. Restaurar grava como versão nova: a atual continua no histórico.
3. **Não havia comparação entre projetos.**
   Correção: `comparar(a, b)` — componentes adicionados/removidos/alterados (tipo, função,
   tensão, pinos), redes novas/removidas e status de verificação dos dois lados.
4. **Mensagem de sucesso sem gravação real no armazenamento local do projetista.**
   Situação anterior: `salvar` devolvia `ok` só após `gravarLista`, mas não reconferia a
   releitura. Correção: a gravação continua condicionada ao `setItem` e agora o teste salva,
   lê de volta, lista versões e restaura — falha em qualquer etapa derruba o teste.

### Baixo

- Ruído de nomenclatura entre "arquivos" (CAD/Cozinha) e "projetos" (projetista) na lista do
  painel; ambos usam o mesmo padrão visual, o título distingue.
- Vista de projeto em cartões com pinos, não em símbolos IEC normalizados (limitação declarada).

## 4. O que já estava correto (e foi confirmado por leitura + teste)

- **Gravação de arquivo no desktop** (`platforms/desktop/arquivos.js`): grava em temporário,
  `fsync`, renomeia, **relê e compara tamanho e hash**, restaura o backup se a conferência falhar,
  e exige confirmação para substituir sem cópia. Não há caminho de "sucesso sem gravar".
- **CAD 3D**: cada exportador (DXF, STL, 3MF, STEP, IFC) reabre o próprio arquivo e devolve a
  validação junto com as perdas da conversão.
- **Bloqueio opcional** (Ajustes ▸ Segurança) e **Obsidian** (Ajustes ▸ Memória) permanecem com
  seus testes de contrato verdes.

## 5. Verificações executadas nesta rodada

| Verificação | Resultado |
| --- | --- |
| `node tests/test_projetista.js` | **OK, 73 verificações** (interpretação, topologias, verificação, correção, arquivo, versões, comparação e modificação) |
| `node tests/test_projetista_ui.js` | OK (criar, desenhar, analisar, corrigir, relatório, ladder, salvar, reabrir, modificar, comparar, versões e restaurar) |
| `npm run test:all` | **EXIT 0, 2.107 verificações** |
| Contratos Python | verdes |

## 6. Não verificado (declarado, não presumido)

- **Compatibilidade com o CADeSIMU**: o formato nativo é proprietário e não há especificação
  pública; o CADeSIMU não está disponível neste ambiente. Nenhum arquivo foi aberto nele.
- **Simulação elétrica**: não implementada; a verificação é estrutural.
- **Android físico** (mic, wake word, arrastar por toque, desempenho no Poco X7).
- **Windows/Electron** em execução real, e integração com um CADeSIMU instalado.
- **Provedores de IA** com chaves reais.

## 7. Recomendações

1. Testar em aparelho Android e no Windows instalado antes de tratar estabilidade como resolvida.
2. Se a compatibilidade binária com o CADeSIMU for requisito, obter arquivos reais e a
   documentação do fornecedor; sem isso, qualquer gerador seria adivinhação.
3. Substituir os cartões da vista por símbolos IEC e permitir edição direta de ligações no palco.
4. Reduzir os `catch` vazios do `app.js` a um log de diagnóstico único, sem mudar comportamento.
