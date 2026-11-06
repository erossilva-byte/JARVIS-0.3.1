# 1.38.0 — Avatar 3D, plano persistente e executores

Data: 2026-11-01.

## Entregue

- Avatar 3D procedural (`avatar.js`): rosto, olhos com piscada, boca por amplitude de voz, estados do assistente, anéis, partículas, pausa por visibilidade/intersecção e fallback Canvas 2D.
- Opção “Avatar 3D” em Aparência do núcleo, com prévia e texto que declara a limitação: sincronização por volume, não visemas por fonema.
- Plano validado convertido em tarefa persistente do `SISTEMA` (`plano_etapa`, `tarefaDoPlano`, `resultadoDaTarefaDoPlano`), com checkpoint, pausa, retomada e cancelamento.
- `semConfirmacaoPropria` no despachante interno: a ação real continua confirmando uma vez; o usuário não confirma a mesma etapa duas vezes.
- Executores de leitura do Core: voz (diagnóstico de microfone), automação (status da acessibilidade), atualização (versão instalada) e planejamento (tarefas/ferramentas).
- Auditorias `docs/IA-1.38.0.md` e `docs/REPERTORIO-1.38.0.md`.

## Testes

- `npm run test:all` — exit 0.
- `node tests/test_avatar.js` — 5 verificações, incluindo fallback Canvas 2D real com canvas falso.
- `node tests/test_sistema.js` — 19 verificações, incluindo confirmação única e retomada.
- `python3 tests/test_v1_38_0.py` — contrato estático.
- `python3 tests/test_v1_37_0.py` e `test_v1_36_0.py` — preservação.

## Build 1.38.0

- Arquivo: `jarvis-nova-1.38.0-10380.apk`.
- Tamanho: 81196059 bytes (78 MB).
- SHA-256: `3fbe237a672eca13f308a266c86e0503d13ddcfa54fdd4e75308bb0b8cae27ba`.
- `aapt`: `com.jarvis.nova`, versão 1.38.0, versionCode 10380, minSdk 26, targetSdk 34, compileSdk 35.
- Assinatura: APK Signature Scheme v2 verificada.
- Assets conferidos: `assets/public/avatar.js`, `app.js`, `index.html`, `sistema.js`, `style.css`.
- O APK é debug/CI, não uma build de produção assinada com chave privada do usuário.

## Limitações

Não houve instalação, abertura, toque, microfone, wake word, notificações, acessibilidade ou teste de segundo plano em aparelho. Nada disso foi simulado. O avatar não foi visto em uma tela real; a validação foi por código, teste de fallback e presença no APK. Chaves de IA, modelo `.task`, Windows, ESP32 e Home Assistant continuam sem prova ao vivo.
