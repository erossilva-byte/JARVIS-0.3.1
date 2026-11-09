# Sandbox JavaScript do J.A.R.V.I.S. Nova

O painel de Desenvolvimento oferece execução de **JavaScript** em um Web Worker criado dentro de um iframe com origem opaca (`sandbox="allow-scripts"`, sem `allow-same-origin`).

## Limites implementados

- Sem Node.js, `require`, acesso ao sistema de arquivos ou DOM do aplicativo.
- CSP do frame: sem conexões de rede, imagens, mídia, frames externos, formulários ou recursos remotos.
- APIs de rede e comunicação externa são desativadas no Worker (`fetch`, XHR, WebSocket, EventSource, `importScripts`, `sendBeacon`).
- Código: até 20.000 caracteres; entrada JSON: até 10.000; saída: até 16.000.
- Prazo padrão de 3 segundos, limitado a 500 ms–10 segundos; o Worker é terminado quando o prazo expira.
- A ferramenta Hermes `sandbox_js` exige confirmação antes da execução.

## Limitações honestas

Este é um sandbox de execução JavaScript no navegador/WebView, **não** uma VM ou contêiner do sistema operacional. O WebView não oferece uma quota de memória por Worker controlável pelo aplicativo; código que aloque memória em excesso ainda pode pressionar o processo. Não execute código malicioso de terceiros. Python, Java, Kotlin, shell e comandos nativos não são executados por este módulo.

A execução em Android e Windows precisa ser validada em runtime nos respectivos WebViews/Electron. Os testes automatizados cobrem limites, configuração de isolamento, integração, empacotamento e comandos, mas não substituem esse teste em dispositivos reais.
