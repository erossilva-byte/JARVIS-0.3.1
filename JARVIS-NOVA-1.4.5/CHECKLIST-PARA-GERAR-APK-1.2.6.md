# Checklist para gerar o APK 1.2.6

1. Envie `JARVIS-NOVA-1.2.6-fonte.zip` para a raiz do repositório GitHub.
2. Confirme que o nome do arquivo é exatamente `JARVIS-NOVA-1.2.6-fonte.zip` e faça commit na branch `main`.
3. Abra a aba **Actions** e acompanhe **Build e testes do J.A.R.V.I.S. Nova**.
4. Se falhar, abra o primeiro passo vermelho e guarde o log completo; não trate um artefato antigo como resultado desta versão.
5. Quando a execução terminar com sucesso, baixe o artefato `JARVIS-Nova-1.2.6-APK`.
6. Instale o APK no Android e teste primeiro os recursos básicos, depois a ativação por voz e o painel Celular.

## Avisos

- Esta revisão ainda não tem APK compilado/confirmado.
- O modelo openWakeWord `Hey Jarvis` é inglês; a detecção de “Jarvis” sozinho e em português não está garantida.
- A licença CC BY-NC-SA 4.0 do modelo pré-treinado precisa ser avaliada antes de distribuição comercial.
- Se o Actions falhar, envie o log do primeiro erro; não remova dependências ou permissões aleatoriamente.
