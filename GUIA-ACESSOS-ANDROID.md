# Guia de acessos do J.A.R.V.I.S. Nova no Android

Este guia é para a versão 1.3.3, focada no APK Android. O app não deve pedir permissões irrestritas; cada acesso deve corresponder a uma função usada.

## 1. Permissões normais do app

- **Microfone**: necessário para comandos de voz e detector de ativação. Conceda em Configurações > Aplicativos > J.A.R.V.I.S. Nova > Permissões > Microfone.
- **Notificações**: permita para ver o estado do serviço de escuta em versões recentes do Android.
- **Contatos**: conceda apenas se quiser consultar nomes para preparar chamadas/mensagens.
- **Internet**: necessária para provedores de IA, pesquisas e validação inicial da AccessKey. Não implica acesso irrestrito a outros apps.

## 2. Acessos especiais que o usuário habilita manualmente

- **Acesso às notificações**: Configurações > Acesso especial a apps > Acesso às notificações > J.A.R.V.I.S. Nova. Permite ler resumos e usar ações de resposta rápida disponíveis; notificações podem conter dados privados.
- **Alarmes e lembretes exatos**: em Configurações > Aplicativos > Acesso especial > Alarmes e lembretes, permita se o Android solicitar. Sem isso, alguns alarmes podem ser aproximados ou recusados pelo sistema.
- **Bateria sem restrições**: em Informações do app > Bateria, escolha “Sem restrições” somente se quiser que a escuta/serviço continue mais confiavelmente em segundo plano. Isso aumenta o consumo e varia conforme o fabricante.
- **Inicialização automática**: alguns fabricantes oferecem uma opção própria de inicialização automática. Ative-a apenas se desejar restaurar os lembretes/serviços permitidos após reiniciar.

Os nomes dos menus variam por fabricante e versão do Android.

## 3. Ativação por “Jarvis”

A versão 1.3.3 removeu o pacote Android openWakeWord que falhava na resolução do build. A ativação contínua usa Porcupine e requer uma AccessKey Picovoice válida; a primeira validação pode exigir internet. Sem a chave, o microfone manual continua disponível, mas a palavra de ativação contínua não está disponível nesta revisão.

Para segundo plano, habilite a opção correspondente no app e mantenha a notificação persistente do serviço visível. O Android pode bloquear o uso do microfone se o serviço for iniciado em segundo plano sem as condições exigidas; o app deve ser aberto antes de ativar a escuta.

## 4. O que não é necessário conceder indiscriminadamente

- SMS, histórico de chamadas e acessibilidade não devem ser habilitados sem uma implementação e necessidade específicas. Preparar uma mensagem no app de SMS/WhatsApp ou abrir a tela de chamada é diferente de enviar automaticamente ou controlar outro aplicativo.
- Não há permissão capaz de dar controle irrestrito sobre todos os aplicativos, desbloquear o aparelho ou contornar as proteções do Android.

## 5. Validação antes de considerar o APK pronto

1. Instalar o APK em aparelho real.
2. Abrir o app e conceder microfone; testar fala e resposta por voz.
3. Testar contatos, abertura de apps, alarmes e lembretes.
4. Habilitar o acesso às notificações somente se quiser essa função; testar leitura/resposta.
5. Testar escuta em segundo plano, bloqueio de tela, música e reinicialização, observando consumo de bateria.
6. Verificar logs e repetir os testes em cada versão Android-alvo.

A aprovação de testes estáticos não substitui a compilação Android real nem os testes em dispositivo físico.
