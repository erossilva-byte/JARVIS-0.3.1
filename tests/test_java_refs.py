"""Confere que as chamadas entre as classes Java nativas existem de verdade.

Motivo: nem a suíte estática nem o `node --check` compilam Java, e o APK só é
compilado no CI. Na 1.13.0 a revisão removeu `JarvisPrefs.pedidoOuvir` junto com o
cofre de chaves antigo, mas o plug-in e o receptor continuaram chamando — o CI
descobriu isso só na compilação, já com o release pendurado. Esta checagem roda em
segundos e pega esse tipo de quebra antes do envio.

Ela é deliberadamente conservadora: compara apenas chamadas `Classe.metodo(` em que
`Classe` é uma das classes nativas conhecidas, e conta como definido qualquer método
(estático ou não) declarado naquela classe.
"""
import re
import sys
from pathlib import Path

raiz = Path(__file__).resolve().parents[1]
fontes = {p.stem: p.read_text(encoding="utf-8") for p in sorted(raiz.glob("*.java"))}

# Interfaces e tipos aninhados que aparecem como `Classe.Tipo` na criação de objetos.
ANINHADOS = {"Ouvinte", "Config", "Callback", "Listener"}


def metodos_de(texto):
    nomes = set()
    for m in re.finditer(r"^\s*(?:public|private|protected|static|final|synchronized|abstract|native|\s)*"
                         r"[\w<>\[\],\.\?\s]+\s+(\w+)\s*\(", texto, re.MULTILINE):
        nomes.add(m.group(1))
    return nomes


definidos = {classe: metodos_de(texto) for classe, texto in fontes.items()}
quebradas = set()

for classe, texto in fontes.items():
    for m in re.finditer(r"\b(Jarvis\w+|MainActivity)\.(\w+)\s*\(", texto):
        alvo, metodo = m.group(1), m.group(2)
        if alvo not in definidos or metodo in ANINHADOS:
            continue
        if metodo not in definidos[alvo]:
            quebradas.add(f"{classe}.java chama {alvo}.{metodo}(), que não existe em {alvo}.java")

# Toda classe nativa precisa estar na lista obrigatória dos dois workflows, senão o
# build falha por falta de arquivo (ou, pior, compila sem a classe nova).
for wf in (".github/workflows/build-apk.yml", ".github/workflows/release-apk.yml"):
    texto = (raiz / wf).read_text(encoding="utf-8")
    for classe in fontes:
        if f"{classe}.java " not in texto and f"{classe}.java;" not in texto:
            quebradas.add(f"{wf} não exige {classe}.java no conjunto de recursos nativos")

for item in sorted(quebradas):
    print("FALHA: " + item)
if quebradas:
    print("\n%d referência(s) nativa(s) quebrada(s)." % len(quebradas))
    sys.exit(1)
print("Referências entre as %d classes nativas conferidas: nenhuma chamada órfã." % len(fontes))
