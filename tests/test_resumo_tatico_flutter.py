#!/usr/bin/env python3
"""Contrato do resumo tático das mensagens (ajuste 085, versão 1.72.0).

O JARVIS já lia as notificações e respondia por elas. Faltava o que o pedido do
usuário chama de resumo tático: separar ruído de grupo, destacar o urgente e
sugerir a resposta — com os provedores de IA que o app já tem.

O que este contrato prende, sem aparelho e sem rede:

1. urgência e ruído de grupo têm regra local pura e testável;
2. o pedido ao provedor é curto, limitado e proíbe invenção;
3. a resposta do provedor é lida com tolerância a cerca de código e a JSON
   inválido devolve nada, em vez de resumo inventado;
4. sem provedor, a tela mostra a triagem local e o motivo honesto;
5. a sugestão abre a resposta da notificação já preenchida;
6. nada de dependência nova, chave em log ou envio sem o provedor do usuário.
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


nucleo = ler(LIB / "core" / "resumo_tatico.dart")
servico = ler(LIB / "services" / "resumo_ia_service.dart")
tela = ler(LIB / "services" / "aparelho_page.dart")
provedor = ler(LIB / "services" / "provider_service.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_085-resposta-em-qualquer-modo-e-resumo-tatico.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.103.0+110300" in pubspec, "versão não atualizada para 1.72.0")
exigir("1.72.0" in changelog and "resumo" in changelog.lower(),
       "CHANGELOG sem o bloco 1.72.0 do resumo")
exigir("tests/test_resumo_tatico_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/resumo_tatico_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 085 ausente")

# 2. Regra local pura.
for termo in ("palavrasUrgentes", "sinaisDeGrupo", "mensagemUrgente",
              "ruidoDeGrupo", "triarMensagens", "TriagemMensagens",
              "SugestaoResposta", "ResumoTatico", "lerResumoTatico",
              "mensagensResumoTatico", "limiteResumoIa"):
    exigir(termo in nucleo, f"core/resumo_tatico.dart sem {termo}")
exigir("urgentes.add(n)" in nucleo and "ruido.add(n)" in nucleo,
       "triagem não separa urgente de ruído")
exigir("SOMENTE com um JSON" in nucleo,
       "pedido não exige JSON como resposta")
exigir("Não invente" in nucleo,
       "pedido não proíbe invenção de remetente/valor")
exigir("indexOf('{')" in nucleo and "lastIndexOf('}')" in nucleo,
       "leitura não tolera texto em volta do JSON")
exigir("replaceAll(RegExp(r'```[a-zA-Z]*'), '')" in nucleo,
       "leitura não remove a cerca de código")
exigir("return resultado.vazio ? null : resultado;" in nucleo,
       "resumo vazio é aceito como resposta")

# 3. Serviço usa o provedor já configurado e devolve o motivo quando falha.
exigir("firstConfiguredProvider()" in servico,
       "serviço não usa o provedor configurado")
exigir("_provedor.complete(" in servico,
       "serviço não chama o provedor")
exigir("mensagensResumoTatico(" in servico,
       "serviço não monta o pedido do resumo")
exigir("lerResumoTatico(bruto)" in servico,
       "serviço não lê a resposta com tolerância")
exigir("triagemLocal(" in servico,
       "sem provedor, o serviço não devolve a triagem local")
exigir("Nenhum provedor de IA configurado" in servico,
       "motivo honesto ausente quando não há provedor")
exigir("erro.message" in servico,
       "erro do provedor não é repassado")
exigir("PlatformSecretStore()" in servico,
       "serviço não usa o cofre seguro de credenciais")

# 4. Tela: botão do resumo, cartões e sugestão aproveitada.
exigir("ValueKey('aparelho-notificacoes-resumo')" in tela,
       "tela sem o botão do resumo tático")
exigir("Future<void> _resumir()" in tela, "tela sem a ação de resumir")
exigir("ValueKey('resumo-texto')" in tela, "tela sem o texto do resumo")
exigir("ValueKey('resumo-erro')" in tela, "tela sem o motivo da falha")
exigir("URGENTE" in tela, "tela não destaca o urgente")
exigir("Ruído de grupo filtrado" in tela,
       "tela não mostra o ruído de grupo filtrado")
exigir("RESPOSTAS SUGERIDAS" in tela, "tela sem as respostas sugeridas")
exigir("ValueKey('resumo-sugestao-$i')" in tela,
       "sugestão sem botão de usar")
exigir("_responderSugestao(" in tela, "tela não abre a resposta da sugestão")
exigir("notificacaoParaResponder(notificacoes, app: sugestao.app)" in tela,
       "sugestão não procura a notificação do app certo")
exigir("textoInicial" in tela and
       "TextEditingController(text: widget.textoInicial)" in tela,
       "diálogo de resposta não abre preenchido com a sugestão")
exigir("class _DialogoResposta extends StatefulWidget" in tela,
       "diálogo perdeu o estado próprio")
exigir("widget.resumoIa ?? ResumoIaService()" in tela,
       "tela não permite injetar o serviço de resumo")

# 5. Reutiliza o que já existe: nada de SDK novo nem chave exposta.
exigir("package:http/http.dart" in provedor,
       "provedor deixou de usar o cliente HTTP já instalado")
for proibido in ("google_generativeai", "openai_dart", "langchain"):
    exigir(proibido not in pubspec.lower(),
           f"SDK novo não previsto no pubspec: {proibido}")
exigir("environment:" in pubspec, "pubspec sem bloco de ambiente")
exigir("SecretStore" in provedor,
       "provedor deixou de usar o cofre de segredos")
exigir("print(" not in servico and "print(" not in nucleo,
       "resumo imprime saída no console")
exigir("Platform.environment" not in servico,
       "serviço lê variáveis de ambiente do aparelho")

# 6. Documentação.
exigir("resumo tático" in inventario.lower(),
       "inventário não cita o resumo tático")
if relatorio.is_file():
    texto = ler(relatorio)
    for termo in ("ruído", "urgente", "sugest", "provedor"):
        exigir(termo in texto.lower(), f"relatório 085 sem {termo}")

if falhas:
    print("FALHAS no contrato do resumo tático:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato do resumo tático: aprovado.")
