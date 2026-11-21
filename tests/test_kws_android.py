"""Garante que o runner Android mantenha o sherpa-onnx intacto no R8.

O plugin Gradle do Flutter liga minify no release. Sem as regras de keep, o R8
renomeia `maxActivePaths` e o JNI falha em runtime com
"Failed to get field ID for maxActivePaths".
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SCRIPT = RAIZ / "flutter_app" / "tool" / "prepare_android_kws.py"


def runner(base: Path) -> Path:
    app = base / "android" / "app"
    (app / "src" / "main").mkdir(parents=True)
    (app / "src" / "main" / "AndroidManifest.xml").write_text(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
        "<application><activity android:name=\".MainActivity\" /></application></manifest>",
        encoding="utf-8",
    )
    (app / "build.gradle.kts").write_text(
        "android {\n    defaultConfig {\n        minSdk = flutter.minSdkVersion\n    }\n}\n",
        encoding="utf-8",
    )
    kws = app / "src" / "main" / "assets" / "kws"
    kws.mkdir(parents=True)
    for nome in (
        "encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
        "decoder-epoch-12-avg-2-chunk-16-left-64.onnx",
        "joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
        "tokens.txt",
        "keywords.txt",
    ):
        (kws / nome).write_text("x", encoding="utf-8")
    return app


def rodar(app: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(app)],
        cwd=RAIZ,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="kws-android-") as pasta:
        app = runner(Path(pasta))
        resultado = rodar(app)
        assert resultado.returncode == 0, resultado.stdout + resultado.stderr

        proguard = (app / "proguard-rules.pro").read_text(encoding="utf-8")
        assert "-keep class com.k2fsa.sherpa.onnx.** { *; }" in proguard
        assert "-keepclassmembers class com.k2fsa.sherpa.onnx.** { *; }" in proguard

        # createStream espera o formato tokenizado do keywords.txt; texto puro
        # ("Jarvis/Javis") falha no EncodeKeywords e devolve stream nulo.
        engine = (RAIZ / "JarvisKwsEngine.java").read_text(encoding="utf-8")
        assert 'createStream("")' in engine
        assert "createStream(keywords)" not in engine

        # Rodar de novo não pode duplicar nem apagar as regras.
        antes = proguard
        assert rodar(app).returncode == 0
        assert (app / "proguard-rules.pro").read_text(encoding="utf-8") == antes

    print("OK: KWS Android mantém as classes do sherpa-onnx no R8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
