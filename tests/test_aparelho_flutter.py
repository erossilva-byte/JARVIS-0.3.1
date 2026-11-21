"""Confere por leitura estática o painel do aparelho do app Flutter (versão 1.60.0).

O comportamento é provado em Dart (`tool/aparelho_test.dart`) e a tela em
`test/aparelho_page_test.dart`. Aqui se prova o contrato: interpretadores puros,
canal nativo registrado, permissões declaradas, limites escritos e relatório.
"""
from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
CORE = APP / "lib" / "core" / "aparelho.dart"
SERVICO = APP / "lib" / "services" / "aparelho_service.dart"
PAGINA = APP / "lib" / "services" / "aparelho_page.dart"
PAGES = APP / "lib" / "pages.dart"
HOME = APP / "lib" / "home_screen.dart"
KOTLIN = (APP / "android" / "app" / "src" / "main" / "kotlin" / "com" /
          "jarvis" / "nova" / "JarvisAparelho.kt")
LISTENER = (APP / "android" / "app" / "src" / "main" / "kotlin" / "com" /
            "jarvis" / "nova" / "JarvisNotificacaoListener.kt")
MAIN = (APP / "android" / "app" / "src" / "main" / "kotlin" / "com" /
        "jarvis" / "nova" / "MainActivity.kt")
MANIFEST = APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
TESTE_PURO = APP / "tool" / "aparelho_test.dart"
TESTE_TELA = APP / "test" / "aparelho_page_test.dart"
CHANGELOG = RAIZ / "CHANGELOG.md"
INVENTARIO = RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md"
RELATORIO = (RAIZ / "docs" / "relatorios" /
             "2026-11-19_072-relogios-e-aparelho.md")
RELATORIO_SPOTIFY = (RAIZ / "docs" / "relatorios" /
                     "2026-11-19_073-tocar-faixa-no-spotify.md")


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, SERVICO, PAGINA, PAGES, HOME, KOTLIN, LISTENER, MAIN,
                    MANIFEST, TESTE_PURO, TESTE_TELA, CHANGELOG, INVENTARIO,
                    RELATORIO, RELATORIO_SPOTIFY):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    servico = SERVICO.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    pages = PAGES.read_text(encoding="utf-8")
    home = HOME.read_text(encoding="utf-8")
    kotlin = KOTLIN.read_text(encoding="utf-8")
    listener = LISTENER.read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    manifest = MANIFEST.read_text(encoding="utf-8")
    teste_puro = TESTE_PURO.read_text(encoding="utf-8")
    teste_tela = TESTE_TELA.read_text(encoding="utf-8")
    changelog = CHANGELOG.read_text(encoding="utf-8")
    inventario = INVENTARIO.read_text(encoding="utf-8")
    relatorio = RELATORIO.read_text(encoding="utf-8")
    relatorio_spotify = RELATORIO_SPOTIFY.read_text(encoding="utf-8")

    # 1. Núcleo Dart puro, offline e com os quatro apps pedidos.
    for proibido in ("package:flutter", "package:http", "dart:io", "WebView"):
        if proibido in core:
            falhas.append(f"núcleo do aparelho com dependência indevida: {proibido}")
    for termo in ("whatsapp", "discord", "instagram", "gmail", "sms",
                  "interpretarMensagem", "interpretarSpotify", "interpretarLigacao",
                  "EstadoAparelho", "fichaDeContato", "perguntasBasicasPessoa",
                  "ResultadoAparelho", "AcaoSpotify.reiniciar",
                  "uriSpotify", "faixaConfere"):
        if termo not in core:
            falhas.append(f"núcleo do aparelho sem {termo}")
    for acao in ("pausar", "continuar", "proxima", "anterior", "reiniciar", "tocar"):
        if acao not in core:
            falhas.append(f"Spotify sem a ação {acao}")

    # 2. Serviço usa o canal nativo e não inventa sucesso.
    if "com.jarvis.nova/aparelho" not in servico:
        falhas.append("serviço sem o canal com.jarvis.nova/aparelho")
    for metodo in ("enviarMensagem", "buscarContatos", "ligar", "spotify",
                   "ativarEmSegundoPlano", "pedirPermissao",
                   "abrirAjustesNotificacoes", "notificacoes"):
        if metodo not in servico:
            falhas.append(f"serviço sem o método {metodo}")

    # 3. Tela nativa com as seções e os limites declarados.
    for termo in ("aparelho-status", "aparelho-atualizar",
                  "aparelho-notificacoes-permitir", "mensagem-app",
                  "mensagem-destino", "mensagem-texto", "mensagem-enviar",
                  "spotify-pausar", "spotify-continuar", "spotify-proxima",
                  "spotify-anterior", "spotify-reiniciar", "spotify-tocar",
                  "contato-busca", "contato-buscar", "ficha-relacao",
                  "ficha-consentimento"):
        if termo not in pagina:
            falhas.append(f"painel sem {termo}")
    for limite in ("não aceitam envio silencioso", "sessão de mídia ativa",
                   "root", "ADB", "permissão de todos os arquivos"):
        if limite not in pagina:
            falhas.append(f"painel sem o limite declarado: {limite}")
    if "abrir-aparelho-conectado" not in pages:
        falhas.append("painel não está ligado em pages.dart")
    if "jarvis-ativo" not in home:
        falhas.append("tela inicial sem o aviso JARVIS ATIVO")

    # 4. Kotlin registra o canal, lê notificações e declara as ações.
    for termo in ("CANAL", "enviarMensagem", "SmsManager", "MediaController",
                  "skipToNext", "skipToPrevious", "seekTo(0)",
                  "buscarContatos", "ACTION_CALL", "ativarEmSegundoPlano",
                  "setShowWhenLocked", "BatteryManager", "ConnectivityManager",
                  "INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH", "playFromUri",
                  "verificarFaixa", "confereFaixa"):
        if termo not in kotlin:
            falhas.append(f"Kotlin sem {termo}")
    if "NotificationListenerService" not in listener:
        falhas.append("serviço de notificações ausente")
    if "JarvisAparelho" not in main:
        falhas.append("MainActivity não registra o canal do aparelho")

    # 5. Permissões declaradas no manifesto.
    for permissao in ("READ_CONTACTS", "CALL_PHONE", "SEND_SMS",
                      "BIND_NOTIFICATION_LISTENER_SERVICE"):
        if permissao not in manifest:
            falhas.append(f"manifesto sem {permissao}")

    # 6. Testes e documentação.
    if teste_puro.count("ok(") < 18:
        falhas.append("teste puro do aparelho com menos de 18 grupos")
    if "mensagem-enviar" not in teste_tela:
        falhas.append("teste de tela não cobre o envio de mensagem")
    if "1.60.0" not in changelog or "1.61.0" not in changelog:
        falhas.append("CHANGELOG sem as versões 1.60.0 e 1.61.0")
    if "Aparelho conectado" not in inventario:
        falhas.append("inventário sem a seção do aparelho")
    for secao in ("## 3. Feito", "## 4. Evidência", "## 6. Não verificado",
                  "## 7. Limitações"):
        if secao not in relatorio:
            falhas.append(f"relatório 072 sem a seção {secao}")
    for termo in ("MEDIA_PLAY_FROM_SEARCH", "playFromUri", "8 s",
                  "## 3. O que o Android permite", "## 7. Não verificado"):
        if termo not in relatorio_spotify:
            falhas.append(f"relatório 073 sem {termo}")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        print("FALHAS no contrato do aparelho:")
        for falha in falhas:
            print(f" - {falha}")
        return 1
    print("Contrato do aparelho conectado: aprovado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
