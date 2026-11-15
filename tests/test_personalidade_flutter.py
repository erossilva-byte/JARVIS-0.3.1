"""Confere por leitura estática a personalidade/humor da interface Flutter.

Sem aparelho e sem chave, o que se prova aqui é o contrato: o nível certo vira prompt, assunto
sensível zera o humor, a conversa usa o estilo e a tela não promete mudar voz nem autenticar.
O comportamento é exercitado em Dart/Flutter.
"""
from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CORE = RAIZ / "flutter_app" / "lib" / "core" / "personalidade.dart"
STORE = RAIZ / "flutter_app" / "lib" / "services" / "personalidade_store.dart"
PAGINA = RAIZ / "flutter_app" / "lib" / "services" / "personalidade_page.dart"
CONVERSA = RAIZ / "flutter_app" / "lib" / "services" / "voice_conversation_page.dart"
HOME = RAIZ / "flutter_app" / "lib" / "home_screen.dart"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, STORE, PAGINA, CONVERSA, HOME):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    store = STORE.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    conversa = CONVERSA.read_text(encoding="utf-8")
    home = HOME.read_text(encoding="utf-8")

    # 1. Níveis reais e um padrão seguro.
    for nivel in ("discreto", "equilibrado", "avancado"):
        if nivel not in core:
            falhas.append(f"nível {nivel} ausente")
    if "NivelHumor.equilibrado" not in core:
        falhas.append("sem nível padrão declarado")

    # 2. Assunto sensível suspende o humor, não só "reduz".
    if "termosSensiveis" not in core:
        falhas.append("lista de assuntos sensíveis ausente")
    for termo in ("saúde", "luto", "violência", "segurança", "dinheiro"):
        if termo not in core:
            falhas.append(f"termo sensível {termo} ausente")
    if "Humor zero" not in core:
        falhas.append("prompt não zera o humor em assunto sensível")
    if "nunca com a pessoa" not in core:
        falhas.append("falta limite contra piada com a pessoa")
    if "Não copie falas" not in core:
        falhas.append("falta proibição de imitar filmes")

    # 3. A conversa aplica o estilo e não o esquece.
    if "estiloDoTurno" not in conversa:
        falhas.append("conversa não monta o estilo do turno")
    if "personalidade: estilo.prompt" not in conversa:
        falhas.append("estilo não chega às mensagens do provedor")
    if "PersonalidadeStore.abrir" not in conversa:
        falhas.append("conversa não lê o nível salvo")

    # 4. A preferência é local e não é segredo; nada de rede.
    if "shared_preferences" not in store:
        falhas.append("preferência não usa armazenamento local")
    for proibido in ("package:http", "image_picker", "camera", "microphone"):
        if proibido in store or proibido in pagina:
            falhas.append(f"{proibido} aparece na personalidade; ela é só uma preferência")

    # 5. A tela declara os próprios limites.
    if "não muda a voz" not in pagina:
        falhas.append("tela não diz que o nível não muda a voz")
    if "não autentica" not in pagina:
        falhas.append("tela não diz que o nível não autentica")
    if "humor é suspenso por completo" not in pagina:
        falhas.append("tela não avisa da suspensão em assunto sensível")
    if "Personalidade salva" not in pagina or "Não foi possível salvar" not in pagina:
        falhas.append("tela não informa sucesso e falha ao salvar")

    # 6. O menu abre a tela real, não o catálogo genérico.
    if "Personalização" not in home or "PersonalidadePage" not in home:
        falhas.append("menu de Personalização não abre a tela real")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"Personalidade Flutter: {len(falhas)} problema(s).")
        return 1
    print("OK: personalidade — níveis, humor zero em assunto sensível, prompt na conversa e limites declarados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
