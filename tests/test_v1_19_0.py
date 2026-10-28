"""Verificações da 1.19.0 — CAD de intercâmbio, visão com sessão, Obsidian e camadas por plataforma.

O teste não confia no próprio gerador: o Node escreve os arquivos e o Python os lê com
bibliotecas diferentes (struct, zipfile, ElementTree) para conferir contagem de triângulos,
contêiner ZIP do 3MF e estrutura dos formatos ISO-10303-21.
"""
import json
import re
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree

raiz = Path(__file__).resolve().parent.parent
html = (raiz / "index.html").read_text(encoding="utf-8")
app = (raiz / "app.js").read_text(encoding="utf-8")
cad = (raiz / "cad.js").read_text(encoding="utf-8")
mem = (raiz / "memoria.js").read_text(encoding="utf-8")
css = (raiz / "style.css").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))
docs = (raiz / "CHANGELOG.md").read_text(encoding="utf-8") + (raiz / "LEIA-ME.md").read_text(encoding="utf-8")
suite = pacote.get("scripts", {}).get("test:all", "")
release_wf = (raiz / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
build_wf = (raiz / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
desktop = (raiz / "platforms/desktop/main.js").read_text(encoding="utf-8")
preload = (raiz / "platforms/desktop/preload.js").read_text(encoding="utf-8")

tmp = Path(tempfile.mkdtemp(prefix="jvcad19-"))
geracao = subprocess.run(
    ["node", str(raiz / "tests/test_cad_formatos.js"), str(tmp)],
    capture_output=True, text=True, timeout=180,
)
if geracao.returncode != 0:
    print("FALHA: a bateria Node do CAD não passou.\n" + (geracao.stderr or "")[-2000:] + (geracao.stdout or "")[-3000:])
    sys.exit(1)
dados = json.loads(geracao.stdout.strip().splitlines()[-1])

# ---------- leitura independente dos arquivos gerados ----------
stl = (tmp / dados["gerados"]["stl"]["nome"]).read_bytes()
tri_stl = struct.unpack("<I", stl[80:84])[0]
tree_stl = (len(stl) - 84) // 50

z = zipfile.ZipFile(tmp / dados["gerados"]["3mf"]["nome"])
nomes_zip = z.namelist()
modelo = z.read("3D/3dmodel.model").decode("utf-8")
ElementTree.fromstring(modelo)  # XML bem formado
tri_3mf = len(re.findall(r"<triangle\s", modelo))
vert_3mf = len(re.findall(r"<vertex\s", modelo))
metodos = {i.compress_type for i in z.infolist()}

dxf = (tmp / dados["gerados"]["dxf"]["nome"]).read_text(encoding="utf-8")
step = (tmp / dados["gerados"]["step"]["nome"]).read_text(encoding="utf-8")
ifc = (tmp / dados["gerados"]["ifc"]["nome"]).read_text(encoding="utf-8")
ascii_stl = (tmp / "peca-teste-ascii.stl").read_text(encoding="utf-8")

checks = {
    # 1. O que o próprio gerador já confere
    "Bateria Node do CAD sem erros": dados["ok"] is True,
    "Volumes dentro da tolerância de tesselação": (
        abs(dados["volumes"]["caixa"] - 120000) < 1
        and abs(dados["volumes"]["cilindro"] - 8042.48) / 8042.48 < 0.03
        and abs(dados["volumes"]["esfera"] - 7238.23) / 7238.23 < 0.04
        and abs(dados["volumes"]["cone"] - 3141.59) / 3141.59 < 0.03),

    # 2. STL binário lido com struct (implementação independente)
    "STL binário com cabeçalho de contagem correto": tri_stl == tree_stl and tri_stl > 0,
    "STL binário com o mesmo número de triângulos do .cad": tri_stl == dados["leitura"]["stl"]["triangulos"],
    "STL ASCII com facetas e o mesmo sólido": ascii_stl.count("facet normal") == tri_stl and ascii_stl.startswith("solid "),

    # 3. 3MF é um contêiner OPC válido
    "3MF com [Content_Types].xml, .rels e modelo": (
        "[Content_Types].xml" in nomes_zip and "_rels/.rels" in nomes_zip and "3D/3dmodel.model" in nomes_zip),
    "3MF com XML de modelo bem formado e triângulos": tri_3mf > 0 and tri_3mf == tri_stl,
    "3MF sem compressão (leitura garantida em qualquer ambiente)": metodos == {zipfile.ZIP_STORED},
    "3MF declara milímetros": 'unit="millimeter"' in modelo,
    "3MF com os vértices batendo com os triângulos": vert_3mf == dados["leitura"]["3mf"]["vertices"],

    # 4. DXF R12 desenhável
    "DXF é R12 com tabela de camadas e faces 3D": (
        "AC1009" in dxf and "LAYER" in dxf and "3DFACE" in dxf and "EOF" in dxf.rstrip()),
    "DXF tem uma face por triângulo": dxf.count("3DFACE") == tri_stl,
    "DXF traz a planta em POLYLINE fechada": "POLYLINE" in dxf and "VERTEX" in dxf,

    # 5. STEP AP203 com B-rep fechado e referências íntegras
    "STEP com cabeçalho ISO-10303-21 e schema AP203": (
        step.startswith("ISO-10303-21;") and "AUTOMOTIVE_DESIGN" in step and step.rstrip().endswith("END-ISO-10303-21;")),
    "STEP com MANIFOLD_SOLID_BREP e CLOSED_SHELL": "MANIFOLD_SOLID_BREP" in step and "CLOSED_SHELL" in step,
    "STEP sem referência quebrada": dados["leitura"]["step"]["quebradas"] == 0,
    "STEP com uma ADVANCED_FACE por triângulo": step.count("ADVANCED_FACE") == tri_stl,

    # 6. IFC4 com hierarquia espacial e elementos
    "IFC com FILE_SCHEMA IFC4 e DATA": "FILE_SCHEMA(('IFC4'))" in ifc and "\nDATA;" in ifc,
    "IFC com projeto, sítio, edifício e pavimento": all(
        t in ifc for t in ("IFCPROJECT", "IFCSITE", "IFCBUILDING(", "IFCBUILDINGSTOREY")),
    "IFC com quatro elementos e vínculo espacial": (
        ifc.count("IFCBUILDINGELEMENTPROXY") == 4 and "IFCRELCONTAINEDINSPATIALSTRUCTURE" in ifc),
    "IFC com unidades e geometria extrudada": (
        "IFCUNITASSIGNMENT" in ifc and "IFCEXTRUDEDAREASOLID" in ifc and "IFCRECTANGLEPROFILEDEF" in ifc),

    # 7. Formatos proprietários recusados com motivo
    "DWG/RVT/RFA/FCStd recusados com explicação": all(
        dados["recusados"][f] != "ACEITOU" and len(dados["recusados"][f]) > 20 for f in ("dwg", "rvt", "rfa", "fcstd")),
    "Formato inventado recusado": dados["recusados"]["xyz"] != "ACEITOU",
    "Matriz de formatos publicada no módulo": (
        "FORMATOS" in cad and cad.count("id: 'dxf'") == 1 and "não é gerado aqui" in cad),

    # 8. Interface da visão e do CAD
    "Painel de visão com sessão, câmera e tela": all(
        i in html for i in ('id="visao-sessao-iniciar"', 'id="visao-sessao-pausar"', 'id="visao-sessao-parar"',
                            'id="visao-frequencia"', 'id="visao-camera-virar"', 'id="visao-tela-capturar"',
                            'id="visao-salvar-memoria"', 'id="visao-tela"')),
    "Sessão de visão implementada com frequência e pausa": (
        "async function vsIniciar" in app and "setInterval(" in app and "function vsPausar" in app
        and "function vsEncerrar" in app and "visaoSessao.ativa" in app),
    "Câmera alterna frontal/traseira de verdade": (
        "let visaoFacing = 'environment'" in app and "facingMode: visaoFacing" in app
        and "async function vsVirar" in app),
    "Sessão termina ao sair da tela": (
        "document.hidden && visaoSessao.ativa" in app and "vsEncerrar(" in app),
    "Captura de tela do PC passa pela ponte do desktop": (
        "capturar_tela" in app and "capturar_tela" in desktop and "desktopCapturer" in desktop),
    "Resumo visual pode ir para a memória": "function vsMemoria" in app and "MEM.criar(" in app,
    "Painel de arquivos exporta os formatos": all(
        i in html for i in ('id="cad-formato"', 'id="cad-exportar"', 'id="cad-malha"', 'id="cad-exportar-status"')),
    "Exportação usa o módulo CAD e reporta perdas": (
        "async function cadExportar" in app and "CAD.exportar(" in app and "perdas" in app),
    "Leitura de arquivo externo detecta o formato": (
        "async function analisarArquivoFormato" in app and "CAD.analisarFormato(" in app),

    # 9. Obsidian
    "Bloco Obsidian no painel de memória": all(
        i in html for i in ('id="obs-caminho"', 'id="obs-testar"', 'id="obs-enviar"', 'id="obs-receber"',
                            'id="obs-baixar"', 'id="obs-importar"')),
    "Memória exporta Markdown com frontmatter e um arquivo por nota": (
        "function arquivosMarkdown" in mem and "function notaMd" in mem and "tema: ' + n.tema" in mem
        and "arquivosMarkdown: arquivosMarkdown" in mem),
    "Memória importa Markdown sem duplicar": (
        "function importarMarkdown" in mem and "importarMarkdown: importarMarkdown" in mem),
    "Ponte do desktop valida o cofre e não apaga nada": (
        "vault_status" in desktop and "vault_sync" in desktop and "vault_ler" in desktop
        and "trashItem" not in desktop.split("vault_sync")[1][:2000]),
    "Aplicativo explica o limite do Android": (
        "SAF" in html and "não embarca" in html and "Baixar .md" in html),

    # 10. Organização por plataforma
    "Desktop saiu da raiz para platforms/desktop": (
        not (raiz / "main.js").exists() and not (raiz / "preload.js").exists()
        and (raiz / "platforms/desktop/main.js").exists() and (raiz / "platforms/desktop/preload.js").exists()),
    "package.json aponta para o novo entrypoint": pacote.get("main") == "platforms/desktop/main.js",
    "electron-builder empacota as duas camadas": (
        "platforms/desktop/main.js" in pacote.get("build", {}).get("files", [])
        and "index.html" in pacote.get("build", {}).get("files", [])),
    "Desktop resolve o núcleo web pela raiz": "path.resolve(__dirname, '..', '..')" in desktop,
    "Preload continua sem acesso a Node no renderer": "contextBridge" in preload and "nodeIntegration" not in preload,
    "Fronteiras documentadas em platforms/LEIA-ME.md": (
        (raiz / "platforms/LEIA-ME.md").exists()
        and "android" in (raiz / "platforms/LEIA-ME.md").read_text(encoding="utf-8").lower()),

    # 11. Versão, documentação e suíte
    "Versão 1.19.0 com versionCode 10190": (
        [int(x) for x in versao.get("version", "0").split(".")] >= [1, 19, 0] and versao.get("versionCode", 0) >= 10190
        and pacote.get("version") == versao.get("version") and ("const VERSAO_APP = '%s';" % versao.get("version")) in app),
    "Interface mostra a versão nova": (
        ('<span class="versao-chip">v%s</span>' % versao.get("version")) in html
        and ('<span class="orb-sub" aria-hidden="true">v%s</span>' % versao.get("version")) in html),
    "Workflows citam a versão corrente": versao.get("version") in build_wf and versao.get("version") in release_wf,
    "CHANGELOG e LEIA-ME registram a versão": ("## %s" % versao["version"]) in docs and ("# J.A.R.V.I.S. Nova %s" % versao["version"]) in docs,
    "Suíte roda o teste novo": (
        "python3 tests/test_v1_19_0.py" in suite and "node --check cad.js" in suite
        and "node tests/test_memoria_md.js" in suite),
    # 12. A aba Visão precisa existir em TODO lugar que abre as outras abas
    "Visão tem aba na barra lateral, ícone no cabeçalho e atalho no painel": (
        'data-lat="visao"' in html and 'id="btn-visao"' in html and 'id="dash-visao"' in html),
    "Ícone do cabeçalho é do mesmo tipo de Tarefas/Configurações": (
        re.search(r'<button id="btn-visao" class="icone"[^>]*>', html) is not None
        and 'aria-label="Abrir a visão"' in html),
    "As três entradas chamam abrirVisao()": (
        "btnVisaoTopo.onclick = () => abrirVisao()" in app
        and "cardVisao.onclick = () => abrirVisao()" in app
        and "if (alvo === 'visao') { abrirVisao(); return; }" in app),
    "Abrir a Visão marca a aba lateral ativa": (
        "x.dataset.lat === 'visao'" in app and "function abrirVisao()" in app),
    "Barra lateral só aparece em tela larga (por isso o ícone e o atalho)": (
        "@media(min-width:960px){#lateral{display:flex}" in css),
}

falhas = [nome for nome, ok in checks.items() if not ok]
for nome, ok in checks.items():
    print(("OK: " if ok else "FALHA: ") + nome)
print()
print("Arquivos gerados em %s: %s" % (tmp.name, ", ".join(sorted(p.name for p in tmp.iterdir()))))
if falhas:
    print("\n%d verificação(ões) da 1.19.0 falharam." % len(falhas))
    if not dados["ok"]:
        print("Erros do gerador: " + "; ".join(dados["erros"]))
    sys.exit(1)
print("%d verificações da 1.19.0 aprovadas." % len(checks))
