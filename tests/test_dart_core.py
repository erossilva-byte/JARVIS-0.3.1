"""Roda os testes Dart puros do núcleo da interface, quando há SDK do Dart.

O núcleo da conversa (agrupamento de tokens do streaming) não depende do Flutter, então pode
ser testado sem emulador e sem `flutter test`. Este passo procura o Dart no PATH, em DART_SDK
ou no SDK temporário usado no desenvolvimento; se não encontrar, avisa e não reprova — o CI
com Flutter roda `flutter analyze` e `flutter test`, e o workflow nativo chama o teste puro
diretamente.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent


def localizar_dart() -> str | None:
    no_path = shutil.which("dart")
    if no_path:
        return no_path
    candidatos = []
    sdk = os.environ.get("DART_SDK")
    if sdk:
        candidatos.append(Path(sdk) / "bin" / "dart")
    candidatos.append(Path("/tmp/dart-sdk/bin/dart"))
    candidatos.append(Path("/tmp/flutter/bin/dart"))
    for caminho in candidatos:
        if caminho.is_file():
            return str(caminho)
    return None


CASOS = (
    ("tool/stream_buffer_test.dart", "agrupamento de tokens (32 ms)"),
    ("tool/sse_test.dart", "parser SSE do streaming"),
    ("tool/conversa_test.dart", "modelo de conversa e título automático"),
    ("tool/memoria_test.dart", "memória: Markdown, busca, citação e orçamento"),
)


def main() -> int:
    dart = localizar_dart()
    if dart is None:
        print("AVISO: Dart não encontrado — testes puros do núcleo não rodaram.")
        return 0
    for caminho, rotulo in CASOS:
        r = subprocess.run(
            [dart, "run", caminho],
            cwd=RAIZ / "flutter_app",
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if r.returncode != 0:
            print((r.stdout or "") + (r.stderr or ""))
            print(f"FALHOU: {rotulo}.")
            return 1
    print("OK: núcleo Dart — " + "; ".join(rotulo for _, rotulo in CASOS))
    return 0

if __name__ == "__main__":
    sys.exit(main())
