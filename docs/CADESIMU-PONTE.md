# Ponte CADeSIMU — o que é conferido e o que não é

O J.A.R.V.I.S. Nova **não lê nem gera o `.cad` nativo do CADeSIMU**. Esse formato é proprietário e
não tem especificação pública; afirmar compatibilidade sem um arquivo real para testar seria mentira.

O que existe é uma **ponte de conferência e intercâmbio** para levar o projeto ao CADeSIMU por
redesenho manual, com menos erro:

## `conferirTrocaCadesimu(projeto)`

Checklist determinístico, sem IA:

- verificação estrutural do projeto (`validar`);
- todo tipo de componente tem símbolo mapeado (`MAPA_CADESIMU`, descrição IEC);
- todo terminal obrigatório tem rede;
- nenhum terminal obrigatório com rede vazia;
- nenhum curto declarado entre polos do mesmo componente;
- netlist v1 exportável.

Devolve `ok`, `nativo: false`, a lista de verificações e as pendências. Qualquer item reprovado
aparece com o componente e o terminal.

## `exportarTrocaCadesimu(projeto)`

Gera um JSON `JARVIS-CADESIMU-TROCA` v1 com:

- título, tipo e especificação (CV, tensão, comando, temporização);
- componentes com `simbolo_iec`, posição, terminais, tensão e tempo;
- redes de energia/retorno/fases;
- netlist v1 completa;
- o resultado do checklist.

O nome do arquivo termina em `.cadesimu-troca.json`. Ele **não** abre no CADeSIMU; serve para
redesenhar, colar dados e conferir terminal por terminal.

## Limites declarados

- Sem importação do `.cad` nativo.
- Sem biblioteca de símbolos idêntica à do CADeSIMU: o mapa é uma descrição IEC, não um ID de biblioteca.
- Sem simulação elétrica e sem garantia de que o desenho manual ficará igual ao projeto.
- A conferência prova consistência interna do projeto, não compatibilidade com o programa.

## Como usar

1. Crie o circuito no projetista.
2. Gere o relatório técnico e leia a seção "Ponte CADeSIMU".
3. Exporte o JSON (ou use `projetista: cadesimu` no chat para ver o checklist).
4. Redesenhe no CADeSIMU seguindo os terminais e as redes.
5. Compare a netlist do CADeSIMU com a netlist exportada.
