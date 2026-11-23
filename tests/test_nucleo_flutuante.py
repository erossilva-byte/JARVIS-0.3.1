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

# 6b. Pausar congela sem tirar da tela; modo econômico reduz e suspende.
for termo in ("fun definirPausado", "fun definirEconomico", "fun pausar()",
              "fun retomar()", "fun suspender()", "fun acordar()",
              "ACTION_SCREEN_OFF", "intervaloMs * 2",
              "ultimoQuadroEconomico", "saveLayerAlpha",
              "reiniciarAnimacao"):
    exigir(termo in kotlin, f"pausa/economia sem {termo}")
exigir("if (!ativo || pausado) return" in kotlin,
       "teletransporte não respeita a pausa")
for termo in ('"definirPausado"', '"definirEconomico"', '"economico"'):
    exigir(termo in principal, f"MainActivity sem {termo}")
for termo in ("definirPausado", "definirEconomico", "pausado", "economico"):
    exigir(termo in controle, f"nucleo_controle.dart sem {termo}")
for termo in ("nucleo-pausar", "Pausar o núcleo", "Retomar o núcleo",
              "nucleo-economico", "Modo econômico", "nucleo-pausado-aviso"):
    exigir(termo in pagina, f"nucleo_page.dart sem {termo}")
teste = ler(APP / "test" / "nucleo_page_test.dart")
exigir("pausar congela" in teste and "modo econômico" in teste,
       "teste sem pausar/economia")

# 6c. Menu no núcleo: cada opção executa a função de verdade.
for termo in ("abrirMenu", "fecharMenu", "aoAbrirMenu", "480L",
              "ACTION_OUTSIDE", "Pausar", "Retomar",
              "Modo econômico: ", "Teletransportar agora", "Abrir o JARVIS",
              "Desligar o núcleo", "linhaTamanhos", "aplicarTamanho"):
    exigir(termo in kotlin, f"menu do núcleo sem {termo}")
exigir("definirPausado(!pausado)" in kotlin,
       "item de pausa não alterna de verdade")
exigir("definirEconomico(!economico)" in kotlin,
       "item do modo econômico não alterna de verdade")
exigir("setOnClickListener" in kotlin and "isClickable = habilitado" in kotlin,
       "itens do menu não executam ao toque")
exigir("FLAG_WATCH_OUTSIDE_TOUCH" in kotlin,
       "menu não fecha ao tocar fora")

# 6d. Medição da economia: quadros e tempo por modo, calculados no aparelho.
for termo in ("fun medicao()", "fun zerarMedicao()", "quadrosNormal",
              "msNormal", "quadrosEconomico", "msEconomico",
              "ultimoDesenho"):
    exigir(termo in kotlin, f"medição sem {termo}")
for termo in ('"medicao"', '"zerarMedicao"'):
    exigir(termo in principal, f"MainActivity sem {termo}")
for termo in ("medicao()", "zerarMedicao()", "MedicaoNucleo"):
    exigir(termo in controle, f"nucleo_controle.dart sem {termo}")
for termo in ("nucleo-medicao-normal", "nucleo-medicao-eco",
              "nucleo-medicao-diferenca", "nucleo-medicao-zerar",
              "Amostra curta"):
    exigir(termo in pagina, f"medição na tela sem {termo}")
exigir((APP / "test" / "medicao_nucleo_test.dart").is_file(),
       "teste do cálculo da medição ausente")

# 6e. O menu acompanha o núcleo no arrasto, com a geometria isolada.
for termo in ("internal object PosicaoMenu", "fun calcular(",
              "aplicarPosicaoMenu", "if (menu != null) aplicarPosicaoMenu()",
              "updateViewLayout(painel, layout)", "cabeDireita"):
    exigir(termo in kotlin, f"menu acompanhando o núcleo sem {termo}")
exigir("if (menu != null) aplicarPosicaoMenu()" in kotlin[kotlin.index("fun arrastarNaTela"):kotlin.index("fun aplicarPosicaoMenu")],
       "arrasto não reposiciona o menu")

# 6f. Consumo real: CPU do processo e bateria em janelas controladas.
for termo in ("fun iniciarConsumo", "fun pararConsumo", "fun estadoConsumo",
              "fun zerarConsumo", "Process.getElapsedCpuTime",
              "BATTERY_PROPERTY_CAPACITY", "isCharging", "telaApagou"):
    exigir(termo in kotlin, f"consumo sem {termo}")
for termo in ('"iniciarConsumo"', '"pararConsumo"', '"consumo"',
              '"zerarConsumo"'):
    exigir(termo in principal, f"MainActivity sem {termo}")
for termo in ("iniciarConsumo", "pararConsumo", "consumo()",
              "zerarConsumo"):
    exigir(termo in controle, f"nucleo_controle.dart sem {termo}")
for termo in ("CONSUMO REAL", "nucleo-consumo-iniciar",
              "nucleo-consumo-parar", "nucleo-consumo-zerar",
              "nucleo-consumo-normal", "nucleo-consumo-eco",
              "nucleo-consumo-diferenca",
              "não entrega energia por janela sobreposta"):
    exigir(termo in pagina, f"consumo na tela sem {termo}")
for caminho in ("test/posicao_menu_test.dart", "test/consumo_nucleo_test.dart"):
    exigir((APP / caminho).is_file(), f"teste ausente: {caminho}")

# 7. O arquivo Kotlin entra no build e o teste está na esteira.
exigir("JarvisNucleo.kt" in preparo,
       "preparo do Android não copia JarvisNucleo.kt")
exigir((APP / "test" / "nucleo_page_test.dart").is_file(),
       "teste da tela do núcleo ausente")
exigir("python3 tests/test_nucleo_flutuante.py" in pacote,
       "contrato fora do test:all")

print("OK: bloco 107 — núcleo flutuante 3D por cima dos apps, com brilho, "
      "arrasto e teletransporte animado.")
