# Modelos de IA local (`.task`) — fontes e compatibilidade

O J.A.R.V.I.S. Nova usa a API **MediaPipe LLM Inference** (`com.google.mediapipe:tasks-genai`, versão
declarada em `android/app/build.gradle`) para gerar texto no próprio aparelho. O formato aceito é o
**Task Bundle** (`.task`): um pacote com o modelo LiteRT/TFLite + tokenizer. **Um GGUF comum não carrega**
e não deve ser renomeado para `.task` — o app recusa o arquivo antes de tentar abrir (confere tamanho e
cabeçalho ZIP ou TFL3 em `JarvisLocalAIPlugin.validarCabecalho`).

O APK **não embarca modelo**: você importa um arquivo em **Ajustes ▸ IA ▸ Importar modelo .task**. O
arquivo é copiado para o armazenamento privado do app (`files/modelos/jarvis-model.task`), pode ser
apagado pelo mesmo painel e nunca é baixado automaticamente.

## Fontes oficiais verificadas

| Modelo | Formato | Onde baixar | Observações |
|---|---|---|---|
| Gemma 3 1B IT | `.task` e `.litertlm` | https://huggingface.co/litert-community/Gemma3-1B-IT | Repositório mantido pela LiteRT Community (Google AI Edge). Várias quantizações e contextos. |
| Coleção LiteRT Community | `.task` / `.litertlm` | https://huggingface.co/litert-community | Outros modelos já empacotados para MediaPipe/LiteRT-LM. |
| Guia oficial do MediaPipe LLM Inference | documentação | https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference | Modelos recomendados, opções (`maxTokens`, `preferredBackend`) e processo de conversão. |
| Gemma (família) no Kaggle | variantes | https://www.kaggle.com/models/google/gemma-3 | Download mediante conta Kaggle e aceite de licença. |

> A documentação do MediaPipe LLM Inference está em **modo de manutenção**: o Google recomenda LiteRT-LM
> para projetos novos. O app continua no MediaPipe porque é a API que ele realmente integra hoje; trocar
> de runtime é uma mudança de arquitetura, não um ajuste de configuração.

## Arquivos conferidos no repositório (nomes exatos)

| Arquivo | Tamanho | Contexto (ekv) | Quantização | Situação no app |
|---|---|---|---|---|
| `Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task` | 529.0 MB | 2048 | q4 | importável (sujeito a RAM) |
| `Gemma3-1B-IT_multi-prefill-seq_q8_ekv2048.task` | 1024.0 MB | 2048 | q8 | importável (sujeito a RAM) |
| `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.task` | tamanho não confirmado | 4096 | q4 | importável (sujeito a RAM) |
| `Gemma3-1B-IT_multi-prefill-seq_q8_ekv1280.task` | 1005.2 MB | 1280 | q8 | importável (sujeito a RAM) |

Os nomes acima foram lidos da API pública do repositório em 2026-10-29. O repositório tem ainda variantes
`f32`, `seq128` e arquivos `.litertlm` (formato do LiteRT-LM, **não** usado por esta versão do app).

## Requisitos e limites reais

- **Armazenamento**: o arquivo fica no diretório privado do app; reserve espaço livre além do tamanho do download.
- **Memória**: o carregamento do `.task` pede mais RAM do que o arquivo ocupa. O app trata falta de memória
  como falha do teste, sem derrubar a interface; em aparelhos modestos pode não abrir.
- **Contexto**: `maxTokens` precisa caber no contexto embutido no modelo (`ekv` do nome). Contexto maior
  consome mais RAM.
- **Licença**: Gemma é distribuída sob os termos do Google; o uso é de sua responsabilidade.
- **Offline**: depois de importado, a inferência roda sem internet e sem chave. O app só usa esse caminho
  quando a IA local é escolhida ou quando os provedores de nuvem falham.

## Como importar

1. Baixe um `.task` pelo navegador do aparelho (ou transfira para ele).
2. **Ajustes ▸ IA ▸ Importar modelo .task** e escolha o arquivo.
3. **Testar modelo** para confirmar que carrega neste aparelho.
4. **Apagar modelo** libera o espaço quando não precisar mais.

O diagnóstico em **Ajustes ▸ Diagnóstico ▸ Inteligência artificial** mostra se o aparelho suporta a API e
se há modelo importado — inclusive quando o estado é “não configurado”, que não é falha.

## Auditoria de compatibilidade — como é feita e o que já foi verificado

**Estado desta revisão (1.23.1):** nenhum arquivo de modelo foi anexado à conversa, então **nenhum modelo foi carregado, executado ou medido**. O que segue separa o que foi verificado no código (fato),
o que é cálculo a partir de tamanho de arquivo (estimativa) e o que é previsão de desempenho.

### O que o motor realmente exige (verificado no código)

- API: `com.google.mediapipe:tasks-genai` **0.10.14** (`android/app/build.gradle`).
- Formato: **Task Bundle** (`.task`), ZIP com modelo LiteRT + tokenizer. `JarvisLocalAIPlugin.validarCabecalho`
  confere tamanho e cabeçalho (ZIP ou `TFL3`) e recusa o resto — GGUF renomeado não passa.
- Chamada: `generate({ prompt })` com o prompt inteiro de `promptSistema()` — portanto a personalidade,
  a calibragem de humor, a memória e os perfis chegam ao modelo local igual aos provedores remotos.
- Sem streaming, sem function calling: o app usa o campo JSON `acao`, interpretado por `hermes.js`.
- Armazenamento: `files/modelos/jarvis-model.task` no espaço privado; importação manual, sem download automático.

### Critérios de classificação

| Resultado | Significado |
|---|---|
| **COMPATÍVEL** | Roda no motor atual sem mudança de código e cabe no aparelho de referência. |
| **COMPATÍVEL COM ADAPTAÇÕES** | Precisa de importação/conversão ou ajuste de contexto/`maxTokens`. |
| **PARCIALMENTE COMPATÍVEL** | Roda, mas com risco real de RAM, lentidão ou respostas curtas demais. |
| **INCOMPATÍVEL** | Formato ou arquitetura não atendida pelo motor atual. |

### Candidatos (estimativas, não medições)

Referência de hardware: **Poco X7, 8 GB de RAM**, Android com o app em primeiro plano e voz ativa
(TTS + serviço) consumindo parte da memória.

| Modelo | Formato | RAM estimada | Poco X7 (8 GB) | Classificação |
|---|---|---|---|---|
| Gemma 3 1B IT, `q4_ekv2048` | `.task` | ~0,9–1,4 GB | viável; respostas curtas, ~5–12 tok/s (previsão) | **COMPATÍVEL COM ADAPTAÇÕES** |
| Gemma 3 1B IT, `q8_ekv2048` | `.task` | ~1,6–2,2 GB | funciona, mas competindo com o app; risco de fechamento por memória | **PARCIALMENTE COMPATÍVEL** |
| Modelos 2B–4B em `.task` | `.task` | ~2,5–5 GB | inviável com o app aberto em 8 GB | **PARCIALMENTE COMPATÍVEL** (não recomendado) |
| Qualquer GGUF (Llama, Qwen, Phi, Mistral) | `.gguf` | — | formato recusado pelo motor | **INCOMPATÍVEL** |
| Safetensors / ONNX crus | outros | — | exigem conversão para Task Bundle | **INCOMPATÍVEL** sem conversão |

As faixas de RAM e velocidade são **previsões** baseadas no tamanho do arquivo e no comportamento
conhecido do MediaPipe LLM Inference; não foram medidas neste ambiente (sem Android e sem o arquivo).

### Como enviar um modelo para auditoria

Anexe o `.task` (ou informe nome, origem, tamanho e SHA-256). A auditoria então verifica: cabeçalho,
tamanho, RAM estimada, resposta em português, aderência à personalidade, contexto útil e estabilidade.
Sem o arquivo, qualquer número seria invenção.
