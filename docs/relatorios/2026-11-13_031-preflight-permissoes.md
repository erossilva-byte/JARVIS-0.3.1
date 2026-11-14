# Ajuste 031 — pré-checagem de APIs e permissões de sistema

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## Por que este ajuste

O defeito do ajuste 030 (`getClientPackageName()` sem `MODIFY_AUDIO_ROUTING`) passou por todos os
testes porque eles verificavam a forma do código, não o contrato da API. A pré-checagem agora
olha três coisas que o compilador também não pega.

## O que a pré-checagem ganhou

1. **Registro de APIs restritas.** Oito métodos que só funcionam com permissão de sistema
   (`getClientPackageName`, `getClientUid`, `getRunningTasks`, `getDeviceId`, `getImei`,
   `getSubscriberId`, `setMicrophoneMute`, `getRunningAppProcesses`) estão na lista. Um uso novo
   **reprova** até alguém registrar a revisão com o motivo e o tratamento do retorno vazio.
   O único uso revisado hoje é o do serviço, que só melhora a mensagem e trata o pacote vazio.
2. **Permissão usada × declarada.** Todo `Manifest.permission.X` no Java precisa aparecer em
   `patch_manifest.py` como `android.permission.X`.
3. **Permissão de sistema pedida no manifesto.** Pedir `WRITE_SECURE_SETTINGS`, `READ_LOGS`,
   `MODIFY_AUDIO_ROUTING` e afins não concede nada; o código que depende delas falha em silêncio.

## Evidência (testes negativos, não só o caminho feliz)

| Prova | Resultado |
|---|---|
| Rodada normal | exit 0 — 23 classes, 6 workflows, 8 APIs monitoradas |
| Arquivo de teste com `getClientUid()` | exit 1, "exige a permissão de sistema MODIFY_AUDIO_ROUTING" |
| Arquivo de teste com permissão inexistente | exit 1, "patch_manifest.py não declara android.permission.FAKE_PROBE" |
| `WRITE_SECURE_SETTINGS` injetada no manifesto | exit 1, "declarar não concede" |
| Remoção dos arquivos/prova e rodada final | exit 0 |

## Limites

A lista é curada, não é um banco de APIs do Android: um método restrito fora dela continua
passando. Ela não sabe se o código **checa** a permissão em tempo de execução, nem se há
tratamento do retorno vazio — por isso o registro exige uma frase de justificativa, que aparece
como `AVISO` em toda rodada. Nada disso substitui compilar e medir.
