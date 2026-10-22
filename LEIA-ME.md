# J.A.R.V.I.S. Nova 1.6.0

Assistente pessoal para Android (Capacitor + WebView), com versão desktop Electron opcional.
Aplicativo independente com `com.jarvis.nova`. O código-fonte fica **na raiz do repositório**
(o workflow ainda aceita `JARVIS-NOVA-*-fonte.zip` por compatibilidade).

## Destaques da 1.6.0 — segundo plano confiável

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
API mínima 26, aplica permissões/versão e compila o APK debug (artefato `JARVIS-Nova-1.6.0-APK`).

Para **publicar um release** (o que o atualizador procura), crie uma tag `v1.6.0`: o workflow
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
  cofre de chaves, responsividade, navegação por painéis, os 34 testes de recursos da 1.5.0 e o
  novo `tests/test_segundo_plano.py`.
- **Compilação Android real desta revisão concluída**: JDK 17 + Android SDK 34, `assembleDebug`
  gerou `app-debug.apk` (~18 MB) com `com.jarvis.nova`, minSdk 26, assinado com `ci/debug.keystore`.
- O release no GitHub ainda precisa ser criado (tag `v1.6.0`) para o atualizador encontrar o APK.

**Ainda precisa de teste em aparelho físico** (não é possível validar em CI): taxa de falso
positivo da palavra “Jarvis”, consumo de bateria com a tela bloqueada, comportamento do microfone
em segundo plano por fabricante (Xiaomi/Samsung/Motorola são os mais restritivos), recuperação do
serviço depois de o app ser removido dos recentes e depois de reiniciar o aparelho, “Ouvir agora”
na notificação e a instalação de atualização pelo FileProvider. O APK debug não substitui uma
versão de produção assinada para distribuição.
