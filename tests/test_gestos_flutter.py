#!/usr/bin/env python3
"""Contrato de flip-to-shush e modo noturno (ajuste 087, versão 1.74.0).

O comparativo com o U.L.T.R.O.N. apontava duas faltas de interface: virar o
celular para calar o JARVIS e um modo noturno de brilho baixo com voz suave.
Agora os dois usam os sensores e o brilho do próprio aparelho, sem permissão
nova e sem nuvem.

O que este contrato prende, sem aparelho:

1. a regra do gesto é pura e tem histerese (não cala duas vezes);
2. o sensor só é registrado com a opção ligada e a tela na frente;
3. virar cala a voz da tela e a do serviço, sem derrubar o detector;
4. o modo noturno aplica brilho só na janela do app (sem WRITE_SETTINGS) e
   baixa o volume da voz sem silenciar;
5. o brilho fica na faixa 10–100 e é confirmado pelo canal;
6. sem acelerômetro ou sem canal Android, a tela explica em vez de fingir.
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


sensores_kt = ler(KOTLIN / "JarvisSensores.kt")
atividade = ler(KOTLIN / "MainActivity.kt")
servico_kt = ler(KOTLIN / "KwsForegroundService.kt")
voz_kt = ler(KOTLIN / "JarvisVoz.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
nucleo = ler(LIB / "core" / "gestos.dart")
canal = ler(LIB / "services" / "sensores_service.dart")
tela = ler(LIB / "services" / "gestos_page.dart")
home = ler(LIB / "home_screen.dart")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
catalogo = ler(LIB / "catalog.dart")
gaveta = ler(LIB / "drawer.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_087-flip-to-shush-e-modo-noturno.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.103.0+110300" in pubspec, "versão não atualizada para 1.74.0")
exigir("1.74.0" in changelog and "noturno" in changelog.lower(),
       "CHANGELOG sem o bloco 1.74.0 do modo noturno")
exigir("tests/test_gestos_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/gestos_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 087 ausente")

# 2. Sensor no Kotlin, sem permissão nova.
for termo in ("TYPE_ACCELEROMETER", "LIMIAR_VIRADO", "LIMIAR_VOLTA",
              "ESPERA_ENTRE_AVISOS_MS", "VOLUME_NOTURNO", "registerListener",
              "unregisterListener", "SENSOR_DELAY_NORMAL"):
    exigir(termo in sensores_kt, f"JarvisSensores.kt sem {termo}")
exigir("z <= LIMIAR_VIRADO" in sensores_kt,
       "regra de bruços ausente no sensor")
exigir("z >= LIMIAR_VOLTA" in sensores_kt,
       "histerese de volta ausente no sensor")
exigir("if (!deBrucos && z <= LIMIAR_VIRADO)" in sensores_kt,
       "o gesto pode avisar repetido")
exigir("class Vigia(" in sensores_kt and "fun iniciar()" in sensores_kt,
       "vigia do sensor sem ciclo de vida")
for proibido in ("Settings.System.putInt", "requirePermission",
                 "GlobalScope", "Runtime.getRuntime().exec"):
    exigir(proibido not in sensores_kt, f"JarvisSensores.kt usa {proibido}")

# 3. Canal, brilho da janela e calar a voz.
exigir('const val CANAL_SENSORES = "com.jarvis.nova/sensores"' in atividade,
       "canal de sensores não declarado")
for termo in ("rearmarVigia()", "aplicarBrilho()", "calarTudo()",
              "BRIGHTNESS_OVERRIDE_NONE", "ACTION_CALAR",
              "JarvisSensores.Vigia(this)"):
    exigir(termo in atividade, f"MainActivity sem {termo}")
exigir("if (!JarvisSensores.calarAoVirar(this)) return" in atividade,
       "o sensor é registrado mesmo com a opção desligada")
exigir("vigiaSensores?.parar()" in atividade,
       "o sensor não é desligado quando a tela sai da frente")
exigir("screenBrightness" in atividade,
       "brilho da janela não é aplicado")
exigir("ACTION_CALAR" in servico_kt and "voz?.parar()" in servico_kt,
       "o serviço não para a voz ao receber o gesto")
exigir('if (intent?.action == ACTION_CALAR)' in servico_kt,
       "serviço sem o caminho do gesto")
exigir("KEY_PARAM_VOLUME" in voz_kt and "JarvisSensores.modoNoturno" in voz_kt,
       "a voz não fica mais baixa no modo noturno")

# 4. Núcleo puro.
for termo in ("limiarViradoParaBaixo", "limiarVoltouParaCima", "viradoParaBaixo",
              "voltouParaCima", "brilhoSeguro", "fatorBrilho", "EstadoGestos",
              "resumoGestos", "limitesGestos", "brilhoMinimoGestos",
              "brilhoMaximoGestos"):
    exigir(termo in nucleo, f"core/gestos.dart sem {termo}")
exigir("WRITE_SETTINGS" in nucleo,
       "limite do brilho do sistema não é declarado ao usuário")

# 5. Canal Dart e tela.
for termo in ("com.jarvis.nova/sensores", "SensoresIndisponivel", "estado()",
              "definirCalarAoVirar", "definirModoNoturno", "definirBrilho",
              "calar()", "TargetPlatform.android"):
    exigir(termo in canal, f"sensores_service.dart sem {termo}")
for termo in ("gestos-status", "gestos-calar", "gestos-noturno",
              "gestos-brilho", "gestos-calaram", "gestos-erro",
              "brilhoMinimoGestos", "limitesGestos"):
    exigir(termo in tela, f"gestos_page.dart sem {termo}")
exigir("semSensor || carregando" in tela,
       "o gesto pode ser ligado sem acelerômetro")
exigir("estado.modoNoturno\n                      ? (valor)" in tela or
       "estado.modoNoturno" in tela,
       "brilho pode ser ajustado com o modo noturno desligado")
exigir("calou" in home and "_desmarcarAtivo()" in home,
       "a tela não reage ao gesto")
exigir("evento.type != 'calou'" in conversa,
       "a conversa não interrompe a resposta quando o celular é virado")
exigir("Gestos e modo noturno" in catalogo and
       "GestosPage()" in home and
       "onModule('Gestos e modo noturno')" in gaveta,
       "módulo de gestos fora do catálogo, gaveta ou rota")

# 6. Reprodutibilidade.
exigir('shutil.copy2(ANDROID / "JarvisSensores.kt"' in preparo,
       "preparo não copia JarvisSensores.kt")

# 7. Documentação.
exigir("noturno" in inventario.lower(), "inventário não cita o modo noturno")
exigir("Flip-to-Shush" in comparativo and "Modo Foco Noturno" in comparativo,
       "comparativo perdeu as linhas do ULTRON")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 087 sem a seção {secao}")
    for termo in ("acelerômetro", "brilho", "noturno", "sensor"):
        exigir(termo in texto.lower(), f"relatório 087 sem {termo}")

if falhas:
    print("FALHAS no contrato de flip-to-shush e modo noturno:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato de flip-to-shush e modo noturno: aprovado.")
