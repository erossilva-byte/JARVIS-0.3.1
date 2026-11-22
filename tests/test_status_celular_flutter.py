#!/usr/bin/env python3
"""Contrato estático do status do celular: bateria, memória, rede,
notificações e localização do aparelho (ajuste 079).

Prova por leitura o que dá para provar sem aparelho: as permissões de
localização estão no manifesto e no gerador, a leitura usa só o
`LocationManager` do Android (sem serviço de mapas), acontece apenas a pedido,
recusa coordenadas impossíveis e a tela mostra os dados reais com as seções de
status, notificações e localização. GPS de verdade, autorização do usuário e
precisão continuam fora daqui: só um aparelho físico resolve.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
ANDROID = APP / "android"
KOTLIN = ANDROID / "app" / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


core = ler(APP / "lib" / "core" / "localizacao.dart")
modelo = ler(APP / "lib" / "core" / "dispositivo.dart")
comandos = ler(APP / "lib" / "core" / "comandos_android.dart")
servico = ler(APP / "lib" / "services" / "aparelho_service.dart")
tela = ler(APP / "lib" / "services" / "dispositivo_page.dart")
executor = ler(APP / "lib" / "services" / "comandos_android_service.dart")
manifesto = ler(ANDROID / "app" / "src" / "main" / "AndroidManifest.xml")
prepare = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")

localizacao_kt = ler(KOTLIN / "JarvisLocalizacao.kt")
aparelho_kt = ler(KOTLIN / "JarvisAparelho.kt")
comandos_kt = ler(KOTLIN / "JarvisComandos.kt")

# 1. Versão, changelog e relatório do ajuste.
exigir("version: 1.86.0+18600" in pubspec, "versão não atualizada para 1.66.0")
exigir("1.66.0" in changelog, "CHANGELOG sem 1.66.0")
exigir(
    (RAIZ / "docs" / "relatorios" / "2026-11-19_079-status-celular.md").is_file(),
    "relatório 079 ausente",
)

# 2. Permissões de localização no manifesto e no gerador do Android.
for permissao in (
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
):
    exigir(permissao in manifesto, f"{permissao} ausente do manifesto")
    exigir(permissao in prepare, f"{permissao} ausente de prepare_android_sistema.py")
exigir("JarvisLocalizacao.kt" in prepare, "prepare_android_sistema.py não copia o Kotlin novo")

# 3. Kotlin: LocationManager, permissão checada, sem Play Services e sem nuvem.
for termo in ("LocationManager", "getLastKnownLocation", "requestLocationUpdates", "Geocoder"):
    exigir(termo in localizacao_kt, f"JarvisLocalizacao.kt sem {termo}")
for proibido in ("com.google.android.gms", "play-services", "OkHttp", "HttpURLConnection"):
    exigir(proibido not in localizacao_kt, f"JarvisLocalizacao.kt usa {proibido}")
exigir(
    "checkSelfPermission" in localizacao_kt and "precisaPermissao" in localizacao_kt,
    "leitura não checa a permissão nem devolve o motivo",
)
exigir(
    "20 seconds" not in localizacao_kt and "20 segundos" in localizacao_kt,
    "limite de espera não é explicado de forma honesta",
)
exigir("gpsLigado" in localizacao_kt and "redeLigada" in localizacao_kt,
       "estado não informa os provedores ligados")
exigir("Thread {" in localizacao_kt, "Geocoder não foi tirado da thread principal")

# 4. Canal do aparelho expõe estado, leitura e a permissão de localização.
for metodo in ('"localizacaoEstado"', '"localizacao"', '"pedirPermissao"'):
    exigir(metodo in aparelho_kt, f"JarvisAparelho sem o caso {metodo}")
exigir("JarvisLocalizacao.obter" in aparelho_kt, "canal não chama a leitura de localização")
exigir("PEDIDO_LOCALIZACAO" in aparelho_kt, "pedido de permissão sem código próprio")
exigir("PERMISSAO_FINA" in aparelho_kt and "PERMISSAO_GROSSA" in aparelho_kt,
       "pedido de permissão não inclui as duas precisões")
exigir("JarvisLocalizacao.obter" in comandos_kt, "comando falado não chega à localização")

# 5. Dart: modelo honesto, sem rede e com validação de coordenadas.
for termo in ("class EstadoLocalizacao", "class LocalizacaoAparelho", "fraseLocalizacao"):
    exigir(termo in core, f"core/localizacao.dart sem {termo}")
exigir("latitude! >= -90" in core and "longitude! >= -180" in core,
       "coordenadas fora do planeta seriam aceitas")
exigir("não informado" in core, "campo ausente não vira 'não informado'")
for proibido in ("package:http", "dio", "HttpClient", "WebView", "webview"):
    exigir(proibido not in core, f"core/localizacao.dart usa {proibido}")
exigir("deMapa" in core, "modelo não lê o mapa do Android")

# 6. Serviço e tela: status, notificações e localização no mesmo lugar.
for termo in ("estadoLocalizacao", "localizacao()", "'localizacao'", "'localizacaoEstado'"):
    exigir(termo in servico, f"aparelho_service.dart sem {termo}")
for texto in ("ESTADO DO APARELHO", "NOTIFICAÇÕES", "LOCALIZAÇÃO", "APPS INSTALADOS"):
    exigir(texto in tela, f"tela de status sem a seção {texto}")
for chave in (
    "status-notificacoes",
    "autorizar-notificacoes",
    "ver-localizacao",
    "localizacao-resultado",
    "ouvir-localizacao",
):
    exigir(chave in tela, f"tela de status sem a chave {chave}")
for termo in ("Memória", "Bateria", "Rede", "Bateria"):
    exigir(termo in tela, f"tela de status sem a linha {termo}")
exigir("pedirPermissao('localizacao')" in tela, "tela não pede a permissão de localização")
exigir("não é guardada nem enviada" in tela, "tela não avisa o que acontece com a localização")
for proibido in ("WebView", "HtmlElement", "webview_flutter"):
    exigir(proibido not in tela, f"tela de status usa {proibido}")

# 7. Comando falado "onde estou" e execução com frase honesta.
exigir("class ComandoLocalizacao" in comandos, "comando de localização ausente")
exigir("onde estou" in comandos, "exemplo 'onde estou' ausente do registro")
exigir("ComandoLocalizacao()" in executor and "fraseLocalizacao" in executor,
       "executor não responde a localização com frase honesta")
exigir("como " in comandos and "por que" in comandos,
       "perguntas com 'como'/'por que' não foram preservadas para a conversa")

# 8. Notificações continuam sendo lidas do canal real, não inventadas.
exigir("notificacoesAcesso" in servico and "notificacoes(" in servico,
       "serviço perdeu a leitura de notificações")
exigir("Acesso a notificações" in tela, "tela não explica a autorização de notificações")
exigir("limparNotificacoes" in tela, "tela não permite limpar a leitura de notificações")

# 9. Provas registradas na suíte.
exigir((APP / "tool" / "localizacao_test.dart").is_file(), "teste puro ausente")
exigir("localizacao_test.dart" in dart_core, "teste puro fora de tests/test_dart_core.py")
exigir((APP / "test" / "dispositivo_page_test.dart").is_file(), "teste de widget ausente")
tela_test = ler(APP / "test" / "dispositivo_page_test.dart")
for termo in ("localização: pede permissão", "permissão negada", "notificações:"):
    exigir(termo in tela_test, f"teste de widget sem o caso {termo}")
exigir("tests/test_status_celular_flutter.py" in pacote, "contrato fora de package.json test:all")

# 10. Inventário e relatório citam o bloco.
exigir("localiza" in inventario.lower(), "inventário não cita a localização")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-19_079-status-celular.md"
if relatorio.is_file():
    texto = relatorio.read_text(encoding="utf-8")
    for termo in ("bateria", "memória", "rede", "notificações", "localização"):
        exigir(termo in texto.lower(), f"relatório 079 sem {termo}")
    exigir("aparelho" in texto.lower(), "relatório 079 não declara o limite de aparelho")

if falhas:
    print("FALHAS:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("OK: status do celular — bateria, memória, rede, notificações e localização.")
