"""Confere a integração da pasta do Obsidian via SAF (Android) por leitura estática.

Não há Android SDK aqui: este teste garante o que é mecânico e some fácil numa edição — a
permissão durável, a recusa de pasta sem permissão, os limites de leitura, o filtro de `.md` e o
nome do canal igual dos dois lados. Ele não prova que o seletor abre; isso é no aparelho.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
KOTLIN = RAIZ / "flutter_app" / "android" / "MainActivity.kt"
DART = RAIZ / "flutter_app" / "lib" / "services" / "cofre_saf.dart"
SCRIPT = RAIZ / "flutter_app" / "tool" / "prepare_android_sistema.py"

def problemas() -> list[str]:
    falhas: list[str] = []
    if not KOTLIN.is_file() or not DART.is_file():
        return ["MainActivity.kt ou cofre_saf.dart não encontrado"]

    kotlin = KOTLIN.read_text(encoding="utf-8")
    dart = DART.read_text(encoding="utf-8")

    # 1. Canal igual nos dois lados.
    no_kotlin = re.search(r'CANAL_MEMORIA\s*=\s*"([^"]+)"', kotlin)
    no_dart = re.search(r"canal\s*=\s*MethodChannel\('([^']+)'\)", dart)
    if not no_kotlin or not no_dart:
        falhas.append("canal de memória não declarado nos dois lados")
    elif no_kotlin.group(1) != no_dart.group(1):
        falhas.append(f"nomes de canal diferentes: {no_kotlin.group(1)} × {no_dart.group(1)}")

    # 2. Permissão durável de verdade.
    if "ACTION_OPEN_DOCUMENT_TREE" not in kotlin:
        falhas.append("seletor de pasta não usa ACTION_OPEN_DOCUMENT_TREE")
    if "FLAG_GRANT_PERSISTABLE_URI_PERMISSION" not in kotlin:
        falhas.append("seletor não pede permissão persistível")
    if "takePersistableUriPermission" not in kotlin:
        falhas.append("permissão não é tornada durável")
    if "persistedUriPermissions" not in kotlin:
        falhas.append("permissão não é reconferida ao abrir")
    if "releasePersistableUriPermission" not in kotlin:
        falhas.append("desconectar não libera a permissão")
    if "esquecerPasta()" not in kotlin:
        falhas.append("pasta revogada não é esquecida")

    # 3. Leitura restrita a Markdown, com limites.
    if '".md"' not in kotlin and "'.md'" not in kotlin:
        falhas.append("leitura não filtra arquivos .md")
    if "LIMITE_NOTAS" not in kotlin or "LIMITE_BYTES" not in kotlin:
        falhas.append("leitura sem limite de notas/tamanho")
    if "MIME_TYPE_DIR" not in kotlin:
        falhas.append("leitura não desce em subpastas")
    if "openInputStream" not in kotlin:
        falhas.append("leitura não abre o conteúdo pelo SAF")

    # 4. Escrita pela pasta, sem apagar nada de ninguém.
    if "FLAG_GRANT_WRITE_URI_PERMISSION" not in kotlin:
        falhas.append("seletor não pede permissão de escrita")
    if "escreverNota" not in kotlin or "openOutputStream" not in kotlin:
        falhas.append("gravação de nota não usa o fluxo do SAF")
    if "createDocument" not in kotlin:
        falhas.append("nota nova não é criada via SAF")
    if "deleteDocument" in kotlin:
        falhas.append("integração tenta apagar arquivo do cofre do usuário")
    if "podeEscrever" not in kotlin:
        falhas.append("pasta sem escrita não é sinalizada")

    sinc = RAIZ / "flutter_app" / "lib" / "core" / "memoria_sync.dart"
    if not sinc.is_file():
        falhas.append("núcleo de sincronização ausente")
    else:
        texto = sinc.read_text(encoding="utf-8")
        if "planejarSincronizacao" not in texto:
            falhas.append("núcleo de sincronização sem planejamento")
        if "apagar(" in texto:
            falhas.append("sincronização apaga nota local em vez de preservar conflito")
        if "conflito" not in texto:
            falhas.append("sincronização sem caminho de conflito")

    # 5. O Dart não inventa sucesso quando não há canal.
    if "MissingPluginException" not in dart:
        falhas.append("cofre Dart não trata ausência do canal")
    if "takePersistableUriPermission(" in dart:
        falhas.append("Dart tentando fazer papel do Kotlin")
    if "pastaAtual" not in dart or "escolherPasta" not in dart or "listarNotas" not in dart or "escreverNota" not in dart:
        falhas.append("métodos do canal não expostos no Dart")

    # 6. O template do app é copiado pelo script e referencia o mesmo pacote.
    if "MainActivity.kt" not in SCRIPT.read_text(encoding="utf-8"):
        falhas.append("script de preparação não copia o MainActivity com SAF")
    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"SAF da memória: {len(falhas)} problema(s).")
        return 1
    print("OK: SAF da memória — seletor, permissão durável, leitura, escrita sem apagar e canal único")
    return 0


if __name__ == "__main__":
    sys.exit(main())
