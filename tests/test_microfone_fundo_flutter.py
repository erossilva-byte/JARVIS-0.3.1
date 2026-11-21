#!/usr/bin/env python3
"""Contrato estático do microfone do comando (ajuste 080).

O relato do aparelho foi: falar depois da palavra de ativação e receber
“Não consegui entender o comando. Tente falar novamente.” sem ter dito nada
estranho. Aqui ficam presas as três causas tratadas no código, que dá para
conferir sem aparelho:

1. a tela religava o detector local por cima do reconhecedor do comando e os
   dois microfones disputavam a captura (o segundo recebia silêncio);
2. o comando curto era cortado cedo demais e voltava como `ERROR_NO_MATCH`;
3. quando o Android bloqueia trazer a tela do app para a frente (sem “Exibir
   sobre outros apps”), o serviço tentava abrir a tela e o microfone ficava sem
   comando nenhum.

Também confirma que o reconhecimento continua sendo **só o offline do Android**:
nada de `createSpeechRecognizer`, nada de nuvem. Fala real, tempo de silêncio e
o pacote pt-BR do aparelho continuam não medidos aqui.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
KOTLIN_TRACKED = APP / "android"
KOTLIN_BUILD = APP / "android" / "app" / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


def kotlin(nome: str) -> str:
    origem = KOTLIN_TRACKED / nome
    if not origem.is_file():
        origem = KOTLIN_BUILD / nome
    return ler(origem)


principal = kotlin("MainActivity.kt")
servico = kotlin("KwsForegroundService.kt")
escuta = kotlin("JarvisEscutaFundo.kt")
ponte = ler(APP / "lib" / "services" / "kws_bridge.dart")
tela = ler(APP / "lib" / "home_screen.dart")
controlador = ler(APP / "lib" / "services" / "kws_controller.dart")
core = ler(APP / "lib" / "core" / "fundo.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-20_080-microfone-e-segundo-plano.md"

# 1. Versão e suíte.
exigir("version: 1.79.0+17900" in pubspec, "versão não atualizada para 1.68.0")
exigir("1.67.0" in changelog, "CHANGELOG sem 1.67.0")
exigir("tests/test_microfone_fundo_flutter.py" in pacote,
       "contrato do microfone fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 080 ausente")

# 2. Um microfone por vez: o comando reserva a captura e a tela não religa o detector.
for termo in ("marcarComandoAtivo(true)", "marcarComandoAtivo(false)",
              "KwsForegroundService.pausarMotor(this)",
              "if (KwsForegroundService.isServiceRunning()) KwsForegroundService.pausarMotor(this)"):
    exigir(termo in principal, f"MainActivity sem {termo}")
exigir('"comandoAtivo"' in principal, "status não publica o comando em andamento")
exigir("KwsForegroundService.isCommandActive()" in principal,
       "start do detector não checa o comando em andamento")
exigir("comandoAtivo" in ponte and "map['comandoAtivo'] == true" in ponte,
       "KwsStatus não lê comandoAtivo do Android")
exigir("status.comandoAtivo" in tela,
       "a tela religa o detector enquanto o comando está com o microfone")
exigir(principal.index("KwsForegroundService.marcarComandoAtivo(true)")
       < principal.index("recognizer.startListening(request)"),
       "comando abre o microfone antes de reservá-lo")

# 3. Nova tentativa automática só para silêncio/“não entendi”.
exigir("tentativaValeRepetir" in principal, "sem decisão de repetir a escuta")
for termo in ("SpeechRecognizer.ERROR_NO_MATCH", "SpeechRecognizer.ERROR_SPEECH_TIMEOUT"):
    exigir(termo in principal.split("private fun tentativaValeRepetir")[1][:400],
           f"repetição sem {termo}")
exigir("tentativasComando < 1" in principal, "repetição sem limite de tentativas")
exigir("Não entendi. Fale de novo, por favor" in principal,
       "repetição sem aviso ao usuário")

# 4. Folga de tempo e pacote offline explicado, sem fallback de nuvem.
for termo in ("EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS",
              "EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS",
              "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS"):
    exigir(termo in principal and termo in escuta, f"tempo de escuta sem {termo}")
for termo in ("ERROR_LANGUAGE_NOT_SUPPORTED", "ERROR_LANGUAGE_UNAVAILABLE"):
    exigir(termo in principal, f"pacote offline ausente sem tratamento: {termo}")
exigir("Reconhecimento de fala offline" in principal,
       "mensagem não diz onde instalar o pacote offline")
for arquivo, texto in (("MainActivity.kt", principal), ("JarvisEscutaFundo.kt", escuta)):
    exigir("createSpeechRecognizer(" not in texto,
           f"{arquivo} usa reconhecedor que pode ir para a nuvem")
    exigir("createOnDeviceSpeechRecognizer" in texto,
           f"{arquivo} não usa o reconhecedor do aparelho")

# 5. Serviço solta o microfone e mantém o comando sem a tela na frente.
exigir("ACTION_PAUSE" in servico and "liberarMicrofone(" in servico,
       "serviço não libera o AudioRecord para o comando")
exigir("comandoAtivo = false" in servico, "serviço não limpa o estado do comando")
exigir("!JarvisFundo.podeAbrirApps(applicationContext)" in servico,
       "serviço só ouve no segundo plano com a sobreposição autorizada")
exigir("Autorizar abrir apps" in servico,
       "aviso sem ação para autorizar abrir apps")

# 6. Texto de limite atualizado: microfone vale mesmo sem sobreposição.
exigir("lanterna e volume" in core,
       "limite não explica que lanterna e volume funcionam sem sobreposição")

# 7. Sem atalhos proibidos.
for arquivo, texto in (("MainActivity.kt", principal), ("KwsForegroundService.kt", servico),
                       ("JarvisEscutaFundo.kt", escuta)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")

# 8. Inventário e relatório.
exigir("microfone" in inventario.lower(), "inventário não cita o microfone")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 080 sem a seção {secao}")
    for termo in ("microfone", "segundo plano", "abrir"):
        exigir(termo in texto.lower(), f"relatório 080 sem {termo}")

if falhas:
    print("FALHAS no contrato do microfone:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do microfone: aprovado.")
