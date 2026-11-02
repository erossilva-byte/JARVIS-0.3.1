# 1.39.0 — Raciocínio em etapas, personalidade adaptativa e verificação

Data: 2026-11-01.

Esta revisão não troca o Hermes, o Core nem o catálogo de ferramentas. Ela acrescenta uma camada determinística antes e depois da IA, para que o turno tenha um plano explícito, use o contexto certo e não entregue uma resposta vazia, genérica, repetida ou que alegue execução não feita.

## O que foi implementado

### 1. Análise do pedido

`cognicao.js` detecta, sem rede e sem DOM:

- intenção: saudação, conversa, pergunta, tarefa ou correção;
- complexidade de 1 a 3;
- assunto sensível e pressa;
- linguagem informal e referências como “aquele projeto”, “isso”, “ontem”;
- necessidade de pesquisa, cálculo ou ferramenta;
- ambiguidade real quando falta contexto.

O resultado inclui cinco etapas internas: compreender, reunir contexto, decidir, responder e verificar.

### 2. Plano interno no prompt

O plano é enviado ao modelo como instrução interna, não como texto para o usuário. Ele orienta:

- não pedir de novo o que o contexto já responde;
- usar pesquisa quando a informação é atual;
- calcular e conferir quando há números;
- usar somente ferramenta disponível e nunca fingir execução;
- responder com profundidade, iniciativa e conversa configuradas;
- verificar a saída antes de concluir.

Isso é combinado com o plano local do Hermes e com as confirmações do `SISTEMA`; o modelo não ganha autorização nova.

### 3. Contexto mais seletivo

`selecionarHistorico` mantém a janela recente e acrescenta mensagens antigas que compartilham termos com o pedido atual. Referências conversacionais aumentam a janela. O histórico continua limitado; nada é enviado além do necessário.

### 4. Verificação e revisão

Antes de a fala ser entregue, `verificarResposta` aponta problemas observáveis:

- fala vazia;
- abertura genérica (“Claro!”, “Como posso ajudar?”);
- humor em assunto sensível;
- resposta curta demais para um pedido complexo;
- alegação de ação quando nenhuma ferramenta foi executada;
- repetição literal de uma fala recente.

`revisarFala` remove aberturas genéricas, normaliza espaços e retira risadas em assunto sensível. A verificação não julga a verdade de fatos externos e não substitui a pesquisa.

### 5. Personalidade adaptativa

Foram adicionados três controles em Ajustes ▸ IA, persistidos no aparelho:

- **Profundidade:** curta, equilibrada ou detalhada;
- **Iniciativa:** baixa, normal ou alta;
- **Comportamento conversacional:** natural ou objetiva.

Os três níveis de humor existentes continuam valendo, assim como os seis eixos de calibragem. Em emergência, saúde, luto, violência ou perda financeira, o humor continua zerado.

## Arquivos

- `cognicao.js` — módulo puro e testável.
- `app.js` — análise por turno, plano no prompt, histórico seletivo, revisão da fala e preferências.
- `index.html` — controles de profundidade, iniciativa e conversa.
- `tests/test_cognicao.js` — 24 verificações determinísticas.
- `tests/test_v1_39_0.py` — contrato de integração e empacotamento.
- workflows, `package.json`, `VERSAO.json` e `LEIA-ME.md` atualizados.

## Testes

- `node tests/test_cognicao.js`.
- `python3 tests/test_v1_39_0.py`.
- Suíte completa `npm run test:all`.
- Regressão dos contratos 1.0–1.38.1.

## Limitações

- A camada é determinística e heurística; não é um modelo de raciocínio simbólico completo.
- A revisão detecta problemas observáveis, não falsidades factuais.
- Provedores reais, modelo local, microfone, aparelho físico, Windows e ESP32/Home Assistant continuam dependendo de chaves, modelos e ambiente externo.
- Nenhum ganho de velocidade, RAM, CPU ou bateria foi medido nesta rodada.

## Build 1.39.0

- Arquivo: `jarvis-nova-1.39.0-10390.apk`.
- Tamanho: 81.202.290 bytes.
- SHA-256: `39341a23fc2bf16680ee89b74b9109799d6b08669755e53695a9241c81f3bcce`.
- `aapt`: `com.jarvis.nova`, 1.39.0, versionCode 10390, minSdk 26, targetSdk 34, compileSdk 35.
- `apksigner`: assinatura v2 verdadeira, chave de CI/debug.
- `npm run test:all`: exit 0 depois do build.
- O APK não foi instalado nem executado em aparelho físico.
