# Ajuste 088 — perfis de timbre da voz na tela

Data: 2026-11-21 · Versão: 1.75.0+17500 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido

Seguir o roadmap do comparativo com o U.L.T.R.O.N. 2.0: os perfis de timbre de
voz na tela, para escolher entre grave, natural e ágil.

## 2. O que existia

- A voz era uma só, sempre com o mesmo tom: `setPitch(0.72f)` e
  `setSpeechRate(0.88f)` fixos na abertura do motor de síntese.
- Não havia tela nem preferência: trocar o timbre exigia editar código, e o
  segundo plano e a tela nunca podiam soar diferentes (nem iguais, por escolha).

## 3. O que foi feito

### Três perfis

- **`JarvisTimbre.kt`** guarda os perfis no aparelho (`SharedPreferences`
  `jarvis_voz`): **grave** (o timbre original, tom 0,72 e ritmo 0,88),
  **natural** (a voz do aparelho sem alteração, 1,00 / 1,00) e **ágil** (mais
  agudo e rápido, 1,15 / 1,12).
- **`core/timbre_voz.dart`** repete os mesmos valores em Dart, com faixas
  seguras (0,5 a 2,0, o que o TextToSpeech aceita), descrição, resumo e limites.
  O teste de contrato compara os números dos dois lados para a tela não prometer
  um timbre diferente do que a síntese usa.

### Aplicação de verdade

- **`JarvisVoz.aplicarTimbre()`** lê o perfil gravado e chama `setPitch` e
  `setSpeechRate` no motor. Ele é chamado ao abrir a voz e quando a tela troca o
  perfil, então a mudança vale na hora.
- **Um perfil para tudo**: a voz da tela e a do segundo plano leem a mesma
  preferência, então o JARVIS não muda de timbre ao sair do app.
- **Transparência**: se a síntese ainda não estiver pronta na troca, o canal
  devolve `aplicado: false` e a tela avisa que o perfil ficou gravado e entra na
  próxima fala — em vez de fingir que já mudou.
- Id desconhecido, vazio ou de uma versão antiga cai no grave, sem quebrar a
  tela (`timbreDe` e `JarvisTimbre.perfil`).

### Tela

- **Nova tela “Perfis de timbre”** (gaveta → Timbre e módulo no catálogo):
  mostra o timbre real lido do aparelho, o tom e o ritmo de cada opção, permite
  escolher e tem **“Ouvir exemplo”** com a mesma síntese da conversa.
- **Sem canal Android** (ou resposta vazia de aparelho antigo), a tela explica
  que os perfis só existem no app instalado, em vez de mostrar uma escolha que
  não faz nada.
- Os limites ficam à vista: a voz é a do aparelho, não é uma voz nova, e no modo
  noturno o volume continua em 45%.

## 4. Evidência

- `flutter analyze` → `No issues found!`
- `flutter test` → suíte completa do app passando, incluindo os 5 casos de
  `timbre_page_test.dart` (timbre gravado, troca para ágil, síntese não pronta,
  ouvir exemplo e canal sem resposta).
- Teste puro com asserções ligadas:
  `dart --enable-asserts run tool/timbre_voz_test.dart` → OK (perfis, paridade
  do grave, faixas, resumo e limites).
- Contrato `tests/test_timbre_flutter.py` dentro de `npm run test:all`.
- APK release arm64: `JARVIS-Nova-1.75.0-timbre.apk`, 117 973 948 bytes,
  SHA-256 `502bfc7c6efad2e63d4d4f6042d8ae0cb31eaad5be570fb80eef743d5155911e`
  (https://files.catbox.moe/ed8iae.apk).

## 5. Arquivos

- `flutter_app/android/JarvisTimbre.kt` (novo): perfis, preferência e estado.
- `flutter_app/android/JarvisVoz.kt`: `aplicarTimbre`, timbre no `status`.
- `flutter_app/android/MainActivity.kt`: canal de voz com `timbre` e
  `definirTimbre`.
- `flutter_app/lib/core/timbre_voz.dart` (novo): contrato puro dos perfis.
- `flutter_app/lib/services/voz_jarvis.dart`: `timbreAtual`, `definirTimbre` e
  `TimbreIndisponivel`.
- `flutter_app/lib/services/timbre_page.dart` (novo): tela dos perfis.
- `flutter_app/lib/catalog.dart`, `drawer.dart`, `home_screen.dart`: navegação.
- `flutter_app/tool/prepare_android_sistema.py`: copia `JarvisTimbre.kt`.
- Testes: `tool/timbre_voz_test.dart`, `test/timbre_page_test.dart`; contrato
  `tests/test_timbre_flutter.py`.

## 6. Não verificado

- **Nenhum áudio foi ouvido nesta sessão**: não há aparelho físico. A diferença
  percebida entre grave, natural e ágil, a inteligibilidade do ágil e o
  comportamento com uma voz pt-BR específica do aparelho não foram medidos.
- A qualidade depende do mecanismo de síntese instalado; sem voz em português, o
  Android usa o idioma padrão e o timbre continua valendo.
- A troca durante uma fala em andamento só vale para a próxima fala; não há
  reinício da frase atual.
- Nada foi commitado nem enviado.
