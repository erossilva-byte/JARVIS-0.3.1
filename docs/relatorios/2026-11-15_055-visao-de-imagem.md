# Ajuste 055 — Fase 8: visão de imagem (2026-11-15)

## Por que

O Flutter só tinha o módulo “Visão e OCR” no catálogo, abrindo uma página genérica. A Fase 8 pede
analisar uma imagem escolhida pelo usuário, com consentimento e sem reconhecimento facial.

## Como ficou

- **Escolha da imagem** pela galeria ou pela câmera do sistema (`image_picker`), com redução para
  1600 px e qualidade 82 antes de medir o limite.
- **Validação antes do envio**: 4 MB, JPEG/PNG/WebP. Arquivo vazio ou HEIC é recusado com mensagem;
  nada é enviado.
- **Consentimento explícito**: a caixa começa desmarcada e é desmarcada ao trocar de imagem. O botão
  “Analisar imagem” só habilita com imagem, autorização e provedor configurado.
- **Provedor com visão**: Gemini 2.5 Flash, Groq Llama 4 Scout, Mistral Pixtral e OpenRouter Gemini,
  nessa ordem, usando a chave já guardada no cofre. Modelo textual não entra na lista.
- **Requisição multimodal** no formato OpenAI-compatible: texto de instrução + imagem em data URL.
  A resposta é lida como string ou lista de partes e mostrada em texto selecionável.
- **Prompt com limites**: descrever só o visível; dizer quando está borrado ou incerto; não
  identificar pessoas, não fazer reconhecimento facial, não estimar idade/emoção/saúde/etnia e não
  deduzir documento, placa ou localização. O pedido do usuário é anexado sem derrubar a proibição.
- **Sem armazenamento**: a imagem vive só na memória da tela; não vai para o histórico, para o cofre
  nem para preferências. A tela declara isso e o teste estático recusa gravação.
- O menu “Visão e OCR” passou a abrir a tela real, não o catálogo genérico.

## Verificação

```
dart run tool/visao_test.dart              → OK
flutter test test/visao_page_test.dart     → 5 testes, All tests passed!
python3 tests/test_visao_flutter.py        → OK (estático)
flutter test                               → 95 testes, All tests passed!
flutter analyze                            → No issues found!
npm run verificar                          → 4 de 4 etapas, 2.379 verificações
```

O teste puro cobre recusa de imagem vazia/acima de 4 MB/HEIC, formatos aceitos, proibição de
identificação mesmo quando o usuário pede, corpo multimodal com base64 correspondente, leitura de
resposta em string e em lista, resposta vazia e lista de provedores sem modelo textual. Os cinco
testes de widget cobrem bloqueio sem imagem/consentimento, escolha que não envia sozinho, envio só
após autorização, ausência de provedor, erro do provedor sem perder a imagem e formato recusado antes
do envio.

## Limites

- Sem chave real, **nenhuma imagem foi analisada por modelo**: a precisão e a obediência ao prompt
  não foram medidas.
- Sem aparelho, câmera, galeria, permissões e o plugin `image_picker` não foram exercitados.
- OCR local não existe; a leitura de texto depende do provedor.
- O app não tem filtro próprio que apague uma resposta que identifique alguém; a proteção é a
  instrução do prompt, e o modelo pode desobedecer.
- HEIC é recusado; câmera que devolve HEIC exige escolher outra imagem.
