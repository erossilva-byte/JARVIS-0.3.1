#!/usr/bin/env python3
"""Contrato estático do histórico de execuções (ajuste 081).

O pedido foi: saber o que o JARVIS executou por voz, com horário e resultado, para
conferir depois. Aqui ficam presas as regras que dá para conferir sem aparelho:

1. todo comando executado é registrado no aparelho com horário, pedido, ação e a
   resposta lida do Android — nunca um "feito" inventado;
2. o comando executado com a tela aberta e o executado em segundo plano entram na
   mesma lista, com a origem marcada;
3. o histórico fica só no aparelho, limitado a 100 registros, e a limpeza pede
   confirmação;
4. a tela permite conferir depois: dia, hora, ação, resultado e mensagem.

Voz real, preenchimento em campo e leitura em aparelho físico continuam fora
deste contrato: só o Poco X7 resolve.
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


core = ler(APP / "lib" / "core" / "historico_voz.dart")
servico = ler(APP / "lib" / "services" / "historico_voz_service.dart")
tela = ler(APP / "lib" / "services" / "historico_voz_page.dart")
conversa = ler(APP / "lib" / "services" / "voice_conversation_page.dart")
comandos_tela = ler(APP / "lib" / "services" / "comandos_android_page.dart")
fundo_tela = ler(APP / "lib" / "services" / "segundo_plano_page.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")

fundo_kt = ler(KOTLIN / "JarvisFundo.kt")
canal_kt = ler(KOTLIN / "JarvisFundoCanal.kt")
servico_kt = ler(KOTLIN / "KwsForegroundService.kt")

relatorio = RAIZ / "docs" / "relatorios" / "2026-11-20_081-historico-de-voz.md"

# 1. Versão, changelog, relatório e suíte.
exigir("version: 1.96.0+19600" in pubspec, "versão não atualizada para 1.68.0")
exigir("1.68.0" in changelog and "histórico" in changelog.lower(),
       "CHANGELOG sem o bloco 1.68.0 do histórico")
exigir(relatorio.is_file(), "relatório 081 ausente")
exigir("tests/test_historico_voz_flutter.py" in pacote,
       "contrato fora de package.json test:all")
exigir("tool/historico_voz_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")

# 2. Armazenamento no aparelho: lista limitada, sem áudio e sem nuvem.
for termo in ("CHAVE_HISTORICO", "LIMITE_HISTORICO", "historico_acoes",
              "org.json.JSONArray", "fun historico(", "registrarHistorico"):
    exigir(termo in fundo_kt, f"JarvisFundo.kt sem {termo}")
for termo in ('"em"', '"pedido"', '"acao"', '"ok"', '"mensagem"'):
    exigir(termo in fundo_kt, f"registro sem o campo {termo}")
exigir("proximo.length() < LIMITE_HISTORICO" in fundo_kt,
       "histórico nativo sem limite de registros")
exigir(".remove(CHAVE_HISTORICO)" in fundo_kt,
       "limpar histórico não apaga a lista")
for proibido in ("HttpURLConnection", "OkHttp", "AudioRecord", "getBytes"):
    exigir(proibido not in fundo_kt, f"histórico nativo guarda/usos indevidos: {proibido}")

# 3. Um registro para cada caminho: tela e segundo plano, com a origem.
for termo in ('"historicoExecucoes"', '"registrarExecucao"', "ORIGEM_TESTE", "pedido = texto"):
    exigir(termo in canal_kt, f"JarvisFundoCanal.kt sem {termo}")
exigir("JarvisFundo.ORIGEM_SEGUNDO_PLANO" in servico_kt,
       "serviço não marca o comando como vindo do segundo plano")
exigir("pedido = texto" in servico_kt,
       "serviço não guarda o que foi realmente ouvido")

# 4. Modelo Dart honesto: ordena, limita, descarta registro incompleto.
for termo in ("enum OrigemExecucao", "class RegistroExecucao", "registrosDeMapa",
              "diaRotulo", "resumoExecucoes", "static const limite = 100"):
    exigir(termo in core, f"core/historico_voz.dart sem {termo}")
exigir("Não executado" in core and "Executado" in core,
       "rótulo de resultado não distingue execução de falha")
exigir("bruto['ok'] == true" in core, "campo ok não booleano seria aceito como sucesso")
exigir("if (pedido.isEmpty) return null" in core,
       "registro sem pedido não foi descartado")
exigir("b.em.compareTo(a.em)" in core, "lista não é ordenada do mais recente")
for proibido in ("package:http", "dio", "HttpClient", "WebView", "webview"):
    exigir(proibido not in core, f"core/historico_voz.dart usa {proibido}")

# 5. Ponte Flutter com o mesmo canal do segundo plano, sem esconder falha.
exigir("com.jarvis.nova/fundo" in servico, "ponte não usa o canal do aparelho")
for metodo in ("historicoExecucoes", "registrarExecucao", "limparHistorico"):
    exigir(metodo in servico, f"serviço Dart sem {metodo}")
exigir("MissingPluginException" in servico, "ponte não trata a ausência do Android")
exigir("origem.id" in servico, "origem não é enviada ao Android")

# 6. Tela para conferir depois.
for chave in ("historico-voz-vazio", "resumo-historico-voz",
              "historico-voz-item-", "limpar-historico-voz",
              "confirmar-limpar-historico-voz", "atualizar-historico-voz"):
    exigir(chave in tela, f"tela do histórico sem a chave {chave}")
for termo in ("registro.hora", "registro.resultadoRotulo", "registro.titulo",
              "registro.mensagem", "registro.origem.rotulo"):
    exigir(termo in tela, f"tela do histórico não mostra {termo}")
exigir("Limpar o histórico?" in tela, "limpeza sem confirmação")
exigir("O áudio não é gravado" in tela, "tela não diz o que acontece com o áudio")
exigir("dentro do aparelho" in tela.lower() or "só neste aparelho" in tela.lower(),
       "tela não avisa que o histórico fica no aparelho")
for proibido in ("WebView", "HtmlElement", "webview_flutter"):
    exigir(proibido not in tela, f"tela do histórico usa {proibido}")

# 7. Comando falado entra no histórico com a origem certa.
exigir("_historico.registrar(" in conversa, "conversa não registra o comando executado")
exigir("origem:\n          widget.fromVoice ? OrigemExecucao.voz : OrigemExecucao.digitado"
       in conversa or "widget.fromVoice ? OrigemExecucao.voz" in conversa,
       "origem da voz não é distinguida")
exigir("ok: ok && !bloqueado" in conversa,
       "comando bloqueado no limite poderia aparecer como executado")
exigir("_concluirComando" in conversa and "acao: acao" in conversa,
       "registro não guarda a ação decidida")

# 8. Caminhos de acesso.
exigir("abrir-historico-voz" in comandos_tela,
       "Comandos do Android sem atalho para o histórico")
exigir("fundo-ver-historico" in fundo_tela,
       "tela de segundo plano sem atalho para o histórico")

# 9. Provas registradas.
exigir((APP / "tool" / "historico_voz_test.dart").is_file(), "teste puro ausente")
exigir((APP / "test" / "historico_voz_page_test.dart").is_file(),
       "teste de widget ausente")
teste_tela = ler(APP / "test" / "historico_voz_page_test.dart")
for caso in ("mostra horário, ação e resultado", "limpar pede confirmação",
             "falha ao limpar avisa", "atualizar relê"):
    exigir(caso in teste_tela, f"teste de widget sem o caso {caso}")

# 10. Sem atalhos proibidos e documentação do bloco.
for arquivo, texto in (("JarvisFundo.kt", fundo_kt), ("JarvisFundoCanal.kt", canal_kt),
                       ("KwsForegroundService.kt", servico_kt)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")
exigir("histórico de execuções" in inventario.lower() or "histórico de execu" in inventario.lower(),
       "inventário não cita o histórico de execuções")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 081 sem a seção {secao}")
    for termo in ("horário", "resultado", "por voz", "aparelho"):
        exigir(termo in texto.lower(), f"relatório 081 sem {termo}")

if falhas:
    print("FALHAS no contrato do histórico de execuções:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do histórico de execuções: aprovado.")
