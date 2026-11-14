"""Roda a verificação completa do projeto e imprime um resumo legível.

Um comando só: pré-checagem Android, suíte completa e empacotamento. Cada etapa é executada
mesmo que a anterior falhe, para mostrar o estado inteiro de uma vez; o código de saída é
diferente de zero se qualquer etapa falhar.

A pré-checagem e o empacotamento também rodam dentro de `npm run test:all`. Aqui eles aparecem
separados de propósito: assim o resumo diz qual barreira caiu, em vez de "a suíte falhou".
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

ETAPAS = [
    ("Pré-checagem Android", ["python3", "ci/preflight_android.py"]),
    ("Suíte completa", ["npm", "run", "test:all"]),
    ("Empacotamento", ["python3", "tests/test_empacotamento.py"]),
]


def comando(partes: list[str]) -> list[str]:
    """No Windows o npm é um .cmd; no restante, o binário comum."""
    if partes[0] == "npm" and shutil.which("npm") is None and shutil.which("npm.cmd"):
        return ["npm.cmd"] + partes[1:]
    return partes


def executar(partes: list[str]) -> tuple[int, str, float]:
    inicio = time.monotonic()
    try:
        r = subprocess.run(
            comando(partes),
            cwd=RAIZ,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        saida = (r.stdout or "") + (r.stderr or "")
        return r.returncode, saida, time.monotonic() - inicio
    except FileNotFoundError as e:
        return 127, f"comando não encontrado: {e}", time.monotonic() - inicio


def resumo_suite(saida: str) -> tuple[int, int]:
    ok = sum(1 for linha in saida.splitlines() if linha.startswith("OK:"))
    avisos = sum(1 for linha in saida.splitlines() if linha.startswith("AVISO:"))
    return ok, avisos


def main() -> int:
    resultados: list[tuple[str, int, str, float]] = []
    for rotulo, partes in ETAPAS:
        codigo, saida, segundos = executar(partes)
        resultados.append((rotulo, codigo, saida, segundos))
        if codigo != 0:
            # Falhou: mostra o fim da saída, que é onde o erro costuma estar.
            print(f"\n--- {rotulo}: saída (últimas linhas) ---")
            for linha in saida.strip().splitlines()[-25:]:
                print(linha)
            print(f"--- fim de {rotulo} ---\n")

    print("Resumo da verificação")
    largura = max(len(rotulo) for rotulo, *_ in resultados)
    for rotulo, codigo, saida, segundos in resultados:
        estado = "OK    " if codigo == 0 else "FALHOU"
        detalhe = ""
        if rotulo == "Suíte completa" and codigo == 0:
            ok, avisos = resumo_suite(saida)
            detalhe = f" · {ok} verificações OK"
            if avisos:
                detalhe += f", {avisos} aviso(s)"
        print(f"  {estado}  {rotulo.ljust(largura)}  {segundos:5.1f} s{detalhe}")

    falhas = [rotulo for rotulo, codigo, *_ in resultados if codigo != 0]
    if falhas:
        print(f"\nFalhou: {len(falhas)} de {len(resultados)} etapa(s) — {', '.join(falhas)}.")
        return 1
    print(f"\nTudo certo: {len(resultados)} de {len(resultados)} etapas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
