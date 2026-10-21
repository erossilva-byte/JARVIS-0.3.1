# Patch de escuta e reprodução de mídia — J.A.R.V.I.S. Nova 1.2.0

## Alterações
- Adicionada a configuração “Priorizar música e vídeos”.
- Com a opção ativa, o plugin Android consulta `AudioManager.isMusicActive()`, interrompe a sessão de `SpeechRecognizer` quando há mídia ativa e retoma a escuta após a reprodução parar.
- O reinício da escuta usa uma tarefa pendente única, evitando acumular tentativas concorrentes.
- A configuração é persistida localmente e aplicada ao salvar Ajustes.

## Limitação importante
Esta é uma proteção intermediária. Enquanto a música estiver tocando, a palavra “Jarvis” não será detectada nesse modo; para dar um comando, o usuário deve tocar no microfone. A implementação atual usa `SpeechRecognizer`, que não foi projetado para detecção contínua de palavra de ativação e pode disputar recursos de áudio. Para obter comportamento realmente semelhante ao “Ok Google”, é necessário integrar um detector local de wake word dedicado, com modelo compatível, licenciamento verificado, consumo medido e testes em aparelhos reais.

## Validação realizada
- `npm run test:all`: aprovado (sintaxe JS, validação estática do projeto e compilação de scripts Python).
- Não foi possível compilar o código Java/Android neste ambiente por não haver Gradle/Android SDK configurados.
- Não houve teste físico de música, vídeos, tela bloqueada ou microfone. Portanto, este patch-fonte não deve ser tratado como APK validado.
