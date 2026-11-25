# Roteiro de teste em PC físico (Etapa 7)

Este roteiro é o que falta para fechar a Etapa 7: instalar, parear, ouvir,
falar, reiniciar, atualizar e desinstalar **sem deixar lixo**, medindo o que der
para medir. Nada aqui foi executado ainda — é a lista para quem tiver o Windows.

Use uma **máquina limpa** (VM recém-instalada serve) e uma segunda máquina com
Windows "sujo" (com outras versões do app já instaladas) para o teste de
atualização.

## Antes de começar

- [ ] Baixar o instalador e o portátil do mesmo release, mais
      `atualizacao.json` e `atualizacao.json.sig`.
- [ ] Anotar no papel: versão do Windows, edição, RAM, se é VM ou físico, e a
      versão do pacote.
- [ ] Confirmar a digital da chave pública em `platforms/desktop/
      atualizacao-publica.pem` contra a divulgada no release.
- [ ] Ter o app do celular na mesma rede, com "Pareamento Windows" abrindo um
      código de 6 dígitos.

## 1. Instalação em máquina limpa

| Passo | O que se espera | O que anotar |
|---|---|---|
| Rodar o `Setup.exe` | instalador abre; se o Windows mostrar SmartScreen, o texto do release já avisa que não há assinatura | se apareceu aviso, e quantos cliques até instalar |
| Escolher "só para mim" / pasta padrão | instala em `%LOCALAPPDATA%\Programs` sem pedir administrador | pediu elevação? |
| Abrir pelo atalho | janela abre sem tela branca | tempo até a interface aparecer (cronômetro) |
| Conferir Ajustes ▸ Informações | "Versão instalada: X" igual ao pacote; notas da versão listadas | se as notas apareceram |
| Fechar e reabrir | abre na mesma versão, sem perder ajustes | — |

## 2. Pareamento PC ↔ celular

| Passo | O que se espera |
|---|---|
| No celular, abrir "Pareamento Windows" e gerar o código | código de 6 dígitos na tela do celular |
| No PC, digitar IP e código | pareado em menos de 5 s; o painel mostra o nome do aparelho |
| Desligar o Wi-Fi do celular e tocar em atualizar | erro claro de rede, sem travar a interface |
| Esquecer o pareamento no PC | o celular deixa de aceitar; parear de novo funciona |

## 3. Ouvir e falar

| Passo | O que se espera | O que medir |
|---|---|---|
| Ligar a ativação (Ajustes ▸ Voz) | o app diz qual motor está ouvindo e se o áudio sai do computador | — |
| Dizer "Jarvis" com a janela na frente | acorda em menos de 2 s | latência até o bipe |
| Colocar outra janela na frente e dizer "Jarvis" | acorda igual (escuta com a janela atrás) | precisou de ajuste ligado? |
| Falar durante a resposta dele | ele para de falar (barge-in) | interrompeu na primeira sílaba? |
| Pedir "que horas são" | responde com a hora do PC | — |
| Fazer uma pergunta com a chave de IA cadastrada | responde em texto e em voz | tempo da primeira palavra |
| Desligar a rede e repetir | modo offline avisa; comandos locais continuam | — |

## 4. Reiniciar e segundo plano

| Passo | O que se espera |
|---|---|
| Reiniciar o Windows com o app aberto | app não abre sozinho (não é serviço); ao abrir, a escuta volta só se estava ligada |
| Minimizar por 10 min e falar "Jarvis" | continua ouvindo se a escuta em segundo plano estava autorizada |
| Bloquear a tela (Win+L) e falar | **não** deve gravar nem acordar |

## 5. Atualização e reversão

| Passo | O que se espera | O que anotar |
|---|---|---|
| Com a versão anterior, abrir Informações ▸ "Conferir atualização baixada…" e escolher a pasta | "Atualização X verificada: assinatura e hash conferem" | — |
| Escolher uma pasta com o manifesto de outra chave | recusa com motivo `assinatura-invalida` | — |
| Trocar um byte do `.exe` e repetir | recusa com motivo `hash` | — |
| Escolher o pacote da versão já instalada | recusa com `mesma-versao` | — |
| Aplicar a atualização boa | instala por cima; dados do usuário continuam | tempo de instalação |
| Reabrir e conferir a versão | mostra a nova versão, notas novas | — |
| **Reverter**: desinstalar mantendo a pasta de dados e rodar o instalador antigo | volta à versão anterior com os mesmos dados | perdeu algum ajuste? |
| Repetir a atualização | volta a instalar normalmente | — |

## 6. Desinstalar sem lixo

| Passo | O que se espera |
|---|---|
| Desinstalar pela lista de programas | app sai; atalhos somem |
| Conferir `%APPDATA%\J.A.R.V.I.S. Nova` (dados do usuário) | permanece — é assim de propósito, para não perder memória e chaves |
| Apagar manualmente a pasta de dados | nada do app reabre nem recria arquivo fora dali |
| Procurar restos: `%LOCALAPPDATA%\Programs`, Menu Iniciar, tarefas agendadas | nada além do que o instalador criou |
| Reinstalar depois de limpar tudo | volta como instalação nova, sem erro de chave antiga |

## 7. Medições para o relatório

Preencha e cole no relatório da versão:

| Medida | Como | Resultado |
|---|---|---|
| Tempo até a interface abrir | cronômetro | ____ s |
| Latência de ativação | dizer "Jarvis" e contar | ____ ms/s |
| CPU com a escuta ligada | Gerenciador de Tarefas ▸ Detalhes, 5 min parado | ____ % |
| Memória em repouso | Gerenciador de Tarefas | ____ MB |
| Tamanho instalado | pasta de instalação | ____ MB |
| Tempo de atualização | cronômetro | ____ s |
| Aviso do SmartScreen | sim/não + cliques | ____ |

## O que só este teste pode provar

- O instalador NSIS realmente instala e desinstala no Windows (aqui não há
  Windows);
- o `safeStorage` usa DPAPI de verdade (no sandbox o teste usa proteção falsa);
- a captura de microfone e as vozes instaladas existem de fato;
- o aviso do SmartScreen aparece (ou some, com certificado);
- o consumo em repouso com a escuta ligada, que na medição sintética foi de 4 a
  8 ms de CPU por minuto de áudio — só no Windows se mede o total.

Até este roteiro ser executado, a Etapa 7 fica **implementada, não aprovada**.
