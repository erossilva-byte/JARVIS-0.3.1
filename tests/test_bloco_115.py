#!/usr/bin/env python3
"""Contrato do bloco 115 — mensagem sem toque e abrir app já na ação.

O que este contrato prende, sem aparelho:

1. existe uma regra pura de "abrir app com ação" (conversa, escrever, buscar,
   rota, música, câmera) e um espelho Kotlin com as mesmas chaves;
2. a conversa usa essa regra antes do comando de abrir app pela lista, e o
   serviço de segundo plano também;
3. o link do app é montado no Kotlin, com recusa honesta quando o contato ou o
   app não existem;
4. o envio sem toque só toca em Enviar com o serviço de acessibilidade
   autorizado, o interruptor ligado, o texto pedido na tela e o pacote certo;
5. o interruptor aparece na tela de acessibilidade e é lido pelo canal;
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


regra = ler(LIB / "core" / "pedido_app.dart")
servico_dart = ler(LIB / "services" / "abrir_app.dart")
aparelho_service = ler(LIB / "services" / "aparelho_service.dart")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
tela_acess = ler(LIB / "services" / "acessibilidade_page.dart")
servico_acess = ler(LIB / "services" / "acessibilidade_service.dart")
regra_kt = ler(ANDROID / "JarvisAbrirApp.kt")
envio_kt = ler(ANDROID / "JarvisEnvioSemToque.kt")
acessibilidade_kt = ler(ANDROID / "JarvisAcessibilidade.kt")
aparelho_kt = ler(ANDROID / "JarvisAparelho.kt")
mensagens_kt = ler(ANDROID / "JarvisMensagens.kt")
kws = ler(ANDROID / "KwsForegroundService.kt")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
nucleo = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_115-mensagem-sem-toque-e-app-com-acao.md")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")

# 0. A preparação do Android precisa levar as classes novas para o build.
for classe in ["JarvisAbrirApp.kt", "JarvisEnvioSemToque.kt",
               "JarvisAbrirTela.kt", "JarvisMensagens.kt",
               "KwsForegroundService.kt"]:
    exigir(f'shutil.copy2(ANDROID / "{classe}"' in preparo,
           f"prepare_android_sistema.py não copia {classe}")

# 1. Chaves dos apps e das ações, iguais nos dois lados.
for chave in ["whatsapp", "whatsapp_business", "telegram", "instagram", "gmail",
              "email", "sms", "maps", "youtube", "spotify", "camera",
              "calculadora"]:
    exigir(chave in regra, f"app {chave} não está na regra Dart")
    exigir(f'"{chave}"' in regra_kt, f"app {chave} não está no espelho Kotlin")

for acao in ["abrir", "conversa", "escrever", "pesquisar", "navegar", "tocar",
             "camera"]:
    exigir(f"'{acao}'" in regra, f"ação {acao} não está na regra Dart")
    exigir(f'"{acao}"' in regra_kt, f"ação {acao} não está no espelho Kotlin")

exigir("PedidoAppAcao? pedidoAppComAcao(" in regra,
       "a regra não expõe pedidoAppComAcao")
exigir("interpretarMensagem(original)" in regra and
       "interpretarLigacao(original)" in regra,
       "a regra de app não recusa mensagem e ligação")

# 2. Ordem dos caminhos no app e no segundo plano.
exigir("AbrirAppComAcao.executar(texto)" in conversa,
       "a conversa não chama AbrirAppComAcao")
pos_app = conversa.find("AbrirAppComAcao.executar(texto)")
pos_lista = conversa.find("_comandos.executar(texto)")
exigir(pos_app >= 0 and pos_lista >= 0 and pos_app < pos_lista,
       "abrir app com ação precisa vir antes do comando de app pela lista")

pos_kt = kws.find("JarvisAbrirApp.interpretar(texto)")
pos_fundo = kws.find("JarvisFundo.interpretar(texto)")
exigir(pos_kt >= 0 and pos_fundo >= 0 and pos_kt < pos_fundo,
       "o segundo plano precisa reconhecer a ação de app antes da pergunta livre")
exigir("private fun abrirAppComAcao(" in kws,
       "o serviço não executa a ação de app")
exigir("podeAbrirApps(applicationContext)" in kws, 
       "a ação de app não confere a autorização de sobreposição")

# 3. Execução Kotlin e canal.
for trecho in ["fun executar(contexto: Context", "wa.me", "mailto:",
               "google.navigation:q=", "geo:0,0?q=", "youtube.com/results",
               "spotify:search:", "INTENT_ACTION_STILL_IMAGE_CAMERA"]:
    exigir(trecho in regra_kt, f"o espelho Kotlin não monta {trecho}")

exigir('"abrirComAcao" -> abrirComAcao(' in aparelho_kt,
       "o canal do aparelho não recebe abrirComAcao")
exigir("JarvisAbrirApp.executar(activity, pedido)" in aparelho_kt,
       "o canal não executa o pedido de app")
exigir("abrirComAcao(" in aparelho_service,
       "o serviço Dart não tem abrirComAcao")
exigir("'abrirComAcao'" in aparelho_service,
       "o serviço Dart não chama o método abrirComAcao")
exigir("pedido.app.chave" in aparelho_service and
       "pedido.acao.chave" in aparelho_service,
       "o serviço Dart não envia as chaves estáveis")

# 4. Envio sem toque: todas as travas.
for trecho in ["fun ativo(contexto: Context)",
               "JarvisAcessibilidade.servicoLigado()",
               "JarvisAcessibilidade.raizVisivel()",
               "raiz.packageName?.toString() == pacote",
               "ACTION_CLICK",
               '"enviar"', '"send"',
               "viuTexto",
               "fun explicar("]:
    exigir(trecho in envio_kt, f"o envio sem toque não tem {trecho}")

exigir("fun raizVisivel()" in acessibilidade_kt,
       "o serviço de acessibilidade não expõe a árvore para o envio")
exigir('"envioSemToque"' in acessibilidade_kt and
       '"definirEnvioSemToque"' in acessibilidade_kt,
       "o canal de acessibilidade não lê/grava o interruptor")

exigir("JarvisEnvioSemToque.tentar(" in aparelho_kt,
       "o app aberto não usa o envio sem toque")
exigir("JarvisEnvioSemToque.tentar(" in mensagens_kt,
       "o segundo plano não usa o envio sem toque")
exigir("concluirEnvio(" in mensagens_kt,
       "o segundo plano não informa o resultado do envio")
exigir("envio.enviado" in aparelho_kt and "envio.enviado" in mensagens_kt,
       "o resultado não distingue enviado de pendente")

# 5. Interruptor na tela.
exigir("acessibilidade-envio-sem-toque" in tela_acess,
       "a tela de acessibilidade não tem o interruptor do envio")
exigir("_alternarEnvio" in tela_acess,
       "a tela não alterna o envio sem toque")
exigir("envioSemToque()" in servico_acess and
       "definirEnvioSemToque(" in servico_acess,
       "o serviço de acessibilidade do app não lê/grava o interruptor")

# 6. Versão, docs e registros.
exigir("version: 1.104.0+110400" in pubspec,
       "pubspec.yaml não está em 1.104.0+110400")
exigir("## 1.92.0" in changelog, "CHANGELOG.md não tem o bloco 1.92.0")
exigir(relatorio.is_file(),
       "falta docs/relatorios/2026-11-25_115-mensagem-sem-toque-e-app-com-acao.md")
exigir("test_bloco_115.py" in pacote,
       "package.json não roda o contrato 115")
exigir("test_bloco_114.py" in pacote,
       "o contrato 114 saiu do test:all")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_115.py" in dados["scripts"]["test:all"],
           "o contrato 115 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

exigir("tool/pedido_app_test.dart" in nucleo,
       "o teste puro da regra não está registrado em test_dart_core.py")
exigir((APP / "tool" / "pedido_app_test.dart").is_file(),
       "falta flutter_app/tool/pedido_app_test.dart")
exigir((APP / "test" / "abrir_app_test.dart").is_file(),
       "falta flutter_app/test/abrir_app_test.dart")

if falhas:
    print("Falhas do bloco 115:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 115: mensagem sem toque e abrir app com ação — contrato OK")
