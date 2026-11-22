# Ajuste 101 — editar o circuito do simulador por prompt

Data: 2026-11-22 · Versão: 1.87.0+18700 · Branch: `work/1.87.0-bloco-101`

## 1. Pedido do usuário

Permitir editar o circuito que já está no simulador por prompt, refazendo a
simulação e mostrando o resultado no chat.

## 2. O que faltava

O bloco 100 montava do zero e pronto: cada pedido começava outro circuito. Quem
já tinha um esquema aberto não conseguia dizer “troca o R1 por 470 ohms” — a
frase ia para a IA e voltava conselho, não uma conta nova. Pior: a conversa nem
sabia qual circuito estava na tela, porque o simulador guardava o dele só para
si.

## 3. O que foi feito

### 3.1 Um único lugar para “o circuito em uso”

**`lib/core/circuito_em_uso.dart`** (novo) guarda o esquema que o simulador está
mostrando. `CircuitoPage` publica ao abrir, a cada mudança feita na tela e quando
troca de exemplo; a conversa lê na hora de interpretar o pedido. Sem banco, sem
arquivo e sem rede — fecha o app e some, igual ao simulador.

### 3.2 A edição, em núcleo puro

**`lib/core/edicao_circuito.dart`** (novo) responde: *este texto quer mudar o
circuito aberto?* Exige verbo de edição (“troca”, “muda”, “ajusta”, “aumenta”,
“fecha”, “abre”, “refaz”) e um alvo — nome de peça ou rótulo (`R1`, `L1`, `F1`,
`KT1`, `S1`).

O que ele faz de verdade:

| Pedido | Efeito |
|---|---|
| “troca o R1 por 470 ohms” / “2k2” / “1M” | muda o valor, com sufixos k e M |
| “muda a fonte para 24 V” | muda a tensão da fonte (número solto conta como volts) |
| “aumenta a tensão em 3 V” | soma (ou subtrai, com “diminui”) |
| “troca a lâmpada por 10 W” / “por 24 V” | muda potência e/ou tensão nominal |
| “muda o KT1 para 5 segundos” | muda o atraso do temporizador |
| “fecha o S1” / “abre o S1” | abre e fecha interruptor |
| “simula de novo” | refaz a conta sem mudar nada |

Depois de aplicar, **refaz a simulação de verdade** (`circuito.simular()`), mede
o elemento editado e compara a potência total. O texto sai assim: “Refiz a
simulação depois da edição: R1: 1 kΩ → 470 Ω. A potência total foi de 0,144 W
para 0,306 W. R1 ficou com 12,8 mA e 0,2 V.”

### 3.3 Recusa honesta

- **Não acrescenta nem remove peça**: isso muda a ligação, e adivinhar onde ligar
  seria inventar. A resposta diz para fazer no simulador.
- **Peça ambígua**: “troca o resistor” num divisor com dois resistores pergunta
  qual, listando “R1, R2” — não escolhe por conta própria.
- **Valor faltando**: “troca o R1 por azul” pede o valor em ohms, com exemplo.
- **Sem circuito aberto**: diz para montar um primeiro ou abrir o simulador.
- **Simulação que não fecha**: entrega o erro, não oferece o esquema como pronto.

### 3.4 No chat e na voz

Em `voice_conversation_page.dart` a edição é decidida depois dos comandos do
aparelho, depois de montar (bloco 100) e antes do provedor de IA, para nenhuma
frase de edição gastar chave. A resposta entra como mensagem, é falada na versão sem setas e o cartão
acima do campo de texto passa a apontar para o circuito editado — o botão “Abrir
no simulador” abre exatamente o resultado, já com o valor novo.

Na voz de fundo (`PonteIaFundo.responderPergunta`) o mesmo núcleo responde quando
o motor já tem o circuito em memória; sem ele, a fala orienta a abrir o
simulador, em vez de fingir que editou.

## 4. Verificação

- `flutter analyze` → **No issues found**.
- `flutter test` → **327 testes verdes** (eram 323), com
  `test/conversa_edicao_test.dart`: edita e mostra o recálculo, sem circuito
  aberto não inventa, o botão abre o simulador com o valor novo (2k2 → 2200 Ω) e
  recusa não troca o circuito do cartão.
- `dart --enable-asserts run tool/edicao_circuito_test.dart` → OK: valor, fonte,
  interruptor, atraso, recálculo, ambiguidade e recusas conferidas.
- Contrato `tests/test_edicao_circuito.py` na suíte, prendendo inclusive a ordem
  (montar → editar → provedor) e a publicação do circuito pelo simulador.
- **Todos os contratos e preflights** com EXIT=0. O contrato do bloco 100 foi
  atualizado em dois pontos que este bloco mudou de propósito: o cartão agora
  guarda um `Circuito` (não um `ResultadoProjeto`) e abre com
  `CircuitoPage(inicial: pronto)`. A verificação da ordem e das recusas
  continua igual.

## 5. Limites declarados

- **Nada foi compilado nem instalado nesta sessão**: sem Android SDK e sem
  aparelho, o APK 1.87.0 não existe e essas telas não foram vistas funcionando
  fora do teste.
- A edição **não acrescenta nem remove peça** e não mexe em contato auxiliar,
  ligação, posição na grade ou no `.circ` importado: só valor de peça existente e
  estado de interruptor.
- O alvo é por nome de peça ou rótulo; sinônimos fora da lista (“o chaveamento”,
  “o componente”) não são reconhecidos.
- A edição vale para **um** circuito: o último publicado pelo simulador. Não há
  histórico de versões nem desfazer por voz.
- O circuito em uso vive na memória do motor do Flutter: com o app encerrado, a
  voz de fundo não tem o que editar e diz isso.

## 6. Arquivos

Novos: `lib/core/circuito_em_uso.dart`, `lib/core/edicao_circuito.dart`,
`tool/edicao_circuito_test.dart`, `test/conversa_edicao_test.dart`,
`tests/test_edicao_circuito.py`.

Alterados: `lib/services/voice_conversation_page.dart` (decisão, conclusão da
edição, cartão e atalho), `lib/services/circuito_page.dart` (publica o circuito
em uso), `lib/services/ponte_ia_fundo.dart` (mesma decisão na voz de fundo),
`tests/test_dart_core.py`, `package.json`, `pubspec.yaml`, `CHANGELOG.md`,
`docs/INVENTARIO_DE_FUNCOES.md`, `docs/COMPARATIVO-ULTRON.md`.
