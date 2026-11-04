"""Contrato estático da tela de bloqueio (NFC, biometria, PBKDF2 e central em Ajustes).

Não substitui teste em aparelho: verifica que o caminho real existe, que o UID bruto não é
persistido e que nenhuma opção da interface ficou sem ligação.
"""
from pathlib import Path

raiz = Path(__file__).resolve().parents[1]
app = (raiz / 'app.js').read_text(encoding='utf-8')
html = (raiz / 'index.html').read_text(encoding='utf-8')
css = (raiz / 'style.css').read_text(encoding='utf-8')
nucleo = (raiz / 'seguranca.js').read_text(encoding='utf-8')
java = (raiz / 'android/app/src/main/java/com/jarvis/nova/JarvisSeguranca.java').read_text(encoding='utf-8')
manifesto = (raiz / 'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
patch_manifest = (raiz / 'patch_manifest.py').read_text(encoding='utf-8')
main = (raiz / 'android/app/src/main/java/com/jarvis/nova/MainActivity.java').read_text(encoding='utf-8')
release = (raiz / '.github/workflows/release-apk.yml').read_text(encoding='utf-8')
build = (raiz / '.github/workflows/build-apk.yml').read_text(encoding='utf-8')
pacote = (raiz / 'package.json').read_text(encoding='utf-8')
doc = (raiz / 'docs/SEGURANCA-1.42.9.md').read_text(encoding='utf-8')

checagens = {
    'NFC declarado no manifesto': 'android.permission.NFC' in manifesto,
    'NFC opcional (não exclui aparelhos sem leitor)': 'android.hardware.nfc" android:required="false"' in manifesto,
    'patch_manifest mantém a permissão': 'android.permission.NFC' in patch_manifest,
    'Plugin registrado no app': 'registerPlugin(JarvisSeguranca.class)' in main,
    'Leitura por reader mode': 'enableReaderMode' in java and 'disableReaderMode' in java,
    'Leitura encerrada na pausa': 'handleOnPause' in java and 'encerrarLeitura' in java,
    'Tecnologias ISO-DEP sinalizadas': 'IsoDep' in java and '"criptografica"' in java,
    'Biometria forte (sem câmera comum)': 'BIOMETRIC_STRONG' in java and 'CAMERA' not in java,
    'Credencial do aparelho como recuperação': 'DEVICE_CREDENTIAL' in java,
    'Hardware facial consultado': 'FEATURE_FACE' in java and 'FEATURE_FINGERPRINT' in java,
    'Falha biométrica não resolve como sucesso': 'onAuthenticationFailed' in java and 'compareAndSet(false, true)' in java,
    'PIN com PBKDF2 e sal': "PBKDF2" in app and "store.get('pin_salt'" in app and '120000' in app,
    'Nunca grava o PIN em texto puro': "store.set('pin_hash', pin)" not in app,
    'Hash antigo migra sem trancar': 'hashPinLegado' in app and 'store.set(\'pin_hash\', forte)' in app,
    'UID guardado como hash': 'hashUid' in app and 'uidHash' in nucleo and 'SEGN.mascararUid' in app,
    'Tag desconhecida não libera': "Tag desconhecida" in nucleo and "acharTag" in app,
    'Modos combinados no núcleo': "'bio+nfc'" in nucleo and "'bio|nfc'" in nucleo and "'nfc+pin'" in nucleo,
    'Central: modo, tempo e tentativas': all(i in html for i in ('id="c-bloq-modo"', 'id="c-bloq-timeout"', 'id="c-bloq-max"')),
    'Central: tags e histórico': all(i in html for i in ('id="c-nfc-cadastrar"', 'id="c-nfc-lista"', 'id="c-bloq-historico"', 'id="c-bloq-restaurar"')),
    'Tela: método, fase e NFC': all(i in html for i in ('id="bloq-metodo"', 'id="bloq-fase"', 'id="bloqueio-nfc"')),
    'Operação sensível pede prova': 'autorizarSensivel' in app and 'cadastrarTagNfc' in app,
    'Autobloqueio usa o tempo configurado': 'cfg.timeoutSeg' in app and 'limiteMs' in app,
    'Histórico sem segredo': 'seguranca_eventos' in app and 'SEGN.historico' in app,
    'Visual dos estados no CSS': '.bloq-nucleo.lendo-nfc' in css and '.bloq-nucleo.confirmado' in css and '.bloq-nucleo.negado' in css,
    'Módulo no APK e no pacote Windows': 'seguranca.js' in release and 'seguranca.js' in build and '"seguranca.js"' in pacote,
    'Suíte inclui os testes novos': 'tests/test_seguranca.js' in pacote and 'tests/test_seguranca_android.py' in pacote,
    'Documento de auditoria': 'Não testado' in doc and 'clonável' in doc,
}

falhas = [n for n, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(('OK: ' if ok else 'FALHA: ') + nome)
if falhas:
    print('\n%d verificação(ões) da segurança falharam.' % len(falhas))
    raise SystemExit(1)
print('\nSegurança Android: %d verificações aprovadas.' % len(checagens))
