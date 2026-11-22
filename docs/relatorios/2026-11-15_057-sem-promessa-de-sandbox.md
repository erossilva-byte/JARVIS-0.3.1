# Ajuste 057 — remover a promessa de execução isolada (2026-11-15)

## Por que

O catálogo Flutter descrevia “Programação e sandbox” como “Assistência de código e execução
isolada”, mas a Fase 9 não entrega execução de código. A frase prometia o que a própria tela de
Arquivos nega — exatamente o tipo de indicador enganoso que o projeto proíbe.

## Como ficou

- Módulo renomeado para **“Programação (sem execução)”**, com descrição “Assistência de código;
  sandbox e execução não disponíveis.”
- A gaveta passou de “Dev. Arquivos” para **“Código sem execução”** e aponta para o nome novo.
- A tela do módulo, em vez do aviso genérico de integração, mostra **“Execução de código não
  disponível”** e explica: não há sandbox, terminal ou permissão para rodar programas; arquivos de
  texto ficam em Arquivos, na pasta isolada.
- Os outros módulos continuam com o aviso genérico — a condição é só para este.
- A tela de Arquivos já dizia que execução não existe; nada nela mudou.

## Verificação

```
flutter test test/programacao_sem_execucao_test.dart → 4 testes, All tests passed!
python3 tests/test_arquivos_flutter.py               → OK (estático)
flutter test                                         → 107 testes, All tests passed!
flutter analyze                                      → No issues found!
npm run verificar                                    → 4 de 4 etapas, 2.380 verificações
```

O teste de widget prova que o catálogo não tem mais o nome antigo, que a tela do módulo declara a
ausência e não mostra “Integração em auditoria”, que outro módulo continua com o aviso genérico e
que a gaveta não usa mais “Dev. Arquivos”. O estático reprova se a frase “Assistência de código e
execução isolada” voltar ao catálogo ou se a tela perder a declaração.

## Limites

- A decisão de não executar código continua valendo; isto só alinha o texto à realidade.
- O app legado (WebView) ainda tem o sandbox JavaScript dele, com os limites já documentados; não foi
  alterado por este ajuste.
