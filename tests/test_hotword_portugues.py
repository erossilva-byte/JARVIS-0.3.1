#!/usr/bin/env python3
"""Contrato da hotword em português (ajuste 098, versão 1.84.0).

A lacuna do comparativo com o U.L.T.R.O.N. era a hotword fonética: o detector
só aceitava “Jarvis” e variações escritas em inglês, e a pessoa não tinha como
dizer ao JARVIS como ela chama. Agora existe uma tabela única em português do
Brasil (`lib/core/hotword_portugues.dart`) com o nome, as pronúncias que já
existiam e as frases de tratamento (“Ei Jarvis”, “Oi Jarvis”, “Alô Jarvis”,
“Olá Jarvis”), e a tela deixa ligar só as que a pessoa usa.

Este contrato prende o que é verificável sem aparelho:

1. cada frase usa apenas tokens que existem no `tokens.txt` do APK — token
   inventado faria o KeywordSpotter falhar na criação do stream;
2. o conjunto de fábrica é exatamente o `keywords.txt` empacotado, então ligar
   o app não muda a escuta de quem já usava;
3. o Flutter grava a escolha e o serviço Android a lê com o app fechado;
4. o motor descarta linha inválida em vez de derrubar o detector;
5. nada de GlobalScope, shell, rede ou reconhecedor de nuvem.

Voz real, sotaque e taxa de acerto continuam fora deste contrato: nada aqui foi
compilado nem executado em aparelho nesta sessão.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
ANDROID = APP / "android"
ASSETS = ANDROID / "app" / "src" / "main" / "assets" / "kws"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


tabela = ler(APP / "lib" / "core" / "hotword_portugues.dart")
loja = ler(APP / "lib" / "services" / "hotword_store.dart")
ponte = ler(APP / "lib" / "services" / "kws_bridge.dart")
controlador = ler(APP / "lib" / "services" / "kws_controller.dart")
tela = ler(APP / "lib" / "services" / "kws_settings_page.dart")
motor = ler(RAIZ / "JarvisKwsEngine.java")
servico = ler(ANDROID / "KwsForegroundService.kt")
principal = ler(ANDROID / "MainActivity.kt")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_098-hotword-em-portugues.md")

# 1. Versão, changelog, suíte e relatório.
exigir("version: 1.100.0+110000" in pubspec,
       "versão não atualizada para 1.87.0+18700")
exigir("1.84.0" in changelog and "portugu" in changelog.lower(),
       "CHANGELOG sem o bloco 1.84.0 da hotword em português")
exigir("tests/test_hotword_portugues.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 098 ausente")

# 2. Toda frase usa tokens do modelo que vai no APK.
vocabulario: set[str] = set()
arquivo_tokens = ASSETS / "tokens.txt"
if arquivo_tokens.is_file():
    for linha in arquivo_tokens.read_text(encoding="utf-8").splitlines():
        partes = linha.split()
        if partes:
            vocabulario.add(partes[0])
exigir(len(vocabulario) > 100, "tokens.txt do modelo ausente ou vazio")

frases: list[dict[str, str]] = []
for bloco in tabela.split("VarianteHotword(")[1:]:
    trecho = bloco.split("),")[0]
    campos = {
        "id": re.search(r"id:\s*'([^']+)'", trecho),
        "frase": re.search(r"frase:\s*'([^']+)'", trecho),
        "tokens": re.search(r"tokens:\s*'([^']+)'", trecho),
        "padrao": "padrao: true" in trecho,
    }
    # O construtor da classe também abre “VarianteHotword(”: só entram no
    # conjunto os blocos que declaram um identificador.
    if campos["id"] is None:
        continue
    exigir(all(campos[k] for k in ("frase", "tokens")),
           f"variante sem frase/tokens: {trecho.strip()[:80]}")
    if not all(campos[k] for k in ("frase", "tokens")):
        continue
    frases.append({
        "id": campos["id"].group(1),
        "frase": campos["frase"].group(1),
        "tokens": campos["tokens"].group(1),
        "padrao": campos["padrao"],
    })

exigir(len(frases) >= 15, f"tabela com poucas frases: {len(frases)}")
ids = [f["id"] for f in frases]
exigir(len(ids) == len(set(ids)), "identificador repetido na tabela")
for frase in frases:
    for token in frase["tokens"].split(" "):
        exigir(token in vocabulario,
               f"token {token!r} de {frase['frase']} não existe no tokens.txt")

# 3. O conjunto de fábrica é o keywords.txt empacotado, linha por linha.
arquivo_chaves = ASSETS / "keywords.txt"
chaves_assets = ([linha.strip() for linha in
                  arquivo_chaves.read_text(encoding="utf-8").splitlines()
                  if linha.strip()] if arquivo_chaves.is_file() else [])
padrao = [f["tokens"] for f in frases if f["padrao"]]
exigir(len(padrao) == len(set(padrao)), "linha padrão repetida")
exigir(set(padrao) == set(chaves_assets),
       "conjunto de fábrica difere do keywords.txt empacotado: "
       f"tabela={sorted(set(padrao))} assets={sorted(set(chaves_assets))}")
exigir(len(padrao) == 11, f"o padrão deveria manter as 11 frases antigas: {len(padrao)}")
for obrigatoria in ("ei-jarvis", "oi-jarvis", "alo-jarvis", "ola-jarvis"):
    exigir(obrigatoria in ids, f"frase em português ausente: {obrigatoria}")
    exigir(not any(f["id"] == obrigatoria and f["padrao"] for f in frases),
           f"{obrigatoria} não deveria vir ligada de fábrica")

# 4. Limite igual nos dois lados.
limite_dart = re.search(r"static const int limite = (\d+);", tabela)
limite_java = re.search(r"static final int LIMITE_FRASES = (\d+);", motor)
exigir(limite_dart is not None and limite_java is not None,
       "limite de frases não declarado nos dois lados")
if limite_dart and limite_java:
    exigir(limite_dart.group(1) == limite_java.group(1),
           "limite de frases difere entre Dart e Java")

# 5. Persistência: o Flutter grava, o Kotlin lê com o app fechado.
exigir("chaveHotwordAtivos = 'jarvis.hotword.ativos'" in loja,
       "loja sem a chave dos identificadores")
exigir("chaveHotwordLinhas = 'jarvis.hotword.linhas'" in loja,
       "loja sem a chave das linhas tokenizadas")
exigir("class HotwordStore implements PreferenciasHotword" in loja,
       "loja sem implementação de preferências")
exigir('PREFS_FLUTTER = "FlutterSharedPreferences"' in servico,
       "serviço não lê as preferências do Flutter")
exigir('CHAVE_HOTWORD_LINHAS = "flutter.jarvis.hotword.linhas"' in servico,
       "serviço não lê a chave das linhas com o prefixo flutter.")
exigir("fun linhasHotwordDe(context: Context): String" in servico,
       "serviço sem leitura das linhas")
exigir("linhasHotwordDe(applicationContext)" in servico,
       "as frases escolhidas não chegam ao motor")
exigir("fun aplicarHotword(context: Context)" in servico,
       "serviço sem ação de aplicar as frases na hora")
trecho_aplicar = servico.split("fun aplicarHotword(context: Context)")[1][:600]
exigir("ACTION_REINICIAR" in trecho_aplicar,
       "aplicar as frases não reinicia o detector")
exigir("if (!running) return" in trecho_aplicar,
       "aplicar as frases sem checar se o serviço está de pé")

# 6. O motor valida a linha antes de gravar e cai no asset quando não há nada.
exigir("private final String linhasHotword;" in motor,
       "motor sem o campo das linhas escolhidas")
exigir("this.linhasHotword = linhasHotword == null ? \"\" : linhasHotword;" in motor,
       "construtor não guarda as linhas escolhidas")
exigir("gravarPalavrasChave(dir);" in motor,
       "motor não aplica as frases antes de abrir o detector")
exigir("private int gravarPalavrasChave(File dir)" in motor,
       "motor sem rotina de gravar as frases")
exigir("lerVocabulario(new File(dir, \"tokens.txt\"))" in motor,
       "motor não confere os tokens contra o tokens.txt")
exigir("if (validas.isEmpty()) return 0;" in motor,
       "motor não preserva o keywords.txt dos assets quando não há linha válida")
exigir("static String fraseLegivel(String linha)" in motor,
       "motor sem conversão dos tokens em nome legível")
exigir("palavrasLegiveis" in motor.split("listener.onState(\"KWS local ativo")[1][:200],
       "diagnóstico não mostra as frases em uso")
exigir("new String[]{\n                \"Jarvis\"" in motor,
       "conjunto antigo de palavras saiu do motor")
exigir("montarPalavrasChave(extraKeywords)" in motor,
       "caminho antigo (JarvisService) perdeu as variantes")

# 7. Ponte, controlador, tela e canal.
exigir("Future<KwsStatus> aplicarHotword();" in ponte,
       "ponte sem método de aplicar as frases")
exigir("'aplicarHotword'" in ponte, "ponte não chama o método nativo")
exigir("final int hotword;" in ponte, "estado sem a contagem de frases")
exigir("int get hotword => _status.hotword;" in controlador,
       "controlador não expõe a contagem de frases")
exigir("Future<KwsStatus> aplicarHotword()" in controlador,
       "controlador sem ação de aplicar as frases")
exigir('"aplicarHotword" ->' in principal,
       "MainActivity não expõe aplicarHotword ao Flutter")
exigir('"hotword" to KwsForegroundService.quantasHotwordsDe(this)' in principal,
       "diagnóstico não devolve a contagem de frases")
exigir("Palavras que acordam o JARVIS" in tela,
       "tela sem a lista de frases")
exigir("ValueKey('hotword-${variante.id}')" in tela,
       "cada frase precisa de chave estável na tela")
exigir("Deixe pelo menos uma frase ligada" in tela,
       "tela pode deixar a escuta sem nenhuma frase")
exigir("HotwordPortugues.nomeAmigavel(controller.lastWake!)" in tela,
       "a ativação recebida não é traduzida para o nome legível")
exigir("hotwordStore.gravar(_hotword)" in tela,
       "marcar a frase não grava a escolha")
exigir("controller.aplicarHotword()" in tela,
       "marcar a frase não religa o detector")
exigir("class VarianteHotword" in tabela and "grupoTratamento" in tabela,
       "tabela em português sem grupos")
exigir("static const int limite = 16;" in tabela,
       "tabela sem o limite de frases")

# 8. Proibições de sempre.
for arquivo, texto in (("KwsForegroundService.kt", servico),
                       ("MainActivity.kt", principal),
                       ("JarvisKwsEngine.java", motor)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")
exigir("SpeechRecognizer.createSpeechRecognizer(" not in servico,
       "serviço de ativação voltou a usar reconhecedor de nuvem")

# 9. Comparativo e inventário reconhecem o bloco.
exigir("ajuste 098" in comparativo,
       "comparativo do U.L.T.R.O.N. sem o ajuste 098")
exigir("hotword" in inventario.lower() and "098" in inventario,
       "inventário sem a hotword do ajuste 098")
if relatorio.is_file():
    texto = relatorio.read_text(encoding="utf-8")
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 5. O que muda na ativação por voz", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 098 sem a seção {secao}")
    for termo in ("ei jarvis", "token", "inglês", "aparelho"):
        exigir(termo in texto.lower(), f"relatório 098 sem {termo}")

if falhas:
    print("FALHAS no contrato da hotword em português:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da hotword em português: aprovado.")
