#!/usr/bin/env python3
"""Contrato da automação de tela (ajuste 095, versão 1.81.0).

A acessibilidade entrou com escopo estreito e consentimento duplo. Este
contrato prende, sem aparelho e sem compilar:

1. existe um serviço dedicado que só lê a janela ativa, toca e rola;
2. não digita, não usa coordenadas, não executa shell e não lê senha nem o
   conteúdo de campo de texto;
3. o manifesto gerado declara o serviço com a permissão de vínculo e a
   configuração XML, e o preparo copia o arquivo Kotlin;
4. o consentimento é uma preferência desligada por padrão; sem ela nenhuma
   chamada chega ao Android;
5. a tela tem interruptor, estado real do serviço, campo de comando e link
   para as configurações do Android;
6. versão, suíte, CHANGELOG, relatório, inventário e comparativo atualizados.
"""

from __future__ import annotations

import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
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


nativo = ler(ANDROID / "JarvisAcessibilidade.kt")
main = ler(ANDROID / "MainActivity.kt")
preparo = ler(APP / "tool" / "prepare_android_sistema.py")
xml = ler(ANDROID / "sistema" / "res" / "xml" / "jarvis_acessibilidade.xml")
strings = ler(ANDROID / "sistema" / "res" / "values" / "jarvis_sistema.xml")
store = ler(APP / "lib" / "services" / "acessibilidade_store.dart")
servico = ler(APP / "lib" / "services" / "acessibilidade_service.dart")
tela = ler(APP / "lib" / "services" / "acessibilidade_page.dart")
nucleo = ler(APP / "lib" / "core" / "acessibilidade.dart")
paginas = ler(APP / "lib" / "pages.dart")
teste_dart = ler(APP / "test" / "acessibilidade_test.dart")
teste_tela = ler(APP / "test" / "acessibilidade_page_test.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
guia = ler(RAIZ / "GUIA-ACESSOS-ANDROID.md")
pacote = ler(RAIZ / "package.json")
conversa = ler(APP / "lib" / "services" / "voice_conversation_page.dart")
teste_conversa = ler(APP / "test" / "conversa_tela_test.dart")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-21_095-acessibilidade-de-tela.md"
relatorio_conversa = (RAIZ / "docs" / "relatorios"
                      / "2026-11-21_096-tela-na-conversa.md")

# 1. Versão, suíte e relatório.
exigir("version: 1.92.0+19200" in pubspec,
       "versão não atualizada para 1.81.0")
exigir("1.81.0" in changelog and "acessibilidade" in changelog.lower(),
       "CHANGELOG sem o bloco 1.81.0 da acessibilidade")
exigir("1.82.0" in changelog and "confirmação" in changelog.lower(),
       "CHANGELOG sem o bloco 1.82.0 da tela na conversa")
exigir("tests/test_acessibilidade.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 095 ausente")
exigir(relatorio_conversa.is_file(), "relatório 096 ausente")

# 2. Serviço dedicado, com escopo fechado.
exigir("class JarvisAcessibilidade : AccessibilityService()" in nativo,
       "serviço de acessibilidade ausente ou com outra classe base")
exigir('const val CANAL = "com.jarvis.nova/acessibilidade"' in nativo,
       "canal nativo com nome diferente do combinado")
for termo in ("ACTION_CLICK", "ACTION_SCROLL_FORWARD",
              "ACTION_SCROLL_BACKWARD", "isPassword", "isEditable",
              "contentDescription"):
    exigir(termo in nativo, f"leitura/toque sem {termo}")
exigir("rootInActiveWindow" in nativo and "windows" in nativo,
       "leitura não usa a janela ativa, com alternativa pelas janelas")
exigir("limiteDeNos" in nativo and "120" in nativo,
       "leitura sem teto de nós")

# 3. O que o serviço não faz.
for proibido in ("ACTION_SET_TEXT", "performGlobalAction", "GLOBAL_ACTION",
                 "digitar", "Runtime.getRuntime", "ProcessBuilder",
                 "GlobalScope", "adb ", "su "):
    exigir(proibido not in nativo, f"caminho proibido no serviço: {proibido}")
exigir('"campo de texto"' in nativo,
       "campo de texto não é rotulado sem o conteúdo digitado")
exigir("no.isPassword" in nativo and "if (editavel) \"\"" in nativo,
       "campo de senha ou texto digitado pode ser lido")

# 4. Manifesto gerado e preparo do runner.
for termo in (".JarvisAcessibilidade",
              "android.permission.BIND_ACCESSIBILITY_SERVICE",
              "@xml/jarvis_acessibilidade",
              "android.accessibilityservice.AccessibilityService"):
    exigir(termo in preparo, f"preparo do manifesto sem {termo}")
exigir('shutil.copy2(ANDROID / "JarvisAcessibilidade.kt"' in preparo,
       "preparo não copia JarvisAcessibilidade.kt")
exigir("JarvisAcessibilidade.kt" in preparo.split("def verificar")[1],
       "verificação do preparo não confere o arquivo Kotlin")
exigir('android:canRetrieveWindowContent="true"' in xml,
       "configuração XML sem acesso ao conteúdo da janela")
# Comentário pode citar o que foi recusado; atributo não pode existir.
xml_sem_comentario = re.sub(r"<!--.*?-->", "", xml, flags=re.S)
for proibido in ("canRequestFilterKeyEvents", "canRequestTouchExplorationMode",
                 "canPerformGestures"):
    exigir(proibido not in xml_sem_comentario,
           f"configuração ampla demais: {proibido}")
exigir("jarvis_acessibilidade_descricao" in strings,
       "texto que o Android mostra ao usuário não foi declarado")
exigir("JarvisAcessibilidadeCanal(this).registrar(flutterEngine)" in main,
       "MainActivity não registra o canal de acessibilidade")

# 5. Consentimento desligado por padrão, fora do cofre de chaves.
exigir("jarvis.acessibilidade.ativo" in store,
       "consentimento sem chave de preferência estável")
exigir("?? false" in store, "consentimento não é desligado por padrão")
exigir("catch (_)" in store and "return false" in store,
       "falha ao ler a preferência deve manter a automação desligada")
exigir("SecureStorage" not in store,
       "consentimento não deve passar pelo cofre de chaves")

# 6. Sem consentimento, nenhuma chamada ao Android.
exigir("if (!await _consentimento.ativo())" in servico,
       "serviço não confere o consentimento antes de agir")
exigir(servico.count("await _chamada(") >= 4,
       "serviço não fala com o canal nativo nas ações")
exigir("MissingPluginException" in servico,
       "serviço não trata ausência da ponte Android")

# 7. Interpretador local e sem capturar pergunta.
for termo in ("InterpretadorTela", "LerTela", "TocarNaTela", "RolarTela",
              "PararAutomacao"):
    exigir(termo in nucleo, f"núcleo sem {termo}")
exigir("^como|por que" not in nucleo and "como|por que" in nucleo,
       "interpretador pode capturar pergunta")
exigir("(?:em|no|na|nos|nas)" in nucleo,
       "toque não exige preposição e pode capturar conversa")

# 8. Tela e porta de entrada.
for termo in ("acessibilidade-ativar", "acessibilidade-campo",
              "executar-acessibilidade", "abrir-acessibilidade-android",
              "acessibilidade-status"):
    exigir(termo in tela, f"tela sem {termo}")
exigir("não digita" in tela, "tela não declara que o JARVIS não digita")
exigir("Serviço do Android" in tela, "tela não mostra o estado real do serviço")
exigir("abrir-acessibilidade" in paginas,
       "módulo Android e dispositivos sem a porta de entrada")

# 9. Testes Dart cobrem o essencial.
for termo in ("pergunta e conversa não viram ação",
              "desligado por padrão: nenhuma chamada chega ao Android",
              "tocar e rolar levam o pedido certo",
              "sem a ponte Android a recusa é explícita"):
    exigir(termo in teste_dart, f"teste Dart sem o caso: {termo}")
exigir("toque de recolher" in teste_dart,
       "teste não cobre conversa parecida com comando")
for termo in ("acessibilidade-ativar", "Automação de tela ligada",
              "canal.argumentos.last['texto']"):
    exigir(termo in teste_tela, f"teste de tela sem {termo}")

# 10. Documentação coerente.
exigir("Acessibilidade de tela" in inventario,
       "INVENTARIO_DE_FUNCOES sem a seção da acessibilidade")
exigir("Acessibilidade (clicar/digitar/rolar)" not in comparativo,
       "comparativo ainda descreve a acessibilidade antiga")
exigir("ajuste 095" in comparativo,
       "comparativo sem a referência ao ajuste 095")
exigir("| Resumo tático das mensagens por IA | — | **Falta** |" not in comparativo,
       "comparativo ainda diz que o resumo tático falta")
exigir("**Falta** (o APK é publicado por link)" not in comparativo,
       "comparativo ainda diz que a atualização OTA falta")
exigir("escopo estreito" in guia.lower() or "consentimento" in guia.lower(),
       "guia de acessos não foi atualizado para a automação consentida")

# 11. Ajuste 096: tela na conversa, com confirmação antes de tocar.
for termo in ("ConversaDeTela", "PedirConfirmacao", "CancelarNaTela",
              "perguntaDeConfirmacao"):
    exigir(termo in nucleo, f"decisor da conversa sem {termo}")
exigir("por que" in nucleo and "_sim" in nucleo and "_nao" in nucleo,
       "confirmação falada sem sim/não")
exigir("ConversaDeTela.decidir(texto, pendente: _telaPendente)" in conversa,
       "conversa não consulta o decisor de tela")
exigir("_pedirConfirmacaoTela" in conversa and "_executarNaTela" in conversa,
       "conversa não pergunta antes de tocar")
exigir("confirmar-toque-tela" in conversa and "cancelar-toque-tela" in conversa,
       "conversa sem os botões de confirmação")
exigir("await _tela.consentido()" in conversa,
       "conversa não confere o consentimento antes de perguntar")
exigir("registrarPedido: _telaPendente == null" in conversa,
       "confirmação pendente não é distinguida de um pedido novo")
exigir("AcessibilidadeService.desligadoPeloApp" in conversa,
       "conversa não usa a mesma recusa do serviço")
exigir("_concluirLocal" in conversa and "_sequenciaComandos" in conversa,
       "comando de tela fora do limite e do histórico")
exigir("OrigemExecucao.voz" in conversa,
       "histórico da conversa perde a origem por voz")
for termo in ("pede confirmação e não chama o Android",
              "“não” cancela e nada é tocado",
              "ler a tela executa direto",
              "sem consentimento o toque é recusado",
              "conversa normal não vira ação de tela"):
    exigir(termo in teste_conversa, f"teste da conversa sem o caso: {termo}")

if falhas:
    print("FALHAS:")
    for falha in falhas:
        print(" -", falha)
    raise SystemExit(1)

print("Acessibilidade de tela: contrato do ajuste 095 conferido.")
