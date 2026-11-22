"""Pré-checagem do pacote Android antes de compilar.

O ambiente onde este projeto é editado não tem Android SDK; a compilação só acontece no CI.
Este script reduz o intervalo entre "escrevi o Java" e "o CI reprovou" verificando o que é
mecânico: classes citadas que não existem, arquivo nativo fora da lista do workflow,
dependência do WorkManager ausente, script do index.html fora do pacote, teste esquecido,
API que exige permissão de sistema usada sem revisão e permissão usada mas não declarada.

Não substitui a compilação: ele não olha tipos, assinaturas nem APIs do Android.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
falhas: list[str] = []
avisos: list[str] = []

# APIs que só funcionam com permissão de sistema (signature/privileged). Um app comum não
# consegue essa permissão: pedi-la no manifesto não concede nada e o método devolve vazio,
# -1 ou uma lista incompleta sem avisar. Foi assim que a detecção de microfone ocupado ficou
# morta até a revisão 030. Uso novo só passa se estiver registrado aqui com o motivo e o
# tratamento do retorno — a revisão é obrigatória, não um carimbo automático.
APIS_RESTRITAS = [
    {
        "api": r"\.getClientPackageName\s*\(",
        "nome": "getClientPackageName",
        "permissao": "MODIFY_AUDIO_ROUTING",
        "revisado": {
            "JarvisService.java": "só enriquece a mensagem; o bloqueio usa a sessão do AudioRecord e trata o pacote vazio",
        },
    },
    {"api": r"\.getClientUid\s*\(", "nome": "getClientUid", "permissao": "MODIFY_AUDIO_ROUTING", "revisado": {}},
    {"api": r"\.getRunningAppProcesses\s*\(", "nome": "getRunningAppProcesses", "permissao": "REAL_GET_TASKS (sistema)", "revisado": {}},
    {"api": r"\.getRunningTasks\s*\(", "nome": "getRunningTasks", "permissao": "REAL_GET_TASKS (sistema)", "revisado": {}},
    {"api": r"\.getDeviceId\s*\(", "nome": "getDeviceId", "permissao": "READ_PRIVILEGED_PHONE_STATE (sistema)", "revisado": {}},
    {"api": r"\.getImei\s*\(", "nome": "getImei", "permissao": "READ_PRIVILEGED_PHONE_STATE (sistema)", "revisado": {}},
    {"api": r"\.getSubscriberId\s*\(", "nome": "getSubscriberId", "permissao": "READ_PRIVILEGED_PHONE_STATE (sistema)", "revisado": {}},
    {"api": r"\.setMicrophoneMute\s*\(", "nome": "setMicrophoneMute", "permissao": "MODIFY_AUDIO_ROUTING", "revisado": {}},
]

# Permissões de assinatura/privilegiadas: declarar no manifesto não as concede.
PERMISSOES_DE_SISTEMA = {
    "MODIFY_AUDIO_ROUTING",
    "CAPTURE_AUDIO_HOTWORD",
    "CAPTURE_AUDIO_OUTPUT",
    "MODIFY_PHONE_STATE",
    "WRITE_SECURE_SETTINGS",
    "READ_LOGS",
    "DUMP",
    "MANAGE_APP_TOKENS",
}


def falha(msg: str) -> None:
    falhas.append(msg)


def raiz_java() -> list[Path]:
    return sorted(p for p in RAIZ.glob("*.java"))


def texto_sem_comentarios(p: Path) -> str:
    texto = p.read_text(encoding="utf-8")
    texto = re.sub(r"/\*.*?\*/", "", texto, flags=re.S)
    return re.sub(r"//[^\n]*", "", texto)


def classes_declaradas() -> dict[str, Path]:
    mapa: dict[str, Path] = {}
    for p in raiz_java():
        texto = p.read_text(encoding="utf-8")
        # Só classes de topo: classes internas (Config, Faixa, Voz...) são indentadas.
        for nome in re.findall(r"(?m)^(?:public\s+)?(?:final\s+|abstract\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)", texto):
            if nome in mapa:
                falha(f"classe {nome} declarada em {mapa[nome].name} e também em {p.name}")
            mapa[nome] = p
    return mapa


def workflows() -> list[Path]:
    return sorted((RAIZ / ".github" / "workflows").glob("*.yml"))


def verificar_classes_no_workflow(classes: dict[str, Path]) -> None:
    for w in workflows():
        texto = w.read_text(encoding="utf-8")
        if "find . -maxdepth 1 -type f -name '*.java'" not in texto:
            continue
        linha_lista = next((l for l in texto.splitlines() if "for f in " in l and "JarvisService.java" in l), None)
        if not linha_lista:
            falha(f"{w.name}: lista explícita de classes não encontrada")
            continue
        achado = re.search(r"for f in ([^;]+); do", linha_lista)
        lista = {n[:-5] for n in achado.group(1).split() if n.endswith(".java")}
        for nome in classes:
            if nome not in lista:
                falha(f"{w.name}: classe {nome} existe mas não está na lista copiada/verificada")


def verificar_referencias(classes: dict[str, Path]) -> None:
    for p in raiz_java():
        texto = p.read_text(encoding="utf-8")
        limpo = texto_sem_comentarios(p)
        for nome in sorted(set(re.findall(r"\bJarvis[A-Z][A-Za-z0-9_]*\b", limpo))):
            if nome not in classes and f"class {nome}" not in texto:
                falha(f"{p.name}: referencia {nome}, que não existe como classe no projeto")


def verificar_gradle_e_manifesto() -> None:
    gradle = (RAIZ / "patch_gradle.py").read_text(encoding="utf-8")
    if "androidx.work:work-runtime" not in gradle:
        falha("patch_gradle.py: dependência androidx.work ausente")
    if "injetar_dependencia(app_text, manutencao_dep)" not in gradle:
        falha("patch_gradle.py: dependência do WorkManager não é injetada")
    manifest = (RAIZ / "patch_manifest.py").read_text(encoding="utf-8")
    if 'foregroundServiceType="microphone|dataSync"' not in manifest:
        falha("patch_manifest.py: tipo do serviço de escuta não está definido")
    if "POST_NOTIFICATIONS" not in manifest:
        falha("patch_manifest.py: permissão de notificações ausente")
    if not (RAIZ / "JarvisManutencaoWorker.java").is_file():
        falha("JarvisManutencaoWorker.java não existe")


def verificar_pacote(classes: dict[str, Path]) -> None:
    pkg = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    arquivos = set(pkg.get("build", {}).get("files", []))
    html = (RAIZ / "index.html").read_text(encoding="utf-8")
    for src in re.findall(r'<script src="([^"]+\.js)"', html):
        if src.startswith(("http:", "https:", "vendor/")):
            continue
        if not (RAIZ / src).is_file():
            falha(f"index.html carrega {src}, que não existe")
        elif src not in arquivos:
            falha(f"{src} é carregado pela tela mas não está em package.json build.files")


def verificar_testes() -> None:
    pkg = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    suite = pkg.get("scripts", {}).get("test:all", "")
    referencias = "\n".join(q.read_text(encoding="utf-8") for q in (RAIZ / "tests").glob("*.py"))
    referencias += "\n".join(w.read_text(encoding="utf-8") for w in workflows())
    for p in sorted((RAIZ / "tests").glob("test_*.js")):
        if p.name in suite or p.name in referencias:
            continue
        falha(f"{p.name} existe mas não roda em npm run test:all nem é chamado por outro teste")


def verificar_metodos_estaticos() -> None:
    """Métodos estáticos do serviço chamados pelo plugin precisam existir no serviço."""
    servico = (RAIZ / "JarvisService.java").read_text(encoding="utf-8")
    plugin = (RAIZ / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
    chamadas = set(re.findall(r"JarvisService\.([a-zA-Z_][A-Za-z0-9_]*)", plugin))
    for nome in sorted(chamadas):
        metodo = re.search(rf"\b(?:static\s+)?[A-Za-z0-9_<>\[\]]+\s+{nome}\s*\(", servico)
        campo = re.search(rf"\bstatic\b[^;\n]*\b{nome}\b\s*=", servico)
        if not metodo and not campo:
            falha(f"plugin usa JarvisService.{nome}, que não existe no serviço")


def verificar_apis_restritas() -> None:
    """Uso de API que exige permissão de sistema precisa de revisão registrada."""
    for p in raiz_java():
        limpo = texto_sem_comentarios(p)
        for regra in APIS_RESTRITAS:
            if not re.search(regra["api"], limpo):
                continue
            motivo = regra["revisado"].get(p.name)
            if motivo:
                avisos.append(f"{p.name}: {regra['permissao']} revisado — {motivo}")
                continue
            nome = regra["nome"]
            falha(
                f"{p.name}: usa {nome}(), que exige a permissão de sistema {regra['permissao']}; "
                "o retorno vem vazio/incompleto sem ela. Registre a revisão no preflight."
            )


def verificar_permissoes() -> None:
    """Permissão usada no código precisa estar declarada; permissão de sistema não adianta pedir."""
    manifesto = texto_sem_comentarios(RAIZ / "patch_manifest.py")
    usadas: set[str] = set()
    for p in raiz_java():
        usadas |= set(re.findall(r"Manifest\.permission\.([A-Z0-9_]+)", texto_sem_comentarios(p)))
    for nome in sorted(usadas):
        if f"android.permission.{nome}" not in manifesto:
            falha(f"{p.name}: usa Manifest.permission.{nome}, mas patch_manifest.py não declara android.permission.{nome}")
    for nome in sorted(PERMISSOES_DE_SISTEMA):
        if f"android.permission.{nome}" in manifesto:
            falha(
                f"patch_manifest.py pede android.permission.{nome}, que é de sistema: "
                "declarar não concede e o código que depende dela falha em silêncio"
            )


def _fim_do_bloco(texto: str, abre: int) -> int:
    """Índice da chave que fecha o bloco aberto em `abre`."""
    nivel = 0
    for i in range(abre, len(texto)):
        if texto[i] == "{":
            nivel += 1
        elif texto[i] == "}":
            nivel -= 1
            if nivel == 0:
                return i
    return len(texto) - 1


def _fim_do_metodo(texto: str, desde: int) -> int:
    achado = re.search(r"\n    \}", texto[desde:])
    return desde + achado.start() if achado else len(texto)


# Saídas aceitáveis quando startForeground falha: encerrar, sair do primeiro plano ou
# devolver false para quem chama encerrar.
SAIDAS_DE_FALHA = ("stopSelf", "stopForeground", "pararTudo", "return false", "throw ")


def verificar_primeiro_plano() -> None:
    """startForeground dentro de try precisa de saída quando falha.

    Serviço nascido de startForegroundService() que nunca consegue promover é morto pelo
    Android com ForegroundServiceDidNotStartInTimeException. Engolir a exceção num catch
    que só registra o erro — ou tenta de novo sem saída — é o defeito que já apareceu duas
    vezes neste projeto (escuta e música).
    """
    for p in raiz_java():
        texto = texto_sem_comentarios(p)
        if "startForeground(" not in texto:
            continue
        for try_m in re.finditer(r"\btry\s*\{", texto):
            corpo_abre = try_m.end() - 1
            corpo_fim = _fim_do_bloco(texto, corpo_abre)
            if "startForeground(" not in texto[corpo_abre:corpo_fim]:
                continue
            if not texto[corpo_fim + 1:].lstrip().startswith("catch"):
                continue  # sem catch no mesmo método: quem chama trata
            abre_catch = texto.find("{", corpo_fim + 1)
            if abre_catch < 0:
                continue
            fim_catch = _fim_do_bloco(texto, abre_catch)
            trecho = texto[abre_catch:_fim_do_metodo(texto, fim_catch)]
            if not any(s in trecho for s in SAIDAS_DE_FALHA):
                falha(
                    f"{p.name}: startForeground com falha engolida e sem encerrar o serviço "
                    "(o Android mata o processo com ForegroundServiceDidNotStartInTime)"
                )


def main() -> int:
    classes = classes_declaradas()
    verificar_classes_no_workflow(classes)
    verificar_referencias(classes)
    verificar_gradle_e_manifesto()
    verificar_pacote(classes)
    verificar_testes()
    verificar_metodos_estaticos()
    verificar_apis_restritas()
    verificar_permissoes()
    verificar_primeiro_plano()

    for a in avisos:
        print(f"AVISO: {a}")
    if falhas:
        for f in falhas:
            print(f"FALHA: {f}")
        print(f"\nPré-checagem Android: {len(falhas)} problema(s).")
        return 1
    print(
        f"Pré-checagem Android: {len(classes)} classes, {len(workflows())} workflows, "
        f"{len(APIS_RESTRITAS)} APIs restritas monitoradas, tudo consistente."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
