#!/usr/bin/env python3
"""Contrato da sentinela de mensagens (ajuste 084, versão 1.71.0).

O JARVIS já lia as notificações, mas só mostrava o texto. Faltava o que o
ULTRON chama de resposta em segundo plano: injetar a resposta no campo da
própria notificação (RemoteInput) sem abrir WhatsApp/Telegram/SMS, e ler as
mensagens em voz alta.

O que este contrato prende, sem aparelho:

1. a notificação guarda chave, pacote e se aceita resposta;
2. a resposta usa o `RemoteInput` da notificação e o `PendingIntent` dela;
3. sem serviço conectado, sem ação de resposta ou sem chave, a recusa é
   explícita — nunca “enviado” sem confirmação;
4. a escolha da mensagem a responder é do mais recente para o mais antigo e
   respeita o app pedido;
5. a leitura em voz alta usa só o que veio do Android;
6. nada de nuvem, shell ou GlobalScope.

Continua fora deste contrato: o envio real no WhatsApp/Telegram, que só o
aparelho confirma.
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


ouvinte = ler(KOTLIN / "JarvisNotificacaoListener.kt")
aparelho_kt = ler(KOTLIN / "JarvisAparelho.kt")
modelo = ler(APP / "lib" / "core" / "aparelho.dart")
servico = ler(APP / "lib" / "services" / "aparelho_service.dart")
tela = ler(APP / "lib" / "services" / "aparelho_page.dart")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_084-sentinela-de-mensagens.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.108.0+110800" in pubspec, "versão não atualizada para 1.71.0")
exigir("1.71.0" in changelog and "mensagens" in changelog.lower(),
       "CHANGELOG sem o bloco 1.71.0 da sentinela")
exigir("tests/test_sentinela_mensagens_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/aparelho_resposta_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 084 ausente")

# 2. O ouvinte guarda o necessário e responde pela própria notificação.
for termo in ("RemoteInput.addResultsToIntent", "acaoDeResposta",
              "respondiveis", "limiteRespostas", '"respondivel" to responde',
              '"chave" to n.key'):
    exigir(termo in ouvinte, f"JarvisNotificacaoListener.kt sem {termo}")
exigir("acao.actionIntent.send(servico, 0, preenchido)" in ouvinte,
       "resposta não é entregue pelo PendingIntent da notificação")
exigir("instancia" in ouvinte,
       "ouvinte não guarda a instância conectada para responder")
exigir("esquecer(n.key)" in ouvinte,
       "notificação respondida/removida continua guardada para resposta")
exigir("FLAG_ONGOING_EVENT" in ouvinte,
       "notificação fixa pode virar alvo de resposta")
exigir('"responderNotificacao" ->' in aparelho_kt,
       "canal do aparelho não expõe responderNotificacao")
exigir('call.argument<String>("chave").orEmpty()' in aparelho_kt,
       "canal não envia a chave da notificação")

# 3. Recusa honesta: sem serviço, sem ação ou sem campo, não finge envio.
for termo in ("O acesso às notificações não está ativo agora",
              "Nenhuma mensagem com campo de resposta disponível agora",
              "Esta notificação não aceita resposta direta",
              "Escreva a resposta antes de enviar"):
    exigir(termo in ouvinte, f"ouvinte sem a recusa: {termo}")
exigir('"ok" to true' in ouvinte and '"ok" to false' in ouvinte,
       "resposta não devolve ok verdadeiro/falso")
exigir('"mensagem" to "Resposta enviada pelo campo da notificação de "' in ouvinte,
       "confirmação não diz por onde a resposta saiu")

# 4. Modelo Dart e escolha da mensagem.
for termo in ("final String chave", "final String pacote",
              "final bool respondivel", "String get fraseLeitura",
              "NotificacaoAparelho? notificacaoParaResponder",
              "List<String> frasesDeLeitura"):
    exigir(termo in modelo, f"core/aparelho.dart sem {termo}")
trecho_escolha = modelo.split("NotificacaoAparelho? notificacaoParaResponder")[1][:900]
exigir("if (!n.respondivel || n.chave.isEmpty) continue;" in trecho_escolha,
       "escolha aceita notificação sem campo de resposta")
exigir("for (final n in lista)" in trecho_escolha,
       "escolha não percorre do mais recente para o mais antigo")

# 5. Serviço e tela.
exigir("responderNotificacao({" in servico and
       "'responderNotificacao'" in servico,
       "AparelhoService sem responderNotificacao")
exigir("ValueKey('notificacao-$i-responder')" in tela,
       "tela sem o botão de responder por notificação")
exigir("if (visiveis[i].respondivel)" in tela,
       "botão de responder aparece em notificação sem campo")
exigir("class _DialogoResposta extends StatefulWidget" in tela,
       "diálogo de resposta sem estado próprio (controlador descartado cedo)")
exigir("ValueKey('resposta-enviar')" in tela,
       "diálogo sem botão de enviar identificável")
exigir("_lerNotificacoes" in tela and
       "ValueKey('aparelho-notificacoes-ler')" in tela,
       "tela sem leitura das mensagens em voz alta")
exigir("frasesDeLeitura(" in tela, "leitura não usa as frases do modelo")

# 6. Reprodutibilidade: as peças nativas passam a ser copiadas pelo preparo.
exigir('shutil.copy2(ANDROID / "JarvisAparelho.kt"' in preparo,
       "preparo não copia JarvisAparelho.kt")
exigir('shutil.copy2(ANDROID / "JarvisNotificacaoListener.kt"' in preparo,
       "preparo não copia JarvisNotificacaoListener.kt")

# 7. Proibições e privacidade.
for arquivo, texto in (("JarvisNotificacaoListener.kt", ouvinte),
                       ("JarvisAparelho.kt", aparelho_kt)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")
    for rede in ("HttpURLConnection", "OkHttpClient", "openConnection("):
        exigir(rede not in texto, f"{arquivo} abre conexão de rede ({rede})")
exigir("createSpeechRecognizer(" not in tela,
       "tela usa reconhecedor que pode ir para a nuvem")

# 8. Documentação.
exigir("mensagens" in inventario.lower(), "inventário não cita a sentinela")
exigir("ajuste 084" in inventario, "inventário sem a seção do ajuste 084")
exigir("U.L.T.R.O.N." in comparativo and "Falta" in comparativo,
       "comparativo com o ULTRON ausente")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 084 sem a seção {secao}")
    for termo in ("notificação", "resposta", "voz", "aparelho"):
        exigir(termo in texto.lower(), f"relatório 084 sem {termo}")

if falhas:
    print("FALHAS no contrato da sentinela de mensagens:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da sentinela de mensagens: aprovado.")
