# Relatório — Fase 2, ajuste 006: auditoria do contrato de conversa

## 1. O que foi auditado

O item aberto da Fase 2 pede quatro coisas: integrar Hermes/Core, cuidar do histórico, da
persona/humor e do roteamento de ferramentas — sem permitir ação sensível sem confirmação. A
auditoria foi feita lendo o caminho real de um turno no código, não a descrição nos documentos, e
cada afirmação abaixo tem arquivo e função correspondentes.

## 2. O contrato como ele realmente é

| Etapa | Onde | O que garante |
|---|---|---|
| Entrada | `app.js` → `enviarTexto`/`enviarComando` → `turno()` | Um único ponto de entrada para texto digitado e fala reconhecida; arquivos anexados entram no mesmo pedido. |
| Rotas locais, antes do Hermes | `app.js` → `responderCore()`, `responderProjetista()`, `responderPessoaPorVoz()` | Só respondem ao que sabem provar (status, projetos, projetos elétricos, fichas de pessoas) e **não** executam ação de risco. |
| Núcleo Hermes | `hermes.js` → `despachar()` | Ordem: habilidade própria (saudação, briefing, diagnóstico, status, visão) → comando no aparelho → IA. Os dois primeiros degraus não gastam cota. |
| IA | `app.js` → `chamar()` + `hermes.js` → `planejarIA()` | Fila de provedores por tipo de tarefa, latência medida e falhas recentes; cada provedor que falha entra em pausa e o próximo assume. |
| Validação da decisão | `hermes.js` → `validarDecisao()` | Ação inventada, desconhecida ou indisponível na plataforma é descartada (a fala continua); a fala nunca sai vazia. |
| Persona e humor | `app.js` → `promptSistema()` | Injeta identidade, personalidade, limites, calibragem de humor, nível configurado, tom do turno (sensível/pressa), plano cognitivo interno, memória, pessoas, aprendizado, lista real de ações e o contrato de JSON. |
| Histórico | `app.js` → `hist` + `COGNICAO.selecionarHistorico()` | 120 mensagens em memória, 40 persistidas em `jv_historico_conversa`; seleção por relevância quando há referência; com o contexto desligado, vai só a mensagem atual. |
| Confirmação | `app.js` → `executarSeguro()` | Risco ≥ 2 exige confirmação explícita; risco ≥ 3 exige PIN cadastrado; modo seguro bloqueia risco ≥ 2; limite de 8 s entre ações críticas; ação de turno com conteúdo externo (possível injeção) nunca é executada. |

Conclusão da leitura: o contrato existe e é conservador — o modelo **pede** a ação, o aplicativo
**decide** se ela pode rodar. Não foi encontrado caminho em que a fala do modelo execute ferramenta
direto.

## 3. Defeitos encontrados e corrigidos

### 3.1 Histórico era enviado fora de ordem

`COGNICAO.selecionarHistorico()` pegava as últimas mensagens e **anexava no fim** as mensagens
antigas trazidas por relevância. O modelo recebia, por exemplo, a conversa de agora e, depois dela,
um turno de dez mensagens atrás — e a pergunta atual deixava de ser a última da lista, justamente o
que o prompt usa para “acompanhar o fio da conversa”.

Correção em `cognicao.js`: a seleção passou a devolver os turnos na ordem original, sempre com o
turno atual por último; quando o teto é atingido, sai o turno mais antigo **não** marcado como
relevante.

### 3.2 A checagem de repetição nunca disparava

O histórico guarda a resposta inteira do modelo (`{"fala":"...","acao":{...}}`), mas
`revisarSaida()` comparava a fala nova com esse texto bruto. Como o JSON nunca é igual à fala, o
problema `repetida` era impossível de ocorrer.

Correção em `cognicao.js`: nova função `falaDoTurno()` extrai a fala do turno guardado, e
`verificarResposta()` compara a fala nova com ela. O `app.js` não precisou mudar.

### 3.3 Comentário do Hermes dizia mais do que ele faz (registrado, correção pendente)

O cabeçalho de `hermes.js` afirma que “todo turno passa por aqui”. Não passa: Core, projetista
elétrico e fichas de pessoas respondem antes, dentro do `app.js`. O texto correto está abaixo e a
correção do comentário fica pendente — `hermes.js` tem cerca de 49 KB e a via de publicação usada
nesta sessão trabalha com arquivos pequenos:

```
O Hermes decide a rota de todo turno que não foi resolvido antes dele no próprio aplicativo:
comandos do Core, do projetista elétrico e das fichas de pessoas respondem primeiro, em app.js,
e só o que sobra chega aqui.
```

Documento que descreve rota inexistente é o mesmo problema dos indicadores enganosos da matriz;
por isso a divergência está registrada, em vez de silenciada.

## 4. Evidência

- `node tests/test_cognicao.js` → **31 verificações aprovadas**, incluindo as novas: ordem
  cronológica do histórico, turno atual por último, turno antigo relevante preservado, teto
  respeitado, `falaDoTurno` com JSON e com texto puro, e repetição detectada a partir do turno em
  JSON.
- `npm run test:all` (a mesma suíte que o CI roda) → **exit 0**, sem regressão.

## 5. Observações que ficaram como pendência (não corrigidas)

- **Turnos resolvidos por habilidade do Hermes não entram no histórico.** Saudação, briefing e
  diagnóstico são falados e não são gravados; ao retomar a conversa, o modelo não sabe que eles
  aconteceram. É uma escolha defensável (não são conteúdo conversacional), mas é uma lacuna do
  contrato, não uma virtude.
- **Persistência corta em 40 mensagens** ao reiniciar, enquanto em memória ficam 120.
- **Não há medição de tamanho de prompt**: `promptSistema()` cresce com memória, pessoas e
  aprendizado; nada mede tokens antes do envio.
- **Confirmação por voz** (`confirmar()` com `falar`/`ouvirUmaVez`) nunca foi exercitada em
  aparelho — inclusive o caso de ruído fazer o “sim” ser reconhecido errado.
- Nada foi executado em Android ou Windows nesta auditoria: o que está provado é o comportamento
  dos módulos em Node e a leitura do caminho no código.
