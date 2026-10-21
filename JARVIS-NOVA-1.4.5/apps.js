// Lista de apps que o Jarvis pode abrir. Adicione os seus.
// win/mac/linux: protocolo (spotify:), URL ou nome de executável.
// android: esquema de URL do app (precisa estar instalado).
const APPS = {
  spotify:   { win: 'spotify:',  mac: 'spotify:',  linux: 'spotify:',  android: 'spotify:' },
  whatsapp:  { win: 'whatsapp:', mac: 'whatsapp:', linux: 'https://web.whatsapp.com', android: 'whatsapp://send' },
  youtube:   { win: 'https://www.youtube.com', mac: 'https://www.youtube.com', linux: 'https://www.youtube.com', android: 'vnd.youtube://' },
  navegador: { win: 'https://www.google.com', mac: 'https://www.google.com', linux: 'https://www.google.com', android: 'https://www.google.com' },
  calculadora: { win: 'calculator:', mac: '', linux: 'gnome-calculator', android: '' },
  bloco_de_notas: { win: 'notepad.exe', mac: '', linux: 'gedit', android: '' },
  explorador: { win: 'explorer.exe', mac: '', linux: 'nautilus', android: '' },
  maps:      { win: 'https://maps.google.com', mac: 'https://maps.google.com', linux: 'https://maps.google.com', android: 'geo:0,0' },
  instagram: { win: 'https://www.instagram.com', mac: 'https://www.instagram.com', linux: 'https://www.instagram.com', android: 'instagram://app' },
  telegram: { win: 'https://web.telegram.org', mac: 'https://web.telegram.org', linux: 'https://web.telegram.org', android: 'tg://resolve?domain=' },
  tiktok: { win: 'https://www.tiktok.com', mac: 'https://www.tiktok.com', linux: 'https://www.tiktok.com', android: 'snssdk1233://' },
  facebook: { win: 'https://www.facebook.com', mac: 'https://www.facebook.com', linux: 'https://www.facebook.com', android: 'fb://facewebmodal/f?href=https://www.facebook.com' },
  discord: { win: 'https://discord.com/app', mac: 'https://discord.com/app', linux: 'https://discord.com/app', android: 'discord://' },
  netflix: { win: 'https://www.netflix.com', mac: 'https://www.netflix.com', linux: 'https://www.netflix.com', android: 'https://www.netflix.com' },
  camera: { win: '', mac: '', linux: '', android: 'camera:' }
};
if (typeof module !== 'undefined' && module.exports) module.exports = APPS;
else window.APPS = APPS;
