"""Roda os contratos Python da suíte na mesma ordem do `npm run test:all`.

O CI não guarda uma lista própria de contratos: este script lê o `package.json`,
executa os comandos que começam com `python3` e falha se algum falhar. Assim o
workflow não envelhece em relação ao que se roda no computador (bloco 102).

Uso:
    python3 ci/contratos_python.py          # roda todos
    python3 ci/contratos_python.py --lista  # só mostra a lista
"""

from __future__ import annotations

import json
import shlex
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PACOTE = RAIZ / "package.json"


def comandos() -> list[str]:
    """Comandos Python do test:all, na ordem em que a suíte local os roda."""
    script = json.loads(PACOTE.read_text(encoding="utf-8"))["scripts"]["test:all"]
    pedacos = [pedaco.strip() for pedaco in script.split("&&")]
    return [pedaco for pedaco in pedacos if pedaco.startswith(("python3 ", "python "))]


def rodar(comando: str) -> int:
    print(f"::group::{comando}", flush=True)
    resultado = subprocess.run(shlex.split(comando), cwd=RAIZ)
    print("::endgroup::", flush=True)
    if resultado.returncode != 0:
        print(f"::error::{comando} falhou (código {resultado.returncode})", flush=True)
    return resultado.returncode


def main(argv: list[str]) -> int:
    lista = comandos()
    if "--lista" in argv:
        for comando in lista:
            print(comando)
        return 0
    if not lista:
        print("::error::nenhum comando Python encontrado em test:all", flush=True)
        return 1
    falhas = [comando for comando in lista if rodar(comando) != 0]
    print(f"{len(lista) - len(falhas)}/{len(lista)} comandos Python passaram.")
    if falhas:
        print("Falharam:", flush=True)
        for comando in falhas:
            print(f" - {comando}", flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
