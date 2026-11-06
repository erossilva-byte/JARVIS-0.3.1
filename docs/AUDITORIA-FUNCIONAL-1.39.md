# Auditoria funcional — J.A.R.V.I.S. Nova 1.39

Data: 2026-11-01  
Base analisada: branch `work/evolution-1.39-audit-20261101`, versão declarada 1.38.1.  
Escopo: rastreabilidade dos requisitos anteriores, inspeção estática dos módulos e preparação de validações automatizadas. Este documento não declara aprovação de testes físicos.

## Legenda
- **No código**: há módulo, interface ou integração identificável no repositório.
- **Parcial / condicionado**: depende de permissão, serviço, provedor, modelo, software externo ou integração adicional.
- **Teste real pendente**: precisa ser exercitado no Android físico ou no Windows instalado.

## Matriz de requisitos

| Área solicitada | Evidência no projeto | Situação honesta |
|---|---|---|
| Interface inspirada no J.A.R.V.I.S. | `index.html`, `style.css`, `interface.css`, `core.css`, `avatar.js`, `orbita.js` | No código; refinamento HUD 1.39 aplicado; validação visual em telas reais pendente |
| Navegação por áreas e botões | `interface.js`, navegação central em `app.js`, testes `test_panel_navigation.py` e `test_ui_responsive.py` | No código; clique/rolagem em aparelho real ainda precisa ser confirmado |
| Núcleo/rosto 3D e estados | `avatar.js`, `orbita.js`; fallback Canvas 2D e pausa por visibilidade | No código; desempenho e recuperação de GPU precisam de teste no Poco X7 |
| Menos travamentos e consumo | pausa fora da tela, fallback 2D, adaptação de qualidade, limites de DPR e taxa de quadros introduzidos em 1.39 | Mitigações no código; não é possível prometer ausência absoluta de travamentos sem teste prolongado |
| IA e provedores | `hermes.js`, `app.js`, `JarvisLocalAIPlugin.java` | Integração no código; chaves, limites, rede e disponibilidade dos provedores condicionam o uso |
| IA local / arquivos .task | `JarvisLocalAIPlugin.java`, `MODELOS-IA-LOCAL.md`, `tests/test_local_ai.py` | Parcial/condicionado ao runtime, modelo e compatibilidade; Gemma 3 1B IT não deve ser considerado funcional sem teste de carga real |
| Voz, microfone, VAD e TTS | `voz_motor.js`, `escuta.js`, `JarvisVozPlugin.java`, `JarvisBackgroundPlugin.java` | Módulos no código; qualidade acústica, permissões e estabilidade exigem teste físico |
| Reconhecimento da pessoa pela voz | `voz_motor.js`, `identidade.js`, `identidade_ui.js`, `pessoas.js` | Comparação de perfil vocal heurística; não é biometria certificada nem prova segura de identidade |
| Palavra de ativação / segundo plano | `JarvisAtivacao.java`, `JarvisService.java`, `JarvisBootReceiver.java`, `JarvisWakeBus.java`, `JarvisWatchdog.java` | Implementação Android condicionada a permissões, notificações, bateria e políticas do fabricante; tela bloqueada/Doze pendentes |
| Pessoas, fotos e perfis | `pessoas.js`, `identidade.js`, `identidade_ui.js`, `tests/test_pessoas.js`, `tests/test_pessoas_ui.py` | Cadastro e gestão no código; reconhecimento facial/voz deve ser testado com amostras reais e consentidas |
| Memória e Obsidian | `memoria.js`, `app.js`, `platforms/desktop/main.js` | Ponte Markdown e seleção de cofre previstas no código; sincronização e permissões de pasta precisam ser verificadas em cada plataforma |
| Arquivos e desenvolvimento | `arquivos_dev.js`, `pc.js`, `platforms/desktop/arquivos.js` | Ferramentas de análise/edição no código; testar arquivos grandes, permissões e operações de gravação |
| CADe_SIMU / .cad | `cad.js`, `cad_projeto.js`, `CAD-MOBILE.md`, `platforms/desktop/cad_pc.js` | Mobile prepara, cria, analisa e envia/exporta; não promete executar CADe_SIMU no telefone. Execução depende do software no PC |
| Visão e câmera | `visao.js`, integração em `app.js` | Interface e análise no código; câmera, vídeos, sobreposição e permissões dependem do dispositivo |
| Rotinas, agentes e planos | `agentes.js`, `sistema.js`, `plano.js`, `core.js`, `core_ui.js` | Planejamento supervisionado e recibos no código; cada ação depende de executor e permissão reais |
| Segurança e privacidade | `JarvisSeguranca.java`, `app.js`, cofre de chaves e confirmações | Controles no código; PIN, biometria, exclusão e armazenamento seguro precisam de validação prática |
| Tela de bloqueio opcional | fluxo de segurança em `app.js` e painel de configurações | Deve permanecer opção em Ajustes > Segurança; não converter em bloqueio obrigatório |
| Personalidade e humor | `humor.js`, prompt/persona em `app.js` | Regras no código; avaliar conversas reais, mantendo prioridade da tarefa e sem piadas em emergência |
| Windows | `platforms/desktop/main.js`, `preload.js`, `pc.js` | Aplicativo Electron e ferramentas PC no código; instalador e funções específicas precisam de teste em Windows real |
| Alarmes no Windows | módulo Android `JarvisAlarmScheduler.java`; agenda desktop deve ser conferida separadamente | Não considerar resolvido sem demonstração de alarme funcionando no Windows |
| Atualização e diagnóstico | `JarvisUpdatePlugin.java`, `app.js`, `core.js` | Verificações no código; publicação, assinatura, atualização e recuperação devem ser testadas com Release válida |

## Pontos que NÃO podem ser declarados concluídos ainda

1. Teste no Poco X7 real (Android 16 / HyperOS), incluindo uso prolongado, alternância entre áreas, câmera, voz, aquecimento e retorno do segundo plano.
2. Teste de wake word com tela bloqueada, economia de bateria e remoção dos recentes; o fabricante pode encerrar serviços.
3. Qualidade de voz em ambiente silencioso e ruidoso, falsos positivos/negativos e comparação entre diferentes locutores.
4. Compatibilidade e desempenho de cada modelo local, em especial Gemma 3 1B IT.
5. Fluxo real de escolha do cofre Obsidian, leitura/gravação de notas e persistência após reiniciar em Android e Windows.
6. Cadastro/edição/exclusão de pessoas e teste de fotos/voz; comparação de locutor não deve desbloquear operações críticas sozinha.
7. Abrir, modificar, validar e exportar arquivos .cad no desktop e transferi-los para o CADe_SIMU; validar formatos CAD externos.
8. Alarmes e tarefas agendadas na versão Windows instalada.
9. Teste manual de todos os botões e caminhos de navegação; testes estáticos não substituem clique real.
10. Build Release assinado e instalação/atualização sem desinstalar dados do usuário.

## Testes automatizados
A suíte `npm run test:all` contém verificações de sintaxe, navegação responsiva, painel, voz, pessoas, memória, CAD, Windows, segundo plano, agentes, Core e contratos de versões. A execução Android API 35 anterior aprovou compilação, instalação, abertura e permanência do processo no emulador; isso não equivale a validação em aparelho físico.

## Regra para encerrar a auditoria
Só marcar um item como **validado** quando houver teste reproduzível com resultado e evidência. Quando a função depender de API, permissão, serviço ou aplicativo externo, registrar a dependência e o resultado separado. Não remover módulos, botões, áreas, o modo de tela de bloqueio opcional, nem a opção de Obsidian em Ajustes > Memória para “simplificar” a interface.
