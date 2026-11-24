"""Bloco 109 — acessos que estavam escondidos.

A voz externa (ID + chave) e o núcleo flutuante existiam no app, mas só se
chegava a eles por dentro de outros módulos. Este contrato exige atalho direto
na gaveta, botão na tela de Voz e um teste de widget que prova o caminho.
Contrato estático: não compila Flutter nem abre tela.
"""

from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"


def ler(caminho: Path) -> str:
    assert caminho.is_file(), f"arquivo ausente: {caminho}"
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    assert condicao, mensagem


gaveta = ler(LIB / "drawer.dart")
casa = ler(LIB / "home_screen.dart")
tela_voz = ler(LIB / "services" / "kws_settings_page.dart")
voz_externa = ler(LIB / "services" / "voz_externa_page.dart")
nucleo = ler(LIB / "nucleo" / "nucleo_page.dart")

# 1. A gaveta tem os dois itens, com o nome que a pessoa procura.
for titulo in ("'Voz externa'", "'Núcleo flutuante'"):
    exigir(titulo in gaveta, f"gaveta sem o item {titulo}")

# 2. A gaveta recebe um callback para cada um (não abre módulo do catálogo).
for campo in ("onVozExterna", "onNucleo"):
    exigir(f"required this.{campo}" in gaveta, f"drawer.dart sem {campo}")
    exigir(f"final VoidCallback {campo};" in gaveta, f"campo {campo} ausente")

# 3. A tela principal liga os callbacks nas telas de verdade.
for chamada, tela in (("onVozExterna: _openVozExterna", "VozExternaPage()"),
                      ("onNucleo: _openNucleo", "NucleoPage()")):
    exigir(chamada in casa, f"home_screen.dart sem {chamada}")
    exigir(tela in casa, f"home_screen.dart não abre {tela}")

# 4. A tela de Voz também leva à voz externa.
exigir("import 'voz_externa_page.dart';" in tela_voz,
       "kws_settings_page.dart não importa a voz externa")
exigir("VozExternaPage()" in tela_voz,
       "kws_settings_page.dart sem botão para a voz externa")
exigir("'abrir-voz-externa'" in tela_voz,
       "botão da voz externa sem chave de teste")

# 5. Os campos que a pessoa precisa preencher continuam existindo.
for campo in ("voz-id-campo", "voz-id-salvar", "voz-chave-campo",
              "voz-chave-salvar", "voz-externa-ativa", "voz-externa-testar"):
    exigir(campo in voz_externa, f"tela de voz externa sem {campo}")

# 6. A tela do núcleo continua com o interruptor e a autorização.
for marca in ("nucleo-ativo", "nucleo-permissao"):
    exigir(marca in nucleo, f"tela do núcleo sem {marca}")

# 7. O caminho fica travado por teste de widget.
exigir((APP / "test" / "gaveta_acessos_test.dart").is_file(),
       "falta o teste de widget da gaveta")

print("OK: voz externa e núcleo flutuante com atalho direto na gaveta")
