# Auditoria técnica — J.A.R.V.I.S. Nova 1.4.1

Data: 2026-10-19

## Alterações desta revisão

- Atualização coordenada da versão para 1.4.1 / versionCode 1401.
- Refinamento visual do HUD: profundidade, anéis, brilho e estados de voz; respeito à preferência de movimento reduzido.
- Melhorias visuais do estado e da autoria das mensagens do assistente.
- Atualização do nome do workflow e do artefato para 1.4.1.
- Documentação explícita das limitações reais da IA local e da palavra de ativação.

## Resultado dos testes

Os testes devem ser executados novamente depois de cada alteração. Testes de sintaxe e testes estáticos não provam que APIs, permissões ou recursos funcionam no Android físico.

## Riscos ainda abertos (não declarar resolvidos)

1. O workflow original substitui o plugin de IA local por um stub, pois a integração MediaPipe atual tem incompatibilidades com JDK/Capacitor. O APK resultante não oferece inferência local real.
2. A palavra de ativação depende de AccessKey Picovoice; não há substituto gratuito local validado nesta revisão.
3. Voz, reconhecimento pt-BR, notificações, alarmes, serviço em segundo plano e ações de telefone exigem teste físico e confirmação de permissões.
4. O APK gerado é debug. Não há configuração de assinatura release nesta revisão.
5. A aparência é refinada por CSS, mas não há gravação ou captura de comparação automatizada com o vídeo de referência.

## Próximos critérios de aceite

- Build CI verde e checksum registrado.
- Instalação em Android real sem crash.
- Testes manuais de microfone, TTS pt-BR, permissões negadas, modo offline, APIs com erro/429, alarmes, notificações, retomada após reinício e economia de bateria.
- Não declarar recurso funcional se estiver apenas visível na interface ou representado por stub.
