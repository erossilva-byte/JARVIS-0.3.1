#!/usr/bin/env python3
"""Contrato estático do microfone e da resposta (ajuste 082, versão 1.69.0).

O relato no aparelho continuou o mesmo: chamar o JARVIS, falar e receber
“Não consegui entender o comando”. O que faltava não era o tempo de silêncio nem
a segunda escuta (080), e sim a **entrega do microfone**: o pedido de pausa ao
detector era um Intent, entregue depois, e o reconhecedor abria a captura com o
AudioRecord do detector ainda gravando. Dois microfones abertos devolvem
silêncio, e o Android responde ERROR_NO_MATCH/ERROR_AUDIO.

Aqui ficam presas, sem aparelho, as regras deste ajuste:

1. a entrega do microfone é confirmada (não é mais “pedido e espero”);
2. a espera acontece fora da thread principal e tem prazo;
3. microfone ocupado e captura vazia também valem nova tentativa;
4. o que já foi reconhecido em parcial não é jogado fora;
5. no segundo plano, uma falha repetível tenta de novo antes de desistir;
6. a palavra de ativação só volta **depois** que a resposta termina de ser falada;
7. fala fraca ganha ganho automático antes do detector.

Continua valendo: só o reconhecedor offline do Android, sem nuvem, sem shell e
sem GlobalScope. Voz real e o aparelho físico seguem fora deste contrato.
"""

from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
KOTLIN = APP / "android"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


principal = ler(KOTLIN / "MainActivity.kt")
servico = ler(KOTLIN / "KwsForegroundService.kt")
escuta = ler(KOTLIN / "JarvisEscutaFundo.kt")
voz = ler(KOTLIN / "JarvisVoz.kt")
motor = ler(RAIZ / "JarvisKwsEngine.java")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-20_082-microfone-e-resposta.md"

# 1. Versão, changelog, suíte e relatório.
exigir("version: 1.85.0+18500" in pubspec, "versão não atualizada para 1.69.0")
exigir("1.69.0" in changelog and "microfone" in changelog.lower(),
       "CHANGELOG sem o bloco 1.69.0 do microfone")
exigir("tests/test_microfone_confiavel_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 082 ausente")

# 2. Entrega do microfone confirmada, com prazo e fora da thread principal.
for termo in ("pararEAguardar(", "microfoneLivre()"):
    exigir(termo in motor, f"JarvisKwsEngine.java sem {termo}")
exigir("SystemClock.uptimeMillis()" in motor,
       "espera do microfone sem prazo medido")
exigir("if (microfoneLivre()) return true;" in motor,
       "espera do microfone não confirma o fechamento do AudioRecord")
for termo in ("motorAtual", "fun liberarMicrofone(", "pararEAguardar(esperaMs)"):
    exigir(termo in servico, f"KwsForegroundService.kt sem {termo}")
exigir("motor?.stop()" not in servico,
       "serviço ainda chama stop() sem esperar o AudioRecord fechar")
for termo in ("abrirMicrofoneDoComando()", "iniciarEscutaDoComando()",
              "KwsForegroundService.liberarMicrofone(",
              "FOLGA_DEPOIS_DO_MICROFONE_MS", "FOLGA_LONGA_DO_MICROFONE_MS"):
    exigir(termo in principal, f"MainActivity.kt sem {termo}")
exigir("Thread {\n            val livre = KwsForegroundService.liberarMicrofone(" in principal,
       "espera do microfone na thread principal (travaria a tela)")

# 3. Ordem: reserva, libera, confirma, só então abre o reconhecedor.
reserva = principal.index("KwsForegroundService.marcarComandoAtivo(true)")
entrega = principal.index("KwsForegroundService.liberarMicrofone(")
abertura = principal.index("iniciarEscutaDoComando()")
escuta_aberta = principal.index("recognizer.startListening(request)")
exigir(reserva < entrega < abertura < escuta_aberta,
       "comando abre o microfone antes de confirmar que o detector o soltou")

# 4. Repetição também para microfone ocupado e captura vazia.
trecho_repetir = principal.split("private fun tentativaValeRepetir")[1][:600]
for termo in ("SpeechRecognizer.ERROR_NO_MATCH", "SpeechRecognizer.ERROR_SPEECH_TIMEOUT",
              "SpeechRecognizer.ERROR_AUDIO", "SpeechRecognizer.ERROR_RECOGNIZER_BUSY"):
    exigir(termo in trecho_repetir, f"repetição sem {termo}")
exigir("atrasoRepeticao(error)" in principal,
       "repetição não escolhe folga conforme o erro")
exigir("-> 800L" in principal, "microfone ocupado não ganha folga maior")

# 5. Parcial já reconhecido não é descartado.
for arquivo, texto, marca in (("MainActivity.kt", principal, "melhorParcialComando"),
                              ("JarvisEscutaFundo.kt", escuta, "melhorParcial")):
    exigir(marca in texto, f"{arquivo} não guarda o parcial reconhecido")
exigir("if (parcial.length >= 3)" in principal,
       "comando parcial não é aproveitado no app aberto")
exigir("if (parcial.length >= 3)" in escuta,
       "comando parcial não é aproveitado no segundo plano")

# 6. Segundo plano: repetição decidida por erro, sem falar por cima do microfone.
for termo in ("onErroRepetivel", "tentativasFundo < 1", "ouvirComandoFundo()"):
    exigir(termo in servico, f"serviço sem {termo}")
exigir("valeRepetir" in escuta, "escuta do fundo não classifica o erro")
exigir("fun onErroRepetivel" in escuta or "onErroRepetivel(codigo: Int" in escuta,
       "interface da escuta sem erro repetível")
repeticao = servico.split("override fun onErroRepetivel")[1][:700]
exigir("voz?.falar" not in repeticao,
       "serviço fala durante a repetição e o microfone ouve a própria voz")

# 7. A palavra de ativação volta depois da resposta.
exigir("setOnUtteranceProgressListener" in voz and "onDone" in voz,
       "síntese de voz não avisa quando termina")
exigir("aoTerminar: (() -> Unit)? = null" in voz,
       "falar() não aceita o aviso de fim")
exigir("voz?.falar(mensagem) {" in servico,
       "serviço não espera a resposta terminar para voltar a ouvir")
exigir("atrasoResposta(" in servico,
       "sem confirmação da síntese não há espera proporcional")

# 8. Detector: não religa com comando em curso e trata fala fraca.
exigir("if (comandoAtivo || comandoEmAndamento)" in servico,
       "detector pode religar durante o comando")
exigir("aplicarGanho(" in motor and "0.02 / rms" in motor,
       "detector sem ganho automático para fala fraca")

# 9. Sem atalhos proibidos e sem nuvem.
for arquivo, texto in (("MainActivity.kt", principal), ("KwsForegroundService.kt", servico),
                       ("JarvisEscutaFundo.kt", escuta), ("JarvisVoz.kt", voz),
                       ("JarvisKwsEngine.java", motor)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")
for arquivo, texto in (("MainActivity.kt", principal), ("JarvisEscutaFundo.kt", escuta)):
    exigir("createSpeechRecognizer(" not in texto,
           f"{arquivo} usa reconhecedor que pode ir para a nuvem")
    exigir("createOnDeviceSpeechRecognizer" in texto,
           f"{arquivo} não usa o reconhecedor do aparelho")

# 10. Documentação do bloco.
exigir("microfone" in inventario.lower(), "inventário não cita o microfone")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 082 sem a seção {secao}")
    for termo in ("microfone", "segundo plano", "resposta", "aparelho"):
        exigir(termo in texto.lower(), f"relatório 082 sem {termo}")

if falhas:
    print("FALHAS no contrato do microfone confiável:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do microfone confiável: aprovado.")
