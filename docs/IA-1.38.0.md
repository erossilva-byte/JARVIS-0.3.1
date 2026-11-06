# Pendências de IA — auditoria da 1.38.0

Data: 2026-11-01. Esta auditoria descreve o que o código realmente faz. Ela não transforma ausência de chave, modelo ou aparelho em aprovação.

## Resumo executivo

| Caminho | Estado | O que prova | O que não prova |
|---|---|---|---|
| Habilidades e comandos locais do Hermes | **implementado e testado em Node** | saudação/briefing, autodiagnóstico, status, visão e comandos do aparelho resolvem sem cota de IA | não valida microfone, câmera ou tela de um Android real |
| Provedores em nuvem (Groq, Cerebras, Mistral, Gemini) | **implementado; bloqueado para prova ao vivo** | roteamento, timeout, fallback, tratamento de erro e leitura de resposta estão no código e nos testes | não há chave real nesta máquina; validade, cota e latência de rede não foram comprovadas |
| Modelo local `.task` (MediaPipe) | **implementado; bloqueado para prova ao vivo** | importação, validação de formato, limite de tamanho, geração e fallback estão no código e nos testes estáticos | o APK não embarca modelo; nenhum `.task` foi importado/executado aqui |
| Cérebro local básico | **implementado** | respostas curtas e comandos locais quando não há geração disponível | não é um modelo generativo e não deve ser apresentado como IA completa |

## Cadeia real de decisão

1. O texto entra no `Hermes.despachar()`.
2. Primeiro ele tenta uma habilidade própria do Hermes (por exemplo, “bom dia”, diagnóstico ou status do núcleo).
3. Depois tenta um comando local do aparelho (`ACOES`/`executarSeguro`).
4. Só então chama a IA. A chamada passa por `planejarIA`, que ordena os provedores por tarefa, latência medida, falhas recentes e pausa.
5. Se a nuvem falhar, tenta o modelo `.task` local; se ele não estiver importado, tenta o cérebro local básico; se nada existir, devolve erro explícito.

O trecho decisivo de `app.js` é `chamar()`: sem provedor com chave, ele tenta `gerarIALocal()` e depois `tentarBrainLocal()`. Não existe uma chamada generativa “escondida” sem chave.

## Provedores e modelos

- Groq: endpoint OpenAI-compatible; modelo padrão `openai/gpt-oss-20b`, com reservas `openai/gpt-oss-120b`.
- Cerebras: `gpt-oss-120b` e `zai-glm-4.7`.
- Mistral: `mistral-small-latest`.
- Gemini: `gemini-2.5-flash` e `gemini-flash-latest` pelo endpoint compatível.
- Chaves são carregadas no aparelho; no Android passam pelo cofre do `JarvisUtil`/Android Keystore. O teste de presença não valida a chave, a cota ou o modelo.

## Modelo local no aparelho

- Formato aceito: Task Bundle `.task` do MediaPipe LLM Inference.
- Runtime: `com.google.mediapipe:tasks-genai:0.10.24`.
- Limite de arquivo: 6 GB; prompt limitado a 6.000 caracteres para caber no contexto de 2.048 tokens do modelo de referência.
- O modelo é importado manualmente em Ajustes ▸ IA e fica em `files/modelos/jarvis-model.task`; **não vem no APK**.
- GGUF renomeado é recusado. O plugin valida tamanho e cabeçalho antes de abrir.
- Sem streaming e sem function calling no caminho local; a decisão JSON é validada pelo Hermes antes de virar ação.

## O que foi fechado nesta rodada

- A rota de fallback foi auditada e documentada, em vez de descrita como “IA sempre disponível”.
- O diagnóstico existente continua mostrando “sem chave” e “modelo não importado” como estados reais.
- O avatar não foi ligado à IA: ele reage à amplitude do áudio, não a fonemas, e não inventa expressões sem sinal.
- Nenhuma chave, token ou modelo foi incluído no repositório, no APK ou na release.

## Pendências que continuam bloqueadas

1. **Chave real e cota**: exige uma chave válida do usuário e uma chamada de rede; não foi feita nesta máquina.
2. **Modelo `.task` real**: exige importar um arquivo compatível e testar no Android; não foi feito.
3. **Latência/custo por token**: o roteador mede latência, mas não contabiliza tokens nem custo monetário em tempo real.
4. **RAG vetorial, MCP remoto, visão local e function calling nativo**: não implementados; não são anunciados como prontos.
5. **Validação em aparelho**: microfone, wake word, TTS, câmera e segundo plano continuam dependentes do Poco X7.

## Evidências de teste

- `node tests/test_hermes.js`
- `node tests/test_voz_motor.js`
- `python3 tests/test_local_ai.py`
- `python3 tests/test_v1_13_0.py`
- `python3 tests/test_ia_arquivos.py`
- `python3 tests/test_v1_38_0.py`

Os testes provam o comportamento estático e de simulação. **Não** provam inferência ao vivo, qualidade de modelo, cota ou funcionamento no aparelho.
