# Auditoria técnica — J.A.R.V.I.S. Nova 1.4.2

Data: 2026-10-20

## Mudanças nesta revisão
- Versão e versionCode sincronizados: `1.4.2` / `1402`.
- Novo perfil acústico experimental: captura de áudio somente após ação explícita do usuário; guarda apenas estatísticas numéricas no armazenamento local, permite comparar e apagar o perfil. Não é biometria confiável e não pode ser usado como autenticação ou autorização.
- Captura usa um caminho de áudio silencioso para evitar reproduzir o microfone nos alto-falantes durante a amostra.
- Importação de modelo local usa arquivo temporário e backup/rollback para reduzir o risco de perder o modelo anterior se a substituição falhar.
- Workflow gera checksum e anexa metadados de versão e ambiente de compilação ao artefato.
- Adicionado teste estático dedicado ao perfil acústico.

## Validação realizada neste ambiente
`npm run test:all` passou em 2026-10-20, incluindo sintaxe JavaScript, rotas de voz, validação de IDs e recursos, patch Gradle, prontidão de release, segurança das chaves, integração MediaPipe e testes do perfil acústico.

## Pendências que não podem ser certificadas sem compilar e testar o APK
1. **Compilação Android real:** o ambiente desta sessão não possui Android SDK/Gradle nativo preparado e não foi possível confirmar um APK recém-compilado. O workflow GitHub Actions deve ser executado com os arquivos desta versão.
2. **IA local:** o plugin usa MediaPipe LLM Inference 0.10.14 e exige que o usuário importe um arquivo `.task` especificamente compatível. Modelos GGUF não funcionam diretamente; o APK não inclui um modelo. O build e a execução do modelo ainda precisam ser confirmados no aparelho.
3. **Palavra de ativação:** Porcupine continua exigindo uma AccessKey Picovoice. A chave pode ser obtida no portal do fornecedor conforme as condições atuais do plano; não existe neste pacote uma alternativa gratuita sem chave validada para detectar “Jarvis” continuamente. Sem chave, o microfone manual funciona.
4. **Identificação de falante:** o perfil acústico desta versão é uma prova de conceito baseada em características simples, com risco de falsos positivos e falsos negativos. Não identifica com confiança biométrica quem fala, não deve bloquear/desbloquear recursos e não substitui autenticação.
5. **Voz masculina:** a aplicação tenta priorizar uma voz com nome sugestivo e português brasileiro, mas o Android não fornece um marcador de gênero padronizado para todas as vozes. O resultado depende das vozes instaladas.
6. **Dispositivo físico:** permissões, escuta em segundo plano, consumo de bateria, microfone, TTS, notificações, alarmes e compatibilidade do POCO X7 ainda precisam de teste manual.

## Próximo procedimento
1. Extrair `JARVIS-NOVA-1.4.2-fonte.zip` e publicar seus conteúdos na raiz de um repositório GitHub novo, mantendo `.github/workflows/build-apk.yml` no caminho correto.
2. Executar **Actions → Build e testes do J.A.R.V.I.S. Nova 1.4.2 → Run workflow**.
3. Se falhar, usar os logs da etapa que falhou; não declarar o APK pronto antes disso.
4. Se passar, baixar `JARVIS-Nova-1.4.2-APK`, instalar o `app-debug.apk` no POCO X7 e executar a lista de testes de dispositivo.

## Limites de segurança e privacidade
- O perfil acústico não armazena a gravação bruta, mas seu vetor local ainda é dado derivado de voz; apagar o perfil remove esse vetor.
- Voz não deve ser usada como fator único para ações sensíveis.
- Chaves de IA e Picovoice devem ser cadastradas no próprio app; nunca publicadas no repositório.
- Não há login nesta versão, conforme solicitado.
