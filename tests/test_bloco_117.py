#!/usr/bin/env python3
"""Contrato do bloco 117 — apelido novo, mapa da voz e funções restantes.

O que este contrato prende, sem aparelho:

1. toda tela do app é alcançável por voz ou está declarada como excluída com
   motivo — a conferência das funções restantes vira teste, não relatório;
2. “o apelido do Murilo é Murilin” é reconhecido no Dart e no Kotlin, grava no
   aparelho, esquece e aparece no painel;
3. “quais telas você abre?” responde no aparelho e a lista completa é uma tela
   que também abre por voz;
4. o total de telas do Kotlin bate com a tabela Dart;
5. versão, CHANGELOG, relatório e registros acompanham a mudança.
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


apelido_dart = ler(LIB / "core" / "pedido_apelido.dart")
apelido_servico = ler(LIB / "services" / "apelido.dart")
mapa_dart = ler(LIB / "core" / "mapa_voz.dart")
mapa_pagina = ler(LIB / "services" / "mapa_voz_page.dart")
regra_telas = ler(LIB / "core" / "pedido_abrir.dart")
telas_kt = ler(ANDROID / "JarvisAbrirTela.kt")
abrir_tela = ler(LIB / "services" / "abrir_tela.dart")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
painel = ler(LIB / "services" / "aparelho_page.dart")
servico_aparelho = ler(LIB / "services" / "aparelho_service.dart")
aparelho_kt = ler(ANDROID / "JarvisAparelho.kt")
apelidos_kt = ler(ANDROID / "JarvisApelidos.kt")
mapa_kt = ler(ANDROID / "JarvisMapaVoz.kt")
contatos_kt = ler(ANDROID / "JarvisContatos.kt")
kws = ler(ANDROID / "KwsForegroundService.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_117-apelido-mapa-e-funcoes-restantes.md")

# 0. Cobertura: cada tela do app tem caminho de voz ou exclusão declarada.
MAPA = {
    "acessibilidade": "acessibilidade",
    "aparelho": "aparelho",
    "arquivos": "arquivos",
    "atualizacao": "atualizacoes",
    "avatar": "avatar",
    "backups": "backups",
    "bloqueio": "seguranca",
    "cadesimu": "cadesimu",
    "circuito": "circuito",
    "comandos_android": "comandos",
    "dispositivo": "dispositivo",
    "gestos": "gestos",
    "habilidades": "habilidades",
    "hermes": "hermes",
    "historico": "historico",
    "historico_voz": "historico_voz",
    "kws_settings": "ativacao",
    "mapa_voz": "mapa_voz",
    "memoria": "memoria",
    "modelos_locais": "modelos_locais",
    "palco": "palco",
    "palco_regras": "regras_palco",
    "personalidade": "personalizacao",
    "pessoas": "pessoas",
    "programacao": "programacao",
    "projetista": "projetista",
    "segundo_plano": "segundo_plano",
    "seguranca": "seguranca",
    "tarefas": "tarefas",
    "timbre": "timbre",
    "visao": "visao",
    "voice_conversation": "conversa",
    "voz_externa": "voz_externa",
    "voz_tela_cheia": "voz",
}
EXCLUIDOS = {
    "conflitos": "precisa da lista de conflitos e do cofre; aberta vazia não mostra nada",
    "modo_visita": "fluxo de segurança com PIN e bloqueio; não abre por voz",
    "pareamento": "mostra um código na tela para o PC digitar; abrir por voz não ajuda e "
        "exporia o fluxo de pareamento a um comando falado",
}

paginas = sorted(p.stem.removesuffix("_page")
                 for p in (LIB / "services").glob("*_page.dart"))
exigir(paginas, "nenhuma página encontrada em lib/services")
for pagina in paginas:
    exigir(pagina in MAPA or pagina in EXCLUIDOS,
           f"a tela {pagina} não tem caminho de voz nem exclusão declarada")
for pagina in MAPA:
    exigir((LIB / "services" / f"{pagina}_page.dart").is_file(),
           f"o mapa aponta {pagina}, mas a página não existe")
for pagina in EXCLUIDOS:
    exigir((LIB / "services" / f"{pagina}_page.dart").is_file(),
           f"a exclusão {pagina} aponta uma página que não existe")

entradas = re.findall(r"^\s+(\w+)\('([a-z_]+)',", regra_telas, re.M)
chave_para_enum = {chave: nome for nome, chave in entradas}
for pagina, chave in MAPA.items():
    exigir(chave in chave_para_enum,
           f"{pagina} aponta a chave {chave}, que não existe em TelaJarvis")
    enum = chave_para_enum.get(chave)
    if enum:
        exigir(f"case TelaJarvis.{enum}:" in abrir_tela,
               f"AbrirTela não monta {enum} (tela {pagina})")
        exigir(f"'{chave}'" in regra_telas,
               f"a chave {chave} não está na tabela Dart")
        exigir(f'"{chave}"' in telas_kt,
               f"a chave {chave} não está no espelho Kotlin")

# 1. Apelido novo.
for trecho in ["PedidoApelido? pedidoApelido(", "_esquecer", "_porApelido",
               "_chamar", "_conhecer", "fraseFalada"]:
    exigir(trecho in apelido_dart, f"a regra de apelido não tem {trecho}")
exigir("AprenderApelido.executar(" in conversa,
       "a conversa não chama AprenderApelido")
exigir("'aprenderApelido'" in servico_aparelho,
       "o serviço Dart não chama aprenderApelido")
exigir('"aprenderApelido" -> result.success(' in aparelho_kt,
       "o canal do aparelho não recebe aprenderApelido")
exigir('"apelidos" -> result.success(' in aparelho_kt,
       "o canal não devolve os apelidos aprendidos")
for trecho in ["fun interpretar(", "fun executar(", "JarvisContatos.resolver(",
               "JarvisContatos.aprender(", "Achei mais de um contato parecido"]:
    exigir(trecho in apelidos_kt, f"JarvisApelidos.kt não tem {trecho}")
for trecho in ["fun apelidos(", "fun esquecer("]:
    exigir(trecho in contatos_kt, f"JarvisContatos.kt não tem {trecho}")
exigir("JarvisApelidos.interpretar(texto)" in kws,
       "o segundo plano não reconhece apelido")
exigir("private fun executarApelido(" in kws,
       "o segundo plano não executa o apelido")
for trecho in ["apelidos-lista", "apelidos-vazio", "servico.apelidos()"]:
    exigir(trecho in painel, f"o painel não mostra os apelidos ({trecho})")

# 2. Mapa da voz.
for trecho in ["String? respostaMapaDaVoz(", "List<CategoriaDaVoz> mapaDaVoz()",
               "totalDeTelasPorVoz"]:
    exigir(trecho in mapa_dart, f"mapa_voz.dart não tem {trecho}")
exigir("respostaMapaDaVoz(texto)" in conversa,
       "a conversa não responde a pergunta do mapa")
exigir("JarvisMapaVoz.pergunta(texto)" in kws,
       "o segundo plano não responde a pergunta do mapa")
exigir("TOTAL_TELAS = " in mapa_kt, "o Kotlin não declara o total de telas")
total_kt = re.search(r"TOTAL_TELAS = (\d+)", mapa_kt)
exigir(total_kt is not None and int(total_kt.group(1)) == len(entradas),
       "o total de telas do Kotlin não bate com TelaJarvis")
exigir("MapaVozPage(" in mapa_pagina, "a página do mapa não existe")

# 3. Empacotamento.
for classe in ["JarvisApelidos.kt", "JarvisMapaVoz.kt"]:
    exigir(f'shutil.copy2(ANDROID / "{classe}"' in preparo,
           f"prepare_android_sistema.py não copia {classe}")

# 4. Versão, docs e registros.
exigir("version: 1.110.0+111000" in pubspec,
       "pubspec.yaml não está em 1.110.0+111000")
exigir("## 1.94.0" in changelog, "CHANGELOG.md não tem o bloco 1.94.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 117")
exigir("test_bloco_117.py" in pacote, "package.json não roda o contrato 117")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_117.py" in dados["scripts"]["test:all"],
           "o contrato 117 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

for teste in ["tool/pedido_apelido_test.dart", "tool/mapa_voz_test.dart"]:
    exigir(teste in nucleo, f"{teste} não está em test_dart_core.py")
    exigir((APP / teste).is_file(), f"falta {teste}")

if falhas:
    print("Falhas do bloco 117:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 117: apelido, mapa da voz e cobertura das telas — contrato OK")
