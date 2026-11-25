#!/usr/bin/env python3
"""Contrato do bloco 125 — Etapa 2: painel do PC com os dois status.

O roteiro do PC (Etapa 2) pede duas seções no painel: “Status do PC” e “Status
do celular”, com “sem conexão” no lado do celular até o pareamento existir, e
uma única regra de formatação para os dois lados. Este contrato prende:

1. as duas seções existem no HTML, com os contêineres que o app preenche;
2. a regra compartilhada do PC (`status_plataforma.js`) é carregada antes do
   app e espelha o modelo Dart;
3. o app consulta `status_pc` de verdade e não inventa número;
4. o lado do celular diz “sem conexão” quando não há pareamento;
5. o teste de DOM que prova o estado vazio está registrado;
6. versão, CHANGELOG, relatório e registros acompanham.
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


html = ler(RAIZ / "index.html")
modelo_js = ler(RAIZ / "status_plataforma.js")
modelo_dart = ler(APP / "lib" / "core" / "status_plataforma.dart")
app = ler(RAIZ / "app.js")
teste = ler(RAIZ / "tests" / "test_status_pc_painel.js")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_125-painel-status-pc.md")

# 1. As duas seções no HTML.
for trecho in ["<h3>Status do PC</h3>", "<h3>Status do celular</h3>",
               'id="sp-linhas"', 'id="sp-alerta"', 'id="sc-pareamento"']:
    exigir(trecho in html, f"o painel não tem: {trecho}")
exigir("Sem conexão" in html,
       "o celular não nasce com o aviso de sem conexão")

# 2. A regra compartilhada, carregada antes do app.
posicao_regra = html.find('src="status_plataforma.js"')
posicao_app = html.find('src="app.js"')
exigir(0 <= posicao_regra < posicao_app,
       "status_plataforma.js precisa ser carregado antes de app.js")
for trecho in ["deMapa", "semDados", "titulo", "linhas", "Memória", "Disco",
               "Ligado há", "Bateria", "Temperatura"]:
    exigir(trecho in modelo_js, f"a regra do PC não formata: {trecho}")
    exigir(trecho in modelo_dart, f"o modelo Dart não formata: {trecho}")
exigir("no total" in modelo_js and "no total" in modelo_dart,
       "memória só com total não está tratada nos dois lados")

# 3. O app consulta o PC de verdade.
for trecho in ["function atualizarStatusPc", "function renderStatusPlataforma",
               "nativo('status_pc'", "StatusPlataforma.deMapa(r, 'pc')"]:
    exigir(trecho in app, f"o app não tem: {trecho}")
trecho_celular = app[app.find("async function atualizarStatusCelular"):
                     app.find("function mostrarWakeMini")]
exigir("atualizarStatusPc();" in trecho_celular,
       "atualizar o status do celular não atualiza o do PC")
exigir("set('sc-pareamento', 'Sem conexão" in trecho_celular,
       "o lado do celular não diz sem conexão quando não há pareamento")
exigir("Sem conexão: nada foi lido deste lado." in app,
       "o estado vazio não tem frase própria")

# 4. O teste de DOM cobre o estado vazio e a formatação.
for trecho in ["sp-linhas", "sc-pareamento", "Sem conexão",
               "renderStatusPlataforma", "STD"]:
    if trecho == "STD":
        continue
    exigir(trecho in teste, f"o teste do painel não cobre: {trecho}")
exigir("semDados" in teste, "o teste não cobre o mapa sem dados")
exigir("node tests/test_status_pc_painel.js" in pacote,
       "package.json não roda o teste do painel")
try:
    dados = json.loads(pacote)
    exigir("node tests/test_status_pc_painel.js" in dados["scripts"]["test:all"],
           "o teste do painel não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

# 5. O roteiro reflete a entrega.
exigir("Etapa 2" in roteiro, "o roteiro perdeu a Etapa 2")
exigir("sem conexão" in roteiro,
       "o roteiro não declara o estado sem conexão do celular")

# 6. Versão, docs e registros.
exigir("version: 1.109.0+110900" in pubspec,
       "pubspec.yaml não está em 1.109.0+110900")
exigir("## 1.102.0" in changelog, "CHANGELOG.md não tem o bloco 1.102.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 125")
exigir("test_bloco_125.py" in pacote, "package.json não roda o contrato 125")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_125.py" in dados["scripts"]["test:all"],
           "o contrato 125 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 125:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 125: painel com status do PC e do celular — contrato OK")
