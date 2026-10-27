# J.A.R.V.I.S. Nova 1.15.0

Esta versão (1.15.0) acrescenta o **estilo de núcleo em plasma** — um anel de energia irregular com
animação própria, no desenho da imagem de referência — escolhido em **Ajustes ▸ Voz ▸ Aparência do
núcleo**, ao lado do HUD técnico que continua sendo o padrão. A troca vale na hora, fica salva e a
abertura nasce com o mesmo estilo. A animação reage ao nível do microfone (como as ondas de voz),
pausa com a tela fora de vista e respeita “reduzir movimento” do sistema.


Esta versão (1.14.0) acrescenta a **escuta contínua pela transcrição da Groq** (opcional, com o app
aberto) ao detector próprio que já funcionava em segundo plano, o **menu Informações** com dados do
aparelho, clima e manchetes, a **conversa em tela própria** com o histórico inteiro e rolagem
correta, o fim das **mensagens e falas duplicadas** (portão de eco único no núcleo) e um **conjunto
de animações** que se combina entre as telas (verificação do sistema, ondas de voz e transições).

A escuta pela Groq exige a chave da Groq (Ajustes ▸ IA), roda com o aplicativo aberto, consome cota
de transcrição e envia o áudio para fora — ela é desligada por padrão. Em segundo plano quem ouve é
o detector do Android, sem chave e sem enviar áudio. Para ligá-la: Ajustes ▸ Voz ▸ “Ouvir pela
transcrição da Groq”. O botão “Testar a transcrição da Groq” grava 2,5 s, transcreve e diz se a
palavra de ativação foi reconhecida, sem executar nenhum comando.



## Novidades da 1.13.0 — detector próprio, motor roteado e visão pela câmera
- **Picovoice saiu do projeto.** Não há mais SDK de palavra de ativação, AccessKey nem
  dependência de terceiro para ouvir. A ativação é um **detector próprio**: o reconhecimento do
  Android transcreve em sessões curtas e as regras de fonética locais decidem — 26 variantes
  conhecidas (“javis”, “charvis”, “garvis”, “jarviz”…), tolerância a sotaque por distância de
  edição, comparação pelo esqueleto consonantal e tolerância que só vale para palavras da
  família “jarv-” (é o que impede “jardim” e “jargão” de acordar o assistente). As mesmas regras
  rodam no serviço (`JarvisAtivacao.java`) e no WebView (`Hermes.ativacao`), conferidas por teste.
- **Calibragem na mão do usuário.** Slider de sensibilidade (0–100) e campo de palavras extras
  (“nova”, um apelido, o seu jeito de falar). Mais sensível = aceita resultado parcial e responde
  antes de a frase terminar; menos sensível = exige a palavra quase perfeita, melhor com televisão
  ligada. Há ainda o **porteiro de ruído** por nível de áudio: transcrição que aparece com o som
  baixo demais é descartada, e o diagnóstico mostra quantas foram descartadas.
- **Roteador de motores de IA no núcleo.** `Hermes.planejarIA()` escolhe entre Groq, Cerebras,
  Mistral e Gemini por tipo de tarefa (conversa curta, raciocínio, pesquisa/atualidade, imagem),
  pela **latência realmente medida** no seu aparelho (média móvel), pelas falhas recentes e pela
  disponibilidade. O segundo colocado da fila é o fallback automático em erro, cota ou tempo
  esgotado, e cada tipo de tarefa tem seu tempo-limite (12 s para pergunta curta).
- **Câmera que reconhece objetos.** O painel **Visão** abre a câmera ao vivo; ao tocar em
  analisar, UM quadro é enviado ao provedor que enxerga imagens e cada objeto reconhecido ganha
  um **balão sobre a própria imagem** — toque no balão para ouvir o detalhe. Nada de vídeo
  contínuo e nada em segundo plano: fechar o painel desliga a câmera. Por voz: “o que você está
  vendo?”.
- **Diagnóstico ampliado.** Além de microfone, voz, IA local, rede e permissões, o diagnóstico
  agora confere **câmera**, **chaves** e **motores de IA** (com a latência medida de cada um e a
  última escolha do roteador). Continua disponível por voz: “verifique o sistema”.
- **Conversa mais legível.** A área de mensagens ganhou balão de carregamento animado (o estado
  explícito entre perguntar e ouvir), espaçamento consistente, melhor contraste e rolagem que não
  puxa a tela enquanto você lê acima.
- **Humor seco documentado.** O prompt de sistema agora descreve o sarcasmo seco, irônico e
  levemente debochado com limites explícitos: nunca rude, nunca sobre pessoas, aparência,
  religião ou tragédia, e suspenso por completo em assunto sensível ou urgente. As frases
  próprias do app ganharam variantes novas (visão sem resultado, troca de motor).
- Versão 1.13.0 (versionCode 10130), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI:
  instala por cima da 1.12.0 e é atualizável pelo próprio app.

## Novidades da 1.12.0 — Hermes no comando do dia
- **Núcleo Hermes Agent.** Toda resposta passa por um motor único, que decide a rota em ordem:
  habilidade própria do núcleo → comando resolvido no aparelho → IA. O núcleo é um arquivo só
  (`hermes.js`), sem DOM: o aplicativo injeta o que ele pode usar. "Bom dia" e os comandos do
  dia a dia deixaram de gastar chamada de IA.
- **Briefing diário.** No primeiro "bom dia" do dia ele fala a **temperatura atual** e as
  **manchetes do momento** (buscadas em paralelo); depois disso cumprimenta curto. Em modo
  offline avisa e não consulta nada.
- **Autodiagnóstico por voz.** "Verifique o sistema" confere núcleo, reconhecimento de voz,
  síntese (incluindo a voz neural, quando baixada), IA local, rede/CORS, chaves e permissão de
  microfone — e responde falando o que passou e o que está pendente.
- **Abertura com reconhecimento de voz.** A animação de inicialização só conclui e libera as
  demais opções do app quando reconhece a sua voz. Sem perfil cadastrado (ou com a conferência
  desligada), roda só a animação inicial. Há botão de continuar sem reconhecer e limite de 25
  segundos: a tela nunca fica presa.
- **Decisão conferida.** Se a IA inventar uma ação que não existe (ou que não funciona nesta
  plataforma), ela é descartada e a fala é ajustada — o assistente não anuncia o que não vai
  fazer.
- **Animação mais fluida.** As camadas do núcleo agora são compostas na GPU e as transições de
  estado usam só `transform`/`opacity`.

Versões anteriores: 1.11.0 (streaming, humor por contexto), 1.10.0 e 1.10.1 (segundo plano), 1.9.0 (voz neural).

## Novidades da 1.11.0 (histórico) — mais rápido e com humor de contexto
- **Resposta em streaming**: a fala começa assim que o texto falado está pronto, sem esperar a IA terminar de gerar o resto. Se o provedor não cooperar, o app volta ao pedido completo sozinho.
- **Menos espera**: a conexão com a IA e o motor de voz são aquecidos enquanto você ainda está falando.
- **Tom do turno**: com pressa ele responde curto e seco; em assunto sensível o humor desaparece.
- **Travamentos corrigidos**: falha ao abrir o microfone não deixa mais o app preso em "ouvindo", e voltar ao primeiro plano religa a ativação na hora.

Versões anteriores: 1.10.0 e 1.10.1 (correções do segundo plano).

## Correções da 1.10.1 — segundo plano estável

Revisão sem funcionalidade nova, só os defeitos que derrubavam ou travavam o serviço:
o player de música não promovia o serviço a primeiro plano (o Android matava o processo
ao pedir "pausar" sem faixa tocando); o alarme rápido do vigia era sobrescrito pelo
periódico; a escuta ficava em "espera" para sempre se o app fosse fechado no meio de um
comando; falha fatal mantinha notificação e primeiro plano eternos; lembretes não eram
restaurados após reiniciar no Android 12+; e interface/serviço discordavam quando o
Android recusava primeiro plano. Detalhes técnicos no `CHANGELOG.md`.

## Destaques da 1.10.0 — obedece de verdade e com personalidade própria

- **Personalidade num só lugar.** `PERSONALIDADE`, no topo do `app.js`, guarda identidade, papel,
  traços, lealdade, tratamento, conversa, humor e limites. O prompt de sistema (nuvem e modelo
  local) é montado a partir dele: mudar o jeito do J.A.R.V.I.S. é editar um bloco. A palavra de
  ativação não depende disso e continua funcionando igual.
- **A voz é analisada em voz alta.** Na ativação ele **fala** “Analisando sua voz, senhor. Um
  instante.”, grava 4 s depois da própria fala e compara com o perfil salvo — já vem ligada para quem tem perfil cadastrado. A conferência é
  exigida **uma vez por sessão** (primeiro acesso e depois de ligar o celular); há um seletor
  “Quando conferir a voz” para quem preferir em toda ativação.
- **“Ligue para X” completa a chamada.** `ACTION_CALL` com a permissão Telefone, pedida na hora.
  Sem permissão (ou em tablet sem telefonia), abre o discador e **diz** que não completou.
- **“Coloque a música This I Love” começa a tocar.** O app procura o arquivo na biblioteca do
  aparelho (MediaStore, sem acento e sem depender da ordem das palavras) e toca num serviço em
  primeiro plano, com notificação, controles de tela bloqueada e `MediaSession`. Não existindo o
  arquivo, abre a busca do streaming e avisa que ali o toque no resultado é seu — nenhum app de
  streaming inicia faixa sem conta autenticada, e fingir isso seria mentira.
- **Economia em segundo plano.** Fora da tela, o reconhecimento do WebView e a fala param; só o
  serviço nativo fica esperando “Jarvis”.
- **Exceção não fecha mais o app.** Erros de JavaScript viram aviso e registro; a IA local confere
  memória antes de carregar o modelo, transformando `OutOfMemoryError` em mensagem.

## Destaques da 1.9.0 — voz neural no próprio aparelho

O APK agora embarca o **sherpa-onnx 1.13.8** (Apache-2.0) com ONNX Runtime e espeak-ng. Os
modelos de voz **não** vão no pacote: você baixa a voz que quiser uma única vez, ela fica no
armazenamento privado do app e depois fala **sem internet e sem chave de API**.

| Voz | Tamanho | Timbre medido | Velocidade medida | Licença |
| --- | --- | --- | --- | --- |
| **Cadu** (Piper, pt-BR) | 67 MB | 127 Hz — masculina grave | RTF 0,06 (~17× tempo real) | CC0 |
| **Faber** (Piper, pt-BR) | 67 MB | 155 Hz — masculina clara | RTF 0,06 | CC0 |
| **Kokoro** (inglês) | 132 MB | bm_fable 129 Hz · bm_george 145 Hz | RTF 1,2–1,5 (mais lenta) | Apache-2.0 |

- **Slider “Profundidade da voz neural”** (0,70–1,10; padrão 0,90): abaixo de 1,00 a fala fica
  mais grave **e** mais lenta — a cadência do filme.
- **Sempre opcional:** o seletor começa em “Desligada”. Se o motor faltar, a voz não estiver
  baixada ou a síntese falhar, a resposta sai pela voz normal do Android.
- **Kokoro fala inglês.** `en-gb` não existe no espeak-ng empacotado (síntese volta vazia), então
  o app usa `en`: o timbre britânico vem do falante, o sotaque é americano.
- **Detector de palavra-chave do sherpa-onnx continua fora:** o único modelo público é em inglês
  (medido na 1.7.0: 1 de 4 acertos em português). A aba Voz explica isso na tela.
- **APK maior:** as bibliotecas nativas ARM somam ~53 MB (total ~72 MB). Nada além do APK é
  baixado até você escolher uma voz.

## Destaques da 1.8.0 — detector que entende o que o Android transcreve

Medi o problema em vez de adivinhar: com voz masculina brasileira, o transcritor de português
escreve “Jarvis” como **“já vi”**, **“aviso”**, **“javis”** ou **“charvis”** — o nome não existe no
vocabulário dele. O detector grátis agora pede 5 hipóteses, confere todas, aceita essas variantes e
usa sessões de até 15 s, o que também acaba com o microfone abrindo e fechando toda hora.

- **Botão “Desligar escuta em segundo plano”** em Ajustes ▸ Voz: encerra serviço, microfone e vigia.
- **A voz salva não muda sozinha** ao fechar e reabrir o app; só troca se a voz sair do aparelho.
- **Perfil “Jarvis completo”** (tom 0,55 / velocidade 0,88) e guia para instalar uma voz masculina
  brasileira offline (Piper/SherpaTTS, `pt_BR-faber` ou `pt_BR-cadu`).
- **IA mais conversadora e bem-humorada:** fio da conversa, pergunta de esclarecimento, pesquisa com
  fontes primárias e humor seco a partir de 40%.
- **Nenhum motor novo do Picovoice foi embarcado:** sherpa-onnx não tem modelo de português,
  openWakeWord tem pesos CC BY-NC-SA e DaVoice depende de modelo licenciado.


Assistente pessoal para Android (Capacitor + WebView), com versão desktop Electron opcional.
Aplicativo independente com `com.jarvis.nova`. O código-fonte fica **na raiz do repositório**
(o workflow ainda aceita `JARVIS-NOVA-*-fonte.zip` por compatibilidade).

## Correção da 1.7.2 — atualizador instalando de novo

O “Baixar e instalar” falhava com `Failed to find configured root that contains
/data/data/com.jarvis.nova/files/updates/jarvis-update.apk` porque existiam **dois** `FileProvider`
com a mesma authority — o do template do Capacitor (`@xml/file_paths`, sem `files/`) e o nosso.
Agora o patch remove os existentes e deixa um único apontando para `@xml/jarvis_paths`
(`files-path updates/`). Instale a 1.7.2 uma vez pelo release; depois o botão volta a funcionar.

## Correção da 1.7.1 — assinatura fixa

Release 1.6.0 e 1.7.0 saíram com assinaturas de debug diferentes entre si, porque o Gradle
do CI não usava o keystore copiado para `~/.android`. A 1.7.1 declara a assinatura em
`patch_gradle.py` (`signingConfigs.debug` → `ci/debug.keystore`), com teste de regressão, e foi
verificada com `HOME` limpo: certificado `04e04712…`, o mesmo do APK instalado. Se a instalação
da 1.7.1 for recusada, é porque a versão instalada veio de um daqueles releases antigos —
desinstale uma vez (perde os ajustes salvos) e, a partir da 1.7.1, as próximas instalam por cima.

## Destaques da 1.7.0 — voz de cinema, Spotify e detector escolhido à mão

- **Motor da palavra de ativação escolhível** em Ajustes ▸ Voz: `Automático`, `Android (grátis)`
  ou `Porcupine`. A escolha é gravada em `JarvisPrefs`, sobrevive ao reinício e o serviço a
  respeita — inclusive reiniciando o detector na hora se você trocar com a escuta ligada.
- **Por que o Sherpa-ONNX/openWakeWord não entraram:** o modelo oficial de KWS do sherpa-onnx foi
  testado aqui e reconhece “Jarvis” em inglês, mas erra a pronúncia em português (1 acerto em 4
  frases com limiar 0,10; nenhum no limiar padrão). O `hey_jarvis` do openWakeWord é treinado em
  inglês e tem licença **CC BY-NC-SA**, que não serve para distribuição comercial. Embutir 50 MB de
  engine que erra a sua fala seria piorar a ativação, então o motor gratuito segue sendo o
  reconhecedor do Android — que entende português e, no Android 12+, roda no dispositivo.
- **Voz estilo filme:** perfis `JARVIS do filme` (tom 0,60, velocidade 0,90) e `Ultra grave`
  (0,50/0,85), além do `Padrão`, no mesmo lugar em que ficam os sliders de ajuste fino.
- **Sinal do HUD:** duas notas curtas antes de cada resposta, opcionais (desligado por padrão).
- **Spotify e mídia:** pausar, continuar, próxima, anterior e volume agora vão pela sessão de
  mídia do Android (funciona com Spotify e YouTube Music); “o que está tocando” responde app,
  faixa e artista; “toca <música>” abre o Spotify na busca, e “abre minhas curtidas” vai direto
  para a biblioteca. Iniciar a faixa sozinho o Spotify não permite — o toque no resultado é seu.

## O que veio da 1.6.0 — segundo plano confiável

- **A escuta sobrevive ao app fechado, ao reinício do serviço e ao reinício do aparelho.**
  O estado desejado (“quero a palavra de ativação ligada”) saiu do `localStorage` e passou a
  viver em `JarvisPrefs`, com a AccessKey do Porcupine **cifrada no Android Keystore**. O serviço
  é `START_STICKY` e, ao ser reiniciado sem comando, retoma a escuta com o mesmo detector.
- **Vigia de recuperação (`JarvisWatchdog`).** Um alarme inexato (`setAndAllowWhileIdle`, sem
  exigir permissão de alarme exato) verifica a cada 15 minutos se o usuário quer a escuta e se o
  serviço está rodando; se o fabricante matou o serviço, ele é reiniciado — o alarme concede a
  isenção temporária que o Android 12+ exige para subir um serviço de microfone a partir do fundo.
  Também dispara depois de o app sair dos recentes (`onTaskRemoved`). No boot, a escuta volta por
  esse mesmo caminho (o Android 14+ não permite serviço de microfone direto do BOOT_COMPLETED).
- **Auto-rearme quando a tela não responde.** Se o Android bloquear a abertura da tela ao ouvir
  “Jarvis”, o serviço volta a ouvir depois de 9 s em vez de ficar mudo até o próximo alarme.
- **Notificação acionável.** A notificação persistente agora tem **“Ouvir agora”** (abre o app e
  já começa a ouvir, sem passar pelo detector) e **“Parar”**. O botão usa `JarvisOuvirReceiver`
  para marcar o pedido, então funciona mesmo com o processo morto.
- **Diagnóstico do segundo plano em Ajustes ▸ Voz.** Consulta real de microfone, notificações,
  otimização de bateria, sobreposição, acesso às notificações, serviço/detector, última ativação,
  último erro e dica específica do fabricante — cada linha com o botão que resolve o problema.
  Comando de voz: “Jarvis, diagnóstico do segundo plano” ou “por que a escuta parou”.
- **Teste da palavra de ativação.** Escuta 20 s, conta as ativações sem abrir o app e mostra o
  detector usado, para medir calibração e falsos positivos no seu aparelho.
- **Atalho de início automático por fabricante** (Xiaomi, Samsung, Motorola, Huawei, Oppo/Realme/
  OnePlus, Vivo, Asus), com fallback para as informações do app quando a tela não é exposta.
- **Lembretes de tarefas.** Tarefa com prazo agora agenda um aviso às 09:00 do dia do prazo,
  reaproveitando o agendador persistente dos alarmes; concluir ou excluir cancela o aviso.
- **Checkbox “Serviço em segundo plano” removido.** Ele podia desligar o serviço com a escuta
  ligada (uma das formas de a ativação parar em silêncio). O serviço agora segue a escuta.

## O que veio da 1.5.x

- **Palavra de ativação sem Picovoice:** sem AccessKey, o detector usa sessões curtas do
  reconhecimento do Android (no Android 12+ prefere o reconhecimento **no dispositivo**). Com
  AccessKey, o Porcupine é o detector preferido por gastar menos bateria.
- **Atualizador honesto:** `releases/latest` responde 404 quando o repositório não tem releases —
  o app procura na lista, explica o motivo real e oferece “Ver releases no navegador”. O APK
  baixado é conferido por SHA-256 quando o GitHub informa o digesto e instalado pelo FileProvider.
- **Reconhecimento de voz com fallback:** o modo offline não é mais forçado; há troca entre
  reconhecedor local e de rede nos códigos 12/13/14 e em falha de rede, com mensagem por código.
- **Perfil acústico recalibrado:** só quadros com fala entram no vetor, comparação por distância
  normalizada, silêncio recusado. A exigência “só obedeça à minha voz” vem desligada por padrão
  (experimental, não é autenticação).
- **Medidor de áudio em dB:** a barra saturava em 100% com qualquer som; agora vai de −60 dB a 0 dB.
- **Ações por voz:** lanterna, brilho, painel de notificações, volume por stream e percentual,
  e-mail, fechar app, versão instalada, verificar/atualizar, piada e apps novos.
- **Cérebro local básico**, humor configurável e central de comando com dashboard.

## Gerar APK

Faça push na `main` com os fontes na raiz (ou envie `JARVIS-NOVA-*-fonte.zip` na raiz). O workflow
`.github/workflows/build-apk.yml` fixa a assinatura de CI, executa `npm run test:all`, configura a
API mínima 26, baixa o AAR do sherpa-onnx (`baixar_sherpa.py`), aplica permissões/versão e compila o
APK debug (artefato `JARVIS-Nova-1.13.0-APK`).

Para **publicar um release** (o que o atualizador procura), crie uma tag `v1.13.0`: o workflow
`.github/workflows/release-apk.yml` compila, testa e publica o APK com checksum. Também é possível
executar o workflow manualmente pelo painel de Actions.

Passo a passo do build também em `TESTES.md` e `GUIA-ACESSOS-ANDROID.md` (permissões).

## Instalar e atualizar pelo próprio aparelho

1. Abra o release **v1.13.0** no GitHub pelo navegador do celular e baixe
   `jarvis-nova-1.13.0-10130.apk` (e, se quiser conferir, o `.sha256` ao lado).
2. Toque no arquivo baixado. O Android pede para permitir “instalar apps desconhecidos” para o
   navegador — autorize só para ele, instale e depois pode revogar.
3. Na primeira instalação ele pede microfone, notificações e contatos; a permissão **Telefone**
   (para completar a ligação) e **Música e áudio** (para achar as faixas) são pedidas na primeira
   vez que você usa cada comando, não na abertura.
4. Nas próximas versões, nem é preciso baixar à mão: diga **“Jarvis, verificar atualização”** e
   depois **“atualizar Jarvis”**. O app baixa do release, confere o SHA-256 e entrega o APK ao
   instalador do Android (é só confirmar a instalação).

> O APK **só instala por cima** se tiver a mesma assinatura. O CI usa sempre `ci/debug.keystore`,
> então todas as releases deste repositório compartilham o certificado `04e04712…` e atualizam
> sem apagar ajustes. Um build feito por você sem esse keystore tem outra assinatura e o Android
> vai recusar a atualização (é preciso desinstalar antes, perdendo os dados do app).

### Gerar a chave de assinatura (só se ainda não existir)

```bash
keytool -genkeypair -v -keystore ci/debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=JARVIS Nova, O=Jarvis, C=BR"
```

O `patch_gradle.py` já aponta a assinatura de debug para `ci/debug.keystore`; o workflow copia esse
arquivo para `~/.android/debug.keystore` antes de compilar. **Guarde o keystore** (e a senha) junto
do projeto: perder o arquivo significa não conseguir mais atualizar o app instalado. Para conferir a
assinatura de um APK: `keytool -printcert -jarfile app-debug.apk | grep SHA256`.

## Limites e privacidade

- O detector analisa áudio local enquanto estiver habilitado; o indicador de microfone do Android
  pode permanecer ativo. O detector livre consome mais bateria que o Porcupine.
- A AccessKey do Picovoice fica cifrada no Keystore. Se o Keystore for invalidado (restauração de
  backup ou troca de senha), a chave é descartada e o serviço volta ao detector livre — basta colar
  a chave de novo.
- O Android não concede controle irrestrito de outros apps: fechar é pela tela de detalhes,
  mensagens/e-mail/ligações passam por confirmação e o painel rápido usa uma API oculta que alguns
  fabricantes bloqueiam (nesse caso ele abre as Configurações e avisa).
- Perfil de voz é comparação de timbre, não biometria; não use para autorizar nada sensível.
- Temperatura significa a leitura que o sistema reporta para a bateria.
- O vigia usa alarme inexato: a recuperação pode levar até ~15 minutos. Ele não contorna a
  otimização de bateria nem o “início automático” — para isso existem os atalhos no diagnóstico.

## Estado real

- `npm run test:all`: sintaxe, validador do projeto, roteamento de voz, IA local, perfil de voz,
  cofre de chaves, responsividade, navegação por painéis, os 34 testes de recursos da 1.5.0, os 15
  da 1.8.0 e os **25 da 1.9.0** (`tests/test_v1_9_0.py`), que conferem o plugin nativo, o catálogo
  de vozes, as dependências de build, a extração segura do .tar.bz2 e o caminho de fala.
- **Build local da 1.9.0 verificado:** `assembleDebug` com JDK 17 + SDK 34 gerou 72.623.658 bytes
  (`sha256 56b48ff9…`), versão 1.9.0/1900, ABIs `arm64-v8a` e `armeabi-v7a`, com
  `JarvisVozPlugin`, `OfflineTts` e `BZip2CompressorInputStream` presentes no DEX. O APK do
  release é recompilado pelo CI com a chave de `ci/debug.keystore`.
- **Compilação Android real desta revisão concluída**: JDK 17 + Android SDK 34, `assembleDebug`
  gerou `app-debug.apk` (~18 MB) com `com.jarvis.nova`, minSdk 26, assinado com `ci/debug.keystore`.
- O release no GitHub ainda precisa ser criado (tag `v1.6.0`) para o atualizador encontrar o APK.

**Ainda precisa de teste em aparelho físico** (não é possível validar em CI): taxa de falso
positivo da palavra “Jarvis”, consumo de bateria com a tela bloqueada, comportamento do microfone
em segundo plano por fabricante (Xiaomi/Samsung/Motorola são os mais restritivos), recuperação do
serviço depois de o app ser removido dos recentes e depois de reiniciar o aparelho, “Ouvir agora”
na notificação e a instalação de atualização pelo FileProvider. O APK debug não substitui uma
versão de produção assinada para distribuição.
