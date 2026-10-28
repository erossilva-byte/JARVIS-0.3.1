const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('jarvisNative', {
  platform: process.platform,
  run: (nome, args) => ipcRenderer.invoke('jarvis:run', nome, args)
});
