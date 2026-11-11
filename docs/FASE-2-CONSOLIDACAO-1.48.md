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
- [ ] Avançar para as integrações prioritárias: memória/Obsidian, arquivos/sandbox, visão, pessoas e CADeSIMU.
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
