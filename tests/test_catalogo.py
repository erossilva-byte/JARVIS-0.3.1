"""Catálogo de capacidades e comandos da Central de Comandos.

Verifica o contrato entre três arquivos que precisam concordar entre si:

- `vendor/catalogo_jarvis.js`  o que a interface mostra (título, estado, ação)
- `utilitarios.js`             o que os comandos marcados 'offline' realmente respondem
- `vendor/central_nova.js`     a interface que consome os dois

Uma capacidade só pode ser marcada como pronta se a ação existir. Este teste é o que
impede o catálogo de virar propaganda: ele executa cada comando declarado e exige
resposta de verdade (não apenas "assumiu o turno").
"""
import json
import re
import subprocess
from pathlib import Path

raiz = Path(__file__).resolve().parents[1]
catalogo = (raiz / "vendor" / "catalogo_jarvis.js").read_text(encoding="utf-8")
central = (raiz / "vendor" / "central_nova.js").read_text(encoding="utf-8")
utilitarios = (raiz / "utilitarios.js").read_text(encoding="utf-8")
index = (raiz / "index.html").read_text(encoding="utf-8")
pkg = json.loads((raiz / "package.json").read_text(encoding="utf-8"))

checks = {}


def ok(nome, condicao):
    checks[nome] = bool(condicao)


# --- contrato do catálogo -------------------------------------------------
ok("catálogo define os seis estados", all(
    "'%s'" % e in catalogo for e in ("pronto", "offline", "chave", "aparelho", "pc", "falta")
))
areas = re.findall(r"id: '([a-z]+)', nome:", catalogo)
ok("pelo menos doze áreas", len(areas) >= 12)
ok("ids de área únicos", len(areas) == len(set(areas)))
for area in ("ia", "voz", "visao", "android", "pc", "memoria", "produtividade",
             "pesquisa", "utilitarios", "seguranca", "dev", "interface"):
    ok("área presente: " + area, area in areas)

# todo item precisa de título, estado, descrição e uma ação coerente
itens = re.findall(r"\{ t: '([^']*)', e: '([a-z]+)', d: '([^']*)'(.*?)\}", catalogo)
ok("mais de cem capacidades declaradas", len(itens) >= 100)
for titulo, estado, descricao, resto in itens:
    ok("estado válido em " + titulo, estado in ("pronto", "offline", "chave", "aparelho", "pc", "falta"))
    ok("descrição em " + titulo, len(descricao) > 5)
    tem_acao = any(chave in resto for chave in ("p: '", "c: '", "a: '"))
    if estado == "falta":
        ok("item sem ação declara o motivo: " + titulo, "n: '" in resto)
    else:
        ok("item disponível tem ação real: " + titulo, tem_acao)

# --- integrações declaradas existem de verdade ----------------------------
paineis_declarados = set(re.findall(r"p: '([a-z]+)'", catalogo))
for painel in sorted(paineis_declarados):
    ok("painel %s navegável no app" % painel, ('data-lat="%s"' % painel) in index)

acoes_declaradas = set(re.findall(r"a: '([a-z]+)'", catalogo))
ok("ações de interface conhecidas", acoes_declaradas.issubset({"deck", "parar", "log", "config"}))
ok("botão Parar existe", 'id="btn-parar"' in index)
ok("botão de registro existe", 'id="btn-log"' in index)
ok("botão de ajustes existe", 'id="btn-config"' in index)

# --- os comandos do catálogo respondem no módulo de utilitários -----------
comandos = re.findall(r"c: '([^']*)'", catalogo)
ok("dez ou mais comandos locais", len(comandos) >= 10)
probe = """
const U = require('./utilitarios.js');
const lista = %s;
(async () => {
  const falhas = [];
  for (const cmd of lista) {
    const falas = [];
    let assumiu = false;
    try {
      assumiu = await U.comando(cmd, { falar: async (t) => falas.push(t), rnd: () => 0.42 });
    } catch (e) {
      falhas.push(cmd + ' (erro: ' + e.message + ')');
      continue;
    }
    if (assumiu !== true || !falas.length) falhas.push(cmd + ' (não respondeu)');
  }
  if (falhas.length) { console.error('FALHAS:\\n - ' + falhas.join('\\n - ')); process.exit(1); }
  console.log('comandos do catálogo respondem: ' + lista.length);
})();
""" % json.dumps(comandos, ensure_ascii=False)
resultado = subprocess.run(["node", "-e", probe], cwd=str(raiz), capture_output=True, text=True)
ok("todos os comandos do catálogo respondem no utilitarios.js", resultado.returncode == 0)
if resultado.returncode != 0:
    print(resultado.stdout)
    print(resultado.stderr)

# --- a interface está escrita para as duas plataformas --------------------
ok("central trata celular e computador", "(max-width:899px)" in central and "(min-width:900px)" in central)
ok("central tem atalho de teclado", "e.key === 'k'" in central and "metaKey" in central)
ok("central respeita movimento reduzido", "prefers-reduced-motion" in central)
ok("central usa área segura do aparelho", "env(safe-area-inset-bottom)" in central)
ok("central não injeta dados do catálogo como HTML",
   "innerHTML = item" not in central and "${" not in central)
ok("central escreve texto com textContent", central.count("textContent") >= 5)
ok("central reaproveita o resolvedor existente", "comandoLocal" in central)
ok("central abre painéis existentes", 'data-lat="' in central)

# --- os dois arquivos entram nos pacotes ---------------------------------
arquivos_build = pkg.get("build", {}).get("files", [])
ok("pacote do PC inclui a pasta vendor", "vendor/**/*" in arquivos_build)
for arquivo in ("vendor/catalogo_jarvis.js", "vendor/central_nova.js", "utilitarios.js"):
    ok("módulo existe no projeto: " + arquivo, (raiz / arquivo).exists())

workflows = list((raiz / ".github" / "workflows").glob("*.yml"))
texto_wf = "\n".join(w.read_text(encoding="utf-8") for w in workflows)
ok("publicação copia todos os módulos js", "cp *.js www/" in texto_wf)
ok("publicação copia a pasta vendor", "cp vendor/*.js www/vendor/" in texto_wf)

# --- o módulo é carregado sem editar o index.html ------------------------
plataforma = (raiz / "plataforma.js").read_text(encoding="utf-8")
ok("carga da central é tolerante e sem CDN",
   "vendor/catalogo_jarvis.js" in plataforma and "vendor/central_nova.js" in plataforma)
ok("utilitarios não é recarregado pela central", "utilitarios.js" not in central)

# --- relatório -----------------------------------------------------------
falhas = [nome for nome, valor in checks.items() if not valor]
for nome, valor in checks.items():
    print(("OK" if valor else "FALHOU") + ": " + nome)
print()
if falhas:
    print("%d verificação(ões) falharam." % len(falhas))
    raise SystemExit(1)
print("test_catalogo: %d verificações aprovadas (%d capacidades, %d áreas, %d comandos)"
      % (len(checks), len(itens), len(areas), len(comandos)))
