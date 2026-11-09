# Inventário funcional inicial — J.A.R.V.I.S. Nova 1.46+

Este inventário foi extraído do catálogo operacional `ACOES` de `app.js` na branch `feat/flutter-dart-migration-1.46.0`. Ele lista capacidades registradas, não certifica que todas funcionem em todos os dispositivos. O atributo `disp`, permissões, dependências nativas e testes precisam ser verificados por ação.

## Catálogo operacional — 53 ações

### Informação e comunicação
- `hora`
- `clima`
- `pesquisar`
- `abrir_link`
- `ligar`
- `abrir_conversa_whatsapp`
- `mensagem`
- `sms`
- `email`
- `agenda`
- `agenda_consultar`

### Aplicativos e navegação Android
- `abrir_app`
- `sair_app`
- `retornar_app`
- `fechar_app`
- `acessibilidade_status`
- `acessibilidade_configurar`
- `acessibilidade_ler`
- `acessibilidade_clicar`
- `acessibilidade_digitar`
- `acessibilidade_rolar`
- `acessibilidade_esperar`
- `acessibilidade_voltar`
- `acessibilidade_inicio`
- `painel`

### Mídia e hardware
- `controle_midia`
- `musica_tocando`
- `tocar_musica`
- `spotify`
- `volume`
- `lanterna`
- `brilho`
- `notificacoes`
- `configurar_notificacoes`
- `responder_notificacao`
- `status_dispositivo`

### Arquivos e produtividade
- `copiar_texto`
- `ler_area_transferencia`
- `arquivos_listar`
- `arquivo_ler`
- `arquivo_pesquisar`
- `arquivo_verificar`
- `arquivo_criar`
- `arquivo_editar`
- `arquivo_compactar`
- `lembrete`
- `alarme`
- `cancelar_lembretes`

### Sistema, atualizações e PC
- `versao`
- `verificar_atualizacao`
- `atualizar_app`
- `bloquear_tela`
- `desligar_pc`

## Outros subsistemas encontrados
- Hermes Agent, Core, catálogo de ferramentas e supervisor de planos.
- Provedores Groq, OpenRouter/DeepSeek, Cerebras, Mistral e Gemini.
- IA local/offline.
- KWS sherpa-onnx, reconhecimento de fala, TTS e perfil de voz.
- Memória semântica e Obsidian.
- Visão, contexto visual e OCR.
- CADeSIMU interno, biblioteca elétrica, projetista e integração PC.
- Avatar, identidade/pessoas e personalidade.
- Segurança, cofre de chaves, PIN e integrações biométricas/NFC condicionadas ao dispositivo.
- Tarefas, rotinas, alarmes, atualizações e monitoramento.
- Integrações Android, Windows, ESP32 e Home Assistant (algumas ainda parciais).

## Cobertura automatizada existente
- 111 arquivos `tests/test_*` encontrados na árvore da branch.
- Script `npm run test:all`: 140 comandos (checagens de sintaxe, testes Node.js/Python e verificações de projeto).
- Testes dedicados encontrados para: agentes, Hermes, Core, sistema, planos, voz, áudio, KWS, memória, visão, segurança, CADeSIMU/elétrica, pessoas, arquivos, Windows, UI, release, chaves seguras e versões anteriores.
- Novo teste `tests/test_settings_persistence.js`: verifica a ordem de hidratação do cofre e gravação das chaves.

## Lacunas que impedem declarar “todas as funções funcionando”
1. Os testes existentes são em grande parte testes de contrato/estáticos e unitários; não equivalem a teste físico de todas as ações.
2. A matriz `disp` por ação precisa ser comparada com o suporte real de cada ponte nativa.
3. Cada ação precisa de cenário de sucesso, falha, falta de permissão, timeout e cancelamento quando aplicável.
4. Android 16/HyperOS precisa de teste físico para acessibilidade, notificações, KWS, câmera, áudio e restrições de segundo plano.
5. Windows precisa de teste em máquina Windows para cada ação desktop.
6. Recursos sem implementação verificável devem ser corrigidos, explicitamente limitados ou removidos da interface.

## Regra de aceite
Nenhuma ação pode ser rotulada como funcional apenas por existir no catálogo ou ter um teste estático. O status final deve ser: aprovado em teste automatizado, aprovado em dispositivo, parcial com limitação documentada, ou removido/substituído.
