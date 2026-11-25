#!/usr/bin/env python3
"""Contrato dos comandos de tela no segundo plano (ajuste 097, versão 1.83.0).

Com o app fechado não existe Flutter no caminho, então o interpretador e o
executor vivem no Kotlin. Este contrato prende, sem aparelho e sem compilar:

1. o interpretador de tela do fundo tem o mesmo escopo estreito: ler, tocar,
   rolar e parar — nada de digitar;
2. o consentimento é a mesma preferência do app, lida do arquivo do Flutter e
   desligada quando ausente;
3. tocar não executa sem confirmação falada, com prazo, e a confirmação morre
   quando o comando termina;
4. leitura e rolagem executam direto, com histórico e origem de segundo plano;
5. o serviço de segundo plano consulta a tela antes da pergunta livre;
6. versão, suíte, relatório, CHANGELOG e inventário atualizados.
"""

from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
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


nucleo = ler(ANDROID / "JarvisTelaVoz.kt")
servico = ler(ANDROID / "KwsForegroundService.kt")
acessibilidade = ler(ANDROID / "JarvisAcessibilidade.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
store = ler(APP / "lib" / "services" / "acessibilidade_store.dart")
conversa = ler(APP / "lib" / "services" / "voice_conversation_page.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_097-tela-no-segundo-plano.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.107.0+110700" in pubspec,
       "versão não atualizada para 1.83.0")
exigir("1.83.0" in changelog and "segundo plano" in changelog.lower(),
       "CHANGELOG sem o bloco 1.83.0 da tela no segundo plano")
exigir("tests/test_tela_segundo_plano.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 097 ausente")

# 2. Escopo estreito no interpretador do fundo.
for termo in ("object JarvisTelaVoz", "sealed class Pedido", "Pedido.Ler",
              "Pedido.Tocar", "Pedido.Rolar", "Pedido.Parar"):
    exigir(termo in nucleo, f"interpretador do fundo sem {termo}")
exigir("JarvisAcessibilidade.ler()" in nucleo
       and "JarvisAcessibilidade.tocar(" in nucleo
       and "JarvisAcessibilidade.rolar(" in nucleo
       and "JarvisAcessibilidade.parar()" in nucleo,
       "executor do fundo não usa as mesmas ações do serviço de acessibilidade")
for proibido in ("digitar", "ACTION_SET_TEXT", "GLOBAL_ACTION",
                 "Runtime.getRuntime", "ProcessBuilder", "GlobalScope", "su ",
                 "adb "):
    exigir(proibido not in nucleo, f"caminho proibido no fundo: {proibido}")
exigir("ALVO_GENERICO" in nucleo and "PERGUNTA" in nucleo,
       "interpretador do fundo pode capturar conversa ou alvo genérico")

# 3. Mesmo consentimento do app.
exigir('PREFS_FLUTTER = "FlutterSharedPreferences"' in nucleo,
       "fundo não lê o arquivo de preferências do Flutter")
exigir('CHAVE_CONSENTIMENTO = "flutter.jarvis.acessibilidade.ativo"' in nucleo,
       "chave de consentimento do fundo diferente da do app")
exigir("getBoolean(CHAVE_CONSENTIMENTO, false)" in nucleo,
       "consentimento do fundo não é desligado por padrão")
exigir("catch (_: Exception)" in nucleo and "false" in nucleo,
       "falha ao ler o consentimento precisa manter a automação desligada")
exigir("jarvis.acessibilidade.ativo" in store,
       "preferência do app mudou e o fundo ficou para trás")

# 4. Toque só com confirmação falada, com prazo.
for termo in ("telaPendente", "perguntarConfirmacaoTela", "JarvisTelaVoz.confirmar(",
              "PRAZO_CONFIRMACAO_MS", "ouvirConfirmacaoTela",
              "conferir" if False else "Cancelado. Nada foi tocado na tela."):
    exigir(termo in servico, f"serviço do fundo sem {termo}")
exigir("Ninguém confirmou o toque" in servico,
       "prazo da confirmação sem recusa falada")
exigir(servico.count("telaPendente = null") >= 2,
       "pendência não é limpa no fim do comando e no prazo")
exigir("voz?.falar(pergunta) { ouvirConfirmacaoTela() }" in servico,
       "microfone pode abrir junto com a pergunta")

# 5. Ordem e histórico.
posicao_tela = servico.find("JarvisTelaVoz.interpretar(texto)")
posicao_fundo = servico.find("JarvisFundo.interpretar(texto)")
exigir(0 <= posicao_tela < posicao_fundo,
       "comando de tela precisa ser avaliado antes da pergunta livre")
exigir("JarvisFundo.registrarHistorico(" in servico,
       "execução de tela no fundo não entra no histórico")
exigir("origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO" in servico,
       "histórico do fundo sem a origem de segundo plano")
exigir("Thread {" in servico and "handler.post { finalizarComando" in servico,
       "execução de tela deveria sair da thread principal")
exigir("comando de tela sem consentimento" in servico,
       "recusa por falta de consentimento não é registrada")

# 6. Preparo do runner copia o arquivo novo.
exigir('shutil.copy2(ANDROID / "JarvisTelaVoz.kt"' in preparo,
       "preparo não copia JarvisTelaVoz.kt")
exigir("JarvisTelaVoz.kt" in preparo.split("def verificar")[1],
       "verificação do preparo não confere JarvisTelaVoz.kt")

# 7. A conversa com o app aberto continua com confirmação.
for termo in ("ConversaDeTela.decidir", "confirmar-toque-tela",
              "await _tela.consentido()"):
    exigir(termo in conversa, f"conversa perdeu {termo}")
exigir("tocar" in acessibilidade and "isPassword" in acessibilidade,
       "serviço de acessibilidade perdeu a proteção de senha")

# 8. Documentação.
exigir("tela no segundo plano" in inventario.lower() or
       "Tela no segundo plano" in inventario,
       "INVENTARIO_DE_FUNCOES sem a seção da tela no segundo plano")
exigir("ajuste 097" in comparativo, "comparativo sem a referência ao ajuste 097")

if falhas:
    print("FALHAS:")
    for falha in falhas:
        print(" -", falha)
    raise SystemExit(1)

print("Tela no segundo plano: contrato do ajuste 097 conferido.")
