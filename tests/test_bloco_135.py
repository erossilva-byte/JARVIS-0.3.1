"""Bloco 135 — correções do uso real e QR no pareamento.

Confere, no texto dos arquivos, o que foi pedido em uso real:

1. abrir app por voz aceitando “abra/abri/abram” e apelidos (zap, insta, waze);
2. alarme criado de verdade, com a permissão SET_ALARM no manifesto gerado;
3. chave de provedor detectada ao testar/listar modelos, com aviso de troca;
4. localização guardada e clima real (Open-Meteo) na resposta e no prompt;
5. palco buscando o assunto na Wikipédia, com a Commons de reserva;
6. notificações relidas ao conectar e reconexão pedida pela tela;
7. visão com contexto e lugar provável, sem endereço;
8. QR no pareamento (celular desenha, PC lê pela câmera);
9. app do PC no Linux sem a GPU que derrubava a janela.

Não executa Android, Electron nem rede: é contrato de código.
"""
from __future__ import annotations

import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
FLUTTER = RAIZ / "flutter_app"
LIB = FLUTTER / "lib"
ANDROID = FLUTTER / "android"
TOOL = FLUTTER / "tool"


def ler(caminho: Path) -> str:
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        raise SystemExit(f"FALHOU: {mensagem}")


# 1. Abrir app por voz.
comandos = ler(LIB / "core" / "comandos_android.dart")
for verbo in ("abra", "abri", "abram"):
    exigir(f"|{verbo}|" in comandos, f"interpretador sem o verbo {verbo}")
exigir("pacotesConhecidos" in comandos, "sem apelidos de pacote no Dart")
for apelido in ("'zap'", "'insta'", "'waze'"):
    exigir(apelido in comandos, f"apelido {apelido} ausente")

kws_comandos = ler(ANDROID / "JarvisComandos.kt")
exigir("pacotesConhecidos" in kws_comandos, "Kotlin sem apelidos de pacote")
exigir("semAcento(" in kws_comandos, "Kotlin não normaliza acento ao casar app")

# 2. Alarme de verdade.
gerador = ler(TOOL / "prepare_android_sistema.py")
exigir("com.android.alarm.permission.SET_ALARM" in gerador,
       "manifesto gerado sem a permissão de alarme")
exigir("AlarmClock.ACTION_SET_ALARM" in kws_comandos, "alarme não usa a ação do Android")
exigir("EXTRA_SKIP_UI, false" in kws_comandos,
       "alarme seria criado sem a confirmação da pessoa")
exigir("SecurityException" in kws_comandos, "sem queda explicada quando falta permissão")
legado = ler(RAIZ / "patch_manifest.py")
exigir("com.android.alarm.permission.SET_ALARM" in legado,
       "patch_manifest.py sem a permissão de alarme")

# 3. Chave detectada e conferida.
provedor = ler(LIB / "services" / "provider_service.dart")
for termo in ("prefixosDeChave", "avisoDeChaveTrocada", "digitosFinais"):
    exigir(termo in provedor, f"serviço de provedores sem {termo}")
pagina_provedor = ler(LIB / "provider_settings_page.dart")
exigir("_salvarSeDigitada" in pagina_provedor,
       "tela não salva a chave digitada ao testar")
exigir("_colar(" in pagina_provedor, "tela sem colar da área de transferência")
exigir("chave-final-" in pagina_provedor, "tela não mostra o fim da chave guardada")

# 4. Localização guardada e clima real.
exigir((LIB / "core" / "clima.dart").is_file(), "falta core/clima.dart")
exigir((LIB / "services" / "clima_service.dart").is_file(),
       "falta services/clima_service.dart")
exigir((LIB / "services" / "localizacao_service.dart").is_file(),
       "falta services/localizacao_service.dart")
clima = ler(LIB / "core" / "clima.dart")
exigir("api.open-meteo.com" in clima, "clima sem fonte pública")
for proibido in ("api_key", "apikey", "Authorization"):
    exigir(proibido not in clima, f"clima pede chave: {proibido}")
exigir("urlDoClima(" in clima and "pedidoDeClima(" in clima,
       "clima sem endereço ou reconhecimento do pedido")
local = ler(LIB / "services" / "localizacao_service.dart")
exigir("validade" in local and "SharedPreferences" in local,
       "localização não é guardada com validade")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
exigir("pedidoDeClima(texto)" in conversa, "conversa não responde clima")
exigir("_contextoDoLugar" in conversa, "conversa não passa o lugar ao modelo")
busca = ler(LIB / "core" / "memoria_busca.dart")
exigir("contextoLocal" in busca, "prompt sem o bloco de lugar")

# 5. Palco busca o assunto.
palco = ler(LIB / "core" / "palco.dart")
exigir("pt.wikipedia.org" in palco, "palco não busca o assunto na Wikipédia")
exigir("lerImagensDaWikipedia(" in palco, "palco sem leitor da Wikipédia")
exigir("urlDeBuscaImagensCommons(" in palco, "palco sem a reserva da Commons")
palco_servico = ler(LIB / "services" / "palco_service.dart")
exigir("lerImagensDaWikipedia(" in palco_servico, "serviço do palco não usa a Wikipédia")
exigir("_buscarCommons(" in palco_servico, "serviço do palco sem reserva")

# 6. Notificações reais.
listener = ler(ANDROID / "JarvisNotificacaoListener.kt")
exigir("activeNotifications" in listener, "leitor não relê as notificações ativas")
exigir("fun reconectar(" in listener, "leitor sem reconexão")
exigir("requestRebind" in listener, "reconexão não pede o rebind ao Android")
aparelho = ler(ANDROID / "JarvisAparelho.kt")
exigir('"notificacoesReconectar"' in aparelho, "canal sem reconectar notificações")
servico_aparelho = ler(LIB / "services" / "aparelho_service.dart")
exigir("reconectarNotificacoes(" in servico_aparelho,
       "serviço Dart sem reconectar notificações")

# 7. Envio no WhatsApp: nova tentativa e confirmação real.
envio = ler(ANDROID / "JarvisEnvioSemToque.kt")
exigir("cliques" in envio, "envio sem toque não tenta de novo")
exigir("aindaNoCampo" in envio, "envio não confere se o texto saiu do campo")
exigir("9000L" in envio, "prazo curto demais para a conversa abrir")

# 8. Visão com contexto.
visao = ler(LIB / "core" / "visao.dart")
exigir("CONTEXTO da cena" in visao, "instrução da visão sem contexto")
exigir('"place"' in visao, "JSON da visão sem lugar provável")
estruturada = ler(LIB / "core" / "visao_estruturada.dart")
for campo in ("contexto", "localProvavel", "Contexto provável"):
    exigir(campo in estruturada, f"análise sem {campo}")

# 9. QR no pareamento.
pubspec = ler(FLUTTER / "pubspec.yaml")
exigir("qr:" in pubspec, "pubspec sem a biblioteca de QR")
qr = LIB / "services" / "qr_pareamento.dart"
exigir(qr.is_file(), "falta o desenho do QR")
exigir((LIB / "core" / "payload_qr.dart").is_file(), "falta o payload puro do QR")
exigir("jarvis://parear?" in ler(LIB / "core" / "payload_qr.dart"),
       "QR sem o formato do pareamento")
pagina_pareamento = ler(LIB / "services" / "pareamento_page.dart")
exigir("QrPareamento(" in pagina_pareamento, "tela do celular sem o QR")
exigir((RAIZ / "vendor" / "jsqr.js").is_file(), "falta o leitor jsQR no PC")
indice = ler(RAIZ / "index.html")
exigir('id="sc-ler-qr"' in indice, "painel do PC sem o botão de ler QR")
exigir('id="qr-video"' in indice, "painel do PC sem a câmera")
exigir("vendor/jsqr.js" in indice, "index.html não carrega o leitor")
web = ler(RAIZ / "app.js")
exigir("lerPayloadPareamento(" in web, "PC não interpreta o QR")
exigir("getUserMedia" in web, "PC não abre a câmera")
pacote = json.loads(ler(RAIZ / "package.json"))
exigir(any("vendor" in item for item in pacote.get("build", {}).get("files", [])),
       "pacote do PC não inclui vendor/")

# 10. Linux sem a GPU que derrubava a janela.
principal = ler(RAIZ / "platforms" / "desktop" / "main.js")
exigir("disableHardwareAcceleration" in principal,
       "PC no Linux ainda inicia a GPU")
exigir("JARVIS_GPU" in principal, "sem opção de religar a aceleração")
exigir("JARVIS_SEM_SANDBOX" in principal, "sem saída para distro sem sandbox")

# 11. Home, central do aparelho e versão.
exigir((LIB / "services" / "cartao_aparelho.dart").is_file(),
       "falta o cartão do celular na tela inicial")
centro = ler(LIB / "command_center.dart")
exigir("CartaoAparelho(" in centro, "tela inicial sem o cartão do celular")
inicio = ler(LIB / "home_screen.dart")
exigir("abrir-dispositivo-central" in inicio, "atalho do status do celular ausente")
dispositivo = ler(LIB / "services" / "dispositivo_page.dart")
for chave in ("reconectar-notificacoes", "cartao-clima", "clima-temperatura"):
    exigir(chave in dispositivo, f"central do aparelho sem {chave}")
exigir("version: 1.111.0+111100" in pubspec, "pubspec não está em 1.111.0+111100")
exigir(pacote.get("version") == "1.111.0", "package.json fora da versão")
versao = json.loads(ler(RAIZ / "VERSAO.json"))
exigir(versao.get("versionCode") == 111100, "versionCode fora da versão")

# 12. Suíte e relatório.
alvo = pacote.get("scripts", {}).get("test:all", "")
exigir("tests/test_bloco_135.py" in alvo, "contrato novo fora do test:all")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
for caso in ("tool/clima_test.dart", "tool/qr_pareamento_test.dart"):
    exigir(caso in dart_core, f"{caso} fora do test_dart_core")

print("OK: bloco 135 (comandos, alarme, chaves, clima, palco, notificações, "
      "visão, QR, Linux e tela inicial)")
