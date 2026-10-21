# J.A.R.V.I.S. Nova 1.4.1 — pacote de fonte

Esta é uma revisão independente da base 1.3.4. A interface mantém o HUD animado, chat, configurações, voz, memória controlada, rotinas, alarmes e integrações Android já presentes, com refinamento visual e versão alinhada.

## Estado real dos recursos

- **Chat por API:** Groq, Cerebras, Mistral e Gemini dependem de chaves próprias e de conexão. O uso pode estar sujeito a limites e mudanças de cada provedor.
- **Voz:** TTS e reconhecimento de fala dependem dos serviços/idiomas disponíveis no aparelho. Os controles de pitch e velocidade não são suportados por todas as vozes.
- **Palavra de ativação:** Porcupine exige uma AccessKey Picovoice. Sem chave, a conversa por microfone manual continua disponível. Esta fonte ainda não oferece uma alternativa gratuita de palavra de ativação local com confiabilidade validada; não use o modo contínuo sem entender o impacto de bateria/privacidade.
- **IA local:** o plugin MediaPipe é experimental. O workflow de CI atual substitui-o por um stub de compatibilidade porque a integração original não compila com a combinação de Capacitor/JDK usada. Logo, IA local **não deve ser considerada funcional no APK produzido por esse workflow**.
- **Ações Android:** dependem do aparelho, versão do Android, permissões e serviços externos. Acesso às notificações exige habilitação manual em Configurações do sistema.
- **Build:** workflow gera APK debug. Não é APK de release assinado, e não há teste físico automatizado.

## Verificações locais

No diretório do projeto, execute:

```bash
npm install --ignore-scripts --legacy-peer-deps
npm run test:all
```

Os testes são estáticos e de regressão; não substituem build Android, instalação, teste de microfone, TTS, notificações, alarmes ou consumo de bateria em aparelho físico.

## Publicar em um novo repositório

1. Crie um repositório GitHub vazio com branch `main`.
2. Coloque `JARVIS-NOVA-1.4.1-fonte.zip` na raiz e o arquivo `.github/workflows/build-apk.yml` no caminho exato `.github/workflows/build-apk.yml`.
3. Inclua também `LEIA-ME-1.4.1.md` e `AUDITORIA-TECNICA-1.4.1.md`.
4. Faça commit/push e abra Actions.
5. Baixe o artefato `JARVIS-Nova-1.4.1-APK` somente se o job terminar com sucesso.
6. Instale e teste no aparelho antes de considerar a versão pronta para uso diário.

Nunca coloque chaves de API, AccessKeys, tokens, senhas ou dados pessoais no repositório.
