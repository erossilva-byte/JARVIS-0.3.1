#!/usr/bin/env python3
"""Contrato da atualização OTA (ajuste 092, versão 1.78.0).

O APK de release sai da esteira com um `.sha256` ao lado. Este contrato prende,
sem aparelho e sem rede:

1. a ponte Kotlin existe, escuta o canal próprio e confere o digesto publicado;
2. o APK divergente é apagado, não oferecido para instalar;
3. o instalador só abre pelo FileProvider, com autorização do Android;
4. o preparo do Android copia o Kotlin, a permissão e o caminho do FileProvider;
5. a esteira publica um Release com APK + SHA-256 (artefato de execução expira);
6. a tela nativa existe e explica versão, digesto e limites.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
NS = "{http://schemas.android.com/apk/res/android}"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


ponte = ler(APP / "android" / "JarvisAtualizacao.kt")
atividade = ler(APP / "android" / "MainActivity.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
servico = ler(APP / "lib" / "services" / "atualizacao_service.dart")
tela = ler(APP / "lib" / "services" / "atualizacao_page.dart")
esteira = ler(RAIZ / ".github" / "workflows" / "flutter-release-apk.yml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pubspec = ler(APP / "pubspec.yaml")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_092-atualizacao-ota.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.90.0+19000" in pubspec, "versão não atualizada para 1.78.0")
exigir("1.78.0" in changelog and "atualiza" in changelog.lower(),
       "CHANGELOG sem o bloco 1.78.0 da atualização")
exigir("tests/test_atualizacao_ota.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 092 ausente")

# 2. Ponte Kotlin: canal próprio, evento de progresso e conferência do digesto.
for termo in ("com.jarvis.nova/atualizacao", "com.jarvis.nova/atualizacao/eventos",
              "releases?per_page=10", "MessageDigest.getInstance(\"SHA-256\")",
              "sha256", "não confere com o publicado", "destino.delete()",
              "canRequestPackageInstalls", "getUriForFile",
              "application/vnd.android.package-archive",
              "androidx.core.content.FileProvider"):
    exigir(termo in ponte, f"JarvisAtualizacao.kt sem {termo or 'algo'}")
exigir("installPackage" not in ponte and "Runtime.exec" not in ponte,
       "a ponte tenta instalação silenciosa ou shell")
exigir("arquivo maior que o limite de segurança" in ponte,
       "a ponte não limita o tamanho do download")
exigir('"disponivel" to versaoMaior(versao, atual)' in ponte,
       "a ponte não compara versão para decidir se há atualização")

# 3. Registro no MainActivity, com desligamento no onDestroy.
exigir("JarvisAtualizacao(this)" in atividade,
       "MainActivity não registra o canal de atualização")
exigir("atualizacao?.encerrar()" in atividade,
       "MainActivity não encerra o worker da atualização")

# 4. Preparo do Android: Kotlin, permissão, provider e caminho.
for termo in ("JarvisAtualizacao.kt", "PROVEDOR_ATUALIZACAO",
              ".fileprovider", "@xml/jarvis_arquivos",
              "REQUEST_INSTALL_PACKAGES", "jarvis_arquivos.xml"):
    exigir(termo in preparo, f"prepare_android_sistema.py sem {termo}")

MANIFESTO = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="J.A.R.V.I.S. Nova" android:name="${applicationName}">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"""

GRADLE = """plugins { id("com.android.application") }

android {
    defaultConfig {
        minSdk = flutter.minSdkVersion
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
"""

with tempfile.TemporaryDirectory() as temporario:
    app = Path(temporario) / "android" / "app"
    (app / "src" / "main").mkdir(parents=True)
    (app / "build.gradle.kts").write_text(GRADLE, encoding="utf-8")
    (app / "src" / "main" / "AndroidManifest.xml").write_text(
        MANIFESTO, encoding="utf-8")
    r = subprocess.run(
        [sys.executable, str(APP / "tool" / "prepare_android_sistema.py"), str(app)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    exigir(r.returncode == 0, "preparo do Android falhou: " + (r.stdout + r.stderr))
    if r.returncode == 0:
        root = ET.parse(app / "src" / "main" / "AndroidManifest.xml").getroot()
        provedores = list(root.iter("provider"))
        exigir(bool(provedores), "manifesto preparado sem FileProvider")
        if provedores:
            exigir((provedores[0].get(NS + "authorities") or "").endswith(".fileprovider"),
                   "FileProvider sem autoridade do app")
            exigir(provedores[0].get(NS + "exported") == "false",
                   "FileProvider exportado para outros apps")
            recursos = [m.get(NS + "resource") for m in provedores[0].iter("meta-data")]
            exigir("@xml/jarvis_arquivos" in recursos,
                   "FileProvider sem o caminho privado do APK")
        permissoes = {n.get(NS + "name") for n in root.iter("uses-permission")}
        exigir("android.permission.REQUEST_INSTALL_PACKAGES" in permissoes,
               "manifesto preparado sem permissão de instalar APK")
        caminho = app / "src" / "main" / "res" / "xml" / "jarvis_arquivos.xml"
        exigir(caminho.is_file(), "jarvis_arquivos.xml não copiado")
        if caminho.is_file():
            exigir("<files-path" in caminho.read_text(encoding="utf-8"),
                   "jarvis_arquivos.xml sem files-path")
        kotlin = app / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"
        exigir((kotlin / "JarvisAtualizacao.kt").is_file(),
               "JarvisAtualizacao.kt não copiado para o runner")

# 5. Esteira: Release com APK e SHA-256, nome versionado.
for termo in ("contents: write", "gh release create", "gh release upload",
              "APK_ENTREGA", "sha256sum", "$NOME.sha256",
              'TAG="android-v$VERSAO_APK"'):
    exigir(termo in esteira, f"esteira sem {termo}")
exigir("app-release.apk.sha256" not in esteira,
       "esteira ainda publica só o artefato com nome genérico")

# 6. Dart: serviço, tela e entrada no catálogo.
for termo in ("com.jarvis.nova/atualizacao", "hashSha256Publicado",
              "versaoMaiorQue", "ResultadoDownload", "AtualizacaoIndisponivel"):
    exigir(termo in servico, f"atualizacao_service.dart sem {termo}")
for termo in ("atualizacao-procurar", "atualizacao-baixar",
              "atualizacao-instalar", "atualizacao-sha256",
              "não há instalação silenciosa", "SHA-256 é"):
    exigir(termo in tela, f"atualizacao_page.dart sem {termo}")
catalogo = ler(APP / "lib" / "catalog.dart")
exigir("Atualizações" in catalogo, "módulo Atualizações saiu do catálogo")
paginas = ler(APP / "lib" / "pages.dart")
exigir("AtualizacaoPage" in paginas, "pages.dart não abre a tela de atualização")
inicio = ler(APP / "lib" / "home_screen.dart")
exigir("AtualizacaoPage" in inicio, "home_screen.dart não abre a tela de atualização")

# 7. Sem código Java novo na interface nativa.
try:
    rastreados = subprocess.run(
        ["git", "ls-files", "flutter_app"], cwd=RAIZ,
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
except Exception:  # pragma: no cover - sem git, não bloqueia
    rastreados = []
exigir(not [f for f in rastreados if f.endswith(".java")],
       "arquivo .java novo na interface Flutter")

# 8. Inventário registra o recurso.
exigir("Atualização pelo release" in inventario,
       "INVENTARIO_DE_FUNCOES.md sem a seção da atualização")

if falhas:
    print("FALHAS no contrato da atualização OTA:")
    for falha in falhas:
        print(f" - {falha}")
    raise SystemExit(1)

print("Contrato da atualização OTA: OK")
print("- ponte Kotlin confere o SHA-256 publicado e descarta divergência")
print("- preparo do Android copia Kotlin, permissão e FileProvider")
print("- esteira publica Release com APK + .sha256 versionado")
print("- tela nativa e testes cobrem versão, download e instalador")
