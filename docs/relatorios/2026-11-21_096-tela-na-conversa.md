# Ajuste 096 — comandos de tela na conversa, com confirmação antes de tocar

Data: 2026-11-21 · Versão: 1.82.0+18200 · Branch: `work/1.82.0-bloco-096`

## 1. Pedido do usuário

Ligar os comandos de tela à conversa por voz, com confirmação antes de tocar e o
mesmo escopo estreito e consentimento do ajuste 095.

## 2. O que muda no uso

Antes, a automação de tela só existia na tela própria de acessibilidade: era
preciso digitar ali. Agora ela entra no mesmo caminho da conversa por voz e do
texto — a fala reconhecida cai no campo e segue por `_enviar`, que decide entre
comando Android, comando de tela ou pergunta para a IA.

- **Ler** (“ler a tela”, “o que está na tela”) e **rolar** (“rolar para baixo”)
  executam direto e a resposta é falada.
- **Tocar** (“tocar em Enviar”) **nunca** executa direto: o JARVIS pergunta
  “Posso tocar em "Enviar" na tela atual?” e espera.
- A confirmação vale por botão (`Tocar` / `Cancelar`) ou por fala: “sim”,
  “confirmo”, “pode”, “claro” executam; “não”, “cancela”, “deixa”,
  “para” cancelam.
- Qualquer outra frase com um toque pendente **cancela o toque** e segue como
  conversa normal: mudar de assunto não deixa toque armado.
- Sem o consentimento do app, o toque é recusado **antes** de perguntar: nenhuma
  chamada chega ao Android.

Escopo inalterado: ler, tocar e rolar. Não digita, não lê senha, não lê o que foi
digitado em campo de texto, não usa coordenadas livres.

## 3. O que foi feito

- **`core/acessibilidade.dart`**: `ConversaDeTela` e as decisões
  `PedirConfirmacao`, `ExecutarNaTela`, `CancelarNaTela` e `SemTela`. A decisão é
  pura — sem Flutter, sem canal —, então o caso “sim/não/outra coisa” é testável
  sem emulador.
- **`voice_conversation_page.dart`**:
  - `_enviar` consulta o decisor depois dos comandos Android e antes da IA;
  - `_pedirConfirmacaoTela` registra o pedido, mostra a pergunta, fala e guarda o
    toque pendente;
  - `_executarNaTela` executa o comando, limpa a pendência e registra o
    resultado no histórico;
  - `_cancelarToque` encerra a pendência, avisa e registra a recusa;
  - `_concluirComando` foi dividido em `_concluirLocal`, para o comando Android e
    a ação de tela usarem o mesmo limite de cinco comandos e o mesmo histórico;
  - cartão de confirmação com `confirmar-toque-tela` e `cancelar-toque-tela`;
  - o botão “Regenerar resposta” some enquanto a confirmação está aberta.
- **Injeção para teste**: a página aceita `tela: AcessibilidadeService`, como já
  aceitava voz, histórico e habilidades.

## 4. Testes e verificações

- `flutter analyze` limpo.
- `flutter test`: 285 testes verdes (5 novos em `conversa_tela_test.dart`):
  1. tocar pede confirmação e **não** chama o Android antes do “sim”;
  2. “não” cancela e nada é tocado;
  3. “ler a tela” executa direto, sem confirmação;
  4. sem consentimento, o toque é recusado antes de perguntar;
  5. “como tocar violão” não vira ação de tela.
- Contrato `tests/test_acessibilidade.py` ampliado para o ajuste 096.

## 5. Limites honestos

- **Nada compilado**: sem Android SDK e sem aparelho nesta sessão; o primeiro
  teste real é o APK instalado com o serviço autorizado.
- **Confirmação falada depende do reconhecimento**: se o “sim” não for
  reconhecido, o botão na tela continua valendo — não há confirmação por
  palavra-chave própria.
- **Toque por texto**: se dois botões têm o mesmo texto, vale o primeiro
  encontrado; não há desambiguação por posição nesta versão.
- **Não executa em segundo plano**: a ligação é com a conversa aberta. Com o app
  fechado, o caminho de segundo plano continua respondendo só o que já existia.
