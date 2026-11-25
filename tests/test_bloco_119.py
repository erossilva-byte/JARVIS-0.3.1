#!/usr/bin/env python3
"""Contrato do bloco 119 — PIN ditado fora do histórico de conversas.

O bloco 118 tirou o PIN do histórico de execuções. Este prende o mesmo cuidado
na conversa: o que vai para o disco (título, mensagens e rascunho) passa pela
máscara, e a conversa aberta na tela continua com o texto como foi dito.

Sem aparelho, o contrato prende:

1. o `ConversaStore` usa a mesma regra de máscara do bloco 118;
2. a máscara é aplicada na cópia gravada, não no objeto em memória;
3. título, mensagens e rascunho passam por ela;
4. os testes que provam isso estão registrados;
5. versão, CHANGELOG e relatório acompanham a mudança.
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
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
pacote = ler(RAIZ / "package.json")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-25_119-pin-fora-da-conversa.md")

# 1. A mesma regra, sem inventar outra.
exigir("import '../core/segredo_pedido.dart';" in store,
       "o ConversaStore não importa a regra de máscara")
exigir("protegerPinNoPedido(" in store,
       "o ConversaStore não aplica a máscara")

# 2. Máscara na cópia gravada, não no objeto da sessão.
exigir("_paraJsonArmazenado" in store,
       "falta a cópia usada só na gravação")
exigir("lista.map(_paraJsonArmazenado)" in store,
       "a gravação não passa pela cópia mascarada")
exigir("conversa.mensagens.remove" not in store,
       "a gravação mexe na lista viva da conversa")

# 3. Título, mensagens e rascunho.
exigir("'titulo': protegerPinNoPedido(conversa.titulo)" in store,
       "o título não é mascarado")
exigir("'texto': protegerPinNoPedido(mensagem.texto)" in store,
       "as mensagens não são mascaradas")
exigir("protegerPinNoPedido(texto)" in store,
       "o rascunho não é mascarado")

# 4. Os testes que provam o comportamento.
for trecho in [
    "PIN ditado não entra no histórico da conversa",
    "telefone continua no histórico da conversa",
    "rascunho com PIN é mascarado",
]:
    exigir(trecho in testes, f"falta o teste: {trecho}")

# 5. Versão, docs e registros.
exigir("version: 1.109.0+110900" in pubspec,
       "pubspec.yaml não está em 1.109.0+110900")
exigir("## 1.96.0" in changelog, "CHANGELOG.md não tem o bloco 1.96.0")
exigir(relatorio.is_file(), "falta o relatório do bloco 119")
exigir("test_bloco_119.py" in pacote, "package.json não roda o contrato 119")
try:
    dados = json.loads(pacote)
    exigir("python3 tests/test_bloco_119.py" in dados["scripts"]["test:all"],
           "o contrato 119 não está no script test:all")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 119:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 119: PIN fora do histórico de conversas — contrato OK")
