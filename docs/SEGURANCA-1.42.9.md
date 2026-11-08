# Tela de bloqueio — PIN, biometria, NFC e central em Ajustes (1.42.9)

Documento da revisão 1.42.9. Separa o que foi implementado, o que foi testado sem aparelho e o que
continua impossível de afirmar nesta máquina.

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

- **Biometria facial pelo sistema**: `BiometricPrompt` com `BIOMETRIC_STRONG`. Se o aparelho tiver
  `android.hardware.face` (API 29+), a interface chama de "reconhecimento facial"; se só houver
  digital, chama de "biometria" e diz isso. **Não há câmera comum no caminho**: foto, vídeo ou
  imagem na tela não passam, porque a prova é feita pelo sensor e pelo Android. Nenhuma imagem do
  rosto é recebida, guardada ou enviada.
- **NFC real** (`JarvisSeguranca.nfcLer`): `NfcAdapter.enableReaderMode` com A/B/F/V, leitura de UID e
  das tecnologias, encerramento no timeout, no erro, no `handleOnPause` e no `handleOnDestroy`.
  O JavaScript guarda **apenas o SHA-256 do UID**, nunca o UID bruto; a lista mostra `•••• 1A2B`.
  Tags desconhecidas, desativadas ou bloqueadas são recusadas e registradas.
- **Modos**: PIN, biometria, NFC, biometria **ou** NFC, biometria + NFC (duas etapas), biometria +
  PIN, NFC + PIN. As etapas são decididas por um núcleo puro (`seguranca.js`), testado em Node.
- **Recuperação**: o PIN é sempre a recuperação final e o código de recuperação apaga o PIN e
  desativa o bloqueio. Nenhum modo consegue trancar o proprietário fora — decisão deliberada.
- **Central em Ajustes ▸ Segurança**: modo, tempo de inatividade (15–3600 s), tentativas máximas
  (3–10), ligar/desligar biometria e NFC, cadastrar/renomear/ativar/bloquear/remover tags, testar
  leitura, testar biometria, histórico (método, resultado, hora, sem segredo) e restaurar.
- **Operações sensíveis exigem prova**: cadastrar, renomear, bloquear ou remover tag pede biometria
  ou o PIN atual.
- **Visual**: selo do método, linha de fase ("Reconhecendo o rosto…", "Tag autorizada", "Acesso
  negado"), estados do núcleo (reconhecendo, lendo NFC, confirmado, negado) com
  `prefers-reduced-motion`, e o desbloqueio nunca espera animação — a saída continua em 260 ms.
- **Autobloqueio** pelo tempo configurado (antes fixo em 120 s), mantendo o bloqueio opcional em
  Ajustes ▸ Segurança e sem tocar na tela de bloqueio do Android.

## 3. Segurança

- PIN: PBKDF2-SHA256, sal por instalação, 120.000 iterações; nunca em texto puro, nunca no histórico.
- Código de recuperação: PBKDF2 com sal próprio; o antigo continua aceito e migra.
- UID de tag: hash SHA-256 com domínio fixo; comparação por hash; UID bruto não é persistido.
- Biometria: executada pelo Android; o app nunca vê a imagem nem o template.
- Histórico: máscara de sequências hexadecimais longas e de 4+ dígitos; limite de 60 eventos.
- Tentativas: atraso progressivo com teto configurável; mensagem no limite sem apagar dados.
- NFC: leitura só com a tela ativa, encerrada na pausa; tag desconhecida não libera nada.
- O bloqueio protege **apenas a abertura do J.A.R.V.I.S.**; não substitui o bloqueio do Android.

## 4. O que foi testado e como

| Verificação | Tipo |
|---|---|
| `node tests/test_seguranca.js` (12 grupos) | automatizado, sem rede |
| `python3 tests/test_seguranca_android.py` | contrato estático do Java/manifesto/UI |
| `test_v1_20_0`, `test_v1_21_3`, `test_v1_21_4`, `test_v1_40_0` | regressão do bloqueio e preservação |
| `test_empacotamento`, `validate_project` | o módulo novo entra no APK e no pacote Windows |
| APK 1.42.9 compilado no GitHub Actions | build real; módulo conferido dentro do pacote |

**Não testado**: leitura NFC física, rosto/digital reais, instalação em aparelho, reinício do
celular e comportamento em fabricantes diferentes. Não há aparelho nem tag nesta máquina, e o APK
sai com assinatura debug/CI.

## 5. Limitações honestas

- **Face × digital**: o Android não expõe "qual biometria foi usada" ao app; o plugin informa se há
  hardware facial e se existe biometria forte. Se o aparelho só tiver digital, o modo "biometria"
  usa a digital — e a interface diz isso.
- **UID de tag é clonável**. Tags ISO-DEP/DESFire são sinalizadas, mas a validação aqui continua
  sendo por UID; autenticação criptográfica da tag (chaves DESFire) não foi implementada.
- **Sem NFC no Windows**: os controles aparecem como indisponíveis, sem botão falso.
- **Biometria forte exige cadastro no Android**: sem digital/rosto cadastrado, o modo cai para PIN
  com explicação.
- **Não substitui a tela de bloqueio do sistema**: isso exigiria APIs e permissões que um app
  comum não tem.
