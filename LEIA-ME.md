# J.A.R.V.I.S. Nova 1.9.0

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
APK debug (artefato `JARVIS-Nova-1.9.0-APK`).

Para **publicar um release** (o que o atualizador procura), crie uma tag `v1.9.0`: o workflow
`.github/workflows/release-apk.yml` compila, testa e publica o APK com checksum. Também é possível
executar o workflow manualmente pelo painel de Actions.

Passo a passo do build também em `TESTES.md` e `GUIA-ACESSOS-ANDROID.md` (permissões).

## Atualização a partir do app

Instale sempre a partir do release publicado: o APK precisa ter a mesma assinatura do release para
o Android permitir a atualização por cima. Builds locais (`./gradlew assembleDebug` sem copiar
`ci/debug.keystore` para `~/.android/debug.keystore`) têm assinatura diferente.

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
