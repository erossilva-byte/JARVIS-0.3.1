#!/usr/bin/env python3
"""Contrato dos perfis de timbre (ajuste 088, versão 1.75.0).

O comparativo com o U.L.T.R.O.N. apontava a falta de perfis de voz escolhíveis:
o JARVIS falava sempre no mesmo timbre grave. Agora a tela oferece grave,
natural e ágil, aplicados pela síntese do próprio aparelho.

O que este contrato prende, sem aparelho:

1. os três perfis existem com os mesmos valores no Dart e no Kotlin;
2. o grave continua sendo o timbre original (0,72 / 0,88), sem regressão;
3. id desconhecido cai no padrão em vez de quebrar a tela;
4. o perfil é gravado no aparelho e aplicado à síntese assim que possível;
5. a tela mostra o timbre real, deixa ouvir um exemplo e explica quando não há
   canal Android ou síntese;
6. o mesmo perfil vale para a voz da tela e do segundo plano (um só JarvisVoz
   lendo a preferência).
"""

from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
KOTLIN = APP / "android"
LIB = APP / "lib"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


timbre_kt = ler(KOTLIN / "JarvisTimbre.kt")
voz_kt = ler(KOTLIN / "JarvisVoz.kt")
atividade = ler(KOTLIN / "MainActivity.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
nucleo = ler(LIB / "core" / "timbre_voz.dart")
ponte = ler(LIB / "services" / "voz_jarvis.dart")
tela = ler(LIB / "services" / "timbre_page.dart")
home = ler(LIB / "home_screen.dart")
catalogo = ler(LIB / "catalog.dart")
gaveta = ler(LIB / "drawer.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_088-perfis-de-timbre.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.88.4+18804" in pubspec, "versão não atualizada para 1.75.0")
exigir("1.75.0" in changelog and "timbre" in changelog.lower(),
       "CHANGELOG sem o bloco 1.75.0 do timbre")
exigir("tests/test_timbre_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/timbre_voz_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 088 ausente")

# 2. Perfis no Kotlin e no Dart, com paridade de valores.
for termo in ('PREFS = "jarvis_voz"', 'PADRAO = "grave"',
              'Perfil("grave"', 'Perfil("natural"', 'Perfil("agil"',
              "fun perfil(", "fun definir(", "fun estado("):
    exigir(termo in timbre_kt, f"JarvisTimbre.kt sem {termo}")
for termo in ("id: 'grave'", "id: 'natural'", "id: 'agil'", "timbrePadrao",
              "PerfilTimbre timbreDe(", "pitchSeguro", "velocidadeSegura",
              "resumoTimbre", "fraseExemploTimbre", "limitesTimbre"):
    exigir(termo in nucleo, f"core/timbre_voz.dart sem {termo}")
for valor in ("0.72", "0.88", "1.15", "1.12"):
    exigir(valor in timbre_kt, f"Kotlin sem o valor {valor}")
    exigir(valor in nucleo, f"Dart sem o valor {valor} (paridade quebrada)")
exigir("grave" in timbre_kt and "timbrePadrao" in nucleo,
       "id padrão diferente entre Dart e Kotlin")

# 3. Síntese aplica o perfil gravado (sem regressão do grave fixo).
for termo in ("fun aplicarTimbre(", "motor.setPitch(perfil.pitch)",
              "motor.setSpeechRate(perfil.velocidade)",
              "JarvisTimbre.id(appContext)", '"timbre" to JarvisTimbre.id(appContext)'):
    exigir(termo in voz_kt, f"JarvisVoz.kt sem {termo}")
exigir("motor.setPitch(0.72f)" not in voz_kt,
       "o tom grave continua fixo no código da voz")
exigir('"timbre" -> result.success(JarvisTimbre.estado(this))' in atividade,
       "canal de voz não expõe o timbre")
exigir('"definirTimbre" ->' in atividade and
       "JarvisTimbre.definir(" in atividade and
       "aplicarTimbre()" in atividade,
       "canal de voz não grava e aplica o timbre")

# 4. Ponte Dart: leitura, gravação e recusa honesta.
for termo in ("timbreAtual()", "definirTimbre(String id)", "TimbreIndisponivel",
              "'definirTimbre'", "'timbre'", "timbreDe(id).id"):
    exigir(termo in ponte, f"voz_jarvis.dart sem {termo}")
exigir("aplicado: dados['aplicado'] == true" in ponte,
       "ponte não devolve se a síntese aplicou agora")

# 5. Tela, navegação e transparência.
for termo in ("timbre-atual", "timbre-opcao-${perfil.id}", "timbre-ouvir",
              "timbre-erro", "timbre-aplicado", "fraseExemploTimbre",
              "perfisTimbre", "resumoTimbre("):
    exigir(termo in tela, f"timbre_page.dart sem {termo}")
exigir("TimbreIndisponivel catch" in tela,
       "tela não trata a ausência do canal")
exigir("Perfis de timbre" in catalogo and "TimbrePage()" in home and
       "onModule('Perfis de timbre')" in gaveta,
       "módulo de timbre fora do catálogo, gaveta ou rota")
exigir('shutil.copy2(ANDROID / "JarvisTimbre.kt"' in preparo,
       "preparo não copia JarvisTimbre.kt")

# 6. Documentação.
exigir("timbre" in inventario.lower(), "inventário não cita o timbre")
exigir("Perfis de timbre" in comparativo,
       "comparativo perdeu a linha dos perfis de timbre")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 088 sem a seção {secao}")
    for termo in ("grave", "natural", "ágil", "síntese"):
        exigir(termo in texto.lower(), f"relatório 088 sem {termo}")

if falhas:
    print("FALHAS no contrato dos perfis de timbre:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato dos perfis de timbre: aprovado.")
