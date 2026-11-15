# Fase 8 — Visão de imagem (entrega para aprovação)

**Branch:** `work/1.48.0-fase2-consolidacao`
**Escopo desta entrega:** analisar uma imagem **escolhida pelo usuário**, com autorização explícita,
por um provedor que aceita imagem. Sem reconhecimento facial, sem identificar pessoas e sem guardar
a foto. OCR local e vídeo continuam fora.

## O que existe de verdade

| # | Item | Estado | Evidência |
|---|---|---|---|
| 1 | Escolher imagem da galeria ou tirar foto pela câmera do sistema | **Atendido no código** | `image_picker`; `escolherImagemPadrao`; botões “Galeria” e “Câmera” |
| 2 | Consentimento explícito antes de qualquer envio | **Atendido no código** | caixa “Autorizo enviar esta imagem…”; botão de análise exige imagem + consentimento |
| 3 | Enviar a imagem somente a provedor com visão | **Atendido no código** | Gemini 2.5 Flash, Groq Llama 4 Scout, Mistral Pixtral ou OpenRouter Gemini; modelo textual é recusado |
| 4 | Descrever objetos, cena e textos legíveis | **Atendido no contrato** | `instrucaoVisao`; resposta exibida em texto selecionável |
| 5 | Dizer quando algo está ilegível ou incerto, sem inventar | **Atendido no contrato** | prompt manda dizer que não sabe; teste puro trava a frase |
| 6 | Não reconhecer rosto nem identificar pessoas | **Atendido no contrato** | prompt proíbe identificação, idade, emoção, etnia e atributos sensíveis |
| 7 | Não guardar a imagem | **Atendido no código** | imagem só em memória; tela declara isso; teste estático recusa gravação |
| 8 | Limite de tamanho e formato antes do envio | **Atendido no código** | 4 MB; JPEG, PNG e WebP; recusa HEIC e arquivo vazio |
| 9 | OCR local / modelo de visão no aparelho | **Não entregue** | exige runtime e modelo; a tela diz que análise local não existe |
| 10 | Precisão real do modelo com fotos do usuário | **Pendente** | sem chave real e sem aparelho, nenhuma imagem foi analisada por modelo |
| 11 | Câmera, galeria e permissões no Poco X7 | **Pendente** | plugin nunca rodou neste ambiente; sem Android SDK |

## Privacidade, sem promessa vazia

- A imagem só sai depois de marcar a autorização; trocar de imagem desmarca a caixa.
- O app não grava a imagem em disco, não a inclui no cofre e não a coloca no histórico da conversa.
- O provedor recebe a imagem apenas naquela requisição; a política de retenção é a do provedor, não
  uma garantia do app.
- Nada de rosto: o pedido proíbe identificação, reconhecimento facial, idade, emoção, saúde, etnia
  ou qualquer atributo sensível; documento, placa e localização também devem ser ignorados.
- Se o usuário pedir “identifique a pessoa”, a proibição continua no prompt — o pedido é anexado,
  não substitui a regra.

## Verificação

```
dart run tool/visao_test.dart              → OK (limite, prompt, multimodal, resposta)
flutter test test/visao_page_test.dart     → 5 testes, All tests passed!
python3 tests/test_visao_flutter.py        → OK (estático)
flutter test                               → 95 testes, All tests passed!
flutter analyze                            → No issues found!
npm run verificar                          → 4 de 4 etapas, 2.379 verificações
```

## Limites

- **Nenhuma imagem real passou por um modelo**: sem chave de provedor, está provado o que o app
  monta e envia, não a qualidade da descrição.
- **Câmera e galeria não foram exercitadas**: o plugin `image_picker` não roda neste ambiente e a
  permissão/retorno do sistema só se confirma no aparelho.
- **Sem OCR local**: textos são lidos pelo modelo do provedor; não há reconhecimento offline.
- A detecção do que é “atributo sensível” depende do modelo obedecer ao prompt; o app não tem um
  filtro próprio que apague uma resposta que identifique alguém.
- HEIC é recusado com mensagem; se a câmera do aparelho devolver HEIC, o usuário precisa escolher
  outra imagem.
