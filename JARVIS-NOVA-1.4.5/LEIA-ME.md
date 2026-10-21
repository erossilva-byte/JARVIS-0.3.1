# J.A.R.V.I.S. Nova 1.3.3

Evolução baseada exclusivamente no fonte 1.2.5 fornecido. Mantém o aplicativo independente com `com.jarvis.nova`.

## Destaques desta revisão

- Ativação contínua por Porcupine no aparelho, após configurar uma AccessKey Picovoice. Sem a chave, o botão de microfone continua disponível para conversas manuais.
- Mini-interface de ativação.
- Painel do celular com bateria, temperatura reportada pela bateria, armazenamento, RAM, conexão e atalhos do Android.
- Links oficiais para cadastrar chaves de IA; cotas gratuitas variam por provedor.
- Humor configurável (0–100%) e estilo de resposta equilibrado, formal, amigável ou técnico.
- Comando por voz para abrir a conversa WhatsApp de um contato cadastrado; envio de áudio e chamadas continuam sendo concluídos pelo usuário no WhatsApp.
- Atalhos para aplicativos comuns, mídia, tarefas, rotinas, alarmes e modo offline herdados da base 1.2.5.

## Gerar APK

Envie `JARVIS-NOVA-1.3.3-fonte.zip` (ou outro `JARVIS-NOVA-*-fonte.zip`) para a raiz do repositório e faça commit na `main`. O workflow de Actions executará os testes, configurará a API mínima 26 e tentará compilar o APK. Consulte `CHECKLIST-PARA-GERAR-APK-1.2.7.md`.

## Limites e privacidade

O detector precisa analisar áudio local enquanto estiver habilitado; o indicador de microfone do Android pode permanecer ativo. O Android não concede controle irrestrito de todos os apps; mensagens e chamadas continuam sujeitas a confirmação. Temperatura significa a leitura que o sistema reporta para a bateria.

## Estado real

Os testes estáticos passaram e o GitHub Actions já compilou uma versão debug 1.2.7. A revisão 1.3.3 remove a dependência openWakeWord que falhava ao resolver no CI e informa claramente que a ativação contínua exige AccessKey Picovoice; execute o workflow para gerar o APK atualizado. Instalação e funcionamento em dispositivo físico ainda precisam ser verificados. O APK debug não equivale a uma versão de produção assinada para distribuição.


### Ajustes finais antes do APK

- A biblioteca de ativação local exige Android 8.0/API 26 ou superior; o patch Gradle agora aplica esse mínimo.
- Teste automatizado confirma que o patch das dependências Porcupine/MediaPipe pode ser aplicado mais de uma vez sem duplicar entradas.
- A validação estática não substitui a compilação real nem o teste físico.

### Revisão 1.2.7

Inclui controles de humor/estilo e comando para abrir uma conversa WhatsApp com contato cadastrado. Ações de chamada, áudio e envio exigem revisão no próprio WhatsApp. Não equivale a controle irrestrito de aplicativos.

### Revisão 1.2.9

Consulte `RELATORIO-REVISAO-1.2.9.md` para a integração Porcupine e pendências. O workflow atualizado aceita `JARVIS-NOVA-*-fonte.zip`; para repositórios com workflow antigo, use também o nome legado `JARVIS-NOVA-1.2.7-fonte.zip` ou atualize o workflow manualmente.


## Segurança das chaves na versão 1.3.0
No Android, as chaves são cifradas com Android Keystore. No aplicativo desktop Electron, o `safeStorage` do sistema operacional cifra as chaves guardadas em arquivo privado do aplicativo. Se a criptografia do sistema não estiver disponível, o salvamento falha sem gravar em texto puro. O navegador comum não é recomendado para cadastrar chaves.

A AccessKey Picovoice é salva separadamente quando o campo perde o foco; o botão geral “Salvar ajustes” não é necessário para essa chave. Nunca compartilhe chaves em prints, mensagens ou repositórios.

A versão 1.3.0 ainda não contém uma integração funcional de modelo LLM local no Android. Essa etapa exige selecionar e validar um runtime/modelo compatível, medir RAM/temperatura e fazer build real antes de ser anunciada como disponível.


## Revisão 1.3.3 — correção de build Android

- Removida a dependência `com.github.msnilsen:openwakeword-android:0.1.0`, que falhava ao ser resolvida no build Android.
- O workflow aceita arquivos-fonte versionados e também pode compilar a partir dos arquivos já presentes na raiz do repositório.
- Testes automatizados locais: em execução nesta revisão; compilação Android real ainda precisa ser confirmada.
- **Estado do APK:** ainda pendente de build Android no GitHub Actions. A aprovação dos testes estáticos não confirma a compilação nem a operação real do microfone, wake word, voz ou consumo de bateria.

- Sem AccessKey Picovoice, a conversa por microfone manual permanece disponível, mas a palavra de ativação contínua não é prometida.
