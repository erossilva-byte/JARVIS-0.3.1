# Estado da Fase 2 — o que está provado, o que está só auditado e o que falta

**Data:** 2026-11-11 · **Branch:** `work/1.48.0-fase2-consolidacao`

Este documento existe para uma pergunta só: diante de cada afirmação do projeto, **o que sustenta
ela?** A regra da sequência é que nenhuma tela, catálogo ou indicador visual vale como prova, e que
ausência de evidência é pendência — nunca aprovação.

Três níveis, sem meio-termo:

| Nível | Significado |
|---|---|
| **Provado** | Existe teste automatizado que executa o caminho real e reprova se ele quebrar |
| **Só auditado** | O código existe e foi lido, mas o caminho nunca rodou contra o mundo real |
| **Pendente de teste físico** | Depende de aparelho, sistema ou programa que este ambiente não tem |

## 1. Provado por teste

| Área | O que o teste executa de verdade | Onde |
|---|---|---|
| Motor de arquivos | Gera PDF/DOCX/XLSX/CSV/ZIP e **relê os bytes** com leitor de ZIP próprio, CRC recalculado e parser de CSV próprio | `tests/test_arquivos_dev.js` |
| Sandbox do PC | Pasta temporária real: caminho fora da raiz recusado, nada criado fora, sem `.tmp` sobrando | sondagem registrada em `docs/relatorios/2026-11-11_009_arquivos-e-sandbox.md` |
| Cofre Obsidian | Escrita e leitura **em disco real**; nota com `---` no corpo deixou de perder o texto seguinte | `tests/test_memoria_md.js` + relatório 008 |
| Contexto visual | Atributos da análise chegam à comparação; sem evidência legível, não são mantidos | `tests/test_visao_contexto.js` (16 grupos) |
| Pessoas | Perfis locais: acento/caixa não fundem, nome ambíguo não é resolvido sozinho, apelido exato, exportar/importar | `tests/test_pessoas.js` |
| Projetista elétrico | Projeto, validação, netlist, relatório, ladder e ponte CADeSIMU (incluindo ID repetido agora visível) | `tests/test_projetista.js`, `tests/test_cadesimu_troca.js` |
| Provedores de IA | Ordem de preferência (Groq → OpenRouter → …), ausência de credencial, conversa usando o primeiro configurado | `tests/test_openrouter.js` e testes do Flutter |
| Contrato de conversa | Histórico em ordem cronológica, detecção de repetição pela fala do turno | `tests/test_hermes.js` |
| Credenciais | Cofre no Android (AES-256-GCM) e no desktop (`safeStorage`, `0o600`, troca atômica), falha fechada | `tests/test_seguranca.js`, `tests/test_secure_keys.py` |
| Suíte inteira | `npm run test:all` | exit 0, 2353 verificações, 0 falhas |

## 2. Só auditado — código existe, mundo real não foi tocado

| Item | O que falta |
|---|---|
| Catálogo Flutter | 1 módulo implementado, 3 parciais, 16 não migrados, 1 fora de escopo (`docs/MATRIZ-CAPACIDADES-FLUTTER.md`) |
| Visão e OCR | Tratamento dos dados está provado; **nenhuma imagem real passou por um modelo de visão** |
| Ponte CADeSIMU | Consistência interna provada; **o programa CADeSIMU nunca foi aberto** e o `.cad` nativo não é gerado nem lido |
| Ponte Electron (Windows) | Código existe e compila no CI; nunca rodou em Windows |
| SAF do Android | Mesma situação: existe, nunca exercitado |
| IA local | Plugin legado existe; Gemma nunca rodou no aparelho, e não há runtime no Windows |
| Memória semântica | Busca lexical/hash funciona; não há embedding neural multilíngue nem sincronização Flutter ↔ Obsidian |
| Avatar | É holograma em `CustomPaint`, não malha 3D — declarado como parcial |

## 3. Pendente de teste físico (Gate B)

- Instalar o APK no Poco X7 (Android 16/HyperOS) e exercitar: permissão de microfone, tela
  bloqueada, Doze, app removido dos recentes, rearme e reinício.
- Medir KWS com "Jarvis" em pt-BR, em silêncio e com ruído: falsos positivos, falsos negativos e
  latência. O modelo disponível é **inglês** — não há aprovação automática por ser multilíngue.
- Validar transcrição on-device pt-BR, inclusive o caso de o pacote offline não estar instalado.
- Confirmar que nenhum áudio sai para a nuvem sem autorização explícita.
- Matriz de funções equivalentes Android ↔ Windows, com o que continuar parcial registrado.
- Release Android e Windows do mesmo commit, com checksums — só depois dos itens acima.

## 4. Bloqueios conhecidos

- **Sem Android SDK nem Windows neste ambiente**: nada de aparelho pode ser verificado aqui.
- **Sem credenciais reais de provedor**: conversa nunca foi exercitada ponta a ponta com chave do
  usuário.
- **CADeSIMU é proprietário**: sem arquivo de amostra, qualquer exportador que prometesse
  compatibilidade seria mentira.
- Picovoice segue proibido; ESP32 e Home Assistant seguem fora de escopo.

## 5. Como atualizar este documento

Ao fechar um ajuste, mover a linha da área entre as seções — e só com evidência anexa (teste que
roda, relatório em `docs/relatorios/`, commit e CI verdes). Se a evidência não existir, o item
continua onde está.
