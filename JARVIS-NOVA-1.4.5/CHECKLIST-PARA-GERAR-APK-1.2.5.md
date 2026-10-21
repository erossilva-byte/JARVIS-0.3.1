# Checklist para gerar o APK — J.A.R.V.I.S. Nova 1.2.6

## Antes do build
- [ ] Repositório GitHub contém os arquivos da pasta `JARVIS-NOVA` na raiz, ou o ZIP `JARVIS-NOVA-1.2.6-fonte.zip` na raiz.
- [ ] O workflow `.github/workflows/build-apk.yml` está commitado no repositório (um workflow que existe apenas dentro do ZIP não será registrado pelo GitHub até que esteja no repositório).
- [ ] A conta Picovoice foi criada e a AccessKey foi configurada no aplicativo durante o teste; nunca colocar a chave no código ou em commit.
- [ ] As chaves de IA são configuradas localmente, não no repositório público.

## Build
1. Abra GitHub → Actions → `Build e testes do J.A.R.V.I.S. Nova`.
2. Escolha `Run workflow`.
3. Aguarde os testes e a etapa `Compilar APK debug`.
4. Se falhar, abra o primeiro passo vermelho e guarde o log completo.
5. Se passar, abra o artefato `JARVIS-Nova-1.2.6-APK` e baixe o APK e o checksum.

## Depois do build
- [ ] Instalar em um Android de teste.
- [ ] Testar “Jarvis” em ambiente silencioso e com ruído.
- [ ] Confirmar que o bipe antecede a fala do comando.
- [ ] Confirmar retorno automático ao modo de espera após a resposta.
- [ ] Testar pausar/retomar, música, alternância de apps e permissão do microfone.
- [ ] Testar modo offline, Groq e fallback, tarefas, alarmes e rotinas.
- [ ] Medir bateria durante 30–60 minutos com ativação ligada e desligada.

Um workflow aprovado comprova que o artefato foi compilado naquele ambiente; não substitui testes físicos nem revisão de segurança.
