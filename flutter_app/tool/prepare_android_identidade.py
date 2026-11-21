#!/usr/bin/env python3
"""Dá ao runner Android gerado a identidade de produção do JARVIS.

O `flutter create` gera o projeto nativo com `com.example.jarvis_nova` e o
rótulo `jarvis_nova`. Este passo troca o identificador, muda o pacote da
`MainActivity` e ajusta o rótulo do aplicativo — sempre de forma idempotente,
porque o runner é gerado a cada build e não entra no controle de versão.

Uso:
    python3 tool/prepare_android_identidade.py android/app
"""
from __future__ import annotations

import sys
from pathlib import Path

ANTIGO = "com.example.jarvis_nova"
NOVO = "com.jarvis.nova"
ROTULO_ANTIGO = 'android:label="jarvis_nova"'
ROTULO_NOVO = 'android:label="J.A.R.V.I.S. Nova"'


def falhar(mensagem: str) -> None:
    print(f"ERRO: {mensagem}", file=sys.stderr)
    raise SystemExit(1)


def preparar(app: Path) -> None:
    gradle = app / "build.gradle.kts"
    if not gradle.is_file():
        falhar(f"build.gradle.kts ausente em {app}")
    conteudo = gradle.read_text(encoding="utf-8")
    if ANTIGO in conteudo:
        gradle.write_text(conteudo.replace(ANTIGO, NOVO), encoding="utf-8")
    elif NOVO not in conteudo:
        falhar(f"identificador Android desconhecido em {gradle}")

    atividade = app / "src/main/kotlin/com/example/jarvis_nova/MainActivity.kt"
    if atividade.is_file():
        fonte = atividade.read_text(encoding="utf-8").replace(
            f"package {ANTIGO}", f"package {NOVO}")
        destino = app / "src/main/kotlin/com/jarvis/nova/MainActivity.kt"
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(fonte, encoding="utf-8")
        atividade.unlink()

    manifesto = app / "src/main/AndroidManifest.xml"
    if not manifesto.is_file():
        falhar(f"AndroidManifest.xml ausente em {app}")
    texto = manifesto.read_text(encoding="utf-8")
    manifesto.write_text(texto.replace(ROTULO_ANTIGO, ROTULO_NOVO), encoding="utf-8")

    final = gradle.read_text(encoding="utf-8")
    for marca in (f'applicationId = "{NOVO}"', f'namespace = "{NOVO}"'):
        if marca not in final:
            falhar(f"runner Android sem {marca}")
    print(f"Identidade Android aplicada: {NOVO}, rótulo J.A.R.V.I.S. Nova.")


def main(argv: list[str]) -> int:
    app = Path(argv[1] if len(argv) > 1 else "android/app")
    preparar(app)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
