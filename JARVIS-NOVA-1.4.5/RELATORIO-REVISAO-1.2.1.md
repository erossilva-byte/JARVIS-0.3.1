# Relatório de revisão — J.A.R.V.I.S. Nova 1.2.1 (fonte de desenvolvimento)

## Base
Partiu do ZIP `JARVIS-NOVA-1.2.0-fonte-microfone-corrigido.zip`, cuja soma SHA-256 conferiu com o arquivo de checksum fornecido.

## Alterações incluídas nesta iteração
- Resolução local de contatos com normalização de acentos, emojis, pontuação e letras repetidas. Exemplo pretendido: `Biaa🩵🩵` pode ser resolvido ao falar `Bia`, desde que o resultado seja único.
- Correspondência por prefixo apenas quando há uma única candidata; nomes ambíguos não são escolhidos automaticamente.
- Personalidade do sistema reforçada: competência, observação, humor seco e ironia leve, sem imitar falas de filmes e sem humor inadequado em situações sensíveis.
- Removidas chamadas de pré-aquecimento de rede feitas na inicialização e antes da captura de voz.
- Escuta contínua por palavra desativada por padrão e bloqueada nesta revisão para que o `SpeechRecognizer` não seja apresentado como detector local de baixo consumo. O botão de microfone continua sendo o método disponível.
- Atualização de metadados para 1.2.1 e do workflow de CI para compilar o ZIP de fonte correspondente.

## Funcionalidade ainda não concluída
A ativação verdadeira semelhante ao “Ok Google” **não está implementada nesta revisão**. Um app comum não pode detectar uma palavra sem captar áudio de alguma forma; a abordagem correta requer um detector local específico, idealmente executado por DSP/serviço de baixo consumo quando o aparelho suporta isso. O `SpeechRecognizer` atual não serve como substituto equivalente. A integração exige escolher uma engine/modelo com licença adequada, incluir seus artefatos, revisar o ciclo de vida do microfone/serviço Android e medir consumo e falsos acionamentos em aparelhos reais.

Também não foram concluídos novos conectores nativos para importar contatos do catálogo do Android, enviar SMS/WhatsApp automaticamente (o app mantém revisão/confirmar), nem a validação física de chamadas, alarmes, temporizadores, notificações, mídia e permissões. Partes dessas funções já existem na base 1.2.0, mas não devem ser consideradas integralmente validadas só por testes estáticos.

## Testes executados
- `npm run test:all` (sintaxe JavaScript, validador estático e compilação dos scripts Python).
- Integridade ZIP e checksum.

## Não executado / limitações
- Não foi compilado APK nesta etapa.
- Não foi executado build Java/Android nem teste em dispositivo físico.
- Não há garantia de ausência de bugs; antes do APK, é necessária a integração do detector dedicado e uma rodada de regressão no aparelho.
