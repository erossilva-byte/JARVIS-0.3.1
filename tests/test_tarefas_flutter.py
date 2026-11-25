#!/usr/bin/env python3
"""Contrato estático de tarefas e automações (Fase 11, ajuste 075)."""

from pathlib import Path
import sys

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"


def ler(caminho: str) -> str:
    return (APP / caminho).read_text(encoding="utf-8")


falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


core = ler("lib/core/tarefas.dart")
store = ler("lib/services/tarefas_store.dart")
agenda = ler("lib/services/agenda_service.dart")
pagina = ler("lib/services/tarefas_page.dart")
pages = ler("lib/pages.dart")
kotlin = ler("android/app/src/main/kotlin/com/jarvis/nova/JarvisAparelho.kt")
agenda_kt = ler("android/app/src/main/kotlin/com/jarvis/nova/JarvisAgenda.kt")
manifesto = ler("android/app/src/main/AndroidManifest.xml")
prepare = APP / "tool" / "prepare_android_sistema.py"
prepare_txt = prepare.read_text(encoding="utf-8")
teste_puro = APP / "tool" / "tarefas_test.dart"
teste_tela = APP / "test" / "tarefas_page_test.dart"
pubspec = (APP / "pubspec.yaml").read_text(encoding="utf-8")
relatorio = (RAIZ / "docs" / "relatorios" /
             "2026-11-19_075-tarefas-e-automacoes.md")
changelog = (RAIZ / "CHANGELOG.md").read_text(encoding="utf-8")
inventario = (RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md").read_text(
    encoding="utf-8")

# 1. Núcleo puro, sem Flutter nem rede.
for proibido in ("package:flutter", "package:http", "dart:io", "WebView"):
    exigir(proibido not in core, f"núcleo com dependência indevida: {proibido}")
for termo in ("class Tarefa", "class Automacao", "class ItemFila",
              "class EventoAutomacao", "automacaoVencida", "lerPrazo",
              "validarTarefa", "validarAutomacao", "itemFilaDeAutomacao",
              "marcarItemFalha", "maxTentativasFila", "TipoAcaoAutomacao.mensagem",
              "aguardandoConfirmacao", "idLembrete"):
    exigir(termo in core, f"núcleo sem {termo}")
exigir("bool get sensivel => this == TipoAcaoAutomacao.mensagem;" in core,
       "somente mensagem deve ser declarada sensível")

# 2. Armazenamento e agendamento não inventam sucesso.
for chave in ("jarvis.tarefas.v1", "jarvis.automacoes.v1", "jarvis.fila.v1",
              "jarvis.historico.v1", "salvarTarefa", "salvarAutomacao",
              "salvarFila", "salvarHistorico", "marcarExecucao"):
    exigir(chave in store, f"store sem {chave}")
exigir("O Android não confirmou a gravação" in store,
       "store sem mensagem de gravação não confirmada")
exigir("agendarLembrete" in agenda and "cancelarLembrete" in agenda,
       "serviço de agenda sem os métodos do canal")
exigir("return false;" in agenda, "serviço de agenda não falha fechado")

# 3. Tela com confirmação, fila e histórico.
for chave in ("tarefa-nova", "tarefa-titulo", "tarefa-prazo", "tarefa-salvar",
              "automacao-nova", "automacao-gatilho", "automacao-acao",
              "automacao-salvar", "automacoes-verificar", "fila-confirmar",
              "fila-recusar", "fila-reenviar", "agenda-atualizar"):
    exigir(f"ValueKey('{chave}" in pagina or f'ValueKey("{chave}' in pagina,
           f"tela sem a chave {chave}")
for termo in ("AGUARDANDO CONFIRMAÇÃO", "HISTÓRICO", "fila offline",
              "Nada é enviado sozinho", "AlarmManager", "Verificar",
              "o envio continua seu"):
    exigir(termo in pagina, f"tela sem o texto/limite: {termo}")
exigir("abrir-tarefas-automacoes" in pages, "navegação para a tela ausente")

# 4. Kotlin: alarme real, receptor, restauração e canal.
for termo in ("setAlarmClock", "AlarmClockInfo", "JarvisAgendaReceiver",
              "ACTION_BOOT_COMPLETED", "ACTION_MY_PACKAGE_REPLACED",
              "repetirDiario", "NotificationChannel", "const val CANAL"):
    exigir(termo in agenda_kt, f"JarvisAgenda.kt sem {termo}")
for termo in ('"agendarLembrete"', '"cancelarLembrete"'):
    exigir(termo in kotlin, f"canal Kotlin sem {termo}")
exigir("JarvisAgendaReceiver" in manifesto,
       "manifesto sem o receptor da agenda")
exigir("RECEIVE_BOOT_COMPLETED" in manifesto,
       "manifesto sem RECEIVE_BOOT_COMPLETED")
exigir("JarvisAgendaReceiver" in prepare_txt,
       "script de preparação não repõe o receptor")
exigir("RECEIVE_BOOT_COMPLETED" in prepare_txt,
       "script de preparação não repõe a permissão")

# 5. Testes e documentação.
exigir(teste_puro.is_file(), "teste puro de tarefas ausente")
exigir(teste_tela.is_file(), "teste de tela de tarefas ausente")
if teste_puro.is_file():
    exigir(teste_puro.read_text(encoding="utf-8").count("ok(") >= 15,
           "teste puro com menos de 15 grupos")
exigir("version: 1.93.0+19300" in pubspec, "versão não atualizada")
exigir("1.63.1" in changelog, "CHANGELOG sem 1.63.1")
exigir("1.64.0" in changelog, "CHANGELOG sem 1.64.0")
exigir("1.63.0" in changelog, "CHANGELOG sem 1.63.0")
exigir("Tarefas e automações" in inventario,
       "inventário sem a seção de tarefas e automações")
exigir(relatorio.is_file(), "relatório 075 ausente")
if relatorio.is_file():
    texto = relatorio.read_text(encoding="utf-8")
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado", "## 7. Limitações"):
        exigir(secao in texto, f"relatório 075 sem a seção {secao}")

if falhas:
    print("FALHAS no contrato de tarefas e automações:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato de tarefas e automações: aprovado.")
