#!/usr/bin/env python3
"""Contrato do bloco 122 — paridade das ações entre tela e segundo plano.

A varredura mostrou que a cobertura de telas estava presa em teste (bloco 117),
mas a cobertura de **ações** não: “liga para a Ana” funcionava com a tela aberta
e com o app fechado, mas “chama a Ana” só com a tela aberta, porque o verbo
faltava no espelho Kotlin. Este contrato fecha isso com uma tabela explícita.

Ele prende:

1. cada ação declarada como “ambos” existe nos dois caminhos, com marcador real;
2. cada ação declarada “só na tela” está ausente do segundo plano — quem
   implementar precisa mudar a tabela, não deixar a divergência silenciosa;
3. cada ação declarada “sem voz” continua fora do caminho de voz;
4. os verbos de ligação e de mensagem são idênticos no Dart e no Kotlin;
5. todo `core/pedido_*.dart` está classificado nesta tabela;
6. versão, CHANGELOG, relatório e registros acompanham.
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
_cache: dict[Path, str] = {}


def ler(caminho: Path) -> str:
    if caminho not in _cache:
        if not caminho.is_file():
            _cache[caminho] = ""
            falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        else:
            _cache[caminho] = caminho.read_text(encoding="utf-8")
    return _cache[caminho]


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def tem(lib_ou_android: str, marcador: str) -> bool:
    base = LIB if lib_ou_android.startswith("lib/") else APP / "android"
    return marcador in ler(base / lib_ou_android.split("/", 1)[-1]
                           if lib_ou_android.startswith("android/")
                           else APP / lib_ou_android)


# Ação → onde ela vive nos dois caminhos.
# (nome, arquivo Dart, marcador Dart, arquivo Kotlin, marcador Kotlin)
PARIDADE = [
    ("abrir tela do JARVIS", "lib/core/pedido_abrir.dart", "TelaJarvis",
     "JarvisAbrirTela.kt", "fun interpretar"),
    ("abrir app", "lib/core/comandos_android.dart", "ComandoAbrirApp",
     "JarvisFundo.kt", "Tipo.ABRIR_APP"),
    ("app já na ação", "lib/core/pedido_app.dart", "PedidoAppAcao",
     "JarvisAbrirApp.kt", "fun interpretar"),
    ("mensagem", "lib/core/aparelho.dart", "interpretarMensagem",
     "JarvisMensagens.kt", "Tipo.MENSAGEM"),
    ("ligação", "lib/core/aparelho.dart", "interpretarLigacao",
     "JarvisMensagens.kt", "Tipo.LIGACAO"),
    ("agir na tela por acessibilidade", "lib/core/acessibilidade.dart",
     "ComandoDeTela", "JarvisTelaVoz.kt", "fun interpretar"),
    ("palco", "lib/core/palco.dart", "Pedido", "JarvisPalco.kt",
     "fun interpretar"),
    ("apelido de contato", "lib/core/pedido_apelido.dart", "pedidoApelido",
     "JarvisApelidos.kt", "fun interpretar"),
    ("mapa da voz", "lib/core/mapa_voz.dart", "mapaDaVoz", "JarvisMapaVoz.kt",
     "fun pergunta"),
    ("lanterna", "lib/core/comandos_android.dart", "ComandoLanterna",
     "JarvisFundo.kt", "Tipo.LANTERNA"),
    ("volume", "lib/core/comandos_android.dart", "ComandoVolume",
     "JarvisFundo.kt", "Tipo.VOLUME"),
    ("alarme", "lib/core/comandos_android.dart", "ComandoAlarme",
     "JarvisFundo.kt", "Tipo.ALARME"),
    ("mídia (pausar, próxima)", "lib/core/aparelho.dart", "PedidoSpotify",
     "JarvisFundo.kt", "Tipo.MIDIA"),
    ("núcleo flutuante", "lib/core/pedido_nucleo.dart", "pedidoNucleo",
     "JarvisFundo.kt", "Tipo.NUCLEO"),
    ("hora e data", "lib/core/hora_data.dart", "respostaHoraData",
     "JarvisFundo.kt", "Tipo.HORA"),
]

# Ação que existe só com a tela aberta, e o marcador que prova que o segundo
# plano ainda não a tem.
SO_TELA = [
    ("ficha de pessoa", "lib/core/pedido_ficha.dart", "PedidoFicha",
     ("arquivo", "JarvisFicha.kt")),
    ("circuito por prompt", "lib/core/circuito_no_chat.dart", "RespostaCircuito",
     ("arquivo", "JarvisCircuito.kt")),
    ("localização", "lib/core/comandos_android.dart", "ComandoLocalizacao",
     ("marcador", "LOCALIZACAO")),
    ("música por nome", "lib/core/aparelho.dart", "interpretarSpotify",
     ("marcador", "interpretarSpotify")),
]

# Ação que não tem voz em nenhum dos dois caminhos, e o que não pode aparecer
# no caminho de voz.
SEM_VOZ = [
    ("anotar na memória", "a tela de memória é o único lugar que grava nota",
     ["memoria?.salvar(", "memoria!.salvar("]),
    ("notificações", "ler e responder exigem o serviço de notificações",
     ["notificacoes(", "responderNotificacao("]),
    ("visão de imagem", "a câmera e o modelo ficam na tela de visão",
     ["VisaoService("]),
    ("tarefas e rotinas", "criação de tarefa é formulário da tela",
     ["TarefasStore"]),
    ("compartilhar arquivo", "o compartilhamento é gesto do painel",
     ["compartilharArquivo("]),
]

voz = ler(LIB / "services" / "voice_conversation_page.dart")

# 1. Ações em paridade.
for nome, arquivo, marcador, kt, marcador_kt in PARIDADE:
    exigir(marcador in ler(APP / arquivo),
           f"{nome}: marcador {marcador} ausente em {arquivo}")
    exigir(marcador_kt in ler(ANDROID / kt),
           f"{nome}: marcador {marcador_kt} ausente em {kt}")

# 1b. Hora e data respondidas no aparelho também com a tela aberta.
exigir("respostaHoraData(" in voz,
       "hora e data não entram no caminho de voz com a tela aberta")

# 2. Ações só na tela — e isso precisa continuar verdadeiro.
for nome, arquivo, marcador, (tipo, alvo) in SO_TELA:
    exigir(marcador in ler(APP / arquivo),
           f"{nome}: marcador {marcador} ausente em {arquivo}")
    if tipo == "arquivo":
        exigir(not (ANDROID / alvo).is_file(),
               f"{nome}: {alvo} existe agora — atualize a tabela de paridade")
    else:
        exigir(alvo not in ler(ANDROID / "JarvisFundo.kt"),
               f"{nome}: o segundo plano passou a tratar {alvo} — "
               "atualize a tabela de paridade")

# 3. Ações sem voz continuam sem voz.
for nome, motivo, proibidos in SEM_VOZ:
    for proibido in proibidos:
        exigir(proibido not in voz,
               f"{nome} entrou no caminho de voz ({proibido}); "
               f"a tabela diz que ainda não tem voz porque {motivo}")

# 4. Verbos idênticos nos dois lados.
def verbos_da_linha(linha: str) -> set[str]:
    # O último parêntese abre o grupo de verbos: em Kotlin a declaração começa
    # com `Regex(` e o Dart com `RegExp(r'`.
    inicio = linha.rindex("(")
    fim = linha.index(")", inicio)
    return {v for v in linha[inicio + 1:fim].split("|") if v.isalpha()}


def bloco_com(texto: str, chave: str) -> str:
    """Linha da chave; se a declaração quebrar, junta até fechar o parêntese."""
    linhas = texto.splitlines()
    for i, linha in enumerate(linhas):
        if chave in linha:
            j = i
            while ")" not in linhas[j] and j + 1 < len(linhas):
                j += 1
            return " ".join(linhas[i:j + 1])
    return ""


aparelho = ler(LIB / "core" / "aparelho.dart")
mensagens_kt = ler(ANDROID / "JarvisMensagens.kt")
pares = [
    ("ligação",
     bloco_com(aparelho, r"RegExp(r'\b(liga|"),
     bloco_com(mensagens_kt, "VERBO_LIGACAO")),
    ("mensagem",
     bloco_com(aparelho, r"\b(manda|mandar|mande"),
     bloco_com(mensagens_kt, "VERBO_MENSAGEM")),
]
for nome, linha_dart, linha_kt in pares:
    exigir(bool(linha_dart) and bool(linha_kt),
           f"{nome}: não achei a lista de verbos nos dois lados")
    if linha_dart and linha_kt:
        exigir(verbos_da_linha(linha_dart) == verbos_da_linha(linha_kt),
               f"{nome}: verbos divergem — Dart {sorted(verbos_da_linha(linha_dart))} "
               f"× Kotlin {sorted(verbos_da_linha(linha_kt))}")

# 5. Todo pedido novo precisa entrar na tabela.
classificados = {arquivo for _, arquivo, _, _, _ in
                 [(p[0], p[1], p[2], p[3], p[4]) for p in PARIDADE]}
classificados |= {arquivo for _, arquivo, _, _ in SO_TELA}
for pedido in sorted((LIB / "core").glob("pedido_*.dart")):
    relativo = pedido.relative_to(APP).as_posix()
    exigir(relativo in classificados,
           f"{relativo} não está classificado na tabela de paridade")

# 6. Versão, docs e registros.
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_122-paridade-das-acoes.md")
exigir("version: 1.109.0+110900" in pubspec,
       "pubspec.yaml não está em 1.109.0+110900")
exigir("## 1.99.0" in changelog, "CHANGELOG.md não tem o bloco 1.99.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 122")
exigir("test_bloco_122.py" in pacote, "package.json não roda o contrato 122")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_122.py" in dados["scripts"]["test:all"],
           "o contrato 122 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")
exigir("tool/ligacao_paridade_test.dart" in nucleo,
       "o teste da regra de ligação não está em test_dart_core.py")

if falhas:
    print("Falhas do bloco 122:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 122: paridade das ações tela × segundo plano — contrato OK")
