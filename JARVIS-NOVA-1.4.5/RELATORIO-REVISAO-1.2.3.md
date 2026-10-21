# J.A.R.V.I.S. Nova 1.2.3 — revisão de segundo plano e ativação por voz

Data: 15/10/2026  
Base: fonte 1.2.2.  
Status: fonte revisada e testes estáticos aprovados; **não foi gerado APK nesta etapa**.

## Alterações realizadas

1. **Ativação experimental “Jarvis” habilitável**: removida a trava que desativava a opção em toda inicialização. Em Android, o usuário pode ativá-la em Ajustes > Voz. A opção continua desligada por padrão.
2. **Reconhecer palavra + comando na mesma fala**: mantém o comportamento do plugin atual que tenta capturar “Jarvis, [comando]” usando o `SpeechRecognizer` do Android.
3. **Falha segura ao iniciar**: se o serviço/reconhecedor falhar, o modo é desativado e a interface avisa; não fica indicando falsamente que está ouvindo.
4. **Segundo plano mais seletivo**: o serviço com notificação é solicitado quando a ativação está habilitada e a preferência de segundo plano está ativa. Se a ativação for desligada, o serviço é encerrado. Alarmes e lembretes continuam usando o agendador nativo e não precisam desse serviço permanente.
5. **Economia de bateria**: removido o `PARTIAL_WAKE_LOCK` que era adquirido por até 12 horas sempre que o serviço iniciava. Isso elimina uma fonte de consumo contínuo desnecessário; a duração real da bateria ainda precisa ser medida no aparelho.
6. **Serviço e interface mais precisos**: retirado o tipo `mediaPlayback` que não correspondia ao trabalho do serviço; a documentação e os textos agora explicam as limitações do modo experimental.
7. **Versão e CI**: versão alterada para 1.2.3 / versionCode 1203 e workflow/validador atualizados.

## Testes executados

- `npm run test:syntax`: passou (`node --check` em `app.js`, `main.js` e `apps.js`).
- `python3 tests/validate_project.py`: passou; 124 IDs únicos e invariantes do projeto validados.
- `python3 -m py_compile patch_manifest.py patch_visual.py patch_android_version.py`: passou.
- Integridade do ZIP e SHA-256 gerados após empacotar a fonte.

## O que ainda precisa ser ajustado/testado

- **Detector dedicado de baixo consumo**: ainda não integrado. O modo 1.2.3 usa `SpeechRecognizer`; não é equivalente ao “Ok Google”, pode consumir mais bateria e a disponibilidade/offline varia conforme aparelho e serviço de reconhecimento.
- **Execução robusta com app encerrado**: o serviço Android atual não hospeda a lógica completa da IA. Se o Android matar o processo WebView/app, não há garantia de que o J.A.R.V.I.S. processe e responda a um novo comando. A próxima etapa é mover a detecção e a entrega de eventos para um serviço nativo persistente e integrar um detector local licenciado.
- **Tela bloqueada e fabricante**: validar em Android real, incluindo otimização de bateria, reinicialização do aparelho, permissões de microfone/notificação e política do fabricante.
- **Música/vídeo**: por padrão a escuta pode pausar durante reprodução para evitar competir pelo áudio. Se desativar essa pausa, poderá haver conflito de áudio e maior consumo.
- **Medição de bateria**: medir pelo menos 30–60 minutos com escuta ligada/desligada, tela apagada, música tocando e em diferentes níveis de bateria; não há medição real neste ambiente.
- **Compilação e testes físicos**: não executados nesta revisão; os testes estáticos não certificam compilação Gradle nem ausência total de bugs.

## Decisão de segurança

Não foi habilitada escuta contínua por padrão e não foram adicionadas permissões de acessibilidade, leitura direta de SMS ou chamadas silenciosas. O usuário mantém controle explícito sobre a ativação por voz.
