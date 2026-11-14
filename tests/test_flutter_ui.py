"""Roda `flutter analyze` e `flutter test` quando o Flutter está instalado.

No CI esses dois passos são do workflow nativo. Aqui eles são repetidos na verificação local
para que uma quebra de widget não chegue ao GitHub. Sem Flutter no PATH, avisa e não reprova.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent


def localizar_flutter() -> str | None:
    no_path = shutil.which("flutter")
    if no_path:
        return no_path
    candidatos = [Path("/tmp/flutter/bin/flutter")]
    sdk = os.environ.get("FLUTTER_ROOT")
    if sdk:
        candidatos.insert(0, Path(sdk) / "bin" / "flutter")
    for caminho in candidatos:
        if caminho.is_file():
            return str(caminho)
    return None


def main() -> int:
    flutter = localizar_flutter()
    if flutter is None:
        print("AVISO: Flutter não encontrado — analyze e testes de widget não rodaram.")
        return 0
    app = RAIZ / "flutter_app"
    for rotulo, argumentos in (
        ("flutter analyze", [flutter, "analyze"]),
        ("flutter test", [flutter, "test"]),
    ):
        r = subprocess.run(argumentos, cwd=app, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode != 0:
            print((r.stdout or "") + (r.stderr or ""))
            print(f"FALHOU: {rotulo}.")
            return 1
    print("OK: interface Flutter — analyze sem problemas e testes de widget aprovados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
