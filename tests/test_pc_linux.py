#!/usr/bin/env python3
"""Contrato da versão Linux do app do PC.

O app é Electron e o código já era agnóstico de sistema em quase tudo. O que
faltava era empacotar, publicar e não fingir controle de mídia/volume quando a
ferramenta do Linux não está instalada. Este contrato prende:

- os três alvos de pacote (AppImage, deb e tar.gz) e o que o deb exige (mantenedor);
- o pacote sem FUSE: o AppImage antigo exigia `libfuse.so.2`, que o Ubuntu 22.04+
  não traz; hoje ele é reembalado com o runtime estático do projeto AppImage,
  existe o tar.gz como reserva e a documentação diz como sair de cada erro;
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
exigir(sorted(linux.get("target") or []) == ["AppImage", "deb", "tar.gz"],
       "o build.linux precisa ter os alvos AppImage, deb e tar.gz")
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
    "name: Empacotar Linux (AppImage + deb + tar.gz)",
    "runs-on: ubuntu-latest",
    "npx electron-builder --linux AppImage deb tar.gz",
    "name: jarvis-nova-linux",
    "'*.AppImage'",
    "'*.deb'",
    "'*.tar.gz'",
    "tar -tzf \"$TARBALL\"",
    "chmod +x \"$APPIMAGE\"",
    "python3 ci/appimage_sem_fuse.py dist",
]:
    exigir(trecho in fluxo, f"release-pc.yml perdeu: {trecho}")
exigir(fluxo.find("Empacotar Linux") < fluxo.find("Anexar Linux ao release"),
       "o Linux precisa ser empacotado antes de anexar ao release")
exigir("if: github.ref_type == 'tag'" in fluxo, "o anexo do release precisa ser só em tag")
exigir(fluxo.find("Empacotar Linux") < fluxo.find("appimage_sem_fuse.py") < fluxo.find("Anexar Linux ao release"),
       "o AppImage precisa ser reembalado antes de conferir e anexar")

# 3. AppImage que abre sem instalar FUSE.
sem_fuse = ler(RAIZ / "ci" / "appimage_sem_fuse.py")
for trecho in [
    "AppImage/type2-runtime",
    "runtime-x86_64",
    "2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d",
    "--appimage-offset",
    "--appimage-extract",
    "resources/app.asar",
]:
    exigir(trecho in sem_fuse, f"ci/appimage_sem_fuse.py perdeu: {trecho}")
exigir("appimage_sem_fuse.py" in (pacote.get("scripts") or {}).get("dist:linux", ""),
       "dist:linux precisa trocar o runtime do AppImage pelo estático")
exigir("electron-builder --linux" in (pacote.get("scripts") or {}).get("dist:linux", ""),
       "dist:linux continua empacotando com o electron-builder")

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
exigir(principal.count("function cofreDoPC(") == 1,
       "duas funções cofreDoPC no mesmo arquivo: a segunda sobrescreve a do cofre de chaves")
exigir("function cofreMemoriaDoPC(" in principal, "o cofre de memória em pasta precisa de nome próprio")
exigir("instale o playerctl" in principal, "sem playerctl o app precisa dizer o que instalar")
exigir("instale o pactl" in principal, "sem pactl/wpctl o app precisa dizer o que instalar")
exigir("/^[a-z][a-z0-9+.-]+:/i" in principal or "shell.openExternal" in principal,
       "o app do PC precisa continuar abrindo links pelo sistema")
exigir(not re.search(r"if \(plat === 'win32'\)[^}]*teclaMultimidiaWindows", principal)
       or "plat === 'linux'" in principal,
       "controle de mídia ficou só no Windows")

# 5. Documentação honesta.
doc = ler(RAIZ / "platforms" / "LINUX.md")
for trecho in [
    "## Instalar",
    "tar -xzf JARVIS-Nova",
    "## O que cada recurso precisa no Linux",
    "playerctl",
    "pactl",
    "wpctl",
    "safeStorage",
    "## Limites declarados",
    "área de trabalho Linux real",
    "jarvis@exemplo.local",
    # O erro que mais aparece no uso real: sem FUSE 2 o AppImage nem abre.
    "libfuse.so.2",
    "libfuse2t64",
    "APPIMAGE_EXTRACT_AND_RUN=1",
    "JARVIS_SEM_SANDBOX=1",
    # O ponto do bloco: o pacote publicado não pede mais FUSE do sistema.
    "runtime estático",
    "fusermount3",
    "Cannot mount AppImage",
]:
    exigir(trecho in doc, f"platforms/LINUX.md perdeu: {trecho}")

if falhas:
    print(f"Linux do PC: {len(falhas)} falha(s).")
    for falha in falhas:
        print("  - " + falha)
    sys.exit(1)
print("PC no Linux: empacotamento, esteira, mídia/volume e limites — contrato OK")
