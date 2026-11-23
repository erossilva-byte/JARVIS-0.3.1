#!/usr/bin/env python3
"""Contrato das habilidades em Markdown (ajuste 086, versão 1.73.0).

O comparativo com o U.L.T.R.O.N. apontava como falta as "skills procedurais em
Skills/*.md". Agora o JARVIS carrega do próprio aparelho pastas de habilidades
escritas pelo usuário e usa o passo a passo na conversa quando a pergunta casa
com os gatilhos.

O que este contrato prende, sem aparelho:

1. o caminho só vale dentro de Skills/ ou Habilidades/;
2. o Markdown (frontmatter + corpo) vira nome, descrição, gatilhos e passos;
3. arquivo repetido, fora da pasta ou sem passos não entra;
4. a pergunta ativa só a habilidade que casa, e nada é ativado sem pergunta;
5. o bloco entra no pedido com limite de tamanho, junto da personalidade;
6. a origem usada aparece na conversa e sobrevive ao salvamento;
7. a leitura usa o SAF já existente e a pasta local, sem nuvem e sem execução
   de código.
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


nucleo = ler(LIB / "core" / "habilidades.dart")
servico = ler(LIB / "services" / "habilidades_service.dart")
tela = ler(LIB / "services" / "habilidades_page.dart")
conversa = ler(LIB / "core" / "conversa.dart")
montagem = ler(LIB / "core" / "memoria_busca.dart")
voz = ler(LIB / "services" / "voice_conversation_page.dart")
ponte = ler(LIB / "services" / "ponte_ia_fundo.dart")
catalogo = ler(LIB / "catalog.dart")
home = ler(LIB / "home_screen.dart")
gaveta = ler(LIB / "drawer.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_086-habilidades-em-markdown.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.88.5+18805" in pubspec, "versão não atualizada para 1.73.0")
exigir("1.73.0" in changelog and "habilidade" in changelog.lower(),
       "CHANGELOG sem o bloco 1.73.0 das habilidades")
exigir("tests/test_habilidades_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/habilidades_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 086 ausente")

# 2. Pastas e leitura do Markdown.
for termo in ("pastasHabilidades", "caminhoDeHabilidade", "lerHabilidade",
              "habilidadesDosArquivos", "habilidadesQueCasam",
              "blocoHabilidades", "exemploHabilidade", "limiteHabilidades",
              "limiteBlocoHabilidades"):
    exigir(termo in nucleo, f"core/habilidades.dart sem {termo}")
exigir("'skills'" in nucleo and "'habilidades'" in nucleo,
       "pastas reconhecidas não incluem Skills/Habilidades")
exigir("lerMarkdown(" in nucleo,
       "habilidade não reutiliza o leitor de Markdown do cofre")
exigir("if (!caminhoDeHabilidade(arquivo.caminho)) continue;" in nucleo,
       "arquivo fora da pasta de habilidades pode entrar")
exigir("if (!vistos.add(chave)) continue;" in nucleo,
       "habilidade repetida entra duas vezes")
exigir("if (instrucoes.isEmpty) return null;" in nucleo,
       "habilidade sem passo a passo é aceita")
exigir("if (texto.isEmpty || habilidades.isEmpty) return const [];" in nucleo,
       "pergunta vazia pode ativar habilidade")

# 3. Leitura do aparelho: SAF existente e pasta local.
for termo in ("CofreSaf.pastaAtual()", "CofreSaf.listarNotas()",
              "getApplicationDocumentsDirectory()", "CofreSaf.escreverNota(",
              "Skills/exemplo-revisar-texto.md", "habilidadesDosArquivos("):
    exigir(termo in servico, f"habilidades_service.dart sem {termo}")
exigir("'Habilidades/$relativo'" in servico,
       "arquivo local não é marcado com a pasta de habilidades")
exigir("Nenhuma pasta de habilidades encontrada" in servico,
       "sem pasta, o motivo não é explicado")
exigir("somente para\n            'leitura" in servico or
       "somente para" in servico,
       "pasta sem escrita não é avisada")
for rede in ("HttpClient", "package:http", "openConnection("):
    exigir(rede not in servico, f"serviço abre rede ({rede})")
exigir("Process.run" not in nucleo and "Process.run" not in servico,
       "habilidade executa programa")

# 4. Conversa: bloco no pedido, registro e transparência.
exigir("String? habilidades," in montagem,
       "montarMensagens não aceita o bloco de habilidades")
exigir("{'role': 'system', 'content': habilidades}" in montagem,
       "bloco de habilidades não entra como instrução de sistema")
exigir("habilidadesQueCasam(" in voz and "blocoHabilidades(" in voz,
       "conversa não carrega nem casa as habilidades")
exigir("habilidades: habilidadesUsadas.map((h) => h.nome).toList(),"
       in voz,
       "resposta não registra as habilidades usadas")
exigir("final List<String> habilidades;" in conversa,
       "modelo de mensagem sem as habilidades usadas")
exigir("if (habilidades.isNotEmpty) 'habilidades': habilidades," in conversa,
       "habilidades não são salvas no histórico")
exigir("Habilidades usadas:" in voz,
       "interface não mostra qual habilidade foi usada")
exigir("habilidadesQueCasam(carregadas.habilidades, texto)" in ponte,
       "pergunta por voz em segundo plano ignora as habilidades")

# 5. Tela e navegação.
for termo in ("habilidades-atualizar", "habilidades-criar-exemplo",
              "habilidades-aviso", "habilidades-vazio", "habilidade-$i",
              "habilidades-exemplo-formato", "HabilidadesService"):
    exigir(termo in tela, f"habilidades_page.dart sem {termo}")
exigir("Habilidades em Markdown" in catalogo,
       "catálogo sem o módulo de habilidades")
exigir("HabilidadesPage()" in home, "home_screen não abre a tela")
exigir("onModule('Habilidades em Markdown')" in gaveta,
       "gaveta sem atalho para as habilidades")

# 6. Documentação.
exigir("habilidades" in inventario.lower(),
       "inventário não cita as habilidades")
exigir("Skills" in inventario, "inventário sem a pasta Skills")
exigir("skills em Markdown" in comparativo.lower() or
       "Skills/*.md" in comparativo,
       "comparativo perdeu a referência às skills")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência",
                  "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 086 sem a seção {secao}")
    for termo in ("markdown", "skills", "gatilho", "aparelho"):
        exigir(termo in texto.lower(), f"relatório 086 sem {termo}")

if falhas:
    print("FALHAS no contrato das habilidades em Markdown:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato das habilidades em Markdown: aprovado.")
