#!/usr/bin/env python3
"""Contrato do bloco 121 — limpeza dos registros anteriores à máscara.

Conversas e histórico de execuções gravados antes das versões 1.95.0 e 1.96.0
podem ter um PIN ditado. Este contrato prende a limpeza única:

1. conversas e rascunho antigos são relidos e regravados pela máscara, uma vez,
   quando o `ConversaStore` abre;
2. o histórico do Android é reescrito por `JarvisFundo.sanearHistorico`, chamado
   na abertura do app, e também ao passar por `anotar`;
3. nada é apagado: o conteúdo antigo é preservado, só o PIN vira `[oculto]`;
4. os testes que provam isso estão registrados;
5. versão, CHANGELOG e relatório acompanham.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


store = ler(APP / "lib" / "services" / "conversa_store.dart")
testes = ler(APP / "test" / "conversa_store_test.dart")
fundo = ler(APP / "android" / "JarvisFundo.kt")
atividade = ler(APP / "android" / "MainActivity.kt")
segredo = ler(APP / "android" / "JarvisSegredo.kt")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_121-limpeza-dos-antigos.md")

# 1. Limpeza das conversas.
exigir("chaveLimpeza" in store, "falta a marca da limpeza única")
exigir("_sanearAntigos()" in store, "falta a limpeza das conversas antigas")
exigir("await store._sanearAntigos();" in store,
       "a limpeza não roda ao abrir o ConversaStore")
exigir("await _gravar(lista);" in store,
       "a limpeza não regrava as conversas antigas")
exigir("protegerPinNoPedido(rascunhoAntigo)" in store,
       "a limpeza não mascara o rascunho antigo")
exigir("_prefs.setBool(chaveLimpeza, true)" in store,
       "a limpeza não se marca como feita")
exigir("apagar(" not in store.split("_sanearAntigos")[1].split("}")[0],
       "a limpeza apaga conversa em vez de mascarar")

# 2. Limpeza do histórico do Android.
exigir("CHAVE_MASCARA_PIN" in fundo, "falta a marca da limpeza no Android")
exigir("fun sanearHistorico(context: Context)" in fundo,
       "falta JarvisFundo.sanearHistorico")
exigir("JarvisFundo.sanearHistorico(this)" in atividade,
       "a limpeza não roda na abertura do app")
exigir("JarvisSegredo.ocultarRegistro(antigo)" in fundo,
       "anotar não reescreve os registros antigos sem PIN")
exigir("fun ocultarRegistro(" in segredo,
       "falta JarvisSegredo.ocultarRegistro")
exigir('put("mensagem", ocultarPin(optString("mensagem")))' in segredo,
       "a limpeza não mascara a mensagem do registro antigo")
exigir("prefs.edit()\n            .putString(CHAVE_HISTORICO, limpo.toString())"
       in fundo, "sanearHistorico não regrava o histórico")

# 3. Testes que provam o comportamento.
for trecho in [
    "limpa o PIN das conversas gravadas antes da máscara",
    "a limpeza dos antigos roda uma vez só",
    "isNot(contains('4321'))",
]:
    exigir(trecho in testes, f"falta o teste: {trecho}")

# 4. Versão, docs e registros.
exigir("version: 1.99.0+19900" in pubspec,
       "pubspec.yaml não está em 1.99.0+19900")
exigir("## 1.98.0" in changelog, "CHANGELOG.md não tem o bloco 1.98.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 121")
exigir("test_bloco_121.py" in pacote, "package.json não roda o contrato 121")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_121.py" in dados["scripts"]["test:all"],
           "o contrato 121 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 121:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 121: limpeza única dos registros antigos — contrato OK")
