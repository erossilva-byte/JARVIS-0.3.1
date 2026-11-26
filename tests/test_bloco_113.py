#!/usr/bin/env python3
"""Contrato do bloco 113 — voz mais rápida, tarefas por voz, mudo e modo de visita.

O que este contrato prende, sem aparelho:

1. os quatro perfis de timbre continuam com os mesmos valores no Dart e no
   Kotlin, e nenhum voltou ao ritmo antigo (0,88);
2. a conversa executa núcleo, música, mensagem e ligação antes de gastar
   provedor, e o pedido de núcleo vem antes do comando de abrir app;
3. o segundo plano entende música e núcleo flutuante, conferindo o estado real
   em vez de afirmar sucesso;
4. o botão de mudo da tela principal para o detector de palavra de verdade;
5. o modo de visita tem cabeçalho, sugestões e ajustes em cartões, sem perder as
   chaves que os testes usam;
6. versão, CHANGELOG e relatório acompanham a mudança.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"
ANDROID = APP / "android"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


timbre_dart = ler(LIB / "core" / "timbre_voz.dart")
timbre_kt = ler(ANDROID / "JarvisTimbre.kt")
nucleo_dart = ler(LIB / "core" / "pedido_nucleo.dart")
tarefas = ler(LIB / "services" / "tarefas_da_voz.dart")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
fundo_kt = ler(ANDROID / "JarvisFundo.kt")
home = ler(LIB / "home_screen.dart")
centro = ler(LIB / "command_center.dart")
visita = ler(LIB / "services" / "modo_visita_page.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-24_113-voz-mais-rapida-tarefas-e-mudo.md")

# 1. Perfis e paridade dos ritmos.
for perfil in ("grave", "natural", "agil", "rapida"):
    exigir(f'Perfil("{perfil}"' in timbre_kt,
           f"JarvisTimbre.kt sem o perfil {perfil}")
    exigir(f"id: '{perfil}'" in timbre_dart,
           f"timbre_voz.dart sem o perfil {perfil}")
exigir('Perfil("grave", "Grave", 0.72f, 1.12f)' in timbre_kt,
       "grave do Kotlin não está em 0,72 / 1,12")
exigir('Perfil("rapida", "Rápida", 1.0f, 1.6f)' in timbre_kt,
       "perfil rápido do Kotlin fora dos valores declarados")
for valor in ("1.12", "1.28", "1.45", "1.6"):
    exigir(valor in timbre_dart and valor in timbre_kt,
           f"ritmo {valor} sem paridade entre Dart e Kotlin")
exigir("0.88" not in timbre_kt and "0.88" not in timbre_dart,
       "o ritmo antigo 0,88 continua em algum perfil")
exigir("PADRAO = \"grave\"" in timbre_kt and "timbrePadrao = 'grave'" in timbre_dart,
       "perfil padrão diferente entre Dart e Kotlin")

# 2. Tarefas na conversa.
for termo in ("class TarefasDaVoz", "interpretarSpotify", "interpretarMensagem",
              "interpretarLigacao", "NucleoControle", "pedidoNucleo"):
    exigir(termo in tarefas, f"tarefas_da_voz.dart sem {termo}")
exigir("tocar|toca|toque|clicar|clica|clique" in tarefas and "tela" in tarefas,
       "tarefas_da_voz.dart não preserva a prioridade da automação de tela")
exigir("_tarefas.executar(texto)" in conversa,
       "a conversa não executa as tarefas do aparelho")
exigir("_tarefas.nucleo(nucleo, texto)" in conversa,
       "a conversa não executa o pedido de núcleo")
exigir(conversa.index("pedidoDeNucleo") < conversa.index("_comandos.executar"),
       "o pedido de núcleo precisa vir antes do comando de abrir app")
exigir(conversa.index("_comandos.executar") < conversa.index("_tarefas.executar"),
       "lanterna, volume e alarme devem ser decididos antes das tarefas")
for termo in ("ativar|ativa|ative", "desativar|desativa|desative"):
    exigir(termo in nucleo_dart, f"pedido_nucleo.dart sem {termo}")

# 3. Segundo plano.
for termo in ("enum class AcaoMidia", "Tipo.MIDIA", "Tipo.NUCLEO",
              "private fun midia(", "private fun nucleo(",
              "controladorMidia(", "skipToNext()", "skipToPrevious()",
              "JarvisNucleo.iniciar(", "JarvisNucleo.parar()"):
    exigir(termo in fundo_kt, f"JarvisFundo.kt sem {termo}")
exigir("não confirmou" in fundo_kt,
       "segundo plano não admite quando o app de música não confirmou")
exigir("sem_permissao" in fundo_kt,
       "segundo plano não explica a falta de “Exibir sobre outros apps”")

# 4. Mudo na tela principal.
for termo in ("bool mudo", "_alternarMudo", "jarvisKwsController.stop()",
              "jarvis-mudo", "if (mudo) return;"):
    exigir(termo in home, f"home_screen.dart sem {termo}")
exigir("mudo: mudo" in home and "onMute: _alternarMudo" in home,
       "a Central de Comando não recebe o mudo")
exigir("ValueKey('mute-button')" in centro and "onMute" in centro,
       "command_center.dart sem o botão de mudo")
exigir("JARVIS MUDO" in home,
       "a tela não avisa que o microfone está desligado")

# 5. Modo de visita.
for termo in ("MODO DE VISITA", "SEM DADOS", "visita-sugestao-",
              "visita-conversa", "visita-entrada", "visita-enviar",
              "visita-ajustes", "visita-bloquear", "ESTADO DO APARELHO",
              "PROMPT SUGERIDO", "O QUE ESTE MODO FAZ", "RadialGradient"):
    exigir(termo in visita, f"modo_visita_page.dart sem {termo}")
exigir("respostaVisita(" in visita and "ajustesVisita" in visita,
       "modo de visita deixou de usar as regras puras")

# 6. Versão, documentação e suíte.
exigir("version: 1.111.0+111100" in pubspec,
       "pubspec sem a versão 1.111.0+111100")
exigir("## 1.90.0" in changelog, "CHANGELOG sem o bloco 1.90.0")
for termo in ("voz mais veloz", "núcleo", "mudo", "modo de visita"):
    exigir(termo.lower() in changelog.lower(),
           f"CHANGELOG do 1.90.0 sem {termo}")
exigir(relatorio.is_file(), "relatório 113 ausente")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 5. O que não foi verificado"):
        exigir(secao in texto, f"relatório 113 sem a seção {secao}")
    for termo in ("1,12", "núcleo", "mudo", "modo de visita"):
        exigir(termo.lower() in texto.lower(), f"relatório 113 sem {termo}")
exigir("tests/test_bloco_113.py" in pacote,
       "contrato novo fora de package.json test:all")
try:
    scripts = json.loads(pacote).get("scripts", {})
    exigir("test_bloco_113" in scripts.get("test:all", ""),
           "test:all não executa o contrato do bloco 113")
except json.JSONDecodeError:
    falhas.append("package.json inválido")

if falhas:
    print("FALHAS no contrato do bloco 113:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do bloco 113: aprovado.")
