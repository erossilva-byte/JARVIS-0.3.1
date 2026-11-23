#!/usr/bin/env python3
"""Contrato da palavra de ativação mais confiável (ajuste 083, versão 1.70.0).

O relato: “o detector às vezes não me ouve quando eu chamo Jarvis”. Havia três
motivos concretos, todos presos por este contrato:

1. a sensibilidade era **fixa no código** (75) e não havia como ajustá-la na tela
   do app Flutter — quem tinha pronúncia diferente ou falava baixo não tinha saída;
2. o limiar só tinha três faixas, então subir a sensibilidade não abria nada
   entre 45 e 69 nem acima de 70;
3. uma falha do motor (JNI/captura) chamava `stopSelf()` e o JARVIS ficava surdo
   até alguém abrir o app; e, depois de acordar, o detector só voltava em 35 s.

Agora a sensibilidade (0–100) vive no aparelho, é gravada pelo serviço Android,
religada na hora quando muda e ajustável na tela “Voz e palavra de ativação”.
O detector se religa sozinho depois de falha e um vigia cobre morte silenciosa.

Continua valendo: só reconhecedor offline, sem nuvem, sem shell, sem GlobalScope
e sem permissão nova. Voz real no aparelho físico segue fora deste contrato.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
KOTLIN = APP / "android"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


servico = ler(KOTLIN / "KwsForegroundService.kt")
principal = ler(KOTLIN / "MainActivity.kt")
motor = ler(RAIZ / "JarvisKwsEngine.java")
modelo = ler(APP / "lib" / "core" / "ativacao_sensibilidade.dart")
ponte = ler(APP / "lib" / "services" / "kws_bridge.dart")
controlador = ler(APP / "lib" / "services" / "kws_controller.dart")
tela = ler(APP / "lib" / "services" / "kws_settings_page.dart")
pubspec = ler(APP / "pubspec.yaml")
changelog = ler(RAIZ / "CHANGELOG.md")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md")
pacote = ler(RAIZ / "package.json")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
relatorio = (RAIZ / "docs" / "relatorios"
             / "2026-11-21_083-ativacao-mais-confiavel.md")

# 1. Versão, changelog, suíte e relatório.
exigir("version: 1.88.4+18804" in pubspec,
       "versão não atualizada para 1.70.0")
exigir("1.70.0" in changelog and "sensibilidade" in changelog.lower(),
       "CHANGELOG sem o bloco 1.70.0 da sensibilidade")
exigir("tests/test_sensibilidade_ativacao_flutter.py" in pacote,
       "contrato novo fora de package.json test:all")
exigir("tool/ativacao_sensibilidade_test.dart" in dart_core,
       "teste puro fora de tests/test_dart_core.py")
exigir(relatorio.is_file(), "relatório 083 ausente")

# 2. A sensibilidade saiu do código fixo e passou a viver no aparelho.
exigir('PREFS_ATIVACAO = "jarvis_kws"' in servico,
       "serviço não guarda a sensibilidade em preferência própria")
exigir("SENSIBILIDADE_PADRAO = 75" in servico,
       "padrão da sensibilidade não é 75 (o valor que já era usado)")
exigir("fun sensibilidadeDe(context: Context): Int" in servico,
       "serviço não lê a sensibilidade do aparelho")
exigir("fun definirSensibilidade(context: Context, valor: Int): Int" in servico,
       "serviço não grava a sensibilidade")
exigir("coerceIn(SENSIBILIDADE_MINIMA, SENSIBILIDADE_MAXIMA)" in servico,
       "sensibilidade gravada sem limitar a 0–100")
exigir("\n            75," not in servico,
       "serviço ainda passa a sensibilidade fixa 75 ao motor")
exigir("val sensibilidade = sensibilidadeDe(applicationContext)" in servico,
       "motor não recebe a sensibilidade escolhida")
exigir("            sensibilidade,\n" in servico,
       "sensibilidade não chega ao construtor do JarvisKwsEngine")

# 3. Mudar na tela vale na hora: reinicia o detector com o limiar novo.
exigir('ACTION_REINICIAR = "com.jarvis.nova.KWS_REINICIAR"' in servico,
       "serviço sem ação de reinício por sensibilidade")
trecho_reinicio = servico.split("if (intent?.action == ACTION_REINICIAR)")[1][:700]
exigir("pararEAguardar(LIBERAR_MICROFONE_MS)" in trecho_reinicio,
       "reinício não espera o AudioRecord fechar")
exigir("iniciarMotor(0)" in trecho_reinicio,
       "reinício não religa o detector com o limiar novo")
exigir("if (running)" in servico.split("fun definirSensibilidade")[1][:900],
       "sensibilidade é gravada mas o detector ativo não é religado")

# 4. Limiar com cinco faixas e pontuação acompanhando.
for termo in ("static float limiarPara(int sensibilidade)",
              "static float pontuacaoPalavra(int sensibilidade)"):
    exigir(termo in motor, f"JarvisKwsEngine.java sem {termo}")
exigir("this.keywordThreshold = limiarPara(s);" in motor,
       "construtor do motor não usa o limiar derivado da sensibilidade")
exigir("setKeywordsThreshold(keywordThreshold)" in motor,
       "limiar não é aplicado ao KWS")
exigir("setKeywordsScore(pontuacaoPalavra(sensibilidade))" in motor,
       "pontuação das palavras não acompanha a sensibilidade")
exigir(motor.count("return 0.") >= 5, "limiar ainda tem menos de cinco faixas")

# 5. Dart e Java precisam concordar nos mesmos pares sensibilidade→limiar.
pares = re.findall(r"s >= (\d+)\) return (0\.\d+)f;", motor)
exigir(len(pares) == 4, f"limiar do Java com faixas inesperadas: {pares}")
for corte, valor in pares:
    exigir(f"s >= {corte}) return {valor};" in modelo,
           f"Dart e Java discordam no limiar de {corte}%: {valor}")

# 6. Ponte, controlador e tela.
exigir("Future<KwsStatus> definirSensibilidade(int valor);" in ponte,
       "ponte sem método de gravar a sensibilidade")
exigir("'definirSensibilidade', {'valor': seguro}" in ponte,
       "ponte não chama o método nativo")
exigir("final int sensibilidade;" in ponte and "final double limiar;" in ponte,
       "estado não devolve a sensibilidade e o limiar em uso")
exigir("int get sensibilidade => _status.sensibilidade;" in controlador,
       "controlador não expõe a sensibilidade atual")
exigir("Future<KwsStatus> definirSensibilidade(int valor) async" in controlador,
       "controlador sem ação de gravar a sensibilidade")
exigir("Sensibilidade da palavra de ativação" in tela,
       "tela sem o controle de sensibilidade")
exigir("ValueKey('sensibilidade-ativacao')" in tela,
       "slider da sensibilidade sem chave estável")
exigir("AtivacaoSensibilidade.descricao(valor)" in tela,
       "tela não explica o efeito do valor escolhido")
exigir("controller.definirSensibilidade(alvo)" in tela,
       "soltar o slider não grava a sensibilidade")
exigir("padrao = 75" in modelo and "passo = 5" in modelo,
       "modelo puro sem padrão 75 ou passo do controle")

# 7. O detector não fica surdo: falha religa e há vigia.
exigir("MAX_TENTATIVAS_FALHA = 3" in servico,
       "serviço sem limite de tentativas de religar")
falha_motor = servico.split("override fun onError(message: String)")[1][:1600]
exigir("stopSelf()" in falha_motor and "scheduleRearme" in falha_motor,
       "falha do motor ainda desliga o detector sem tentar de novo")
exigir("falhasMotor <= MAX_TENTATIVAS_FALHA" in falha_motor,
       "religação sem limite de tentativas")
exigir("fun iniciarVigia()" in servico and "fun pararVigia()" in servico,
       "serviço sem vigia do detector")
vigia = servico.split("private fun iniciarVigia()")[1][:900]
exigir("engine?.isRunning != true" in vigia,
       "vigia não confere se o motor continua de pé")
exigir("comandoAtivo || comandoEmAndamento" in vigia,
       "vigia pode tomar o microfone durante um comando")
exigir("JANELA_POS_DETECCAO_MS" in vigia,
       "vigia pode religar no meio da ativação")
exigir("REARM_DELAY_MS = 8_000L" in servico,
       "detector ainda fica 35 s sem ouvir depois de acordar")
exigir("if (comandoAtivo || comandoEmAndamento)" in servico,
       "detector pode religar durante o comando")

# 8. Métodos nativos expostos e diagnóstico com o valor em uso.
exigir('"definirSensibilidade" ->' in principal,
       "MainActivity não expõe definirSensibilidade ao Flutter")
exigir('"sensibilidade" ->' in principal,
       "MainActivity não expõe a sensibilidade ao Flutter")
exigir('"sensibilidade" to sensibilidade' in principal,
       "diagnóstico não mostra a sensibilidade atual")
exigir('"limiar" to JarvisKwsEngine.limiarPara(sensibilidade).toDouble()'
       in principal, "diagnóstico não mostra o limiar em uso")

# 9. Proibições e privacidade continuam valendo.
for arquivo, texto in (("KwsForegroundService.kt", servico),
                       ("MainActivity.kt", principal), ("JarvisKwsEngine.java", motor)):
    exigir("GlobalScope" not in texto, f"{arquivo} usa GlobalScope")
    exigir("Runtime.getRuntime().exec" not in texto, f"{arquivo} executa shell")
for arquivo, texto in (("MainActivity.kt", principal),
                       ("JarvisEscutaFundo.kt", ler(KOTLIN / "JarvisEscutaFundo.kt"))):
    exigir("createSpeechRecognizer(" not in texto,
           f"{arquivo} usa reconhecedor que pode ir para a nuvem")
exigir("internet" not in servico.lower(), "serviço abriu caminho de rede")

# 10. Documentação do bloco.
exigir("sensibilidade" in inventario.lower(),
       "inventário não cita a sensibilidade da ativação")
exigir("Fase 14" in inventario or "ajuste 083" in inventario,
       "inventário sem a seção do ajuste 083")
if relatorio.is_file():
    texto = ler(relatorio)
    for secao in ("## 3. O que foi feito", "## 4. Evidência", "## 6. Não verificado"):
        exigir(secao in texto, f"relatório 083 sem a seção {secao}")
    for termo in ("sensibilidade", "limiar", "vigia", "aparelho"):
        exigir(termo in texto.lower(), f"relatório 083 sem {termo}")

if falhas:
    print("FALHAS no contrato da ativação mais confiável:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)
print("Contrato da ativação mais confiável: aprovado.")
