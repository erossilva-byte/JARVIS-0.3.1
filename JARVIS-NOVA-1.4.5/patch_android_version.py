"""Aplica versionName/versionCode em um projeto Android gerado pelo Capacitor.
Uso: python3 patch_android_version.py android/app/build.gradle [VERSAO.json]
"""
import json
import re
import sys
from pathlib import Path

gradle = Path(sys.argv[1])
meta_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('VERSAO.json')
meta = json.loads(meta_path.read_text(encoding='utf-8'))
version = str(meta.get('version') or '').strip()
code = int(meta.get('versionCode') or 0)
if not re.fullmatch(r'\d+\.\d+\.\d+', version) or code < 1:
    raise SystemExit('VERSAO.json precisa de version semver e versionCode positivo')
s = gradle.read_text(encoding='utf-8')
if 'versionCode' not in s or 'versionName' not in s:
    raise SystemExit(f'Não encontrei versionCode/versionName em {gradle}')
s2 = re.sub(r'(?m)(\bversionCode\s+)\d+', rf'\g<1>{code}', s, count=1)
s2 = re.sub(r'(?m)(\bversionName\s+)["\'][^"\']*["\']', lambda m: m.group(1) + '"' + version + '"', s2, count=1)
if s2 == s:
    if re.search(rf'(?m)^\s*versionCode\s+{code}\s*$', s) and re.search(rf'(?m)^\s*versionName\s+[\"\']{re.escape(version)}[\"\']\s*$', s):
        print(f'Android version já está correta: {version} (versionCode {code})')
        raise SystemExit(0)
    raise SystemExit('Não foi possível alterar a versão; revise o formato do build.gradle')
gradle.write_text(s2, encoding='utf-8')
print(f'Android version definida: {version} (versionCode {code})')
