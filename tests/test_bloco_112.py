"""Bloco 112 — um chat por sessão, fala em fluxo e segundo plano com Fish Audio.

O que este contrato protege:
1. a conversa continua no mesmo chat enquanto o app está aberto e só recomeça
   quando o JARVIS é fechado e aberto de novo (a anterior fica no histórico);
2. o histórico tem entrada visível na tela inicial;
3. a resposta é falada por frases, enquanto ainda está chegando;
4. o segundo plano não vence o prazo durante uma resposta legítima;
5. o Fish Audio fala com o app fechado, pelo motor sem tela.
"""

from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"
KOTLIN = APP / "android" / "app" / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"


def ler(caminho: Path) -> str:
    assert caminho.is_file(), f"arquivo ausente: {caminho}"
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    assert condicao, mensagem


# 1. Um chat por sessão -------------------------------------------------------
loja = ler(LIB / "services" / "conversa_store.dart")
exigir("static Conversa? conversaAberta" in loja,
       "sem a conversa da sessão: cada tela abriria um chat novo")
exigir("Conversa? buscar(String id)" in loja, "sem busca da conversa salva")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
exigir("ConversaStore.conversaAberta" in conversa,
       "a conversa não lembra o chat da sessão")
exigir("atual.buscar(id)" in conversa, "não retoma o chat salvo da sessão")
exigir("if (conversa.mensagens.isNotEmpty) await store!.salvar(conversa);" in conversa,
       "conversa vazia entraria no histórico")
exigir("if (salva != null) conversa = salva;" in conversa,
       "o histórico não devolve a conversa escolhida à tela")

# 2. Histórico visível --------------------------------------------------------
inicio = ler(LIB / "home_screen.dart")
exigir("'historico-button'" in inicio, "sem botão de histórico na tela inicial")
exigir("onPressed: _abrirHistorico" in inicio,
       "o botão de histórico não abre a lista")
exigir((LIB / "services" / "historico_page.dart").is_file(),
       "a tela de histórico sumiu")

# 3. Fala em fluxo ------------------------------------------------------------
nucleo = ler(LIB / "core" / "fala_em_fluxo.dart")
exigir("class FalasEmFluxo" in nucleo, "sem o núcleo da fala em fluxo")
exigir("List<String> acrescentar(String parcial" in nucleo,
       "a fala em fluxo não recebe o parcial")
exigir("_corteDeFrase()" in nucleo, "sem corte de frase")
exigir("_ehDigito" in nucleo, "ponto de número fecharia a frase")
exigir("_falarEmFluxo" in conversa, "a conversa não fala durante a resposta")
exigir("_encerrarFalaEmFluxo" in conversa, "a sobra da resposta não é falada")
exigir("_filaFala" in conversa, "as frases poderiam falar por cima uma da outra")
exigir("_geracaoFala" in conversa,
       "fala de uma resposta antiga sobreviveria à interrupção")
exigir("falarEmFluxo" in ler(LIB / "services" / "fala_jarvis.dart"),
       "a fala de resposta não tem caminho por frase")
exigir("falarEmFila" in ler(LIB / "services" / "voz_jarvis.dart"),
       "a voz do aparelho não entra na fila")
exigir("tocarEAguardar" in ler(LIB / "services" / "voz_externa_service.dart"),
       "a voz externa não espera o MP3 terminar")
exigir("falarEmFila" in ler(KOTLIN / "JarvisVoz.kt"),
       "o sintetizador do aparelho não tem fila")
exigir("QUEUE_ADD" in ler(KOTLIN / "JarvisVoz.kt"),
       "frase nova cortaria a anterior")
exigir("falarAudioAguardar" in ler(KOTLIN / "MainActivity.kt"),
       "o canal de voz não avisa o fim do MP3")
exigir((APP / "tool" / "fala_em_fluxo_test.dart").is_file(),
       "falta o teste puro da fala em fluxo")
exigir("tool/fala_em_fluxo_test.dart" in ler(RAIZ / "tests" / "test_dart_core.py"),
       "teste puro da fala em fluxo fora da suíte")

# 4. Segundo plano: prazo com sinal de vida -----------------------------------
ponte = ler(LIB / "services" / "ponte_ia_fundo.dart")
exigir("Timer.periodic" in ponte and "'progresso'" in ponte,
       "a ponte não avisa que a resposta continua a caminho")
exigir("falarComVozExterna" in ponte and "'falarResposta'" in ponte,
       "a ponte não fala pelo Fish Audio")
exigir("VozExternaConfig.pronta" in ponte,
       "a fala de fundo não respeita o interruptor da voz externa")
principal = ler(LIB / "main.dart")
exigir("Future<void> mainFundo() async" in principal,
       "o motor sem tela não carrega a voz externa")
exigir("VozExternaConfig.carregar()" in principal,
       "o motor sem tela não decide a voz externa")

ponte_kt = ler(KOTLIN / "JarvisPonteIa.kt")
exigir("ESPERA_MS = 90_000L" in ponte_kt,
       "o prazo do segundo plano continua curto demais")
exigir("armarCobranca" in ponte_kt and "renovarCobranca" in ponte_kt,
       "o prazo não é renovado pelo sinal de vida")
exigir('"progresso"' in ponte_kt, "o serviço não escuta o sinal de vida")
exigir("fun falarFundo(" in ponte_kt, "sem fala de fundo pela ponte")
exigir("fun preparar(" in ponte_kt,
       "o motor sem tela não sobe antes da resposta")
exigir("PREF_VOZ_EXTERNA" in ponte_kt and "vozExternaLigada" in ponte_kt,
       "o serviço não sabe se a voz externa está ligada")
exigir("CANAL_VOZ" in ponte_kt and '"falarAudio"' in ponte_kt,
       "o motor sem tela não toca o MP3 do Fish Audio")

servico = ler(KOTLIN / "KwsForegroundService.kt")
exigir("JarvisPonteIa.preparar(applicationContext)" in servico,
       "a voz externa não é preparada na detecção")
exigir("JarvisPonteIa.falarFundo(mensagem)" in servico,
       "o serviço não tenta o Fish Audio antes da voz local")
exigir("private fun falarLocal(" in servico,
       "sem volta para a voz do aparelho quando o Fish Audio falha")
exigir("JarvisPonteIa.usarVoz(voz)" in servico,
       "o MP3 de fundo não tem por onde tocar")

# 5. Versão, suíte e registro -------------------------------------------------
exigir("version: 1.89.2+18902" in ler(APP / "pubspec.yaml"),
       "versão não atualizada para 1.89.2")
exigir("python3 tests/test_bloco_112.py" in ler(RAIZ / "package.json"),
       "contrato do bloco fora da suíte")
exigir("## 1.89.2" in ler(RAIZ / "CHANGELOG.md"), "CHANGELOG sem o 1.89.2")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-24_112-chat-unico-fala-e-fundo.md"
exigir(relatorio.is_file(), "falta o relatório do bloco 112")

print("OK: chat único por sessão, histórico visível, fala em fluxo e "
      "segundo plano com Fish Audio")
