# J.A.R.V.I.S. Nova 1.4.2

## O que há nesta versão
- Interface HUD e recursos já existentes do J.A.R.V.I.S. Nova preservados.
- Perfil com nome do usuário separado do tratamento (“senhor”, por exemplo).
- Preferência por voz masculina e controles de tom/velocidade, limitados às vozes instaladas no Android.
- Perfil acústico experimental que grava amostras somente mediante toque, guarda características numéricas localmente e permite comparar/apagar. **Não é autenticação biométrica e não confirma identidade com segurança.**
- Integração experimental de IA local MediaPipe que exige importar um modelo `.task` compatível.
- Build debug por GitHub Actions.

## Como publicar e compilar
1. Baixe e extraia `JARVIS-NOVA-1.4.2-fonte.zip`.
2. Envie o conteúdo extraído para a raiz de um repositório GitHub novo. Não envie apenas o ZIP se quiser que o workflow fique ativo: `.github/workflows/build-apk.yml` precisa existir na raiz do repositório.
3. Abra **Actions**, selecione **Build e testes do J.A.R.V.I.S. Nova 1.4.2** e clique em **Run workflow**.
4. Aguarde o job terminar. Se falhar, abra a etapa vermelha e guarde o log completo.
5. Se concluir com sucesso, abra o artefato `JARVIS-Nova-1.4.2-APK` e baixe `app-debug.apk`.

## Limitações importantes
- A palavra “Jarvis” em escuta contínua ainda exige AccessKey Picovoice; sem ela, use o botão de microfone.
- A IA local depende de modelo `.task` compatível e ainda requer validação no aparelho.
- A voz masculina depende das vozes TTS instaladas no Android.
- O perfil acústico é experimental e não deve autorizar ações privadas/sensíveis.
- Esta versão não tem login.
- Testes estáticos passaram; o APK só pode ser considerado compilado após uma execução bem-sucedida do GitHub Actions e não certificado em dispositivo até a instalação/teste físico.
