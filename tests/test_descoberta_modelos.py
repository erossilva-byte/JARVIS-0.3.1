#!/usr/bin/env python3
"""Contrato da descoberta de modelos (ajuste 094, versão 1.80.0).

Sem rede, este contrato prende:

1. o endereço de `/models` é derivado do endpoint de conversa, com o Gemini no
   caminho nativo (o de compatibilidade responde 404);
2. a resposta é lida nos dois formatos e não inventa modelo quando é inválida;
3. a descoberta exige provedor configurado, manda só a chave e nada da conversa;
4. o modelo escolhido é guardado nas preferências (não no cofre) e passa a ser o
   primeiro tentado; 404 cai para o padrão;
5. a tela tem filtro, marca o modelo atual, avisa que a lista não garante acesso
   e oferece voltar ao padrão;
6. versão, CHANGELOG, relatório, inventário, comparativo e suíte atualizados.
"""

from __future__ import annotations

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


servico = ler(APP / "lib" / "services" / "provider_service.dart")
loja = ler(APP / "lib" / "services" / "modelo_store.dart")
tela = ler(APP / "lib" / "provider_settings_page.dart")
teste_dart = ler(APP / "test" / "descoberta_modelos_test.dart")
teste_tela = ler(APP / "test" / "descoberta_modelos_page_test.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
relatorio = (
    RAIZ / "docs" / "relatorios" / "2026-11-21_094-descoberta-de-modelos.md"
)

# 1. Versão, suíte e relatório.
exigir("version: 1.104.0+110400" in pubspec,
       "versão não atualizada para 1.80.0")
exigir("1.80.0" in changelog and "modelos" in changelog.lower(),
       "CHANGELOG sem o bloco 1.80.0 da descoberta de modelos")
exigir("tests/test_descoberta_modelos.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 094 ausente")

# 2. Endereços: derivado para OpenAI-compatíveis, nativo para o Gemini.
exigir("String urlDeModelos(AiProvider provider)" in servico,
       "sem função de derivação do endereço de modelos")
exigir("replaceFirst(RegExp(r'/chat/completions$'), '')" in servico,
       "endereço não é derivado do endpoint de conversa")
exigir("https://generativelanguage.googleapis.com/v1beta/models" in servico,
       "Gemini sem o endereço nativo de modelos")
exigir("x-goog-api-key" in servico,
       "Gemini sem o cabeçalho próprio de autenticação")
exigir(servico.count("x-goog-api-key") == 1,
       "cabeçalho do Gemini fora do único ponto de descoberta")

# 3. Leitura honesta da resposta.
exigir("List<ModeloDoProvedor> lerModelos(String corpo)" in servico,
       "sem leitura da lista de modelos")
exigir("supportedGenerationMethods" in servico
       and "generateContent" in servico,
       "não descarta modelos que o Gemini não usa para conversa")
exigir("contains('embedding')" in servico,
       "não descarta modelos de embedding")
exigir("return const [];" in servico,
       "resposta inválida não devolve lista vazia")

# 4. Privacidade e recusa sem chave.
inicio = servico.find("Future<List<ModeloDoProvedor>> descobrirModelos")
fim = servico.find("Future<AiProvider?> firstConfiguredProvider", max(inicio, 0))
bloco = servico[inicio:fim] if inicio >= 0 and fim > inicio else ""
exigir("'messages'" not in bloco,
       "descoberta parece enviar mensagens da conversa")
exigir("Cadastre a chave deste provedor antes de ver os modelos." in bloco,
       "descoberta sem chave não recusa com explicação")
exigir("_zerokeyDesligado" in bloco,
       "descoberta ignora o consentimento do Zero-Key")
exigir(".get(" in bloco, "descoberta não usa GET")
exigir("Duration(seconds: 15)" in bloco, "descoberta sem limite de tempo")
for codigo in ("401", "403", "404", "429"):
    exigir(codigo in servico, f"mensagem para HTTP {codigo} ausente")
exigir("O modelo padrão continua valendo." in servico,
       "falha ao listar não diz que o padrão continua valendo")

# 5. Escolha guardada e ordem de tentativa.
exigir("jarvis.ai.modelo." in loja, "preferência de modelo sem chave estável")
exigir("SecureStorage" not in loja,
       "escolha de modelo não deve passar pelo cofre de segredos")
exigir("Future<String?> modeloEscolhido" in servico,
       "serviço não expõe o modelo escolhido")
exigir("Future<void> escolherModelo" in servico,
       "serviço não grava o modelo escolhido")
exigir("Future<List<String>> _modelosPara(AiProvider provider)" in servico,
       "ordem de modelos não está centralizada")
exigir("if (escolhido != null && escolhido.isNotEmpty) escolhido," in servico,
       "modelo escolhido não é o primeiro tentado")
exigir(servico.count("await _modelosPara(provider)") == 3,
       "ordem de modelos não vale nos três caminhos (teste, conversa, streaming)")
exigir("final modelos = [provider.model, ...provider.fallbackModels];" not in servico,
       "ainda existe caminho usando só os modelos fixos")

# 6. Tela: lista, filtro, aviso e voltar ao padrão.
exigir("ValueKey('modelos-${provider.id}')" in tela,
       "cartão sem botão de listar modelos")
exigir("ValueKey('modelos-busca')" in tela, "janela sem filtro")
exigir("ValueKey('modelo-padrao')" in tela, "janela sem voltar ao padrão")
exigir("'Modelo em uso: " in tela, "cartão não mostra o modelo em uso")
exigir("não garante que a sua chave alcança" in tela,
       "janela não avisa que a lista não garante acesso")
exigir("_voltarAoPadrao" in tela, "tela não permite desfazer a escolha")
exigir("configured[provider.id] != true" in tela,
       "tela oferece lista sem provedor configurado")

# 7. Testes Dart.
for termo in ("endereço de /models", "lê a lista nativa do Gemini",
              "resposta inválida não vira lista inventada",
              "nada da conversa", "x-goog-api-key",
              "sem chave, a descoberta nem chama a rede",
              "primeiro tentado na conversa", "cai para o padrão",
              "apagar volta ao padrão"):
    exigir(termo in teste_dart, f"teste Dart sem o caso: {termo}")
for termo in ("modelos-groq", "modelos-busca", "Modelo escolhido",
              "sem consentimento"):
    exigir(termo in teste_tela, f"teste de tela sem o caso: {termo}")

# 8. Documentação.
exigir("Descoberta de modelos" in inventario,
       "INVENTARIO_DE_FUNCOES sem a seção da descoberta")
exigir("| seleção manual de modelo | **Falta** |" not in comparativo,
       "comparativo ainda diz que a descoberta de modelos falta")
exigir("ajuste 094" in comparativo,
       "comparativo sem a referência ao ajuste 094")

if falhas:
    print("FALHAS:")
    for falha in falhas:
        print(" -", falha)
    raise SystemExit(1)

print("Descoberta de modelos: contrato do ajuste 094 conferido.")
