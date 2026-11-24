#!/usr/bin/env python3
"""Contrato estático da segurança: tela de bloqueio, PIN e biometria (ajuste 078).

Prova por leitura o que dá para provar sem aparelho: o PIN nunca é guardado,
a verificação é por derivação com sal, as tentativas têm limite, a biometria usa
o prompt do Android e a recuperação exige a credencial do próprio aparelho.
O que depende de sensor físico e de tela real continua fora daqui.
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


core = ler(APP / "lib" / "core" / "seguranca.dart")
store = ler(APP / "lib" / "services" / "bloqueio_store.dart")
biometria = ler(APP / "lib" / "services" / "biometria_service.dart")
tela = ler(APP / "lib" / "services" / "bloqueio_page.dart")
gate = ler(APP / "lib" / "services" / "bloqueio_gate.dart")
configuracao = ler(APP / "lib" / "services" / "seguranca_page.dart")
main = ler(APP / "lib" / "main.dart")
pages = ler(APP / "lib" / "pages.dart")
manifesto = ler(APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml")
prepare = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-19_078-seguranca.md"
teste_puro = APP / "tool" / "seguranca_test.dart"
teste_tela = APP / "test" / "bloqueio_page_test.dart"

kotlin = {}
for nome in ("JarvisBiometria.kt", "MainActivity.kt"):
    origem = KOTLIN_TRACKED / nome
    if not origem.is_file():
        origem = KOTLIN_BUILD / nome
    if not origem.is_file():
        falhas.append(f"{nome} não encontrado")
        kotlin[nome] = ""
    else:
        kotlin[nome] = ler(origem)

# 1. Núcleo puro, sem Flutter nem rede.
for proibido in ("package:flutter", "package:http", "dart:io", "WebView"):
    exigir(proibido not in core, f"núcleo com dependência indevida: {proibido}")
for termo in ("avaliarPin", "PoliticaPin", "derivarPin", "compararDigest",
              "novoSalt", "tentativasAntesDeEspera", "esperaPorTentativas",
              "avaliarTentativa", "deveBloquearAoVoltar", "ConfigBloqueio",
              "PortaBloqueio", "BiometriaStatus", "EstadoBiometria"):
    exigir(termo in core, f"núcleo sem {termo}")
exigir("Hmac(sha256" in core, "derivação não usa HMAC-SHA256")
exigir("iteracoesPadrao" in core and "24000" in core, "custo da derivação não declarado")
exigir("diferenca |= a[i] ^ b[i]" in core, "comparação não é em tempo constante")
exigir("if (a.isEmpty || a.length != b.length) return false;" in core,
       "digest vazio poderia passar como igual")
for politica in ("repetido", "sequencia", "comum", "naoNumerico"):
    exigir(politica in core, f"política sem o caso {politica}")

# 2. Nada de PIN em texto no armazenamento.
exigir("jarvis.seguranca." in store, "cofre sem prefixo próprio")
exigir("jarvis.bloqueio.v1" in store, "configuração sem chave versionada")
exigir("FlutterSecureStorage" in store, "digest não vai para o cofre seguro")
exigir("_chaveDigest" in store and "_chaveSal" in store, "sal ou digest ausentes")
exigir("hexDe(digest)" in store and "hexDe(sal)" in store,
       "sal e digest não são gravados como hex")
exigir("pin.trim(), sal" in store, "verificação não deriva o PIN com o sal")
exigir("implements PortaBloqueio" in store, "store não cumpre o contrato da porta")

# 3. Tela de bloqueio: teclado, tentativas, biometria e recuperação.
for chave in ("bloqueio-tecla-$n", "bloqueio-tecla-0", "bloqueio-apagar",
              "bloqueio-desbloquear", "bloqueio-biometria", "bloqueio-esqueci",
              "bloqueio-pin-exibido", "bloqueio-erro", "bloqueio-espera"):
    exigir(f"ValueKey('{chave}')" in tela or f"ValueKey('{chave}" in tela,
           f"tela sem a chave {chave}")
for termo in ("Esqueci o PIN", "credencial do próprio aparelho",
              "não vê o que você digita", "Usar biometria", "Aguarde"):
    exigir(termo in tela, f"tela sem o texto: {termo}")
exigir("obscureText: true" in tela, "PIN novo não é mascarado no diálogo")
exigir("List.filled(digitos, '●')" in tela, "PIN não é exibido como pontos")
exigir("aoDesbloquear" in tela, "tela não avisa o gate do desbloqueio")

# 4. Configurações: definir, alterar, desligar e biometria.
for chave in ("seguranca-definir-pin", "seguranca-alterar-pin", "seguranca-desligar",
              "seguranca-biometria", "seguranca-espera", "seguranca-bloquear-agora",
              "seguranca-pin-atual", "seguranca-confirmar-pin", "seguranca-aviso"):
    exigir(f"ValueKey('{chave}')" in configuracao or f"ValueKey('{chave}" in configuracao,
           f"configuração sem a chave {chave}")
for termo in ("PBKDF2-HMAC-SHA256", "não é guardado", "Aparelho", "O Android só devolve"):
    exigir(termo in configuracao or termo in tela, f"texto de transparência ausente: {termo}")
exigir("alterarPin" in configuracao and "desligar" in configuracao,
       "configuração não exige o PIN atual")
exigir("abrir-seguranca" in pages, "navegação para a segurança ausente")

# 5. Gate: bloqueia ao abrir e ao voltar, sem prender o app quando desligado.
exigir("WidgetsBindingObserver" in gate, "gate não observa o ciclo de vida")
exigir("deveBloquearAoVoltar" in gate, "gate não respeita o tempo escolhido")
exigir("BloqueioGate" in main, "app não está envolvido pelo gate")
exigir("controladorBloqueio" in gate and "controladorBloqueio" in configuracao,
       "bloquear agora não conversa com o gate")

# 6. Biometria nativa, sem dependência nova e sem dado biométrico.
biometria_kt = kotlin["JarvisBiometria.kt"]
for termo in ("BiometricPrompt", "FingerprintManager", "KeyguardManager",
              "createConfirmDeviceCredentialIntent", "com.jarvis.nova/biometria"):
    exigir(termo in biometria_kt, f"Kotlin sem {termo}")
exigir("JarvisBiometria.tratarResultado" in kotlin["MainActivity.kt"],
       "MainActivity não entrega o resultado da credencial")
exigir("JarvisBiometria(this).registrar(flutterEngine)" in kotlin["MainActivity.kt"],
       "canal da biometria não registrado")
exigir("USE_BIOMETRIC" in manifesto, "manifesto sem USE_BIOMETRIC")
exigir("USE_FINGERPRINT" in manifesto, "manifesto sem USE_FINGERPRINT")
exigir("USE_BIOMETRIC" in prepare, "script de preparação não repõe USE_BIOMETRIC")
exigir("JarvisBiometria.kt" in prepare, "script de preparação não copia o Kotlin novo")
exigir("biometric:" not in pubspec, "dependência nativa extra desnecessária")
exigir("androidx.biometric" not in ler(APP / "android" / "app" / "build.gradle.kts"),
       "dependência androidx.biometric inesperada")
for arquivo, texto in kotlin.items():
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")

# 7. Testes registrados.
exigir(teste_puro.is_file(), "teste puro de segurança ausente")
exigir(teste_tela.is_file(), "teste de widget da tela de bloqueio ausente")
if teste_puro.is_file():
    exigir(ler(teste_puro).count("assert(") >= 30, "teste puro com poucas verificações")
exigir("tool/seguranca_test.dart" in ler(RAIZ / "tests" / "test_dart_core.py"),
       "teste puro fora do núcleo Dart")
script = json.loads(ler(RAIZ / "package.json"))
exigir("tests/test_seguranca_flutter.py" in script["scripts"]["test:all"],
       "contrato da segurança fora da suíte")
exigir("crypto:" in pubspec, "dependência crypto ausente para a derivação")

# 8. Versão e documentação.
exigir("version: 1.89.2+18902" in pubspec, "versão não atualizada para 1.65.0")
exigir("1.65.0" in changelog and "1.66.0" in changelog, "CHANGELOG sem 1.65.0")
exigir("Tela de bloqueio" in inventario, "inventário sem a tela de bloqueio")
exigir(relatorio.is_file(), "relatório 078 ausente")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 5. Não verificado",
                  "## 6. Limitações"):
        exigir(secao in texto, f"relatório 078 sem a seção {secao}")

if falhas:
    print("FALHAS no contrato da segurança:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da segurança: aprovado.")
