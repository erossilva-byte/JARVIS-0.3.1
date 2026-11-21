# Ajuste 093 — provedor sem chave (Zero-Key)

Data: 2026-11-21 · Versão: 1.79.0+17900 · Branch: `work/1.78.0-bloco-092`

## 1. Pedido

Fazer o bloco do provedor sem chave (Zero-Key), uma das lacunas apontadas no
comparativo do U.L.T.R.O.N.

## 2. O que faltava

- **Toda conversa exigia uma chave do usuário.** Sem Groq, OpenRouter, Cerebras,
  Mistral ou Gemini cadastrados, a conversa, o resumo tático e as perguntas em
  segundo plano paravam com “nenhum provedor configurado”.
- **Não havia consentimento nem limite para um serviço público.** Um provedor sem
  chave manda a pergunta para fora do aparelho sem credencial; isso precisa de um
  “sim” explícito e de uma explicação do que sai e do que pode falhar.
- **A mensagem de erro não oferecia saída** para quem só quer testar o app sem
  criar conta em lugar nenhum.

## 3. Medição antes de escolher o serviço

Não escolhi endpoint por memória. Em 2026-11-21, desta sessão:

- `POST https://text.pollinations.ai/openai/chat/completions` com
  `{"model":"openai-fast"}` e **sem nenhum cabeçalho de autorização** respondeu
  **HTTP 200** com o envelope normal de conversa (`choices[0].message.content`),
  em ~6 s, com `"user_tier":"anonymous"`.
- A mesma chamada logo depois respondeu **HTTP 402** com
  `"Free limit reached: 1 reply every 45 seconds per IP"` — o limite real do
  serviço público.
- `api.llm7.io` também responde sem chave, mas neste IP já devolvia **HTTP 429**
  de cota grátis esgotada em todos os modelos livres; foi descartado como
  principal justamente por não ter cota confiável.

Por isso o provedor é um só, e as mensagens falam de limite — não de
disponibilidade garantida.

## 4. O que foi feito

### Serviço (`provider_service.dart`)

- `AiProvider` ganhou `semChave` (padrão `false`) e a lista ganhou
  `provedorSemChave` (`zerokey`, “Zero-Key · Pollinations”, modelo
  `openai-fast”), **por último** na prioridade: nunca passa na frente de um
  provedor com chave.
- `_cabecalhos(chave)` monta `Authorization` só quando existe chave; no Zero-Key
  a chamada sai anônima. `complete`, `streamComplete` e `testConnection` usam o
  mesmo ponto.
- `isConfigured('zerokey')` consulta o consentimento, não o cofre de chaves;
  `saveKey`/`removeKey` no Zero-Key são recusados com explicação.
- `_mensagemHttp` separa 402/429/503 do serviço público das falhas de provedor
  com chave, sem culpar a rede nem sugerir trocar de chave.

### Consentimento (`zero_key_store.dart`)

- `ZeroKeyStore` com implementação em `SharedPreferences`
  (`jarvis.zerokey.ativo`), **desligada por padrão**; falha de leitura também
  mantém desligado. Não é segredo, então não entra no cofre de chaves.

### Tela (`provider_settings_page.dart`)

- Cartão do Zero-Key com interruptor (`zerokey-ativar`), sem campo de chave e sem
  “Salvar/Remover”. O texto diz o que sai do aparelho (pergunta e histórico
  recente, sem cadastro, identificado pelo IP), o limite de ~45 s e que pode
  falhar. A tela agora aceita serviço injetado para teste.

### Resto do app

- Conversa, resumo tático e ponte de segundo plano citam o Zero-Key quando não há
  provedor configurado.

## 5. Verificação

- `flutter analyze` e os testes Dart do bloco
  (`test/zero_key_test.dart`, `test/zero_key_page_test.dart`) mais
  `test/provider_service_test.dart`.
- `python3 tests/test_zero_key.py` e os contratos vizinhos.
- Testes Dart cobrem: desligado por padrão, chamada sem `Authorization`, modelo
  `openai-fast`, 402 explicado com o limite de 45 s, recusa de chave, fallback de
  streaming depois dos provedores com chave e persistência do consentimento.

## 6. Limites honestos

- **Nada foi testado em aparelho físico.** Os testes são de serviço e de tela com
  cliente falso; não houve conversa real a partir do celular.
- **O serviço público pode mudar sem aviso.** A medição é de uma sessão; cota,
  modelo e disponibilidade são do provedor, não deste repositório. Se ele
  responder 402/429/503, o app explica o limite e não inventa resposta.
- **Privacidade**: com o Zero-Key ligado, a pergunta e o histórico recente saem do
  aparelho para um serviço de terceiros, identificados apenas pelo IP. É por isso
  que o padrão é desligado.
- Ainda falta a descoberta automática de modelos (`/models`), a outra lacuna de IA
  do comparativo.
