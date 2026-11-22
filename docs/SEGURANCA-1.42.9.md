# Tela de bloqueio — PIN, biometria, NFC e central em Ajustes (revisão 1.46.0)

Documento atualizado na linha 1.46.0. A revisão corrige os modos AND/OR, o tratamento do BiometricPrompt e a descrição dos fatores realmente disponíveis.

## 1. Auditoria do que existia

| Peça | Estado anterior | Lacuna |
|---|---|---|
| `JarvisSeguranca.java` | `BiometricPrompt` com `BIOMETRIC_STRONG + DEVICE_CREDENTIAL`, consulta de disponibilidade | não distinguia hardware facial, não lia NFC |
| PIN em `app.js` | SHA-256 com prefixo fixo `jarvis\|`, tentativas com atraso até 30 s, código de recuperação | hash rápido e sem sal; sem PBKDF2 |
| Tela de bloqueio | núcleo holográfico, relógio, PIN, biometria, recuperação, `prefers-reduced-motion` | um único caminho: PIN/biometria; nenhum selo de método ou fase |
| Ajustes ▸ Segurança | ativar bloqueio, PIN, testar biometria, gerar código | sem modos, sem NFC, sem histórico, sem tempo de inatividade configurável |
| Manifesto | `USE_BIOMETRIC`, `USE_FINGERPRINT` | sem permissão `NFC` |

Uma correção de segurança entrou junto: o PIN agora usa **PBKDF2-SHA256 com sal aleatório e 120.000
iterações**, e o hash antigo continua sendo aceito uma vez e migrado no próximo acerto — ninguém
fica trancado fora por causa da atualização.

## 2. O que foi implementado (real, não demonstração)

- **Biometria forte pelo sistema**: `BiometricPrompt` com `BIOMETRIC_STRONG` e, no bloqueio, `permitirCredencial: false`. A prova é feita pelo sensor e pelo Android; o app não recebe imagem nem template. O Android escolhe o sensor biométrico forte cadastrado. A aplicação pode informar hardware facial/digital quando o sistema expõe essas características, mas não consegue forçar face ou digital de forma portável.
- **NFC real** (`JarvisSeguranca.nfcLer`): `NfcAdapter.enableReaderMode` com A/B/F/V, leitura de UID e
  das tecnologias, encerramento no timeout, no erro, no `handleOnPause` e no `handleOnDestroy`.
  O JavaScript guarda **apenas o SHA-256 do UID**, nunca o UID bruto; a lista mostra `•••• 1A2B`.
  Tags desconhecidas, desativadas ou bloqueadas são recusadas e registradas.
- **Modos AND/OR**: somente PIN; somente biometria forte; somente NFC; biometria **ou** NFC; PIN **ou** biometria; PIN **ou** NFC; PIN, biometria **ou** NFC; biometria **e** NFC; biometria **e** PIN; NFC **e** PIN. As etapas são decididas por `seguranca.js`; o modo OR aceita qualquer fator válido, enquanto o modo AND exige todos.
- **Recuperação**: o PIN só é fator de desbloqueio quando o modo escolhido o inclui. Para modos sem PIN, o código de recuperação é o caminho de emergência; após validar o código, o app desativa o bloqueio e permite redefinir a configuração. Ao desligar um fator que tornaria o modo inviável, a configuração muda para PIN para evitar bloqueio acidental.
- **Central em Ajustes ▸ Segurança**: modo, tempo de inatividade (15–3600 s), tentativas máximas
  (3–10), ligar/desligar biometria e NFC, cadastrar/renomear/ativar/bloquear/remover tags, testar
  leitura, testar biometria, histórico (método, resultado, hora, sem segredo) e restaurar.
- **Operações sensíveis exigem prova**: cadastrar, renomear, bloquear ou remover tag pede biometria
  ou o PIN atual.
- **Visual**: selo do método, linha de fase ("Aguardando biometria forte do Android…", "Tag autorizada", "Acesso
  negado"), estados do núcleo (reconhecendo, lendo NFC, confirmado, negado) com
  `prefers-reduced-motion`, e o desbloqueio nunca espera animação — a saída continua em 260 ms.
- **Autobloqueio** pelo tempo configurado (antes fixo em 120 s), mantendo o bloqueio opcional em
  Ajustes ▸ Segurança e sem tocar na tela de bloqueio do Android.

## 3. Segurança

- PIN: PBKDF2-SHA256, sal por instalação, 120.000 iterações; nunca em texto puro, nunca no histórico.
- Código de recuperação: PBKDF2 com sal próprio; o antigo continua aceito e migra.
- UID de tag: hash SHA-256 com domínio fixo; comparação por hash; UID bruto não é persistido.
- Biometria: executada pelo Android; o app nunca vê a imagem nem o template. O bloqueio não aceita a credencial de dispositivo como substituto silencioso da biometria.
- Histórico: máscara de sequências hexadecimais longas e de 4+ dígitos; limite de 60 eventos.
- Tentativas: atraso progressivo com teto configurável; mensagem no limite sem apagar dados.
- NFC: leitura só com a tela ativa, encerrada na pausa; tag desconhecida não libera nada.
- O bloqueio protege **apenas a abertura do J.A.R.V.I.S.**; não substitui o bloqueio do Android.

## 4. O que foi testado e como

| Verificação | Tipo |
|---|---|
| `node tests/test_seguranca.js` (inclui modos AND/OR) | automatizado, sem rede |
| `python3 tests/test_seguranca_android.py` | contrato estático do Java/manifesto/UI |
| `test_v1_20_0`, `test_v1_21_3`, `test_v1_21_4`, `test_v1_40_0` | regressão do bloqueio e preservação |
| `test_empacotamento`, `validate_project` | o módulo novo entra no APK e no pacote Windows |
| APK 1.42.9 compilado no GitHub Actions | build real; módulo conferido dentro do pacote |

**Não testado nesta linha 1.46.0**: leitura NFC física, autenticação biométrica real, instalação em aparelho, reinício do celular e comportamento em fabricantes diferentes. O CI anterior da linha 1.42.9 não valida a nova implementação nem substitui build e teste da 1.46.0.

## 5. Limitações honestas

- **Face × digital**: o Android não permite que o app force o sensor em todos os dispositivos. O `BiometricPrompt` escolhe uma biometria forte cadastrada; a interface informa a presença de hardware quando disponível, sem afirmar que uma autenticação foi facial ou digital.
- **UID de tag é clonável**. Tags ISO-DEP/DESFire são sinalizadas, mas a validação aqui continua
  sendo por UID; autenticação criptográfica da tag (chaves DESFire) não foi implementada.
- **Sem NFC no Windows**: os controles aparecem como indisponíveis, sem botão falso.
- **Biometria forte exige cadastro no Android**: sem digital/rosto cadastrado, o modo cai para PIN
  com explicação.
- **Não substitui a tela de bloqueio do sistema**: isso exigiria APIs e permissões que um app
  comum não tem.


## 6. Modos AND/OR da revisão 1.46.0
- `bio|nfc`: qualquer uma das duas provas.
- `pin|bio`: PIN do app ou biometria forte.
- `pin|nfc`: PIN do app ou tag NFC autorizada.
- `pin|bio|nfc`: qualquer uma das três.
- `bio+pin`, `nfc+pin`, `bio+nfc`: todas as etapas são obrigatórias.
- `pin+bio` e `pin+nfc` são normalizados para as formas canônicas acima.
- Em modos OR, os controles de cada fator aparecem somente se o hardware/ajuste estiver disponível. Em modos AND, se um fator for desligado ou ficar indisponível, o modo é alterado para PIN antes de salvar.
- Para biometria do bloqueio, `permitirCredencial: false` impede que a senha/PIN do Android seja aceita como se fosse biometria. O PIN do aplicativo continua sendo um fator separado.
