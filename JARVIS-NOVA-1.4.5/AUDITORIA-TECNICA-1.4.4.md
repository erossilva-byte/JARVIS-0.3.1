# Auditoria técnica — J.A.R.V.I.S. Nova 1.4.4

## Ajustes desta revisão
- Versão e metadados atualizados para 1.4.4 / versionCode 1404.
- Workflow publica artefato com nome coerente com a versão.
- Reconhecimento manual: o modo `somenteLocal` falha explicitamente quando o reconhecedor local Android não está disponível; quando solicitado, prefere o reconhecedor on-device e informa qual mecanismo foi escolhido.
- Mantida a regra de não declarar como offline o serviço de reconhecimento Android que pode usar rede.

## Estado real dos modos de voz
- **Picovoice Porcupine:** integração no plugin presente; exige AccessKey válida e teste em aparelho.
- **Manual offline:** caminho estrito via `SpeechRecognizer.createOnDeviceSpeechRecognizer`; depende de Android compatível e pacote de reconhecimento local instalado para `pt-BR`. Se indisponível, deve falhar com mensagem e permitir digitação. Não é possível garantir reconhecimento offline em todo aparelho sem incluir um modelo próprio.
- **sherpa-onnx KWS:** NÃO integrado nesta revisão. O SDK sozinho não basta: é necessário empacotar biblioteca nativa, modelo KWS compatível, configuração de keyword/token e fazer o serviço gerenciar o áudio. A interface/código não deve apresentar essa opção como operacional até essa integração ser compilada e testada.
- **Segundo plano:** existe serviço foreground com notificação e tipo microphone. Contudo, o detector Porcupine é atualmente propriedade do plugin Capacitor, não do serviço; se o processo/atividade do app for destruído, o serviço não recria o detector. Assim, segundo plano ao minimizar é o objetivo testável, mas sobrevivência a encerramento do processo ainda não está garantida.

## Testes pendentes obrigatórios
1. Compilar APK no GitHub Actions e inspecionar logs.
2. Testar Porcupine com chave válida, sem chave e sem internet após inicialização.
3. Testar transcrição offline com pacote `pt-BR` instalado e ausente.
4. Testar minimizar, bloquear tela, reprodução de música, revogar microfone e encerrar processo no POCO X7.
5. Integrar e testar sherpa-onnx KWS antes de anunciar os três modos como funcionais.

**Conclusão:** pacote de preparação e correções parciais; não é certificação de release. Não existe garantia honesta de três detectores funcionais enquanto sherpa-onnx não estiver integrado e validado.
