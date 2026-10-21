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
]
linhas = "".join(f'    <uses-permission android:name="{p}" />\n' for p in permissoes if f'name="{p}"' not in m)
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
           '        android:foregroundServiceType="microphone"\n'
           '        android:stopWithTask="false" />\n')
if '.JarvisService' in m:
    m = re.sub(r'(<service\b[^>]*android:name="\.JarvisService"[^>]*android:stopWithTask=")[^"]*(")', r'\g<1>false\2', m, count=1)
if '.JarvisService' not in m:
    j = m.rindex('</application>')
    m = m[:j] + service + m[j:]
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
# Android 11+: package visibility for app shortcuts opened by voice.
q_start = m.find('<queries')
q_end = m.find('</queries>', q_start) if q_start >= 0 else -1
if q_start >= 0 and q_end >= 0:
    block = m[q_start:q_end]
    packages = ['com.jarvis.nova','com.whatsapp','com.google.android.youtube','com.spotify.music','com.instagram.android','com.google.android.apps.maps','com.google.android.gm','com.android.chrome','com.google.android.calculator','org.telegram.messenger','com.zhiliaoapp.musically','com.facebook.katana','com.discord','com.netflix.mediaclient']
    add = ''.join(f'        <package android:name="{pkg}" />\n' for pkg in packages if f'android:name="{pkg}"' not in block)
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
path.write_text(m, encoding="utf-8")

print(f'Manifesto corrigido: {path}')
