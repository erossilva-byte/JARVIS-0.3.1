# Auditoria técnica — J.A.R.V.I.S. Nova 1.2.7

Data da revisão: 2026-10-16
Fonte revisada: `JARVIS-NOVA-1.2.7-fonte-revisada.zip` (52 arquivos de projeto; aproximadamente 401.100 bytes descompactados).
APK conferido: `app-debug.apk`, 73.806.412 bytes.

## Resultado confirmado

- `npm run test:all`: aprovado nesta revisão.
- Sintaxe JavaScript e scripts Python: aprovados.
- Validação estática do HTML, IDs, recursos, identidade, versão e estrutura: aprovada.
- Testes do patch Gradle, JitPack e API mínima: aprovados.
- Integridade do ZIP da fonte e do ZIP de artefato: aprovada.
- GitHub Actions run `38973408843`: `success`; o APK debug de referência foi gerado e o artefato está disponível no repositório. Essa compilação precede a correção final de apresentação da bateria feita nesta fonte revisada.
- SHA-256 do APK: `bcec4f65593abd9a5084610e30cbb1b370c018c9946f7e9e2126334b54f4925f`.
- O arquivo `VERSAO.json`, este relatório, o README e o checklist foram atualizados para remover a informação obsoleta de que o APK ainda não havia sido compilado. Também foi corrigido o comando de status do aparelho, que podia falar “-1%” quando o Android não disponibilizava a leitura da bateria; agora informa “indisponível” e não afirma o estado de carga nesse caso. Como essa alteração no código foi feita após a compilação de referência, é necessária uma nova execução do workflow para incluí-la no APK.

## Escopo da revisão

Foi corrigido um defeito de apresentação confirmado por leitura de código: o comando falado de estado do aparelho tratava `bateria = -1` como uma leitura válida e podia dizer “Bateria: -1%”. Agora valida o valor numérico antes de formar a resposta, e há teste de regressão estático para esse caso.

Foram examinados os arquivos de interface (`index.html`, `style.css`), lógica (`app.js`, `apps.js`), aplicação desktop (`main.js`, `preload.js`), configuração (`package.json`, `capacitor.config.json`, `VERSAO.json`), patches Python, testes, workflow e fontes Java nativas para Android: atividade principal, plugin utilitário, plugin de voz/segundo plano, serviço, alarmes, receiver de inicialização e listener de notificações. Os relatórios históricos foram comparados para identificar afirmações desatualizadas.

## Limitações funcionais confirmadas pela própria fonte

1. **Wake word:** o modelo incluído detecta “Hey Jarvis”, não a palavra “Jarvis” isolada em português. A integração nativa do detector é gerenciada pelo plugin e seu ciclo de vida após encerrar a atividade/tela bloqueada ainda precisa de teste real; não se declara escuta contínua garantida.
2. **Modo offline:** comandos locais compatíveis continuam disponíveis, mas pesquisa na web e respostas dos provedores de IA exigem rede. Reconhecimento de fala local depende do serviço/modelo disponível no aparelho.
3. **Tarefas:** a lista de tarefas é local; o texto da interface informa que prazos de tarefa não criam notificações automáticas em segundo plano. Alarmes e lembretes usam caminho nativo separado.
4. **WhatsApp e mensagens:** o app abre a conversa ou prepara texto; envio, áudio e chamadas precisam ser concluídos/confirmados pelo usuário dentro do WhatsApp.
5. **Integrações Android:** leitura/resposta de notificações, contatos, alarmes exatos, microfone e serviços em segundo plano dependem de permissões, versão do Android, fabricante e suporte do app externo.
6. **Chaves de API:** no Android, o projeto usa cofre nativo cifrado pelo Android Keystore; nas plataformas desktop/web, as chaves são armazenadas no `localStorage` do perfil local e não têm a mesma proteção do cofre Android.
7. **Licença:** o modelo openWakeWord pré-treinado tem licença CC BY-NC-SA 4.0 segundo a documentação do projeto; avalie a licença antes de uso comercial/distribuição.

## O que a compilação comprova — e o que não comprova

A execução verde comprova que as etapas do workflow terminaram, que as dependências foram resolvidas e que o Gradle produziu um APK. Os testes estáticos aprovados verificam invariantes selecionados, não todas as combinações de permissões, APIs reais, áudio, rede ou UI. Não houve teste físico controlado, medição de bateria, teste de falsos acionamentos nem teste ponta a ponta de cada provedor. Portanto, não é tecnicamente correto prometer “zero erros” antes desses testes.

## Próximos testes recomendados no celular

- Instalar e abrir em Android API 26 ou superior; conferir primeira inicialização e permissões.
- Configurar e remover uma chave de API; testar chave inválida, cota excedida e fallback.
- Testar modo offline com Wi-Fi/dados desligados e confirmar que nenhum áudio é enviado ao provedor.
- Testar “Hey Jarvis” com tela ligada/bloqueada, ruído, música, pausa e retomada; observar o indicador de microfone e consumo de bateria.
- Criar/cancelar um lembrete, timer e alarme; testar permissão de alarmes exatos, reinicialização e notificações.
- Testar contatos, WhatsApp, SMS, leitura/resposta de notificação e controles de mídia somente com permissões consentidas.
- Testar layout em tela pequena, teclado aberto, modo escuro/claro e TalkBack.

## Entrega

Esta revisão corrige documentação/metadados obsoletos e o tratamento do valor de bateria indisponível no comando falado. A compilação de referência é verde, mas antecede essa última alteração; execute o workflow novamente para produzir o APK atualizado. A próxima revisão funcional deve priorizar o ciclo de vida do detector de palavra de ativação e os testes ponta a ponta no aparelho.
