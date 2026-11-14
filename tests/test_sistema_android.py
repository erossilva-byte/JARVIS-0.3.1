"""Testa a preparação da integração Android (atalhos, widget, compartilhar, canal).

Cada caso monta um runner falso, roda o script de preparação e confere o manifesto e os
recursos resultantes. É a verificação possível sem Android SDK: aqui não se compila Kotlin.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SCRIPT = RAIZ / "flutter_app" / "tool" / "prepare_android_sistema.py"
NS = "{http://schemas.android.com/apk/res/android}"

MANIFESTO = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="J.A.R.V.I.S. Nova" android:name="${applicationName}">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
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
}
"""


def runner(base: Path) -> Path:
    app = base / "android" / "app"
    (app / "src" / "main").mkdir(parents=True)
    (app / "build.gradle.kts").write_text(GRADLE, encoding="utf-8")
    (app / "src" / "main" / "AndroidManifest.xml").write_text(MANIFESTO, encoding="utf-8")
    return app


def rodar(app: Path):
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(app)],
        cwd=RAIZ,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def manifesto(app: Path):
    return ET.parse(app / "src" / "main" / "AndroidManifest.xml").getroot()


def caso_atalhos_widget_e_compartilhamento(tmp: Path) -> None:
    app = runner(tmp)
    r = rodar(app)
    assert r.returncode == 0, r.stdout + r.stderr

    raiz = manifesto(app)
    atividade = next(n for n in raiz.iter("activity") if n.get(NS + "name") == ".MainActivity")
    acoes = {a.get(NS + "name") for a in atividade.iter("action")}
    assert {
        "com.jarvis.nova.ACAO_VOZ",
        "com.jarvis.nova.ACAO_CONVERSA",
        "com.jarvis.nova.ACAO_HISTORICO",
    } <= acoes, acoes
    assert "android.intent.action.SEND" in acoes
    assert any(d.get(NS + "mimeType") == "text/plain" for d in atividade.iter("data"))
    assert any(m.get(NS + "name") == "android.app.shortcuts" for m in atividade.iter("meta-data"))

    receptores = [n for n in raiz.iter("receiver") if n.get(NS + "name") == ".JarvisWidgetProvider"]
    assert receptores, "receiver do widget ausente"
    atualizacao = {a.get(NS + "name") for a in receptores[0].iter("action")}
    assert "android.appwidget.action.APPWIDGET_UPDATE" in atualizacao
    assert any(m.get(NS + "resource") == "@xml/jarvis_widget_info" for m in receptores[0].iter("meta-data"))


def caso_recursos_e_codigo(tmp: Path) -> None:
    app = runner(tmp)
    assert rodar(app).returncode == 0

    res = app / "src" / "main" / "res"
    atalhos = ET.parse(res / "xml" / "shortcuts.xml").getroot()
    assert len(atalhos.findall("shortcut")) == 3
    assert (res / "layout" / "jarvis_widget.xml").is_file()
    assert (res / "drawable" / "jarvis_widget_fundo.xml").is_file()
    assert (res / "values" / "jarvis_sistema.xml").is_file()

    kotlin = app / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"
    atividade = (kotlin / "MainActivity.kt").read_text(encoding="utf-8")
    assert '"com.jarvis.nova/sistema"' in atividade
    assert "intencaoPendente" in atividade
    provedor = (kotlin / "JarvisWidgetProvider.kt").read_text(encoding="utf-8")
    assert "R.layout.jarvis_widget" in provedor
    assert provedor.count("setOnClickPendingIntent") == 2


def caso_idempotente(tmp: Path) -> None:
    app = runner(tmp)
    assert rodar(app).returncode == 0
    antes = ET.tostring(manifesto(app), encoding="unicode")
    assert rodar(app).returncode == 0
    depois = ET.tostring(manifesto(app), encoding="unicode")
    assert antes == depois, "segunda execução alterou o manifesto"
    texto = (app / "src" / "main" / "AndroidManifest.xml").read_text(encoding="utf-8")
    assert texto.count("<receiver") == 1
    assert texto.count("android.app.shortcuts") == 1
    assert texto.count("com.jarvis.nova.ACAO_VOZ") == 1


def caso_recusa_runner_incompleto(tmp: Path) -> None:
    app = runner(tmp)
    (app / "src" / "main" / "AndroidManifest.xml").unlink()
    r = rodar(app)
    assert r.returncode != 0, "script aceitou runner sem manifesto"
    assert "manifesto ausente" in r.stdout + r.stderr


def caso_manifesto_parcialmente_preparado(tmp: Path) -> None:
    """Manifesto com receptor e meta-data, mas sem filtros, ganha só o que falta."""
    app = runner(tmp)
    manifest_path = app / "src" / "main" / "AndroidManifest.xml"
    texto = manifest_path.read_text(encoding="utf-8").replace(
        "</activity>",
        '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />\n        </activity>',
    ).replace(
        "</application>",
        '        <receiver android:name=".JarvisWidgetProvider" android:exported="true" />\n    </application>',
    )
    manifest_path.write_text(texto, encoding="utf-8")
    r = rodar(app)
    assert r.returncode == 0, r.stdout + r.stderr
    depois = manifest_path.read_text(encoding="utf-8")
    assert depois.count(".JarvisWidgetProvider") == 1
    assert depois.count("android.app.shortcuts") == 1
    assert depois.count("com.jarvis.nova.ACAO_VOZ") == 1


def main() -> int:
    casos = (
        ("atalhos, widget e compartilhamento", caso_atalhos_widget_e_compartilhamento),
        ("recursos e código copiados", caso_recursos_e_codigo),
        ("execução idempotente", caso_idempotente),
        ("recusa runner incompleto", caso_recusa_runner_incompleto),
        ("manifesto parcialmente preparado", caso_manifesto_parcialmente_preparado),
    )
    for nome, caso in casos:
        with tempfile.TemporaryDirectory(prefix="sistema-") as pasta:
            caso(Path(pasta))
        print(f"ok — {nome}")
    print("OK: integração Android — atalhos, widget, compartilhamento e canal do sistema")
    return 0


if __name__ == "__main__":
    sys.exit(main())
