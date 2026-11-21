# Ajuste 094 — descoberta de modelos (`/models`)

Data: 2026-11-21 · Versão: 1.80.0+18000 · Branch: `work/1.79.0-bloco-093`

## 1. Pedido

Fazer o bloco da descoberta de modelos (`/models`), a outra lacuna de IA do
comparativo do U.L.T.R.O.N.

## 2. O que faltava

- **O modelo de cada provedor era um nome fixo no código.** Quando o provedor
  aposentava o nome, o app dependia de uma lista de reserva escrita à mão (foi
  por isso que `gemini-3.8-flash` já tinha quatro substitutos).
- **Quem tem a lista é o provedor.** O app nunca perguntava; o usuário não tinha
  como ver nem escolher o modelo que a conta dele realmente alcança.
- **A escolha não podia ser guardada nem desfeita**: não existia preferência de
  modelo por provedor.

## 3. O que foi medido antes

Em 2026-11-21, nesta sessão:

| Endereço | Resposta sem chave |
|---|---|
| `text.pollinations.ai/openai/models` | **200**, lista com `openai-fast` |
| `openrouter.ai/api/v1/models` | **200**, catálogo público com ~925 KB |
| `api.groq.com/openai/v1/models` | **401** (existe; pede chave) |
| `api.cerebras.ai/v1/models` | **403** (existe; pede chave) |
| `api.mistral.ai/v1/models` | **401** (existe; pede chave) |
| `generativelanguage.googleapis.com/v1beta/openai/models` | **404** |

Duas consequências diretas:

1. **Gemini precisa de endereço próprio.** O caminho de compatibilidade com
   OpenAI (`/v1beta/openai/…`) não tem `/models`; a lista fica em
   `/v1beta/models` e a autenticação vai em `x-goog-api-key`.
2. **Lista não é cota.** O OpenRouter devolve o catálogo inteiro, público, mesmo
   sem chave. A tela precisa dizer que a lista não garante que a chave alcança
   todo modelo — o teste de conexão é que confirma.

## 4. O que foi feito

### Descoberta (`provider_service.dart`)

- `urlDeModelos(provider)` deriva `/models` do endpoint de conversa e trata o
  Gemini separadamente.
- `lerModelos(corpo)` lê `data[]` (OpenAI e clones) e `models[]` (Gemini),
  remove o prefixo `models/`, ignora duplicados, modelos de embedding e, no
  Gemini, métodos que não sejam `generateContent`; ordena por id.
- `descobrirModelos(id)` exige provedor configurado (chave ou consentimento do
  Zero-Key), faz `GET` com 15 s de limite, manda **só a chave** — o corpo é vazio,
  a conversa nunca entra — e traduz 401/403/404/429/5xx sem ecoar o corpo bruto.

### Escolha do modelo

- `PreferencesModeloStore` guarda `jarvis.ai.modelo.<provedor>` nas preferências
  (não no cofre): é escolha, não segredo.
- `_modelosPara(provider)` monta a ordem **escolhido → padrão do app → reservas
  do código**, sem repetir. Essa ordem passou a valer no teste de conexão, na
  conversa (`complete`) e no streaming, então um modelo escolhido que foi
  retirado responde 404 e a mesma chamada cai para o padrão.

### Tela (`provider_settings_page.dart`)

- Cada cartão mostra “Modelo em uso: … (padrão do app)” ou “(escolhido)” e ganha
  “Ver modelos” (só com provedor configurado) e “Usar padrão”.
- A janela de modelos tem filtro por nome/id, marca o modelo atual, mostra o
  nome de exibição quando o provedor manda, e avisa que a lista não garante
  acesso.

## 5. O que muda na escolha de provedor

| Antes | Agora |
|---|---|
| Modelo fixo no código, com reservas escritas à mão | Lista lida do provedor e modelo escolhido por cartão |
| Nome aposentado só era coberto se estivesse na reserva | Escolhido 404 → padrão → reservas, na mesma chamada |
| Sem visão do que a conta alcança | “Ver modelos” mostra a lista do provedor; o teste confirma o acesso |
| Escolha não sobrevivia ao fechamento do app | Preferência por provedor, com “Usar padrão” para desfazer |

A prioridade entre provedores **não muda**: continua Groq primeiro, Zero-Key por
último. O que muda é que, dentro de cada provedor, o modelo deixou de ser
adivinhado.

## 6. Verificação

- `flutter analyze` sem problemas; suíte Flutter completa verde.
- 15 testes novos (`test/descoberta_modelos_test.dart`,
  `test/descoberta_modelos_page_test.dart`): derivação do endereço, leitura dos
  dois formatos, descarte de embedding, Gemini com `x-goog-api-key`, Zero-Key sem
  `Authorization`, 401 explicado sem vazar corpo, nenhuma chamada sem chave,
  escolha valendo na conversa, queda para o padrão no 404, persistência e filtro
  na tela.
- `python3 tests/test_descoberta_modelos.py` e os contratos vizinhos.

## 7. Limites honestos

- **Nenhuma chave real foi usada.** Só a lista pública (Zero-Key e OpenRouter)
  foi medida; Groq, Cerebras, Mistral e Gemini responderam “sem chave”, o que
  prova o endereço, não a lista.
- **Nenhum aparelho físico.** A escolha de modelo foi testada com cliente e tela
  simulados.
- **A lista é do provedor.** Pode vir enorme (OpenRouter), mudar sem aviso ou
  incluir modelo que a sua conta não alcança — a tela avisa e o teste confirma.
- Um modelo escolhido pode exigir parâmetros diferentes (por exemplo, não aceitar
  temperatura); isso aparece como erro do provedor, não é tratado neste bloco.
