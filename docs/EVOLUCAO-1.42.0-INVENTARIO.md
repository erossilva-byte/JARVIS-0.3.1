# Inventário da evolução 1.42.0 — J.A.R.V.I.S. Nova

> Auditoria feita antes de alterar o núcleo. Este documento registra o que já existia,
> o que foi reutilizado e o que permanece bloqueado. Ele não declara concluído nenhum
> módulo que não tenha implementação e teste correspondentes.

## 1. Estado do repositório

- Repositório: `https://github.com/erossilva-byte/JARVIS-0.3.1.git`
- Branch de trabalho: `feat/evolucao-1.42.0`
- HEAD da branch: `26ec589` (`Registra o run bem-sucedido do GitHub Actions`)
- Base usada: `release/1.38.1-20261101`
- `main` e `origin/main` continuam em `33d8c6d` (1.31.2); **não foram mescladas**.
- O working tree já continha as alterações não commitadas de 1.39.0, 1.40.0 e 1.41.0;
  elas foram preservadas, não recriadas nem substituídas.
- Nenhum commit, push, release ou publicação foi feito nesta etapa.

## 2. Referência de testes

- Antes da memória semântica, a suíte de 1.41.0 passou com 2.060 linhas `OK` e `EXIT:0`.
- `node tests/test_memoria_md.js` passou após a primeira camada de memória.
- `node tests/test_memoria_semantica.js` cobre paráfrase, stopwords, embedding,
  RAG, registro de uso, histórico, restauração e conflito do Obsidian.
- A suíte completa foi executada ao final desta etapa com `EXIT:0`; o log está em
  `artifacts/test-all-memoria-1.42.log`.
- A auditoria de runtime em jsdom carregou `index.html` e um subconjunto dos scripts
  reais, clicou 18 abas e 287 botões e terminou sem exceções nem erros de runtime.
  O log está em `/tmp/jarvis-boot-audit-after.log`; o subconjunto não substitui o APK.
- A suíte foi repetida após a correção do Core e da navegação: `EXIT:0`, 2.065
  linhas `OK`, zero linhas `FALHA`; log em `artifacts/test-all-reconstrucao-final2.log`.

## 3. Inventário dos módulos existentes

| Área | Módulo/arquivo existente | O que já havia | Decisão nesta etapa |
|---|---|---|---|
| Memória e Obsidian | `memoria.js`, `app.js`, `index.html`, `platforms/desktop/main.js` | Notas por tema, busca textual, Markdown, cofre local, exportação/importação e painel | **Ampliado**: embedding lexical, recuperação por significado, RAG, prioridade, versões e conflito de importação |
| Pareamento Android/Windows | nenhum módulo oficial | Apenas canais/plataforma existentes | **Não iniciado**: exige protocolo, QR, autenticação mútua e dois dispositivos |
| Sandbox de código | `arquivos_dev.js`, `sistema.js`, `pc.js`, camada Windows | Criação/leitura de arquivos e executores existentes | **Não iniciado**: não há isolamento real; não foi criado stub |
| Agentes | `agentes.js`, `sistema.js`, `plano.js`, `hermes.js`, `core.js` | Agentes, plano, ferramentas e executores seguros; 12 agentes descritivos, 6 executores registrados no app | **Preservado e corrigido**: a verificação do Core agora recusa falha escrita mesmo com `ok: true`; nenhum segundo sistema de agentes foi criado |
| Visão/OCR | `visao.js`, câmera e captura existentes | Objetos, balões, análise de imagem | **Não iniciado**: OCR/modelo e validação visual continuam pendentes |
| Voz/biometria | `voz_motor.js`, `escuta.js`, `identidade.js` | Vetores, amostras, consentimento, replay gate e diagnóstico | **Preservado**: não foi substituído nem simulado |
| ESP32/Home Assistant | nenhum módulo oficial | Ferramentas e agentes centrais | **Bloqueado**: depende de hardware, firmware e token reais |
| Controle Windows | `platforms/desktop/main.js`, `preload.js`, `pc.js` | IPC, automação e permissões existentes | **Preservado**: não foi aberta API irrestrita ao renderer |
| Interface | `index.html`, `app.js`, `interface.css`, `interface.js` | Núcleo futurista, áreas, memória, visão, ajustes | **Ajuste local**: busca por significado e aviso de conflito na memória |

## 4. O que foi realmente alterado agora

1. `memoria.js`
   - embedding lexical determinístico de 128 dimensões (palavra + trigramas),
     normalizado e comparável por cosseno;
   - dicionário fechado de sinônimos e remoção de palavras vazias;
   - `buscarSemantica()` com limite, limiar de cosseno, corte relativo e explicação
     do motivo (`significado`, `termos` ou `tema`);
   - `buscar()` mantém a busca literal primeiro e usa a semântica como fallback;
   - `contextoRelevante()` (RAG) usa somente resultados relevantes e registra uso;
   - prioridade por importância, recência e frequência de uso;
   - histórico de até três versões, restauração e `reforcar()`;
   - `importarMarkdown()` devolve conflitos quando o título já existe com conteúdo
     diferente e **não sobrescreve** a nota original.
2. `app.js`
   - o painel de memória usa `buscarSemantica()` e mostra a relevância;
   - o resultado do Obsidian informa conflitos preservados;
   - a importação manual de `.md` também informa conflitos.
3. `index.html`
   - o campo de busca passa a dizer “Buscar por significado” e explica que o
     embedding é local.
4. `tests/test_memoria_semantica.js`
   - novo teste de regressão dedicado.
5. `package.json`
   - o novo teste foi incluído em `test:all`.
6. `core.js` e `tests/test_core.js`
   - corrigida a confirmação falsa de resultado: a resposta `{ ok: true, info: "Não consegui…" }`
     agora é `falhou`, e um recibo `ok` não apaga uma falha explícita no texto;
   - o teste cobre falha explícita, recibo otimista contraditório e a frase legítima
     “Concluído sem falhas”.
7. Auditor de navegação
   - o mapa de abas foi corrigido para incluir `#painel-areas`, `#painel-core`,
     `#painel-pessoas` e `#painel-dev`; “Central” é testada separadamente como ação
     que fecha todos os painéis;
   - resultado: 18 abas, 287 botões, zero exceções no subconjunto carregado.
8. Navegação e camada visual
   - `fecharPaineis()` passou a limpar o marcador com `replaceState`, em vez de
     agendar `history.back()`; um `popstate` atrasado não fecha mais o painel que
     acabou de abrir;
   - `garantirInterfaceVisivel()` recupera `scrim` e `travado` órfãos em até 2 s;
   - a auditoria jsdom reproduziu fechar → abrir e confirmou que o painel novo
     permanece visível;
   - a abertura demorada oferece “Continuar sem reconhecer” após 8 s, sem esperar
     o limite duro de 45 s.

## 5. Limitações declaradas

- O embedding é **lexical determinístico**, não um modelo neural. Ele melhora a
  recuperação por sinônimos e paráfrases simples, mas não compreende linguagem
  natural arbitrária como um modelo de embeddings treinado.
- A memória de curto prazo, as relações entre pessoas/projetos e a detecção de
  contradições continuam parciais; não foram apresentadas como concluídas.
- A sincronização Obsidian → Jarvis é manual/por leitura de cofre; gravação automática
  Bidirecional com resolução de conflitos na interface ainda não foi concluída.
- O pareamento, o sandbox real, OCR, biometria nova, ESP32/Home Assistant e controle
  Windows ampliado **não foram implementados** nesta etapa.
- Nenhum teste de hardware, áudio, câmera, rede ou dois dispositivos foi simulado.
- O APK local continua sendo o **1.41.0/10410**; ele não contém a memória semântica,
  a correção do Core nem a auditoria desta etapa. Não existe APK 1.42.0 compilado.
- A auditoria jsdom carrega apenas um subconjunto de scripts; ela não prova o
  comportamento do APK, do Capacitor, do microfone, da câmera ou do Android.

## 6. Invariantes de segurança preservados

- Nenhum `eval`, `Function` ou execução de código recebido pela IA no processo principal
  foi adicionado.
- Nenhum token, áudio bruto ou biometria em texto puro foi criado.
- A memória continua local; não há envio do cofre para serviço externo.
- `contextIsolation`, `nodeIntegration: false`, `sandbox: true` e as confirmações
  existentes não foram alterados.
- Operações destrutivas continuam exigindo confirmação; a importação de nota com
  conflito não apaga nem sobrescreve arquivo do usuário.

## 7. Próximos passos, em ordem de dependência

1. **Concluído nesta rodada:** suíte completa verde (`EXIT:0`, 2.065 `OK`), regressão
   do Core e regressão de navegação aprovadas.
2. Ampliar a memória com relações, curto/longo prazo e sincronização automática
   observável, sem trocar o módulo existente.
3. Implementar o pareamento com protocolo autenticado e testes em dois dispositivos.
4. Implementar o sandbox com isolamento comprovado antes de conectá-lo aos agentes.
5. Tratar OCR/biometria com modelos e aparelhos reais; manter pendente sem hardware.
6. Integrar ESP32/Home Assistant somente com token e dispositivo reais.
7. Ampliar o Windows por allowlist, validação de IPC e confirmação de risco.
8. Só então atualizar versão, gerar APK/instalador e publicar com relatório de testes.
