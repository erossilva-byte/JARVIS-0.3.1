# Matriz de capacidades — app Flutter vs. catálogo

**Data:** 2026-11-11 · **Branch:** `work/1.48.0-fase2-consolidacao` · **Alvo:** `flutter_app/`

Este documento responde a uma pergunta só: dos 21 módulos que o catálogo do app Flutter
mostra, quantos têm serviço real por trás? Ele existe porque a regra do projeto é que
nenhum catálogo, tela ou indicador seja tratado como prova de integração funcional.

Critério de estado:

| Estado | Significado |
|---|---|
| **Implementado** | Existe caminho de código no app Flutter que executa a função (ainda sem teste em aparelho) |
| **Parcial** | Existe parte real da função, com limite declarado |
| **Não migrado** | Só existe no app legado (Capacitor/Java) ou não existe |
| **Fora de escopo** | Declarado fora desta sequência de trabalho |

## Matriz dos 21 módulos

| # | Módulo no catálogo | Promessa exibida | O que existe no Flutter | Evidência | Estado |
|---|---|---|---|---|---|
| 1 | Hermes Agent | "Orquestração e execução de agentes." | Nada. Abre a página genérica "Integração em auditoria" | `lib/home_screen.dart` (`_openModule`) | Não migrado |
| 2 | Provedores de IA | "Groq, Gemini, Cerebras, Mistral e OpenRouter." | Página real: salvar chave no cofre seguro, testar conexão, remover, e conversa usando o primeiro provedor configurado | `lib/provider_settings_page.dart`, `test/provider_service_test.dart`, `lib/services/voice_conversation_page.dart` | **Implementado** |
| 3 | Modelos locais | "Modelos locais e operação offline." | Nada. `JarvisLocalAIPlugin.java` é do app legado | — | Não migrado |
| 4 | Agentes especializados | "Agentes por domínio e ferramentas." | Nada | — | Não migrado |
| 5 | Memória semântica | "Contexto e recuperação de informações." | Nada. O histórico da conversa vive só em memória RAM e morre ao fechar a tela | `voice_conversation_page.dart` (`history`) | Não migrado |
| 6 | Obsidian | "Vínculo e sincronização com cofre Obsidian." | Nada. A tela de Ajustes descreve o que falta, sem prometer | `pages.dart` (`SettingsPage`) | Não migrado |
| 7 | Voz e KWS | "Voz, palavra de ativação local e síntese." | Painel de diagnóstico real: ativar, parar, teste de 20 s, estado do plugin e mensagem de indisponibilidade. Bridge `MethodChannel com.jarvis.nova/kws`, só Android | `services/kws_settings_page.dart`, `kws_bridge.dart`, `kws_controller.dart`, `test/kws_controller_test.dart` | **Parcial** (nunca executado em aparelho; modelo é inglês) |
| 8 | Visão e OCR | "Câmera, tela, imagens e documentos." | Nada | — | Não migrado |
| 9 | Arquivos | "Leitura, criação, conversão e organização." | Nada | — | Não migrado |
| 10 | Programação e sandbox | "Assistência de código e execução isolada." | Nada | — | Não migrado |
| 11 | CADeSIMU e elétrica | "Projetos, circuitos e validação elétrica." | Nada | — | Não migrado |
| 12 | Avatar 3D | "Avatar e representação visual do assistente." | Holograma em `CustomPaint`: anéis em perspectiva e 48 pontos orbitais, respondendo a toque e arraste. **Não é malha 3D** | `lib/hologram.dart` (`HologramPainter`) | **Parcial** |
| 13 | Pessoas e contexto | "Perfis e contexto configurável." | Nada | — | Não migrado |
| 14 | Tarefas e rotinas | "Tarefas persistentes e automações." | Nada | — | Não migrado |
| 15 | Segurança e privacidade | "PIN, biometria e permissões suportadas." | Só o cofre de credenciais (`flutter_secure_storage`). Não há PIN, biometria nem gestão de permissões no Flutter | `services/provider_service.dart` (`PlatformSecretStore`) | **Parcial** |
| 16 | Android e dispositivos | "Estado do dispositivo e recursos Android." | Nada | — | Não migrado |
| 17 | Pareamento Windows | "Vínculo seguro entre celular e computador." | Nada | — | Não migrado |
| 18 | Controle do Windows | "Ações autorizadas no computador." | Nada | — | Não migrado |
| 19 | ESP32 e Home Assistant | "Integração residencial e dispositivos." | Nada | Declarado fora de escopo na Fase 2 | Fora de escopo |
| 20 | Backup e restauração | "Cópia e recuperação dos dados." | Nada | — | Não migrado |
| 21 | Atualizações | "Versões, integridade e atualização." | Nada. O atualizador é `JarvisUpdatePlugin.java`, do app legado | — | Não migrado |

**Placar:** 1 implementado · 3 parciais · 16 não migrados · 1 fora de escopo. Total 21.

O congelamento de escopo é coerente com a Fase 2: o app Flutter ainda não substitui Hermes/Core.
A conversa dele chama o provedor direto, sem histórico persistente e sem roteamento de
ferramentas, então módulos que dependem desse núcleo continuam não migrados por definição.

## Indicadores corrigidos nesta auditoria

Três elementos afirmavam coisa que o código não fazia:

| Onde | Antes | Agora |
|---|---|---|
| Gaveta lateral, rodapé | `SYSTEM STATUS` + `ONLINE` em verde fixo, sem medir nada | `VOZ LOCAL` + estado real do detector (`KWS ESCUTANDO`, `KWS PRONTO`, `KWS INDISPONÍVEL`, `KWS COM FALHA`, `KWS NÃO VERIFICADO`), atualizado por listener do controlador |
| Tela de conversa, tarja do comando | `Comando capturado por voz` e `Reconhecimento de fala no dispositivo · pt-BR` para **qualquer** origem, inclusive texto digitado e atalhos | `Comando capturado por voz` só quando a origem é o KWS; texto digitado mostra `Comando digitado` e `Enviado pelo campo de conversa` |
| `HomeScreen` antiga (código morto, não era o `home:` do app) | Segundo catálogo e cartões `ATIVO` / `PENDENTE` / `CATÁLOGO` | Removida junto com `_Heading`, `_Status` e `_Quick`, que só ela usava |

Indicadores que **passaram** na auditoria e continuam como estão:

- `SEM CHAVE` / `CONFIGURADO` na tela de provedores — lido do cofre seguro, não é decoração.
- `PRONTO · EM ESPERA` no painel de voz — o controlador só chega a `idle` quando o plugin respondeu `available: true`.
- Página genérica de módulo com "Integração em auditoria" — 19 dos 21 módulos abrem essa página, e ela diz exatamente isso.
- Rodapé da Central: "Ações de dispositivo e módulos sem integração comprovada não são exibidos como ativos."
- Avisos do painel de voz sobre modelo em inglês e sobre o pacote pt-BR offline.

## Bug de layout encontrado pela verificação

O teste novo da gaveta reprovou na primeira execução por um motivo legítimo: o cabeçalho da
gaveta lateral estourava 68 pixels à direita (`RenderFlex overflowed`), porque a coluna de
título não tinha largura flexível. Corrigido com `Expanded` e `TextOverflow.ellipsis`.
O defeito existia antes desta auditoria e aparecia com faixa amarela em telas estreitas.

## Limites desta matriz

- Ela foi montada por leitura de código e execução de `flutter analyze` e `flutter test`; **nenhum item foi validado em aparelho**.
- "Implementado" aqui significa caminho de código existente, não sucesso em teste com chave real do usuário.
- O app legado (Capacitor/Java) tem muito mais função real; nada disso foi contado a favor do Flutter.
