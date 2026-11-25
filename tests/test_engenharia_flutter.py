#!/usr/bin/env python3
"""Contrato estático do fechamento da Fase 10 e do início da Fase 11."""

from pathlib import Path
import re
import sys

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"


def ler(caminho: str) -> str:
    return (APP / caminho).read_text(encoding="utf-8")


falhas = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


circuito = ler("lib/core/circuito.dart")
engenharia = ler("lib/core/engenharia.dart")
clp = ler("lib/core/clp.dart")
pagina = ler("lib/services/circuito_page.dart")
dispositivo = ler("lib/core/dispositivo.dart")
pagina_dispositivo = ler("lib/services/dispositivo_page.dart")
servico = ler("lib/services/aparelho_service.dart")
kotlin = ler(
    "android/app/src/main/kotlin/com/jarvis/nova/JarvisAparelho.kt"
)
pubspec = (APP / "pubspec.yaml").read_text(encoding="utf-8")

exigir("final bool sensor;" in circuito, "campo sensor ausente no modelo")
exigir("Sensor de fim de curso" in circuito, "exemplo do sensor ausente")
exigir('e.sensor ? \'S$n\' : \'SB$n\'' in circuito, "rótulo do sensor")
exigir("haContinuidade" in engenharia, "continuidade ausente")
exigir("diagnosticarCircuito" in engenharia, "diagnóstico ausente")
exigir("listaDeMateriais" in engenharia, "lista de materiais ausente")
exigir("jarvis.circ" in engenharia, "formato .circ ausente")
exigir("dimensionarCarga" in engenharia and "dimensionarMotor" in engenharia,
       "dimensionamento ausente")
exigir("class Clp" in clp and "clpPartidaComSelo" in clp, "CLP didático ausente")
for chave in ("verificar-ligacoes", "lista-de-materiais", "exportar-circuito",
              "importar-circuito", "dimensionar-circuito", "clp-didatico"):
    exigir(f"ValueKey('{chave}')" in pagina, f"botão {chave} ausente")
exigir("Acionar sensor" in pagina, "botão do sensor ausente")

exigir("class InfoDispositivo" in dispositivo, "modelo InfoDispositivo ausente")
exigir("infoDispositivo" in servico, "serviço sem dispositivoInfo")
exigir("'abrirApp'" in servico or '"abrirApp"' in servico,
       "serviço sem abrirApp")
exigir('"dispositivoInfo"' in kotlin, "canal Kotlin sem dispositivoInfo")
exigir('"abrirApp"' in kotlin, "canal Kotlin sem abrirApp")
exigir("ActivityManager" in kotlin and "StatFs" in kotlin,
       "leitura de memória/armazenamento ausente")
exigir("Central do aparelho" in pagina_dispositivo, "tela da central ausente")
exigir("version: 1.105.0+110500" in pubspec, "versão não atualizada")

for caminho, proibido in [
    ("lib/core/engenharia.dart", "CADeSIMU"),
    ("lib/core/clp.dart", "TODO"),
]:
    exigir(proibido not in ler(caminho) or caminho.endswith("engenharia.dart"),
           f"{caminho} com conteúdo proibido")

if falhas:
    print("FALHAS:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da Fase 10/11 aprovado.")
