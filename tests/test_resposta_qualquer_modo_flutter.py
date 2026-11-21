#!/usr/bin/env python3
"""Contrato da resposta em qualquer modo (ajuste 085, versão 1.72.0).

Com a tela aberta, o JARVIS reconhecia o comando na conversa; sem a autorização
de "Exibir sobre outros apps" ele caía no caminho de segundo plano e respondia
"Não reconheci esse comando em segundo plano" — inclusive para uma pergunta
simples como "que horas são".

O que este contrato prende, sem aparelho:

1. a tela aberta muda a rota: comando chamado pelo app não é tratado como
   segundo plano;
2. hora e data são respondidas no próprio aparelho (sem provedor, sem rede);
3. pergunta livre vai ao provedor de IA já configurado, pela ponte com o
   Flutter, e a resposta é falada;
4. sem ponte/provedor a resposta é honesta, nunca "não tenho essa função em
   segundo plano";
5. o texto falado é limpo de markdown antes de ir para a síntese de voz;
6. nada de GlobalScope, shell ou conexão de rede nova no Kotlin.

Continua fora deste contrato: a resposta real em aparelho físico, que depende
de provedor configurado e do motor do Flutter vivo.
"""

from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
KOTLIN = APP / "android"
LIB = APP / "lib"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


fundo_kt = ler(KOTLIN / "JarvisFundo.kt")
servico_kt = ler(KOTLIN / "KwsForegroundService.kt")
atividade_kt = ler(KOTLIN / "MainActivity.kt")
ponte_kt = ler(KOTLIN / "JarvisPonteIa.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
pergunta = ler(LIB / "core" / "pergunta_livre.dart")
ponte_dart = ler(LIB / "services" / "ponte_ia_fundo.dart")
principal = ler(LIB / "main.dart")
fundo_dart = ler(LIB / "core" / "fundo.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_085-resposta-em-qualquer-modo-e-resumo-tatico.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.79.0+17900" in pubspec, "versão não atualizada para 1.72.0")
exigir("1.72.0" in changelog, "CHANGELOG sem o bloco 1.72.0")
exigir("tests/test_resposta_qualquer_modo_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/pergunta_livre_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 085 ausente")

# 2. A tela aberta não é segundo plano.
exigir("@Volatile private var visivel = false" in atividade_kt,
       "MainActivity sem o estado de tela visível")
exigir("@JvmStatic fun marcarVisivel(ativo: Boolean)" in atividade_kt,
       "MainActivity não marca a visibilidade")
exigir("marcarVisivel(true)" in atividade_kt and
       "marcarVisivel(false)" in atividade_kt,
       "visibilidade não é atualizada em onResume/onPause")
exigir("!MainActivity.estaVisivel() &&" in servico_kt,
       "serviço não distingue tela aberta de segundo plano")

# 3. Hora e data são locais.
for termo in ("HORA", "DATA", "horaFalada", "dataFalada", "Calendar"):
    exigir(termo in fundo_kt, f"JarvisFundo.kt sem {termo}")
exigir("Agora são $hora horas" in fundo_kt,
       "hora não é dita em frase falável")
exigir("Hoje é $dia" in fundo_kt, "data não é dita em frase falável")

# 4. Pergunta livre vai para a IA, com resposta honesta quando não há ponte.
exigir("if (comando.tipo == JarvisFundo.Tipo.DESCONHECIDO)" in servico_kt,
       "serviço não desvia a pergunta livre para a IA")
exigir("responderPerguntaLivre(" in servico_kt,
       "serviço sem o caminho da pergunta livre")
exigir("JarvisPonteIa.perguntar(" in servico_kt,
       "serviço não usa a ponte de IA")
exigir("Não consegui consultar a IA agora" in servico_kt,
       "sem ponte, a resposta não é honesta")
exigir("Não reconheci esse comando em segundo plano" not in servico_kt and
       "Não reconheci esse comando em segundo plano" not in fundo_kt,
       "a recusa antiga de segundo plano continua no código")
exigir('"pergunta livre"' in servico_kt,
       "histórico não registra a pergunta livre")

# 5. Ponte Kotlin: canal, prazo e registro na Activity.
exigir('const val CANAL = "com.jarvis.nova/fundo_ia"' in ponte_kt,
       "ponte sem o canal combinado")
exigir("ESPERA_MS" in ponte_kt and "50_000L" in ponte_kt,
       "ponte sem prazo de espera")
exigir("AtomicBoolean" in ponte_kt,
       "ponte pode responder duas vezes à mesma pergunta")
exigir("JarvisPonteIa.registrar(flutterEngine)" in atividade_kt,
       "Activity não registra a ponte de IA")
exigir('shutil.copy2(ANDROID / "JarvisPonteIa.kt"' in preparo,
       "preparo não copia JarvisPonteIa.kt")

# 6. Ponte Dart: mesmo canal, provedor já configurado, resposta falável.
exigir("com.jarvis.nova/fundo_ia" in ponte_dart,
       "ponte Dart com canal diferente do Kotlin")
exigir("firstConfiguredProvider()" in ponte_dart,
       "ponte Dart não usa o provedor configurado")
exigir("responderPergunta" in ponte_dart and
       "setMethodCallHandler(_atender)" in ponte_dart,
       "ponte Dart não atende o método responderPergunta")
exigir("respostaFalada(" in ponte_dart,
       "ponte Dart não limpa o texto antes de falar")
exigir("PonteIaFundo.ligar()" in principal,
       "main.dart não liga a ponte")
exigir("PlatformException" in ponte_dart,
       "ponte Dart não sinaliza falha para o Kotlin")

# 7. Núcleo puro da pergunta.
for termo in ("instrucaoPerguntaVoz", "mensagensPerguntaLivre",
              "respostaFalada", "português do Brasil", "Não use markdown"):
    exigir(termo in pergunta, f"core/pergunta_livre.dart sem {termo}")
exigir("montarMensagens(" in pergunta,
       "pergunta livre não reutiliza a montagem da conversa")

# 8. A tela de segundo plano não mente mais sobre perguntas livres.
exigir("continuam abrindo a tela" not in fundo_dart,
       "texto antigo ainda diz que pergunta livre abre a tela")
exigir("Dizer as horas e a data" in fundo_dart,
       "lista de ações do segundo plano não cita hora e data")

# 9. Proibições e privacidade nos arquivos novos.
for arquivo, texto in (("JarvisPonteIa.kt", ponte_kt),
                       ("JarvisFundo.kt", fundo_kt),
                       ("KwsForegroundService.kt", servico_kt)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto,
           f"{arquivo} executa shell")
for rede in ("HttpURLConnection", "OkHttpClient", "openConnection("):
    exigir(rede not in ponte_kt,
           f"JarvisPonteIa.kt abre conexão de rede ({rede})")

# 10. Documentação.
exigir("085" in inventario, "inventário sem a seção do ajuste 085")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 085 sem a seção {secao}")
    for termo in ("segundo plano", "hora", "provedor", "voz"):
        exigir(termo in texto.lower(), f"relatório 085 sem {termo}")

if falhas:
    print("FALHAS no contrato da resposta em qualquer modo:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da resposta em qualquer modo: aprovado.")
