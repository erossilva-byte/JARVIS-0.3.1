# Catálogo de funcionalidades — cobertura real na 1.43.0

Este documento responde ao catálogo de 76 áreas dos oito JARVIS. Ele não promete o que não
existe: cada linha diz **onde** a capacidade está, ou **do que ela depende**. O critério é
simples — só entra como “pronto” o que tem código no projeto e verificação automatizada.

## Como ler

- **Já existia** — implementado antes da 1.43.0, com testes no `npm run test:all`.
- **Novo 1.43.0** — implementado nesta versão (núcleos puros + painel + chat local).
- **Parcial** — funciona, mas com limite explícito (ex.: offline, dados curados).
- **Depende de conta/chave** — precisa de serviço externo e credencial do usuário.
- **Depende de hardware/permissão** — precisa de sensor, Android específico ou acesso do sistema.
- **Roadmap** — não implementado; sem promessa de prazo.

## Parte 1 — Inteligência artificial e raciocínio

| Área | Situação | Onde / limite |
|---|---|---|
| 1. Conversação, contexto, personalidade | Já existia | Hermes + Groq/Mistral, memória, perfis, humor; IA exige chave |
| 2. Raciocínio, plano, agentes, ReAct | Já existia (parcial) | `agentes.js`, `plano.js`, Core; sem orquestração arbitrária de modelos |
| 3. Seleção/fallback de modelos | Parcial | fallback e limites no app; não há ranking automático por custo/latência |
| 4. Agentes especializados | Parcial | agentes do Core; sem runtime externo nem MCP |

## Parte 2 — Voz e comunicação

| Área | Situação | Onde / limite |
|---|---|---|
| 5. Reconhecimento de voz, VAD, wake word | Já existia | `escuta.js`, `voz_motor.js`, ativação “Jarvis”; depende de microfone/permissão |
| 6. Síntese de voz e troca de vozes | Já existia | TTS nativo, perfis de voz; ElevenLabs/Fish não integrados |
| 7. Conversa em tempo real, barge-in | Parcial | interrupção de fala existe; sem sessão duplex contínua |
| 8. Controles de voz/áudio | Já existia | testes de áudio, push-to-talk, seleção de microfone conforme Android |

## Parte 3 — Pesquisa e internet

| Área | Situação | Onde / limite |
|---|---|---|
| 9. Pesquisa web, notícias, páginas | Já existia | Hermes/pesquisa e painel Informações; exige rede |
| 10. Pesquisa aprofundada multi-etapas | Parcial | plano multi-etapas; sem índice próprio |
| 11. Monitoramento de assuntos | Novo 1.43.0 (núcleo) | `briefing.js`: comparação de listas com novidades/saídas; agendamento usa as rotinas existentes |

## Parte 4 — Automação do dispositivo

| Área | Situação | Onde / limite |
|---|---|---|
| 12. Controle de aplicativos e acessibilidade | Parcial | abrir apps e ações via plugins; cliques por texto dependem de serviço de acessibilidade |
| 13. Configurações do aparelho | Já existia | lanterna, volume, brilho, mídia, status |
| 14. Chamadas, SMS e notificações | Já existia | discador/composição com confirmação; respostas a notificações |
| 15. Navegação e mapas | Já existia | intents para Maps/rotas |
| 16. Alarmes, timers e lembretes | Já existia | alarmes, lembretes e rotinas agendadas |

## Parte 5 — Computadores e outros dispositivos

| Área | Situação | Onde / limite |
|---|---|---|
| 17. Controle de computador | Parcial | app desktop e `pc.js` para arquivos/CAD; sem mouse/teclado remotos |
| 18. Integração celular–PC, pareamento | Parcial | arquivos e diagnóstico; sem espelhamento de tela nem Wake-on-LAN |
| 19. Controle de TV | Roadmap | depende de ADB/rede e app na TV; não implementado |

## Parte 6 — Visão e multimídia

| Área | Situação | Onde / limite |
|---|---|---|
| 20. Visão computacional, OCR, imagens | Já existia | `visao.js`, `visao_contexto.js`, câmera e análise; sem pose/gestos |
| 21. Gestos por câmera (MediaPipe) | Roadmap | exigiria MediaPipe e calibração; não implementado |
| 22. Captura de tela e câmera | Já existia | captura e envio de imagem ao modelo |
| 23. Geração de imagens | Depende de conta/chave | precisa de provedor de imagem; não configurado |
| 24. Áudio e vídeo | Já existia | música, vídeo local/URL, controles; sem Netflix/YouTube integrados |

## Parte 7 — Memória e personalização

| Área | Situação | Onde / limite |
|---|---|---|
| 25. Memória de longo prazo | Já existia | cofre Obsidian, busca semântica e por palavra-chave |
| 26. Memória documental / RAG | Parcial | notas e arquivos indexáveis; sem FAISS/ColBERT |
| 27. Personalidade configurável | Já existia | nome, tom, idioma, tamanho de resposta |
| 28. Sessões e continuidade | Parcial | histórico e retomada; resumo automático de sessão agora tem núcleo (`briefing.js`) |
| 29. Memória proativa / briefing | Novo 1.43.0 (núcleo) | briefing local que não inventa dados; sugestão de rotina de casa pede confirmação |

## Parte 8 — Produtividade

| Área | Situação | Onde / limite |
|---|---|---|
| 30. Agenda e calendário | Parcial | agenda local e lembretes; sem sincronização Google/CalDAV |
| 31. Tarefas, foco e rotinas | Já existia | tarefas, modo foco, rotinas por voz/interface |
| 32. Briefing matinal | Novo 1.43.0 | `briefing.js` + seção Briefing no painel; clima/manchetes entram se fornecidos |
| 33. Gestão de arquivos | Já existia | listar, ler, organizar, converter, exportar com confirmação |
| 34. Documentos e conteúdo | Parcial | redação via IA; sem geração de apresentações |
| 35. Área de transferência | Roadmap | exigiria serviço de acessibilidade/leitura de clipboard |

## Parte 9 — Ferramentas técnicas

| Área | Situação | Onde / limite |
|---|---|---|
| 36. Programação e execução | Parcial | análise/geração de código; sem REPL Python no aparelho |
| 37. Cálculos e matemática | Novo 1.43.0 | `utilidades.js`: expressões, fatorial, equações, matrizes, estatística, bases |
| 38. Ferramentas de sistema | Já existia | bateria, RAM, armazenamento, rede, diagnóstico |
| 39. Conversões, QR, aleatoriedade | Novo 1.43.0 (sem QR) | unidades, temperatura, bases, senha, números e listas; QR não implementado |

## Parte 10 — Cotidiano

| Área | Situação | Onde / limite |
|---|---|---|
| 40. Entretenimento e sugestões | Novo 1.43.0 | filmes, séries, música e atividades no acervo local |
| 41. Jogos | Novo 1.43.0 | blackjack, velha, ligue 4, forca, PPT, adivinha, termo e roleta de fichas |
| 42. Esportes | Depende de conta/chave | exige fonte esportiva; não configurada |
| 43. Clima | Já existia | clima real com cidade configurada; exige rede |
| 44. Saúde, alimentação e exercícios | Novo 1.43.0 (informativo) | IMC/BMR/água, nutrição de frutas, receitas e treinos; não é sistema médico |
| 45. Finanças e mercado | Parcial + Novo | simulação local de juros/ROI; cotações reais exigem fonte |
| 46. Receitas e bebidas | Novo 1.43.0 | 8 receitas e 5 bebidas com ingredientes e modo |
| 47. Piadas e curiosidades | Novo 1.43.0 | acervo local de 12 piadas e 12 curiosidades |

## Parte 11 — Integrações externas

| Área | Situação | Onde / limite |
|---|---|---|
| 48. E-mail e comunicação | Roadmap | Gmail/Slack exigem OAuth e backend; não configurado |
| 49. Armazenamento e produtividade | Parcial | arquivos locais; sem Drive/Trello |
| 50. Serviços de mídia | Parcial | reprodução local/URL; sem Spotify/Netflix |
| 51. Plugins especializados (Cakto, rastreio) | Roadmap | dependem de APIs e chaves próprias |
| 52. MCP e plugins | Roadmap | sem runtime MCP no APK |

## Parte 12 — Interface

| Área | Situação | Onde / limite |
|---|---|---|
| 53. Interface holográfica | Já existia | núcleo, órbitas, avatar e animações; sem sincronia labial |
| 54. Personalização visual | Parcial | temas/cores e modos; sem importação de temas |
| 55. Painéis dinâmicos | Já existia + Novo | painéis de sistema, visão, memória e agora Utilidades |
| 56. Gerenciamento | Já existia | Ajustes por abas, diagnóstico, agentes, memória |
| 57. Controles por voz da interface | Parcial | abrir painéis e comandos; sem controle de cores por voz |

## Parte 13 — Autonomia

| Área | Situação | Onde / limite |
|---|---|---|
| 58. Automação multi-etapas | Parcial | plano/agentes com passos permitidos; sem replanejamento livre |
| 59. Monitoramento contínuo | Parcial | rotinas agendadas + diff de listas (1.43.0) |
| 60. Rotinas automatizadas | Já existia | rotinas por voz/interface e agendadas |
| 61. Execução com verificação | Parcial | arquivos/CAD verificam; nem toda ação tem prova |
| 62. Desfazer ações | Parcial | arquivos com versão nova; sem desfazer universal |

## Parte 14 — Segurança e diagnóstico

| Área | Situação | Onde / limite |
|---|---|---|
| 63. Autorização de operações | Já existia | confirmações, operações sensíveis com biometria/PIN |
| 64. Proteção de dados | Já existia | chaves no Keystore, PIN PBKDF2, NFC em hash, sem imagens de rosto |
| 65. Diagnóstico | Já existia | Core, testes de áudio, rede, provedores |
| 66. Controle de interrupção | Já existia | parar fala, cancelar tarefa, cancelar leitura NFC |

## Parte 15 — Inventário por projeto

As 76 áreas acima já consolidam os oito repositórios. Recursos que **não** foram trazidos
por exigirem outro runtime ou serviço: controle de TV por ADB, MediaPipe/gestos, avatar com
sincronia labial, MCP, Gmail/Drive/Slack/Trello, Spotify/Netflix, REPL Python, FAISS/ColBERT,
espelhamento celular–PC, OCR dedicado e geração de imagens.

## Lacunas desta versão (honestas)

1. Nada foi validado em aparelho físico nesta rodada: o painel novo depende de teste visual.
2. Cotações, esportes e notícias em tempo real continuam dependendo de rede/fonte.
3. O briefing **não busca** clima/manchetes sozinho na 1.43.0; ele usa o que o painel
   Informações ou o usuário fornecerem. Isso é deliberado para não inventar dados.
4. Jogos e acervo são locais e finitos; não há ranking online.
5. O catálogo completo dos oito projetos é aspiracional: várias linhas seguem como roadmap.
