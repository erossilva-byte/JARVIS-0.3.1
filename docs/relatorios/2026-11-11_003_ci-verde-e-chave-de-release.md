# Relatório — Fase 2, ajuste 003: CI verde e chave de release fora do repositório

## 1. Identificação

- **Projeto:** J.A.R.V.I.S. Nova · **Versão:** 1.46.0
- **Data:** 2026-11-11 · **Branch:** `work/1.48.0-fase2-consolidacao`
- **Ajuste:** 003 (fecha a Fase 2)
- **Plataformas afetadas:** CI, Android (build e release), documentação

## 2. Resumo

O CI da branch passou a rodar ponta a ponta no mesmo commit, incluindo a compilação
Android real com `targetSdk` 36 e o portão Flutter nos dois sistemas. A reprovação que
existia não era defeito de código: eram duas asserções de teste que exigiam a
configuração anterior à Fase 2. Foram corrigidas para a nova verdade — mais estritas,
não mais frouxas. Este ajuste também impede que uma chave de assinatura entre no
repositório.

## 3. O que foi feito

| # | Mudança | Arquivo | Tipo |
|---|---|---|---|
| 1 | `tests/test_local_ai.py` passou a exigir AGP 8.13.0 e `gradle-8.13-all.zip` (antes 8.7.3/8.9) | `tests/test_local_ai.py` | teste |
| 2 | `tests/test_novos_recursos.py` passou a exigir `assembleRelease` e recusa de `CN=Android Debug` (antes exigia `assembleDebug` na release) | `tests/test_novos_recursos.py` | teste |
| 3 | `.gitignore` passa a ignorar `*.jks` e `*.keystore`, com exceção declarada para `ci/debug.keystore` | `.gitignore` | segurança |
| 4 | Nova verificação de prontidão: `.gitignore` cobre chaves, release não referencia a chave de debug, release compila `assembleRelease` e recusa debug, e nenhuma chave está versionada (`git ls-files`) | `tests/test_release_readiness.py` | teste |
| 5 | Registro do estado verificado e do Gate A no plano da fase | `docs/FASE-2-CONSOLIDACAO-1.48.md` | documentação |
| 6 | Inventário atualizado com a evidência do CI | `docs/INVENTARIO_DE_FUNCOES.md` | documentação |

## 4. Evidência do CI

Commit `20168c8` (`test(release): exige APK de release assinado, não APK de debug`):

**CI de desenvolvimento — run `42923146108`, dois jobs, ambos `success`:**

| Job | Etapas relevantes |
|---|---|
| Regressão estática e funcional automatizada | *Executar suíte de regressão existente* (15 de 15 etapas verdes) |
| Compilação Android real com KWS local | Android SDK, *Instalar Android 36*, *Gerar projeto Android e instalar modelo KWS*, *Preparar código nativo e Gradle*, *Compilar APK de validação* (23:26:03 → 23:27:35, 92 s), *Publicar APK como artefato* |

**Flutter native UI validation — run `42923146213`, três jobs, todos `success`:**

| Job | Etapas |
|---|---|
| `flutter-android` | pub get, `dart format`, analyze, test, `build apk --debug`, verificação de identidade do APK, publicação do artefato |
| `flutter-windows` | pub get, analyze, test, `build windows`, publicação do artefato |
| `advance-gate (Android + Windows)` | exige o sucesso dos dois |

## 5. O que reprovava antes, e por quê

| Run | Commit | Falha |
|---|---|---|
| `568` | `f3d8c2a` | Etapa *Executar suíte de regressão existente*, saída 1 após 12 s. Job Android ficou `skipped` |
| `565`–`567` | commits anteriores | mesma causa, repetida a cada push |

Duas causas, ambas asserções obsoletas:

- `FALHA: Toolchain Java 21 alinhada no patch do CI` — o teste cobrava o texto
  "AGP atualizado para 8.7.3" e `gradle-8.9-all.zip`.
- `FALHA: Workflow de release publica o APK` — o teste cobrava `assembleDebug` no
  workflow de release, ou seja, exigia que a release publicasse APK **assinado em
  debug**: exatamente o que a Fase 2 removeu.

As execuções do Flutter entre `403` e `409` aparecem como **canceladas**, não reprovadas:
cada push cancela a rodada anterior do mesmo grupo de concorrência.

## 6. Evidência local (executada neste ambiente)

```
python3 tests/test_local_ai.py            -> EXIT=0 (mesmo arquivo publicado, baixado por git show)
python3 tests/test_novos_recursos.py      -> EXIT=0 (34 verificações da 1.5.0)
suíte completa de scripts['test:all']     -> 143 comandos, falhas: 0
```

Os dois arquivos de teste publicados foram baixados do remoto (`git show FETCH_HEAD:...`)
e comparados com a cópia local byte a byte: idênticos.

## 7. Decisão sobre a chave de release

A chave hoje usada (`ci/debug.keystore`) é a chave de debug padrão do Android —
`CN=Android Debug`, senha `android`, versionada em repositório público. Ela assinou
todas as releases já publicadas (`release-10460`, `central-10461`, `central-10462`).
Como o atualizador embutido instala APK por `FileProvider`/`ACTION_VIEW`, qualquer
pessoa com esse arquivo pode assinar um APK que o Android aceita como atualização
legítima do app.

**Decisão:** chave nova, privada, só em secrets. Consequência declarada: o APK
release-assinado não instala por cima do app assinado em debug, então cada aparelho
precisa desinstalar uma vez. O app tem exportação de memória (`#mem-exportar`,
`exportarMemoria()` em `app.js`) para preservar os dados antes disso.

Passo a passo da geração e do cadastro dos quatro secrets em
`files/GUIA-CHAVE-DE-RELEASE.md`. Os comandos foram testados aqui: chave gerada com
keytool 21.0.13, base64 decodificado nas duas formas (uma linha e com quebras) e as
checagens do `release-apk.yml` reproduzidas — alias correto aceito, alias errado
recusado, guarda `CN=Android Debug` sem disparar na chave nova.

## 8. Não verificado

- **`./gradlew assembleRelease` não rodou aqui** (sem Android SDK). O caminho de release
  só é exercitado por tag e depende dos quatro secrets.
- **Nenhum APK foi instalado em aparelho físico.** Gate B continua aberto por definição.
- **`CHANGELOG.md` não foi atualizado neste ajuste**: o arquivo tem 121 KB e a publicação
  pela API substitui o arquivo inteiro. O bloco para colar no topo está na seção 9.

## 9. Pendência única e bloco do CHANGELOG

Colar no topo do `CHANGELOG.md`:

```markdown
## 1.46.0 — Fase 2

### Corrigido
- **Suíte de regressão reprovava por asserções obsoletas**: `tests/test_local_ai.py`
  cobrava AGP 8.7.3/Gradle 8.9 e `tests/test_novos_recursos.py` exigia APK de release
  assinado em debug. Ambos passaram a exigir a configuração da Fase 2 (AGP 8.13.0,
  Gradle 8.13, `assembleRelease` e recusa de `CN=Android Debug`).

### Segurança
- **Release não assina mais com a chave de debug** versionada no repositório: a chave
  vem de secrets (`JARVIS_KEYSTORE_B64`, `JARVIS_KEYSTORE_PASSWORD`,
  `JARVIS_KEY_ALIAS`, `JARVIS_KEY_PASSWORD`) e o workflow recusa APK assinado em debug.
- `.gitignore` passa a ignorar `*.jks` e `*.keystore`, e um teste falha se alguma chave
  de release for versionada.

### Android
- `compileSdk`/`targetSdk` 36 (Android 16), AGP 8.13.0 e Gradle 8.13.

### CI
- CI de desenvolvimento verde no commit `20168c8`: regressão completa e compilação
  Android real com SDK 36.
- Portão Flutter verde: `flutter-android`, `flutter-windows` e o agregador.
```

## 10. Próximos passos

1. Gerar a chave de release e cadastrar os quatro secrets (guia em `files/GUIA-CHAVE-DE-RELEASE.md`).
2. Publicar a primeira release com a chave nova, subindo `versionCode` para 10463 ou mais,
   com o aviso de desinstalação única.
3. Primeira execução real no Poco X7 com o checklist da 3B.11 (Gate B).
