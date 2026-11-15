"""Confere por leitura estática as garantias de privacidade das fichas de pessoas.

Sem Android SDK, o que dá para provar aqui é o que se perde numa edição distraída: consentimento
obrigatório, armazenamento seguro, contexto da IA sem contato/observação/histórico e ausência de
câmera, biometria ou rede no código das fichas. O comportamento é testado em Dart/Flutter.
"""
from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CORE = RAIZ / "flutter_app" / "lib" / "core" / "pessoas.dart"
STORE = RAIZ / "flutter_app" / "lib" / "services" / "pessoas_store.dart"
PAGINA = RAIZ / "flutter_app" / "lib" / "services" / "pessoas_page.dart"
HOME = RAIZ / "flutter_app" / "lib" / "home_screen.dart"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, STORE, PAGINA, HOME):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    store = STORE.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    home = HOME.read_text(encoding="utf-8")

    # 1. Consentimento é regra, não sugestão.
    if "validarPessoa" not in core or "consentimento" not in core:
        falhas.append("núcleo sem validação de consentimento")
    if "if (pessoa.consentimento" in core:
        falhas.append("consentimento invertido: aceitaria sem autorização")

    # 2. Armazenamento seguro e sem rede nas fichas.
    if "FlutterSecureStorage" not in store:
        falhas.append("fichas não usam armazenamento seguro")
    for proibido in ("shared_preferences", "package:http", "dio", "image_picker", "camera"):
        for nome, texto in (("store", store), ("página", pagina), ("núcleo", core)):
            if proibido in texto:
                falhas.append(f"{proibido} aparece em {nome}; fichas devem ser locais e sem câmera")

    # 3. Contexto da IA não carrega contato, observação, compromisso nem histórico.
    inicio = core.find("String contextoPessoas")
    if inicio < 0:
        falhas.append("contextoPessoas ausente")
    else:
        trecho = core[inicio:]
        for campo in (".contatos", ".observacoes", ".compromissos", ".historico"):
            if campo in trecho:
                falhas.append(f"contexto da IA inclui {campo}")

    # 4. Descrição não inventa: sem dados, diz exatamente isso.
    if "nenhuma informação além do nome" not in core:
        falhas.append("descrição sem frase explícita de ausência de dados")

    # 5. A tela declara o que não existe e mostra campo vazio como não informado.
    if "Sem foto, câmera ou reconhecimento facial" not in pagina:
        falhas.append("tela não declara ausência de foto/reconhecimento facial")
    if "Não informado" not in pagina:
        falhas.append("tela não mostra campo vazio como não informado")
    if "Excluir esta ficha?" not in pagina:
        falhas.append("exclusão da ficha sem confirmação")

    # 6. A conversa usa o bloco seguro e o bloco não carrega campo sensível.
    conversa = RAIZ / "flutter_app" / "lib" / "services" / "voice_conversation_page.dart"
    if not conversa.is_file():
        falhas.append("tela de conversa ausente")
    else:
        texto_conversa = conversa.read_text(encoding="utf-8")
        if "blocoPessoasParaConsulta" not in texto_conversa:
            falhas.append("conversa não usa o bloco seguro de pessoas")
        if "pessoas: contextoPessoa" not in texto_conversa:
            falhas.append("bloco de pessoas não chega às mensagens do provedor")

    inicio_bloco = core.find("String blocoPessoasParaConsulta")
    fim_bloco = core.find("String contextoPessoas", inicio_bloco)
    if inicio_bloco < 0 or fim_bloco < 0:
        falhas.append("blocoPessoasParaConsulta ausente")
    else:
        trecho_bloco = core[inicio_bloco:fim_bloco]
        for campo in (".contatos", ".observacoes", ".compromissos", ".historico"):
            if campo in trecho_bloco:
                falhas.append(f"bloco da conversa inclui {campo}")
        if "não invente" not in trecho_bloco:
            falhas.append("bloco da conversa sem instrução contra invenção")
        if "nenhuma ficha" not in trecho_bloco:
            falhas.append("bloco da conversa não cobre nome ausente")

    # 7. O módulo do menu abre as fichas, não um placeholder.
    if "Pessoas e contexto" not in home or "PessoasPage" not in home:
        falhas.append("menu de Pessoas não abre a tela de fichas")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"Privacidade das fichas: {len(falhas)} problema(s).")
        return 1
    print("OK: fichas de pessoas — consentimento, armazenamento seguro, contexto sem dado sensível e sem câmera")
    return 0


if __name__ == "__main__":
    sys.exit(main())
