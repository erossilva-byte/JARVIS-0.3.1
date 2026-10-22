from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
html=(ROOT/'index.html').read_text(encoding='utf-8')
js=(ROOT/'app.js').read_text(encoding='utf-8')
checks={
  'Botões de cadastrar/comparar/apagar perfil': all(x in html for x in ['c-voz-cadastrar','c-voz-verificar','c-voz-apagar-perfil']),
  'Perfil captura microfone apenas após ação do usuário': 'navigator.mediaDevices.getUserMedia' in js and "btnVozCadastrar.onclick" in js,
  'Perfil persiste somente vetor acústico e contagem': "store.set(VOZ_PERFIL_KEY,JSON.stringify({v:vec,samples,updated:new Date().toISOString()}))" in js and "{v:vec,samples,updated:new Date().toISOString()}" in js,
  'Aviso de que não é autenticação segura': 'não é biometria profissional nem prova de identidade' in html and 'não confirma identidade' in js,
  'Usuário pode apagar o perfil': "store.set(VOZ_PERFIL_KEY,'')" in js,
}
for k,v in checks.items(): print(('OK' if v else 'FALHA')+': '+k)
if not all(checks.values()): raise SystemExit(1)
