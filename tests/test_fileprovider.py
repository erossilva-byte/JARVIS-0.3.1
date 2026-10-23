#!/usr/bin/env python3
"""Garante que o atualizador consegue entregar o APK ao instalador do Android.

Regressão real: o template do Capacitor já traz um FileProvider (@xml/file_paths,
sem files/). O patch adicionava outro com a mesma authority, o Android ficava com o
do template e o "Baixar e instalar" falhava com
"Failed to find configured root that contains .../files/updates/jarvis-update.apk".
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / "patch_manifest.py"

MANIFESTO_CAPACITOR = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:allowBackup="true" android:label="@string/app_name">
        <activity android:name=".MainActivity" />
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
"""

with tempfile.TemporaryDirectory(prefix="jarvis-manifest-") as tmp:
    app = Path(tmp) / "app"
    main = app / "src" / "main"
    main.mkdir(parents=True)
    manifest = main / "AndroidManifest.xml"
    manifest.write_text(MANIFESTO_CAPACITOR, encoding="utf-8")

    for _ in range(2):  # idempotente
        subprocess.run([sys.executable, str(PATCH), str(manifest)], check=True, capture_output=True, text=True)

    texto = manifest.read_text(encoding="utf-8")
    caminhos = main / "res" / "xml" / "jarvis_paths.xml"
    assert caminhos.exists(), "jarvis_paths.xml não foi criado"
    xml = caminhos.read_text(encoding="utf-8")

    assert texto.count("androidx.core.content.FileProvider") == 1, (
        "Manifesto tem %d FileProviders; duas authorities iguais fazem o instalador "
        "usar o do template e falhar" % texto.count("androidx.core.content.FileProvider"))
    assert "com.jarvis.nova.fileprovider" in texto, "Authority do atualizador ausente"
    assert "@xml/jarvis_paths" in texto, "FileProvider não aponta para jarvis_paths"
    assert "@xml/file_paths" not in texto, "FileProvider do template (sem files/) continua no manifesto"
    assert texto.count('android:resource="@xml/jarvis_paths"') == 1, "Meta-data do FileProvider duplicada"
    assert 'path="updates/"' in xml, "jarvis_paths.xml não expõe a pasta updates/ onde o APK é baixado"
    assert "<files-path" in xml, "jarvis_paths.xml não usa files-path (o APK fica em files/updates)"

print("FileProvider do atualizador validado: um único provider apontando para files/updates.")
