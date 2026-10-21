# Revisão corretiva — J.A.R.V.I.S. Nova 1.4.5

## Corrigido nesta revisão
- Abertura e fechamento de painéis (Configurações, Registro e Tarefas) agora compartilham um único marcador de histórico.
- Alternar entre painéis substitui o estado atual em vez de empilhar vários `pushState`; isso evita que o botão Voltar percorra painéis antigos e reduz o risco de sair inesperadamente da interface.
- Fechar painéis verifica os elementos antes de manipulá-los; falhas de navegação são registradas sem interromper a interface.
- Adicionado teste de regressão `tests/test_panel_navigation.py` ao `npm run test:all`.
- Corrigido o rótulo desatualizado da versão no workflow de compilação (1.4.3 → 1.4.5).

## Verificações executadas
- `npm run test:all`: passou, incluindo sintaxe JS, IDs HTML, segurança estática das chaves, plugins locais, layout responsivo, rotas de voz e o novo teste de navegação.
- ZIP contém fonte web, plugins Android, patches nativos, workflow e testes.

## Limitações importantes
- Os testes executados são predominantemente estáticos e de regressão; não substituem teste de interface em emulador/celular.
- Esta revisão não foi compilada em APK neste ambiente. É necessário executar o workflow Android em GitHub Actions e instalar/testar o APK no aparelho.
- Não foi possível confirmar que o retorno à tela inicial tinha uma única causa; a navegação do histórico era um risco concreto e foi corrigida, mas logs de falha/Logcat ainda são necessários caso o problema persista.
- O wake word Porcupine depende de AccessKey; sherpa-onnx não está integrado nesta versão. Execução em segundo plano varia conforme as restrições do Android/fabricante.


## Correção 1.4.6 — rolagem dos painéis (21/10/2026)

- Causa identificada: `#painel-config` tinha `overflow:hidden`, anulando a rolagem vertical do painel de configurações no Android WebView.
- Corrigido para `overflow-y:auto`, com altura limitada à viewport (`100dvh` com fallback `100vh`), `min-height:0`, rolagem por toque (`touch-action:pan-y`) e `-webkit-overflow-scrolling:touch`.
- Aplicada regra de rolagem explícita também a todos os `.painel` (Configurações, Tarefas e Registro), mantendo o painel acima do scrim.
- Teste estático: verificação das regras finais e dos seletores de todos os painéis; teste físico no Android ainda é necessário para confirmar o gesto no dispositivo.
