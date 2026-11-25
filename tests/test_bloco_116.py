#!/usr/bin/env python3
"""Contrato do bloco 116 — entender o nome do contato e completar a voz.

O que este contrato prende, sem aparelho:

1. existe uma regra de nomes com normalização (emoji, acento, letra repetida),
   apelidos do português e comparação por semelhança, com a mesma tabela e as
   mesmas notas no Dart e no Kotlin;
2. mensagem, ligação, e-mail e conversa usam essa regra em vez do LIKE exato;
3. empate de nome vira pergunta com os candidatos, nunca palpite;
4. a lista de contatos do aparelho aparece no painel e o nome dito ordena a
   lista pelo mais parecido;
5. as telas que existiam e não abriam por voz (backups, regras do palco,
   histórico de voz e palavra de ativação) entram na tabela dos dois lados;
6. versão, CHANGELOG, relatório e registros acompanham a mudança.
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


nomes_kt = ler(ANDROID / "JarvisContatos.kt")
nomes_dart = ler(LIB / "core" / "nome_contato.dart")
aparelho_kt = ler(ANDROID / "JarvisAparelho.kt")
mensagens_kt = ler(ANDROID / "JarvisMensagens.kt")
abrir_app_kt = ler(ANDROID / "JarvisAbrirApp.kt")
painel = ler(LIB / "services" / "aparelho_page.dart")
regra_telas = ler(LIB / "core" / "pedido_abrir.dart")
telas_kt = ler(ANDROID / "JarvisAbrirTela.kt")
abrir_tela = ler(LIB / "services" / "abrir_tela.dart")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_116-voz-e-nomes-de-contato.md")

# 1. Regra de nomes dos dois lados.
for trecho in ["fun normalizar(", "fun variantes(", "fun pontuar(",
               "fun distancia(", "fun resolver(", "fun buscar(",
               "fun aprender(", "fun lista(", "NOTA_MINIMA = 0.55",
               "EMPATE = 0.02", "val primeiroTelefone"]:
    exigir(trecho in nomes_kt, f"JarvisContatos.kt não tem {trecho}")

for trecho in ["normalizarNomeContato(", "variantesNome(", "semelhancaNome(",
               "distanciaEdicao(", "escolherContato(", "ordenarContatosPorNome(",
               "notaMinimaContato = 0.55", "empateContato = 0.02"]:
    exigir(trecho in nomes_dart, f"nome_contato.dart não tem {trecho}")

# Emoji, acento e letra repetida são tratados na normalização.
exigir("\\u0300-\\u036f" in nomes_kt or "Normalizer.Form.NFD" in nomes_kt,
       "o Kotlin não tira acento do nome")
exigir("a-z0-9" in nomes_kt, "o Kotlin não tira emoji e pontuação do nome")
exigir("a-z0-9" in nomes_dart, "o Dart não tira emoji e pontuação do nome")
exigir("anterior" in nomes_kt and "anterior" in nomes_dart,
       "os dois lados não compactam letra repetida")

# Mesma tabela de apelidos nos dois lados.
apelidos_kt = set(re.findall(r'^\s*"([a-z]+)" to listOf\(', nomes_kt, re.M))
apelidos_dart = set(re.findall(r"^\s*'([a-z]+)': \[", nomes_dart, re.M))
exigir(apelidos_kt == apelidos_dart,
       "apelidos diferentes entre Dart e Kotlin: "
       f"só no Kotlin {sorted(apelidos_kt - apelidos_dart)}, "
       f"só no Dart {sorted(apelidos_dart - apelidos_kt)}")
for apelido, nomes in [("bia", ("beatriz", "bianca")), ("ze", ("jose",)),
                       ("duda", ("eduarda",)), ("nanda", ("fernanda",))]:
    exigir(apelido in apelidos_kt, f"apelido {apelido} não está na tabela")
    linha = re.search(rf'"{apelido}" to listOf\(([^)]*)\)', nomes_kt)
    for nome in nomes:
        exigir(linha is not None and nome in linha.group(1),
               f"apelido {apelido} não aponta {nome}")

# 2. Quem usa a regra.
exigir("JarvisContatos.resolver(" in aparelho_kt,
       "o canal do aparelho não resolve o nome do contato")
exigir("JarvisContatos.buscar(" in aparelho_kt,
       "a busca de contatos não usa a semelhança")
exigir("JarvisContatos.resolver(" in mensagens_kt,
       "mensagem/ligação no segundo plano não resolvem o nome")
exigir("JarvisContatos.resolver(" in abrir_app_kt,
       "abrir app com ação não resolve o nome do contato")
exigir("LIKE ?" not in aparelho_kt.split("private fun telefoneDe")[1][:400],
       "telefoneDe ainda procura por texto exato")
exigir("escolha.ambiguo" in mensagens_kt,
       "o segundo plano não pergunta quando o nome empata")
exigir("Achei mais de um contato parecido" in mensagens_kt,
       "a resposta de empate não lista os candidatos")

# 3. Lista de contatos no painel, ordenada pelo nome dito.
exigir("ordenarContatosPorNome(" in painel,
       "o painel de contatos não ordena pelo nome falado")
exigir("buscarContatos(procurado)" in painel,
       "o painel não busca com o texto digitado")

# 4. Telas que faltavam.
for chave in ["backups", "regras_palco", "historico_voz", "ativacao"]:
    exigir(f"'{chave}'" in regra_telas,
           f"a tela {chave} não está na regra Dart")
    exigir(f'"{chave}"' in telas_kt,
           f"a tela {chave} não está no espelho Kotlin")
for caso in ["TelaJarvis.historicoVoz", "TelaJarvis.backups",
             "TelaJarvis.regrasPalco", "TelaJarvis.ativacao"]:
    exigir(f"case {caso}:" in abrir_tela,
           f"AbrirTela não monta {caso}")
exigir("KwsSettingsPage(" in abrir_tela,
       "a palavra de ativação não abre a tela de configuração")
exigir("PalcoRegrasPage(" in abrir_tela,
       "as regras do palco não abrem a tela")
exigir("BackupsPage(" in abrir_tela, "os backups não abrem a tela")
exigir("HistoricoVozPage(" in abrir_tela,
       "o histórico de voz não abre a tela")

# 5. Empacotamento.
exigir('shutil.copy2(ANDROID / "JarvisContatos.kt"' in preparo,
       "prepare_android_sistema.py não copia JarvisContatos.kt")

# 6. Versão, docs e registros.
exigir("version: 1.97.0+19700" in pubspec,
       "pubspec.yaml não está em 1.97.0+19700")
exigir("## 1.93.0" in changelog, "CHANGELOG.md não tem o bloco 1.93.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 116")
exigir("test_bloco_116.py" in pacote, "package.json não roda o contrato 116")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_116.py" in dados["scripts"]["test:all"],
           "o contrato 116 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

exigir("tool/nome_contato_test.dart" in nucleo,
       "o teste puro dos nomes não está em test_dart_core.py")
exigir((APP / "tool" / "nome_contato_test.dart").is_file(),
       "falta flutter_app/tool/nome_contato_test.dart")

if falhas:
    print("Falhas do bloco 116:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 116: nomes de contato e telas por voz — contrato OK")
