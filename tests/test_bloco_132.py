#!/usr/bin/env python3
"""Contrato do bloco 132 — compatibilidade Android ↔ PC (protocolo jarvis/2).

A Etapa 3 deixou o celular e o PC pareados, mas com um canal só de leitura e sem
nenhuma forma de o PC saber o que aquela versão do celular aceita. Este bloco
começa a compatibilidade de verdade: negociação de protocolo e recursos, e um
canal de comando fechado (`abrir_tela`) do PC para o celular.

O contrato prende o que os dois lados prometem — a mesma lista de ações nas duas
linguagens, a mesma versão de protocolo, as recusas com código certo, a ordem
"autentica antes de olhar o corpo", a tela desabilitando o botão quando o
celular é antigo, e o relatório dizendo com todas as letras que nada disto rodou
em aparelho de verdade.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
falhas: list[str] = []


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


# 1. Núcleo do celular: protocolo, lista fechada e validação sem Flutter.
nucleo = ler(RAIZ / "flutter_app" / "lib" / "core" / "comando_remoto.dart")
for trecho in [
    "const protocoloAtual = 'jarvis/2'",
    "const protocoloLegado = 'jarvis/1'",
    "const recursoComando = 'comando'",
    "const janelaDoComandoSegundos = 60",
    "const validadeDoNonceSegundos = 300",
    "const comandosPorMinuto = 20",
    "const acoesRemotas = <String, List<String>>{",
    "({String protocolo, List<String> recursos}) lerNegociacao(",
    "bool aceitaComando(Object? dados)",
    "ValidacaoDeComando validarComando(",
    "class RegistroDeComandos",
]:
    exigir(trecho in nucleo, f"comando_remoto.dart perdeu: {trecho}")
exigir("package:flutter" not in nucleo, "o núcleo do comando não pode depender de Flutter")

# 2. A lista de ações do celular é a mesma do PC (comparação de verdade).
lista_dart = re.search(r"const acoesRemotas = <String, List<String>>\{(.*?)\n\};", nucleo, re.S)
exigir(lista_dart is not None, "não achei a lista de ações no Dart")
lista_js = re.search(r"const ACOES_REMOTAS = \{(.*?)\n\};", ler(RAIZ / "platforms" / "desktop" / "pareamento.js"), re.S)
exigir(lista_js is not None, "não achei a lista de ações no JS")


def telas(texto: str) -> dict[str, list[str]]:
    achado: dict[str, list[str]] = {}
    for acao, corpo in re.findall(r"['\"]?([a-z_]+)['\"]?\s*:\s*\[([^\]]*)\]", texto):
        achado[acao] = [item.strip().strip("'\"") for item in corpo.split(",") if item.strip()]
    return achado


if lista_dart and lista_js:
    exigir(telas(lista_dart.group(1)) == telas(lista_js.group(1)),
           "a lista de ações do Dart e a do JS divergiram")
exigir("PROTOCOLO = 'jarvis/2'" in ler(RAIZ / "platforms" / "desktop" / "pareamento.js"),
       "o PC não declara o protocolo jarvis/2")

# 3. Serviço do celular: negociação nas duas respostas e rota de comando.
servico = ler(RAIZ / "flutter_app" / "lib" / "services" / "pareamento_service.dart")
for trecho in [
    "final Future<Object?> Function(EnvelopeDeComando comando)? executarComando;",
    "negociacao(comando: executarComando != null)",
    "caminho == '/jarvis/comando'",
    "await _comando(pedido)",
    "if (!_autorizado(pedido)) {",
    "validarComando(",
    "validacao.codigoHttp",
    "_comandos.podeExecutar",
    "429",
    "timeout(const Duration(seconds: 10))",
]:
    exigir(trecho in servico, f"pareamento_service.dart perdeu: {trecho}")
ordem = servico.find("Future<void> _comando(HttpRequest pedido) async {")
if ordem >= 0:
    corpo = servico[ordem:ordem + 1800]
    exigir(corpo.find("_autorizado") < corpo.find("validarComando("),
           "o comando precisa conferir o token antes de ler o corpo")
    exigir(corpo.find("_autorizado") < corpo.find("_corpo(pedido)"),
           "o celular lê o corpo antes de autenticar")

# 4. Tela do celular: comando injetado e só abre tela da lista.
pagina = ler(RAIZ / "flutter_app" / "lib" / "services" / "pareamento_page.dart")
for trecho in ["executarComando: _executarComando", "TelaJarvis.porChave(", "AbrirTela.abrir("]:
    exigir(trecho in pagina, f"pareamento_page.dart perdeu: {trecho}")

# 5. PC: cliente, capacidade e IPC.
cliente = ler(RAIZ / "platforms" / "desktop" / "pareamento.js")
for trecho in [
    "function lerNegociacao(",
    "function aceitaComando(",
    "function conferirPedidoDeComando(",
    "async function enviarComando(",
    "'sem-recurso'",
    "crypto.randomBytes(16).toString('hex')",
    "emitidoEm: new Date().toISOString()",
    "if (!aceitaComando(registro)) {",
    "podeComandar: aceitaComando(registro)",
]:
    exigir(trecho in cliente, f"pareamento.js do PC perdeu: {trecho}")
inicio_envio = cliente.find("async function enviarComando(")
exigir(inicio_envio >= 0, "falta enviarComando no cliente do PC")
if inicio_envio >= 0:
    corpo_envio = cliente[inicio_envio:inicio_envio + 1500]
    exigir(corpo_envio.find("if (!aceitaComando(registro))") < corpo_envio.find("/jarvis/comando"),
           "o PC precisa recusar canal de leitura antes de tocar a rede")

main_js = ler(RAIZ / "platforms" / "desktop" / "main.js")
exigir("comandar_celular:" in main_js, "o processo principal não expõe comandar_celular")

espelho = ler(RAIZ / "pareamento.js")
exigir("function podeComandar(" in espelho, "o espelho da tela não sabe dizer se pode comandar")

html = ler(RAIZ / "index.html")
for trecho in ['id="sc-comandos"', 'data-comando-tela="memoria"', 'id="sc-comando-status"']:
    exigir(trecho in html, f"index.html perdeu: {trecho}")

app = ler(RAIZ / "app.js")
for trecho in ["atualizarComandosCelular(", "async function comandarCelular(", "'comandar_celular'", "P.podeComandar("]:
    exigir(trecho in app, f"app.js perdeu: {trecho}")
exigir("b.disabled = !pode" in app, "o botão de comando precisa desabilitar em canal de leitura")

# 6. Testes entrando na esteira.
pacote = json.loads(ler(RAIZ / "package.json") or "{}")
suite = (pacote.get("scripts") or {}).get("test:all", "")
for comando in ["node tests/test_comando_remoto.js", "python3 tests/test_bloco_132.py"]:
    exigir(comando in suite, f"test:all não roda: {comando}")
exigir((RAIZ / "tests" / "test_comando_remoto.js").is_file(), "falta o teste do PC")
exigir((RAIZ / "flutter_app" / "tool" / "comando_remoto_test.dart").is_file(),
       "falta o teste Dart do protocolo")

# 7. Documentação honesta.
doc = ler(RAIZ / "docs" / "COMPATIBILIDADE-ANDROID-PC.md")
for trecho in [
    "## O que já existe",
    "## Protocolo jarvis/2",
    "/jarvis/comando",
    "jarvis/1",
    "abrir_tela",
    "## Limites declarados",
    "executado em aparelho",
]:
    exigir(trecho in doc, f"COMPATIBILIDADE-ANDROID-PC.md perdeu: {trecho}")

relatorio = list((RAIZ / "docs" / "relatorios").glob("*132*.md"))
exigir(bool(relatorio), "falta o relatório do bloco 132")
if relatorio:
    texto = relatorio[0].read_text(encoding="utf-8")
    exigir("executado em aparelho" in texto,
           "o relatório precisa declarar que nada rodou em aparelho")

changelog = ler(RAIZ / "CHANGELOG.md")
exigir("compatibilidade Android ↔ PC" in changelog or "protocolo jarvis/2" in changelog,
       "o CHANGELOG não registra a compatibilidade do bloco 132")

if falhas:
    print(f"Bloco 132: {len(falhas)} falha(s).")
    for falha in falhas:
        print("  - " + falha)
    sys.exit(1)

print("Bloco 132: compatibilidade Android ↔ PC (negociação e comando) — contrato OK")
