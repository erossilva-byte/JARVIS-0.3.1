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
