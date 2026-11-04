# Checklist de teste — J.A.R.V.I.S. Nova 1.1.0

## Testes automatizados no projeto-fonte
- [x] JavaScript: `npm run test:syntax` passou no ambiente de preparação.
- [x] Validar o projeto completo: `npm run test:all` passou (sintaxe, invariantes de HTML/ID/versão e compilação dos scripts Python).
- [ ] Compilar Android em ambiente com SDK: `./gradlew assembleDebug` ou GitHub Actions.
- [x] Conferir por fixture de teste versionName `1.1.0`, versionCode `1100`, ícone adaptativo e splash (gerados a partir de recursos Android simulados).

## Verificações manuais no app instalado
- [ ] Instalar junto ao APK antigo; confirmar que os dois ícones aparecem e ambos abrem.
- [ ] IA: testar uma pergunta comum com Groq e uma chave alternativa.
- [ ] Pesquisa web: usar notícia recente; verificar título, domínio, resumo, data apenas quando presente, URL e aviso de validação.
- [ ] Pesquisa atual: provocar falha de rede e confirmar que o app não apresenta Wikipédia como se fosse notícia atual.
- [ ] Contexto: alternar “Contexto da conversa” e confirmar que uma pergunta subsequente não recebe o histórico quando desativado.
- [ ] Memória: adicionar item manual, salvar, testar memória global e o controle por conversa em estados ligados/desligados.
- [ ] Reinicialização: agendar dois lembretes futuros, reiniciar o telefone e confirmar restauração; cancelar outro e confirmar que não volta a ser agendado; verificar que alarmes já vencidos com o telefone desligado não disparam atrasados.
- [ ] Microfone: testar ambiente silencioso e ruidoso; conferir nível, ruído-base, pico, sensibilidade e permissões.
- [ ] Wake word: pausar e reativar pelo botão rápido; testar no Android físico, com tela ligada, bloqueada e app em segundo plano. Remover o app dos recentes e confirmar se o serviço/notificação permanece; repetir em modo de economia de bateria.
- [ ] Rotinas: criar, reordenar, editar, excluir; testar ações com e sem argumentos; confirmar limite de 8 ações/rotina e 20 rotinas.
- [ ] Privacidade: apagar histórico/memória/registros; confirmar que chaves permanecem somente quando esse fluxo é escolhido; testar apagar cada chave separadamente.
- [ ] Diagnóstico: rodar com/sem chave, com internet desligada e após negar permissão do microfone.
- [ ] Segurança: confirmar que modo seguro vem ligado e ações críticas continuam exigindo confirmação/PIN.

## Separação das verificações
A validação integral local passou. A instalação das dependências e a compilação Android não foram aprovadas: a tentativa de baixar dependências falhou por indisponibilidade de DNS (`EAI_AGAIN` para registry.npmjs.org), e este ambiente não possui Android SDK, projeto Android gerado ou Gradle wrapper. A execução visual automatizada no Chromium também foi bloqueada pela política do ambiente (`ERR_BLOCKED_BY_ADMINISTRATOR`), portanto as interações ainda exigem teste externo. A compilação deve ser considerada pendente até o GitHub Actions terminar com sucesso. A versão 1.0.1 introduziu o modo de conversa ampliada; a versão 1.1.0 acrescenta comandos locais e modo offline. Esses recursos ainda precisam de teste funcional no dispositivo. Wake word, reconhecimento de voz, microfone em segundo plano e instalação lado a lado exigem um dispositivo Android real.

## Testes adicionais da versão-fonte 1.1.0

- [ ] Ativar modo offline e verificar que o chip mostra “Modo offline”.
- [ ] Com modo offline ativo, confirmar que conversa generativa, pesquisa, clima e testes de rede não chamam provedores.
- [ ] Verificar reconhecimento on-device em português sem Wi-Fi/dados móveis; se não houver pacote local, confirmar mensagem de indisponibilidade sem fallback online.
- [ ] Testar “ligar para [contato]” e confirmar que a confirmação aparece antes de abrir o discador.
- [ ] Testar “mandar SMS para [contato] dizendo [texto]”; revisar a tela de SMS e confirmar que nada é enviado automaticamente.
- [ ] Testar “mandar mensagem para [contato] dizendo [texto]”; verificar abertura do WhatsApp com texto preparado, sem envio automático.
- [ ] Conceder acesso a notificações; testar leitura dos resumos, exclusão dos resumos após leitura e ausência de leitura sem autorização.
- [ ] Testar resposta por voz somente em notificação com ação de resposta rápida; verificar confirmação antes da resposta.
- [ ] Ativar/desativar anúncio de chamadas e testar em um telefone real; comportamento varia por app de telefone.
- [ ] Testar pausar/continuar/próxima/anterior e volume em YouTube/Spotify ou app instalado.
- [ ] Testar “sair do YouTube” e “retorne para o YouTube”; confirmar que sair leva à tela inicial e não promete force-stop.
- [ ] Criar evento, conferir os dados no editor de calendário e salvar manualmente.
- [ ] Reiniciar o aparelho: verificar restauração de alarmes; confirmar se o Android exige abrir o app para reativar a escuta.
- [ ] Compilar APK no GitHub Actions e instalar/testar no aparelho antes de distribuir.


## Atualização 1.2.7 — 2026-10-16

O GitHub Actions concluiu com sucesso a compilação do APK debug (`run ID 38973408843`). O APK foi gerado e seu SHA-256 é `bcec4f65593abd9a5084610e30cbb1b370c018c9946f7e9e2126334b54f4925f`. Os parágrafos anteriores descrevem testes históricos de versões anteriores. A instalação e os testes em aparelho físico ainda não foram concluídos.

## Atualização 1.42.9 — execução local no Windows (2026-11-04)

O script oficial `npm run test:all` usa `python3` porque o CI roda em Ubuntu. No Windows, `python3` costuma ser o atalho da Microsoft Store e não executa Python, então a suíte não rodava na máquina de desenvolvimento mesmo com Python instalado.

- [x] Adicionado `npm run test:all:win`, que lê a mesma suíte de `test:all` e troca apenas a invocação do interpretador por `tests/python.js`.
- [x] `tests/python.js` resolve, nesta ordem: `JARVIS_PYTHON`, `py -3`, `python` (Windows) ou `python3`, `python` (Linux/macOS).
- [x] A suíte oficial permanece intacta, com `python3`, para o CI e para os testes históricos que conferem o registro em `test:all`.
- [x] Regressão coberta por `tests/test_runner_windows.py`, registrado na suíte.
- [x] Corrigido `tests/test_arquivos_sistema.py`: o caminho relativo do motor usa o separador da plataforma (`~\Jarvis\...` no Windows) e o teste só removia `~/`; a leitura do JSON do gerador agora é UTF-8 explícita.
- [x] Corrigido `tests/test_cad_pacote.py`: saída do gerador decodificada como UTF-8 (antes usava a página de código do Windows e quebrava em nomes acentuados).
- [x] Execução local completa: `npm run test:all:win` terminou com código 0.

O que continua sem teste local: compilação Android (exige JDK + Android SDK), microfone, câmera, NFC, biometria e segundo plano reais. Esses itens seguem dependendo do aparelho físico ou do GitHub Actions.

## Assinatura de release — 2026-11-04

O APK publicado deixou de usar a chave de debug (`ci/debug.keystore`, pública e com senha conhecida) e passou a exigir uma chave de release.

- [x] `patch_gradle.py` cria `signingConfigs.release` a partir de `JARVIS_KEYSTORE_PATH`, `JARVIS_KEYSTORE_PASSWORD`, `JARVIS_KEY_ALIAS` e `JARVIS_KEY_PASSWORD`, ou de `android/app/keystore.properties` no build local.
- [x] `release-apk.yml` compila `assembleRelease`, decodifica o keystore de `ANDROID_KEYSTORE_BASE64` e falha de propósito quando os segredos faltam.
- [x] O workflow roda `apksigner verify --print-certs` e aborta se o certificado for `CN=Android Debug`.
- [x] `JarvisUpdatePlugin` compara a assinatura do APK baixado com a instalada e explica a troca de chave antes de abrir o instalador (migração debug → release exige desinstalar uma vez).
- [x] Regressão coberta por `tests/test_release_signing.py`, registrado na suíte.
- [x] `tests/test_arquivos_sistema.py` e `tests/test_cad_pacote.py` limpam o temporário com `shutil.rmtree` em vez de `rm -rf` (que falhava no Windows).
- [x] `npm run test:all:win` terminou com código 0 após as mudanças.

Operação da chave (geração, segredos, backup e migração): `ASSINATURA-APK.md`.

O que ainda depende de execução real: compilar `assembleRelease` com a chave configurada (GitHub Actions) e validar a instalação por cima no aparelho físico.

## Preparação da 1.43.0 — 2026-11-04

- [x] Versão 1.43.0 / versionCode 10430 em `VERSAO.json`, `package.json`, `package-lock.json`, `app.js`, `index.html` e nos dois workflows.
- [x] `CHANGELOG.md` e `LEIA-ME.md` registram a 1.43.0 e a migração de assinatura.
- [x] `VERSAO.json` marca o build como `pendente`; a tag `v1.43.0` publica o primeiro APK assinado com a chave de release.
- [ ] Compilar a tag `v1.43.0` e conferir no log o SHA-256 e o certificado `CN=J.A.R.V.I.S. Nova`.
- [ ] Desinstalar a 1.42.9 de debug no aparelho e instalar a 1.43.0 por cima do sistema (uma vez).
