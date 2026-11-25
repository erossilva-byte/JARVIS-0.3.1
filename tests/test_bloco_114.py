#!/usr/bin/env python3
"""Contrato do bloco 114 — abrir tudo por voz, no app e no segundo plano.

O que este contrato prende, sem aparelho:

1. existe uma regra única de "abrir tela do JARVIS", com as mesmas chaves no
   Dart e no Kotlin, e ela não engole abrir app de terceiro, mensagem, ligação
   nem pergunta;
2. a conversa abre a tela antes de tentar o comando de abrir app;
3. o serviço de segundo plano reconhece a tela antes de abrir app e antes da
   IA, e entrega a chave ao app por `Intent`;
4. mensagem e ligação também valem com o app fechado, com recusa honesta quando
   falta permissão;
5. o app abre a tela pedida pelo serviço no navegador único;
6. versão, CHANGELOG, relatório e registro do teste puro acompanham a mudança.
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


regra = ler(LIB / "core" / "pedido_abrir.dart")
abrir = ler(LIB / "services" / "abrir_tela.dart")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
principal = ler(LIB / "main.dart")
home = ler(LIB / "home_screen.dart")
sistema = ler(LIB / "services" / "sistema_android.dart")
regra_kt = ler(ANDROID / "JarvisAbrirTela.kt")
mensagens_kt = ler(ANDROID / "JarvisMensagens.kt")
servico = ler(ANDROID / "KwsForegroundService.kt")
atividade = ler(ANDROID / "MainActivity.kt")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-24_114-abrir-tudo-por-voz.md")

# 1. Regra Dart e paridade das chaves com o Kotlin.
exigir("enum TelaJarvis" in regra, "pedido_abrir.dart sem o enum TelaJarvis")
exigir("PedidoAbrir? pedidoAbrir(" in regra, "pedido_abrir.dart sem pedidoAbrir")
exigir("RegExp(r'^(como|por que" in regra,
       "pedido_abrir.dart sem a guarda de pergunta")
exigir("_bloqueio" in regra, "pedido_abrir.dart sem o bloqueio de mensagem/ligação")
for chave in ("'visao'", "'palco'", "'memoria'", "'pessoas'", "'segundo_plano'",
              "'voz_externa'", "'provedores'", "'historico'"):
    exigir(chave in regra, f"tela {chave} ausente no Dart")
    exigir(f'Pedido("{chave.strip(chr(39))}"' in regra_kt,
           f"tela {chave} ausente no Kotlin")

chaves_dart = set(re.findall(r"^\s{2}\w+\('([a-z_]+)':?", regra, re.M))
chaves_kt = set(re.findall(r'Pedido\("([a-z_]+)"', regra_kt))
exigir(chaves_dart, "nenhuma chave lida do enum Dart")
exigir(chaves_dart == chaves_kt,
       f"chaves diferentes entre Dart e Kotlin: "
       f"dart={sorted(chaves_dart)} kt={sorted(chaves_kt)}")

# 2. A conversa abre a tela antes do comando de abrir app.
pos_regra = conversa.find("pedidoAbrir(texto)")
pos_comando = conversa.find("_comandos.executar(texto)")
exigir(pos_regra > 0, "a conversa não chama pedidoAbrir")
exigir(pos_regra < pos_comando,
       "pedidoAbrir precisa vir antes de abrir app na conversa")
exigir("AbrirTela.abrir(abrir.tela" in conversa,
       "a conversa não abre a tela pelo serviço")

# 3. Serviço de segundo plano: tela antes de app e antes da IA.
pos_tela = servico.find("JarvisAbrirTela.interpretar(texto)")
pos_app = servico.find("val comando = JarvisFundo.interpretar(texto)")
exigir(pos_tela > 0, "o serviço não reconhece tela do JARVIS")
exigir(0 < pos_tela < pos_app,
       "a tela do JARVIS precisa vir antes de abrir app no serviço")
exigir("putExtra(JarvisAbrirTela.EXTRA_TELA" in servico,
       "o serviço não manda a chave da tela no Intent")
exigir("JarvisFundo.podeAbrirApps" in servico,
       "o serviço abriria tela sem conferir “Exibir sobre outros apps”")
exigir('"abrir ${pedido.rotulo}"' in servico,
       "o histórico do serviço não registra a tela aberta")

# 4. Mensagem e ligação com o app fechado.
pos_msg = servico.find("JarvisMensagens.interpretar(texto)")
pos_ia = servico.find("responderPerguntaLivre(texto)")
exigir("JarvisMensagens.interpretar(texto)" in servico,
       "o serviço não reconhece mensagem/ligação")
exigir(0 < pos_msg < pos_ia,
       "mensagem/ligação precisam vir antes da pergunta livre")
exigir("executarMensagem(" in servico, "o serviço não executa a mensagem")
exigir("Manifest.permission.CALL_PHONE" in mensagens_kt,
       "ligação sem conferir a permissão de chamada")
exigir("Manifest.permission.SEND_SMS" in mensagens_kt,
       "SMS sem conferir a permissão de envio")
exigir("não aceita envio silencioso" in mensagens_kt,
       "mensagem sem a recusa honesta do toque em enviar")
exigir("ACTION_DIAL" in mensagens_kt and "ACTION_CALL" in mensagens_kt,
       "ligação sem a volta para o discador quando falta permissão")
for termo in ("whatsapp", "telegram", "sms", "gmail", "instagram", "signal"):
    exigir(termo in mensagens_kt.lower(), f"app {termo} ausente nas mensagens")

# 5. O app abre a tela pedida.
exigir("navigatorKey: AbrirTela.navegador" in principal,
       "main.dart sem o navegador único")
exigir("intencao.pediuTela" in home, "home_screen não trata a tela pedida")
exigir("AbrirTela.abrir(tela)" in home,
       "home_screen não abre a tela pelo serviço")
exigir("acao == 'tela'" in sistema, "IntencaoSistema sem a ação de tela")
exigir("TelaJarvis.porChave(texto)" in sistema,
       "IntencaoSistema não traduz a chave da tela")
exigir("JarvisAbrirTela.EXTRA_TELA" in atividade,
       "MainActivity não lê a chave da tela")
for pagina in ("VisaoPage", "PalcoPage", "MemoriaPage", "PessoasPage",
               "TarefasPage", "SegurancaPage", "SegundoPlanoPage"):
    exigir(pagina in abrir, f"abrir_tela.dart sem {pagina}")

# 6. Versão, CHANGELOG, relatório e registro do teste.
exigir("version: 1.103.0+110300" in pubspec,
       "pubspec sem a versão 1.103.0+110300")
exigir("## 1.91.0" in changelog, "CHANGELOG sem o bloco 1.91.0")
for termo in ("abre o modo visão", "mensagem", "segundo plano"):
    exigir(termo in changelog.lower(), f"CHANGELOG do 1.91.0 sem {termo}")
exigir(relatorio.is_file(), "relatório do bloco 114 não encontrado")
exigir("tool/pedido_abrir_test.dart" in nucleo,
       "teste puro de abrir telas fora do test_dart_core.py")
try:
    scripts = json.loads(pacote).get("scripts", {})
    exigir("tests/test_bloco_114.py" in scripts.get("test:all", ""),
           "package.json → test:all sem o contrato 114")
except json.JSONDecodeError:
    falhas.append("package.json inválido")

if falhas:
    print("FALHOU: contrato do bloco 114")
    for item in falhas:
        print(" -", item)
    sys.exit(1)
print("OK: bloco 114 — abrir telas, mensagens e ligação por voz no app e no fundo.")
