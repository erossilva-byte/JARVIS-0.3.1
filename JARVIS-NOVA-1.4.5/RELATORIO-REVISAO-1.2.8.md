# Revisão 1.2.8 — interface e personalidade

## Alterações
- Cartão de configuração rápida na categoria IA com atalho direto para Voz/Picovoice.
- Reorganização visual de categorias, campos, rótulos e barra inferior em telas pequenas.
- Prévia ilustrativa que muda ao ajustar humor e estilo, para deixar o efeito esperado explícito antes de salvar.
- Instruções de personalidade reforçadas no prompt: estilo mais consistente e humor suspenso em assuntos sensíveis.
- Versão Android atualizada para 1.2.8 / versionCode 1208 para permitir atualização sobre 1.2.7.
- Mantido aviso honesto: a AccessKey Picovoice pode ser guardada, mas Porcupine ainda não está integrado; o detector segue sendo openWakeWord.

## Verificações
- `npm run test:all`: aprovado nesta revisão.
- Os testes são estáticos e não comprovam build Gradle, renderização visual real, comportamento do modelo em chamadas online nem testes físicos.

## Pendências recomendadas
1. Integrar o SDK nativo Porcupine e definir como o modelo “Hey Jarvis” será fornecido; só então validar a AccessKey em runtime.
2. Executar GitHub Actions e instalar o APK resultante.
3. Testar humor/estilos com prompts idênticos em todos os provedores de IA e comparar respostas.
4. Testar configurações, rolagem e acessibilidade em tela pequena.
