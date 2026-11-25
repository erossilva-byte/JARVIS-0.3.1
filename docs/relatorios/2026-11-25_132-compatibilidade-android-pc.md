# Bloco 132 — compatibilidade Android ↔ PC: protocolo jarvis/2

## O que foi entregue

O pareamento da Etapa 3 já ligava celular e PC, mas o canal só sabia ler status
e o PC não tinha como saber o que aquela versão do celular aceitava. Este bloco
começa a compatibilidade pelos dois pontos que faltavam:

- **Negociação** (`/jarvis/info` e resposta do pareamento): o celular anuncia
  `protocolo: jarvis/2` e `recursos: [status, comando]`. Ausente ou desconhecido
  vira `jarvis/1`, com `[status]` — celular de versão anterior continua
  pareando e lendo exatamente como antes.
- **Canal de comando** (`POST /jarvis/comando`): o PC pede `abrir_tela` e o
  celular abre memória, pessoas, visão, histórico ou conversa pelo mesmo
  `AbrirTela` que a voz usa.
- **Regras em espelho**: `flutter_app/lib/core/comando_remoto.dart` e
  `platforms/desktop/pareamento.js` têm a mesma versão de protocolo e a mesma
  lista de ações; o contrato compara as duas.
- **Tela do PC**: bloco “Comandos” no painel do celular, com os botões
  desabilitados quando o celular pareado é antigo, explicando por quê.

## Ordem das recusas do celular

Token (401) → protocolo (400) → formato do `id` (400) → prazo de 60 s (409) →
`id` repetido em 5 min (409) → ação fora da lista (422) → ritmo, 1 s entre
comandos e 20 por minuto (429). O corpo só é lido **depois** do token.

## Testes (o que rodou de verdade)

- `tests/test_comando_remoto.js`: cliente do PC **real** contra um celular falso
  em Node. Celular antigo (sem negociação) pareia e recusa comando **sem tocar a
  rede**; celular jarvis/2 negocia, executa `abrir_tela`, recusa o mesmo `id`
  duas vezes, recusa comando com hora de 5 minutos atrás, protocolo errado,
  ação desconhecida e token revogado; e o 429 de ritmo chega ao PC como erro
  explicado. Verde.
- `tests/test_bloco_132.py`: contrato estático — lista de ações igual nas duas
  linguagens, protocolo 1 preservado, ordem autenticar-antes-de-ler, IPC, HTML,
  app.js, `test:all` e documentação honesta. Verde.
- `flutter_app/tool/comando_remoto_test.dart`: regras puras, registro de
  `id`s/ritmo e o serviço real em 127.0.0.1 nas duas configurações (com e sem
  executor). **Rodou e passou** com o SDK do Flutter que esta máquina tem em
  `/tmp/flutter` (34 verificações). `flutter analyze` nos arquivos tocados:
  sem avisos.

## Limites declarados

- **Nada foi executado em aparelho Android nem em PC físico.** O pareamento
  real entre dois aparelhos continua sendo o primeiro item do roteiro de
  hardware da Etapa 7.
- Sem TLS: token e `id` trafegam em claro na LAN.
- Uma ação só (`abrir_tela`). Sem conversa remota, arquivos, microfone ou
  qualquer leitura de dado do celular pelo PC.
- O servidor do celular morre com a tela de pareamento; comando depois disso não
  chega.
