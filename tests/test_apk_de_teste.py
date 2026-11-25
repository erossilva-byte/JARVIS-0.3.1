#!/usr/bin/env python3
"""Contrato do APK de teste e dos consertos das esteiras de release.

O release da tag não produzia APK: a esteira antiga (`release-apk.yml`) compila
o projeto Capacitor, para nos testes estáticos e nunca chega ao Gradle do
Flutter, e a esteira oficial (`flutter-release-apk.yml`) exige os quatro
segredos da chave de release. Este contrato prende:

- a esteira de APK de teste, que compila o Flutter e assina em debug;
- o aviso honesto de que a assinatura de debug não recebe atualização por cima;
- os fontes Kotlin que faltavam no checkout do CI (android/ é ignorado pelo Git);
- o `setup-python` da esteira antiga sem cache de pip, que falhava na hora.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
falhas: list[str] = []


def ler(caminho: str) -> str:
    arquivo = RAIZ / caminho
    if not arquivo.exists():
        falhas.append(f"arquivo ausente: {caminho}")
        return ""
    return arquivo.read_text(encoding="utf-8")


esteira = ler(".github/workflows/flutter-apk-teste.yml")
oficial = ler(".github/workflows/flutter-release-apk.yml")
antiga = ler(".github/workflows/release-apk.yml")

# A esteira de teste precisa ser disparável à mão e compilar o Flutter.
for trecho, motivo in [
    ("workflow_dispatch", "a esteira de teste precisa de disparo manual"),
    ("subosito/flutter-action@v2", "a esteira de teste precisa do Flutter"),
    ("flutter build apk --release", "a esteira de teste precisa compilar o APK"),
    ("-PJARVIS_PERMITIR_DEBUG=true", "a assinatura de debug é consciente e explícita"),
    ("--target-platform android-arm64", "o APK distribuído é arm64"),
    ("sha256sum", "o APK sai com SHA-256"),
    ("gh release create", "o APK precisa ir para um Release para ter link"),
]:
    if trecho not in esteira:
        falhas.append(f"esteira do APK de teste sem {trecho!r} ({motivo})")

# E precisa dizer na cara que não é o APK oficial.
for trecho in ("chave de debug", "não recebe atualização por cima"):
    if trecho not in esteira:
        falhas.append(f"aviso ausente na esteira do APK de teste: {trecho!r}")
if "android-v$VERSAO_APK-teste" not in esteira:
    falhas.append("a tag do release de teste precisa terminar em -teste para não "
                  "entrar no caminho de atualização do app")

# A esteira oficial continua exigindo a chave de release: nada de afrouxar.
for trecho in ("JARVIS_KEYSTORE_B64", "--exigir-release", "keytool"):
    if trecho not in oficial:
        falhas.append(f"esteira oficial perdeu a exigência de chave de release: {trecho!r}")

# Os fontes Kotlin que a preparação do Android copia precisam estar versionados,
# mesmo com android/ no .gitignore.
import subprocess

versionados = subprocess.run(
    ["git", "ls-files", "flutter_app/android"],
    cwd=RAIZ,
    capture_output=True,
    text=True,
    check=False,
).stdout
for fonte in ("JarvisAbrirTela.kt", "JarvisMensagens.kt"):
    if f"flutter_app/android/{fonte}" not in versionados:
        falhas.append(f"{fonte} precisa estar versionado: a esteira copia do checkout")

# O setup-python da esteira antiga não pode pedir cache sem arquivo de dependências.
if any(linha.strip() == "cache: pip" for linha in antiga.splitlines()):
    falhas.append("release-apk.yml: setup-python com cache: pip falha sem requirements.txt")

# O contrato entra na suíte.
pacote = json.loads(ler("package.json") or "{}")
if "tests/test_apk_de_teste.py" not in pacote.get("scripts", {}).get("test:all", ""):
    falhas.append("tests/test_apk_de_teste.py não está no test:all")

if falhas:
    for falha in falhas:
        print(f"FALHA: {falha}", file=sys.stderr)
    sys.exit(1)
print("OK: APK de teste, assinatura de debug e fontes versionados")
