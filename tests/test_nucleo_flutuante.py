"""Bloco 107 — núcleo flutuante 3D sobre os outros apps.

Confere o caminho estático: janela de sobreposição no Android, malha geodésica
calculada no aparelho, teletransporte com sumir/voltar e clarão, arrasto, toque
que abre o app, autorização de sobreposição e a tela que liga tudo. Contrato não
compila Kotlin nem testa em aparelho — isso continua fora daqui.
"""

from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
ANDROID = APP / "android"
NUCLEO = APP / "lib" / "nucleo"


def ler(caminho: Path) -> str:
    assert caminho.is_file(), f"arquivo ausente: {caminho}"
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    assert condicao, mensagem


kotlin = ler(ANDROID / "JarvisNucleo.kt")
principal = ler(ANDROID / "MainActivity.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
controle = ler(NUCLEO / "nucleo_controle.dart")
pagina = ler(NUCLEO / "nucleo_page.dart")
previa = ler(NUCLEO / "nucleo_previa.dart")
avatar = ler(APP / "lib" / "services" / "avatar_page.dart")
holograma = ler(APP / "lib" / "hologram.dart")
pacote = ler(RAIZ / "package.json")

# 1. A janela fica por cima dos outros apps e só com autorização.
for termo in ("TYPE_APPLICATION_OVERLAY", "WindowManager", "addView(",
              "FLAG_NOT_FOCUSABLE", "Settings.canDrawOverlays",
              "ACTION_MANAGE_OVERLAY_PERMISSION", "sem_permissao"):
    exigir(termo in kotlin, f"JarvisNucleo.kt sem {termo}")

# 2. É geometria 3D calculada no aparelho, não bitmap.
for termo in ("malhaGeodesica", "subdivididas", "giro", "inclinacao",
              "camera /", "RadialGradient", "postInvalidateOnAnimation",
              "floatArrayOf", "perspectiva"):
    exigir(termo in kotlin, f"desenho do núcleo sem {termo}")
exigir("BitmapFactory" not in kotlin and "lottie" not in kotlin.lower(),
       "núcleo usa imagem pronta em vez de geometria")

# 3. Teletransporte: some, muda de ponto, volta com clarão e sem sair da tela.
for termo in ("fun teletransportar", "alpha(0f)", "scaleX(0.18f)",
              "OvershootInterpolator", "moverParaPontoAleatorio", "piscar()",
              "nextInt(", "coerceIn("):
    exigir(termo in kotlin, f"teletransporte sem {termo}")

# 4. Toque abre o app; arrasto move a janela e pausa o teletransporte.
for termo in ("onTouchEvent", "ACTION_MOVE", "aoArrastar", "arrastarNaTela",
              "updateViewLayout", "PAUSA_APOS_ARRASTO_MS", "aoTocar",
              "getLaunchIntentForPackage"):
    exigir(termo in kotlin, f"interação sem {termo}")

# 5. O canal do app liga, desliga, ajusta e pede permissão.
for termo in ('"com.jarvis.nova/nucleo"', '"iniciar"', '"parar"',
              '"teleportar"', '"abrirAjusteSobreposicao"'):
    exigir(termo in principal, f"MainActivity sem {termo}")
for termo in ("MethodChannel('com.jarvis.nova/nucleo')", "iniciar(",
              "parar(", "teleportar(", "abrirAjusteSobreposicao"):
    exigir(termo in controle, f"nucleo_controle.dart sem {termo}")

# 6. A tela explica, mostra prévia e não promete o que não faz.
for termo in ("SwitchListTile", "nucleo-ativo", "nucleo-tamanho",
              "nucleo-intervalo", "nucleo-teleportar", "nucleo-permissao",
              "NucleoPrevia"):
    exigir(termo in pagina, f"nucleo_page.dart sem {termo}")
exigir("Exibir sobre outros apps" in pagina,
       "tela não explica a autorização de sobreposição")
exigir("consome bateria" in pagina or "gasta " in pagina,
       "tela não avisa sobre bateria")
exigir("HologramPainter" in previa and "fundo: false" in previa,
       "prévia não usa o desenho do núcleo sem fundo")
exigir("this.fundo = true" in holograma and "if (fundo)" in holograma,
       "HologramPainter sem a opção de fundo")
exigir("NucleoPage" in avatar and "avatar-nucleo-flutuante" in avatar,
       "avatar não leva ao núcleo flutuante")

# 7. O arquivo Kotlin entra no build e o teste está na esteira.
exigir("JarvisNucleo.kt" in preparo,
       "preparo do Android não copia JarvisNucleo.kt")
exigir((APP / "test" / "nucleo_page_test.dart").is_file(),
       "teste da tela do núcleo ausente")
exigir("python3 tests/test_nucleo_flutuante.py" in pacote,
       "contrato fora do test:all")

print("OK: bloco 107 — núcleo flutuante 3D por cima dos apps, com brilho, "
      "arrasto e teletransporte animado.")
