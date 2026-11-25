# 128 — Memória em Markdown e fichas de pessoas no PC (Etapa 4)

**Data:** 25/11/2026 · **Versão:** 1.105.0+110500 · **Bloco:** 128

## O que a Etapa 4 pedia

O roteiro do PC pedia dois entregáveis e um aceite:

- memória em Markdown com busca, citação e sincronização, no mesmo formato do
  celular e com cofre em pasta escolhida;
- fichas de pessoas com consentimento e bloco seguro na conversa;
- aceite: os mesmos testes de regra do celular portados para o JavaScript do PC
  (busca, orçamento, consentimento, ambiguidade).

## O que foi feito

### Regras da memória (`memoria_regras.js`)

Porte de `core/memoria_busca.dart` e `core/memoria_sync.dart` para um módulo
sem DOM que roda no aplicativo e em Node:

- `buscarNotas` — embedding lexical de 128 dimensões (FNV-1a sobre termos e
  trigramas), sinônimos fechados, pontuação `0,50 × similaridade + 0,28 ×
  literal + 0,07 × importância + 0,10 × recência + 0,05 × uso`, corte relativo
  de 50% e regra de que nota sem palavra em comum só entra com similaridade
  ≥ 0,35. Cada resultado carrega o **motivo** (“título contém o termo”, “tag
  correspondente”, “termos parecidos”, “atualizada há pouco”…).
- `contextoRelevante` — orçamento em caracteres, trecho de 500 por nota, no
  máximo 3 notas e devolve **quais** foram usadas. Sem relação com a pergunta,
  devolve vazio em vez do cofre inteiro.
- `citacoes` / `linhaCitacoes` — “Título — Tema”, com caminho quando a nota veio
  da pasta. É o que o painel copia no botão “citar”.
- `lerMarkdown` / `escreverMarkdown` / `hashConteudo` — frontmatter do celular
  (`id`, `titulo`, `tema`, `tags`, `importancia`, `criada`, `atualizada`), hash
  FNV duplo de 16 caracteres, `---` no corpo não corta o texto.
- `planejarSincronizacao` — os mesmos 13 casos do celular: importar arquivo
  novo, enviar nota nova, adotar caminho de nota igual, enviar/receber quando
  só um lado mudou, conflito quando os dois mudaram (ou nunca sincronizaram),
  nota ausente na pasta, mesmo título em caminhos diferentes e caminho repetido.

### Cofre em pasta (`platforms/desktop/memoria_pasta.js`)

No processo principal do Electron: escolher a pasta pelo diálogo do sistema,
lembrar a escolha em `userData/memoria-pasta.json`, listar `.md`
recursivamente (400 arquivos, 200 kB por arquivo), gravar com arquivo temporário
e `rename`, e sincronizar usando a regra testada. Caminho absoluto, `..` e
arquivo que não é `.md` são recusados; nada é apagado.

### Painel e conversa (`index.html`, `app.js`)

- Seção “Cofre em pasta (.md)” no painel de memória, só visível no desktop:
  escolher, sincronizar, desconectar, nome da pasta e status com o resumo
  (enviadas, recebidas, iguais, conflitos, notas só neste PC).
- Busca do painel com motivo e relevância; botão “citar” em cada nota.
- Contexto da IA usa `contextoRelevante` com orçamento de 1.600 caracteres e os
  títulos das notas no bloco (a fonte fica explícita na resposta).

### Fichas de pessoas (`pessoas.js`, `identidade.js`, `identidade_ui.js`)

- `validar` exige nome **e** consentimento declarado; importação pula ficha sem
  consentimento; `revogarConsentimento` tira a ficha do contexto sem apagar.
- `blocoParaConsulta` é o porte de `contextoPessoasParaConsulta`: detalhe,
  ambíguo, ausente ou nenhum; nome completo vence primeiro nome; primeiro nome
  sozinho encontra homônimos e vira pergunta; quando não há ficha, manda dizer
  que não encontrou.
- Só nome, apelido, relação e preferências entram. Contato, descrição,
  observações, compromissos e histórico **nunca** entram — e o teste do contrato
  confere que o bloco não usa esses campos.
- Na tela de pessoas do PC, a ficha nova só salva com a caixa “Tenho o
  consentimento desta pessoa”; editar permite revogar.

## Verificações executadas

- `node tests/test_memoria_regras.js` — busca, colisão de embedding, sinônimo,
  orçamento, citação, Markdown, hash e os 13 casos de sincronização.
- `node tests/test_memoria_pasta.js` — pasta temporária real: escolher,
  cancelar, gravar subpasta, recusar `..`/absoluto/não-`.md`, ler recursivo,
  sincronizar, reenviar sem mudança, receber edição do Obsidian, preservar
  conflito e desconectar sem apagar.
- `node tests/test_pessoas_conversa.js` — bloco seguro, ausência, ambiguidade,
  nome completo, apelido, conversa não relacionada, consentimento revogado e
  cadastro sem consentimento recusado.
- `node tests/test_pessoas.js` — os 16 grupos antigos, atualizados para o
  consentimento obrigatório.
- Regressões: `test_memoria_md.js`, `test_memoria_semantica.js`,
  `test_identidade.js`, `test_pessoas_voz.js`, `test_interface_dom.js`,
  `test_botoes_honestos.js`, `test_diag_dom.js`, `test_identidade_ui.py`,
  `test_pessoas_ui.py`, `test_pessoas_privacidade.py`,
  `test_empacotamento.py`, `test_panel_navigation.py`,
  `test_ui_responsive.py` — todos verdes.
- `node --check` em `memoria_regras.js`, `pessoas.js`, `app.js`,
  `identidade.js`, `identidade_ui.js`, `platforms/desktop/main.js`,
  `platforms/desktop/memoria_pasta.js`.

## O que não foi feito ou medido

- **Nada em PC físico.** A pasta foi exercitada numa pasta temporária real, mas
  o diálogo nativo de escolha de pasta e o Obsidian de verdade não.
- **Tema menor no celular.** O PC tem 10 temas; o celular tem 6. O arquivo é
  Markdown com as mesmas chaves, mas uma nota de “Gostos” escrita no PC volta
  como “Contextos” no celular. Unificar o conjunto de temas é uma etapa própria.
- **Ficha antiga sem consentimento declarado** (criada antes desta versão)
  continua no contexto até o usuário editar e confirmar; o app pede na próxima
  edição, mas não bloqueia o perfil antigo sozinho.
- **Conflito não gera cópia de backup** no PC (o celular tem a tela de
  backups): as duas versões ficam onde estão e o painel lista o conflito.
- **A interface não foi vista rodando** nesta entrega: a conferência foi de
  DOM, de `node --check` e dos testes de regra.
- O contrato `tests/test_bloco_128.py` prende a ligação, mas a suíte completa
  (`test:all`) não foi executada de ponta a ponta nesta máquina.
