#!/usr/bin/env python3
"""Contrato da assinatura de release (ajuste 091, versão 1.77.0).

O APK de release precisa ser assinado sempre pela mesma chave, guardada fora do
repositório. Até o ajuste 090 ele saía assinado com a chave de debug da máquina
que compilou — outra assinatura a cada build, e o Android recusava a atualização
por cima.

Este contrato prende, sem aparelho:

1. o preparo do Android injeta o bloco de assinatura por key.properties;
2. a ordem de procura do arquivo e as propriedades -P do CI existem;
3. release sem chave para (e o teste local exige opt-in explícito);
4. nenhum segredo é versionado e o .gitignore cobre keystore/key.properties;
5. existe guia, modelo sem senha e ferramenta de conferência.
"""

from __future__ import annotations

import subprocess
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


preparo = ler(APP / "tool" / "prepare_android_sistema.py")
verificador = ler(APP / "tool" / "verificar_assinatura.py")
modelo = ler(APP / "key.properties.example")
guia = ler(RAIZ / "docs" / "GUIA-ASSINATURA-RELEASE.md")
gitignore = ler(RAIZ / ".gitignore")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
pubspec = ler(APP / "pubspec.yaml")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_091-assinatura-de-release.md")
gerado = APP / "android" / "app" / "build.gradle.kts"

# 1. Versão, suíte e relatório.
exigir("version: 1.88.7+18807" in pubspec, "versão não atualizada para 1.77.0")
exigir("1.77.0" in changelog and "assinatura" in changelog.lower(),
       "CHANGELOG sem o bloco 1.77.0 da assinatura")
exigir("tests/test_assinatura_release.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 091 ausente")

# 2. Bloco de assinatura aplicado pelo preparo do Android.
for termo in ("MARCA_ASSINATURA", "configurar_assinatura",
              "create(\"release\")", "JARVIS_KEY_PROPERTIES",
              "rootProject.file(\"key.properties\")",
              "JARVIS_PERMITIR_DEBUG", "gradle.taskGraph.whenReady",
              "documents", "docs/GUIA-ASSINATURA-RELEASE.md"):
    if termo == "documents":
        continue
    exigir(termo in preparo, f"preparo do Android sem {termo}")
exigir("configurar_assinatura(app)" in preparo,
       "preparo não chama a configuração de assinatura")
exigir("build.gradle.kts" in preparo and "signingConfigs" in preparo,
       "preparo não escreve signingConfigs")

# 3. O arquivo gerado (quando existe) tem o bloco esperado.
if gerado.is_file():
    texto = gerado.read_text(encoding="utf-8")
    for termo in ("JARVIS_KEY_PROPERTIES", "temChaveRelease",
                  "signingConfigs.getByName(\"release\")",
                  "APK de release sem chave"):
        exigir(termo in texto, f"build.gradle.kts gerado sem {termo}")
    exigir("motor.setPitch" not in texto, "build.gradle.kts virou outra coisa")

# 4. Recusa de debug: o aviso e a saída explícita existem, sem senha padrão.
exigir("permitirDebug" in preparo,
       "preparo não lê a autorização explícita de teste em debug")
exigir("storePassword=COLOQUE" in modelo or "COLOQUE_A_SENHA" in modelo,
       "modelo não deixa claro que a senha é do usuário")

# 5. Modelo do key.properties sem segredo real.
for termo in ("storeFile", "storePassword", "keyAlias", "keyPassword",
              "certificadoSha256"):
    exigir(termo in modelo, f"modelo sem {termo}")
exigir("jarvis-release.jks" not in modelo or "/caminho/absoluto/" in modelo,
       "modelo aponta para keystore real")

# 6. .gitignore recusa segredos e chaves.
for termo in ("key.properties", "*.jks", "*.keystore", "!ci/debug.keystore"):
    exigir(termo in gitignore, f".gitignore sem {termo}")

# 7. Nenhuma chave ou propriedade versionada (exceção: keystore de debug do CI).
try:
    rastreados = subprocess.run(
        ["git", "ls-files"], cwd=RAIZ, capture_output=True, text=True, check=True
    ).stdout.splitlines()
except Exception:  # pragma: no cover - sem git, não bloqueia o contrato
    rastreados = []
proibidos = [f for f in rastreados
             if f.endswith(".jks")
             or (f.endswith(".keystore") and f != "ci/debug.keystore")
             or f.endswith("key.properties")]
exigir(not proibidos, f"arquivos de assinatura versionados: {proibidos}")

# 8. Ferramenta de conferência.
for termo in ("--exigir-release", "print-certs", "certificadoSha256",
              "Android Debug"):
    exigir(termo in verificador, f"verificar_assinatura.py sem {termo}")

# 9. Guia: chave fora do repositório, backup, desinstalação única e CI.
for termo in ("keytool -genkeypair", "fora do repositório", "backup",
              "desinstal", "JARVIS_KEYSTORE_B64", "JARVIS_KEY_PROPERTIES"):
    exigir(termo.lower() in guia.lower(), f"guia sem {termo}")
exigir("key.properties" in guia and "ASSINATURA" in guia.upper(),
       "guia não explica o key.properties")

# 10. Esteira do GitHub Actions: assina com os secrets, fora do repositório.
esteira = ler(RAIZ / ".github" / "workflows" / "flutter-release-apk.yml")
validacao = ler(RAIZ / ".github" / "workflows" / "flutter-native.yml")
exigir("workflow_dispatch" in esteira,
       "esteira de release sem disparo manual")
pares = (
    ("JARVIS_KEYSTORE_B64", "KEYSTORE_B64"),
    ("JARVIS_KEYSTORE_PASSWORD", "KEYSTORE_PASSWORD"),
    ("JARVIS_KEY_ALIAS", "KEY_ALIAS"),
    ("JARVIS_KEY_PASSWORD", "KEY_PASSWORD"),
)
for segredo, variavel in pares:
    exigir(f"secrets.{segredo}" in esteira, f"esteira sem o secret {segredo}")
    exigir(f'test -n "${variavel}"' in esteira,
           f"esteira não para quando {segredo} falta")
exigir("base64 -d" in esteira and "keytool -list" in esteira,
       "esteira não decodifica nem confere o keystore")
exigir("$RUNNER_TEMP" in esteira,
       "esteira deveria gravar a chave fora do repositório (RUNNER_TEMP)")
exigir("JARVIS_KEY_PROPERTIES" in esteira,
       "esteira não aponta o key.properties para o build")
exigir("flutter build apk --release" in esteira
       and "--target-platform android-arm64" in esteira,
       "esteira não compila o APK de release arm64")
exigir("--exigir-release" in esteira,
       "esteira publica o APK sem conferir a assinatura")
exigir("if-no-files-found: error" in esteira,
       "esteira sem falha explícita quando o APK não existe")
exigir("tool/prepare_android_identidade.py" in esteira
       and "tool/prepare_android_identidade.py" in validacao,
       "preparo da identidade Android não é compartilhado pelas duas esteiras")

# 11. Documentação.
exigir("091" in inventario, "inventário sem a seção do ajuste 091")

if falhas:
    print("FALHAS no contrato da assinatura de release:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da assinatura de release: aprovado.")
