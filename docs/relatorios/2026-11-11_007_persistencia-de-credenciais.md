# Relatório — Fase 2, ajuste 007: persistência segura e credenciais (Android e Windows)

## 1. O que foi auditado

Onde cada segredo fica, o que acontece quando o cofre não está disponível e o que a interface
promete versus o que o código garante. Só entrou no quadro o que foi lido no código; nada foi
executado em aparelho.

## 2. Chaves de API dos provedores

| Plataforma | Onde fica | Como é protegida | Falha (cofre indisponível) |
|---|---|---|---|
| Android | `SharedPreferences` privado `jarvis_seguro`, valor `iv:ct` em base64 | AES-256-GCM (`JarvisUtilPlugin`), chave AES no **AndroidKeyStore** (alias `jarvis_chaves`), IV aleatório por gravação | A gravação recusa: “Cofre seguro do Android indisponível…”; nada vai para texto puro |
| Windows/desktop | `jarvis-secrets.json` em `app.getPath('userData')` | `safeStorage` do Electron (DPAPI no Windows), arquivo `0o600`, gravação em `.tmp` e renomeação atômica | `exigirCofreDesktop()` lança erro antes de gravar |
| Navegador | Não persiste; `CHAVES` fica só em memória | — | `gravarChave()` recusa e explica que o navegador não tem cofre |

Pontos verificados no caminho:

- A chave antiga gravada em `localStorage` (`jv_key*`) é **removida em qualquer desfecho**: se a
  migração para o cofre der certo, se falhar e até no navegador. Não sobra cópia em claro.
- O cofre do desktop só aceita os cinco nomes de provedor (lista fechada); nome fora da lista é
  recusado antes de tocar no arquivo.
- Cofre ilegível **não é sobrescrito**: a leitura lança erro e a gravação não acontece.
- O diagnóstico do desktop mostra apenas os **nomes** das chaves presentes, sem decifrar nada.

## 3. PIN e código de recuperação

- PBKDF2-SHA256, sal aleatório de 16 bytes por instalação, 120.000 iterações, saída `pbkdf2$sal$hash`.
- O hash SHA-256 antigo continua aceito **uma vez** e é migrado no acerto; ninguém fica trancado fora.
- O código de recuperação usa o mesmo esquema, com sal próprio (`rec_salt`).
- PIN e código nunca aparecem no histórico de eventos (máscara de sequências hexadecimais e de 4+ dígitos).

## 4. O que **não** é cofre, e a interface já diz isso

- **Biometria de voz**: AES-GCM em repouso com a chave guardada no **mesmo** `localStorage`
  (`jv_identidade_chave`). Isso protege contra leitura casual de um arquivo de backup, não contra
  quem tem acesso ao armazenamento — quem lê o armazenamento lê a chave. O código (`identidade.js`)
  e o `LEIA-ME.md` já declaram “chave local, não Keystore”; não há promessa de hardware aqui.
- **Memória pessoal e histórico de conversa**: texto puro no `localStorage`. O histórico só é
  gravado com `salvar_historico` ligado (padrão desligado); a memória também é opcional.
- **Windows e permissões de arquivo**: `mode: 0o600` é ignorado no Windows — a proteção real é a
  ACL do perfil do usuário em `%APPDATA%` somada à cifra do DPAPI. Vale registrar para ninguém
  tratar o `0o600` como garantia ali.

## 5. Assimetrias encontradas (registradas, não corrigidas)

1. **Lista de nomes só no desktop.** O cofre Android aceita qualquer `nome`; o desktop restringe aos
   cinco provedores. Sem impacto prático hoje (só o `app.js` chama), mas é uma diferença de rigor.
2. **Sem vínculo do nome ao texto cifrado (AAD).** Quem puder escrever nas preferências privadas
   pode trocar o blob de `groq` pelo de `gemini`; o efeito é usar a chave errada, não vazar chave.
3. **Sem leitura de conferência depois de gravar.** O app confia no retorno do cofre; não relê para
   confirmar que a chave chegou. Um “salvo” silencioso não seria detectado.
4. **Biometria de voz fora do Keystore** (item 4). Migrar para o cofre nativo é possível, mas muda
   o fluxo de chaves do módulo de identidade e precisa de teste em aparelho — não entra numa
   auditoria sem validação física.

## 6. Evidência

- `python3 tests/test_secure_keys.py` — passou a cobrir, além das checagens antigas: cifra
  AES-GCM com chave do Keystore, gravação de `iv:ct` (nunca o segredo), falha fechada sem cofre,
  remoção da cópia em claro nos três desfechos de migração, PBKDF2 com sal para PIN e recuperação,
  `0o600` com troca atômica no desktop, diagnóstico só com nomes e a declaração honesta da
  biometria de voz.
- `npm run test:all` — suíte completa, incluindo a checagem acima.

## 7. Não verificado

- Nenhuma gravação/leitura real no AndroidKeyStore nem no DPAPI do Windows: o que está provado é o
  contrato do código e os testes estáticos. Sem aparelho e sem Windows, isso segue pendente.
- Não foi testado backup/restauração do Android (caso em que a chave do Keystore pode ser invalidada).
- Não foi medido o comportamento do `safeStorage` em Linux sem keyring (fora do escopo desta fase).
