"""Testa a pré-checagem da interface Flutter (Fase 5).

Cada regra é exercitada num projeto falso mínimo: o teste precisa provar que a regra reprova o
defeito, não só que o repositório atual passa.
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent


def carregar():
    caminho = RAIZ / "ci" / "preflight_interface.py"
    spec = importlib.util.spec_from_file_location("preflight_interface", caminho)
    modulo = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(modulo)
    return modulo


BASE = {
    "pubspec.yaml": "name: jarvis_nova\ndependencies:\n  flutter:\n    sdk: flutter\n",
    "lib/drawer.dart": "\n".join(f"  _item(Icons.circle, '{secao}', () {{}});" for secao in (
        "IA", "Voz", "Memória", "Visão", "Pessoas", "Arquivos", "CADeSIMU",
        "Tarefas", "Celular", "Segurança", "Personalização", "Configurações",
    )),
    "lib/home_screen.dart": "final reduzir = MediaQuery.maybeOf(context)?.disableAnimations ?? false;\n",
    "lib/command_center.dart": "Widget build() => RepaintBoundary(child: Text('núcleo'));\n",
}


def projeto(extra: dict[str, str] | None = None, remover: tuple[str, ...] = ()) -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="interface-"))
    (tmp / "flutter_app").mkdir()
    for nome, conteudo in BASE.items():
        if nome in remover:
            continue
        destino = tmp / "flutter_app" / nome
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(conteudo, encoding="utf-8")
    for nome, conteudo in (extra or {}).items():
        destino = tmp / "flutter_app" / nome
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(conteudo, encoding="utf-8")
    return tmp


def main() -> int:
    modulo = carregar()

    limpo = projeto()
    assert modulo.verificar(limpo) == [], "projeto limpo deveria passar"

    com_webview = projeto({"lib/tela.dart": "import 'package:webview_flutter/webview_flutter.dart';\nclass T { final WebView w; }\n"})
    problemas = modulo.verificar(com_webview)
    assert any("WebView" in p for p in problemas), problemas

    com_pacote = projeto({"pubspec.yaml": "dependencies:\n  webview_flutter: ^4.0.0\n"})
    assert any("webview_flutter" in p for p in modulo.verificar(com_pacote)), "pacote proibido"

    com_html = projeto({"lib/nota.dart": "final x = Html('<b>oi</b>');\n"})
    assert any("Html(" in p for p in modulo.verificar(com_html)), "HTML embutido"

    sem_secao = projeto(remover=("lib/drawer.dart",))
    assert any("drawer.dart" in p for p in modulo.verificar(sem_secao)), "gaveta ausente"

    sem_animacao = projeto({"lib/home_screen.dart": "class A {}\n"})
    assert any("animação reduzida" in p for p in modulo.verificar(sem_animacao)), "animação reduzida"

    sem_repaint = projeto({"lib/command_center.dart": "class A {}\n"})
    assert any("RepaintBoundary" in p for p in modulo.verificar(sem_repaint)), "RepaintBoundary"

    print("OK: pré-checagem da interface reprova WebView, pacote web, HTML embutido, seção ausente, animação e RepaintBoundary")

    real = subprocess.run([sys.executable, str(RAIZ / "ci" / "preflight_interface.py")],
                          cwd=RAIZ, capture_output=True, text=True)
    assert real.returncode == 0, real.stdout + real.stderr
    assert "sem WebView" in real.stdout, real.stdout
    print("OK: interface atual passa na pré-checagem (sem WebView, 12 seções)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
