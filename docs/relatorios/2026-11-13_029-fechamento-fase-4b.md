# Ajuste 029 — fechamento da Fase 4B: pré-checagem e critérios de aceite

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## Por que este ajuste

Os itens 1–9 da Fase 4B estão implementados e cobertos por testes locais, mas o Java nunca foi
compilado aqui (sem Android SDK) e nada foi medido no aparelho. Antes de pedir uma rodada de
CI, faltava uma barreira que pegue os erros mecânicos antes do Gradle — e um documento que
diga, sem otimismo, o que está pronto, o que falta medir e o que conta como falha.

## O que foi feito

**`ci/preflight_android.py` (novo)**

Verifica, lendo o repositório:

- toda classe de topo `*.java` está na lista explícita copiada/verificada pelos workflows;
- toda classe `Jarvis*` citada no código existe de fato (pega nome errado depois de renomear);
- `patch_gradle.py` injeta `androidx.work` e `JarvisManutencaoWorker.java` existe;
- `patch_manifest.py` mantém `foregroundServiceType="microphone|dataSync"` e `POST_NOTIFICATIONS`;
- todo `<script src>` do `index.html` existe e está em `package.json build.files`;
- todo `tests/test_*.js` roda na suíte ou é chamado por outro teste;
- todo `JarvisService.método`/campo usado pelo plugin existe no serviço.

**CI** — passo "Pré-checagem das classes e dependências Android" nos quatro fluxos que compilam
APK (`ci.yml`, `build-apk.yml`, `release-apk.yml`, `ci-android-auditoria.yml`).

**`docs/FASE-4B-ACEITE.md` (novo)** — situação por requisito (com arquivo e teste que sustenta),
checklist de dez medições no Poco X7 com critério de aceite, definição de pronto e riscos
abertos.

## Evidência

| Verificação | Resultado |
|---|---|
| `python3 ci/preflight_android.py` | exit 0 — **23 classes, 6 workflows, tudo consistente** |
| Teste negativo (classe removida da lista do workflow) | exit 1 com a mensagem exata; restaurado → exit 0 |
| YAML dos 6 workflows | todos analisados sem erro |
| `npm run test:all` | **exit 0, suíte completa** |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Passo de pré-checagem no CI | presente nos quatro fluxos que compilam APK |

## O que continua pendente (não é falha deste ajuste)

- **Compilar**: só o CI prova; a pré-checagem não olha tipos nem APIs.
- **Medir no Poco X7**: os dez itens da ficha, inclusive consumo de 8 h e as quatro provas de
  privacidade.
- Taxa de ativação em PT-BR, comportamento no Doze e sobrevivência no HyperOS continuam sem
  número.
