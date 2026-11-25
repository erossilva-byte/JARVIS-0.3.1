#!/usr/bin/env python3
"""Contrato do bloco 126 — asserts ligados no núcleo e triagem presa em teste.

O executor `tests/test_dart_core.py` chamava `dart run` sem `--enable-asserts`.
Os testes puros são feitos de `assert`, e sem a flag o Dart roda com os asserts
desligados: o arquivo compilava, nada era verificado e o passo dizia “OK”. O
primeiro item deste contrato impede o silêncio de voltar.

O resto prende a triagem: todo `tool/*_test.dart` do repositório precisa estar
no executor (um teste esquecido é um teste que não roda) e os defeitos reais
corrigidos não podem regredir sem que o teste puro acuse.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
RUNNER = RAIZ / "tests" / "test_dart_core.py"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


# 1. A flag que faz os asserts valerem.
runner = ler(RUNNER)
exigir('[dart, "run", "--enable-asserts", caminho]' in runner,
       "test_dart_core.py não liga --enable-asserts")
exigir('[dart, "run", caminho]' not in runner,
       "test_dart_core.py ainda tem uma chamada sem --enable-asserts")

# 2. Todo teste puro do diretório está registrado no executor.
arquivos = sorted(p.name for p in (APP / "tool").glob("*_test.dart"))
registrados = set(
    linha.split("tool/", 1)[1].split('"', 1)[0]
    for linha in runner.splitlines()
    if "tool/" in linha and "_test.dart" in linha
)
for arquivo in arquivos:
    exigir(arquivo in registrados,
           f"{arquivo} não está no executor dos testes puros")
for registrado in sorted(registrados):
    exigir(registrado in arquivos,
           f"o executor cita {registrado}, que não existe mais")

# 3. Os defeitos reais da triagem continuam corrigidos na origem.
ativacao = ler(APP / "lib" / "core" / "ativacao_sensibilidade.dart")
exigir("${rotulo(valor)}" in ativacao,
       "o resumo da sensibilidade voltou a interpolar a função rotulo")

aparelho = ler(APP / "lib" / "core" / "aparelho.dart")
exigir("lanterna|volume|alarme" in aparelho,
       "a guarda de ligação perdeu volume/lanterna/alarme")
exigir("startsWith('como ')" in aparelho,
       "pergunta com “como” voltou a discar")

especialidades = ler(APP / "lib" / "core" / "especialidades.dart")
exigir("bitola" in especialidades, "CADeSIMU deixou de reconhecer bitola/cabo")
exigir("null (?:pointer|check operator)" in especialidades,
       "programação deixou de reconhecer null check operator")

comandos = ler(APP / "lib" / "core" / "comandos_android.dart")
exigir(r"[?!.]+$" in comandos,
       "a limpeza de comando não tira a pontuação final")

busca = ler(APP / "lib" / "core" / "memoria_busca.dart")
exigir("similaridade < 0.35" in busca,
       "o corte de similaridade da memória voltou a aceitar ruído")

sync = ler(APP / "lib" / "core" / "memoria_sync.dart")
exigir("porCaminhoMinusculo" in sync,
       "a sincronização voltou a diferenciar Motor.md de motor.md")

palco = ler(APP / "lib" / "core" / "palco.dart")
exigir("_dataDoRss" in palco, "notícia do RSS voltou a ficar sem data")

pedido_app = ler(APP / "lib" / "core" / "pedido_app.dart")
exigir("melhorInicio" in pedido_app,
       "a escolha do app deixou de considerar a primeira citação")
exigir("e-mail|email|e|" in pedido_app,
       "o conector e-mail voltou a ser comido pela conjunção “e”")

ficha = ler(APP / "lib" / "core" / "pedido_ficha.dart")
exigir("(?:pra|para) la" in ficha, "“deixa pra lá” deixou de cancelar a ficha")

pessoas = ler(APP / "lib" / "core" / "pessoas.dart")
exigir("primeiros" in pessoas,
       "primeiro nome dito sozinho voltou a escolher uma ficha em silêncio")

contato = ler(APP / "lib" / "core" / "nome_contato.dart")
exigir("exatos" in contato,
       "nome dito inteiro voltou a perder para o prefixo mais curto")

# 4. Versão, registros e execução.
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-25_126-asserts-e-triagem.md"
exigir("version: 1.107.0+110700" in pubspec,
       "pubspec.yaml não está em 1.107.0+110700")
exigir("## 1.103.0" in changelog, "CHANGELOG.md não tem o bloco 1.103.0")
exigir(relatorio.is_file(), "falta o relatório da triagem")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_126.py" in dados["scripts"]["test:all"],
           "o contrato 126 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 126:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 126: asserts ligados e triagem dos testes puros — contrato OK")
