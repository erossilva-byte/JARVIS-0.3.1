# J.A.R.V.I.S. Nova 1.2.4 — revisão técnica de fonte

Data: 16/10/2026  
Base: fonte 1.2.3.  
Status: integração do detector dedicada implementada no código-fonte e testes estáticos em andamento; **não há APK compilado nem validação em aparelho nesta revisão**.

## Alterações feitas

1. **Detector de palavra-chave dedicado:** o plugin nativo usa `ai.picovoice:porcupine-android:4.0.2` e a palavra integrada `JARVIS`, em vez de usar `SpeechRecognizer` em ciclo contínuo para procurar o nome.
2. **Separação entre espera e conversa:** o detector de palavra-chave é executado em espera; após detecção, o detector é liberado e a aplicação inicia o fluxo de transcrição/conversa. A UX passa a orientar “diga Jarvis, aguarde o bipe e então fale”.
3. **Configuração da chave:** adicionado campo de AccessKey Picovoice. No Android, a chave é guardada usando o cofre nativo do app quando disponível; existe ação para apagá-la. A chave não foi embutida no código-fonte.
4. **Mídia:** a preferência para pausar durante música/vídeo agora pausa e retoma o motor de palavra-chave.
5. **Falha segura:** erros de inicialização/desempenho do detector desligam a escuta e reportam a causa à interface, sem deixar o estado de UI afirmando que está ouvindo.
6. **Personalidade:** reforçada a combinação de cortesia, precisão, calma, humor seco e ironia sutil e ocasional. O prompt proíbe copiar diálogos ou bordões dos filmes.
7. **Build:** workflow atualizado para adicionar a dependência Porcupine e publicar artefato nomeado 1.2.4.

## Verificações estáticas executadas

- `npm run test:all`: aprovado.
- `node --check app.js`, `main.js` e `apps.js`: aprovados.
- `tests/validate_project.py`: aprovado; 126 IDs únicos, versão 1.2.4, integração Porcupine, AccessKey e workflow validados.
- `python3 -m py_compile` em `patch_manifest.py`, `patch_visual.py`, `patch_android_version.py` e `patch_gradle.py`: aprovado.
- `patch_gradle.py` testado em Gradle sintético: inserção e execução idempotente aprovadas.
- `patch_manifest.py` testado duas vezes com manifesto/Gradle sintéticos: permissões e dependência adicionadas sem duplicação.
- Varredura estrutural de delimitadores Java: aprovada; não substitui compilação.
- Varredura dos arquivos de código por chaves API embutidas: nenhuma correspondência encontrada.
- Integridade do ZIP e checksum SHA-256: ver arquivo de checksum que acompanha esta fonte.

## O que não pode ser certificado sem build/aparelho

- Compilação Android/Gradle e compatibilidade binária real do SDK no workflow.
- Validação da AccessKey, detecção real da pronúncia brasileira de “Jarvis”, taxa de falsos positivos e tempo de resposta.
- Consumo real de bateria, funcionamento após encerrar a tela do app, reinício do aparelho, limites de execução em segundo plano, conflitos com música/chamadas e diferenças entre fabricantes.
- A detecção local não significa que o microfone deixe de captar áudio: o microfone permanece em uso enquanto a palavra de ativação está habilitada, mas a transcrição completa não fica rodando continuamente.

## Pendências prioritárias

1. Obter e configurar uma AccessKey própria no Picovoice Console; não colocar a chave em repositório público.
2. Executar o workflow de build Android e corrigir qualquer erro de compilação real.
3. Testar em aparelho: 30–60 minutos com tela ativa/inativa, em silêncio, com ruído ambiente e com música; registrar bateria, falsos acionamentos e falhas de detecção.
4. Testar os comandos locais, online/offline, voz de resposta, alarmes, notificações e rotinas para evitar regressões.
5. Confirmar a política de licença/limites da conta Picovoice para o uso pretendido.
