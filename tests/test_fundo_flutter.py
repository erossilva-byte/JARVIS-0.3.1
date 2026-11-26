#!/usr/bin/env python3
"""Contrato estático do segundo plano de verdade (Fase 12, ajuste 077).

Prova por leitura o que dá para provar sem aparelho: o serviço executa o comando
sem abrir a tela, a autorização de sobreposição é exigida antes de abrir outro
app, o reconhecimento é só o offline do Android e a tela mostra pendências reais.
O que depende de voz, microfone e Android real continua não medido aqui.
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
    return caminho.read_text(encoding="utf-8")


core = ler(APP / "lib" / "core" / "fundo.dart")
servico = ler(APP / "lib" / "services" / "fundo_service.dart")
pagina = ler(APP / "lib" / "services" / "segundo_plano_page.dart")
pages = ler(APP / "lib" / "pages.dart")
teste_puro = APP / "tool" / "fundo_test.dart"
teste_tela = APP / "test" / "segundo_plano_page_test.dart"
manifesto = ler(APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml")
prepare_sistema = ler(APP / "tool" / "prepare_android_sistema.py")
prepare_kws = ler(APP / "tool" / "prepare_android_kws.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-19_077-segundo-plano.md"

kotlin = {}
for nome in ("JarvisFundo.kt", "JarvisEscutaFundo.kt", "JarvisFundoCanal.kt",
             "KwsForegroundService.kt", "MainActivity.kt"):
    origem = KOTLIN_TRACKED / nome
    if not origem.is_file():
        origem = KOTLIN_BUILD / nome
    if not origem.is_file():
        falhas.append(f"{nome} não encontrado")
        kotlin[nome] = ""
    else:
        kotlin[nome] = ler(origem)

# 1. Núcleo puro: sem Flutter, sem rede, sem promessa pronta por omissão.
for proibido in ("package:flutter", "package:http", "dart:io", "WebView"):
    exigir(proibido not in core, f"núcleo com dependência indevida: {proibido}")
for termo in ("class EstadoFundo", "fundoPronto", "pendenciasFundo", "resumoFundo",
              "idadeUltimaAcao", "acoesEmSegundoPlano", "limitesSegundoPlano",
              "ponteDisponivel", "class ResultadoFundo"):
    exigir(termo in core, f"núcleo sem {termo}")
exigir("estado.servicoAtivo &&" in core and "estado.modoSemTela &&" in core
       and "estado.podeAbrirApps" in core,
       "fundoPronto não exige serviço, modo sem tela e autorização juntos")
exigir("modoSemTela: false,\n    podeAbrirApps: false" in core,
       "estado vazio não começa desligado")

# 2. Canal com estado real e falha explícita fora do Android.
exigir("com.jarvis.nova/fundo" in servico, "serviço sem o canal do segundo plano")
for metodo in ("estado", "definirModoSemTela", "abrirAjusteSobreposicao",
               "limparHistorico", "executarTexto"):
    exigir(f"'{metodo}'" in servico, f"serviço sem o método {metodo}")
exigir("MissingPluginException" in servico and "EstadoFundo.vazio" in servico,
       "fora do Android o serviço deveria devolver estado vazio, não sucesso")
exigir("on PlatformException" in servico, "erro nativo não é tratado")

# 3. Tela mostra pendências, limites e testa comando.
for chave in ("fundo-modo-sem-tela", "fundo-autorizar-sobreposicao", "fundo-comando",
              "fundo-executar", "fundo-atualizar", "fundo-ultima-acao",
              "fundo-modo-cartao", "fundo-limpar-historico"):
    exigir(f"ValueKey('{chave}')" in pagina, f"tela sem a chave {chave}")
for termo in ("FALTA PARA FUNCIONAR", "LIMITES REAIS", "O QUE ELE FAZ SEM A TELA",
              "Exibir sobre outros apps", "limitesSegundoPlano"):
    exigir(termo in pagina, f"tela sem o texto/limite: {termo}")
for termo in ("reiniciar", "offline", "Não Perturbe"):
    exigir(termo in core, f"limite não declarado no núcleo: {termo}")
exigir("abrir-segundo-plano" in pages, "navegação para a tela ausente")
exigir("SegundoPlanoPage" in pages, "páginas não abrem a tela real")

# 4. Kotlin: modo sem tela decide o caminho e nada abre app sem autorização.
servico_kt = kotlin["KwsForegroundService.kt"]
fundo_kt = kotlin["JarvisFundo.kt"]
exigir("JarvisFundo.modoSemTela(applicationContext)" in servico_kt,
       "serviço não consulta o modo sem tela")
exigir(servico_kt.index("iniciarComandoEmSegundoPlano")
       < servico_kt.index("getLaunchIntentForPackage"),
       "serviço abre a tela antes de tentar o comando em segundo plano")
for termo in ("JarvisEscutaFundo", "JarvisFundo.interpretar", "JarvisFundo.executar",
              "voz?.falar", "avisarAtivo", "IMPORTANCE_HIGH", "setTimeoutAfter"):
    exigir(termo in servico_kt, f"serviço sem {termo}")
exigir(servico_kt.count("getLaunchIntentForPackage") >= 1,
       "caminho antigo (abrir a tela) removido sem necessidade")
exigir("fun modoSemTela(" in fundo_kt and "CHAVE_MODO_SEM_TELA" in fundo_kt,
       "preferência do modo sem tela ausente")
exigir("Settings.canDrawOverlays" in fundo_kt, "sem checagem de sobreposição")
exigir(fundo_kt.index("podeAbrirApps(context)")
       < fundo_kt.index("context.startActivity(abertura)"),
       "abrir app sem conferir a autorização antes")
exigir("Settings" in fundo_kt, "executor não usa Settings do Android")
exigir("PREFS = \"jarvis_fundo\"" in fundo_kt, "preferências do segundo plano sem nome")
exigir("Nenhum app instalado" in fundo_kt and "Encontrei mais de um app" in fundo_kt,
       "executor não trata app ausente nem ambiguidade")
exigir("Shell" not in fundo_kt and "exec(" not in fundo_kt,
       "executor não pode rodar shell")

# 5. Reconhecimento só offline, sem fallback de nuvem.
escuta_kt = kotlin["JarvisEscutaFundo.kt"]
for termo in ("createOnDeviceSpeechRecognizer", "EXTRA_PREFER_OFFLINE",
              "isOnDeviceRecognitionAvailable", "LIMITE_MS", "pt-BR"):
    exigir(termo in escuta_kt, f"escuta sem {termo}")
exigir("createSpeechRecognizer" not in escuta_kt,
       "escuta usa reconhecedor que pode ir para a nuvem")
exigir("nada foi enviado para a nuvem" in escuta_kt,
       "escuta não declara que não envia áudio")

# 5b. Comando curto com folga e pacote offline ausente explicado.
for termo in ("EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS",
              "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS",
              "ERROR_LANGUAGE_NOT_SUPPORTED", "ERROR_LANGUAGE_UNAVAILABLE"):
    exigir(termo in escuta_kt, f"escuta sem {termo}")

# 5c. Sem autorização de sobreposição o microfone do segundo plano continua vivo.
exigir("!JarvisFundo.podeAbrirApps(applicationContext)" in servico_kt,
       "serviço só escuta no segundo plano com a sobreposição autorizada")
exigir("ACTION_PAUSE" in servico_kt and "pausarMotor" in servico_kt,
       "serviço não solta o microfone para o comando")
exigir("marcarComandoAtivo" in servico_kt and "isCommandActive" in servico_kt,
       "serviço não publica que o comando está com o microfone")
exigir("Autorizar abrir apps" in servico_kt,
       "aviso sem o botão que autoriza abrir apps")

# 6. Canal registrado e permissão no manifesto.
exigir("JarvisFundoCanal(this).registrar(flutterEngine)" in kotlin["MainActivity.kt"],
       "MainActivity não registra o canal do segundo plano")
exigir("com.jarvis.nova/fundo" in kotlin["JarvisFundoCanal.kt"],
       "canal Kotlin sem o identificador")
exigir("SYSTEM_ALERT_WINDOW" in manifesto, "manifesto sem SYSTEM_ALERT_WINDOW")
exigir("SYSTEM_ALERT_WINDOW" in prepare_sistema,
       "script de preparação não repõe a permissão")
for nome in ("JarvisFundo.kt", "JarvisFundoCanal.kt", "JarvisEscutaFundo.kt"):
    exigir(nome in prepare_sistema, f"prepare_android_sistema.py não copia {nome}")
    exigir(nome in prepare_kws, f"prepare_android_kws.py não copia {nome}")

# 7. Sem atalhos proibidos.
for arquivo, texto in kotlin.items():
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")
exigir(not list(APP.glob("android/*.java")), "arquivo .java novo no runner Android")

# 8. Testes registrados.
exigir(teste_puro.is_file(), "teste puro do segundo plano ausente")
exigir(teste_tela.is_file(), "teste de widget do segundo plano ausente")
if teste_puro.is_file():
    exigir(ler(teste_puro).count("assert(") >= 20, "teste puro com poucas verificações")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
exigir("tool/fundo_test.dart" in nucleo, "teste puro fora do núcleo Dart")
script = json.loads(ler(RAIZ / "package.json"))
exigir("tests/test_fundo_flutter.py" in script["scripts"]["test:all"],
       "contrato do segundo plano fora da suíte")

# 9. Versão e documentação.
exigir("version: 1.111.0+111100" in pubspec, "versão não atualizada para 1.64.0")
exigir("1.64.0" in changelog, "CHANGELOG sem 1.64.0")
exigir("Segundo plano" in inventario or "segundo plano" in inventario,
       "inventário sem a seção do segundo plano")
exigir(relatorio.is_file(), "relatório 077 ausente")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 077 sem a seção {secao}")

if falhas:
    print("FALHAS no contrato do segundo plano:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do segundo plano: aprovado.")
