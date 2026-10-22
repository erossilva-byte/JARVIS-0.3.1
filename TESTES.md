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
