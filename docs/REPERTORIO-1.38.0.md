# Auditoria do repertório — 1.38.0

Data: 2026-11-01. Inventário baseado no código deste repositório, não em promessas de versões anteriores.

## Números medidos

- **53 ações** no catálogo `ACOES` de `app.js` (hora, clima, apps, SMS, chamadas, mídia, volume, brilho, lanterna, painéis, arquivos, agenda, lembretes, acessibilidade, etc.).
- **12 agentes** no Core: `principal`, `pesquisa`, `programacao`, `arquivos`, `automacao`, `voz`, `memoria`, `tecnico`, `planejamento`, `diagnostico`, `desenvolvimento`, `atualizacao`.
- **6 executores** registrados no app: `diagnostico`, `memoria`, `voz`, `automacao`, `atualizacao`, `planejamento`.
- **10 ferramentas** no `SISTEMA` em tempo de execução: 8 embutidas (`calc`, `converter`, `senha`, `texto_estatisticas`, `json_formatar`, `hash`, `data_calcular`, `sistema_status`) + `audio_diagnostico` + `plano_etapa`.
- **21 classes Java nativas** exigidas pelo build Android, incluindo serviço de escuta, ativação, voz, mídia, acessibilidade, atualização, notificações, alarmes, boot e watchdog.
- **8 modos/áreas principais** de interface descritos em `interface.js` (central, áreas, IA, Core, Voz, Sistema, Memória, Arquivos, Pessoas, PC, Dev), com os painéis antigos preservados.

## Classificação

### Implementado e testado sem aparelho

- Núcleo Hermes e comandos locais; roteador de provedores com fallback e tratamento de erro.
- `SISTEMA`: catálogo, permissões, confirmação, PIN, traces sem valores, tarefas persistentes, checkpoint, pausa e retomada.
- Planos validados convertidos em tarefas persistentes; etapa interna sem confirmação duplicada.
- Agentes e recibos de execução; Core com projetos, contexto, saúde, pré-checagem e recuperação limitada.
- Memória local, aprendizado explícito reversível, pessoas/perfis, visão e CAD no que é coberto pelos testes de Node.
- Núcleo HUD/plasma/órbita e novo avatar procedural com fallback 2D.
- Calculadora sem `eval`, conversões, senha Web Crypto, JSON, hash, datas e estatísticas de texto.
- Pacote desktop e camada de arquivos/CAD do PC (testes de Node; não abertos em Windows).

### Implementado, dependente de Android real

- Microfone, diagnóstico de áudio, escuta em primeiro/segundo plano, wake word e TTS.
- Acessibilidade opt-in: leitura de árvore, clique por texto, digitação, rolagem, esperar, voltar e início.
- Notificações, alarmes, mídia, volume, brilho, lanterna, abertura de apps, SMS e chamadas.
- Atualização in-app, FileProvider, assinatura, instalação e sobreposição de instalação.
- Avatar em tela real (WebGL/Canvas 2D), desempenho e consumo.

### Parcial ou condicionado

- IA em nuvem: exige chave e cota; sem chave o app não inventa resposta generativa.
- IA local: exige modelo `.task` importado; o APK não embarca modelo.
- Voz neural offline: exige download de 67–132 MB; não está no APK.
- PC/Windows: o código e os testes existem; o executável não foi aberto em Windows nesta máquina.
- Integrações físicas: ESP32, Home Assistant, TV e pareamento PC→TV não foram implementados nem validados.
- MCP remoto, RAG vetorial e sandbox de processo separado: não implementados.

### Não implementado

- Modelo facial realista, rig de músculos, visemas por fonema e download automático de avatar.
- OCR/visão local ampla, execução de código em sandbox, instalação de habilidades remotas.
- Garantia de funcionamento em aparelhos diferentes do Poco X7, em ROMs modificadas ou com restrições de fabricante.
- Publicação automática de release sem credencial válida.

## Preservação

A 1.38.0 não removeu identidade, voz, memória, personalidade, agentes, núcleo 3D, HUD, plasma, órbita, planos, aprendizado, PC, acessibilidade, confirmações, PIN nem tarefas persistentes. O avatar é um estilo adicional; HUD, plasma e órbita continuam selecionáveis.

## Limites da auditoria

Este documento é um inventário de engenharia. Ele não é um teste de campo. Instalação, abertura, microfone, wake word, notificações, acessibilidade, segundo plano e toque real no aparelho continuam **bloqueados** até existir um dispositivo conectado ou alguém executar o APK e devolver o resultado.
