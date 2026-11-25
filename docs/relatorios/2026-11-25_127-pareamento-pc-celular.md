# Bloco 127 — Etapa 3 do PC: pareamento PC ↔ celular

## O que foi entregue

- **Descoberta por IP manual** (a opção que o roteiro permite): a tela do
  celular mostra os endereços IPv4 da rede local com a porta do canal; o PC
  tem um campo para digitar `IP` ou `IP:porta`.
- **Código de 6 dígitos mostrado no celular**, com prazo de 2 minutos, cinco
  tentativas e botão de gerar outro. O código nunca vai pela rede e não é
  gravado em disco.
- **Canal autenticado só de leitura**: `GET /jarvis/info` devolve o desafio;
  `POST /jarvis/parear` recebe a prova HMAC-SHA256 e devolve o token uma única
  vez; `GET /jarvis/status` exige `Authorization: Bearer <token>`;
  `POST /jarvis/esquecer` revoga. Não existe rota de comando nesta etapa.
- **Registro no PC** em `userData/pareamento-celular.json`, com o botão
  “Esquecer este celular”, que avisa o celular e apaga o registro local.
- **Painel** com o formulário na seção “Status do celular”; pareado, ele lê o
  status pelo canal e desenha com a mesma regra das duas seções (Etapa 1).
- **Celular**: módulo “Pareamento Windows” deixou de ser “não existe” e virou
  **parcial** — tem tela, pareia e só lê; controle remoto continua fora.

## O protocolo, em uma frase por passo

1. O celular sorteia `código` (6 dígitos) e `desafio` (16 bytes) e abre o
   servidor em `0.0.0.0:47600`.
2. O PC recusa qualquer endereço fora da LAN **antes** de abrir conexão.
3. O PC lê `{nome, desafio, expiraEmSegundos}` — nunca o código.
4. O PC manda `HMAC-SHA256(código, desafio)` e o nome do computador.
5. O celular compara em tempo constante; erro gasta tentativa, cinco erros
   queimam a oferta.
6. Acerto gera um token de 32 bytes (64 hex), guardado só no registro do PC;
   o celular mantém em memória.
7. Cada leitura de status confere o token em tempo constante. “Esquecer” zera
   o registro dos dois lados.

**Por que HMAC e não o código direto:** quem escuta a rede vê um hash de uso
único por desafio; não consegue reutilizar para parear outro PC nem descobrir o
código. O token não aparece em log.

## Nada sai da rede local

- O celular **só escuta**; não faz nenhuma conexão de saída (`dart:io`
  `HttpServer`, sem `package:http`, sem `https://` no serviço).
- O servidor recusa pedido cujo endereço de origem não seja loopback ou faixa
  privada (10/8, 172.16/12, 192.168/16, 169.254/16, fe80::/10, fc00::/7).
- O cliente do PC recusa `8.8.8.8` e nomes de domínio antes de qualquer
  requisição — o teste usa um `fetch` espião e confirma zero tentativas.

## Testes (o que rodou de verdade)

- `tool/pareamento_test.dart`: código, formatação, prova com vetor fixo
  (`f6ced6…d2e4`, conferido contra `hmac` do Python), token, prazo,
  tentativas, registro e faixas de rede.
- `tool/pareamento_rede_test.dart`: **celular real em 127.0.0.1** e PC
  simulado por `HttpClient` — oferta, código errado (403 + tentativa), prova
  certa, token, status sem token (401), status com token, POST no status
  (404), esquecimento, expiração (410) e cinco erros queimando a oferta.
- `tests/test_pareamento_pc.js`: **cliente do PC real** contra celular falso em
  Node — regras, prova igual à do Dart, recusa fora da LAN sem tocar a rede,
  arquivo corrompido, pareamento, status, revogação e esquecimento.
- `tests/test_pareamento_painel.js`: 36 verificações de DOM — formulário,
  ordem dos scripts, validação, estado vazio honesto e as quatro ações nativas.
- `test/pareamento_page_test.dart`: 4 testes de tela — código formatado,
  endereço, estado pareado e esquecer.
- `flutter analyze` limpo; `flutter test` e a suíte Python completos rodados
  antes de fechar o bloco.

## Limites declarados

- **Sem TLS.** O canal é HTTP na LAN, como o roteiro pedia (“canal
  autenticado”, não “canal criptografado”). Em rede de confiança, o risco é
  escuta passiva; o código não trafega e o token é revogável. TLS com
  certificado próprio fica para a etapa de controle, se for necessário.
- **O canal só existe com a tela aberta.** Não há serviço de primeiro plano
  nesta etapa: fechar a tela fecha o servidor e o PC perde a leitura até abrir
  de novo. Manter de pé em segundo plano é decisão da Etapa 6, junto com a voz.
- **Sem mDNS.** A escolha é IP manual, como o roteiro autoriza; descoberta
  automática pode entrar depois sem mudar o protocolo.
- **Nada foi testado em aparelho Android nem em PC físico.** A prova é de
  protocolo e de integração local; o pareamento real entre dois aparelhos é o
  primeiro item do roteiro de teste em hardware.
