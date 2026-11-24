# Bloco 112 — um chat por sessão, fala em fluxo e segundo plano estável

**Versão:** 1.89.2+18902
**Data:** 2026-11-24

## O que o usuário pediu

1. Manter a conversa em um único chat; o chat só deve recomeçar depois de fechar
   e abrir o app. Além disso, uma parte de Histórico para ver conversas passadas.
2. Falar mais rápido enquanto produz a resposta.
3. Fazer o Fish Audio funcionar também no segundo plano.
4. Corrigir o aviso de segundo plano “O provedor de IA demorou demais para
   responder. Tente de novo em instantes.”

## O que mudou

### Um chat por sessão

- `ConversaStore.conversaAberta` guarda, só na memória, a conversa aberta
  nesta sessão do app. Ao abrir a conversa, a tela retoma essa conversa
  em vez de criar outra.
- Fechar e abrir o JARVIS zera essa marca (o processo é novo) e a conversa
  começa limpa; a anterior continua salva no histórico.
- Conversa sem nenhuma mensagem não é mais gravada: abrir a tela não cria item
  vazio no histórico.
- A pergunta do usuário é gravada assim que é enviada, para sobreviver a uma
  falha do provedor.
- Quem abre uma conversa pelo histórico passa a continuar nela; ao voltar, a
  tela de conversa mostra a escolhida.

### Histórico visível

- A tela inicial ganhou o botão **Histórico de conversas** (ícone de relógio),
  ao lado de Configurações. Antes ele só era alcançável de dentro da conversa.
- A tela de histórico continua com busca por título ou mensagem, fixar e apagar.

### Fala em fluxo

- `core/fala_em_fluxo.dart` (Dart puro) corta a resposta em frases: ponto,
  exclamação, interrogação, reticências, ponto e vírgula e quebra de linha.
  Ponto entre números (`1.89`) não fecha frase.
- A conversa fala cada frase assim que ela fica pronta, em fila (uma de cada
  vez, na ordem), em vez de esperar a resposta inteira.
- O que sobra no fim é falado ao finalizar; resposta curta sem pontuação é lida
  inteira, como antes.
- Interromper a geração descarta a fila: nada de fala antiga depois do “parar”.

### Segundo plano

- O prazo do serviço deixou de ser um relógio fixo de 50 s. O Dart manda um
  sinal de vida (“progresso”) a cada 8 s enquanto a resposta está a caminho, e
  o serviço renova o prazo (90 s por silêncio). Era isso que produzia o aviso
  “demorou demais” com o provedor ainda respondendo.
- O mesmo aviso continua existindo para o caso real de silêncio total.

### Fish Audio no segundo plano

- `mainFundo` agora carrega a configuração da voz externa no motor sem tela.
- A ponte de segundo plano ganhou `falarResposta`: gera o MP3 com a chave que
  está no cofre do Flutter e toca pelo canal de voz do serviço.
- O motor sem tela ganhou o canal `com.jarvis.nova/voz` (`falarAudio` /
  `pararAudio`) usando a voz do serviço, com o mesmo volume e modo noturno.
- Ao detectar a palavra de ativação, o serviço sobe o motor sem tela
  adiantado quando a voz externa está ligada; a resposta já sai pelo Fish Audio
  com o app fechado.
- Se não houver motor, chave ou áudio, a voz do aparelho assume — o JARVIS
  nunca fica mudo.

## Limites declarados

- Nada foi testado em aparelho físico nesta sessão: nem a fala em fluxo no
  alto-falante, nem o Fish Audio no segundo plano, nem o reinício do chat ao
  reabrir o app.
- Cada frase falada é uma chamada ao Fish Audio: a fala começa mais cedo, mas
  o consumo de cota cresce com o número de frases.
- O fim do MP3 não é informado pelo MediaPlayer; o retorno do microfone usa uma
  estimativa proporcional ao tamanho do texto.
- Sem SDK Flutter no ambiente, `flutter analyze` e `flutter test` rodam só no
  CI; aqui rodaram os contratos Python e o teste puro do núcleo.
