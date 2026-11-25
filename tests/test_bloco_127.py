#!/usr/bin/env python3
"""Contrato do bloco 127 — Etapa 3 do PC: pareamento por código de 6 dígitos.

A Etapa 3 tinha três entregáveis no roteiro: descoberta na rede local (mDNS ou
IP manual), canal autenticado só de leitura e registro no PC com opção de
esquecer. A escolha foi IP manual, sem mDNS — este contrato prende a escolha,
o protocolo (desafio, prova HMAC, token, revogação) e a promessa de que nada
sai da rede local.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


# 1. Regras puras no celular.
core = ler(LIB / "core" / "pareamento.dart")
for trecho in [
    "const portaPareamento = 47600",
    "const validadeOfertaSegundos = 120",
    "const tentativasPareamento = 5",
    "String gerarCodigoPareamento(",
    "String provaDePareamento(",
    "bool iguaisEmTempoConstante(",
    "class OfertaPareamento",
    "class RegistroPareamento",
    "bool enderecoDaRedeLocal(",
    "({String host, int porta})? enderecoDoCelular(",
]:
    exigir(trecho in core, f"core/pareamento.dart perdeu: {trecho}")

# 2. Servidor do celular: só as quatro rotas, só leitura, só LAN.
servico = ler(LIB / "services" / "pareamento_service.dart")
for trecho in [
    "'/jarvis/info'",
    "'/jarvis/parear'",
    "'/jarvis/status'",
    "'/jarvis/esquecer'",
    "HttpServer.bind(InternetAddress.anyIPv4",
    "HttpHeaders.authorizationHeader",
    "iguaisEmTempoConstante",
    "enderecoDaRedeLocal(remoto)",
]:
    exigir(trecho in servico, f"pareamento_service.dart perdeu: {trecho}")
exigir("/jarvis/comando" not in servico and "'/comando'" not in servico,
       "o canal de leitura ganhou rota de comando")
exigir("package:http" not in servico and "https://" not in servico,
       "o serviço do celular passou a falar com a internet")
exigir("'/jarvis/status'" in servico and "pedido.method == 'GET'" in servico,
       "o status deixou de ser leitura (GET)")

# 3. Tela do celular e navegação.
pagina = ler(LIB / "services" / "pareamento_page.dart")
for trecho in [
    "formatarCodigoPareamento",
    "pareamento-codigo",
    "pareamento-abrir",
    "pareamento-esquecer",
    "PareamentoService.enderecosLocais",
]:
    exigir(trecho in pagina, f"pareamento_page.dart perdeu: {trecho}")
home = ler(LIB / "home_screen.dart")
exigir("'Pareamento Windows'" in home and "PareamentoPage()" in home,
       "o módulo Pareamento Windows não abre a tela de pareamento")
estado = ler(LIB / "core" / "estado_modulos.dart")
exigir("TelaModulo.pareamento" in estado,
       "o estado do módulo não aponta para a tela de pareamento")
exigir("nome: 'Pareamento Windows',\n    estado: EstadoModulo.parcial" in estado,
       "Pareamento Windows deveria estar como parcial")

# 4. Lado do PC: regra no renderer, cliente no processo principal.
regra_pc = ler(RAIZ / "pareamento.js")
for trecho in [
    "validarDigitacao",
    "estadoPareado",
    "resumoPareado",
    "enderecoDaRedeLocal",
    "window.Pareamento",
]:
    exigir(trecho in regra_pc, f"pareamento.js perdeu: {trecho}")

cliente = ler(RAIZ / "platforms" / "desktop" / "pareamento.js")
for trecho in [
    "createHmac('sha256'",
    "'/jarvis/info'",
    "'/jarvis/parear'",
    "'/jarvis/status'",
    "'/jarvis/esquecer'",
    "Authorization: 'Bearer '",
    "criarPareamento",
    "enderecoDoCelular",
    "fs.renameSync",
]:
    exigir(trecho in cliente, f"cliente do PC perdeu: {trecho}")
exigir("/comando" not in cliente,
       "o cliente do PC ganhou rota de comando antes da etapa certa")
exigir("https://" not in cliente,
       "o cliente do PC passou a falar com a internet")

main = ler(RAIZ / "platforms" / "desktop" / "main.js")
for acao in ["pareamento_celular", "parear_celular", "status_celular", "esquecer_celular"]:
    exigir(f"{acao}:" in main, f"main.js não registra a ação {acao}")

# 5. Painel: formulário, ordem dos scripts e ligação no app.js.
html = ler(RAIZ / "index.html")
for ident in ["sc-ip", "sc-codigo", "sc-parear", "sc-esquecer", "sc-pareado", "sc-linhas"]:
    exigir(f'id="{ident}"' in html, f"o painel não tem #{ident}")
exigir('src="pareamento.js"' in html and
       html.index('src="pareamento.js"') < html.index('src="app.js"'),
       "pareamento.js precisa carregar antes de app.js")
app = ler(RAIZ / "app.js")
for trecho in [
    "function iniciarPareamentoPainel(",
    "async function parearCelular(",
    "async function esquecerCelular(",
    "nativo('parear_celular'",
    "nativo('status_celular'",
    "nativo('esquecer_celular'",
    "renderStatusPlataforma('sc-linhas'",
]:
    exigir(trecho in app, f"app.js perdeu: {trecho}")

# 6. Os dois testes de integração local e a recusa por código errado.
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
exigir("tool/pareamento_test.dart" in nucleo,
       "o teste puro do pareamento não está no executor")
exigir("tool/pareamento_rede_test.dart" in nucleo,
       "o teste de rede do pareamento não está no executor")
rede = ler(APP / "tool" / "pareamento_rede_test.dart")
exigir("código errado deveria ser 403" in rede,
       "o teste de rede perdeu a recusa por código errado")
exigir("PcSimulado" in rede, "o teste de rede perdeu o PC simulado")
pc = ler(RAIZ / "tests" / "test_pareamento_pc.js")
exigir("celularFalso" in pc and "/jarvis/parear" in pc,
       "o teste do PC perdeu o celular simulado")
exigir("fora da rede local" in pc,
       "o teste do PC perdeu a recusa fora da LAN")
painel = ler(RAIZ / "tests" / "test_pareamento_painel.js")
exigir("sc-parear" in painel, "o teste do painel perdeu o formulário")

# 7. Versão, docs e execução.
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_127-pareamento-pc-celular.md")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
exigir("version: 1.108.0+110800" in pubspec,
       "pubspec.yaml não está em 1.108.0+110800")
exigir("## 1.104.0" in changelog and "1.104.0" in roteiro,
       "CHANGELOG.md ou roteiro sem o bloco 1.104.0")
exigir(relatorio.is_file(), "falta o relatório do pareamento")
exigir("Decisão de base única" in roteiro,
       "o roteiro não registrou a decisão de base única no fim da Etapa 3")
try:
    dados = json.loads(pacote)
    scripts = dados["scripts"]["test:all"]
    for trecho in [
        "node tests/test_pareamento_pc.js",
        "node tests/test_pareamento_painel.js",
        "python3 tests/test_bloco_127.py",
    ]:
        exigir(trecho in scripts, f"test:all não roda: {trecho}")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 127:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 127: pareamento PC ↔ celular por código de 6 dígitos — contrato OK")
