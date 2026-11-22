"""Contrato do bloco 102 — a esteira do CI passa a ser a do Flutter.

O que este teste prende:

- `.github/workflows/flutter-ci.yml` existe, dispara em push e pull request para
  a `main`, instala o Flutter e roda pub get, `flutter analyze`, `flutter test`
  e os contratos Python;
- `build-apk.yml` e `ci-android-auditoria.yml` não disparam mais sozinhos: sem
  `push:` nem `pull_request:` no gatilho, só execução manual;
- nenhum workflow repete o grupo de concorrência de outro — era isso que fazia
  uma esteira cancelar a outra na fila;
- o runner dos contratos lê a lista do `package.json`, em vez de ter lista própria.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
WORKFLOWS = RAIZ / ".github" / "workflows"
NOVO = WORKFLOWS / "flutter-ci.yml"
ANTIGOS = [WORKFLOWS / "build-apk.yml", WORKFLOWS / "ci-android-auditoria.yml"]
RUNNER = RAIZ / "ci" / "contratos_python.py"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    exigir(caminho.exists(), f"arquivo ausente: {caminho.relative_to(RAIZ)}")
    return caminho.read_text(encoding="utf-8") if caminho.exists() else ""


def gatilho(texto: str) -> str:
    """Trecho entre `on:` e a próxima seção de primeiro nível."""
    linhas = texto.splitlines()
    inicio = next((i for i, linha in enumerate(linhas) if linha.strip() == "on:"), None)
    if inicio is None:
        return ""
    fim = len(linhas)
    for i in range(inicio + 1, len(linhas)):
        linha = linhas[i]
        if linha and not linha.startswith((" ", "#")):
            fim = i
            break
    return "\n".join(linhas[inicio:fim])


def grupo(texto: str) -> str:
    achado = re.search(r"^\s*group:\s*(.+)$", texto, re.MULTILINE)
    return achado.group(1).strip() if achado else ""


# --------------------------------------------------------------------------
# 1. A esteira nova
# --------------------------------------------------------------------------
novo = ler(NOVO)
gatilho_novo = gatilho(novo)
exigir("push:" in gatilho_novo, "flutter-ci.yml não dispara em push")
exigir("pull_request:" in gatilho_novo, "flutter-ci.yml não dispara em pull request")
exigir("branches: [main]" in gatilho_novo, "flutter-ci.yml não aponta para a main")
exigir("subosito/flutter-action" in novo, "flutter-ci.yml não instala o Flutter")
exigir("channel: stable" in novo, "flutter-ci.yml não usa o canal estável do Flutter")
exigir("run: flutter pub get" in novo, "flutter-ci.yml não instala as dependências do app")
exigir("run: flutter analyze" in novo, "flutter-ci.yml não roda flutter analyze")
exigir("run: flutter test" in novo, "flutter-ci.yml não roda flutter test")
exigir("run: python3 ci/contratos_python.py" in novo, "flutter-ci.yml não roda os contratos Python")
exigir("working-directory: flutter_app" in novo, "flutter-ci.yml não entra em flutter_app")
exigir(grupo(novo).startswith("flutter-ci-"), "grupo de concorrência do flutter-ci.yml fora do padrão")

# A ordem importa: dependências, análise, testes, contratos.
ordem = [
    novo.find("run: flutter pub get"),
    novo.find("run: flutter analyze"),
    novo.find("run: flutter test"),
    novo.find("run: python3 ci/contratos_python.py"),
]
exigir(all(posicao >= 0 for posicao in ordem), "etapa obrigatória ausente no flutter-ci.yml")
exigir(ordem == sorted(ordem), "etapas do flutter-ci.yml fora de ordem (pub get → analyze → test → contratos)")

# O teste do hotword em português lê android/app/src/main/assets/kws/tokens.txt.
# A pasta android/ é ignorada no git e o modelo é baixado: sem preparar os dois
# antes, `flutter test` falha no CI (foi o que aconteceu no primeiro run).
gerar_android = novo.find("flutter create --project-name jarvis_nova --platforms=android")
preparar_modelo = novo.find("../preparar_kws.py android/app")
testes = novo.find("run: flutter test")
exigir(gerar_android >= 0, "flutter-ci.yml não gera a pasta android/ antes dos testes")
exigir(preparar_modelo >= 0, "flutter-ci.yml não prepara o modelo de ativação antes dos testes")
exigir(
    0 <= gerar_android < preparar_modelo < testes,
    "geração da pasta android/ e do modelo fora de ordem (precisa vir antes de flutter test)",
)

# Os contratos Python leem o que a preparação do sistema grava no projeto Android.
preparar_sistema = novo.find("tool/prepare_android_sistema.py android/app")
exigir(preparar_sistema >= 0, "flutter-ci.yml não prepara a integração com o sistema Android")
exigir(0 <= preparar_sistema < testes, "preparação do sistema Android depois de flutter test")

# Fontes Kotlin nativos vivem em flutter_app/android/ (pasta ignorada no git):
# sem eles versionados, os contratos do segundo plano e dos sensores não têm o
# que ler no CI — foi o que faltou no segundo run.
nativos = sorted((RAIZ / "flutter_app" / "android").glob("*.kt"))
exigir(len(nativos) >= 19, f"fontes Kotlin nativos faltando em flutter_app/android (achei {len(nativos)})")
for obrigatorio in ("JarvisComandos.kt", "JarvisSensores.kt", "JarvisFundo.kt", "JarvisVoz.kt",
                    "JarvisTimbre.kt", "JarvisAgenda.kt"):
    exigir((RAIZ / "flutter_app" / "android" / obrigatorio).is_file(), f"{obrigatorio} ausente em flutter_app/android")

rastreados = subprocess.run(
    ["git", "ls-files", "flutter_app/android"], cwd=RAIZ, capture_output=True, text=True
).stdout.splitlines()
exigir(
    sum(1 for linha in rastreados if linha.endswith(".kt")) >= 19,
    "os fontes Kotlin nativos de flutter_app/android/ não estão versionados (git add -f)",
)

# --------------------------------------------------------------------------
# 2. As esteiras antigas aposentadas
# --------------------------------------------------------------------------
for antigo in ANTIGOS:
    texto = ler(antigo)
    gatilho_antigo = gatilho(texto)
    nome = antigo.name
    exigir("workflow_dispatch:" in gatilho_antigo, f"{nome} perdeu a execução manual")
    exigir("push:" not in gatilho_antigo, f"{nome} ainda dispara em push")
    exigir("pull_request:" not in gatilho_antigo, f"{nome} ainda dispara em pull request")
    exigir("cap add android" in texto, f"{nome} deixou de ser a esteira antiga do Capacitor")

# --------------------------------------------------------------------------
# 3. Nenhum grupo de concorrência repetido
# --------------------------------------------------------------------------
grupos: dict[str, list[str]] = {}
for arquivo in sorted(WORKFLOWS.glob("*.yml")):
    nome_grupo = grupo(arquivo.read_text(encoding="utf-8"))
    if nome_grupo:
        grupos.setdefault(nome_grupo, []).append(arquivo.name)
repetidos = {chave: nomes for chave, nomes in grupos.items() if len(nomes) > 1}
exigir(
    not repetidos,
    "grupo de concorrência compartilhado (um cancela o outro): "
    + "; ".join(f"{chave} → {', '.join(nomes)}" for chave, nomes in repetidos.items()),
)

# --------------------------------------------------------------------------
# 4. O runner dos contratos lê a lista do package.json
# --------------------------------------------------------------------------
runner = ler(RUNNER)
exigir("package.json" in runner, "ci/contratos_python.py não lê a lista do package.json")
exigir("test:all" in runner, "ci/contratos_python.py não usa o test:all")

pacote = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
suite = pacote.get("scripts", {}).get("test:all", "")
exigir("python3 tests/test_ci_flutter.py" in suite, "test:all não roda este contrato")

esperados = [pedaco.strip() for pedaco in suite.split("&&") if pedaco.strip().startswith("python3 ")]
saida = subprocess.run(
    [sys.executable, str(RUNNER), "--lista"],
    cwd=RAIZ,
    capture_output=True,
    text=True,
)
exigir(saida.returncode == 0, f"ci/contratos_python.py --lista falhou: {saida.stderr.strip()}")
listados = [linha.strip() for linha in saida.stdout.splitlines() if linha.strip()]
exigir(listados == esperados, "ci/contratos_python.py não lista os mesmos comandos do test:all")
exigir("python3 tests/test_dart_core.py" in listados, "lista dos contratos sem o teste do núcleo Dart")
exigir("python3 ci/preflight_android.py" in listados, "lista dos contratos sem a pré-checagem Android")

# --------------------------------------------------------------------------
# 5. Resultado
# --------------------------------------------------------------------------
if falhas:
    print("Contrato do CI Flutter: problemas encontrados.\n")
    for falha in falhas:
        print(f" - {falha}")
    raise SystemExit(1)

print(f"CI Flutter: {len(grupos)} grupos de concorrência distintos, {len(listados)} contratos Python na lista.")
print("OK: esteira Flutter ativa, antigas em modo manual e ninguém cancelando ninguém.")
