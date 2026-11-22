# Fase 4B — critérios de aceite

Data: 2026-11-13 · Branch: `work/1.48.0-fase2-consolidacao`

Regra da fase: **nada é declarado pronto sem evidência**. Implementação verificada por teste
local e código; comportamento no aparelho só vale com medição registrada.

## 1. Situação por requisito

| # | Requisito | Implementação | Evidência local | Estado |
|---|---|---|---|---|
| 1 | Serviço de escuta em primeiro plano | `JarvisService` com tipo `microphone|dataSync` | `test_perfil_energia`, `test_segundo_plano` | Implementado — **não compilado** |
| 2 | Notificação com Pausar/Retomar, Abrir, Ouvir agora, Desligar | `JarvisService.montarNotificacao` | `test_perfil_energia` | Implementado — não medido |
| 3 | Perfis Sempre / Carregando / Horários / Desligado | `bloqueioPerfil` + `JarvisPrefs` | `test_perfil_energia` | Implementado — não medido |
| 4 | Redução por bateria ≤ limite (10/15/20) e economia | `bloqueioBateria` | `test_perfil_energia` | Implementado — não medido |
| 5 | Manutenção periódica com WorkManager | `JarvisManutencaoWorker` (6 h, bateria não baixa) | `test_manutencao` | Implementado — não compilado |
| 6 | Fone desconectado e microfone tomado | `ACTION_AUDIO_BECOMING_NOISY`, `getActiveRecordingConfigurations` + sessão do `AudioRecord` | `test_microfone` | Implementado — não medido |
| 7 | "Por que parou?" explica a parada | `segundo_plano.js` + botão | `test_segundo_plano` | Implementado |
| 8 | Linha do microfone em tempo real | `estadoMicrofone` + laço de 2,5 s | `test_microfone` | Implementado — não medido |
| 9 | Nenhum áudio sai antes da ativação | auditoria + `TrafficStats` + roteiro | `test_privacidade` | Preparado — **provas 2–4 pendentes** |
| 10 | Nada de mock | — | código real, sem dados falsos | Mantido |

## 2. Pré-checagem antes do CI

```
npm run verificar
```

O comando roda pré-checagem, suíte completa e empacotamento em sequência e imprime um resumo
com estado, tempo e contagem. Individualmente, as mesmas etapas são `python3
ci/preflight_android.py`, `npm run test:all` e `python3 tests/test_empacotamento.py`.

A pré-checagem é o primeiro passo de `npm run test:all` (falha ali para a suíte) e valida:
classe citada que não existe, classe fora da lista copiada pelos
workflows, dependência do WorkManager ausente, tipo do serviço no manifesto, script carregado
pelo `index.html` fora do pacote, teste não executado pela suíte, método estático do serviço
usado pelo plugin que não existe, API que exige permissão de sistema usada sem revisão
registrada, permissão usada no código e não declarada, e permissão de sistema pedida no
manifesto. Ela **não compila** e não substitui o CI.

## 3. Checklist no Poco X7 (preencher em `FASE-4B-FICHA-MEDICAO.md`)

| Item | Como medir | Critério de aceite | Resultado |
|---|---|---|---|
| Consumo em espera | 8 h com tela apagada | ≤ 3%/h e serviço ativo no fim | |
| Reconhecimento PT-BR | 20 tentativas em silêncio + 20 com ruído | registrar taxa; sem meta inventada | |
| Pausar/Retomar | notificar e conferir com tela apagada | pausa persiste; retomada funciona | |
| Perfis | cada um dos quatro, com o estado esperado | microfone não abre fora da condição | |
| Bateria | 15% (e limite trocado) e economia ligada | reduz e volta sozinho ao carregar | |
| WorkManager | "Rodar manutenção agora" e 6 h | última verificação avança; lembretes restaurados | |
| Fone | desconectar Bluetooth e cabo | pausa e retoma em ~5 s | |
| Microfone tomado | gravador de voz do sistema | pausa com aviso na tela; retoma ao fechar | |
| Reinício / Doze / recentes / economia | `FASE-4B-FICHA-MEDICAO.md`, teste B | escuta volta em até 15 min | |
| Privacidade | 4 provas de `FASE-4B-PRIVACIDADE.md` | zero áudio e zero tráfego em espera | |

## 4. Definição de pronto da fase

1. CI compila o APK **com** as classes novas (artefato gerado).
2. Ficha preenchida com os dez itens acima.
3. Nenhum item com resultado "—"; itens reprovados viram correção com relatório próprio.
4. Relatórios 021–029 refletindo o estado real, sem promessa além do medido.

## 5. Riscos abertos (conhecidos, não escondidos)

- Modelo de ativação treinado em inglês; taxa em PT-BR é desconhecida até a medição.
- HyperOS pode matar o serviço; o vigia recupera em até 15 min, mas o atraso não foi medido.
- `getActiveRecordingConfigurations()` pode vir vazio em algumas versões/OEM; vazio é tratado
  como "livre" — e isso significa que a pausa por microfone ocupado pode não disparar.
- O Android não informa **qual** app está gravando para um app comum (`MODIFY_AUDIO_ROUTING` é
  de sistema): a notificação diz "outro app", sem nome.
- `TrafficStats` é por app e não diz o conteúdo; a prova de áudio é a inspeção de código.
- Rotinas não rodam em segundo plano: um Worker não executa o JavaScript da interface.
