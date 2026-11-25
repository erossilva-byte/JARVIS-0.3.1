# Roteiro — JARVIS no PC

**Estado de partida:** o PC já tem app Electron (`platforms/desktop/main.js`,
`index.html`, módulos JS) na versão 1.46.0, com instalador (`electron-builder`),
arquivos, CAD, projetista, voz e o painel “Status do celular”. O celular é o
Flutter Nova 1.100.0, com 34 telas, voz em segundo plano, apelidos, PIN e
paridade de ações presa em contrato.

**Decisão de base:** manter o Electron como app do PC e trazer as funções do
celular por etapas. Reescrever o PC em Flutter agora jogaria fora o CAD, o
projetista e os utilitários que só existem lá; a decisão de uma base única fica
para o fim da Etapa 3, quando houver números de manutenção.

Cada etapa tem entregável e critério de aceite. Nenhuma etapa muda duas coisas
ao mesmo tempo, e nenhuma depende de aparelho para começar — o que depende de
aparelho fica declarado no fim.

## Etapa 1 — Base de produção e status unificado

**Entregável**
- Modelo de status compartilhado no celular (`lib/core/status_plataforma.dart`),
  lendo o formato do Android e o do PC (`status_pc`) e formatando as duas telas
  com as mesmas regras.
- Roteiro deste arquivo.
- Contrato que prende os campos usados pelo PC e o comportamento honesto
  (campo ausente não vira zero).

**Aceite**
- `dart run tool/status_plataforma_test.dart` verde.
- `tests/test_bloco_124.py` verde, incluindo a checagem dos campos de
  `status_pc` no Electron.
- Nenhuma tela muda de comportamento nesta etapa.

**Por que primeiro:** é o exemplo que o dono pediu (status do PC e do celular) e
a menor peça que já serve às duas plataformas.

## Etapa 2 — Status dos dois lados no app do PC

**Entregável**
- Painel do PC com duas seções: “Status do PC” (real, já existe) e “Status do
  celular”.
- Enquanto não houver pareamento, a seção do celular diz **“sem conexão”** e
  explica o que falta — nada de número inventado.

**Aceite**
- Teste de DOM conferindo as duas seções e o estado vazio honesto.
- Uma única função de formatação para os dois lados (o modelo da Etapa 1).

**Depende de:** Etapa 1.

## Etapa 3 — Pareamento PC ↔ celular

**Estado:** entregue na 1.104.0 — descoberta por IP manual, código de 6
  dígitos no celular, prova HMAC, token de leitura e “esquecer” no PC. Sem
  mDNS, sem TLS e sem serviço de segundo plano; os limites estão no relatório
  `docs/relatorios/2026-11-25_127-pareamento-pc-celular.md`.

**Entregável**
- Descoberta na rede local (mDNS ou lista manual de IP) com código de 6 dígitos
  mostrado no celular.
- Canal autenticado só para leitura de status; sem envio de mensagem nesta
  etapa.
- Registro do pareamento no PC, com opção de esquecer.

**Aceite**
- Dois testes de integração local (PC e celular simulados) e um teste de recusa
  com código errado.
- Nenhum dado sai da rede local.

**Depende de:** Etapa 2. Esta é a primeira etapa que precisa de aparelho para
provar de verdade.

## Etapa 4 — Memória e pessoas no PC

**Estado:** entregue na 1.105.0 — regras da memória portadas para o JS (busca,
  orçamento, citação), Markdown no formato do celular, cofre em pasta com
  conflito preservado, consentimento nas fichas e bloco seguro na conversa. Os
  limites (tema menor no celular, ficha antiga sem consentimento declarado,
  nada medido em PC físico) estão no relatório
  `docs/relatorios/2026-11-25_128-memoria-e-pessoas-pc.md`.

**Entregável**
- Memória em Markdown com busca, citação e sincronização (mesmo formato do
  celular, cofre em pasta escolhida).
- Fichas de pessoas com consentimento e bloco seguro na conversa.

**Aceite**
- Os mesmos testes de regra do celular portados para o JS do PC (busca,
  orçamento, consentimento, ambiguidade).

**Depende de:** Etapa 1.

## Etapa 5 — Segurança no PC

**Estado:** entregue na 1.106.0 — política de PIN, PBKDF2 com vetor fixo,
  espera progressiva, cofre de chaves pelo `safeStorage` (com recusa sem
  proteção do sistema), PIN de visita e modo de visita local. Os limites estão
  no relatório `docs/relatorios/2026-11-25_129-seguranca-pc.md`.

**Entregável**
- PIN de bloqueio com derivação e espera progressiva, cofre de chaves protegido
  pelo sistema (DPAPI no Windows, Keychain no macOS, secret service no Linux).
- Modo visita equivalente ao do celular, com o mesmo prompt e sem dados.

**Aceite**
- Testes de política de PIN, derivação, tentativas e recusa do cofre sem
  proteção do sistema.

**Depende de:** Etapa 4 (cofre).

## Etapa 6 — Voz e segundo plano no PC

**Entregável**
- Palavra de ativação local no PC, escuta sem a janela em foco e fala com a
  mesma voz do celular quando configurada.
- Ações por voz em paridade com a tabela do bloco 122 (o contrato do celular
  serve de lista de conferência).

**Aceite**
- Teste de paridade de ações adaptado ao PC, com a mesma tabela (ambos, só
  tela, sem voz).
- Medição de uso de CPU com a escuta ligada, registrada no relatório.

**Depende de:** Etapa 3 (pareamento) para as ações que tocam o celular.

## Etapa 7 — Empacotamento, atualização e teste em PC real

**Entregável**
- Instalador assinado, atualização com verificação de assinatura, versão e
  changelog no app.
- Roteiro de teste em PC físico: instalar, parear, ouvir, falar, reiniciar,
  atualizar e desinstalar sem deixar lixo.

**Aceite**
- Instalador gerado e instalado em máquina limpa; atualização aplicada e
  revertida; relatório com o que foi medido.

**Depende de:** todas as anteriores.

## Decisão de base única (fim da Etapa 3)

**Decisão: manter o Electron como app do PC.** Os números que sustentam a
escolha, contados no repositório em 25/11/2026:

| Lado | Código | Testes |
|------|--------|--------|
| Celular (Flutter) | 45.497 linhas em `lib/` | 81 testes de widget, 6.858 linhas em `tool/` |
| PC (Electron/JS) | 12.593 linhas em `app.js` + 2.155 em `platforms/desktop` | 65 testes Node |
| Núcleo web compartilhado | 30.256 linhas em módulos JS da raiz | jsdom e Node |

O PC tem CAD, projetista, utilitários, arquivos e empacotamento que só existem
em JS; reescrever isso em Flutter custaria mais do que manter as duas telas, e o
pareamento já provou que protocolo pode ser compartilhado sem base única. A
decisão muda se a Etapa 6 precisar de um modelo de voz que o Electron não
consiga rodar, ou se o custo de manter duas interfaces passar o de uma reescrita
— nenhum dos dois aconteceu ainda.

## O que fica declarado como não feito

- Nenhuma etapa acima foi executada em PC físico nem em aparelho Android; as
  Etapas 1 a 5 têm código e teste local, não medição em hardware.
- O pareamento entre dois aparelhos reais é o primeiro item do roteiro de teste
  em hardware (Etapa 7).
- Funções exclusivas do celular (SMS, ligação, contatos, acessibilidade de tela)
  não serão copiadas para o PC: serão **acessadas pelo pareamento**, na Etapa 6.
