# Fase 2 — Consolidação e estabilidade (linha 1.48.0)

## Base e regras de segurança

- Referência funcional histórica: tag `v1.45.0`, commit `fb444cb26babcefa7c1037d29c6b1a6437e5e8ff`.
- Base de trabalho: head da PR #9, `6875d8831a212ea31efbaef8bb796a8a7da5a0b8`, que incorpora a evolução da PR #8.
- Branch isolada: `work/1.48.0-fase2-consolidacao`.
- `main`, tag `v1.45.0`, PR #8 e PR #9 não devem ser alteradas ou mescladas automaticamente.
- Preservar os módulos legados e os serviços Android/Electron até que exista paridade funcional demonstrada.
- Picovoice está proibido. ESP32 e Home Assistant ficam fora do escopo desta sequência.
- Groq é o provedor prioritário; OpenRouter é o fallback seguinte. Credenciais não podem aparecer em logs ou mensagens de erro.
- Nenhuma tela, catálogo ou indicador visual pode ser tratado como prova de integração funcional.

## Estado inicial verificado

- PR #8: aberta, em rascunho; migração Flutter inicial e ajustes de persistência.
- PR #9: aberta, em rascunho; bridge Flutter/Kotlin e KWS sherpa-onnx.
- CI anterior aprovou builds debug Android e Windows no mesmo SHA, mas isso não comprova execução física.
- KWS sherpa-onnx está integrado ao pipeline; modelo disponível GigaSpeech é inglês e não tem precisão pt-BR validada.
- SpeechRecognizer on-device depende do pacote pt-BR instalado no Android.
- Conversa Flutter ainda usa chamada direta aos provedores; não substitui Hermes/Core nem executa ações locais.
- CADeSIMU nativo, IA local, Obsidian bidirecional, QR e paridade Windows continuam pendentes/parciais conforme a auditoria 1.47.

## Alterações da Fase 2

- [x] Criar branch de consolidação sem modificar `main` ou as PRs de origem.
- [x] Centralizar a seleção do primeiro provedor configurado em `ProviderService`, respeitando a ordem declarada (Groq, OpenRouter, Cerebras, Mistral, Gemini).
- [x] Corrigir a conversa para usar o primeiro provedor configurado tanto no envio automático da transcrição quanto no envio manual.
- [x] Preservar a transcrição e exibir erro seguro quando o cofre não puder ser acessado ou não houver provedor configurado.
- [x] Evitar envios manuais duplicados enquanto a leitura do cofre está em andamento.
- [x] Adicionar testes para prioridade Groq/OpenRouter e ausência de credenciais.
- [x] Habilitar o workflow Flutter Android/Windows para a branch de consolidação.
- [x] Executar o workflow no head atual e corrigir falhas sem remover testes ou reduzir critérios. (duas asserções obsoletas corrigidas; ver `docs/relatorios/2026-11-11_003_ci-verde-e-chave-de-release.md`)
- [x] Auditar o contrato de conversa: integrar Hermes/Core, histórico, persona/humor e roteamento de ferramentas sem permitir ações sensíveis sem confirmação. (contrato mapeado com arquivo e função; histórico passou a ir em ordem cronológica com o turno atual por último; checagem de repetição passou a comparar a fala do turno guardado, não o JSON bruto; ver `docs/relatorios/2026-11-11_006_contrato-de-conversa.md`)
- [x] Auditar persistência segura e comportamento de credenciais em Android e Windows. (chaves no AndroidKeyStore com AES-256-GCM, `safeStorage` com `0o600` e troca atômica no desktop, falha fechada sem cofre, cópia em claro removida em qualquer desfecho, PIN/recuperação em PBKDF2 120k; biometria de voz e memória continuam fora de cofre, declaradas como tal; ver `docs/relatorios/2026-11-11_007_persistencia-de-credenciais.md`)
- [x] Construir matriz de capacidades reais versus catálogo Flutter e eliminar indicadores enganosos. (`docs/MATRIZ-CAPACIDADES-FLUTTER.md`: 1 implementado, 3 parciais, 16 não migrados, 1 fora de escopo; gaveta e tarja de voz corrigidas; overflow de 68 px eliminado; ver `docs/relatorios/2026-11-11_004_matriz-capacidades-flutter.md`)
- [ ] Avançar para as integrações prioritárias: memória/Obsidian, arquivos/sandbox, visão, pessoas e CADeSIMU. (parcial em 2026-11-11: o cofre Obsidian passou a ter evidência de escrita e leitura **em disco real** para o formato por tópico, com nomes de arquivo saneados e reimportação idempotente; a nota com separador `---` no corpo, que perdia o texto seguinte na importação, foi corrigida e travada por teste; a ponte de pasta do Electron e o SAF do Android continuam sem teste; ver `docs/relatorios/2026-11-11_008_cofre-obsidian-em-disco.md`. No eixo arquivos/sandbox, o motor de arquivos do app ganhou teste de comportamento com leitura independente dos bytes (leitor de ZIP próprio com CRC recalculado e parser de CSV próprio), e as bordas do motor do PC foram conferidas com pasta temporária real — caminho fora da pasta recusado e nada criado fora da raiz; ver `docs/relatorios/2026-11-11_009_arquivos-e-sandbox.md`. No eixo visão e pessoas, a análise visual deixou de perder os atributos do objeto no registro — antes `comparar()` nunca encontrava diferença e respondia "sem dados" em qualquer uso real —, com a mesma regra da marca (sem evidência legível, atributo não é mantido) e teste travando o caso; pessoas foi sondada e não apresentou defeito; ver `docs/relatorios/2026-11-11_010_visao-e-pessoas.md`. No eixo elétrica/CADeSIMU, o checklist de intercâmbio passou a reprovar ID repetido como item próprio do checklist: antes o conjunto reprovava (`ok: false`, uma pendência) **sem nenhum item reprovado**, e o relatório imprimia "1 pendência" seguido de todas as linhas OK, sem dizer o que corrigir; ver `docs/relatorios/2026-11-11_011_cadesimu.md`)
- [ ] Documentar as diferenças de hardware e a paridade Android/Windows.

## Estado verificado (2026-11-11)

No commit `20168c8` da branch, os dois workflows passaram por inteiro:

- **CI de desenvolvimento** (run `42923146108`): job "Regressão estática e funcional automatizada" com a etapa *Executar suíte de regressão existente* verde, e job "Compilação Android real com KWS local" verde, incluindo *Compilar APK de validação* (92 s) com `compileSdk`/`targetSdk` 36, AGP 8.13.0 e Gradle 8.13.
- **Flutter native UI validation** (run `42923146213`): `flutter-android` (formato, analyze, testes, build APK debug, verificação do APK), `flutter-windows` (analyze, testes, build Windows) e o agregador `advance-gate`, todos verdes.

Falha anterior, para registro: o run `568` reprovava na suíte de regressão porque `tests/test_local_ai.py` exigia AGP 8.7.3/Gradle 8.9 e `tests/test_novos_recursos.py` exigia APK de release assinado em debug — asserções contrárias à própria Fase 2. Foram corrigidas para a nova verdade, não afrouxadas. Runs do Flutter entre `403` e `409` aparecem cancelados por concorrência (cada push cancela o anterior), não reprovados.

## Gates

### Gate A — automação

- `dart format`, `flutter analyze`, `flutter test`.
- Build APK debug e build Windows no mesmo commit.
- Job agregado deve exigir sucesso de Android e Windows.
- Suíte legada deve continuar preservada e ser executada no pipeline correspondente.

**Situação do Gate A:** atendido no commit `20168c8` (evidência acima).

### Gate B — validação funcional

- Testes físicos no Poco X7/Android 16/HyperOS serão feitos após disponibilização do APK.
- Não declarar KWS pt-BR, IA offline, Obsidian, CADeSIMU nativo ou paridade Windows concluídos sem evidência específica.
- Operações locais sensíveis exigem confirmação explícita.
- Falha ou ausência de evidência é pendência, não aprovação.

## Regra de publicação

Esta branch é de consolidação e validação. Não mesclar PRs, retirar rascunhos, publicar Release estável ou remover os módulos legados antes da aprovação dos gates aplicáveis e da validação funcional exigida.

### Ajuste 013 — interface com núcleo de reator (2026-11-12)

- [x] Criar núcleo 3D próprio em Canvas 2D, sem dependência, com malha, anéis, satélites e varredura.
- [x] Reagir ao nível do microfone (`--nv`) e aos estados já existentes do assistente.
- [x] Limitar desempenho: 60 fps, densidade 2, pausa em segundo plano, movimento reduzido.
- [x] Corrigir o núcleo que não se auto-iniciava (tentativas idempotentes) e o brilho que lavava a malha.
- [x] Aplicar pele visual nova (vidro, grade, tipografia, botões com foco visível) sem renomear identificadores.
- [x] Reorganizar a transcrição em coluna cheia, com falas em cartões.
- [x] Incluir os arquivos novos no workflow Android e no pacote Windows.
- [x] Rodar a suíte completa: `npm run test:all` exit 0, 2.353 verificações.
- [x] Revisar os quatro estados no celular (390×844 e 360×740): cores distintas por estado, sem transbordo horizontal.
- [x] Ajustar tamanhos e espaçamentos para tela pequena e corrigir o rótulo `QUICK COMMANDS` para `COMANDOS RÁPIDOS`.
- [ ] Migrar a interface para Flutter nativo (regra 15 do prompt v2) — não feito, fora desta entrega.
- [ ] Validar em aparelho físico (Gate B) — continua não feito.

Relatório: `docs/relatorios/2026-11-12_013_interface-reator.md`.

### Ajuste 014 — consumo de tokens (Fase 3 do prompt, 2026-11-12)

- [x] Auditar a central de provedores contra a Fase 3: erro, limite, failover e modelo alternativo já existiam; consumo não.
- [x] Criar módulo de conta sem rede e sem tela (`consumo_ia.js`), tolerante aos dois formatos de `usage`.
- [x] Registrar o consumo nos caminhos normal e de streaming, por provedor, com persistência local.
- [x] Pedir `include_usage` no streaming e recuar sem o campo quando o provedor recusa.
- [x] Mostrar em Ajustes ▸ IA e no diagnóstico, dizendo "não informou" quando a API não manda número.
- [x] Teste com comportamento real do módulo e verificação da ligação no app (23 verificações).
- [x] Incluir no pacote Windows e no workflow Android; suíte completa exit 0.
- [ ] Chamada real a provedor com chave do usuário — continua sem credencial neste ambiente.

Relatório: `docs/relatorios/2026-11-12_014_consumo-de-tokens.md`.

### Ajuste 015 — motor principal e alternativo (Fase 3 do prompt, 2026-11-12)

- [x] Roteador do Hermes aceita `principal` e `alternativo`, com principal na frente e alternativo em segundo.
- [x] Escolha sem chave é ignorada, repetição não duplica a fila e a visão respeita quem enxerga.
- [x] Principal escolhido continua valendo mesmo em pausa, com a reserva logo atrás.
- [x] Dois seletores em Ajustes ▸ IA, com opção automática e marcação "sem chave".
- [x] Ao salvar: valida os ids, grava e libera a pausa do motor escolhido.
- [x] Testes de comportamento do roteador (8 novas verificações) e suíte completa exit 0 (2.361).
- [x] Verificado na tela real: gravação em `jv_prov_principal`/`jv_prov_alternativo` e valores de volta ao reabrir.
- [ ] Chamada real a provedor com chave do usuário — sem credencial neste ambiente.

Relatório: `docs/relatorios/2026-11-12_015_escolha-de-provedor.md`.

### Ajuste 016 — delegação de agentes com validação (Fase 3 do prompt, 2026-11-12)

- [x] Auditar agentes: faltavam programação, engenharia e eletrônica; ações caíam em "Conversa".
- [x] Criar os três agentes e corrigir `status_dispositivo`/`acessibilidade_*` para Dispositivo.
- [x] Recibo passa a registrar quem delegou, para qual agente e em qual tarefa.
- [x] `abrirTarefa`, `recibosDaTarefa`, `verificarTarefa` e `porAgente` no módulo de agentes.
- [x] Cadeia só é `ok` com todos os elos confirmados; incerto, falho, bloqueado, cancelado ou aberto vira pendência.
- [x] Plano abre a tarefa delegada, alimenta a cadeia e não anuncia conclusão quando a validação reprova.
- [x] Diagnóstico com confirmadas/total por agente.
- [x] Testes: 75 verificações no módulo de agentes e suíte completa exit 0 (2.361).
- [ ] Plano ponta a ponta com provedor real — sem chave neste ambiente.
- [ ] Linha de diagnóstico por agente conferida na tela — coberta só por teste estático.

Relatório: `docs/relatorios/2026-11-12_016_delegacao-de-agentes.md`.

### Ajuste 017 — modo de desenvolvimento com autorização (Fase 3 do prompt, 2026-11-12)

- [x] Auditar o painel Dev. Arquivos: analisava, corrigia e criava sem nenhuma porta de autorização.
- [x] Módulo `modo_dev.js`: leitura livre, escrita com autorização ativa e prazo, operação desconhecida negada.
- [x] Toda tentativa registrada, inclusive as recusadas, com hora, operação e motivo.
- [x] Porta única no app: corrigir, criar projeto e criar arquivo passam por `devAutorizado`.
- [x] Escrita de código do próprio app bloqueada sem autorização, com explicação ao usuário.
- [x] Seção "Autorização" no painel, com estado e minutos restantes.
- [x] Testes: 18 verificações no módulo e suíte completa exit 0 (2.361).
- [x] Defeito achado na tela: a análise sobrescrevia o aviso de correção — corrigido e coberto por teste.
- [x] Telas pequenas (360×740 e 320×700): selo sobre o título e rótulo em duas linhas corrigidos; botões empilhados, sem corte e sem rolagem lateral.
- [x] Seção conferida na tela (13/11): desligado → autorizado → correção aplicada → bloqueio após encerrar.
- [ ] Edição de código pedida por IA real — sem chave de provedor neste ambiente.

Relatório: `docs/relatorios/2026-11-12_017_modo-dev-com-autorizacao.md`.

### Ajuste 018 — painéis em telas pequenas (2026-11-13)

- [x] Auditar os painéis em 360×740 e 320×700 medindo borda, corte, sobreposição e toque.
- [x] Utilidades: abas voltaram a filtrar (display:grid vencia `hidden`) — as sete seções apareciam juntas.
- [x] Utilidades: respiro lateral nas seções e abas que não encolhem nem transbordam.
- [x] Pessoas: "Identificação e reconhecimento" não quebra mais no meio da palavra.
- [x] Selo do cabeçalho com largura do próprio texto, em todos os painéis.
- [x] Resultado medido: 0 elementos fora da borda, 0 textos cortados, 0 sobreposição, 0 rolagem lateral.
- [ ] Aparelho físico — Gate B continua não feito.
- [ ] Estados com listas cheias (muitas tarefas/perfis) não foram testados.

Relatório: `docs/relatorios/2026-11-13_018_paineis-em-telas-pequenas.md`.

### Ajuste 019 — Fase 4: atividade de voz e barge-in (2026-11-13)

- [x] Módulo `escuta_voz.js`: dBFS, pico, piso de ruído adaptativo, confirmação de 120 ms e cauda de 500 ms.
- [x] Regra de barge-in (fala sustentada ≥ 300 ms) testada com sinais sintéticos.
- [x] Barge-in ligado no `falar()` com cancelamento de eco; microfone fechado no `finally`.
- [x] Medição real de microfone (3 s) com veredito honesto e caminho de erro.
- [x] Interruptor persistente "Interromper a resposta quando eu começar a falar".
- [x] Testes: 22 verificações próprias e suíte completa exit 0 (o `test_escuta.js` original segue passando).
- [ ] Voz e TTS reais: este ambiente não tem microfone.
- [ ] KWS sherpa-onnx, serviço de microfone em primeiro plano e Fase 4B: bloqueados sem SDK Android e aparelho.

Relatório: `docs/relatorios/2026-11-13_019_fase4-vad-e-barge-in.md`.

### Ajuste 020 — cabeçalho do cartão do núcleo (2026-11-13)

- [x] Corrigir a sobreposição entre "APARÊNCIA DO NÚCLEO" e "Estilo do núcleo central" em 360 px.
- [x] Medir de novo em 360×740 e 320×700: sem sobreposição, sem corte, sem rolagem lateral.
- [ ] Aparelho físico — Gate B continua não feito.

Relatório: `docs/relatorios/2026-11-13_020_cabecalho-do-nucleo.md`.

### Preparação da Fase 4B (2026-11-13)

- [x] Auditar o que já existe no Android: serviço de microfone, KWS sherpa-onnx, notificação, pausa em chamada/mídia, vigia de 15 min, boot a 20 s, lembretes por `AlarmManager`, diagnóstico real.
- [x] Registrar as lacunas da Fase 4B: ação Pausar na notificação, perfis de energia, WorkManager, fone/microfone disputado, botão "Por que parou?".
- [x] Escrever o passo a passo no Poco X7 (permissões, HyperOS, bateria, sobreposição) e os testes A–E com metas.
- [x] Ficha de medição pronta para preencher.
- [ ] Nada medido em hardware: sem Android SDK e sem aparelho.

Documentos: `docs/FASE-4B-PLANO-APARELHO.md` e `docs/FASE-4B-FICHA-MEDICAO.md`.

### Ajuste 021 — botão "Por que parou?" (Fase 4B, 2026-11-13)

- [x] Módulo `segundo_plano.js`: causa mais provável primeiro, sem inventar quando não sabe.
- [x] Botão na seção Segundo plano lendo o diagnóstico nativo que já existia.
- [x] No navegador/desktop o botão diz que o serviço só existe no APK Android.
- [x] Testes: 14 verificações e suíte completa exit 0.
- [ ] Resposta real no APK: sem SDK e sem aparelho.

Relatório: `docs/relatorios/2026-11-13_021_por-que-parou.md`.

### Ajuste 022 — pausa e perfis de energia (Fase 4B, 2026-11-13)

- [x] Ação Pausar/Retomar na notificação, com pausa persistida e vencendo vigia e recentes.
- [x] Quatro perfis: Sempre ouvindo, Somente carregando, Horários definidos, Desligado.
- [x] Checagem dentro de `iniciarMotor`, então o microfone não abre fora do perfil.
- [x] Tela com seletor, janela de horário e estado; plugin expõe leitura e aplicação.
- [x] 15 + 16 verificações e suíte completa exit 0.
- [ ] Compilar no CI e medir no Poco X7: sem SDK e sem aparelho aqui.

Relatório: `docs/relatorios/2026-11-13_022-pausar-e-perfis-de-energia.md`.

### Ajuste 023 — redução por bateria (Fase 4B, 2026-11-13)

- [x] Bateria em 15% ou menos, sem carregador: microfone não abre.
- [x] Economia de energia do sistema reduz a escuta mesmo com bateria cheia.
- [x] Retomada automática ao carregar ou desligar a economia, pelo laço já existente.
- [x] Diagnóstico, resumo do perfil e "Por que parou?" explicam a redução.
- [x] 17 + 17 verificações e suíte completa exit 0.
- [ ] Compilar no CI e medir no Poco X7.

Relatório: `docs/relatorios/2026-11-13_023-reducao-por-bateria.md`.

### Ajustes 024 e 025 — limite escolhível e WorkManager (Fase 4B, 2026-11-13)

- [x] Limite de redução por bateria em 10%, 15% (padrão) ou 20%, aplicado pelo serviço.
- [x] Manutenção periódica com WorkManager (6 h, sem bateria baixa, trabalho único).
- [x] Agendada ao ligar a escuta e depois do reinício; restaura lembretes e vigia.
- [x] Diagnóstico e tela mostram a última verificação e permitem rodar agora.
- [x] Dependência `androidx.work` injetada pelo `patch_gradle.py`; workflows copiam a classe.
- [x] 20 + 9 verificações e suíte completa exit 0.
- [ ] Compilar no CI e medir no Poco X7.
- [ ] Rotinas em segundo plano: fora de escopo — Worker não executa JavaScript.

Relatórios: `docs/relatorios/2026-11-13_024-limite-de-bateria-configuravel.md` e
`docs/relatorios/2026-11-13_025-workmanager-manutencao.md`.

### Ajuste 026 — fone e microfone disputado (Fase 4B, 2026-11-13)

- [x] Fone desconectado pausa a escuta e ela volta em 5 s.
- [x] Outro app gravando impede abrir o microfone e pausa a sessão em curso.
- [x] Retomada automática quando o microfone fica livre.
- [x] "Por que parou?" explica as duas causas.
- [x] 9 + 17 verificações e suíte completa exit 0.
- [ ] Compilar no CI e medir no Poco X7 (o aviso de fone varia por fabricante).

Relatório: `docs/relatorios/2026-11-13_026-fone-e-microfone-disputado.md`.

### Ajuste 027 — microfone em tempo real (Fase 4B, 2026-11-13)

- [x] Linha na tela mostra outro app no microfone, pausa do fone, escuta ativa ou serviço parado.
- [x] Consulta a cada 2,5 s, encerrada ao sair da aba ou com o painel oculto.
- [x] Alerta visual quando o microfone está em uso por outro app.
- [x] 12 verificações e suíte completa exit 0.
- [ ] Ver no Poco X7 com o gravador de voz do sistema.

Relatório: `docs/relatorios/2026-11-13_027-microfone-em-tempo-real.md`.

### Ajuste 028 — verificação de privacidade (Fase 4B, 2026-11-13)

- [x] Auditoria estática: detector, serviço e captura JS sem cliente de rede; `disparar()` sem envio.
- [x] Contador `TrafficStats` do app exposto no diagnóstico, com "-1" quando indisponível.
- [x] Tela mostra a auditoria; módulo nunca transforma desconhecido em zero.
- [x] Roteiro com quatro provas e critérios de falha.
- [x] 11 verificações e suíte completa exit 0.
- [ ] Provas 2–4 no Poco X7 (contador ocioso, modo avião, captura externa).

Relatório: `docs/relatorios/2026-11-13_028-verificacao-de-privacidade.md`.

### Ajuste 029 — fechamento da Fase 4B (2026-11-13)

- [x] `ci/preflight_android.py`: classes, referências, WorkManager, manifesto, pacote e testes.
- [x] Passo de pré-checagem nos quatro workflows que compilam APK.
- [x] Teste negativo comprova que a pré-checagem pega classe fora da lista.
- [x] `docs/FASE-4B-ACEITE.md` com situação por requisito, checklist de 10 medições e riscos abertos.
- [x] Suíte completa e empacotamento exit 0.
- [ ] CI compilar o APK com as classes novas.
- [ ] Ficha de medição preenchida no Poco X7.

Relatório: `docs/relatorios/2026-11-13_029-fechamento-fase-4b.md`.

### Ajuste 030 — revisão de compilação do Java (2026-11-13)

- [x] Detecção de microfone ocupado corrigida: sessão do `AudioRecord` em vez de nome de pacote.
- [x] Pausa manual vence o aviso de fone; teste só anuncia "diga Jarvis" com captura ativa.
- [x] Worker limitado a duas tentativas por ciclo; `kwsEngine` volátil.
- [x] `docs/REVISAO-JAVA-COMPILACAO.md` com defeitos, riscos de API e ciclo de vida.
- [x] Relatórios 026 e 027 corrigidos quanto ao nome do pacote.
- [x] Suíte completa, pré-checagem e empacotamento exit 0.
- [ ] CI compilar (riscos de API anotados na revisão).

Relatório: `docs/relatorios/2026-11-13_030-revisao-java.md`.

### Ajuste 031 — pré-checagem de APIs e permissões (2026-11-13)

- [x] Registro de 8 APIs que exigem permissão de sistema; uso novo reprova até revisão.
- [x] Permissão usada no Java precisa estar declarada no manifesto.
- [x] Permissão de sistema no manifesto reprova (declarar não concede).
- [x] Três testes negativos comprovam que cada checagem reprova de verdade.
- [x] Suíte, pré-checagem e empacotamento exit 0.

Relatório: `docs/relatorios/2026-11-13_031-preflight-permissoes.md`.

### Ajuste 032 — pré-checagem na suíte local (2026-11-13)

- [x] `npm run test:all` começa pela pré-checagem Android; falha ali para a suíte.
- [x] Teste de empacotamento garante que o passo continua na suíte.
- [x] Teste negativo: permissão de sistema injetada faz `npm run test:all` sair 1 na hora.
- [x] Suíte completa exit 0 depois da restauração.

Relatório: `docs/relatorios/2026-11-13_032-preflight-na-suite.md`.

### Ajuste 033 — comando único de verificação (2026-11-13)

- [x] `npm run verificar` roda pré-checagem, suíte e empacotamento e imprime resumo legível.
- [x] Etapas continuam após falha; código de saída diferente de zero se qualquer uma falhar.
- [x] Teste negativo: defeito injetado aponta "2 de 3" e mostra a saída da etapa reprovada.
- [x] Teste de empacotamento garante que o comando existe e aponta para o script.
- [x] `npm run verificar` exit 0 — 3 de 3 etapas.

Relatório: `docs/relatorios/2026-11-13_033-comando-de-verificacao.md`.

### Ajuste 034 — revisão do Java de música, acessibilidade, atualização e voz (2026-11-13)

- [x] `MediaPlayer` liberado quando o arquivo é inválido.
- [x] Player de música encerra quando não consegue primeiro plano (sem crash de FGS).
- [x] Acessibilidade fora da thread da interface (fim do risco de ANR em `esperar`).
- [x] Motor de voz não é liberado durante a síntese nativa.
- [x] `InputStream` do download fechado em `finally`.
- [x] `npm run verificar` exit 0 — 2364 verificações, 3 de 3 etapas.
- [ ] CI compilar e aparelho medir (riscos listados na revisão).

Relatório: `docs/relatorios/2026-11-13_034-revisao-java-restante.md`.

### Ajuste 035 — plugins restantes e regra de primeiro plano (2026-11-14)

- [x] NFC cancela a promessa pendente ao destruir o plugin.
- [x] Listener de notificações remove entradas e limpa a lista no destroy.
- [x] Watchdog não desfaz mais a pausa manual.
- [x] Cofre e contatos fora da thread principal (executor `fundo`), com streams em `finally`.
- [x] Pré-checagem reprova `startForeground` com falha engolida; teste negativo confirmado.
- [x] `npm run verificar` exit 0 — 2364 verificações, 3 de 3 etapas.
- [ ] CI compilar e aparelho medir.

Relatório: `docs/relatorios/2026-11-14_035-plugins-restantes-e-primeiro-plano.md`.

### Fase 5 — ensaio do Gate A (2026-11-14)

- [x] `ci/rehearsal_gate_a.py`: patch aplica no `HEAD` limpo e reconstrói os arquivos.
- [x] Defeito real encontrado: `modo_dev.js` e dois testes novos fora do patch; corrigido.
- [x] Pré-checagem aprovada no código vindo do patch.
- [ ] CI compilar (`assembleDebug`) — Gate A.
- [ ] Aparelho medir — Gate B.

Documento: `docs/GATE-A-ENSAIO-DO-PATCH.md`.
Relatório: `docs/relatorios/2026-11-14_036-fase-5-ensaio-do-patch.md`.

### Ajuste 037 — ensaio do patch no GitHub Actions (2026-11-14)

- [x] `ci/rehearsal_gate_a.py --aplicar`: aplica no checkout e roda a pré-checagem.
- [x] Passo antes da compilação em `build-apk.yml`, `ci.yml` (2 trabalhos) e `release-apk.yml`.
- [x] Sem patch na raiz, o passo avisa e segue (fluxo normal intacto).
- [x] `*.patch` na raiz dispara o workflow de build.
- [x] Teste negativo: patch inválido reprova antes de compilar.
- [ ] CI compilar (`assembleDebug`) — Gate A.

Relatório: `docs/relatorios/2026-11-14_037-ensaio-no-workflow.md`.

### Ajuste 038 — início da Fase 5: interface nativa (2026-11-14)

- [x] Pré-checagem da interface: reprova WebView, HTML embutido e pacote de webview.
- [x] Navegação confere as doze seções pedidas; Segurança e Personalização entraram.
- [x] Animação reduzida respeitada; núcleo isolado com `RepaintBoundary`.
- [x] Etapa própria no `npm run verificar` e no `npm run test:all`, com teste negativo.
- [x] `npm run verificar` exit 0 — 4 de 4 etapas, 2365 verificações.
- [ ] `flutter analyze`, teste de widget e medição de fps (sem SDK aqui).

Documento da fase: `docs/FASE-5-INTERFACE.md`.
Relatório: `docs/relatorios/2026-11-14_038-fase-5-interface.md`.

### Ajuste 039 — núcleo de streaming da conversa (2026-11-14)

- [x] `StreamBuffer` em Dart puro: agrupa tokens e entrega no máximo a cada 32 ms.
- [x] Teste executável sem Flutter (`dart run tool/stream_buffer_test.dart`), 5 casos.
- [x] Passo `tests/test_dart_core.py` na suíte local e no workflow nativo.
- [x] Sintaxe dos 20 arquivos Dart conferida com `dart format --output=none`.
- [ ] Ligar o buffer à tela de conversa (Fase 5).
- [ ] `flutter analyze` e `flutter test` (CI).

Relatório: `docs/relatorios/2026-11-14_039-nucleo-de-streaming.md`.

### Ajuste 040 — conversa em streaming, parar e estados (2026-11-14)

- [x] Parser SSE em Dart puro, tolerante a linha cortada, com teste (`tool/sse_test.dart`).
- [x] `ProviderService.streamComplete` cancelável; botão de parar mantém o texto recebido.
- [x] Estados vazio, processando e erro com “tentar de novo” na conversa.
- [x] Campo `fontes` preparado; memória da Fase 7 é quem vai preencher.
- [x] `npm run verificar` exit 0 — 4 de 4 etapas.
- [ ] `flutter analyze`, `flutter test` e medição no aparelho.

Relatório: `docs/relatorios/2026-11-14_040-conversa-em-streaming.md`.
Entrega da fase: `docs/FASE-5-ACEITE.md`.

### Ajuste 041 — fecha os itens abertos da Fase 5 (2026-11-14)

- [x] Flutter 3.50 instalado em pasta temporária: `flutter analyze` e `flutter test` rodaram.
- [x] Migração para `material_ui` (depreciação do `flutter/material.dart` no 3.50): 0 problemas.
- [x] Histórico de conversas com busca, fixar, apagar e nova conversa, persistido localmente.
- [x] Rascunho restaurado; conversa salva a cada mensagem.
- [x] Modo voz em tela cheia com estado real do KWS e legendas.
- [x] Regenerar resposta e copiar; atalho de tela cheia na tela principal.
- [x] `npm run verificar` exit 0 — 4 de 4 etapas; 36 testes de widget, 2.368 verificações.
- [ ] Integração com o sistema Android (atalhos, widget, compartilhar) e medição no Poco X7.

Relatório: `docs/relatorios/2026-11-14_041-fechamento-fase-5.md`.
Entrega: `docs/FASE-5-ACEITE.md`.

### Ajuste 042 — integração com o sistema Android (2026-11-14)

- [x] Atalhos estáticos do ícone: falar, nova conversa e histórico.
- [x] Widget da tela inicial com estado real do KWS e dois botões.
- [x] Receber texto de outros apps (ACTION_SEND) e compartilhar a conversa.
- [x] Canal `com.jarvis.nova/sistema` ligado ao Flutter (intenção pendente + eventos).
- [x] Script de preparação idempotente do runner e 5 testes com runner falso.
- [x] 43 testes de widget e 7 casos Dart novos para as intenções.
- [ ] Compilar o APK no CI e testar atalhos/widget/compartilhar no Poco X7.

Relatório: `docs/relatorios/2026-11-14_042-integracao-android.md`.

### Ajuste 043 — workflow confere o APK e testa a preparação (2026-11-14)

- [x] Simulação do runner gerado pelo Flutter com os dois scripts de preparação: manifesto íntegro.
- [x] Workflow roda o teste da integração antes do build.
- [x] Workflow confere, no APK, atalhos, widget, filtro de compartilhamento e canal do sistema.
- [x] Fallback do aapt2 corrigido para `pipefail`; conferência olha todos os `classes*.dex`.
- [x] `pubspec.yaml` declara `flutter: ">=3.47.0"` (exigência do `material_ui`).
- [x] Teste do workflow com cinco mutações; suíte com 2.372 verificações.
- [ ] Primeira compilação real do APK no CI e teste no Poco X7.

Relatório: `docs/relatorios/2026-11-14_043-revisao-workflow-apk.md`.

### Ajuste 044 — medição de abertura, fps e travadas (2026-11-14)

- [x] Roteiro de medição com comandos `adb`, metas provisórias e ficha para preencher.
- [x] Trecho de cálculo de fps/p95 conferido com amostra sintética (60 fps, p95 17,8 ms).
- [ ] Rodar no Poco X7: abertura fria/morna, 60 s parado, 60 s de uso e modo voz.

Relatório: `docs/FASE-5-MEDICAO-APARELHO.md`.

### Ajuste 045 — Fase 6: memória local e citação (2026-11-14)

- [x] Cofre local de notas com Markdown, frontmatter e chaves desconhecidas preservadas.
- [x] Importação com repetição e conflito sem sobrescrita.
- [x] Busca lexical determinística com motivo, orçamento e corte relativo.
- [x] Notas relevantes entram no envio como sistema; `fontes` mostra “O que lembrei”.
- [x] Tela de memória: lista, busca, editor, exclusão, cópia e importação de Markdown.
- [x] 10 testes novos (cofre + widget), análise limpa, suíte 4 de 4.
- [ ] Cofre via SAF, sincronização Obsidian e versionamento de nota (pendência 7B).

Aceite: `docs/FASE-6-ACEITE.md`. Relatório: `docs/relatorios/2026-11-14_045-memoria-local.md`.

### Ajuste 046 — Fase 6: pasta do Obsidian via SAF (2026-11-14)

- [x] Canal `com.jarvis.nova/memoria` com escolher, consultar, listar e esquecer pasta.
- [x] Permissão durável (`takePersistableUriPermission`) reconferida a cada abertura.
- [x] Leitura recursiva só de `.md`, com limites de notas, profundidade e bytes.
- [x] Tela: conectar pasta, importar notas, desconectar; importação usa repetição/conflito.
- [x] 6 testes Dart com canal simulado e verificação estática do Kotlin na suíte.
- [x] Conferência do APK passou a exigir o canal de memória no dex.
- [ ] Compilar no CI e abrir o seletor no Poco X7; sincronização bidirecional continua fora.

Relatório: `docs/relatorios/2026-11-14_046-cofre-saf.md`.

### Ajuste 047 — Fase 6: sincronização nos dois sentidos (2026-11-15)

- [x] Núcleo puro decide enviar, receber, adotar caminho ou conflitar pelo hash do corpo.
- [x] Escrita na pasta via SAF (`openOutputStream` truncando, `createDocument` para novo e subpastas).
- [x] Permissão de escrita pedida; pasta só de leitura fica visível e sem botão ativo.
- [x] Nenhuma ação de apagar: conflito preserva os dois lados; arquivo sumido vira “só neste aparelho”.
- [x] 13 casos puros, 8 testes de serviço com cofre falso e 2 de widget; 69 testes no total.
- [ ] Compilar e sincronizar num aparelho real; resolução assistida de conflito continua fora.

Relatório: `docs/relatorios/2026-11-15_047-sincronizacao-obsidian.md`.

### Ajuste 048 — Fase 6: sincronização automática e fechamento (2026-11-15)

- [x] Sincroniza ao abrir o app e ao voltar do segundo plano, em silêncio.
- [x] `resumed` repetido sem saída não dispara sincronização; uma por vez.
- [x] Conectar pasta já sincroniza; conflito fica sinalizado no cartão, sem diálogo automático.
- [x] 2 testes de widget com ciclo de vida real; 70 testes no total.
- [x] Fase 6 fechada no código; resta o ensaio no aparelho (Gate B).
- [ ] Busca semântica neural e versionamento de nota continuam fora, declarados.

Relatório: `docs/relatorios/2026-11-15_048-sincronizacao-automatica.md`.

### Ajuste 049 — Fase 6: tela de resolução de conflito (2026-11-15)

- [x] Tela com as duas versões (aparelho × pasta), texto selecionável, lado a lado quando cabe.
- [x] Escolha confirmada; perdedora vira nota de backup sem caminho — nada é apagado.
- [x] Escolher o aparelho grava na pasta antes; falha de escrita não altera nada.
- [x] Backup com id estável; próxima sincronização o envia como arquivo novo.
- [x] 1 caso puro (5 verificações), 3 testes de serviço e 1 de widget; 74 no total.
- [ ] Ensaio visual no aparelho e gestão de backups continuam fora.

Relatório: `docs/relatorios/2026-11-15_049-resolver-conflitos.md`.

### Ajuste 050 — Fase 6: gestão dos backups de conflito (2026-11-15)

- [x] Tela “Backups de conflito” com atalho e contador na tela de memória.
- [x] Abrir, restaurar como nota normal, apagar um e apagar todos — sempre com confirmação.
- [x] Marca `origem: backup-conflito`; backups antigos reconhecidos pelo prefixo do id.
- [x] Exclusão só no aparelho; a pasta do Obsidian não é alterada.
- [x] 5 testes de widget; 79 no total.
- [ ] Inspeção visual no aparelho e expurgo automático continuam fora (expurgo não é desejado).

Relatório: `docs/relatorios/2026-11-15_050-backups-de-conflito.md`.

### Ajuste 051 — Fase 7: fichas de pessoas (2026-11-15)

- [x] Ficha local com os campos pedidos; nome e consentimento obrigatórios.
- [x] Criar, editar, buscar, consultar e excluir com confirmação; nada é inventado.
- [x] Dois “João” viram ambiguidade; nomes parecidos não são fundidos.
- [x] Armazenamento seguro no aparelho, 50 fichas / 64 kB, falha informada.
- [x] Contexto para a IA sem contato, observação, compromisso ou histórico.
- [x] 1 teste puro, 5 de widget e 1 estático de privacidade; menu abre a tela real.
- [ ] Foto/reconhecimento facial, histórico automático e uso na conversa continuam fora.

Relatório: `docs/relatorios/2026-11-15_051-fichas-de-pessoas.md`.

### Ajuste 052 — Fase 7: pessoas na conversa (2026-11-15)

- [x] Pergunta que cita pessoa envia bloco seguro como mensagem de sistema.
- [x] Bloco só com nome, apelido, relação e preferências; contato/anotação/compromisso/histórico fora.
- [x] Nome ausente instrui “diga que não encontrou; não invente”.
- [x] Ambiguidade manda perguntar qual; nome completo vence primeiro nome.
- [x] 9 grupos de teste puro e verificação estática do envio; conversa sem chave real segue não provada.
- [ ] Resposta real do modelo e bloco no aparelho continuam dependentes de chave/CI.

Relatório: `docs/relatorios/2026-11-15_052-pessoas-na-conversa.md`.

### Ajuste 053 — Fase 7: transparência das fichas na conversa (2026-11-15)

- [x] Cada resposta guarda o bloco de pessoas **exatamente** como foi enviado e os nomes citados.
- [x] A bolha mostra “Ficha usada: Ana”, “Fichas citadas: …” ou “Fichas: nenhuma correspondência”.
- [x] O bloco abre por toque e aparece literal, sem resumo — é o mesmo texto que o provedor recebeu.
- [x] Bloco e fichas sobrevivem a salvar/reabrir a conversa; conversa antiga sem esses campos continua válida.
- [x] 3 testes de widget, 11 grupos puros e estático ampliado; 87 testes no total.
- [ ] Inspeção visual da bolha em tela estreita e resposta real do modelo continuam fora.

Relatório: `docs/relatorios/2026-11-15_053-transparencia-das-fichas.md`.
