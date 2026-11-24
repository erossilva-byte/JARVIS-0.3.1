"""Bloco 111 — regras de enquadramento do palco, com prévia sem internet.

O usuário escreve a regra por tipo de mídia (altura na tela e recorte), a
imagem é classificada por dois limiares ajustáveis, a prévia é desenhada no
aparelho (nenhuma imagem de rede) e as regras ficam guardadas.
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


palco = ler(LIB / "core" / "palco.dart")
pagina = ler(LIB / "services" / "palco_page.dart")
editor = ler(LIB / "services" / "palco_regras_page.dart")
loja = ler(LIB / "services" / "palco_regras_store.dart")

# 1. Regras no núcleo ---------------------------------------------------------
exigir("class RegraMoldura" in palco, "sem RegraMoldura")
exigir("class RegrasPalco" in palco, "sem RegrasPalco")
for campo in ("capaLarga", "retratoAlto", "quadrada", "capaVideo",
              "capaNoticia", "limiarLargo", "limiarEstreito"):
    exigir(f"this.{campo} " in palco or f"this.{campo} =" in palco,
           f"RegrasPalco sem o campo {campo}")
exigir("static const padrao = RegrasPalco();" in palco, "sem regras padrão")
exigir("alturaMinima = 0.15" in palco and "alturaMaxima = 0.62" in palco,
       "faixa de altura errada")
exigir("RegrasPalco comRegra(" in palco, "não dá para trocar uma regra")
exigir("Map<String, Object?> paraJson()" in palco, "regras sem JSON de saída")
exigir("static RegrasPalco deJson(" in palco, "regras sem leitura de JSON")
exigir("limiarLargo <= estreito + 0.1" in palco or
       "largo <= estreito + 0.1" in palco,
       "limiares podem se cruzar")
exigir("Moldura molduraDoItem(ItemPalco item," in palco and
       "{RegrasPalco regras = RegrasPalco.padrao}" in palco,
       "moldura não recebe as regras")
exigir("proporcao >= regras.limiarLargo" in palco and
       "proporcao <= regras.limiarEstreito" in palco,
       "limiares não classificam a imagem")

# 2. Tela do palco -----------------------------------------------------------
exigir("RegrasPalco regras = RegrasPalco.padrao;" in pagina,
       "tela do palco sem as regras")
exigir("_carregarRegras()" in pagina, "tela do palco não lê as regras salvas")
exigir("PalcoRegrasPage(regras: regras)" in pagina, "não abre o editor")
exigir("'palco-regras'" in pagina, "sem botão visível de regras")
exigir("molduraDoItem(item, regras: regras)" in pagina,
       "resultado não usa as regras")

# 3. Editor e prévia offline -------------------------------------------------
for chave in ("'previa-moldura'", "'previa-legenda'", "'regra-tipo-",
              "'regra-altura'", "'regra-recorte'", "'regra-inteira'",
              "'regra-limiar-largo'", "'regra-limiar-estreito'",
              "'regra-salvar'", "'regra-padrao'"):
    exigir(chave in editor, f"editor sem {chave}")
exigir("Image.network" not in editor,
       "a prévia baixa imagem: precisa ser desenhada no aparelho")
exigir("http" not in editor.replace("http://www.w3.org", ""),
       "o editor menciona rede")
exigir("class PreviaMoldura" in editor, "sem widget de prévia")
exigir("Navigator.of(context).pop(atual)" in editor,
       "salvar não devolve as regras")
exigir("RegrasPalco.padrao)" in editor, "sem voltar ao padrão")

# 4. Guardar no aparelho -----------------------------------------------------
exigir("class PalcoRegrasStore" in loja, "sem armazenamento das regras")
exigir("jarvis.palco.regras.v1" in loja, "chave de armazenamento ausente")
exigir("Future<bool> salvar(RegrasPalco regras)" in loja, "sem salvar")
exigir("RegrasPalco carregar()" in loja, "sem carregar")
exigir("voltarAoPadrao" in loja, "sem voltar ao padrão")

# 5. Versão e suíte ----------------------------------------------------------
exigir("version: 1.91.0+19100" in ler(APP / "pubspec.yaml"),
       "versão não atualizada para 1.89.1")
pacote = ler(RAIZ / "package.json")
exigir("python3 tests/test_bloco_111.py" in pacote,
       "contrato do bloco fora da suíte")
dart = ler(RAIZ / "tests" / "test_dart_core.py")
exigir("tool/palco_regras_test.dart" in dart,
       "teste puro das regras fora da suíte")
exigir((APP / "test" / "palco_regras_page_test.dart").is_file(),
       "falta o teste de tela do editor")
exigir((APP / "test" / "palco_regras_store_test.dart").is_file(),
       "falta o teste do armazenamento")

print("OK: regras por tipo de mídia, limiares ajustáveis e prévia sem internet")
