#!/usr/bin/env python3
"""Prepara a integração da interface Flutter com o Android.

O runner Android é gerado pelo `flutter create` no CI; este script aplica, de forma
idempotente, o que o app precisa para aparecer no sistema:

- atalhos estáticos do ícone (falar, nova conversa, histórico);
- widget da tela inicial com estado e dois botões;
- recepção de texto compartilhado por outros apps;
- canal `com.jarvis.nova/sistema` no `MainActivity` (compartilhar e atualizar widget).

Uso: python3 tool/prepare_android_sistema.py android/app
"""
from __future__ import annotations

import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ANDROID = RAIZ / "flutter_app" / "android"
PACOTE = "com.jarvis.nova"

ACOES = (
    "com.jarvis.nova.ACAO_VOZ",
    "com.jarvis.nova.ACAO_CONVERSA",
    "com.jarvis.nova.ACAO_HISTORICO",
)

NS = "{http://schemas.android.com/apk/res/android}"

ATALHOS_META = '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />\n'

FILTROS = """            <intent-filter>
                <action android:name="com.jarvis.nova.ACAO_VOZ" />
                <action android:name="com.jarvis.nova.ACAO_CONVERSA" />
                <action android:name="com.jarvis.nova.ACAO_HISTORICO" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>
"""

RECEPTOR = """        <receiver
            android:name=".JarvisWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/jarvis_widget_info" />
        </receiver>
"""


def falhar(mensagem: str) -> None:
    raise SystemExit(f"Integração com o sistema não aplicada: {mensagem}")


def copiar_recursos(app: Path) -> None:
    destino = app / "src" / "main" / "res"
    origem = ANDROID / "sistema" / "res"
    if not origem.is_dir():
        falhar(f"recursos ausentes em {origem}")
    for arquivo in sorted(origem.rglob("*")):
        if not arquivo.is_file():
            continue
        alvo = destino / arquivo.relative_to(origem)
        alvo.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(arquivo, alvo)


def copiar_codigo(app: Path) -> None:
    kotlin = app / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"
    kotlin.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ANDROID / "MainActivity.kt", kotlin / "MainActivity.kt")
    shutil.copy2(ANDROID / "JarvisWidgetProvider.kt", kotlin / "JarvisWidgetProvider.kt")


def ajustar_manifesto(app: Path) -> None:
    manifest_path = app / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.is_file():
        falhar(f"manifesto ausente em {manifest_path}")
    texto = manifest_path.read_text(encoding="utf-8")
    if "</activity>" not in texto:
        falhar("manifesto sem </activity>; o runner não é o esperado")

    if "com.jarvis.nova.ACAO_VOZ" not in texto:
        texto = texto.replace("</activity>", FILTROS + "        </activity>", 1)
    if "android.app.shortcuts" not in texto:
        texto = texto.replace("</activity>", ATALHOS_META + "        </activity>", 1)

    if ".JarvisWidgetProvider" not in texto:
        if "</application>" not in texto:
            falhar("manifesto sem </application>")
        texto = texto.replace("</application>", RECEPTOR + "    </application>", 1)

    try:
        ET.fromstring(texto)
    except ET.ParseError as erro:
        falhar(f"manifesto inválido após a alteração: {erro}")
    manifest_path.write_text(texto, encoding="utf-8")


def verificar(app: Path) -> None:
    manifesto = ET.parse(app / "src" / "main" / "AndroidManifest.xml").getroot()
    atividades = [n for n in manifesto.iter("activity") if n.get(NS + "name") == ".MainActivity"]
    if not atividades:
        falhar("MainActivity não declarada no manifesto")
    atividade = atividades[0]
    acoes_manifesto = {a.get(NS + "name") for a in atividade.iter("action")}
    faltando = [acao for acao in ACOES if acao not in acoes_manifesto]
    if faltando:
        falhar("ações de atalho ausentes no manifesto: " + ", ".join(faltando))
    if "android.intent.action.SEND" not in acoes_manifesto:
        falhar("filtro de compartilhamento (ACTION_SEND) ausente")
    if not any(m.get(NS + "name") == "android.app.shortcuts" for m in atividade.iter("meta-data")):
        falhar("meta-data de atalhos ausente")
    receptores = [n for n in manifesto.iter("receiver") if n.get(NS + "name") == ".JarvisWidgetProvider"]
    if not receptores:
        falhar("receiver do widget ausente")

    atalhos = ET.parse(app / "src" / "main" / "res" / "xml" / "shortcuts.xml").getroot()
    if len(atalhos.findall("shortcut")) != 3:
        falhar("shortcuts.xml precisa declarar três atalhos")
    info = ET.parse(app / "src" / "main" / "res" / "xml" / "jarvis_widget_info.xml").getroot()
    if info.get(NS + "initialLayout") != "@layout/jarvis_widget":
        falhar("widget sem layout inicial")
    if not (app / "src" / "main" / "res" / "layout" / "jarvis_widget.xml").is_file():
        falhar("layout do widget não copiado")

    kotlin = app / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"
    for nome in ("MainActivity.kt", "JarvisWidgetProvider.kt"):
        if not (kotlin / nome).is_file():
            falhar(f"{nome} não copiado")
    texto = (kotlin / "MainActivity.kt").read_text(encoding="utf-8")
    if '"com.jarvis.nova/sistema"' not in texto:
        falhar("MainActivity sem canal do sistema")
    provedor = (kotlin / "JarvisWidgetProvider.kt").read_text(encoding="utf-8")
    if "R.layout.jarvis_widget" not in provedor:
        falhar("widget provider não usa o layout copiado")


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: prepare_android_sistema.py android/app", file=sys.stderr)
        return 2
    app = Path(sys.argv[1]).resolve()
    if not app.is_dir():
        falhar(f"diretório do app inexistente: {app}")
    copiar_recursos(app)
    copiar_codigo(app)
    ajustar_manifesto(app)
    verificar(app)
    print("Integração Android preparada: atalhos, widget, compartilhamento e canal do sistema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
