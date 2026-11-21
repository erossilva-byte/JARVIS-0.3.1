#!/usr/bin/env python3
"""Confere qual chave assinou o APK — e reprova APK de release em debug.

Um APK assinado com a chave de debug não instala por cima de outro build: o
Android recusa a atualização. Este script existe para isso não passar
despercebido.

Uso:
    python3 tool/verificar_assinatura.py CAMINHO.apk
    python3 tool/verificar_assinatura.py CAMINHO.apk --exigir-release
    python3 tool/verificar_assinatura.py CAMINHO.apk --fingerprint 00:11:...
    python3 tool/verificar_assinatura.py CAMINHO.apk --properties ~/.jarvis/key.properties

`--exigir-release` falha se o certificado for de debug (CN=Android Debug).
`--fingerprint` (ou `certificadoSha256` no key.properties) falha se o SHA-256 do
signatário não for o esperado.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def achar_apksigner() -> str | None:
    no_path = shutil.which("apksigner")
    if no_path:
        return no_path
    sdk = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if sdk:
        builds = Path(sdk) / "build-tools"
        if builds.is_dir():
            candidatos = sorted(
                (p / "apksigner" for p in builds.iterdir() if p.is_dir()),
                reverse=True,
            )
            for candidato in candidatos:
                if candidato.is_file():
                    return str(candidato)
    return None


def ler_propriedade(arquivo: Path, nome: str) -> str | None:
    if not arquivo.is_file():
        return None
    for linha in arquivo.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        chave, valor = linha.split("=", 1)
        if chave.strip() == nome:
            return valor.strip() or None
    return None


def normalizar(impressao: str) -> str:
    return re.sub(r"[^0-9a-f]", "", impressao.lower())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", help="caminho do APK")
    parser.add_argument("--exigir-release", action="store_true",
                        help="reprova APK assinado com a chave de debug")
    parser.add_argument("--fingerprint", default=None,
                        help="SHA-256 esperado do certificado")
    parser.add_argument("--properties", default=os.environ.get("JARVIS_KEY_PROPERTIES"),
                        help="key.properties para ler certificadoSha256")
    args = parser.parse_args()

    apk = Path(args.apk)
    if not apk.is_file():
        print(f"APK não encontrado: {apk}", file=sys.stderr)
        return 2
    apksigner = achar_apksigner()
    if not apksigner:
        print("apksigner não encontrado: defina ANDROID_SDK_ROOT ou instale build-tools.",
              file=sys.stderr)
        return 2

    # apksigner é um script que chama `java`; o JDK vem de JAVA_HOME quando existe.
    ambiente = dict(os.environ)
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        ambiente["PATH"] = f"{java_home}/bin:" + ambiente.get("PATH", "")
    saida = subprocess.run([apksigner, "verify", "--print-certs", str(apk)],
                           capture_output=True, text=True, env=ambiente)
    if saida.returncode != 0:
        erro = (saida.stderr or saida.stdout).strip()
        if "java" in erro and "not found" in erro:
            print("apksigner encontrado, mas o `java` não está no PATH. "
                  "Defina JAVA_HOME (JDK 17).", file=sys.stderr)
        else:
            print("Assinatura inválida ou APK corrompido:", file=sys.stderr)
        print(erro, file=sys.stderr)
        return 1
    texto = saida.stdout
    dn = re.search(r"certificate DN:\s*(.+)", texto)
    sha = re.search(r"certificate SHA-256 digest:\s*([0-9a-fA-F:]+)", texto)
    if not sha:
        print("Não foi possível ler o SHA-256 do certificado.", file=sys.stderr)
        return 1

    nome = dn.group(1).strip() if dn else "(desconhecido)"
    impressao = sha.group(1).strip()
    print(f"APK: {apk}")
    print(f"Certificado: {nome}")
    print(f"SHA-256: {impressao}")

    debug = "android debug" in nome.lower()
    if debug:
        print("Assinatura: DEBUG — não serve para distribuir nem para atualizar por cima.")

    esperado = args.fingerprint
    if not esperado and args.properties:
        esperado = ler_propriedade(Path(args.properties), "certificadoSha256")
    if esperado:
        if normalizar(esperado) != normalizar(impressao):
            print(f"FALHA: impressão digital diferente da esperada ({esperado}).")
            return 1
        print("Impressão digital confere com a esperada.")

    if args.exigir_release and debug:
        print("FALHA: APK de release assinado com a chave de debug.")
        return 1
    if args.exigir_release and not esperado:
        print("Aviso: confira a impressão digital com --fingerprint ou "
              "certificadoSha256 no key.properties.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
