# Sequência 1.47.0 — integração funcional Flutter, CADeSIMU, IA local, memória e pareamento

**Branch:** `feat/functional-integration-1.47.0`  
**Base:** `feat/flutter-dart-migration-1.46.0`  
**Estado:** iniciada; nenhum dos itens abaixo é declarado concluído por este documento.

## Regras de execução
- Preservar `main`, a linha 1.46 e os módulos legados até haver equivalência comprovada.
- Não usar Picovoice. Não incluir ESP32 nesta sequência.
- Groq é o provedor prioritário; credenciais sempre no armazenamento seguro do sistema.
- Nenhuma tela, cartão ou botão conta como integração. Só ativar ações depois de ligar serviço real e testar sucesso, erro, permissão negada, timeout, cancelamento e persistência.
- Não chamar `.cad` JSON interno de formato nativo CADeSIMU.
- Não declarar KWS PT-BR validado com o modelo GigaSpeech inglês sem medições.
- Release Android e Windows deve sair do mesmo commit e só depois de testes de integração.

## Estado de partida confirmado
- PR #8 continua aberta em rascunho; não mesclar nem alterar `main` nesta sequência.
- CI legado/KWS: run 42703343705 concluído com sucesso; suíte automatizada e compilação APK de validação passaram.
- Flutter: run 42703343152 concluído com sucesso; analyze, testes e builds debug Android/Windows passaram.
- Flutter ainda é um shell de catálogo. A tela declara explicitamente que Hermes, voz, KWS, memória/Obsidian, visão, CADeSIMU, pareamento e Windows ainda não têm adaptadores Flutter.
- `ProviderService` já implementa guardar/testar/remover chaves dos cinco provedores no armazenamento seguro Flutter, mas não substitui o roteador Hermes nem está provado como motor conversacional completo.
- `memoria.js` tem busca lexical + embedding determinístico por hash/trigramas de 128 dimensões; não é embedding neural. Há importação/exportação Markdown e IDs estáveis no legado, mas a UI Flutter não está ligada a isso.
- `JarvisLocalAIPlugin` legado usa MediaPipe LLM Inference 0.10.24 e modelo `.task`; Gemma 3 1B IT requer importação do modelo e teste de geração no dispositivo. O diagnóstico do projeto aponta que LiteRT-LM é a direção recomendada para novos desenvolvimentos, mas a troca exige migração e testes. O diagnóstico de PC legado informa que o modelo local não está conectado no Windows.
- `cad.js` chama seu JSON de “CadSimu CAD”, mas é formato interno Jarvis para primitivas geométricas 3D. `projetista.js` cria projetos elétricos determinísticos em JSON próprio e declara que não lê nem grava o formato nativo proprietário CADeSIMU. Não há evidência de compatibilidade nativa CADeSIMU.
- A camada Windows legada tem Electron/Node, IPC com lista branca, arquivos, CAD genérico e diagnóstico de PC. Isso não equivale à interface Flutter Windows nem prova paridade total.
- Não foi localizada integração de pareamento QR funcional na base da PR #8; deve ser implementada e auditada antes de habilitar o cartão correspondente.

## Frente A — Flutter como interface oficial Android + Windows
1. Criar contratos Dart versionados para Hermes/Core, armazenamento seguro, memória, IA local, voz/KWS, visão/OCR, arquivos, CAD, status de dispositivo, pareamento e controle remoto.
2. Criar adaptadores nativos separados por plataforma: Android (Kotlin/Platform Channels) e Windows (Dart FFI/Method Channels ou serviço local assinado, conforme suporte real).
3. Não executar código arbitrário recebido pelo IPC; lista branca, autorização por sessão, validação de argumentos e logs sem segredos.
4. Migrar telas por fluxo completo, não apenas por aparência. Catálogo só mostra “ativo” após health check do serviço.
5. Migrar preferências e cofre de chaves com leitura/escrita/teste/remover, sem expor valores.
6. Só mudar o entrypoint do APK/Windows depois de paridade aprovada e plano de rollback.

## Frente B — CADeSIMU e engenharia elétrica
1. Separar claramente três conceitos: formato interno Jarvis CAD 3D; projeto elétrico interno do Projetista; arquivo nativo CADeSIMU.
2. Obter arquivos reais de exemplo do CADeSIMU (circuito de comando, partida direta, reversão e estrela-triângulo), criados e salvos no aplicativo oficial, para engenharia reversa controlada e testes diferenciais.
3. Inspecionar assinatura, estrutura, codificação, símbolos, coordenadas, fios, contatos, bobinas, referências cruzadas e metadados. Não inventar formato nem sobrescrever originais.
4. Implementar importador/exportador apenas para estruturas comprovadas; preservar dados desconhecidos em round-trip e recusar gravação destrutiva.
5. Construir editor elétrico Flutter com biblioteca de componentes, encaixe de fios, seleção múltipla, zoom/pan, propriedades, desfazer/refazer, camadas comando/potência/CLP e validação visual.
6. Validar continuidade, curto, bobinas, contatos NA/NF, intertravamento, proteção, alimentação e sequência. Distinguir análise estrutural de simulação física.
7. Testar abrir → editar → salvar cópia → reabrir no CADeSIMU oficial; comparar resultado e documentar limitações.
8. Se o formato não puder ser validado, oferecer exportação intermediária comprovada (ex.: DXF/relatório/netlist) e não alegar compatibilidade nativa.

## Frente C — IA local
1. Auditar `JarvisLocalAIPlugin`, dependências, ciclo de vida, memória, cancelamento, limites de contexto e erros nativos.
2. Validar Gemma 3 1B IT Q4 com arquivo `.task` real no Poco X7/Android 16: importar, carregar, gerar, cancelar, descarregar, reabrir, medir RAM/latência/bateria/temperatura e testar pressão de memória.
3. Separar estados: não importado, importado, formato válido, carregado, geração aprovada, indisponível por memória.
4. Garantir que o modo local não dependa de internet/chaves; não fazer fallback silencioso para nuvem quando o usuário escolheu offline.
5. Integrar o mesmo contrato ao Flutter Android; para Windows, selecionar runtime local suportado (LiteRT-LM/ONNX/llama.cpp após prova de compatibilidade), com detecção de hardware e modelo explicitamente instalado.
6. Não alegar paridade local entre Android e Windows até os dois motores executarem testes equivalentes.

## Frente D — memória semântica e Obsidian
1. Migrar o repositório de notas do legado sem perda, mantendo IDs, histórico, temas e deduplicação.
2. Distinguir busca lexical/hash atual de embeddings semânticos neurais. Criar interface de embedding substituível e avaliar modelo multilíngue local para português; fallback lexical explícito.
3. Implementar recuperação híbrida (lexical + vetor + recência + importância), limiar calibrável, explicação do motivo do resultado e testes contra consultas parafraseadas.
4. Implementar persistência transacional, versionamento, conflito de edição e sincronização bidirecional Markdown com Obsidian, sem apagar notas alheias.
5. Unificar o seletor do cofre em Ajustes > Memória; Android usa SAF/URI persistida, Windows usa seletor nativo. Permissões revogadas devem produzir estado claro.
6. Testar importação repetida, sincronização repetida, conflito, restauração e migração sem duplicações.

## Frente E — pareamento QR Android ↔ Windows
1. Pareamento por QR com payload mínimo: endpoint local/identidade efêmera, nonce, versão do protocolo e chave pública efêmera; nunca incluir token permanente ou segredo no QR.
2. Exigir confirmação explícita nos dois dispositivos, comparação de código curto, expiração curta e uso único do desafio.
3. Estabelecer canal autenticado e criptografado (TLS com pinning/identidade de dispositivo ou Noise protocol), derivar segredo de sessão e armazenar credenciais no cofre do SO.
4. Descoberta na LAN com fallback manual de endereço; suportar redes diferentes apenas por relay explicitamente configurado, sem abrir portas públicas automaticamente.
5. Autorizar por escopos (status, arquivos, controle, câmera/microfone) e revogar dispositivos individualmente.
6. Implementar reconexão, rotação/revogação de chaves, replay protection, rate limiting, auditoria sem dados sensíveis e modo somente leitura.
7. Android e Windows devem mostrar estado real: não pareado, aguardando, pareado, offline, revogado, erro de autenticação.
8. Testar QR expirado/reutilizado, MITM, replay, PIN/código incorreto, rede isolada, perda de conexão, revogação e reinstalação.

## Frente F — paridade funcional Windows
Criar matriz por ação do catálogo operacional (incluindo 53 ações atuais e subsistemas fora do catálogo). Para cada recurso registrar: Android, Windows, adaptação, permissão, serviço, teste automatizado, teste em máquina real e limitação.
- Adaptar sensores e permissões mobile a recursos equivalentes do PC; nunca exibir GPS/bateria/câmera/microfone como ativos sem API real.
- Windows deve receber painel de status de CPU/RAM/disco/rede/bateria quando disponível, processos e controles autorizados.
- Pareamento é pré-requisito para ações remotas do telefone no PC; controle local no próprio PC segue política separada.
- KWS no Windows requer implementação local específica e configuração de microfone; não reutilizar pressupostos Android.
- Preservar Electron/Node até Flutter Windows substituir cada serviço e fluxo com evidência.

## Sequência de execução e gates
1. Inventário técnico e contratos (sem telas falsas).
2. Bridge Flutter ↔ serviços existentes, primeiro leitura/diagnóstico e cofre.
3. Memória/Obsidian bidirecional com migração e testes de não duplicação.
4. Motor IA local Android validado; depois runtime local Windows.
5. Pareamento QR seguro e escopos de controle.
6. Matriz de paridade Android/Windows e migração dos fluxos.
7. CADeSIMU: arquivos reais, parser/serializer, editor, validação e round-trip no programa oficial.
8. Testes integrados em Android 16/HyperOS e Windows real; correção de todas as regressões.
9. Release única Android + Windows, checksums, assinatura, notas e rollback.

## Critérios finais de conclusão
- Nenhuma frente pode ser encerrada por teste estático isolado.
- Flutter Android e Windows são as interfaces de produção e todos os botões executam serviços reais.
- Os mesmos fluxos de IA, memória, arquivos, projetos, agentes, tarefas e pareamento funcionam nas duas plataformas, com adaptações documentadas para hardware.
- Gemma local gera resposta offline real em Android; modelo local Windows também gera resposta offline real.
- Memória recupera paráfrases em português e sincroniza Obsidian sem duplicar ou apagar conteúdo.
- Pareamento QR passa os testes de segurança e reconexão.
- Arquivos de CADeSIMU abrem e salvam no CADeSIMU oficial, ou o produto informa claramente a limitação e fornece intercâmbio alternativo comprovado.
- Suíte legada + Flutter + integração + builds Android/Windows verdes no mesmo commit.
- Testes físicos e evidências anexados. Só então criar Release estável.
