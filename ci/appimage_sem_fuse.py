#!/usr/bin/env python3
"""Troca o runtime do AppImage pelo estático, que não precisa de libfuse.so.2.

O electron-builder 25 embute o runtime antigo do AppImage: para montar o próprio
squashfs ele carrega `libfuse.so.2` do sistema. Essa biblioteca não vem mais no
Ubuntu 22.04+ (no 24.04 o pacote virou `libfuse2t64`), então o arquivo morria
antes de rodar qualquer linha do app:

    dlopen(): error loading libfuse.so.2
    AppImages require FUSE to run.

O projeto AppImage publica um runtime com libfuse e squashfuse ligados
estaticamente dentro do binário. Trocar só os primeiros bytes do AppImage (o
runtime, que fica antes do squashfs) é o suficiente: o conteúdo do app é copiado
byte a byte e o pacote passa a abrir sem nada instalado no sistema.

Uso:
    python3 ci/appimage_sem_fuse.py [pasta-dist]

O runtime é baixado uma vez do release fixado (URL e sha256 aqui no arquivo) e
fica em cache; `--runtime CAMINHO` usa um arquivo já baixado, sem rede.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# Release do AppImage/type2-runtime fixado de propósito: o mesmo binário que o
# electron-builder 26+ usa por padrão (toolset 1.0.3). Trocar a versão muda o
# runtime publicado, então o sha256 fica preso aqui e é conferido a cada build.
RUNTIME_URL = (
    "https://github.com/AppImage/type2-runtime/releases/download/"
    "20251108/runtime-x86_64"
)
RUNTIME_SHA256 = "2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"
RUNTIME_BYTES = 944632
RUNTIME_NOME = "runtime-x86_64-20251108"


def sha256(caminho: Path) -> str:
    resumo = hashlib.sha256()
    with caminho.open("rb") as arquivo:
        for bloco in iter(lambda: arquivo.read(1024 * 1024), b""):
            resumo.update(bloco)
    return resumo.hexdigest()


def conferir_runtime(caminho: Path) -> None:
    tamanho = caminho.stat().st_size
    if tamanho != RUNTIME_BYTES:
        raise SystemExit(
            f"runtime com {tamanho} bytes, esperado {RUNTIME_BYTES}: {caminho}"
        )
    resumo = sha256(caminho)
    if resumo != RUNTIME_SHA256:
        raise SystemExit(
            f"sha256 do runtime não confere ({resumo}); esperado {RUNTIME_SHA256}"
        )


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "jarvis-nova"


def garantir_runtime(forcado: str | None) -> Path:
    if forcado:
        caminho = Path(forcado).expanduser().resolve()
        if not caminho.is_file():
            raise SystemExit(f"runtime não encontrado: {caminho}")
        conferir_runtime(caminho)
        return caminho

    caminho = cache_dir() / RUNTIME_NOME
    if caminho.is_file():
        try:
            conferir_runtime(caminho)
            return caminho
        except SystemExit:
            caminho.unlink()  # cache corrompido: baixa de novo

    caminho.parent.mkdir(parents=True, exist_ok=True)
    parcial = caminho.with_suffix(".parcial")
    print(f"Baixando o runtime estático do AppImage: {RUNTIME_URL}")
    try:
        with urllib.request.urlopen(RUNTIME_URL, timeout=120) as resposta, \
                parcial.open("wb") as destino:
            shutil.copyfileobj(resposta, destino)
    except Exception as erro:  # rede bloqueada, proxy, release fora do ar
        parcial.unlink(missing_ok=True)
        raise SystemExit(
            f"não consegui baixar o runtime estático ({erro}).\n"
            f"Baixe {RUNTIME_URL} e rode de novo com --runtime CAMINHO."
        ) from erro
    conferir_runtime(parcial)
    parcial.chmod(0o755)
    os.replace(parcial, caminho)
    return caminho


def offset_do_appimage(arquivo: Path) -> int:
    """Onde o squashfs começa, segundo o próprio runtime do arquivo."""
    try:
        saida = subprocess.run(
            [str(arquivo.resolve()), "--appimage-offset"],
            capture_output=True, text=True, timeout=120, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as erro:
        raise SystemExit(f"{arquivo.name}: não consegui medir o offset ({erro})")
    try:
        return int(saida)
    except ValueError as erro:
        raise SystemExit(f"{arquivo.name}: offset inesperado: {saida!r}") from erro


def reembalar(arquivo: Path, runtime: Path) -> tuple[int, int]:
    antes = arquivo.stat().st_size
    inicio = offset_do_appimage(arquivo)
    if not 0 < inicio < antes:
        raise SystemExit(f"{arquivo.name}: offset {inicio} fora do arquivo ({antes} bytes)")

    temporario = arquivo.with_name(arquivo.name + ".reembalando")
    try:
        with temporario.open("wb") as destino, arquivo.open("rb") as origem:
            with runtime.open("rb") as rt:
                shutil.copyfileobj(rt, destino)
            origem.seek(inicio)
            shutil.copyfileobj(origem, destino)
        temporario.chmod(0o755)
        os.replace(temporario, arquivo)
    finally:
        temporario.unlink(missing_ok=True)

    return antes, arquivo.stat().st_size


def conferir_pacote(arquivo: Path) -> None:
    """O pacote só serve se o runtime novo achar e ler o conteúdo do app."""
    offset = offset_do_appimage(arquivo)
    if offset != RUNTIME_BYTES:
        raise SystemExit(
            f"{arquivo.name}: o runtime embutido tem {offset} bytes; "
            f"a troca não pegou (esperado {RUNTIME_BYTES})"
        )
    with tempfile.TemporaryDirectory() as pasta:
        for padrao in ("AppRun", "resources/app.asar"):
            # Caminho absoluto: a extração roda numa pasta temporária.
            resultado = subprocess.run(
                [str(arquivo.resolve()), "--appimage-extract", padrao],
                cwd=pasta, capture_output=True, text=True, timeout=300,
            )
            extraido = Path(pasta) / "squashfs-root" / padrao
            if resultado.returncode != 0 or not extraido.is_file() or extraido.stat().st_size == 0:
                raise SystemExit(
                    f"{arquivo.name}: o conteúdo não abre depois da troca "
                    f"({padrao}): {resultado.stdout}{resultado.stderr}"
                )


def principal() -> int:
    analisador = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    analisador.add_argument("pasta", nargs="?", default="dist",
                            help="pasta com os pacotes (padrão: dist)")
    analisador.add_argument("--runtime", default=None,
                            help="runtime já baixado, para não usar a rede")
    argumentos = analisador.parse_args()

    pasta = Path(argumentos.pasta)
    if not pasta.is_dir():
        raise SystemExit(f"pasta não encontrada: {pasta}")
    pacotes = sorted(pasta.glob("*.AppImage"))
    if not pacotes:
        raise SystemExit(f"nenhum AppImage em {pasta}: rode o electron-builder antes")

    runtime = garantir_runtime(argumentos.runtime)
    for pacote in pacotes:
        antes, depois = reembalar(pacote, runtime)
        conferir_pacote(pacote)
        print(
            f"{pacote.name}: runtime estático embutido (sem libfuse.so.2) · "
            f"{antes / 1024 / 1024:.1f} MB → {depois / 1024 / 1024:.1f} MB · "
            f"sha256 {sha256(pacote)[:16]}"
        )
    print(f"AppImage pronto para abrir sem instalar nada ({len(pacotes)} arquivo(s)).")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
