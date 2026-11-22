# Ajuste 099 — restos da auditoria, voz externa e circuito por prompt

Data: 2026-11-22 · Versão: 1.85.0+18500 · Branch: `work/1.85.0-bloco-099`

## 1. Pedido do usuário

Três pedidos no mesmo bloco:

1. **Terminar os restos das funções que ainda estão como “Integração em
   auditoria”** — as telas de Hermes Agent, Agentes especializados, Modelos
   locais, Tarefas e rotinas, CADeSIMU e elétrica e Segurança e privacidade
   mostravam o mesmo aviso âmbar, inclusive as que já tinham conteúdo.
2. **Implementar o ID de voz `82d13948027e4be69892dd3d0104e681`.**
3. **Poder mandar um prompt para o JARVIS criar qualquer tipo de circuito.**

## 2. O que estava errado de verdade

O aviso “Integração em auditoria” era o `else` da tela de módulo: 24 dos 25
módulos do catálogo caíam nele, então ele dizia a mesma coisa para situações
opostas — “existe e abre” e “não existe”. **Tarefas e rotinas**, **Segurança e
privacidade** e o **CADeSIMU** já tinham tela funcionando e ainda assim
apareciam como “em auditoria”; no caso do CADeSIMU, os dois botões apareciam
*abaixo* do aviso genérico, um contradizendo o outro.

Havia também duas lacunas reais por trás disso:

- **Circuito**: existia importador `.cad` e simulador, mas o caminho natural —
  descrever o que se quer e ver o esquema montado — não existia no Flutter. O
  projetista por prompt era só do núcleo web.
- **Voz**: a voz é a do aparelho, com três timbres. Um **ID de voz** é o nome de
  uma voz em um serviço remoto; sem uma ponte para esse serviço, guardar o ID
  seria só enfeite.

## 3. O que foi feito

### 3.1 Cada módulo declara o estado real

- **`lib/core/estado_modulos.dart`** (novo): tabela dos 25 módulos do catálogo,
  cada um com `pronto`, `parcial` ou `ausente`, um título e um motivo próprio.
  Módulo que não está na tabela cai em “fora da tabela de estado” e não promete
  nada.
- **`lib/pages.dart`**: a tela de módulo troca o aviso genérico por um cartão de
  estado (verde/âmbar/cinza) e pelos botões da tela de verdade. O texto
  “Integração em auditoria” não existe mais no código.
- **Resultado**: 17 prontos, 2 parciais (Obsidian e Backup), 6 ausentes com
  motivo escrito — Programação sem execução, Pareamento Windows, Controle do
  Windows, ESP32/Home Assistant, Avatar 3D e Modelos locais.

Os módulos que já tinham tela agora abrem por botão: Tarefas, Segurança,
Habilidades, Visão, Arquivos, Gestos, Timbre, Voz externa, Atualizações,
Android e os de conectividade que existem. Memória, Pessoas, Personalidade,
Obsidian e Backup dizem onde a tela mora (gaveta), porque dependem de um
armazenamento criado na abertura do app.

### 3.2 Hermes Agent e Agentes especializados, de verdade

- **`lib/core/agentes.dart`** (novo): porte do registro de `agentes.js` — 12
  domínios, regras na mesma ordem (programação antes de eletrônica, arquivos
  antes de dispositivo) e instrução de sistema por agente.
- **`lib/core/hermes_plano.dart`** (novo): o Hermes decompõe o pedido em passos
  (elétrico: 4; código: 3; visão/arquivos/memória: 2; conversa: 2), diz qual
  agente responde e qual é o limite do plano. Determinístico e sem rede.
- **`lib/services/hermes_page.dart`** (novo): mostra rota, passos e aviso antes
  de executar; a execução usa o provedor já configurado. Sem chave, a tela diz
  que falta a chave — o plano continua na tela. A mesma página traz a lista dos
  agentes com um campo para testar o roteamento.
- **`lib/services/modelos_locais_page.dart`** (novo): declara o que roda sem
  internet hoje e o que falta para um modelo de texto local (runtime, pesos,
  escolha por tamanho). Nenhum download é anunciado.

### 3.3 Circuito por prompt

- **`lib/core/projetista.dart`** (novo): lê o texto em português e monta o
  circuito na grade do simulador. Oito famílias: lâmpada com interruptor, LED
  com resistor calculado, lâmpadas em série (2 ou 3), em paralelo (2 ou 3),
  divisor de tensão, partida direta com selo, reversão com intertravamento e
  ligação temporizada.
- **O circuito só é entregue depois de simular**: o projetista roda
  `circuito.simular()` e devolve `ok: false` com o motivo quando a conta não
  fecha, quando há erro elétrico ou quando o pedido está fora das famílias. Não
  existe caminho que desenhe um esquema e diga que está pronto sem simulação.
- **`lib/services/projetista_page.dart`** (novo): campo de pedido, exemplos
  tocáveis, cartão com componentes/potência/estado da simulação e botão “Abrir
  no simulador” (`CircuitoPage(inicial:)`).
- Liga também pelo Hermes: pedido elétrico ganha o botão “Montar no projetista”
  com o texto já preenchido.

### 3.4 ID de voz

- **`lib/core/voz_externa.dart`** (novo): o ID pedido
  (`82d13948027e4be69892dd3d0104e681`) vira o padrão, com validação de formato
  (16 a 40 caracteres), montagem da URL e do corpo do pedido e os limites
  escritos.
- **`lib/services/voz_externa_service.dart`** (novo): guarda o ID como
  preferência e a **chave no cofre do aparelho**; gera o áudio por HTTPS e
  traduz cada falha (chave recusada, cota, ID inválido, sem rede). Sem chave,
  nada é chamado.
- **`lib/services/voz_externa_page.dart`** (novo): ID, chave, interruptor e
  botão “Testar voz”, com o motivo na tela quando não dá.
- **`android/JarvisVoz.kt`** e `MainActivity.kt`: método `falarAudio` e
  `pararAudio` no canal `com.jarvis.nova/voz`, tocando o MP3 pelo `MediaPlayer`
  no mesmo volume da voz local (o modo noturno vale para os dois). Reprovar o
  áudio não deixa o aparelho mudo: devolve `false` e a voz do aparelho continua.

**O que isso muda na prática:** sem a chave do serviço, o ID fica gravado e a
tela diz que falta a chave; o JARVIS continua falando com a voz do aparelho. Com
a chave, o texto da resposta passa a sair do aparelho — é o contrário da voz
local, e está escrito na tela antes de ligar.

## 4. Verificação

- `flutter analyze` → **No issues found**.
- `flutter test` → **319 testes verdes** (eram 303), incluindo
  `programacao_sem_execucao_test.dart` reescrito, `projetista_page_test.dart`,
  `hermes_page_test.dart` e `voz_externa_page_test.dart`.
- Núcleo puro (`dart --enable-asserts run`): `tool/estado_modulos_test.dart`,
  `tool/hermes_plano_test.dart`, `tool/projetista_test.dart` e
  `tool/voz_externa_test.dart` — todos OK. O teste do projetista monta e
  **simula** os sete exemplos da tela.
- Contrato `tests/test_restos_099.py` dentro de `npm run test:all`.

## 5. Limites declarados

- **Nada foi compilado nem instalado nesta sessão.** Não há Android SDK nem
  aparelho aqui: o Kotlin novo (`falarAudio`/`pararAudio`) nunca foi compilado,
  e o `MediaPlayer` nunca tocou um MP3 de verdade.
- **A voz externa nunca foi executada**: não há chave do serviço nesta sessão.
  O caminho de rede, o cofre e a reprodução só serão provados no aparelho, com
  a chave cadastrada.
- **O projetista monta oito famílias, não “qualquer” circuito.** Trifásico,
  transistor, CI, corrente alternada e o `.cad` nativo do CADeSIMU continuam
  fora — e a tela diz isso quando o pedido sai da faixa suportada.
- **Hermes não executa ferramenta**: ele monta o plano e pede texto ao provedor.
  Quem monta circuito é o projetista local, e quem fala é a voz.
- O simulador é de corrente contínua; os valores elétricos saem da conta MNA,
  não de um CAD.

## 6. Arquivos

Novos: `lib/core/estado_modulos.dart`, `lib/core/agentes.dart`,
`lib/core/hermes_plano.dart`, `lib/core/projetista.dart`,
`lib/core/voz_externa.dart`, `lib/core/texto_ptbr.dart`,
`lib/services/hermes_page.dart`, `lib/services/projetista_page.dart`,
`lib/services/modelos_locais_page.dart`, `lib/services/voz_externa_service.dart`,
`lib/services/voz_externa_page.dart`, `tool/estado_modulos_test.dart`,
`tool/hermes_plano_test.dart`, `tool/projetista_test.dart`,
`tool/voz_externa_test.dart`, `test/projetista_page_test.dart`,
`test/hermes_page_test.dart`, `test/voz_externa_page_test.dart`,
`tests/test_restos_099.py`.

Alterados: `lib/pages.dart`, `android/JarvisVoz.kt`, `android/MainActivity.kt`
(mais as cópias em `android/app/src/main/kotlin/com/jarvis/nova/`),
`test/programacao_sem_execucao_test.dart`, `tests/test_dart_core.py`,
`package.json`, `pubspec.yaml`, `CHANGELOG.md`, `docs/INVENTARIO_DE_FUNCOES.md`,
`docs/COMPARATIVO-ULTRON.md`.
