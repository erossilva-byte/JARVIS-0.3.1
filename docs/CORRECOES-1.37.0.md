# Correções de execução — 1.37.0

Data: 31 de outubro de 2026

## Falhas encontradas

1. **Retomada de tarefa incerta reexecutava a etapa.** Ao confirmar a continuação, o laço chamava a ferramenta novamente. Em uma mensagem, chamada ou escrita, isso podia duplicar o efeito. A correção aceita a etapa incerta como concluída, registra “autorizado sem repetir” e segue para a próxima.
2. **Não havia pausa manual entre etapas.** O estado `pausada` existia, mas só era atingido por incerteza. Agora o núcleo aceita uma solicitação de pausa durante a execução: a ferramenta atual termina, a próxima não começa e o checkpoint é preservado.
3. **A tela de tarefas dizia que lembretes não eram agendados**, embora `agendarAvisoTarefa` já usasse o agendador do Android. O texto foi corrigido para descrever o comportamento real e suas dependências de permissão.

## Implementação

- `sistema.js`: `pausarTarefa`, fila de pausas, limpeza em cancelar/limpar e retomada conservadora de etapa incerta.
- `app.js`: botões **Iniciar**, **Continuar** e **Pausar**; atualização ao receber `tarefa:pausa` e `tarefa:cancelada`.
- `index.html`: descrição correta dos lembretes de prazo.
- `tests/test_sistema.js`: cobertura de não duplicação e pausa entre etapas.
- `tests/test_v1_37_0.py`: contrato estático da versão.

## Classificação

| Funcionalidade | Problema | Solução aplicada | Resultado |
|---|---|---|---|
| Retomada de tarefa incerta | Reexecutava a etapa | Aceita sem repetir e segue | **CORRIGIDO E TESTADO** em Node |
| Pausa de tarefa | Só automática por incerteza | Pausa manual entre etapas | **ADAPTADO E TESTADO** em Node |
| Botão de pausa/continuação | Não existia | UI com três estados | **IMPLEMENTADO, MAS NÃO TESTADO** visualmente |
| Lembrete de prazo | Texto dizia que não agendava | Texto alinhado ao código | **CORRIGIDO** |
| Tarefa em execução durante pausa | A ferramenta atual não é abortada | Termina e não inicia a próxima | **ADAPTADO E TESTADO** |
| Cancelamento durante ferramenta | Efeito já iniciado pode concluir | Limitação documentada | **PARCIALMENTE FUNCIONAL** |
| Android/notificações | Depende de permissão e fabricante | Sem simulação | **BLOQUEADO POR PERMISSÃO** |
| Voz, câmera, wake word, Windows, ESP32 | Sem hardware/serviço aqui | Não simulados | **BLOQUEADO POR HARDWARE/SISTEMA** |

## Testes

- `node tests/test_sistema.js`: 18 verificações aprovadas.
- `python3 tests/test_v1_37_0.py`.
- Suíte completa e build registrados no fechamento.

## Build 1.37.0

- Arquivo: `jarvis-nova-1.37.0-10370.apk`.
- Bytes: 81186378.
- SHA-256: `efb88aa631cdd56cadc761f6b0b6e3c7f7345b45db53daedc0382b77f4554fe6`.
- `aapt`: pacote `com.jarvis.nova`, versão 1.37.0, versionCode 10370, minSdk 26, targetSdk 34, acessibilidade presente.
- Assets: app, sistema, Core, aprendizado e UI de aprendizado.
- Build: `assembleDebug`, JDK 21, SDK 35, build-tools 35.0.0, 36 s.
- Instalação e abertura em aparelho não foram testadas.

## Limitações restantes

A pausa não interrompe uma ferramenta que já começou; ela impede a próxima etapa. Isso é intencional para não deixar efeitos pela metade. Não há como validar toque, notificação, microfone, wake word, instalação ou integração física sem aparelho/serviço disponível.
