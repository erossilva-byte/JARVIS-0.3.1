#!/usr/bin/env python3
"""Contrato do Duress PIN no formato de visita (ajuste 090, versão 1.76.0).

O comparativo com o U.L.T.R.O.N. pedia um Duress PIN. A decisão deste bloco foi
o **modo de visita**: um segundo PIN, diferente do principal, que abre o app
vazio em vez do app real — sem apagar nada.

O que este contrato prende, sem aparelho:

1. dois PINs, cada um com sal e digest próprios no cofre seguro, nunca em texto;
2. o PIN de coação passa pela mesma política, não pode ser igual ao principal e
   só é definido ou removido com o PIN principal;
3. a verificação confere os dois sempre, para o tempo não denunciar qual casou,
   e devolve `coacao` para a tela nunca abrir o app real;
4. o modo de visita não consulta IA, não lê dados do dono e desliga a escuta;
5. existe o prompt sugerido chamado "Modo de visita", copiável na tela;
6. nada de permissão nova, shell ou rede.
"""

from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
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


nucleo = ler(LIB / "core" / "modo_visita.dart")
seguranca = ler(LIB / "core" / "seguranca.dart")
loja = ler(LIB / "services" / "bloqueio_store.dart")
tela_bloqueio = ler(LIB / "services" / "bloqueio_page.dart")
portao = ler(LIB / "services" / "bloqueio_gate.dart")
visita = ler(LIB / "services" / "modo_visita_page.dart")
tela_seguranca = ler(LIB / "services" / "seguranca_page.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_090-modo-de-visita.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.88.0+18800" in pubspec, "versão não atualizada para 1.76.0")
exigir("1.76.0" in changelog and "modo de visita" in changelog.lower(),
       "CHANGELOG sem o bloco 1.76.0 do modo de visita")
exigir("tests/test_coacao_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/modo_visita_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 090 ausente")

# 2. Dois PINs separados, nenhum em texto.
for termo in ("_chaveCoacaoSal", "_chaveCoacaoDigest", "_chaveCoacaoIteracoes",
              "implements PortaBloqueio, PortaCoacao", "definirCoacao",
              "removerCoacao", "temCoacao", "coacaoUsadaEm"):
    exigir(termo in loja, f"bloqueio_store.dart sem {termo}")
exigir("novoSalt(_random)" in loja and "derivarPin(pinNovo.trim(), sal)" in loja,
       "PIN de coação não usa sal e derivação próprios")
exigir("cofre.dados" not in loja, "loja mexe em campo de teste")

# 3. Regras: política, diferente do principal, PIN principal como prova.
for termo in ("avaliarPin(pinNovo)", "precisa ser diferente do PIN principal",
              "Digite o PIN principal, não o PIN de coação.",
              "if (!atual.ativo)"):
    exigir(termo in loja, f"regra de coação ausente: {termo}")

# 4. Conferência dos dois sempre e marca `coacao` no resultado.
exigir("final bool coacao" in seguranca, "ResultadoTentativa sem a marca coacao")
exigir("principal || coacao" in loja,
       "conferência não soma os dois PINs")
exigir("await _iteracoesCoacao()" in loja,
       "conferência não usa as iterações da coação")
exigir("coacao: true" in loja and "_registrarUsoCoacao()" in loja,
       "uso da coação não é marcado/registrado")
exigir("bool visita" in portao and "ModoVisitaPage(aoBloquear" in portao,
       "portão não troca o app pelo modo de visita")
exigir("jarvisKwsController.stop()" in portao,
       "modo de visita não desliga a palavra de ativação")
exigir("aoEntrar: _entrar" in portao and
       "void Function(bool coacao)? aoEntrar" in tela_bloqueio,
       "tela de bloqueio não avisa que o PIN era de coação")

# 5. Modo de visita sem dados e sem IA.
for termo in ("boasVindasVisita", "respostaVisita", "ajustesVisita",
              "limitesModoVisita", "promptModoVisita",
              "nomePromptModoVisita = 'Modo de visita'",
              "não tenho um provedor"):
    exigir(termo in nucleo, f"core/modo_visita.dart sem {termo}")
for proibido in ("ProviderService", "http", "memoria_store",
                 "pessoas_store", "conversa_store"):
    exigir(proibido not in visita.lower(),
           f"modo de visita toca em {proibido}")
for termo in ("visita-entrada", "visita-enviar", "visita-ajustes",
              "visita-bloquear", "visita-prompt", "visita-prompt-nome"):
    exigir(termo in visita, f"tela de visita sem {termo}")

# 6. Tela de segurança: definir, remover, último uso e prompt copiável.
for termo in ("seguranca-coacao", "seguranca-definir-coacao",
              "seguranca-remover-coacao", "seguranca-coacao-uso",
              "seguranca-coacao-prompt", "seguranca-coacao-copiar",
              "Clipboard.setData"):
    exigir(termo in tela_seguranca, f"tela de segurança sem {termo}")
exigir("pergunta o PIN principal" in tela_seguranca or
       "_DialogoPedirPin" in tela_seguranca,
       "remoção da coação não pede o PIN principal")

# 7. Proibições.
for arquivo, texto in (("bloqueio_store.dart", loja),
                       ("modo_visita_page.dart", visita),
                       ("bloqueio_gate.dart", portao)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto,
           f"{arquivo} executa shell")
    for rede in ("HttpURLConnection", "http.get(", "http.post("):
        exigir(rede not in texto, f"{arquivo} abre rede ({rede})")

# 8. Documentação.
exigir("090" in inventario, "inventário sem a seção do ajuste 090")
exigir("modo de visita" in comparativo.lower(),
       "comparativo perdeu a linha do Duress PIN")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 090 sem a seção {secao}")
    for termo in ("modo de visita", "PIN de coação", "prompt"):
        exigir(termo.lower() in texto.lower(),
               f"relatório 090 sem {termo}")

if falhas:
    print("FALHAS no contrato do modo de visita:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do Duress PIN (modo de visita): aprovado.")
