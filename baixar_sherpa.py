"""Baixa o AAR do sherpa-onnx para o projeto Android, conferindo o SHA-256.

O AAR não é versionado no repositório (50 MB). Este script é chamado pelos
workflows antes do Gradle e pode ser rodado à mão:

    python3 baixar_sherpa.py android/app

O destino é <pasta-do-app>/libs/sherpa-onnx-<versao>.aar, exatamente o caminho
que patch_gradle.py referencia em `implementation files('libs/...')`.
"""
import hashlib
import sys
import urllib.request
from pathlib import Path

VERSAO = "1.13.8"
SHA256 = "633c24321e06b1fe79feafa03ea16cbc0f8a286641e2da3559bac91bdb13bd96"
URL = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
    f"v{VERSAO}/sherpa-onnx-{VERSAO}.aar"
)
NOME = f"sherpa-onnx-{VERSAO}.aar"


def baixar(destino: Path) -> None:
    print(f"Baixando {URL}")
    pedido = urllib.request.Request(URL, headers={"User-Agent": "JARVIS-Nova-build"})
    temporario = destino.with_suffix(destino.suffix + ".part")
    with urllib.request.urlopen(pedido, timeout=120) as resposta, open(temporario, "wb") as saida:
        esperado = resposta.headers.get("Content-Length")
        lido = 0
        while True:
            bloco = resposta.read(1 << 16)
            if not bloco:
                break
            saida.write(bloco)
            lido += len(bloco)
        if esperado and int(esperado) != lido:
            temporario.unlink(missing_ok=True)
            raise SystemExit(f"Download incompleto: {lido} de {esperado} bytes")
    temporario.replace(destino)


def conferir(arquivo: Path) -> None:
    resumo = hashlib.sha256()
    with open(arquivo, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            resumo.update(bloco)
    if resumo.hexdigest() != SHA256:
        raise SystemExit(
            f"SHA-256 inesperado para {arquivo.name}: {resumo.hexdigest()} (esperado {SHA256})"
        )


def main() -> None:
    app = Path(sys.argv[1] if len(sys.argv) > 1 else "android/app")
    if not app.is_dir():
        raise SystemExit(f"Pasta do app Android não encontrada: {app}")
    libs = app / "libs"
    libs.mkdir(parents=True, exist_ok=True)
    destino = libs / NOME
    if destino.is_file() and destino.stat().st_size > 10_000_000:
        conferir(destino)
        print(f"AAR já presente e conferido: {destino} ({destino.stat().st_size} bytes)")
        return
    baixar(destino)
    conferir(destino)
    print(f"AAR pronto: {destino} ({destino.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
