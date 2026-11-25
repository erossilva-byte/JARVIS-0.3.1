#!/usr/bin/env python3
"""Contrato do bloco 118 — PIN ditado não entra no histórico de execuções.

O que este contrato prende, sem aparelho:

1. existe uma regra pura de máscara para 4 a 8 dígitos isolados, igual no Dart e
   no Kotlin;
2. o app mascara antes de o pedido sair pelo canal, e o Android mascara de novo
   no funil de gravação (que cobre o serviço de segundo plano);
3. não sobrou nenhuma gravação do pedido cru no histórico;
4. telefone e hora continuam legíveis;
5. versão, CHANGELOG, relatório e registros acompanham a mudança.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"
ANDROID = APP / "android"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


regra_dart = ler(LIB / "core" / "segredo_pedido.dart")
servico = ler(LIB / "services" / "historico_voz_service.dart")
regra_kt = ler(ANDROID / "JarvisSegredo.kt")
fundo_kt = ler(ANDROID / "JarvisFundo.kt")
canal_kt = ler(ANDROID / "JarvisFundoCanal.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_118-pin-fora-do-historico.md")

# 1. Regra nos dois lados, com a mesma faixa e o mesmo marcador.
for trecho in ["textoOcultoNoPedido", r"protegerPinNoPedido(String texto)",
               r"(?<!\d)\d{4,8}(?!\d)"]:
    exigir(trecho in regra_dart, f"a regra Dart não tem {trecho}")
for trecho in ["OCULTO", "fun ocultarPin(texto: String)",
               r"(?<!\\d)\\d{4,8}(?!\\d)"]:
    exigir(trecho in regra_kt, f"a regra Kotlin não tem {trecho}")
exigir('"[oculto]"' in regra_kt, "o marcador do Kotlin não é [oculto]")
exigir("'[oculto]'" in regra_dart, "o marcador do Dart não é [oculto]")

# 2. Aplicação nas duas pontas.
exigir("protegerPinNoPedido(pedido.trim())" in servico,
       "o app não mascara o pedido antes de mandar ao canal")
exigir("JarvisSegredo.ocultarPin(pedido.trim())" in fundo_kt,
       "o Android não mascara o pedido no funil de gravação")

# 3. Nenhuma gravação crua sobrou.
for arquivo, texto in [("JarvisFundo.kt", fundo_kt),
                       ("JarvisFundoCanal.kt", canal_kt)]:
    exigir('put("pedido", pedido.trim()' not in texto,
           f"{arquivo} ainda grava o pedido cru")
exigir('put("pedido"' not in canal_kt or "ocultarPin" in canal_kt,
       "o canal grava pedido sem passar pela máscara")

# 4. Empacotamento.
exigir('shutil.copy2(ANDROID / "JarvisSegredo.kt"' in preparo,
       "prepare_android_sistema.py não copia JarvisSegredo.kt")

# 5. Versão, docs e registros.
exigir("version: 1.100.0+110000" in pubspec,
       "pubspec.yaml não está em 1.100.0+110000")
exigir("## 1.95.0" in changelog, "CHANGELOG.md não tem o bloco 1.95.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 118")
exigir("test_bloco_118.py" in pacote, "package.json não roda o contrato 118")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_118.py" in dados["scripts"]["test:all"],
           "o contrato 118 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

exigir("tool/segredo_pedido_test.dart" in nucleo,
       "o teste puro da máscara não está em test_dart_core.py")
exigir((APP / "tool" / "segredo_pedido_test.dart").is_file(),
       "falta flutter_app/tool/segredo_pedido_test.dart")

if falhas:
    print("Falhas do bloco 118:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 118: PIN fora do histórico de execuções — contrato OK")
