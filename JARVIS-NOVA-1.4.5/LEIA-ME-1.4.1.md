# J.A.R.V.I.S. Nova 1.4.1 — build de validação

## Novidades desta revisão
- Perfil com nome do usuário separado do tratamento preferido.
- Preferência por voz masculina com fallback para pt-BR e tom inicial mais grave.
- Correção da extração do pacote de fontes no GitHub Actions (ZIP com `package.json` na raiz ou numa pasta).
- Compatibilidade do callback AndroidX e versão MediaPipe 0.10.14 para a cadeia de build baseada em Java 17/Gradle 8.2.

## Como gerar o APK
1. Crie um repositório novo no GitHub.
2. Extraia o conteúdo de `JARVIS-NOVA-1.4.1-fonte.zip` diretamente na raiz do repositório, mantendo a pasta `.github/workflows`.
3. Faça commit e push para a branch `main`.
4. Abra **Actions → Build e testes do J.A.R.V.I.S. Nova 1.4.1 → Run workflow**.
5. Se todas as etapas passarem, baixe o artefato `JARVIS-Nova-1.4.1-APK`.

O workflow agora também consegue extrair um ZIP de fonte que tenha `package.json` diretamente na raiz, desde que o ZIP esteja na raiz do repositório.

## Importante
- Os testes `npm run test:all` passaram nesta cópia, mas isso não significa que o APK já foi compilado.
- A IA local exige que o usuário importe um modelo `.task` compatível. O APK não inclui modelo.
- A palavra de ativação local ainda depende de AccessKey Picovoice; a chave é requisito do SDK, não uma assinatura mensal de IA.
- A voz masculina é uma preferência heurística. Se o Android não tiver uma voz masculina pt-BR instalada, o app usa a voz pt-BR disponível e tom mais grave.
- A identificação biométrica de falante (reconhecer que a voz é especificamente do proprietário) ainda precisa de um modelo de speaker verification, cadastro de amostras e testes de falsos positivos. Não foi simulada nem apresentada como concluída.
- Instalação, consumo de bateria, microfone, voz e ativação em segundo plano precisam ser validados no POCO X7 real.

Consulte `AUDITORIA-TECNICA-1.4.1.md` e `IMPLEMENTACAO-PERFIL-VOZ-1.4.1.md` para os detalhes e limites.
