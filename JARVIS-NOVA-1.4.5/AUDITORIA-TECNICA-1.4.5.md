# Auditoria técnica — J.A.R.V.I.S. Nova 1.4.5

## Alterações desta revisão
- Refinamento visual do HUD inspirado na referência enviada: paleta ciano, fundo técnico discreto, anéis mais contidos e núcleo reduzido.
- Regras responsivas para telas baixas e celulares estreitos; respeita `prefers-reduced-motion`.
- Atualização da versão para 1.4.5 / versionCode 1405 e nome do artefato de CI.

## Segundo plano: estado real
O app possui um serviço Android em primeiro plano e notificação persistente, mas isso não garante execução contínua em todas as condições do Android. O detector Porcupine continua pertencendo ao plugin Capacitor, não ao serviço. O processo do detector pode parar quando a Activity/plugin for destruída. A implementação deve ser refatorada para que o serviço seja dono do ciclo de vida do detector antes de declarar a função confiável.

Para testar no dispositivo: conceder microfone, iniciar a escuta enquanto o app está visível, confirmar a notificação persistente, apagar a tela, aguardar 15–30 minutos, testar após alternar apps e verificar reinicialização após interrupção. Rever a otimização de bateria do fabricante e restrições de inicialização automática. Não solicitar exclusões de bateria sem consentimento explícito.

## Sherpa-ONNX
Sherpa-ONNX ainda NÃO está integrado nesta versão. Não basta adicionar uma dependência: é necessário escolher e empacotar um modelo de keyword spotting compatível com a palavra “Jarvis”, configurar tokens/keywords, licenças e tamanho, carregar os assets no Android, implementar captura PCM e ciclo de vida no serviço e testar consumo de CPU/RAM/bateria. Os modelos públicos de KWS não garantem português ou a palavra-alvo sem configuração e validação. Esta revisão não finge que essa integração já funciona.

## Verificação
Esta revisão de fonte não equivale a uma compilação Android. A APK, a execução em segundo plano e o wake word devem ser verificados no CI e em dispositivo físico antes de considerar a versão pronta.
