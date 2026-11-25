#!/usr/bin/env python3
"""Contrato do segundo plano sem o app aberto (ajuste 089, versão 1.75.1).

O ajuste 085 levava a pergunta livre ao provedor por uma ponte com o Flutter,
mas só enquanto o motor do app estava vivo. Com o app encerrado, o Android
derrubava esse motor e toda pergunta — "como está tudo, Jarvis", "me fale sobre
culinária" — terminava em "abra o JARVIS e pergunte de novo".

Agora a ponte sobe um **motor sem tela** do próprio serviço, com a entrada
`mainFundo`, que usa o mesmo provedor, as mesmas chaves e a mesma
personalidade. Este contrato prende essa ligação sem aparelho:

1. a entrada Dart existe e não abre tela;
2. a ponte Kotlin cria o motor só quando ninguém está atendendo, espera o canal
   registrar e desliga o motor depois de ocioso ou no fim do serviço;
3. o serviço distingue falta de provedor de falha de tempo, em vez de mandar o
   usuário abrir o app para tudo;
4. nenhuma permissão nova, nenhum shell e nenhuma chave duplicada no Kotlin.
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


ponte_kt = ler(KOTLIN / "JarvisPonteIa.kt")
servico_kt = ler(KOTLIN / "KwsForegroundService.kt")
atividade = ler(KOTLIN / "MainActivity.kt")
principal = ler(LIB / "main.dart")
ponte_dart = ler(LIB / "services" / "ponte_ia_fundo.dart")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
manifesto = ler(APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_089-segundo-plano-sem-app-aberto.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.93.0+19300" in pubspec, "versão não atualizada para 1.75.1")
exigir("1.75.1" in changelog, "CHANGELOG sem o ajuste 1.75.1")
exigir("tests/test_fundo_motor.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 089 ausente")

# 2. Entrada Dart sem tela.
exigir("@pragma('vm:entry-point')" in principal,
       "main.dart sem marcação de entrypoint")
exigir("Future<void> mainFundo() async" in principal,
       "main.dart sem a entrada mainFundo")
trecho = principal.split("mainFundo() async")[-1]
exigir("PonteIaFundo.ligar();" in trecho,
       "mainFundo não liga a ponte de IA")
exigir("runApp(" not in trecho.split("}")[0],
       "mainFundo abre tela em vez de ficar em segundo plano")
exigir("package:jarvis_nova/main.dart" in ponte_kt and
       "mainFundo" in ponte_kt,
       "ponte Kotlin não aponta para a entrada mainFundo")

# 3. A ponte sobe, espera e desliga o motor sem tela.
for termo in ("FlutterEngine(", "DartEntrypoint(", "executeDartEntrypoint",
              "subirMotor(", "esperarCanal(", "motorProprio",
              "OCIOSIDADE_MS", "destroy()", "fun encerrar()"):
    exigir(termo in ponte_kt, f"JarvisPonteIa.kt sem {termo}")
exigir("fun perguntar(\n        contexto: Context," in ponte_kt or
       "contexto: Context," in ponte_kt,
       "ponte não recebe o contexto para subir o motor")
exigir("if (canal == null) subirMotor(app)" in ponte_kt,
       "ponte sobe motor mesmo com o app atendendo")
exigir("MOTIVO_INDISPONIVEL" in ponte_kt and "MOTIVO_TEMPO" in ponte_kt,
       "ponte não separa falha de tempo de canal indisponível")
exigir("notImplemented()" in ponte_kt and "tentativas" in ponte_kt,
       "ponte não espera o Dart registrar o atendimento")
exigir("JarvisPonteIa.registrar(flutterEngine)" in atividade,
       "Activity continua registrando a ponte do app")
exigir("JarvisPonteIa.encerrar()" in servico_kt,
       "fim do serviço não desliga o motor sem tela")

# 4. O serviço fala o motivo certo, sem mandar abrir o app para tudo.
exigir("JarvisPonteIa.perguntar(applicationContext, texto)" in servico_kt,
       "serviço não passa o contexto à ponte")
exigir('"sem_provedor" ->' in servico_kt,
       "falta de provedor não é explicada")
exigir('"tempo" ->' in servico_kt and "demorou demais" in servico_kt,
       "demora do provedor não é explicada")
exigir("O app precisa estar aberto" not in servico_kt,
       "o aviso antigo de 'abra o app' continua no serviço")
exigir("Verifique a conexão" in servico_kt,
       "falha sem provedor e falha de rede não são distinguidas")

# 5. Mesma chave, sem duplicar provedor no Kotlin.
for proibido in ("Bearer ", "api_key", "Authorization", "openrouter.ai",
                 "api.groq.com", "HttpURLConnection", "OkHttpClient",
                 "openConnection("):
    exigir(proibido not in ponte_kt,
           f"JarvisPonteIa.kt duplica provedor ou abre rede ({proibido})")
exigir("GlobalScope" not in ponte_kt,
       "JarvisPonteIa.kt usa GlobalScope")
exigir("Runtime.getRuntime().exec" not in ponte_kt and
       "Runtime.getRuntime().exec" not in servico_kt,
       "segundo plano executa shell")
exigir("PackageManager" not in ponte_kt,
       "ponte mexe em pacotes sem necessidade")

# 6. A ponte Dart já sinalizava falta de provedor; o serviço agora usa isso.
exigir("code: 'sem_provedor'" in ponte_dart,
       "ponte Dart perdeu o código sem_provedor")
exigir("firstConfiguredProvider()" in ponte_dart,
       "ponte Dart não usa o provedor configurado")

# 7. Nenhuma permissão nova no manifesto.
# BIND_ACCESSIBILITY_SERVICE não é pedida pelo app: ela aparece só como exigência
# do serviço dedicado (ajuste 095), e quem a concede é o próprio Android.
for perigosa in ("WRITE_SETTINGS",
                 "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
                 "FOREGROUND_SERVICE_CAMERA",
                 "BIND_ACCESSIBILITY_SERVICE"):
    exigir(f'uses-permission android:name="android.permission.{perigosa}"' not in manifesto,
           f"manifesto ganhou permissão nova ({perigosa})")

# 8. Documentação.
exigir("089" in inventario, "inventário sem a seção do ajuste 089")
exigir("mainFundo" in inventario or "motor sem tela" in inventario,
       "inventário não explica o motor sem tela")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 089 sem a seção {secao}")
    for termo in ("motor sem tela", "mainFundo", "provedor"):
        exigir(termo in texto, f"relatório 089 sem {termo}")

if falhas:
    print("FALHAS no contrato do segundo plano sem app aberto:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do segundo plano sem app aberto: aprovado.")
