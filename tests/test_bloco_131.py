#!/usr/bin/env python3
"""Contrato do bloco 131 — Etapa 7 do PC: instalador e atualização assinada.

A Etapa 7 pede instalador assinado, atualização com verificação de assinatura,
versão e changelog no app, e roteiro de teste em PC físico. Nenhum instalador
foi compilado aqui (não há Windows nesta máquina) e nenhum certificado de código
foi comprado: este contrato prende o que **pode** ser provado — as regras de
aceitar e recusar um pacote, as ferramentas de assinatura, o caminho no processo
principal, o painel de versão/notas e o roteiro de campo.

Ele também impede mentira por descuido: exige que o relatório continue dizendo
que o instalador não foi gerado e que a etapa está implementada, não aprovada.
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


# 1. Regras da atualização.
modulo = ler(RAIZ / "atualizacao_pc.js")
for trecho in [
    "var APP = 'jarvis-nova-pc'",
    "function canonico(",
    "function compararVersoes(",
    "function validarManifesto(",
    "function assinar(",
    "function verificarAssinatura(",
    "function verificarAtualizacao(",
    "function planoDeAtualizacao(",
    "function notasDaVersao(",
    "raiz.AtualizacaoPc = api",
]:
    exigir(trecho in modulo, f"atualizacao_pc.js perdeu: {trecho}")
for motivo in ["sem-chave", "sem-assinatura", "assinatura-invalida", "mesma-versao",
               "mais-antiga", "versao-minima", "sem-arquivo"]:
    exigir(motivo in modulo, f"atualizacao_pc.js perdeu o motivo {motivo}")
exigir("c.sign(null" in modulo or "crypto.sign" in modulo or "c.sign(" in modulo,
       "a assinatura deixou de ser Ed25519 sobre o manifesto")
exigir("chavePrivadaPem" in modulo and "chavePublicaPem" in modulo,
       "o módulo deixou de separar chave privada de pública")

# 2. Ferramentas de release.
chave_tool = ler(RAIZ / "tools" / "chave_atualizacao.js")
for trecho in ["generateKeyPairSync('ed25519')", "0o600", "não sobrescrevo"]:
    exigir(trecho in chave_tool, f"tools/chave_atualizacao.js perdeu: {trecho}")
assinar_tool = ler(RAIZ / "tools" / "assinar_atualizacao.js")
for trecho in ["--versao", "sha256", "A.assinar(", "atualizacao.json.sig",
               "20000000", "verificarAssinatura"]:
    exigir(trecho in assinar_tool, f"tools/assinar_atualizacao.js perdeu: {trecho}")

# 3. Chave pública embutida, privada fora do repositório.
publica = ler(RAIZ / "platforms" / "desktop" / "atualizacao-publica.pem")
exigir("BEGIN PUBLIC KEY" in publica, "a chave pública de atualização não está no pacote")
gitignore = ler(RAIZ / ".gitignore")
for trecho in [".chaves-dev/", "!platforms/desktop/atualizacao-publica.pem"]:
    exigir(trecho in gitignore, f".gitignore perdeu: {trecho}")
exigir(not (RAIZ / "platforms" / "desktop" / "atualizacao-privada.pem").exists(),
       "a chave privada de atualização foi parar no pacote")

# 4. Ligação no processo principal e no app.
main = ler(RAIZ / "platforms" / "desktop" / "main.js")
for trecho in [
    "require(path.join(RAIZ, 'atualizacao_pc.js'))",
    "atualizacao_info:",
    "atualizacao_verificar:",
    "novidades_app:",
    "ATUALIZACAO.verificarAtualizacao({",
    "ATUALIZACAO.planoDeAtualizacao(",
    "createHash('sha256')",
]:
    exigir(trecho in main, f"main.js perdeu: {trecho}")
app = ler(RAIZ / "app.js")
for trecho in [
    "async function renderSobre(",
    "async function conferirAtualizacaoBaixada(",
    "nativo('atualizacao_info'",
    "nativo('atualizacao_verificar'",
    "nativo('novidades_app'",
    "A instalação e a atualização do computador são feitas no app do PC",
]:
    exigir(trecho in app, f"app.js perdeu: {trecho}")
html = ler(RAIZ / "index.html")
for ident in ["sobre-versao", "sobre-notas", "btn-conferir-atualizacao",
              "sobre-atualizacao-status"]:
    exigir(f'id="{ident}"' in html, f"index.html não tem #{ident}")

# 5. Teste de regra com cripto de verdade.
teste = ler(RAIZ / "tests" / "test_atualizacao_pc.js")
for trecho in ["generateKeyPairSync('ed25519')", "A.assinar(", "assinatura-invalida",
               "mais-antiga", "sha256", "assinar_atualizacao.js"]:
    exigir(trecho in teste, f"test_atualizacao_pc.js perdeu: {trecho}")

# 6. Roteiro de campo e guia de assinatura.
guia = ler(RAIZ / "docs" / "ASSINATURA-PC.md")
for trecho in ["Authenticode", "Ed25519", "Trusted Signing", "atualizacao-publica.pem",
               "não existe", "assinatura-invalida"]:
    exigir(trecho in guia, f"docs/ASSINATURA-PC.md perdeu: {trecho}")
roteiro_campo = ler(RAIZ / "docs" / "TESTE-PC-FISICO.md")
for etapa in ["máquina limpa", "Pareamento", "Ouvir e falar", "Reiniciar",
              "Atualização e reversão", "Desinstalar sem lixo", "Medições"]:
    exigir(etapa in roteiro_campo, f"docs/TESTE-PC-FISICO.md sem a etapa {etapa}")
exigir("implementada, não aprovada" in roteiro_campo,
       "o roteiro de campo deixou de dizer que a etapa não foi aprovada")

# 7. A esteira de release assina o manifesto e publica junto do instalador.
workflow = ler(RAIZ / ".github" / "workflows" / "release-pc.yml")
for trecho in [
    "CHAVE_ATUALIZACAO: ${{ secrets.CHAVE_ATUALIZACAO_PRIVADA }}",
    "if: env.CHAVE_ATUALIZACAO != ''",
    "printf '%s\\n' \"$CHAVE_ATUALIZACAO\" > \"$ARQ\"",
    "chmod 600 \"$ARQ\"",
    "node tools/assinar_atualizacao.js --pasta dist",
    "node tools/conferir_atualizacao.js dist",
    'rm -f "$RUNNER_TEMP/atualizacao-privada.pem"',
    "dist/atualizacao.json",
    "dist/atualizacao.json.sig",
]:
    exigir(trecho in workflow, f"release-pc.yml perdeu: {trecho}")
exigir(workflow.count("dist/atualizacao.json.sig") >= 2,
       "o .sig precisa entrar nos artefatos do build e no release")
exigir("Falta o segredo CHAVE_ATUALIZACAO_PRIVADA" in workflow,
       "numa tag sem segredo o release precisa parar com mensagem clara")
exigir(workflow.find("Assinar o manifesto") < workflow.find("Anexar ao release"),
       "a assinatura precisa acontecer antes de anexar ao release")
exigir(workflow.find("Conferir a assinatura com a chave pública") < workflow.find("Anexar ao release"),
       "a conferência da assinatura precisa acontecer antes de publicar")
exigir("if: always()" in workflow, "a limpeza da chave precisa rodar mesmo em falha")
exigir(not re.search(r"begin private key", workflow, re.IGNORECASE),
       "nenhuma chave privada pode estar escrita no workflow")
ajuda = ler(RAIZ / "tools" / "conferir_atualizacao.js")
for trecho in ["A.verificarAtualizacao(", "atualizacao-publica.pem", "process.exit(1)"]:
    exigir(trecho in ajuda, f"tools/conferir_atualizacao.js perdeu: {trecho}")

# 8. Versão, changelog, relatório, roteiro e suíte.
pubspec = ler(RAIZ / "flutter_app" / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-25_131-instalador-e-atualizacao-pc.md"
exigir("version: 1.110.0+111000" in pubspec, "pubspec.yaml não está em 1.110.0+111000")
exigir("## 1.110.0" in changelog, "CHANGELOG.md sem o bloco 1.110.0")
exigir("Estado:** implementada e **não aprovada**" in roteiro,
       "o roteiro não registrou a Etapa 7 como implementada e não aprovada")
texto_relatorio = ler(relatorio)
for trecho in ["Nenhum instalador foi gerado", "Nenhum certificado de código foi comprado",
               "não aprovada", "861d4030"]:
    exigir(trecho in texto_relatorio, f"o relatório perdeu: {trecho}")
try:
    dados = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    arquivos = dados["build"]["files"]
    for nome in ["atualizacao_pc.js", "platforms/desktop/atualizacao-publica.pem", "CHANGELOG.md"]:
        exigir(nome in arquivos, f"o pacote Windows não inclui {nome}")
    scripts = dados["scripts"]["test:all"]
    for trecho in ["node tests/test_atualizacao_pc.js", "python3 tests/test_bloco_131.py"]:
        exigir(trecho in scripts, f"test:all não roda: {trecho}")
    exigir("atualizacao_pc.js" in dados["scripts"]["test:syntax"],
           "test:syntax não confere atualizacao_pc.js")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 131:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 131: atualização assinada, painel de versão e roteiro de campo — contrato OK")
