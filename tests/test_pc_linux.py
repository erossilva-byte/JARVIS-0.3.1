#!/usr/bin/env python3
"""Contrato da versão Linux do app do PC.

O app é Electron e o código já era agnóstico de sistema em quase tudo. O que
faltava era empacotar, publicar e não fingir controle de mídia/volume quando a
ferramenta do Linux não está instalada. Este contrato prende:

- os dois alvos de pacote (AppImage e deb) e o que o deb exige (mantenedor);
- o job de Linux na esteira de release, com conferência de tamanho e anexo na tag;
- as alternativas de mídia/volume no `main.js` e a recusa explicada sem elas;
- a documentação, incluindo o limite honesto de que nada rodou numa área de
  trabalho Linux de verdade.
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


# 1. Empacotamento.
pacote = json.loads(ler(RAIZ / "package.json") or "{}")
build = pacote.get("build") or {}
linux = build.get("linux") or {}
exigir(sorted(linux.get("target") or []) == ["AppImage", "deb"],
       "o build.linux precisa ter os alvos AppImage e deb")
exigir(linux.get("executableName") == "jarvis-nova", "executável do Linux sem nome definido")
exigir("${version}" in str(linux.get("artifactName")) and "${arch}" in str(linux.get("artifactName")),
       "o nome do pacote Linux precisa levar versão e arquitetura")
autor = pacote.get("author") or {}
exigir(isinstance(autor, dict) and "@" in str(autor.get("email")),
       "o .deb exige mantenedor com e-mail: package.json sem author.email")
exigir("dist:linux" in (pacote.get("scripts") or {}), "falta o script dist:linux")
exigir("node tests/test_pc_linux.py" in (pacote.get("scripts") or {}).get("test:all", "")
       or "python3 tests/test_pc_linux.py" in (pacote.get("scripts") or {}).get("test:all", ""),
       "test:all não roda o contrato do Linux")

# 2. Esteira.
fluxo = ler(RAIZ / ".github" / "workflows" / "release-pc.yml")
for trecho in [
    "name: Empacotar Linux (AppImage + deb)",
    "runs-on: ubuntu-latest",
    "npx electron-builder --linux AppImage deb",
    "name: jarvis-nova-linux",
    "'*.AppImage'",
    "'*.deb'",
    "chmod +x \"$APPIMAGE\"",
]:
    exigir(trecho in fluxo, f"release-pc.yml perdeu: {trecho}")
exigir(fluxo.find("Empacotar Linux") < fluxo.find("Anexar Linux ao release"),
       "o Linux precisa ser empacotado antes de anexar ao release")
exigir("if: github.ref_type == 'tag'" in fluxo, "o anexo do release precisa ser só em tag")

# 3. Código do processo principal.
principal = ler(RAIZ / "platforms" / "desktop" / "main.js")
for trecho in [
    "const MIDIA_LINUX = {",
    "playerctl",
    "pactl",
    "wpctl",
    "if (plat === 'linux') {",
    "loginctl",
]:
    exigir(trecho in principal, f"main.js perdeu: {trecho}")
exigir("instale o playerctl" in principal, "sem playerctl o app precisa dizer o que instalar")
exigir("instale o pactl" in principal, "sem pactl/wpctl o app precisa dizer o que instalar")
exigir("/^[a-z][a-z0-9+.-]+:/i" in principal or "shell.openExternal" in principal,
       "o app do PC precisa continuar abrindo links pelo sistema")
exigir(not re.search(r"if \(plat === 'win32'\)[^}]*teclaMultimidiaWindows", principal)
       or "plat === 'linux'" in principal,
       "controle de mídia ficou só no Windows")

# 4. Documentação honesta.
doc = ler(RAIZ / "platforms" / "LINUX.md")
for trecho in [
    "## Instalar",
    "## O que cada recurso precisa no Linux",
    "playerctl",
    "pactl",
    "wpctl",
    "safeStorage",
    "## Limites declarados",
    "área de trabalho Linux real",
    "jarvis@exemplo.local",
]:
    exigir(trecho in doc, f"platforms/LINUX.md perdeu: {trecho}")

if falhas:
    print(f"Linux do PC: {len(falhas)} falha(s).")
    for falha in falhas:
        print("  - " + falha)
    sys.exit(1)
print("PC no Linux: empacotamento, esteira, mídia/volume e limites — contrato OK")
