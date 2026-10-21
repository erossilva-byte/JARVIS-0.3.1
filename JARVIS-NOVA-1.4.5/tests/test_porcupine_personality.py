"""Checks regression markers for wake-word engine selection and personality preferences."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / 'app.js').read_text(encoding='utf-8')
native = (ROOT / 'JarvisBackgroundPlugin.java').read_text(encoding='utf-8')
gradle = (ROOT / 'patch_gradle.py').read_text(encoding='utf-8')
assert 'accessKey: CHAVE_PICOVOICE' in app, 'AccessKey não é passada ao plugin ao ativar escuta'
assert 'Porcupine.BuiltInKeyword.JARVIS' in native, 'Porcupine não seleciona a palavra Jarvis'
assert 'setAccessKey(porcupineAccessKey)' in native, 'Porcupine não recebe AccessKey'
assert 'OpenWakeWord' not in native, 'Dependência openWakeWord não resolvida ainda referenciada'
assert 'AccessKey Picovoice ausente' in native, 'Falha sem AccessKey não é explicada ao usuário'
assert 'ai.picovoice:porcupine-android:4.0.2' in gradle, 'Dependência Porcupine ausente'
assert "store.set('humor'" in app and "store.set('estilo_resposta'" in app, 'Preferências de humor/estilo não são persistidas'
assert 'const humor = Math.max(0, Math.min(100, Number(store.get(\'humor\', \'40\'))))' in app, 'Prompt não lê o nível de humor salvo'
assert "const estilo = store.get('estilo_resposta', 'equilibrado')" in app, 'Prompt não lê o estilo salvo'
print('Porcupine, tratamento sem AccessKey e persistência de humor/estilo validados estaticamente.')
