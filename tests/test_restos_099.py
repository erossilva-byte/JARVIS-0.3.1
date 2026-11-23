#!/usr/bin/env python3
"""Contrato do ajuste 099 (versão 1.85.0).

Três frentes no mesmo bloco:

1. o aviso genérico “Integração em auditoria” saiu do código: todo módulo do
   catálogo tem estado declarado (pronto, parcial ou ausente) e motivo próprio;
2. o ID de voz `82d13948027e4be69892dd3d0104e681` é o padrão da voz externa,
   com a chave no cofre do aparelho e reprodução por MediaPlayer no Android;
3. existe projetista por prompt no Flutter, e ele **só** entrega circuito que
   feche a simulação.

O que este contrato prende (verificável sem aparelho):

- a tabela de estados cobre exatamente os módulos do catálogo;
- nenhum arquivo do app usa o texto genérico de auditoria;
- o projetista monta pelas famílias declaradas e chama a simulação;
- o núcleo da voz externa não fala com a rede (a rede fica no serviço);
- o Kotlin tem `falarAudio`/`pararAudio` e o canal de voz os expõe;
- as ferramentas Dart e os testes de tela novos estão registrados;
- documentação: relatório, CHANGELOG, inventário e comparativo.

Isto não prova áudio, voz externa nem circuito em aparelho: nada foi compilado
nem instalado nesta sessão.
"""

from __future__ import annotations

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


# 1. Versão e pacote.
pubspec = ler(APP / "pubspec.yaml")
exigir("version: 1.88.6+18806" in pubspec, "pubspec sem 1.88.0+18800")
pacote = ler(RAIZ / "package.json")
exigir("tests/test_restos_099.py" in pacote, "contrato fora do npm run test:all")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
for ferramenta in (
    "tool/estado_modulos_test.dart",
    "tool/hermes_plano_test.dart",
    "tool/projetista_test.dart",
    "tool/voz_externa_test.dart",
):
    exigir(ferramenta in dart_core, f"test_dart_core.py sem {ferramenta}")

# 2. Catálogo e tabela de estados cobrem os mesmos módulos.
catalogo = re.findall(r"JarvisModule\(\s*'([^']+)'", ler(LIB / "catalog.dart"))
estados_txt = ler(LIB / "core" / "estado_modulos.dart")
estados = re.findall(r"^\s{4}nome: '([^']+)',", estados_txt, re.M)
exigir(len(catalogo) == 26, f"catálogo com {len(catalogo)} módulos, esperado 26")
exigir(len(estados) == 26, f"tabela de estados com {len(estados)} módulos")
exigir(set(catalogo) == set(estados),
       "catálogo e tabela de estados divergem: "
       f"{sorted(set(catalogo) ^ set(estados))}")

# 3. Nenhum resto do aviso genérico.
for arquivo in LIB.rglob("*.dart"):
    texto = ler(arquivo)
    exigir("Integração em auditoria" not in texto,
           f"{arquivo.relative_to(RAIZ)} ainda usa o aviso genérico")
paginas = ler(LIB / "pages.dart")
for termo in ("situacaoDe(", "rotuloEstado(", "TelaModulo."):
    exigir(termo in paginas, f"pages.dart sem {termo}")

# 4. Os seis módulos do pedido estão declarados como prontos.
for modulo in (
    "Hermes Agent",
    "Agentes especializados",
    "Tarefas e rotinas",
    "CADeSIMU e elétrica",
    "Segurança e privacidade",
    "Perfis de timbre",
):
    bloco = re.search(
        r"nome: '" + re.escape(modulo) + r"',.*?estado: EstadoModulo\.(\w+)",
        estados_txt, re.S)
    exigir(bloco is not None and bloco.group(1) == "pronto",
           f"{modulo} não está como pronto")

# 5. Projetista: famílias declaradas, simulação obrigatória, recusa honesta.
projetista = ler(LIB / "core" / "projetista.dart")
for termo in (
    "enum FamiliaCircuito",
    "FamiliaCircuito.reversao",
    "FamiliaCircuito.temporizador",
    "circuito.simular()",
    "ok: false",
    "ResultadoProjeto montarProjetoDe(",
    "familiasSuportadas",
):
    exigir(termo in projetista, f"projetista.dart sem {termo}")
# Só o `_validar` pode marcar sucesso — e ele só marca depois da simulação.
exigir(projetista.count("    ok: true,") == 1,
       "projetista com mais de um caminho de sucesso")
sucesso = projetista.index("    ok: true,")
exigir("circuito.simular()" in projetista[:sucesso],
       "o sucesso do projetista vem antes de alguma simulação")
exigir("Primerio" not in projetista and "esquiema" not in projetista,
       "projetista com erro de digitação")

# 6. Voz externa: ID padrão, validação e rede isolada no serviço.
voz = ler(LIB / "core" / "voz_externa.dart")
exigir("82d13948027e4be69892dd3d0104e681" in voz, "ID de voz padrão ausente")
for termo in ("idVozValido", "normalizarIdVoz", "urlVozExterna",
              "corpoVozExterna", "limitesVozExterna"):
    exigir(termo in voz, f"voz_externa.dart sem {termo}")
for chamada in ("package:http", "http.post", "http.get", "http.Client"):
    exigir(chamada not in voz,
           f"o núcleo da voz externa não pode falar com a rede ({chamada})")
servico = ler(LIB / "services" / "voz_externa_service.dart")
for termo in ("xi-api-key" if False else "chaveSegredoVozExterna",
              "chaveVozExternaId", "falarAudio", "402", "429"):
    exigir(termo in servico, f"voz_externa_service.dart sem {termo}")
exigir("http.post" in servico or ".post(" in servico,
       "serviço não monta o pedido HTTP")
interface = ler(LIB / "services" / "voz_externa_page.dart")
for termo in ("voz-id-campo", "voz-chave-campo", "voz-externa-testar",
              "voz-externa-status"):
    exigir(termo in interface, f"voz_externa_page.dart sem {termo}")
tela = ler(LIB / "services" / "voz_externa_page.dart")
exigir("texto" in tela and "segredo" not in tela.lower().replace("segredo de", ""),
       "a tela da chave parece guardar o valor")

# 6b. A voz externa é usada nas respostas, com volta para a voz local.
fala = ler(LIB / "services" / "fala_jarvis.dart")
for termo in ("class FalaJarvis", "ultimoErro", "_externaPronta()",
              "_externa.gerar(", "_externa.tocar(", "_local.falar(texto)",
              "Future<void> parar()"):
    exigir(termo in fala, f"fala_jarvis.dart sem {termo}")
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
for termo in ("FalaJarvis", "_fala.falar(texto)", "_fala.parar()"):
    exigir(termo in conversa, f"conversa sem {termo}")
exigir("unawaited(voz.parar())" not in conversa,
       "a conversa ainda para só a voz local")
exigir((APP / "test" / "fala_jarvis_test.dart").is_file(),
       "teste da fala com Fish Audio ausente")
for termo in ("class VozExternaConfig", "get pronta", "static Future<void> carregar"):
    exigir(termo in servico, f"voz_externa_service.dart sem {termo}")
exigir("VozExternaConfig.carregar()" in ler(LIB / "main.dart"),
       "app não carrega a configuração da voz externa na abertura")

# 7. Kotlin: MediaPlayer e canal.
voz_kt = ler(ANDROID / "JarvisVoz.kt")
for termo in ("import android.media.MediaPlayer", "fun falarAudio(",
              "fun pararAudio(", "mp3?.release()"):
    exigir(termo in voz_kt, f"JarvisVoz.kt sem {termo}")
ativ_kt = ler(ANDROID / "MainActivity.kt")
for termo in ('"falarAudio"', '"pararAudio"', "voz?.falarAudio("):
    exigir(termo in ativ_kt, f"MainActivity.kt sem {termo}")
copia = ler(ANDROID / "app" / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova" / "JarvisVoz.kt")
exigir("fun falarAudio(" in copia, "cópia do JarvisVoz na árvore de build sem falarAudio")

# 8. Hermes e agentes.
hermes = ler(LIB / "core" / "hermes_plano.dart")
for termo in ("PlanoHermes planejarPedido(", "mensagensDoPasso(", "resumoPlano("):
    exigir(termo in hermes, f"hermes_plano.dart sem {termo}")
agentes = ler(LIB / "core" / "agentes.dart")
exigir(agentes.count("AgenteEspecializado(") >= 12, "menos de 12 agentes")
for termo in ("agenteDe(", "instrucaoDoAgente(", "regrasAgente"):
    exigir(termo in agentes, f"agentes.dart sem {termo}")
pagina_hermes = ler(LIB / "services" / "hermes_page.dart")
for termo in ("hermes-campo", "hermes-planejar", "hermes-executar",
              "hermes-montar", "agentes-rota"):
    exigir(termo in pagina_hermes, f"hermes_page.dart sem {termo}")

# 9. Testes novos e documentação.
for arquivo in (
    "test/projetista_page_test.dart",
    "test/hermes_page_test.dart",
    "test/voz_externa_page_test.dart",
):
    exigir((APP / arquivo).is_file(), f"{arquivo} não existe")
teste_programacao = ler(APP / "test" / "programacao_sem_execucao_test.dart")
exigir("Integração em auditoria" in teste_programacao,
       "o teste antigo deveria provar que o aviso sumiu")
changelog = ler(RAIZ / "CHANGELOG.md")
exigir("## 1.85.0" in changelog, "CHANGELOG sem o bloco 1.85.0")
for termo in ("auditoria", "voz externa", "circuito por prompt"):
    exigir(termo in changelog.lower(), f"CHANGELOG sem {termo}")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md").lower()
for termo in ("estado dos módulos", "voz externa", "circuito por prompt"):
    exigir(termo in inventario, f"inventário sem {termo}")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
exigir("099" in comparativo, "comparativo sem o bloco 099")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-22_099-restos-auditoria-voz-externa-circuito.md"
exigir(relatorio.is_file(), "relatório do bloco 099 não existe")
texto_relatorio = ler(relatorio)
for termo in ("## 5. Limites declarados", "82d13948027e4be69892dd3d0104e681",
              "Nada foi compilado"):
    exigir(termo in texto_relatorio, f"relatório sem “{termo}”")

# 10. Proibições do projeto.
proibido = re.compile(r"(GlobalScope|Process\.run|Runtime\.getRuntime|shell)")
for arquivo in list(LIB.rglob("*.dart")) + [ANDROID / "JarvisVoz.kt", ANDROID / "MainActivity.kt"]:
    exigir(not proibido.search(ler(arquivo)),
           f"{arquivo.relative_to(RAIZ)} usa construção proibida")

if falhas:
    print("FALHAS no contrato do ajuste 099:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)

print("OK: ajuste 099 — 26 módulos com estado, voz externa por ID, projetista "
      "por prompt e documentação conferidos.")
