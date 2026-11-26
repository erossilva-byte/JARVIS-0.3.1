#!/usr/bin/env python3
"""Contrato do bloco 128 — Etapa 4 do PC: memória em Markdown e fichas de pessoas.

A Etapa 4 tinha dois entregáveis no roteiro: memória em Markdown com busca,
citação e sincronização no mesmo formato do celular (cofre em pasta escolhida),
e fichas de pessoas com consentimento e bloco seguro na conversa. O aceite era
"os mesmos testes de regra do celular portados para o JS do PC (busca,
orçamento, consentimento, ambiguidade)".

Este contrato prende as regras portadas, a ligação no painel e do painel com o
processo principal do Electron, e a promessa que não pode voltar atrás: contato,
observações, compromissos e histórico nunca entram na conversa.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


# 1. Regras da memória portadas do celular, num módulo sem DOM.
regras = ler(RAIZ / "memoria_regras.js")
for trecho in [
    "function buscarNotas(",
    "function contextoRelevante(",
    "function citacoes(",
    "function linhaCitacoes(",
    "function lerMarkdown(",
    "function escreverMarkdown(",
    "function hashConteudo(",
    "function planejarSincronizacao(",
    "function caminhoParaTitulo(",
    "raiz.MemoriaRegras = api",
]:
    exigir(trecho in regras, f"memoria_regras.js perdeu: {trecho}")
# Formato do celular: as chaves do frontmatter são as mesmas do core/memoria.dart.
for chave in ["'id: '", "'titulo: '", "'tema: '", "'tags: ['", "'importancia: '", "'criada: '", "'atualizada: '"]:
    exigir(f"      {chave}" in regras or f"'{chave}" in regras or chave in regras,
           f"Markdown sem a chave {chave} do celular")
exigir("'+ 0.28 * literal'" not in regras, "peso da busca mudou sem teste")
exigir("0.50 * similaridade" in regras and "0.28 * literal" in regras,
       "a pontuação da busca deixou de ser a do celular")
exigir("literal === 0 && similaridade < 0.35" in regras,
       "a busca voltou a aceitar colisão de embedding sem palavra em comum")
exigir("plano.conflitos.push" in regras and "ausentesNaPasta" in regras,
       "sincronização perdeu conflito ou nota ausente")
exigir("  function apagar" not in regras,
       "a regra de sincronização ganhou função de apagar")

# 2. Fichas: consentimento, ambiguidade e bloco seguro.
pessoas = ler(RAIZ / "pessoas.js")
for trecho in [
    "function validar(p)",
    "consentimento",
    "function revogarConsentimento(",
    "function blocoParaConsulta(",
    "FICHAS DE PESSOAS",
    "FICHA DE PESSOA",
    "Contato, anotações, compromissos e histórico não estão disponíveis para envio",
    "blocoParaConsulta: blocoParaConsulta",
]:
    exigir(trecho in pessoas, f"pessoas.js perdeu: {trecho}")
exigir("consentimento desta pessoa" in pessoas,
       "o cadastro deixou de exigir o consentimento declarado")
# O bloco seguro não pode montar o texto com os campos sensíveis.
bloco = pessoas[pessoas.find("function blocoParaConsulta("):pessoas.find("function exportar()")]
for campo in ["contato", "descricao", "observacoes", "compromissos", "historico"]:
    exigir(f"pessoa.{campo}" not in bloco,
           f"o bloco da conversa passou a usar {campo}")

# 3. Cofre em pasta no processo principal: só .md, só dentro da pasta, sem apagar.
pasta = ler(RAIZ / "platforms" / "desktop" / "memoria_pasta.js")
for trecho in [
    "function criarCofre(",
    "function listarNotas(",
    "function escreverNota(",
    "function sincronizar(",
    "A nota tentou sair da pasta escolhida",
    "Só notas .md entram no cofre",
    "fs.renameSync",
]:
    exigir(trecho in pasta, f"memoria_pasta.js perdeu: {trecho}")
exigir("unlinkSync" not in pasta and "rmSync(arquivoConfig" not in pasta.replace("fs.rmSync(arquivoConfig, { force: true })", ""),
       "o cofre em pasta ganhou rotina de apagar nota")
exigir("require('../../memoria_regras.js')" in pasta,
       "o cofre em pasta não usa a regra testada de sincronização")

# 4. Ligação no Electron e no painel.
main = ler(RAIZ / "platforms" / "desktop" / "main.js")
for acao in ["memoria_pasta", "memoria_escolher_pasta", "memoria_esquecer_pasta", "memoria_sincronizar"]:
    exigir(f"{acao}:" in main, f"main.js não registra a ação {acao}")

html = ler(RAIZ / "index.html")
for ident in ["mem-pasta-bloco", "mem-pasta-escolher", "mem-pasta-sincronizar",
              "mem-pasta-esquecer", "mem-pasta-status", "mem-pasta-nome", "idp-consent-dados"]:
    exigir(f'id="{ident}"' in html, f"o HTML não tem #{ident}")
exigir('src="memoria_regras.js"' in html, "index.html não carrega memoria_regras.js")
exigir(html.index('src="memoria_regras.js"') < html.index('src="memoria.js"'),
       "memoria_regras.js precisa carregar antes de memoria.js")

app = ler(RAIZ / "app.js")
for trecho in [
    "const MEM_REGRAS",
    "MEM_REGRAS.buscarNotas(MEM.carregar(), busca",
    "MEM_REGRAS.contextoRelevante(MEM.carregar(), perguntaAtual",
    "FICHAS.blocoParaConsulta",
    "function citacaoDaNota(",
    "function copiarCitacaoMemoria(",
    "async function sincronizarMemPasta(",
    "nativo('memoria_sincronizar'",
]:
    exigir(trecho in app, f"app.js perdeu: {trecho}")
exigir("PESSOAS.contexto()" in app,
       "app.js perdeu o contexto compacto de pessoas")
# O contexto da conversa não pode voltar a mandar a ficha inteira.
exigir("pessoasCtx = (PESSOAS && (!identCfg || identCfg.contexto)" in app,
       "a montagem do contexto de pessoas mudou de forma não prevista")

# 5. Consentimento na tela de pessoas do PC.
ident = ler(RAIZ / "identidade.js")
exigir("function consentirDados(" in ident and "consentirDados: consentirDados" in ident,
       "identidade.js não guarda o consentimento para a ficha")
ui = ler(RAIZ / "identidade_ui.js")
exigir("idp-consent-dados" in ui, "a tela de pessoas não lê o consentimento")
exigir("antes de salvar a ficha" in ui,
       "a tela de pessoas não bloqueia ficha nova sem consentimento")

# 6. Os testes de regra do celular portados para o JS.
regras_teste = ler(RAIZ / "tests" / "test_memoria_regras.js")
for trecho in ["busca", "orçamento", "citação", "Sincronização", "conflito"]:
    exigir(trecho.lower() in regras_teste.lower(), f"test_memoria_regras.js perdeu: {trecho}")
conversa_teste = ler(RAIZ / "tests" / "test_pessoas_conversa.js")
for trecho in ["ambiguidade", "consentimento", "bloco seguro", "telefone"]:
    exigir(trecho.lower() in conversa_teste.lower(), f"test_pessoas_conversa.js perdeu: {trecho}")
pasta_teste = ler(RAIZ / "tests" / "test_memoria_pasta.js")
for trecho in ["caminho absoluto", "sincronizar", "conflito", "esquecer"]:
    exigir(trecho in pasta_teste, f"test_memoria_pasta.js perdeu: {trecho}")

# 7. Versão, changelog, relatório e roteiro.
pubspec = ler(RAIZ / "flutter_app" / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
roteiro = ler(RAIZ / "docs" / "ROTEIRO-PC.md")
relatorio = RAIZ / "docs" / "relatorios" / "2026-11-25_128-memoria-e-pessoas-pc.md"
exigir("version: 1.111.0+111100" in pubspec, "pubspec.yaml não está em 1.111.0+111100")
exigir("## 1.105.0" in changelog, "CHANGELOG.md sem o bloco 1.105.0")
exigir("Estado:** entregue na 1.105.0" in roteiro,
       "o roteiro não registrou a Etapa 4 como entregue")
exigir(relatorio.is_file(), "falta o relatório da Etapa 4")

# 8. A suíte roda os testes novos e o contrato.
try:
    dados = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    scripts = dados["scripts"]["test:all"]
    for trecho in [
        "node tests/test_memoria_regras.js",
        "node tests/test_memoria_pasta.js",
        "node tests/test_pessoas_conversa.js",
        "python3 tests/test_bloco_128.py",
    ]:
        exigir(trecho in scripts, f"test:all não roda: {trecho}")
    arquivos = dados["build"]["files"]
    for nome in ["memoria_regras.js", "platforms/desktop/memoria_pasta.js"]:
        exigir(nome in arquivos, f"o pacote Windows não inclui {nome}")
except Exception as erro:  # noqa: BLE001
    falhas.append(f"package.json inválido: {erro}")

if falhas:
    print("Falhas do bloco 128:")
    for falha in falhas:
        print(f"  - {falha}")
    sys.exit(1)
print("Bloco 128: memória em Markdown e fichas de pessoas no PC — contrato OK")
