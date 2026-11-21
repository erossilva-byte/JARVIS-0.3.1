# U.L.T.R.O.N. 2.0 × J.A.R.V.I.S. Nova — o que já existe e o que falta

Comparação feita em 2026-11-21, lendo o código deste repositório (não a
descrição do outro app). A referência é a lista de funções do U.L.T.R.O.N.
Mobile v1.3.2 enviada pelo operador.

Legenda: **Tem** (existe e é testado no código), **Parcial** (existe com
limite), **Falta** (não existe), **Não se aplica** (decisão do projeto).

## Controle do aparelho

| U.L.T.R.O.N. | J.A.R.V.I.S. Nova | Situação |
|---|---|---|
| Lanterna, volume, abrir apps, ajustes do sistema, alarme/timer | `JarvisComandos.kt`, `core/comandos_android.dart` | **Tem** |
| Telemetria (bateria, RAM, modelo, versão, rede) | `core/dispositivo.dart`, `JarvisAparelho.kt` | **Tem** |
| Discador, vibração, pesquisa web | `JarvisAparelho.kt` (ligar), comandos de risco 2 | **Tem** |
| Alarmes e lembretes no Relógio | `JarvisAgenda.kt`, `agenda_service.dart` | **Tem** |
| Controle do Spotify | `JarvisAparelho.kt` + `interpretarSpotify` | **Parcial** (faixa exata só com link) |
| Acessibilidade (ler a tela, tocar e rolar) | `JarvisAcessibilidade.kt`, `acessibilidade_page.dart` | **Novo no ajuste 095** (escopo estreito, desligado por padrão; não digita) |

## Mensagens e notificações

| U.L.T.R.O.N. | J.A.R.V.I.S. Nova | Situação |
|---|---|---|
| Ler notificações de WhatsApp/Telegram/SMS | `JarvisNotificacaoListener.kt` | **Tem** |
| Ler as mensagens em voz alta (pt-BR) | `VozJarvis` + botão na aba CELULAR | **Novo no ajuste 084** |
| Resposta em 2º plano pelo campo da notificação (RemoteInput) | `JarvisNotificacaoListener.responder` | **Novo no ajuste 084** |
| Enviar WhatsApp/SMS com busca na agenda | `enviarMensagem` + `buscarContatos` | **Tem** (SMS sai direto; WhatsApp abre o app) |
| Resumo tático das mensagens por IA | `core/resumo_tatico.dart`, `resumo_ia_service.dart` | **Novo no ajuste 085** |
| Hotword fonético com variações | KWS com aliases (Javis, Jarve, Charles…) | **Parcial** (modelo inglês, sem modelo pt-BR) |

## Voz e interface

| U.L.T.R.O.N. | J.A.R.V.I.S. Nova | Situação |
|---|---|---|
| STT contínuo, parcial ao vivo, VAD, barge-in | `voice_conversation_page.dart`, `JarvisEscutaFundo.kt` | **Tem** |
| TTS pt-BR com timbre grave | `JarvisVoz.kt` (pitch 0,72, 0,88x) | **Tem** |
| Flip-to-Shush (virar o celular para calar) | `JarvisSensores.kt`, `gestos_page.dart` | **Novo no ajuste 087** |
| Núcleo orbital 60 FPS com modos de palco | `command_center.dart` | **Parcial** (sem medição de FPS) |
| Modo Foco Noturno / sussurro | `JarvisSensores` + `JarvisVoz` (volume 45%) | **Novo no ajuste 087** |
| Perfis de timbre escolhíveis (GRAVE/NATURAL/ÁGIL) | `JarvisTimbre.kt`, `timbre_page.dart` | **Novo no ajuste 088** |

## IA

| U.L.T.R.O.N. | J.A.R.V.I.S. Nova | Situação |
|---|---|---|
| Vários provedores com failover | `provider_service.dart`, 12 agentes | **Tem** |
| Provedor sem chave (Zero-Key) | `zero_key_store.dart`, `ProviderService` | **Novo no ajuste 093** (opcional, desligado por padrão; limite de ~1 resposta/45 s por IP) |
| Descobrir modelos (`/models`) | `/models` por provedor, escolha guardada e queda para o padrão no 404 | **Novo no ajuste 094** (a lista não garante acesso; o teste de conexão confirma) |
| IA local no aparelho | Gemma 3 1B opcional (~529 MB) | **Parcial** (não usado por padrão) |
| Visão multimodal com consentimento | `visao_page.dart` | **Tem** |
| Tags `[ACTION:...]` | comandos naturais interpretados no aparelho | **Tem** (equivalente) |

## Memória e automação

| U.L.T.R.O.N. | J.A.R.V.I.S. Nova | Situação |
|---|---|---|
| Cofre Obsidian em disco (diário, notas) | `cofre_saf.dart`, `memoria_sync.dart` | **Tem** |
| Skills procedurais em `Skills/*.md` | `core/habilidades.dart`, `habilidades_service.dart` | **Novo no ajuste 086** |
| Histórico em SQLite com criptografia | histórico por SharedPreferences (sem SQLCipher) | **Parcial** |
| Fichas de pessoas com consentimento | `pessoas.dart` | **Tem** |

## Segurança

| U.L.T.R.O.N. | J.A.R.V.I.S. Nova | Situação |
|---|---|---|
| PIN PBKDF2 + biometria + bloqueio exponencial | `bloqueio_store.dart`, `biometria_service.dart` | **Tem** |
| Duress PIN com app camuflado (modo de visita) | `bloqueio_store.dart`, `modo_visita_page.dart` | **Novo no ajuste 090** |
| Kill switch remoto do PC (HMAC na LAN) | — | **Não se aplica hoje** (não há app de PC na versão Flutter) |
| Atualização OTA com SHA-256 | `atualizacao_service.dart`, `JarvisAtualizacao.kt` | **Novo no ajuste 092** (baixa, confere o `.sha256` e só então abre o instalador) |

## Conclusão

O JARVIS **não está atrás** no controle do aparelho, na voz, na memória local ou
na segurança básica: nesses pontos ele tem equivalentes ou algo mais (simulador
de circuitos, pessoas com LGPD, visão com consentimento). As ausências reais são
de **conveniência de mensagens** e **automação**:

1. ~~responder pela notificação e ler mensagens em voz alta~~ — feito no ajuste 084;
2. ~~resumo tático das mensagens por IA~~ — feito no ajuste 085;
3. ~~skills em Markdown (`Skills/*.md`) reaproveitando o cofre SAF~~ — feito no ajuste 086;
4. ~~flip-to-shush e modo noturno (sensores e brilho)~~ — feito no ajuste 087;
5. ~~perfis de timbre de voz na tela~~ — feito no ajuste 088;
6. ~~Duress PIN~~ — feito no ajuste 090 no formato de modo de visita;
7. ~~atualização OTA com SHA-256~~ — feito no ajuste 092;
8. ~~provedor sem chave~~ — feito no ajuste 093 como opção explícita, desligada
   por padrão e com o limite do serviço público declarado;
9. ~~descoberta de modelos (`/models`)~~ — feito no ajuste 094, com escolha por
   provedor e queda para o modelo padrão quando o escolhido é retirado;
10. ~~acessibilidade (ler a tela, tocar e rolar)~~ — feito no ajuste 095, com
    escopo estreito, consentimento dentro do app e serviço desligado por padrão.

Nada nesta lista foi medido em aparelho físico neste repositório; a coluna
“Tem” significa “existe no código com teste”, não “funciona no seu celular”.
