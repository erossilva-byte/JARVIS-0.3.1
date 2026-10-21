# J.A.R.V.I.S. Nova 1.2.5 — relatório de revisão

Data: 16/10/2026  
Base: fonte 1.2.4. Esta é uma revisão corretiva de preparação para build, não uma declaração de que o aplicativo está pronto para distribuição.

## Correção concreta nesta versão

- Removidas duas definições duplicadas dos métodos `reiniciar(long)` e `musicaAtiva()` em `JarvisBackgroundPlugin.java`. A duplicação de métodos com a mesma assinatura é um erro de compilação Java e precisava ser corrigida antes de tentar produzir o APK.
- Ampliado `tests/validate_project.py` para sinalizar assinaturas de métodos Java duplicadas em arquivos Java na raiz do projeto.
- Atualizados `package.json`, `VERSAO.json`, versionCode para 1205, workflow e nome do artefato para 1.2.5.
- Mantida a arquitetura Porcupine para a palavra integrada JARVIS e reconhecimento completo somente após a ativação.
- Mantidas as funções já presentes na base: controles de memória/contexto, modo offline, provedores de IA, pesquisa com fontes, tarefas/rotinas, alarmes, diagnóstico, controles de voz e configurações de privacidade. A presença no código não equivale a validação funcional em aparelho.

## Testes executados nesta revisão

- `npm run test:all`: executado após as alterações; resultado registrado no relatório externo.
- `node --check` para os scripts JavaScript.
- Validador do projeto, incluindo verificação de IDs e assinaturas duplicadas de métodos Java.
- `python3 -m py_compile` dos scripts de patch.
- Verificação estrutural do arquivo Java para confirmar que os dois helpers não têm definições duplicadas.
- Integridade do ZIP e checksum SHA-256 gerados após empacotamento.

## Ainda não certificado

- Não foi executado build Gradle/Android real nesta sessão.
- Não foi testada a AccessKey Picovoice do usuário.
- Não foi instalado/testado em telefone físico.
- Consumo de bateria, taxa de falso acionamento, precisão com sotaque brasileiro, segundo plano, conflitos de áudio e permissões dependem de teste real.
- A ativação de palavra-chave exige captação de áudio enquanto está habilitada; o detector local evita transcrever continuamente, mas não elimina o uso do microfone.

## Próximas etapas obrigatórias para APK

1. Adicionar os arquivos do projeto ao repositório e executar o workflow GitHub Actions atualizado.
2. Corrigir qualquer falha real de dependência, Gradle, manifesto ou compilação nativa.
3. Baixar o APK debug do artefato e instalar em aparelho de teste.
4. Validar chave, ativação, fala após bipe, retorno ao modo de espera, pausar/retomar, música, notificações e alarmes.
5. Fazer uma revisão de segurança de permissões, armazenamento de chaves e ações sensíveis antes de uma versão de distribuição.


## Próxima revisão 1.2.6

A evolução seguinte deve partir do pacote-fonte 1.2.5 fornecido, substituir o detector com chave por openWakeWord local, adicionar o painel de estado do aparelho e uma mini-interface de ativação. A compilação real e os testes no Android permanecem obrigatórios antes de declarar o APK pronto.
