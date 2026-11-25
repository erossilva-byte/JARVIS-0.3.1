#!/usr/bin/env python3
"""Contrato do bloco 130 — Etapa 6 do PC: voz e segundo plano.

O roteiro pedia palavra de ativação local, escuta sem a janela em foco, fala com
a mesma voz do celular e paridade de ações com a tabela do bloco 122, e exigia
um teste de paridade adaptado ao PC e a medição de CPU com a escuta ligada.

Este contrato prende:

1. a tabela de ações do PC, com cada linha apontando para o caminho real no
   código — e as ações do celular continuando fora do PC;
2. a regra de quando ouvir, que permite a janela atrás e proíbe ouvir a própria
   voz, a tela de bloqueio e o modo de visita;
3. o motor de escuta escolhido com honestidade (local, nuvem ou nada);
4. a voz do PC com a mesma prosódia do celular e aviso quando a voz salva não
   existe no computador;
5. a medição de CPU feita pelo laço real, com a metodologia declarada;
6. versão, CHANGELOG, relatório, roteiro e suíte acompanhando.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
falhas: list[str] = []


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


# 1. Regras do módulo.
voz = ler(RAIZ / "voz_pc.js")
for trecho in [
    "var ONDE = {",
    "PC_TELA: 'pc-tela'",
    "CELULAR: 'celular'",
    "var TABELA = [",
    "function podeOuvir(",
    "function motorDeEscuta(",
    "function vozParaPC(",
    "function medirCpu(",
    "function mensagemAcao(",
    "var PERFIS = {",
    "raiz.VozPc = api",
]:
    exigir(trecho in voz, f"voz_pc.js perdeu: {trecho}")
exigir("só de leitura" in voz,
       "a mensagem das ações do celular deixou de dizer que o pareamento é só leitura")
exigir("sem captura de áudio" in voz,
       "a medição de CPU deixou de declarar o que não mede")

# 2. A tabela aponta para caminhos reais.
app = ler(RAIZ / "app.js")
main = ler(RAIZ / "platforms" / "desktop" / "main.js")
linhas = re.findall(r"\{ acao: '([^']+)', onde: ONDE\.(\w+), (marcador|chave): '([^']+)' \}", voz)
exigir(len(linhas) >= 20, f"a tabela encolheu: {len(linhas)} linhas lidas")
por_onde: dict[str, list[str]] = {}
for acao, onde, tipo, valor in linhas:
    por_onde.setdefault(onde, []).append(acao)
    if tipo == "marcador":
        exigir(valor in app or valor in main,
               f"{acao}: marcador ausente no código: {valor}")
    else:
        padrao = re.compile(re.escape(valor) + r": \{ risco: \d+, disp: \['android'\]")
        exigir(bool(padrao.search(app)),
               f"{acao}: deixou de ser só do Android no app.js")
for categoria in ("PC", "PC_TELA", "CELULAR", "SEM_VOZ"):
    exigir(por_onde.get(categoria), f"a tabela não tem nenhuma ação em {categoria}")

# 3. Ligação no aplicativo.
for trecho in [
    "const VOZ_PC = window.VozPc || null",
    "VOZ_PC.podeOuvir({",
    "VOZ_PC.motorDeEscuta({",
    "VOZ_PC.mensagemAcao(VOZ_PC.ONDE.CELULAR)",
    "VOZ_PC.vozParaPC(vs",
    "escuta_fora_de_foco",
]:
    exigir(trecho in app, f"app.js perdeu: {trecho}")
exigir("decisao ? !decisao.ouvindo : (ocupado || document.hidden || paradaAtiva)" in app,
       "o laço de escuta deixou de usar a regra de voz_pc.js (o antigo "
       "'document.hidden' voltou a decidir sozinho)")

# 4. A voz do PC fala com a prosódia do celular.
perfis_app = {}
for chave, pitch, rate in re.findall(
        r"(padrao|filme|jarvis|ultra): \{ nome: '[^']*', pitch: '([\d.]+)', rate: '([\d.]+)' \}", app):
    perfis_app[chave] = (float(pitch), float(rate))
exigir(len(perfis_app) == 4, f"não li os quatro perfis de voz do app: {sorted(perfis_app)}")
for chave, pitch, rate in re.findall(
        r"(padrao|filme|jarvis|ultra): \{ nome: '[^']*', pitch: ([\d.]+), rate: ([\d.]+) \}", voz):
    esperado = perfis_app.get(chave)
    exigir(esperado == (float(pitch), float(rate)),
           f"perfil {chave} divergiu entre app.js {esperado} e voz_pc.js {(pitch, rate)}")

# 5. Tela e ajuste.
html = ler(RAIZ / "index.html")
exigir('src="voz_pc.js"' in html, "index.html não carrega voz_pc.js")
exigir(html.index('src="voz_pc.js"') < html.index('src="app.js"'),
       "voz_pc.js precisa carregar antes de app.js")
for ident in ["c-linha-fora-foco", "c-escuta-fora-foco"]:
    exigir(f'id="{ident}"' in html, f"index.html não tem #{ident}")

# 6. Teste e medição.
teste = ler(RAIZ / "tests" / "test_voz_pc.js")
for trecho in ["podeOuvir", "motorDeEscuta", "vozParaPC", "medirCpu", "TABELA"]:
    exigir(trecho in teste, f"test_voz_pc.js perdeu: {trecho}")
medida = ler(RAIZ / "tools" / "medir_cpu_escuta.js")
for trecho in ["V.medirCpu(", "CPU do processo", "por minuto de áudio",
               "EscutaVoz.criarDetector", "Hermes.ativacao.presente"]:
    exigir(trecho in medida, f"tools/medir_cpu_escuta.js perdeu: {trecho}")

# 7. Versão, changelog, relatório, roteiro e suíte.
pubspec = ler(RAIZ / "flutter_app" / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-25_130-voz-e-segundo-plano-pc.md"
exigir("version: 1.108.0+110800" in pubspec, "pubspec.yaml não está em 1.108.0+110800")
exigir("## 1.107.0" in changelog, "CHANGELOG.md sem o bloco 1.107.0")
exigir("Estado:** entregue na 1.107.0" in roteiro,
       "o roteiro não registrou a Etapa 6 como entregue")
exigir(relatorio.is_file(), "falta o relatório da Etapa 6")
try:
    dados = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    scripts = dados["scripts"]["test:all"]
    for trecho in ["node tests/test_voz_pc.js", "python3 tests/test_bloco_130.py"]:
        exigir(trecho in scripts, f"test:all não roda: {trecho}")
    exigir("voz_pc.js" in dados["build"]["files"], "o pacote Windows não inclui voz_pc.js")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 130:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 130: tabela de voz do PC, escuta em segundo plano, voz e CPU — contrato OK")
