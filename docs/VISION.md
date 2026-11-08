# Vision — diagnóstico, o que mudou e o que não foi provado

Documento da revisão 1.42.8. Ele separa o que é determinístico e testado do que depende de modelo
externo e **não foi validado** nesta máquina (sem chave de IA, sem câmera, sem aparelho físico).

## 1. Diagnóstico do Vision anterior

| Peça | Estado encontrado | Problema |
|---|---|---|
| `visao.js` | geometria de balões, plano de quadros de vídeo, relato e texto | correto e testado; **não guarda contexto** |
| Câmera e galeria | `analisarQuadro` / `analisarDataUrl` em `app.js` | captura e envio funcionam com provedor; sem provedor não há resposta |
| Modelos | `hermes.js` → Gemini 2.5 Flash / `gemini-flash-latest`, Groq `llama-4-scout`, Mistral `pixtral-12b` | escolha por provedor com visão; **nenhum teste real** de precisão sem chave |
| Objetos e balões | `normalizar`, `layoutBaloes`, lista lateral | posiciona; **não resolve "ele", "essa peça"** |
| Pergunta de acompanhamento | reenviava a imagem com a pergunta | o modelo recebia a pergunta sem o referente explícito; contexto vivia só na tela |
| Memória | botão "Salvar resumo na memória" | existia, mas sem procedência nem distinção estimativa × confirmado |
| OCR | texto do modelo | texto de imagem podia voltar como se fosse instrução confiável |
| Integração técnica | nenhuma | um contator fotografado não conversava com o Projetista elétrico |

## 2. O que foi implementado (determinístico, testado em Node)

Novo núcleo `visao_contexto.js`, sem DOM e sem rede:

- **Memória da sessão**: objetos da última análise, objeto atual, seleção por índice, contagem de análises e histórico curto de perguntas.
- **Acompanhamento**: reconhece pronomes e perguntas curtas ("ele", "essa", "e quanto custa?") e resolve para o objeto atual, sem repetir a imagem.
- **Procedência**: `rotular()` classifica cada afirmação em `confirmado` (fabricante/manual/etiqueta), `loja` (anúncio) ou `estimado` (visual). Marca e modelo **são apagados** quando não há evidência legível.
- **Consultas de pesquisa**: monta termos por intenção (preço, ficha técnica, onde comprar, compatibilidade) a partir do que foi realmente identificado.
- **Múltiplos objetos**: lista, seleção e comparação determinística de atributos, sem emitir opinião sem dado.
- **Ponte técnica**: objeto reconhecido como contator, disjuntor, térmico, motor, CLP, temporizador, transformador, sensor ou sinaleiro é consultado em `eletrica.js` (terminais, função, limites) e relacionado ao Projetista elétrico.
- **OCR como dado**: `limparTextoOcr()` descarta linhas que tentam instruir o sistema ("ignore as instruções", `system:`, comandos) e marca o restante como `dado`.
- **Privacidade**: nada é salvo automaticamente; `podeSalvar()` exige pedido explícito e registra que a imagem **não** é guardada, só texto e atributos.

No aplicativo: cada análise registra o contexto; a pergunta de acompanhamento envia ao modelo o referente explícito ("contexto visual: contator 25 A, marca não confirmada") e perguntas técnicas são respondidas **localmente**, sem rede, pela base elétrica.

## 3. Modelos de visão

Os mesmos do roteador (`hermes.js`), sem adicionar dependência: Gemini 2.5 Flash e `gemini-flash-latest` (Google), `meta-llama/llama-4-scout-17b-16e-instruct` (Groq) e `pixtral-12b-2409` (Mistral). Nenhum modelo local de visão foi embarcado: o app Android/Windows não tem runtime de inferência visual, e adicionar um exigiria modelo de centenas de MB sem ganho comprovado.

## 4. Integração com pesquisa

As consultas são montadas localmente (`consultas(objeto, intencao)`). A busca em si continua sendo a que o app já tem (`pesquisarWeb`), e o resultado deve citar a fonte. Este documento **não** afirma que a busca foi executada para imagens reais: sem chave não há chamada de rede, e a integração de preço/loja não foi validada ponta a ponta.

## 5. Exemplos que o motor resolve hoje (sem rede)

- "Que tênis é esse?" → hipótese "calçado esportivo", marca/modelo só se houver logo, etiqueta ou texto legível; senão pede foto de detalhe.
- "Ele é bom para corrida?" → mesma referência da pergunta anterior, intenção `uso`.
- "E quanto custa?" → mesma referência, intenção `preco`, consulta "marca modelo preço onde comprar".
- "Esse componente serve no meu projeto?" → contator → `EletricaBase` (A1/A2, 13/14, 21/22, limites) + relação com o Projetista.
- "Identifique essas ferramentas" → lista de objetos com seleção individual e comparação.
- "É de couro?" → `estimado` se só pela aparência; `confirmado` apenas com manual/etiqueta.

## 6. Testes executados

| Comando | Resultado |
|---|---|
| `node tests/test_visao_contexto.js` | 11 grupos OK (evidência, acompanhamento, múltiplos objetos, consultas, procedência, OCR, base elétrica, resposta honesta, privacidade) |
| `node tests/test_visao_nova.js` | 8 grupos OK (geometria e vídeo, inalterado) |
| `node tests/test_cad_circuito_ui.js` | app inteiro no jsdom, incluindo pergunta técnica respondida pelo contexto |

## 7. Limitações (não declarar resolvidas)

- **Precisão de identificação não medida**: sem chave de IA e sem conjunto de imagens rotuladas, não há número de acerto. O que existe é o contrato de honestidade (evidência → confiança).
- **Sem busca automática de preço/loja validada**: as consultas são geradas; a execução depende do provedor e não foi testada com imagem real.
- **Sem OCR próprio**: o texto vem do modelo multimodal; não há Tesseract/ML Kit embarcado.
- **Sem vídeo em tempo real**: o plano de quadros existe e é testado; a análise ao vivo continua manual por quadro.
- **Sem câmera nem Windows reais nesta máquina**: nada foi validado em aparelho físico; assinatura debug/CI.
- **Sem conversão de imagem em netlist**: identificar símbolo e reconstruir circuito exige contrato visual dedicado e confirmação humana; continua fora do escopo.
