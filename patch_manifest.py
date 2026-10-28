"""Ajusta o AndroidManifest.xml gerado pelo Capacitor de forma idempotente."""
import sys
import re
from pathlib import Path

path = Path(sys.argv[1])
m = path.read_text(encoding="utf-8")
permissoes = [
    "android.permission.INTERNET", "android.permission.RECORD_AUDIO", "android.permission.MODIFY_AUDIO_SETTINGS",
    "android.permission.FOREGROUND_SERVICE", "android.permission.FOREGROUND_SERVICE_MICROPHONE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.WAKE_LOCK", "android.permission.VIBRATE",
    "android.permission.RECEIVE_BOOT_COMPLETED", "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.SCHEDULE_EXACT_ALARM", "android.permission.READ_CONTACTS",
    "android.permission.CAMERA", "android.permission.REQUEST_INSTALL_PACKAGES",
    # Bloqueio OPCIONAL do aplicativo com BiometricPrompt (não substitui o bloqueio do Android).
    "android.permission.USE_BIOMETRIC", "android.permission.USE_FINGERPRINT",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    # Chamada completada de verdade: sem CALL_PHONE o app só abre o discador.
    "android.permission.CALL_PHONE",
    # Biblioteca de música do aparelho (o player toca o arquivo, não só busca).
    "android.permission.READ_MEDIA_AUDIO",
    # Serviço de música em primeiro plano (obrigatório a partir do Android 14).
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    # Serviço de escuta sem microfone autorizado: o Android 14 recusa o tipo "microphone"
    # sem RECORD_AUDIO e o app morria com ForegroundServiceDidNotStartInTimeException.
    # Com dataSync declarado, o serviço sobe em espera e a interface pede a permissão.
    "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
]
linhas = "".join(f'    <uses-permission android:name="{p}" />\n' for p in permissoes if f'name="{p}"' not in m)
# Armazenamento antigo: só vale até o Android 12; do 13 em diante a permissão é READ_MEDIA_AUDIO.
if 'android:name="android.permission.READ_EXTERNAL_STORAGE"' not in m:
    linhas += '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />\n'
# Permissions should precede <queries> and <application>.
idx = m.find("<queries")
app_idx = m.find("<application")
insert_at = idx if idx >= 0 else app_idx
if linhas and insert_at >= 0:
    m = m[:insert_at] + linhas + m[insert_at:]

# Add missing package visibility queries even if the manifest already contains one query.
need = [
    ('android.intent.action.TTS_SERVICE', 'TTS_SERVICE'),
    ('android.speech.RecognitionService', 'RecognitionService'),
]
q_start = m.find("<queries")
q_end = m.find("</queries>", q_start) if q_start >= 0 else -1
if q_start >= 0 and q_end >= 0:
    before, block, after = m[:q_start], m[q_start:q_end], m[q_end:]
    additions = ""
    for action, _ in need:
        if action not in block:
            additions += f'        <intent>\n            <action android:name="{action}" />\n        </intent>\n'
    if additions:
        block += "\n" + additions
    m = before + block + after
else:
    additions = "".join(f'        <intent>\n            <action android:name="{action}" />\n        </intent>\n' for action, _ in need)
    q = '    <queries>\n' + additions + '    </queries>\n'
    app_idx = m.find("<application")
    if app_idx >= 0:
        m = m[:app_idx] + q + m[app_idx:]

service = ('    <service android:name=".JarvisService" android:exported="false"\n'
           '        android:foregroundServiceType="microphone|dataSync"\n'
           '        android:stopWithTask="false" />\n')
if '.JarvisService' in m:
    m = re.sub(r'(<service\b[^>]*android:name="\.JarvisService"[^>]*android:stopWithTask=")[^"]*(")', r'\g<1>false\2', m, count=1)
    # Tipo declarado: sem dataSync, o serviço não pode subir em espera quando o microfone
    # ainda não foi autorizado (SecurityException no Android 14).
    m = re.sub(r'(<service\b[^>]*android:name="\.JarvisService"[^>]*android:foregroundServiceType=")[^"]*(")',
               r'\g<1>microphone|dataSync\2', m, count=1)
if '.JarvisService' not in m:
    j = m.rindex('</application>')
    m = m[:j] + service + m[j:]
# Player de música local: serviço em primeiro plano do tipo mediaPlayback.
musica = ('    <service android:name=".JarvisMusicaService" android:exported="false"\n'
          '        android:foregroundServiceType="mediaPlayback"\n'
          '        android:stopWithTask="false" />\n')
if '.JarvisMusicaService' not in m:
    j = m.rindex('</application>')
    m = m[:j] + musica + m[j:]
receiver = '    <receiver android:name=".JarvisAlarmReceiver" android:exported="false" />\n'
if '.JarvisAlarmReceiver' not in m:
    j = m.rindex('</application>')
    m = m[:j] + receiver + m[j:]
notification_listener = ('    <service android:name=".JarvisNotificationListener" android:label="J.A.R.V.I.S. Nova" '
                        'android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" android:exported="true">\n'
                        '        <intent-filter><action android:name="android.service.notification.NotificationListenerService" /></intent-filter>\n'
                        '    </service>\n')
if '.JarvisNotificationListener' not in m:
    j = m.rindex('</application>')
    m = m[:j] + notification_listener + m[j:]
# FileProvider do atualizador: entrega o APK baixado ao instalador do Android.
#
# O template do Capacitor já declara um FileProvider com authority ".fileprovider"
# apontando para @xml/file_paths (external-path/cache-path, sem files/). Com duais
# declarações da mesma authority o Android fica com a do template e o instalador
# falha com "Failed to find configured root that contains
# /data/data/com.jarvis.nova/files/updates/jarvis-update.apk". Por isso removemos
# todo FileProvider existente e deixamos exatamente um, apontando para os nossos
# caminhos (files/updates/).
m = re.sub(r'(?s)\n?\s*<provider\b[^>]*androidx\.core\.content\.FileProvider.*?</provider>', '', m)
provider = ('    <provider android:name="androidx.core.content.FileProvider"\n'
           '        android:authorities="com.jarvis.nova.fileprovider"\n'
           '        android:exported="false" android:grantUriPermissions="true">\n'
           '        <meta-data android:name="android.support.FILE_PROVIDER_PATHS"\n'
           '            android:resource="@xml/jarvis_paths" />\n'
           '    </provider>\n')
j = m.rindex('</application>')
m = m[:j] + provider + m[j:]
# Visibilidade de pacote para abrir o instalador de APK (Android 11+).
if 'application/vnd.android.package-archive' not in m:
    q_start = m.find('<queries')
    q_end = m.find('</queries>', q_start) if q_start >= 0 else -1
    if q_start >= 0 and q_end >= 0:
        consulta_apk = ('        <intent>\n'
                        '            <action android:name="android.intent.action.VIEW" />\n'
                        '            <data android:mimeType="application/vnd.android.package-archive" />\n'
                        '        </intent>\n')
        m = m[:q_end] + consulta_apk + m[q_end:]
# Android 11+: package visibility for app shortcuts opened by voice.
q_start = m.find('<queries')
q_end = m.find('</queries>', q_start) if q_start >= 0 else -1
if q_start >= 0 and q_end >= 0:
    block = m[q_start:q_end]
    packages = ['com.jarvis.nova','com.whatsapp','com.google.android.youtube','com.spotify.music','com.instagram.android','com.google.android.apps.maps','com.google.android.gm','com.android.chrome','com.google.android.calculator','org.telegram.messenger','com.zhiliaoapp.musically','com.facebook.katana','com.discord','com.netflix.mediaclient']
    add = ''.join(f'        <package android:name="{pkg}" />\n' for pkg in packages if f'android:name="{pkg}"' not in block)
    # Android 11+: sem esta entrada o resolveActivity do instalador de APK volta nulo.
    if 'application/vnd.android.package-archive' not in block:
        add += ('        <intent>\n'
                '            <action android:name="android.intent.action.VIEW" />\n'
                '            <data android:mimeType="application/vnd.android.package-archive" />\n'
                '        </intent>\n')
    if add: m = m[:q_end] + '\n' + add + m[q_end:]
boot = ('    <receiver android:name=".JarvisBootReceiver" android:enabled="true" android:exported="false">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
        '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
        '            <action android:name="android.intent.action.TIME_SET" />\n'
        '            <action android:name="android.intent.action.TIMEZONE_CHANGED" />\n'
        '        </intent-filter>\n'
        '    </receiver>\n')
if '.JarvisBootReceiver' not in m:
    j = m.rindex('</application>')
    m = m[:j] + boot + m[j:]
# Vigia da escuta (reinicia o serviço) e ação "Ouvir agora" da notificação.
escuta_extra = ('    <receiver android:name=".JarvisWatchdog" android:enabled="true" android:exported="false">\n'
               '        <intent-filter>\n'
               '            <action android:name="com.jarvis.nova.VERIFICAR_ESCUTA" />\n'
               '        </intent-filter>\n'
               '    </receiver>\n'
               '    <receiver android:name=".JarvisOuvirReceiver" android:enabled="true" android:exported="false" />\n')
if '.JarvisWatchdog' not in m:
    j = m.rindex('</application>')
    m = m[:j] + escuta_extra + m[j:]
# Soft keyboard resize on MainActivity.
for match in list(re.finditer(r'<activity\b[^>]*>', m)):
    tag = match.group(0)
    if 'MainActivity' in tag and 'windowSoftInputMode' not in tag:
        newer = tag.replace('<activity', '<activity android:windowSoftInputMode="adjustResize"', 1)
        m = m[:match.start()] + newer + m[match.end():]
        break
# Desativar backup do Android para não copiar conversas/configurações por padrão.
m = m.replace('android:allowBackup="true"', 'android:allowBackup="false"')
app_match = re.search(r'<application\b[^>]*>', m)
if app_match and 'android:allowBackup=' not in app_match.group(0):
    tag = app_match.group(0).replace('<application', '<application android:allowBackup="false"', 1)
    m = m[:app_match.start()] + tag + m[app_match.end():]
# Nenhum endpoint do app usa HTTP: bloquear tráfego em texto puro fecha a porta para
# interceptação mesmo se algum recurso futuro tentar http://.
app_match = re.search(r'<application\b[^>]*>', m)
if app_match and 'android:usesCleartextTraffic=' not in app_match.group(0):
    tag = app_match.group(0).replace('<application', '<application android:usesCleartextTraffic="false"', 1)
    m = m[:app_match.start()] + tag + m[app_match.end():]

# Arquivo de caminhos do FileProvider do atualizador (resources do app).
try:
    res_xml = path.parent / "res" / "xml"
    res_xml.mkdir(parents=True, exist_ok=True)
    caminhos = res_xml / "jarvis_paths.xml"
    conteudo_caminhos = ('<?xml version="1.0" encoding="utf-8"?>\n'
                         '<paths xmlns:android="http://schemas.android.com/apk/res/android">\n'
                         '    <files-path name="jarvis_updates" path="updates/" />\n'
                         '</paths>\n')
    if not caminhos.exists() or caminhos.read_text(encoding="utf-8") != conteudo_caminhos:
        caminhos.write_text(conteudo_caminhos, encoding="utf-8")
        print(f"Caminhos do FileProvider do atualizador gravados: {caminhos}")
except Exception as e:
    raise SystemExit(f"Não consegui criar jarvis_paths.xml: {e}")
path.write_text(m, encoding="utf-8")

print(f'Manifesto corrigido: {path}')
