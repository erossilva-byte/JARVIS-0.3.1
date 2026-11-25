#!/usr/bin/env python3
"""Contrato do bloco 129 — Etapa 5 do PC: segurança.

O roteiro da Etapa 5 pedia: PIN de bloqueio com derivação e espera progressiva,
cofre de chaves protegido pelo sistema (DPAPI no Windows, Keychain no macOS,
secret service no Linux) e modo visita equivalente ao do celular, com o mesmo
prompt e sem dados. O aceite eram testes de política de PIN, derivação,
tentativas e recusa do cofre sem proteção do sistema.

Este contrato prende essas regras, a ligação no aplicativo e a promessa que não
pode voltar atrás: o cofre recusa gravar quando o sistema não oferece proteção,
e o modo visita não mostra nem envia dado de quem é o dono.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


# 1. Política do PIN, derivação e espera progressiva.
bloqueio = ler(RAIZ / "bloqueio.js")
for trecho in [
    "var TAMANHO_MIN = 4",
    "var TAMANHO_MAX = 8",
    "var TENTATIVAS_ANTES_DE_ESPERA = 5",
    "var ITERACOES = 120000",
    "var PREFIXO_PIN = 'pin|'",
    "function avaliarPin(",
    "function esperaDeBloqueios(",
    "function avaliarTentativa(",
    "function derivarPin(",
    "function compararDigest(",
    "function empacotarDigest(",
    "raiz.BloqueioRegras = api",
]:
    exigir(trecho in bloqueio, f"bloqueio.js perdeu: {trecho}")
exigir("pbkdf2Sync" in bloqueio and "'sha256'" in bloqueio,
       "a derivação deixou de ser PBKDF2-HMAC-SHA256")
exigir("ESPERA_BASE_SEG * Math.pow(2, n)" in bloqueio,
       "a espera deixou de crescer a cada bloco de falhas")
exigir("pin|2583" not in bloqueio, "o módulo ficou com vetor de teste embutido")

# 2. Modo visita: mesmo prompt e nenhuma resposta com dado do dono.
visita = ler(RAIZ / "modo_visita.js")
for trecho in [
    "var NOME_PROMPT = 'Modo de visita'",
    "Nunca mencione o dono do computador",
    "não peça senhas",
    "function respostaVisita(",
    "Nenhum configurado",
    "Ele esconde o conteúdo, não o criptografa de novo",
    "Nada é enviado à internet no modo de visita",
    "raiz.ModoVisita = api",
]:
    exigir(trecho in visita, f"modo_visita.js perdeu: {trecho}")
exigir("fetch(" not in visita and "http" not in visita.lower(),
       "o modo de visita ganhou acesso à rede")

# 3. Cofre: cifra pelo sistema e recusa sem proteção.
cofre = ler(RAIZ / "platforms" / "desktop" / "cofre_chaves.js")
for trecho in [
    "safeStorage.isEncryptionAvailable",
    "safeStorage.encryptString",
    "safeStorage.decryptString",
    "jarvis-secrets.json",
    "0o600",
    "não foi salva",
    "texto puro",
    "gravarArquivo",
    "NOMES_VALIDOS",
]:
    exigir(trecho in cofre, f"cofre_chaves.js perdeu: {trecho}")
exigir("writeFileSync(temporario, String(valor)" not in cofre,
       "o cofre passou a gravar o valor sem cifrar")

# 4. Processo principal usa o cofre testável.
main = ler(RAIZ / "platforms" / "desktop" / "main.js")
for trecho in [
    "require(path.join(__dirname, 'cofre_chaves.js'))",
    "guardar_chave_segura",
    "ler_chave_segura",
    "cofre_listar",
    "cofre_apagar",
]:
    exigir(trecho in main, f"main.js perdeu: {trecho}")

# 5. Aplicativo: política no cadastro, espera no desbloqueio e PIN de visita.
app = ler(RAIZ / "app.js")
for trecho in [
    "const BLOQ_REG = window.BloqueioRegras",
    "const VISITA = window.ModoVisita",
    "BLOQ_REG.avaliarPin(pin)",
    "BLOQ_REG.avaliarTentativa({ config: estado, pinCorreto: false",
    "BLOQ_REG.avaliarTentativa({ config: estado, pinCorreto: true",
    "BLOQ_BLOQUEIOS",
    "function abrirModoVisita(",
    "function responderModoVisita(",
    "function definirPinVisita(",
    "pin_coacao_hash",
    "coacaoDefinida()",
    "BLOQ_REG.ITERACOES",
    "BLOQ_REG.PREFIXO_PIN",
]:
    exigir(trecho in app, f"app.js perdeu: {trecho}")
exigir("dentro de tentarDesbloquear" not in app, "marcador de teste vazou")
# O PIN de visita precisa ser conferido antes do principal ser dado como certo.
posicao_visita = app.find("coacaoDefinida() && await pinConfere(pin, store.get('pin_coacao_hash'")
posicao_principal = app.find("if (await pinConfere(pin, esperado)) {")
exigir(posicao_visita > 0 and posicao_principal > posicao_visita,
       "o PIN de visita deixou de ser conferido antes do principal")

# 6. Tela: campos do PIN de visita, tela de visita e esconder o resto.
html = ler(RAIZ / "index.html")
for ident in ["c-coacao-atual", "c-coacao-pin", "c-coacao-definir", "c-coacao-remover",
              "c-coacao-status", "visita", "visita-chat", "visita-form", "visita-texto",
              "visita-ajustes"]:
    exigir(f'id="{ident}"' in html, f"index.html não tem #{ident}")
for script in ["bloqueio.js", "modo_visita.js"]:
    exigir(f'src="{script}"' in html, f"index.html não carrega {script}")
    exigir(html.index(f'src="{script}"') < html.index('src="app.js"'),
           f"{script} precisa carregar antes de app.js")
css = ler(RAIZ / "style.css")
exigir("body.modo-visita > *:not(#visita)" in css,
       "a tela de visita deixou de esconder o resto do aplicativo")

# 7. Testes de regra: política, derivação, tentativas e recusa do cofre.
teste_pin = ler(RAIZ / "tests" / "test_bloqueio.js")
for trecho in ["avaliarPin", "derivarPin", "vetor", "espera", "progressiva", "compararDigest"]:
    exigir(trecho.lower() in teste_pin.lower(), f"test_bloqueio.js perdeu: {trecho}")
teste_cofre = ler(RAIZ / "tests" / "test_cofre_chaves.js")
for trecho in ["não está disponível", "texto puro", "cifrado", "ilegível"]:
    exigir(trecho.lower() in teste_cofre.lower(), f"test_cofre_chaves.js perdeu: {trecho}")
teste_visita = ler(RAIZ / "tests" / "test_modo_visita.js")
for trecho in ["prompt", "ajustes", "limites", "resposta"]:
    exigir(trecho.lower() in teste_visita.lower(), f"test_modo_visita.js perdeu: {trecho}")

# 8. Versão, changelog, relatório, roteiro e suíte.
pubspec = ler(RAIZ / "flutter_app" / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-25_129-seguranca-pc.md"
exigir("version: 1.106.0+110600" in pubspec, "pubspec.yaml não está em 1.106.0+110600")
exigir("## 1.106.0" in changelog, "CHANGELOG.md sem o bloco 1.106.0")
exigir("Estado:** entregue na 1.106.0" in roteiro,
       "o roteiro não registrou a Etapa 5 como entregue")
exigir(relatorio.is_file(), "falta o relatório da Etapa 5")
try:
    dados = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    scripts = dados["scripts"]["test:all"]
    for trecho in [
        "node tests/test_bloqueio.js",
        "node tests/test_modo_visita.js",
        "node tests/test_cofre_chaves.js",
        "python3 tests/test_bloco_129.py",
    ]:
        exigir(trecho in scripts, f"test:all não roda: {trecho}")
    arquivos = dados["build"]["files"]
    for nome in ["bloqueio.js", "modo_visita.js", "platforms/desktop/cofre_chaves.js"]:
        exigir(nome in arquivos, f"o pacote Windows não inclui {nome}")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 129:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 129: PIN com espera progressiva, cofre do sistema e modo visita — contrato OK")
