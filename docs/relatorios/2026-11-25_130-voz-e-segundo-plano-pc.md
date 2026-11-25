# 130 — Voz e segundo plano no PC (Etapa 6)

**Data:** 25/11/2026 · **Versão:** 1.107.0+110700 · **Bloco:** 130

## O que a Etapa 6 pedia

- palavra de ativação local no PC, escuta sem a janela em foco e fala com a
  mesma voz do celular quando configurada;
- ações por voz em paridade com a tabela do bloco 122;
- aceite: teste de paridade adaptado ao PC e medição de CPU com a escuta
  ligada, registrada no relatório.

## O que já existia

O PC já ouvia de um jeito: microfone aberto, trecho de 2,5 s enviado à
transcrição da Groq e a palavra “Jarvis” conferida **localmente** por
`Hermes.ativacao` antes de qualquer resposta. Havia três furos:

1. o laço parava com `document.hidden` — a janela atrás encerrava a escuta, o
   que contradiz o entregável;
2. ligar a ativação no PC não fazia nada, porque `iniciarWake` dependia do
   serviço do Android e desistia em silêncio;
3. não existia tabela de paridade: ninguém sabia quais ações de voz o PC faz.

E um exagero: quando uma ação era do celular, o PC dizia apenas “ação
indisponível”, sem explicar por quê.

## O que este bloco entrega

### `voz_pc.js` — as regras, em módulo puro

- **Tabela de paridade** com 24 ações em quatro categorias: **13 no PC**
  (hora, clima, abrir app, volume, mídia, e-mail, copiar texto, ligar, WhatsApp
  com mensagem pronta, travar a tela, desligar o PC, status, listar arquivos),
  **3 só com a interface aberta** (ficha de pessoa, consulta à memória, projetos
  e CAD), **7 do celular** (SMS, lanterna, brilho, notificações, acessibilidade
  da tela, agenda, alarme) e **1 sem voz** (compartilhar arquivo, que é gesto).
- **Quando ouvir** (`podeOuvir`): permite a janela fora de foco quando o ajuste
  autoriza; proíbe ouvir com ele gravando, pensando, falando (a própria voz), com
  a tela de bloqueio, no modo de visita ou durante o comando de parada. Toda
  decisão traz um texto para a tela.
- **Qual motor** (`motorDeEscuta`): detector local quando existe; nuvem quando
  há chave — e nesse caso o texto diz, sem rodeio, que o áudio do trecho sai do
  computador; nada quando falta chave ou o modo offline está ligado.
- **Qual voz** (`vozParaPC`): mantém a voz salva quando ela existe, senão escolhe
  uma masculina em português, depois qualquer português, depois uma masculina de
  outro idioma, e **avisa** quando trocou — a prosódia (tom e velocidade) é a
  mesma dos quatro perfis do celular.
- **Medição** (`medirCpu`): mede o laço de quadros com `process.cpuUsage()`,
  declarando que não inclui captura de áudio.

### Ligação no aplicativo

- O laço de escuta passou a consultar `podeOuvir` e **continua com a janela
  atrás no PC**, controlado por “Ouvir com a janela atrás no computador”
  (Ajustes ▸ Voz, visível só no PC).
- `iniciarWake` no PC, sem o serviço do Android, escolhe o motor pela regra: com
  chave, liga a escuta com transcrição e palavra conferida localmente; sem chave
  ou em offline, **explica por que não começou** em vez de não fazer nada.
- A voz do `speechSynthesis` passa por `vozParaPC` e o aviso de troca aparece uma
  vez no chat e no registro.
- Ação do celular pedida no PC agora responde que ligação/SMS/tela são do
  aparelho e que o pareamento é **só de leitura** — que é a verdade do protocolo
  (`GET /jarvis/status` com token; nada de comando).

## Medição de CPU com a escuta ligada

`node tools/medir_cpu_escuta.js 300` processa 300 s de áudio sintético em quadros
de 50 ms (16 kHz, 800 amostras), com fala e silêncio alternados, e confere a
palavra de ativação a cada 2,5 s — o mesmo trabalho do laço real, sem microfone.
Duas execuções nesta máquina (Node no sandbox Linux):

| Execução | CPU total (300 s) | Por minuto de áudio | Por hora | Fração de um núcleo |
|----------|-------------------|---------------------|----------|---------------------|
| 1ª | 19,35 ms | 3,87 ms | 232 ms | 0,006% |
| 2ª | 41,26 ms | 8,25 ms | 495 ms | 0,014% |

A diferença entre as duas é o aquecimento do JIT, não o algoritmo: são 4 a 8
milissegundos de CPU por minuto de áudio, meio segundo por hora no pior caso.
**O que isso não mede:** a captura do microfone (driver do sistema), a
transcrição (rede, quando a nuvem é usada) e o consumo com a janela minimizada
no Windows — nada disso roda nesta máquina.

## Verificações executadas

- `node tests/test_voz_pc.js` — 60 verificações: cada linha da tabela conferida
  contra o código real, cada ação do celular conferida como Android-only, dez
  casos de `podeOuvir`, sete de `motorDeEscuta`, oito de voz e cinco de CPU
  (com relógio e `cpuUsage` injetados, além da medição real).
- `node tools/medir_cpu_escuta.js 300` — números da tabela acima.
- `node --check` em `voz_pc.js` e `app.js`.
- Contrato `tests/test_bloco_130.py` e a suíte inteira (Node e Python) rodados
  antes do commit.

## O que não foi feito, e por quê

- **Não há detector de palavra local no PC.** O Android tem o sherpa-onnx em
  C++; no computador não existe modelo equivalente instalado. O que é local é a
  conferência da palavra; o áudio do trecho vai para a transcrição quando a
  nuvem é usada. A tela e o relatório dizem isso, em vez de chamar de “local”.
- **As ações do celular não são executadas pelo PC.** O pareamento é de leitura
  por projeto (token só para `/jarvis/status`). Levar comando até o aparelho
  exigiria uma rota autenticada de escrita no celular e um teste em dois
  aparelhos — fica para quando houver hardware.
- **A voz real não foi ouvida.** As vozes do `speechSynthesis` dependem do
  sistema; a escolha e o aviso foram testados com listas sintéticas, não com o
  áudio saindo da caixa de som.
- **Nada foi medido em PC físico**: nem driver de microfone, nem janela
  minimizada, nem consumo de bateria (não existe no PC de mesa).
- A escuta com a janela atrás **só funciona com chave de transcrição**. Sem ela,
  o PC continua dependendo do app aberto para ouvir — e agora diz isso.
