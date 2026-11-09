"""Prepara o modelo KWS sherpa-onnx para inclusão no APK Android.

Baixa apenas os artefatos necessários do modelo GigaSpeech, gera a palavra-chave
com o tokenizer oficial do sherpa-onnx e valida os arquivos antes do empacotamento.
O modelo de reconhecimento é inglês; "Jarvis" é configurado como hotword. O áudio
em execução permanece local no dispositivo.
"""
from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

VERSAO = "1.13.8"
MODELO = "sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01"
URL = f"https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/{MODELO}.tar.bz2"
ARQUIVOS = (
    "encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
    "decoder-epoch-12-avg-2-chunk-16-left-64.onnx",
    "joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
    "tokens.txt",
    "bpe.model",
)
ARQUIVOS_RUNTIME = tuple(x for x in ARQUIVOS if x != "bpe.model")


def baixar(destino: Path) -> None:
    pedido = urllib.request.Request(URL, headers={"User-Agent": "JARVIS-Nova-KWS/1.46.0"})
    with urllib.request.urlopen(pedido, timeout=180) as resposta, destino.open("wb") as saida:
        shutil.copyfileobj(resposta, saida, length=1024 * 1024)


def extrair_seletivo(arquivo: Path, destino: Path) -> None:
    destino.mkdir(parents=True, exist_ok=True)
    esperados = set(ARQUIVOS)
    with tarfile.open(arquivo, "r:bz2") as pacote:
        encontrados = {}
        for membro in pacote.getmembers():
            nome = Path(membro.name).name
            if nome in esperados and membro.isfile():
                encontrados[nome] = membro
        faltantes = esperados - set(encontrados)
        if faltantes:
            raise SystemExit("O pacote do KWS não contém: " + ", ".join(sorted(faltantes)))
        for nome, membro in encontrados.items():
            origem = pacote.extractfile(membro)
            if origem is None:
                raise SystemExit(f"Não foi possível ler o artefato {nome}")
            with origem, (destino / nome).open("wb") as saida:
                shutil.copyfileobj(origem, saida)


def gerar_keywords(pasta: Path) -> None:
    cli = shutil.which("sherpa-onnx-cli")
    if not cli:
        raise SystemExit("sherpa-onnx-cli não encontrado. Instale sherpa-onnx==1.13.8 no Python do build.")
    raw = pasta / "keywords_raw.txt"
    raw.write_text("JARVIS\nJAVIS\n", encoding="utf-8")
    subprocess.run([
        cli, "text2token",
        "--tokens", str(pasta / "tokens.txt"),
        "--tokens-type", "bpe",
        "--bpe-model", str(pasta / "bpe.model"),
        str(raw), str(pasta / "keywords.txt"),
    ], check=True)
    saida = pasta / "keywords.txt"
    if not saida.is_file() or not saida.read_text(encoding="utf-8").strip():
        raise SystemExit("O tokenizer não gerou keywords.txt válido.")


def preparar(app: Path) -> None:
    destino = app / "src/main/assets/kws"
    if all((destino / nome).is_file() and (destino / nome).stat().st_size > 0
           for nome in ARQUIVOS_RUNTIME) and (destino / "keywords.txt").is_file():
        print(f"Modelo KWS já preparado em {destino}")
        return
    with tempfile.TemporaryDirectory(prefix="jarvis-kws-") as tmp:
        raiz = Path(tmp)
        pacote = raiz / (MODELO + ".tar.bz2")
        baixar(pacote)
        bruto = raiz / MODELO
        extrair_seletivo(pacote, bruto)
        gerar_keywords(bruto)
        destino.mkdir(parents=True, exist_ok=True)
        for nome in ARQUIVOS_RUNTIME:
            shutil.copy2(bruto / nome, destino / nome)
        shutil.copy2(bruto / "keywords.txt", destino / "keywords.txt")
    for nome in ARQUIVOS_RUNTIME + ("keywords.txt",):
        p = destino / nome
        if not p.is_file() or p.stat().st_size == 0:
            raise SystemExit(f"Artefato KWS ausente ou vazio: {p}")
        print(f"{nome}: {p.stat().st_size} bytes · SHA-256 {hashlib.sha256(p.read_bytes()).hexdigest()}")
    print(f"Modelo KWS pronto: {destino}")


if __name__ == "__main__":
    pasta_app = Path(sys.argv[1] if len(sys.argv) > 1 else "android/app")
    if not pasta_app.is_dir():
        raise SystemExit(f"Pasta Android não encontrada: {pasta_app}")
    preparar(pasta_app)
