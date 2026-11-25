#!/usr/bin/env python3
"""Contrato do bloco 120 — a máscara de PIN convive com apelidos e envio.

A pergunta era se mascarar 4 a 8 dígitos poderia quebrar um apelido com número
ou um comando com número. A resposta precisa ser presa em teste, não em
promessa. Este contrato garante:

1. a máscara é chamada **só** na gravação (histórico e conversa salva);
2. as regras de apelido, de contato e de mensagem não importam a máscara;
3. existe um teste puro provando apelido com número, contato com número e
   comando com número, e ele está registrado;
4. versão, CHANGELOG e relatório acompanham.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


# 1. Onde a máscara pode aparecer.
locais_dart = {
    "core/segredo_pedido.dart",
    "services/historico_voz_service.dart",
    "services/conversa_store.dart",
}
for arquivo in sorted(LIB.rglob("*.dart")):
    relativo = arquivo.relative_to(LIB).as_posix()
    texto = arquivo.read_text(encoding="utf-8")
    usa = "protegerPinNoPedido(" in texto and not relativo.endswith(
        "segredo_pedido.dart")
    if usa:
        exigir(relativo in locais_dart,
               f"a máscara escapou para o caminho de comando: {relativo}")

locais_kt = {"JarvisSegredo.kt", "JarvisFundo.kt"}
for arquivo in sorted((APP / "android").glob("*.kt")):
    texto = arquivo.read_text(encoding="utf-8")
    if "ocultarPin(" in texto and arquivo.name != "JarvisSegredo.kt":
        exigir(arquivo.name in locais_kt,
               f"o Kotlin mascara fora da gravação: {arquivo.name}")

# 2. As regras que interpretam a fala não conhecem a máscara.
for nome in ["core/pedido_apelido.dart", "core/nome_contato.dart",
             "core/aparelho.dart"]:
    texto = ler(LIB / nome)
    exigir("segredo_pedido" not in texto,
           f"{nome} importa a máscara — ela não pertence à interpretação")
    exigir("protegerPinNoPedido" not in texto,
           f"{nome} aplica a máscara no meio da interpretação")

# 3. O teste puro que prova a convivência.
teste = ler(APP / "tool" / "pin_sem_colisao_test.dart")
for trecho in [
    "chama o Murilo de Murilo 2",
    "escolherContato('Murilo 2'",
    "interpretarMensagem",
    "o código é 4321",
    "protegerPinNoPedido(mensagem.texto)",
]:
    exigir(trecho in teste, f"o teste de convivência não cobre: {trecho}")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
exigir("tool/pin_sem_colisao_test.dart" in nucleo,
       "o teste de convivência não está em test_dart_core.py")

# 4. O mesmo número aparece nas duas linguagens, sem divergir.
dart = ler(LIB / "core" / "segredo_pedido.dart")
kt = ler(APP / "android" / "JarvisSegredo.kt")
faixa_dart = re.search(r"\\d\{(\d+),(\d+)\}", dart)
faixa_kt = re.search(r"\\d\{(\d+),(\d+)\}", kt)
exigir(faixa_dart is not None and faixa_kt is not None,
       "não achei a faixa de dígitos nas duas regras")
if faixa_dart and faixa_kt:
    exigir(faixa_dart.groups() == faixa_kt.groups(),
           "a faixa de dígitos diverge entre Dart e Kotlin")

# 5. Versão, docs e registros.
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_120-mascara-e-comandos.md")
exigir("version: 1.104.0+110400" in pubspec,
       "pubspec.yaml não está em 1.104.0+110400")
exigir("## 1.97.0" in changelog, "CHANGELOG.md não tem o bloco 1.97.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 120")
exigir("test_bloco_120.py" in pacote, "package.json não roda o contrato 120")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_120.py" in dados["scripts"]["test:all"],
           "o contrato 120 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 120:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 120: máscara isolada da interpretação — contrato OK")
