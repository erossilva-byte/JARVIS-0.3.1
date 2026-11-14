"""Ensaio do Gate A: o patch aplica num código limpo e reconstrói o estado atual?

A publicação deste projeto sai como patch (a integração recusa arquivos grandes). Antes de
pedir uma rodada de CI, este ensaio responde duas perguntas:

1. o patch aplica sobre o HEAD, sem conflito, num diretório limpo?
2. depois de aplicado, cada arquivo alterado fica igual ao da árvore de trabalho — e nenhuma
   mudança da árvore ficou de fora do patch?

Uso:
    python3 ci/rehearsal_gate_a.py ../files/interface-v3.patch
    python3 ci/rehearsal_gate_a.py patch.patch --aplicar   # no CI: aplica na árvore e segue

O modo `--aplicar` é para o GitHub Actions: a árvore é o checkout limpo, então não há o que
comparar — o ensaio confere que o patch aplica e roda a pré-checagem no código resultante,
antes de o APK ser compilado.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
IGNORAR = ("node_modules/", "files/", ".git/")


def rodar(partes: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(partes, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def caminhos_do_patch(patch: Path) -> list[str]:
    """Arquivos citados no patch, na ordem em que aparecem."""
    lista: list[str] = []
    for linha in patch.read_text(encoding="utf-8").splitlines():
        if not linha.startswith("diff --git a/"):
            continue
        _, _, resto = linha.partition(" b/")
        if resto and resto not in lista:
            lista.append(resto)
    return lista


def mudancas_da_arvore() -> list[str]:
    """Mudanças de trabalho (não preparadas) e arquivos novos.

    O repositório já tinha arquivos preparados de sessões anteriores (Flutter, .gitignore);
    eles não pertencem a este patch. O que interessa aqui é o que foi editado agora: diff
    não preparado + arquivos novos não ignorados.
    """
    lista: list[str] = []
    diff = rodar(["git", "diff", "--name-only"], RAIZ)
    if diff.returncode != 0:
        raise SystemExit("não consegui ler o git diff: " + diff.stderr.strip())
    for caminho in diff.stdout.splitlines():
        caminho = caminho.strip()
        if caminho and not caminho.startswith(IGNORAR) and caminho not in lista:
            lista.append(caminho)
    novos = rodar(["git", "ls-files", "--others", "--exclude-standard"], RAIZ)
    if novos.returncode != 0:
        raise SystemExit("não consegui listar os arquivos novos: " + novos.stderr.strip())
    for caminho in novos.stdout.splitlines():
        caminho = caminho.strip()
        if caminho and not caminho.startswith(IGNORAR) and caminho not in lista:
            lista.append(caminho)
    return lista


def aplicar_na_arvore(patch: Path) -> int:
    """Modo do CI: aplica o patch no checkout e roda a pré-checagem no resultado."""
    conferir = rodar(["git", "apply", "--check", str(patch)], RAIZ)
    if conferir.returncode != 0:
        print("FALHA: o patch não aplica no checkout:\n" + (conferir.stderr or conferir.stdout).strip())
        return 1
    aplicar = rodar(["git", "apply", str(patch)], RAIZ)
    if aplicar.returncode != 0:
        print("FALHA: o patch falhou ao aplicar:\n" + (aplicar.stderr or aplicar.stdout).strip())
        return 1
    preflight = rodar(["python3", "ci/preflight_android.py"], RAIZ)
    if preflight.returncode != 0:
        print("FALHA: pré-checagem reprovou no código vindo do patch:\n" + preflight.stdout.strip())
        return 1
    print(f"Gate A (CI): patch aplicado no checkout ({len(caminhos_do_patch(patch))} arquivo(s)) e pré-checagem aprovada.")
    return 0


def main() -> int:
    aplicar = "--aplicar" in sys.argv[1:]
    argumentos = [a for a in sys.argv[1:] if a != "--aplicar"]
    if len(argumentos) != 1:
        print("uso: python3 ci/rehearsal_gate_a.py <caminho-do-patch> [--aplicar]")
        return 2
    patch = Path(argumentos[0]).resolve()
    if not patch.is_file():
        print(f"patch não encontrado: {patch}")
        return 2
    arquivos = caminhos_do_patch(patch)
    if not arquivos:
        print("o patch não cita nenhum arquivo")
        return 1
    if aplicar:
        return aplicar_na_arvore(patch)

    with tempfile.TemporaryDirectory(prefix="gate-a-") as tmp:
        destino = Path(tmp)
        # Cópia limpa do HEAD, sem .git: é o que o CI veria antes do patch.
        r = subprocess.run(
            ["bash", "-c", f"git archive HEAD | tar -x -C '{destino}'"],
            cwd=RAIZ, capture_output=True, text=True,
        )
        if r.returncode != 0:
            print("FALHA: não consegui exportar o HEAD: " + (r.stderr or r.stdout).strip())
            return 1

        conferir = rodar(["git", "apply", "--check", str(patch)], destino)
        if conferir.returncode != 0:
            print("FALHA: o patch não aplica no HEAD limpo:\n" + (conferir.stderr or conferir.stdout).strip())
            return 1
        aplicar = rodar(["git", "apply", str(patch)], destino)
        if aplicar.returncode != 0:
            print("FALHA: o patch falhou ao aplicar:\n" + (aplicar.stderr or aplicar.stdout).strip())
            return 1

        divergentes: list[str] = []
        ausentes: list[str] = []
        for caminho in arquivos:
            atual = RAIZ / caminho
            aplicado = destino / caminho
            if not aplicado.is_file():
                ausentes.append(caminho)
                continue
            if not atual.is_file() or atual.read_bytes() != aplicado.read_bytes():
                divergentes.append(caminho)
        if ausentes or divergentes:
            if ausentes:
                print("FALHA: o patch não criou: " + ", ".join(ausentes[:10]))
            if divergentes:
                print("FALHA: conteúdo do patch difere da árvore: " + ", ".join(divergentes[:10]))
            return 1

        # O repositório carrega mudanças de outras sessões (Flutter, arquivos grandes). O
        # patch tem escopo declarado; aqui só avisamos o que ficou de fora, sem reprovar.
        cobertos = set(arquivos)
        fora = [c for c in mudancas_da_arvore() if c not in cobertos]
        if fora:
            print(f"AVISO: {len(fora)} arquivo(s) alterado(s) fora do escopo deste patch "
                  "(não avaliados pelo ensaio).")

        preflight = rodar(["python3", "ci/preflight_android.py"], destino)
        if preflight.returncode != 0:
            print("FALHA: pré-checagem reprovou no código vindo do patch:\n" + preflight.stdout.strip())
            return 1

    print(
        f"Gate A (ensaio): patch aplica no HEAD limpo, {len(arquivos)} arquivo(s) conferidos "
        "e pré-checagem aprovada no código vindo do patch."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
