#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
1.11.0 — o que esta revisão precisa garantir para não regredir.

Confere, no código real, quatro coisas: (a) o streaming existe e o caminho normal
continua como fallback; (b) o tom do turno entra no prompt e nas frases próprias;
(c) o gravador não pode voltar a ficar pendurado; (d) o código morto removido não
ressuscita e a versão está consistente em todos os arquivos.
"""
import json
import re
import sys
from pathlib import Path

raiz = Path(__file__).resolve().parent.parent
app = (raiz / "app.js").read_text(encoding="utf-8")
servico = (raiz / "JarvisService.java").read_text(encoding="utf-8")
vigia = (raiz / "JarvisWatchdog.java").read_text(encoding="utf-8")
plug = (raiz / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))
historico = (raiz / "CHANGELOG.md").read_text(encoding="utf-8")
leituras = (raiz / "LEIA-ME.md").read_text(encoding="utf-8")
gradle = (raiz / "android" / "app" / "build.gradle")
gradle = gradle.read_text(encoding="utf-8") if gradle.exists() else ""

checagens = {
    # 1. Streaming com fallback para o caminho normal
    "Corpo da resposta é lido em streaming": (
        "async function lerStreamIA(" in app
        and "b.stream = true" in app
        and "data: " in app and "[DONE]" in app),
    "Fala antecipada quando o campo fecha no JSON parcial": (
        "function extrairFalaParcial(" in app
        and "const s = await tentarStream(p, conteudo, avisoIA ? null : aoFalar);" in app
        and "if (r.jaFalou) await r.jaFalou;" in app),
    "Caminho normal continua como fallback": (
        "let r = await tentarProvedor(p);" in app
        and "if (!res.ok) return { ok: false, status: res.status" in app),
    "Streaming pode ser desligado sem sair do app": "const usaStream = () => store.get('resposta_stream', '1') === '1';" in app,
    "Provedor sem streaming não pausa nem erra": (
        "const aposentado = s && (s.status === 404" in app
        and "if (!aposentado) return null;" in app),

    # 2. Latência
    "Pré-aquecimento da conexão está ligado ao caminho quente": (
        app.count("aquecer();") >= 3 and "function aquecer() {" in app),
    "Motor de voz aquecido durante a transcrição": (
        "async function aquecerVoz(forcar)" in app and "if (!neuralAtiva()) aquecerVoz(true);" in app),

    # 3. Travamento
    "Gravador não usa executor async dentro de new Promise": (
        "return new Promise((resolve, reject) => {" in app
        and "return new Promise(async (resolve, reject)" not in app
        and "} catch (e) { falhar(e); }" in app),

    # 4. Tom do turno e humor
    "Pressa e assunto sensível são detectados por turno": (
        "const RX_SENSIVEL =" in app and "const RX_PRESSA =" in app and "function tomDoTurno(" in app),
    "O prompt recebe o contexto do turno": "CONTEXTO DO TURNO" in app and "${tomTurno}" in app,
    "Frases próprias com variação e gating de humor": (
        "const FRASES = {" in app and "function fraseApp(" in app and "const rotacaoFrases = {};" in app),
    "Humor respeita configuração, pressa e sensibilidade": (
        "humor >= 40 && !tom.serio && !tom.pressa" in app
        and "if (tomDoTurno(perguntaAtual).serio) return 'Agora não é o melhor momento" in app),
    "Preferência de humor continua lida do armazenamento": (
        "const humor = Math.max(0, Math.min(100, Number(store.get('humor', '40'))))" in app),

    # 5. Recursos e ciclo de vida
    "Histórico com limite de memória": "while (hist.length > 120) hist.shift();" in app,
    "Lista de vozes cacheada com janela de reteste": "vozesVaziasAte" in app,
    "Voltar ao primeiro plano religa a ativação": (
        "if (wakeLigado() && !wakeAtivo && !iniciandoWake) iniciarWake();" in app),

    # 6. Código morto
    "Vigia sem garantir() sem chamador": "static void garantir(" not in vigia,
    "Serviço sem pararTeste() sem chamador": "static void pararTeste(" not in servico,
    "Plugin sem métodos de escuta órfãos": (
        "public void pausarEscuta(PluginCall" not in plug
        and "public void pararTesteEscuta(PluginCall" not in plug
        and "public void statusEscuta(PluginCall" not in plug),
    "Nada foi perdido no diagnóstico": (
        "public void statusTesteEscuta(PluginCall" in plug
        and "public void iniciarTesteEscuta(PluginCall" in plug
        and "public void statusEscuta" not in plug),

    # 7. Versão e documentação
    "Versão 1.11.0 com versionCode 10110": (
        versao.get("version") == "1.11.0"
        and versao.get("versionCode") == 10110
        and pacote.get("version") == "1.11.0"
        and "const VERSAO_APP = '1.11.0';" in app
        and (not gradle or ("versionCode 10110" in gradle and 'versionName "1.11.0"' in gradle))),
    "Mudança registrada no CHANGELOG": "## 1.11.0" in historico,
    "Instruções atualizadas no LEIA-ME": (
        "# J.A.R.V.I.S. Nova 1.11.0" in leituras
        and "1.10.0" in leituras  # histórico preservado
        and "assinatura" in leituras.lower()),
    "Teste de comportamento do streaming na suíte": "test_stream_1110.js" in pacote.get("scripts", {}).get("test:all", ""),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(("OK: " if ok else "FALHA: ") + nome)
if falhas:
    print("\n%d verificação(ões) da 1.11.0 falharam." % len(falhas))
    sys.exit(1)
print("\n%d verificações da 1.11.0 aprovadas." % len(checagens))
