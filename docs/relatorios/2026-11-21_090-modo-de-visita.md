# Ajuste 090 — Duress PIN no formato de visita

Data: 2026-11-21 · Versão: 1.76.0+17600 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido

Seguir o último item escolhido do roadmap do comparativo com o U.L.T.R.O.N.: o
Duress PIN, no formato de **modo de visita** descrito antes (esconde os dados,
não apaga), e entregar o APK.

## 2. O que existia

- PIN principal com PBKDF2-HMAC-SHA256 e sal próprio no cofre seguro, comparação
  em tempo constante, limite de tentativas com espera, biometria opcional e uma
  tela que cobre o app inteiro (`BloqueioGate`).
- Nenhum segundo PIN: quem fosse obrigado a desbloquear mostrava o JARVIS real,
  com conversas, memória, fichas de pessoas e cofre.

## 3. O que foi feito

### Dois PINs, dois segredos

- **`BloqueioStore` agora também implementa `PortaCoacao`**. O PIN de coação tem
  **sal e digest próprios** (`coacao.sal`, `coacao.digest`, `coacao.iteracoes`) no
  cofre seguro do aparelho; nenhum dos dois PINs fica em texto e o uso continua
  protegido por tentativas e espera.
- **Definir exige o PIN principal**, passa pela mesma política do principal
  (tamanho, repetição, sequência, lista de PINs comuns) e é **recusado se for
  igual ao principal** — comparado por digest, não por texto.
- **A conferência calcula os dois sempre**, mesmo quando o principal já casou, e
  só então decide. Assim o tempo de resposta não denuncia qual dos dois foi
  digitado. O acerto pela coação devolve `coacao: true` e registra a data do uso.
- Remover a coação também exige o PIN principal; usar o PIN de coação para tentar
  trocar ou remover é recusado com a frase “Digite o PIN principal”. Desligar o
  bloqueio apaga os dois PINs, para não sobrar um PIN de coação órfão.

### Modo de visita

- **A tela de bloqueio ganhou `aoEntrar(bool coacao)`**. Com o PIN de coação, o
  portão **nem monta o app real**: no lugar dele aparece o `ModoVisitaPage`. O
  app real só volta com o PIN principal, e “Bloquear e sair” (nos ajustes da
  visita) retorna à tela do PIN.
- **Um app recém-instalado**: conversa em memória, sem histórico; ajustes
  mostram “Nenhum configurado / Nenhuma guardada / Vazia” em provedor, conversas,
  memória, pessoas, arquivos e palavra de ativação.
- **Nenhuma pergunta sai do aparelho**: o modo de visita não usa
  `ProviderService` nem rede. Hora, data, saudação e identidade são locais;
  qualquer outra pergunta recebe “Neste aparelho eu ainda não tenho um provedor
  de inteligência configurado…”. Isso é honesto e plausível para uma instalação
  nova.
- **A palavra de ativação é desligada** ao entrar no modo de visita, para o
  JARVIS não responder por voz com dados reais. Ao voltar do segundo plano, o
  modo de visita se fecha e pede o PIN de novo.
- **Registro discreto**: a tela de segurança (só depois do PIN principal) mostra
  a data do último uso do modo de visita.

### Prompt sugerido “Modo de visita”

- **`promptModoVisita`** em `core/modo_visita.dart`, com o nome
  **Modo de visita**: manda responder em português do Brasil, em no máximo três
  frases, nunca mencionar dono, conversas, memória, fichas, arquivos, localização
  ou chaves, não inventar fatos e não pedir senhas.
- Aparece na seção “Modo de visita (Duress PIN)” da tela de segurança e nos
  ajustes do próprio modo de visita, com botão **Copiar prompt**.

## 4. Evidência

- `flutter analyze` → `No issues found!`
- `flutter test` → suíte do app passando, incluindo
  `test/bloqueio_coacao_test.dart` (6 casos de PIN de coação) e
  `test/modo_visita_page_test.dart` (5 casos, entre eles “PIN de coação abre o
  modo de visita, nunca o app real” e “PIN principal abre o app real”).
- Teste puro com asserções ligadas:
  `dart --enable-asserts run tool/modo_visita_test.dart` → OK.
- Contrato novo `tests/test_coacao_flutter.py` em `npm run test:all`.
- APK release arm64: `JARVIS-Nova-1.76.0-modo-de-visita.apk`, 117 974 288 bytes,
  SHA-256 `243b6ae9bb2ab8450e1c8e8cf71e6b62c2b52c2cf47def5fdbc0c153226cc198`
  (https://files.catbox.moe/8sosee.apk).

## 5. Arquivos

- `flutter_app/lib/core/modo_visita.dart` (novo): prompt, respostas locais,
  ajustes vazios e limites.
- `flutter_app/lib/core/seguranca.dart`: `ResultadoTentativa.coacao` e
  `PortaCoacao`.
- `flutter_app/lib/services/bloqueio_store.dart`: PIN de coação, conferência dos
  dois e registro de uso.
- `flutter_app/lib/services/bloqueio_page.dart`: `aoEntrar(bool coacao)`.
- `flutter_app/lib/services/bloqueio_gate.dart`: modo de visita, desligar a
  escuta e re-lock ao voltar.
- `flutter_app/lib/services/modo_visita_page.dart` (novo): app de visita e
  ajustes com o prompt.
- `flutter_app/lib/services/seguranca_page.dart`: seção do PIN de coação.
- Testes: `tool/modo_visita_test.dart`, `test/bloqueio_coacao_test.dart`,
  `test/modo_visita_page_test.dart`; contrato `tests/test_coacao_flutter.py`.

## 6. Não verificado

- **Nenhum aparelho físico**: o fluxo real de definir o PIN de coação, digitar
  sob pressão e a aparência do app vazio em tela pequena não foram vistos. O
  teclado da tela de bloqueio foi exercitado apenas em teste de widget.
- **Não é negação plausível de disco**: os dados reais continuam no aparelho e,
  com root ou perícia, ainda podem ser encontrados. O modo esconde, não apaga.
- **Biometria continua abrindo o app real** — se o dono for obrigado a usar o
  dedo/rosto, cai no app verdadeiro. Desligar a biometria é decisão do usuário.
- Quem souber os dois PINs não é protegido; um PIN de coação óbvio (data de
  nascimento) pode ser adivinhado por quem conhece a pessoa.
- O registro de uso fica em `SharedPreferences`, não no cofre: informa a data,
  não o conteúdo.
- As habilidades em Markdown e qualquer provedor de IA ficam fora do modo de
  visita por decisão de projeto — não há resposta de conhecimento ali.
- Nada foi commitado nem enviado.
