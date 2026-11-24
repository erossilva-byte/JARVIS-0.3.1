#!/usr/bin/env python3
"""Contrato do provedor sem chave (ajuste 093, versão 1.79.0).

O Zero-Key é opcional e desligado por padrão. Este contrato prende, sem rede:

1. existe um único provedor `semChave`, por último na prioridade;
2. sem consentimento ele não conta como configurado, não é escolhido e a
   conversa explica que está desligado;
3. com consentimento a chamada sai sem cabeçalho `Authorization` e sem chave
   gravada no cofre;
4. o limite do serviço público (45 s por IP, 402/429/503) é explicado, sem
   chamar de problema de conexão nem prometer disponibilidade;
5. a tela tem o interruptor, o texto de privacidade e nenhum campo de chave
   para o Zero-Key;
6. versão, CHANGELOG, relatório, inventário e suíte estão atualizados.
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
consentimento = ler(APP / "lib" / "services" / "zero_key_store.dart")
tela = ler(APP / "lib" / "provider_settings_page.dart")
resumo = ler(APP / "lib" / "services" / "resumo_ia_service.dart")
voz = ler(APP / "lib" / "services" / "voice_conversation_page.dart")
ponte = ler(APP / "lib" / "services" / "ponte_ia_fundo.dart")
teste_dart = ler(APP / "test" / "zero_key_test.dart")
teste_tela = ler(APP / "test" / "zero_key_page_test.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
pacote = ler(RAIZ / "package.json")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-21_093-provedor-sem-chave.md"

# 1. Versão, suíte e relatório.
exigir("version: 1.89.0+18900" in pubspec,
       "versão não atualizada para 1.79.0")
exigir("1.79.0" in changelog and "sem chave" in changelog.lower(),
       "CHANGELOG sem o bloco 1.79.0 do provedor sem chave")
exigir("tests/test_zero_key.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir(relatorio.is_file(), "relatório 093 ausente")

# 2. Um único provedor sem chave, por último na prioridade.
exigir(servico.count("semChave: true") == 1,
       "deve existir exatamente um provedor sem chave")
exigir("id: 'zerokey'" in servico, "provedor sem chave sem id zerokey")
exigir("text.pollinations.ai/openai/chat/completions" in servico,
       "endpoint sem chave diferente do medido")
exigir("model: 'openai-fast'" in servico,
       "modelo sem chave diferente do medido")
exigir("provedorSemChave,\n];" in servico,
       "provedor sem chave não é o último da lista de prioridade")
exigir("provedorSemChave,\n];" in servico
       and servico.index("provedorSemChave,\n];") > servico.index("id: 'gemini'"),
       "Zero-Key precisa ficar depois dos provedores com chave")

# 3. Sem consentimento nada é escolhido; com consentimento, sem Authorization.
exigir("if (provider.semChave) return _zeroKey.ativo();" in servico,
       "isConfigured não consulta o consentimento do Zero-Key")
exigir("if (chave != null && chave.isNotEmpty)" in servico,
       "cabeçalho Authorization não é condicional à chave")
exigir(servico.count("'Authorization'") == 1,
       "Authorization aparece fora do único ponto que decide a chave")
exigir("_cabecalhos(key)" in servico and "_cabecalhos(key, streaming: true)" in servico,
       "chamadas não usam o mesmo conjunto de cabeçalhos")
exigir("Future<String?> _chaveDe(AiProvider provider)" in servico,
       "serviço não separa provedor com chave de provedor sem chave")
exigir("throw const ProviderException(_zerokeyDesligado)" in servico,
       "conversa não recusa o Zero-Key desligado com explicação")
exigir("não guarda chave" in servico,
       "saveKey não recusa o provedor sem chave")
exigir("não tem chave para remover" in servico,
       "removeKey não recusa o provedor sem chave")

# 4. Limite do serviço público explicado e nada de promessa de gratuidade.
exigir("45 segundos" in servico and "45 s" in servico,
       "limite do serviço público não aparece nas mensagens")
for termo in ("402", "429", "503"):
    exigir(termo in servico, f"mensagem para HTTP {termo} ausente")
exigir("sem cota" in servico, "falta a explicação de cota esgotada")
exigir("ilimitad" not in servico.lower(),
       "serviço promete uso ilimitado do provedor público")
exigir("ilimitad" not in tela.lower(),
       "tela promete uso ilimitado do provedor público")

# 5. Consentimento desligado por padrão e fora do cofre de chaves.
exigir("jarvis.zerokey.ativo" in consentimento,
       "preferência do Zero-Key sem chave estável")
exigir("?? false" in consentimento,
       "consentimento do Zero-Key não é desligado por padrão")
exigir("catch (_)" in consentimento
       and "return false" in consentimento,
       "falha ao ler preferência deve manter o Zero-Key desligado")
exigir("SecureStorage" not in consentimento,
       "consentimento não deve passar pelo cofre de chaves")
exigir("definirZeroKey" in servico, "serviço não expõe ligar/desligar o Zero-Key")

# 6. Tela: interruptor, texto de privacidade e sem campo de chave no Zero-Key.
exigir("zerokey-ativar" in tela, "tela sem interruptor do Zero-Key")
exigir("Switch(" in tela, "tela sem controle de ativação")
exigir("45 segundos" in tela, "tela não declara o limite do serviço público")
exigir("sem cadastro" in tela and "pelo IP" in tela,
       "tela não explica o que sai do aparelho")
exigir("if (!provider.semChave)" in tela,
       "tela não esconde salvar/remover chave no provedor sem chave")
exigir("_alternarZeroKey" in tela, "tela não grava o consentimento")

# 7. As telas que dependem de provedor mencionam a opção sem chave.
for nome, texto in (("resumo_ia_service", resumo),
                    ("voice_conversation_page", voz),
                    ("ponte_ia_fundo", ponte)):
    exigir("Zero-Key" in texto, f"{nome} não oferece o Zero-Key quando falta provedor")

# 8. Testes Dart cobrem o essencial.
for termo in ("desligado por padrão", "sem cabeçalho Authorization",
              "402 do serviço público", "só tenta o Zero-Key depois",
              "não guarda nem remove chave"):
    exigir(termo in teste_dart, f"teste Dart sem o caso: {termo}")
exigir("zerokey-ativar" in teste_tela, "teste de tela sem o interruptor")
exigir("Zero-Key ativado" in teste_tela, "teste de tela não confere a ativação")

# 9. Documentação.
exigir("Zero-Key" in inventario, "INVENTARIO_DE_FUNCOES sem a seção do Zero-Key")
exigir("exige chave do usuário | **Falta**" not in comparativo,
       "comparativo com o ULTRON ainda diz que o provedor sem chave falta")
exigir("ajuste 093" in comparativo, "comparativo sem a referência ao ajuste 093")

if falhas:
    print("FALHAS:")
    for falha in falhas:
        print(" -", falha)
    raise SystemExit(1)

print("Zero-Key: contrato do ajuste 093 conferido.")
