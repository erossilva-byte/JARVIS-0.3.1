# Ajuste 095 — acessibilidade de tela com escopo estreito e consentimento

Data: 2026-11-21 · Versão: 1.81.0+18100 · Branch: `work/1.81.0-bloco-095`

## 1. Pedido do usuário

Corrigir as duas linhas desatualizadas do comparativo do U.L.T.R.O.N. (resumo
tático e atualização OTA continuavam como “Falta”) e seguir para o bloco da
acessibilidade com escopo estreito e consentido, dizendo antes o que muda no
controle do aparelho.

## 2. O que muda no controle do aparelho

Até o ajuste 094, o JARVIS **abria** apps, mas não agia dentro deles. Agora ele
age, com três ações e nada além delas:

- **ler a tela**: lista os textos e ações visíveis da janela ativa;
- **tocar**: procura um texto visível (“Enviar”) e toca no elemento clicável
  correspondente;
- **rolar**: sobe ou desce a área rolável visível.

O que continua fora, de propósito: **digitar**, usar coordenadas livres, abrir
intents arbitrárias, executar shell, interceptar teclas ou gestos.

A autorização é dupla e nenhuma das duas liga sozinha:

1. o serviço precisa ser autorizado em Configurações ▸ Acessibilidade ▸ JARVIS
   Nova;
2. o interruptor “Ler a tela e tocar por mim”, dentro do app, precisa estar
   ligado — e ele nasce desligado.

Desligado o interruptor, nenhuma chamada sai do Flutter: a recusa é local, antes
do canal. É diferente de um serviço autorizado que fica parado esperando ordem.

## 3. O que foi feito

### Nativo (Kotlin novo, sem `.java` novo)

- **`JarvisAcessibilidade.kt`**: `AccessibilityService` de escopo estreito.
  - lê a janela ativa com `rootInActiveWindow` e, se não houver, a primeira
    janela disponível; teto de 120 nós e profundidade 18;
  - campo de senha (`isPassword`) nunca entra na lista nem é alvo de toque;
  - campo de texto entra como “campo de texto”, **sem** o conteúdo digitado;
  - toque sobe até cinco níveis de pai procurando um elemento clicável e
    confirma o retorno de `performAction(ACTION_CLICK)`;
  - rolagem usa a primeira área `isScrollable` visível;
  - `parar` marca a próxima ação como cancelada; nada roda em laço;
  - nenhum `GlobalScope`, nenhum `Thread.sleep`, nenhuma intent arbitrária.
- **`JarvisAcessibilidadeCanal`** (mesmo arquivo): canal
  `com.jarvis.nova/acessibilidade` com `status`, `ler`, `tocar`, `rolar`,
  `parar` e `abrirConfiguracoes`. A leitura roda numa thread própria e a
  resposta volta para a thread principal — a árvore pode levar dezenas de
  milissegundos.
- **`MainActivity.kt`** registra o canal ao lado de `JarvisComandos`.
- **`res/xml/jarvis_acessibilidade.xml`**: só `canRetrieveWindowContent`; sem
  `canRequestFilterKeyEvents`, sem `canRequestTouchExplorationMode` e sem
  `canPerformGestures`.
- **`prepare_android_sistema.py`** declara o serviço com
  `BIND_ACCESSIBILITY_SERVICE`, copia o arquivo Kotlin, copia o XML e confere
  tudo isso no fim — o mesmo script idempotente que já monta o runner.

### Interface (Dart)

- **`core/acessibilidade.dart`**: interpretador puro e resumo da leitura.
  - “ler a tela”, “o que está na tela”, “quais botões na tela” → leitura;
  - “tocar em X” / “clicar em X” exigem preposição: “toque de recolher” não é
    comando;
  - “rolar para cima/baixo” precisa de direção única;
  - “parar a automação de tela”;
  - perguntas (“como…”, “por que…”) nunca viram ação;
  - `resumoDaTela` encurta, remove repetidos e declara quando a leitura parou no
    limite.
- **`services/acessibilidade_store.dart`**: consentimento em
  `jarvis.acessibilidade.ativo`, desligado por padrão, com falha de leitura
  tratada como “desligado”; nada passa pelo cofre de chaves.
- **`services/acessibilidade_service.dart`**: confere o consentimento antes de
  qualquer chamada, traduz o resultado em frase e trata `MissingPluginException`
  e `PlatformException` sem inventar sucesso.
- **`services/acessibilidade_page.dart`**: explicação do escopo, interruptor
  (`acessibilidade-ativar`), estado real do serviço (`acessibilidade-status`),
  botão que abre as configurações do Android
  (`abrir-acessibilidade-android`), campo de comando
  (`acessibilidade-campo`), execução (`executar-acessibilidade`) e a lista do
  que foi lido.
- **`pages.dart`**: botão “Acessibilidade de tela (ler e tocar)” em Android e
  dispositivos.

### Comparativo do U.L.T.R.O.N.

- resumo tático deixou de ser “Falta” (feito no ajuste 085);
- atualização OTA deixou de ser “Falta” (feito no ajuste 092);
- a linha de acessibilidade passou a descrever o que existe hoje, com escopo e
  consentimento;
- `GUIA-ACESSOS-ANDROID.md` deixou de dizer que acessibilidade “não deve ser
  habilitada” em geral e passou a descrever a implementação específica.

## 4. Testes e verificações

- `flutter analyze` limpo.
- `flutter test`: 14 casos novos (interpretador, resumo, consentimento, serviço
  e tela) somados à suíte completa.
- Contrato `tests/test_acessibilidade.py` (leitura estática) e
  `tests/test_comandos_android.py` ajustado: a permissão de acessibilidade
  continua proibida no executor de comandos e só é aceita no serviço dedicado.
- `tests/test_comandos_android.py`, `test_dart_core.py` e os demais contratos da
  suíte rodaram com `python3`.

## 5. Limites honestos

- **Nada foi compilado**: esta sessão não tem Android SDK nem aparelho. O Kotlin
  novo só será provado no CI (`flutter build apk`).
- **Nada foi executado em celular**: leitura de tela, toque e rolagem dependem
  do serviço autorizado nas configurações do Android; o primeiro teste real é
  manual, com o APK instalado.
- **Apps protegidos**: bancos e alguns apps de mensagem bloqueiam a captura da
  tela (`FLAG_SECURE`). Nesses casos o Android devolve pouco ou nada, e a
  resposta é “não encontrei” — nunca “feito”.
- **Toque por texto é frágil por natureza**: dois botões com o mesmo texto usam
  a primeira ocorrência; não há desambiguação por posição nesta versão.
- **Ainda não entra na conversa por voz**: por enquanto o comando de tela é
  digitado na tela própria. Ligar isso à voz e ao segundo plano é um bloco
  separado, com confirmação antes de agir.
