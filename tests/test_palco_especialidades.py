#!/usr/bin/env python3
"""Contrato do bloco 105: especialização, modo palco e microfone de perguntas.

O que este teste confere sem aparelho:

1. o palco usa três fontes públicas que **não pedem chave** e lê cada resposta
   num leitor puro, coberto por teste Dart;
2. o módulo “Modo palco” existe no catálogo, tem estado **parcial** e tela
   própria — sem prometer player embutido;
3. CADeSIMU e programação têm instrução própria, com limites escritos, e essa
   instrução entra no pedido da conversa e da voz de fundo;
4. o microfone do segundo plano aceita **pergunta**, não só comando: limite de
   20 s, folga de silêncio, pista de vocabulário e escolha pela confiança;
5. nada de reconhecedor de nuvem, nada de chave escrita no código.

O que ele **não** mede: resposta real das fontes, microfone, tela no aparelho,
tempo de fala e qualidade do reconhecimento. Isso continua pendente de teste
físico.
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


pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = json.loads(ler(RAIZ / "package.json") or "{}")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
palco = ler(LIB / "core" / "palco.dart")
palco_servico = ler(LIB / "services" / "palco_service.dart")
palco_tela = ler(LIB / "services" / "palco_page.dart")
especialidades = ler(LIB / "core" / "especialidades.dart")
catalogo = ler(LIB / "catalog.dart")
estado = ler(LIB / "core" / "estado_modulos.dart")
paginas = ler(LIB / "pages.dart")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
ponte = ler(LIB / "services" / "ponte_ia_fundo.dart")
pergunta = ler(LIB / "core" / "pergunta_livre.dart")
fundo = ler(LIB / "core" / "fundo.dart")
segundo_plano = ler(LIB / "services" / "segundo_plano_page.dart")
sistema = ler(LIB / "services" / "sistema_android.dart")
escuta = ler(ANDROID / "JarvisEscutaFundo.kt")
palco_voz = ler(ANDROID / "JarvisPalco.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
home = ler(LIB / "home_screen.dart")
principal = ler(ANDROID / "MainActivity.kt")
servico = ler(ANDROID / "KwsForegroundService.kt")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-23_105-especialidades-palco-e-microfone.md")

# 1. Versão e suíte.
exigir("version: 1.92.0+19200" in pubspec, "pubspec sem a versão 1.92.0+19200")
exigir("## 1.88.6" in changelog, "CHANGELOG sem o bloco 1.88.6")
exigir(relatorio.is_file(), "relatório do bloco 105 ausente")
for comando in ("python3 tests/test_palco_especialidades.py",
                "tool/palco_test.dart", "tool/especialidades_test.dart"):
    alvo = pacote.get("scripts", {}).get("test:all", "")
    exigir(comando in alvo or comando in dart_core,
           f"{comando} fora da suíte")

# 2. Palco: três fontes sem chave, cada uma com o seu endereço.
for termo in ("commons.wikimedia.org", "news.google.com/rss/search",
              "api.dailymotion.com"):
    exigir(termo in palco, f"palco sem a fonte {termo}")
for termo in ("api_key", "apikey", "token=", "Authorization"):
    exigir(termo not in palco, f"palco pede chave: {termo}")
    exigir(termo not in palco_servico, f"serviço do palco pede chave: {termo}")
for leitor in ("lerImagensDoCommons", "lerNoticiasDoRss",
               "lerVideosDoDailymotion"):
    exigir(f"List<ItemPalco> {leitor}(" in palco, f"palco sem o leitor {leitor}")
exigir("itemDeLink(" in palco, "palco não aceita link direto")
exigir("linkSeguro(" in palco and "https://" in palco,
       "palco não restringe os esquemas de link")
exigir("TimeoutException" in palco_servico and "PalcoException" in palco_servico,
       "serviço do palco sem tratamento de tempo/falha")
exigir("User-Agent" in palco_servico, "serviço do palco sem identificação")

# 3. Tela do palco: campos, estados e link.
for chave in ("palco-campo", "palco-pesquisar", "palco-tipo-",
              "palco-resultado", "palco-erro", "palco-proximo"):
    exigir(chave in palco_tela, f"tela do palco sem a chave {chave}")
exigir("Image.network" in palco_tela, "palco não exibe a imagem")
exigir("SistemaAndroid.abrirUrl" in palco_tela,
       "palco não oferece abrir no navegador")
exigir("player embutido" in palco_tela or "player" in palco,
       "palco não declara a ausência de player")

# 4. Catálogo, estado e navegação.
exigir("'Modo palco'" in catalogo, "catálogo sem o módulo Modo palco")
exigir("palco," in estado, "TelaModulo sem palco")
exigir(re.search(r"nome: 'Modo palco',\s*\n\s*estado: EstadoModulo\.parcial", estado)
       is not None, "Modo palco não está declarado como parcial")
exigir("abrir-palco" in paginas and "PalcoPage" in paginas,
       "tela do palco não está ligada ao módulo")
exigir("pedidoPalco(texto)" in conversa
       and "PalcoPage(pedidoInicial: palco)" in conversa,
       "conversa não abre o palco no pedido de mídia")

# 5b. Palco por voz com o app fechado: reconhecimento no Kotlin e abertura no
# app pela intenção, com o pedido já pesquisando.
for termo in ("object JarvisPalco", "fun interpretar", "EXTRA_TIPO",
              "EXTRA_CONSULTA", "consultaDe", "fraseDeAbertura",
              "fotos?", "v[ií]deos?", "not[ií]cias?"):
    exigir(termo in palco_voz, f"JarvisPalco.kt sem {termo}")
exigir("JarvisPalco.interpretar(texto)" in servico,
       "serviço de fundo não reconhece o pedido de palco")
exigir(servico.index("JarvisPalco.interpretar(texto)")
       < servico.index("val comando = JarvisFundo.interpretar(texto)"),
       "pedido de palco é avaliado depois do comando")
exigir("abrirPalco(" in servico and "JarvisPalco.EXTRA_CONSULTA" in servico,
       "serviço não entrega o pedido de palco ao app")
exigir("podeAbrirApps" in servico,
       "serviço abre o app sem conferir a autorização de sobreposição")
exigir("JarvisPalco.EXTRA_CONSULTA" in principal
       and '"acao" to "palco"' in principal,
       "Android não transforma o pedido em intenção de palco")
exigir("JarvisPalco.kt" in preparo,
       "preparo do Android não copia JarvisPalco.kt")
exigir("pedidoDePalcoVoz(" in palco,
       "núcleo do palco não aceita o pedido vindo da voz")
exigir("abrirPalco" in sistema and "pedidoPalco" in sistema,
       "IntencaoSistema não carrega o pedido de palco")
exigir("PalcoPage(pedidoInicial: pedido)" in home,
       "tela inicial não abre o palco da intenção")
exigir((APP / "test" / "intencao_palco_test.dart").is_file(),
       "teste da intenção de palco ausente")
exigir("conversa_palco_test.dart" in str(pacote.get("scripts", ""))
       or (RAIZ / "flutter_app" / "test" / "conversa_palco_test.dart").is_file(),
       "teste da conversa abrindo o palco ausente")

# 5. Especialidades: reconhecimento, instrução e limites.
for termo in ("especialidadeCadesimu", "especialidadeProgramacao",
              "instrucaoDaEspecialidade", "blocoDaEspecialidade"):
    exigir(termo in especialidades, f"especialidades sem {termo}")
exigir(".cad" in especialidades and "proprietário" in especialidades,
       "especialidade de CADeSIMU não declara o formato proprietário")
exigir("não executa" in especialidades and "sandbox" in especialidades,
       "especialidade de programação promete execução")
exigir("especialidade: especialidade" in conversa,
       "conversa não passa a especialidade ao provedor")
exigir("especialidade: blocoDaEspecialidade" in ponte,
       "voz de fundo não passa a especialidade")
exigir("String? especialidade," in pergunta and "String? especialidade,",
       "pergunta livre não aceita a especialidade")

# 6. Microfone: pergunta além de comando.
for arquivo, texto in (("JarvisEscutaFundo.kt", escuta),
                       ("MainActivity.kt", principal)):
    exigir("createOnDeviceSpeechRecognizer" in texto,
           f"{arquivo} não usa o reconhecedor do aparelho")
    exigir("createSpeechRecognizer(" not in texto,
           f"{arquivo} usa reconhecedor que pode ir para a nuvem")
    exigir("EXTRA_BIASING_STRINGS" in texto and "TIRAMISU" in texto,
           f"{arquivo} sem pista de vocabulário no Android 13+")
    exigir("CONFIDENCE_SCORES" in texto,
           f"{arquivo} não escolhe a alternativa pela confiança")
    exigir("2600L" in texto, f"{arquivo} sem folga de silêncio para pergunta")
exigir("LIMITE_MS = 20_000L" in escuta,
       "escuta de fundo continua cortando a pergunta em 12 s")
exigir("pergunta ou comando" in servico,
       "serviço de fundo ainda anuncia só comando")
exigir("pergunta" in fundo.lower() and "20 segundos" in fundo,
       "texto de limites do segundo plano não cita a pergunta")
exigir("responde perguntas" in segundo_plano.lower(),
       "tela do segundo plano não diz que responde pergunta")

# 7. Abrir link no navegador é só http(s).
exigir("abrirUrl" in sistema, "SistemaAndroid sem abrirUrl")
exigir('"abrirUrl"' in principal and "ACTION_VIEW" in principal,
       "Android sem o método abrirUrl")
exigir("https://" in principal and "javascript" not in principal,
       "Android aceita esquema fora de http(s) no abrirUrl")

# 8. Proibições do projeto continuam valendo nos arquivos novos.
proibido = re.compile(r"(GlobalScope|Process\.run|Runtime\.getRuntime|shell)")
for arquivo, texto in (("core/palco.dart", palco),
                       ("core/especialidades.dart", especialidades),
                       ("services/palco_service.dart", palco_servico),
                       ("services/palco_page.dart", palco_tela)):
    exigir(not proibido.search(texto), f"{arquivo} usa construção proibida")

# 9. Relatório com as seções combinadas.
if relatorio.is_file():
    texto = relatorio.read_text(encoding="utf-8")
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 5. Limites declarados", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 105 sem a seção {secao}")
    for termo in ("palco", "CADeSIMU", "microfone", "pergunta"):
        exigir(termo.lower() in texto.lower(), f"relatório 105 sem {termo}")

if falhas:
    print("FALHAS no contrato do bloco 105:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("OK: bloco 105 — palco com três fontes sem chave, especialidades com "
      "limites e microfone de fundo aberto a perguntas.")
