#!/usr/bin/env python3
"""Baixa o runtime neural oficial (sherpa-onnx) para android/app/libs.

Por que baixar e não versionar: o AAR tem ~48 MB e carrega bibliotecas nativas
para quatro arquiteturas. Guardar isso no Git engordaria o repositório para
sempre; o build baixa uma vez e confere o SHA-256.

O app usa o runtime em duas frentes:
  * TTS neural opcional (Piper/VITS e Kokoro) — este é o motivo do download;
  * nenhuma outra função depende dele: sem o AAR o build falha com mensagem
    explícita, e no aparelho a voz do sistema continua sendo o padrão.
"""
from __future__ import annotations

import hashlib
import sys
import urllib.request
from pathlib import Path

VERSAO = "1.13.8"
URL = f"https://github.com/k2-fsa/sherpa-onnx/releases/download/v{VERSAO}/sherpa-onnx-{VERSAO}.aar"
SHA256 = "633c24321e06b1fe79feafa03ea16cbc0f8a286641e2da3559bac91bdb13bd96"
BYTES = 50129134
NOME = f"sherpa-onnx-{VERSAO}.aar"


def destino(raiz: Path) -> Path:
    return raiz / "android" / "app" / "libs" / NOME


def conferir(arquivo: Path) -> bool:
    if not arquivo.exists() or arquivo.stat().st_size != BYTES:
        return False
    h = hashlib.sha256()
    with arquivo.open("rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest() == SHA256


def baixar(arquivo: Path) -> None:
    arquivo.parent.mkdir(parents=True, exist_ok=True)
    parcial = arquivo.with_suffix(".part")
    print(f"Baixando {URL}")
    with urllib.request.urlopen(URL, timeout=120) as resposta, parcial.open("wb") as saida:
        total = int(resposta.headers.get("Content-Length") or BYTES)
        lido = 0
        while True:
            bloco = resposta.read(1 << 20)
            if not bloco:
                break
            saida.write(bloco)
            lido += len(bloco)
            if total:
                print(f"  {lido * 100 // total:3d}%  {lido}/{total}", end="\r", flush=True)
    print()
    if parcial.stat().st_size != BYTES:
        raise SystemExit(f"Tamanho inesperado: {parcial.stat().st_size} (esperado {BYTES})")
    parcial.replace(arquivo)


def main() -> int:
    raiz = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    arquivo = destino(raiz)
    if conferir(arquivo):
        print(f"AAR já presente e conferido: {arquivo}")
        return 0
    if arquivo.exists():
        print("AAR existente com tamanho/hash diferente: baixando de novo.")
    try:
        baixar(arquivo)
    except Exception as e:  # rede fora, proxy, rate limit do GitHub
        print(f"Falha ao baixar o runtime neural: {e}", file=sys.stderr)
        return 1
    if not conferir(arquivo):
        print("SHA-256 não confere com o publicado. Build interrompido.", file=sys.stderr)
        arquivo.unlink(missing_ok=True)
        return 1
    print(f"OK: {arquivo} ({arquivo.stat().st_size} bytes, sha256 {SHA256[:16]}…)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
