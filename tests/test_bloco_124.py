#!/usr/bin/env python3
"""Contrato do bloco 124 — roteiro do PC e status unificado.

Primeira etapa da produção do JARVIS para PC: um modelo de status que serve ao
celular e ao PC, e o roteiro por etapas. O contrato prende:

1. o roteiro existe, tem as sete etapas e declara os limites;
2. o modelo lê os campos que o PC realmente entrega (`status_pc`) e os do
   celular, sem inventar número quando o campo falta;
3. o teste puro cobre os dois formatos e o estado vazio;
4. nada do app do PC foi quebrado: `status_pc` continua no Electron com os
   mesmos campos;
5. versão, CHANGELOG, relatório e registros acompanham.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


modelo = ler(APP / "lib" / "core" / "status_plataforma.dart")
teste = ler(APP / "tool" / "status_plataforma_test.dart")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
desktop = ler(RAIZ / "platforms" / "desktop" / "main.js")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_124-pc-roteiro-e-status.md")

# 1. O roteiro.
for etapa in range(1, 8):
    exigir(f"## Etapa {etapa} —" in roteiro,
           f"o roteiro não tem a Etapa {etapa}")
for trecho in [
    "Status do PC",
    "Status do celular",
    "**Aceite**",
    "O que fica declarado como não feito",
]:
    exigir(trecho in roteiro, f"o roteiro não fala de: {trecho}")
exigir("sem conexão" in roteiro,
       "o roteiro não declara o estado honesto de celular sem pareamento")

# 2. O modelo cobre os dois formatos.
for campo in ["cpu", "ramTotal", "ramLivre", "discoTotal", "discoLivre",
              "uptime", "bateria", "temperatura", "conexao", "uptimeMin"]:
    exigir(f"'{campo}'" in modelo,
           f"o modelo não lê o campo {campo}")
for trecho in ["enum OrigemStatus", "class StatusPlataforma", "semDados",
               "String get titulo", "List<LinhaStatus> get linhas"]:
    exigir(trecho in modelo, f"o modelo não tem: {trecho}")
exigir("'Status do PC'" in modelo and "'Status do celular'" in modelo,
       "os títulos das duas plataformas não estão no modelo")

# 3. O teste puro prova os dois formatos e a honestidade.
for trecho in ["OrigemStatus.pc", "OrigemStatus.celular", "semDados",
               "Status do PC", "Status do celular", "linha inventada",
               "inventar"]:
    exigir(trecho in teste, f"o teste do modelo não cobre: {trecho}")

# 4. O PC não foi quebrado: os campos que o modelo lê existem no Electron.
exigir("status_pc: async ()" in desktop,
       "o Electron deixou de ter status_pc")
for campo in ["cpu:", "ramLivre:", "ramTotal:", "discoLivre:", "discoTotal:",
              "aparelho:", "uptime:"]:
    exigir(campo in desktop, f"status_pc não entrega mais {campo}")
exigir("os.cpus()" in desktop, "status_pc deixou de medir a CPU de verdade")

# 5. Versão, docs e registros.
exigir("version: 1.104.0+110400" in pubspec,
       "pubspec.yaml não está em 1.104.0+110400")
exigir("## 1.101.0" in changelog, "CHANGELOG.md não tem o bloco 1.101.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 124")
exigir("test_bloco_124.py" in pacote, "package.json não roda o contrato 124")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_124.py" in dados["scripts"]["test:all"],
           "o contrato 124 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")
exigir("tool/status_plataforma_test.dart" in nucleo,
       "o teste do status não está em test_dart_core.py")

if falhas:
    print("Falhas do bloco 124:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 124: roteiro do PC e status unificado — contrato OK")
