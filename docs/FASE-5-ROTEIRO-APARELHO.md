# Roteiro de verificação no aparelho — atalhos, widget e compartilhar (Fase 5)

Para o APK debug do CI (`jarvis-flutter-android-debug`). Leva uns 15 minutos. O objetivo é
conseguir dizer, para cada item, **o que era esperado, o que aconteceu e quanto tempo levou** —
não basta “funcionou”.

## Antes de começar

1. Baixe o artefato `jarvis-flutter-android-debug` do run mais recente do workflow
   “Flutter native UI validation”.
2. Instale com `adb install -r app-debug.apk` (ou copie o APK para o aparelho e abra).
3. Abra o app uma vez e configure um provedor de IA, para a conversa ter o que responder.
4. Deixe as opções de desenvolvedor ligadas, se quiser medir abertura com `adb shell am start -W`.

## 1. Identidade

- [ ] O app aparece como **J.A.R.V.I.S. Nova**, com o ícone normal.
- [ ] Abre sem fechar sozinho.

Anote: nome exibido, tempo até a tela principal, qualquer aviso na abertura.

## 2. Atalhos do ícone

Toque longo no ícone do app na gaveta ou na tela inicial.

- [ ] Aparecem **três** atalhos: “Falar com o Jarvis”, “Nova conversa” e “Histórico”.
- [ ] “Falar com o Jarvis” abre o modo voz em tela cheia.
- [ ] “Nova conversa” abre a conversa vazia (com o rascunho, se houver).
- [ ] “Histórico” abre a lista de conversas; se estiver vazia, mostra a mensagem de vazio.
- [ ] Repita cada um **com o app fechado** e **com o app já aberto**.

Anote, por atalho: abriu a tela certa? (sim/não) · tempo até a tela · o app já estava aberto? ·
alguma tela apareceu duas vezes?

Se um atalho não aparecer, teste o mesmo pedido por comando, para separar atalho de navegação:

```
adb shell am start -a com.jarvis.nova.ACAO_VOZ -n com.jarvis.nova/.MainActivity
adb shell am start -a com.jarvis.nova.ACAO_CONVERSA -n com.jarvis.nova/.MainActivity
adb shell am start -a com.jarvis.nova.ACAO_HISTORICO -n com.jarvis.nova/.MainActivity
```

Anote: o comando abriu a mesma tela que o atalho deveria abrir?

## 3. Widget

- [ ] Toque longo na tela inicial → Widgets → encontre o widget do JARVIS e adicione.
- [ ] Antes de abrir o app, o widget mostra **“JARVIS pronto”** (estado neutro, sem inventar
      que está tudo certo).
- [ ] Abra o app e inicie a escuta do KWS; volte para a tela inicial: o texto do widget muda
      para o estado real (`KWS ESCUTANDO`, `KWS COM FALHA`, etc.).
- [ ] Toque em **FALAR**: abre o modo voz.
- [ ] Toque em **CONVERSA**: abre a conversa.
- [ ] Reinicie o aparelho: o widget volta com o último estado, sem travar o launcher.

Anote: texto mostrado antes e depois · botão que abriu o quê · tempo de resposta ao toque ·
o widget sumiu ou ficou desatualizado depois do reinício?

## 4. Compartilhar a conversa (de dentro do app)

- [ ] Converse uma vez (ou use “Nova conversa” e escreva algo).
- [ ] Toque no ícone de compartilhar no topo da conversa.
- [ ] A folha de compartilhamento do Android abre; escolha um app (Notas, Mensagens ou e-mail).
- [ ] O texto chega com as falas identificadas (“Você: …” / “J.A.R.V.I.S.: …”).

Anote: a folha abriu? · o texto chegou completo? · algum app recusou o conteúdo?

## 5. Receber texto compartilhado (de fora para o app)

- [ ] Em outro app (Chrome, Notas), selecione um texto e escolha **Compartilhar → J.A.R.V.I.S.
      Nova**.
- [ ] O app abre na conversa com o texto já no campo.
- [ ] Envie e confira se a resposta usa esse texto.
- [ ] Repita com o app já aberto em outra tela.

Anote: abriu a conversa certa? · o texto veio inteiro? · o campo ficou editável? · abriu duas
telas?

Alternativa por comando:

```
adb shell am start -a android.intent.action.SEND -t text/plain \
  --es android.intent.extra.TEXT "teste de compartilhamento" \
  -n com.jarvis.nova/.MainActivity
```

## 6. Casos ruins (o que não pode acontecer)

- [ ] Negue a permissão de microfone e toque em FALAR: a tela **não** pode dizer “Ouvindo”.
      Deve mostrar o estado real e explicar o que falta.
- [ ] Sem provedor configurado, envie uma mensagem: o texto do usuário é preservado e aparece um
      aviso, sem resposta inventada.
- [ ] Gire o aparelho depois de abrir um atalho: o mesmo pedido **não** pode ser repetido.

Anote: o que a tela mostrou · a mensagem explicou o motivo? · algo foi perdido?

## Ficha para preencher

| Item | Esperado | Observado | Tempo | Print |
|---|---|---|---|---|
| Abertura do app | tela principal | | | |
| Atalho Falar (fechado) | modo voz | | | |
| Atalho Nova conversa (aberto) | conversa vazia | | | |
| Atalho Histórico | lista | | | |
| Widget neutro | “JARVIS pronto” | | | |
| Widget com KWS ativo | estado real | | | |
| Widget FALAR / CONVERSA | telas certas | | | |
| Compartilhar para fora | texto completo | | | |
| Compartilhar para dentro | conversa preenchida | | | |
| Microfone negado | sem “Ouvindo” | | | |

## Se algo falhar

Registre o item, o que apareceu na tela e o horário, e colete o log do app:

```
adb logcat -d -s flutter:I AndroidRuntime:E > falha-jarvis.txt
```

Isso basta para eu reproduzir a causa sem adivinhar.
