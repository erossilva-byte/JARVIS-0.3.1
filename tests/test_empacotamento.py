"""Empacotamento: todo <script src> do index.html precisa existir no pacote Android e no Windows.

Regressão do release 1.42.5: o workflow copiava uma lista fixa de .js para www/ e o projetista.js
ficou de fora — o APK abria com o painel do projetista inoperante (módulo ausente).
"""
import json
import re
from pathlib import Path

raiz = Path(__file__).resolve().parents[1]
html = (raiz / 'index.html').read_text(encoding='utf-8')
scripts = re.findall(r'<script[^>]*\bsrc="([^"]+)"', html)
workflow = (raiz / '.github' / 'workflows' / 'release-apk.yml').read_text(encoding='utf-8')

copiados = set()
for linha in workflow.splitlines():
    texto = linha.strip()
    if not texto.startswith('cp ') or ' www' not in texto:
        continue
    for nome in re.findall(r'[A-Za-z0-9_./-]+\.js', texto):
        copiados.add(Path(nome).name)

faltando_www = []
for src in scripts:
    if not src.endswith('.js'):
        continue
    if src.startswith('vendor/'):
        if 'three.min.js' not in workflow:
            faltando_www.append(src)
        continue
    if Path(src).name not in copiados:
        faltando_www.append(src)

pacote = json.loads((raiz / 'package.json').read_text(encoding='utf-8'))
arquivos_windows = set(pacote.get('build', {}).get('files', []))
faltando_windows = [src for src in scripts if src.endswith('.js') and src.startswith('vendor/') is False and src not in arquivos_windows]

checks = {
    'index.html carrega o projetista': 'projetista.js' in scripts,
    'workflow Android copia todos os scripts': not faltando_www,
    'pacote Windows inclui todos os scripts': not faltando_windows,
    'projetista.js existe na raiz': (raiz / 'projetista.js').is_file(),
}
for rotulo, ok in checks.items():
    print(('OK' if ok else 'FALHOU') + ': ' + rotulo +
          ('' if ok else ' — ausente: ' + ', '.join(faltando_www or faltando_windows)))
if not all(checks.values()):
    raise SystemExit(1)
