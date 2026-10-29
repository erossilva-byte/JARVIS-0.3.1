# Camadas por plataforma — J.A.R.V.I.S. Nova 1.19.0

O projeto tem **um núcleo compartilhado** e **camadas finas por plataforma**. A regra é simples:
nada de código de dispositivo no núcleo, e nada de regra de negócio nas camadas.

```
raiz (núcleo web compartilhado)
  index.html  style.css  app.js  apps.js  hermes.js
  plataforma.js  memoria.js  orbita.js  cad.js   <- rodam em Android, iOS, desktop e navegador
platforms/
  desktop/   Electron: janela, IPC, arquivos do PC (arquivos.js), CAD do PC (cad_pc.js),
             Obsidian, captura de tela — ver platforms/WINDOWS.md
  android/   Java nativo (serviço, voz, plugins) + patches de build
  ios/       configuração do Capacitor e checklist de portabilidade
  web/       PWA (manifesto) e o que muda no navegador
```

## Por que o Java ainda mora na raiz

Os 20 arquivos `Jarvis*.java` continuam na raiz **de propósito**: o workflow de release os copia
por nome para `android/app/src/main/java/com/jarvis/nova/` e 17 testes de regressão leem esses
caminhos. Movê-los agora quebraria a verificação do build sem ganho funcional. A separação
efetiva é por camada: o que é do Android está identificado abaixo e nada mais o importa.

## Fronteiras

| Camada | Só dela | Nunca faz |
| --- | --- | --- |
| Núcleo (raiz) | interface, conversa, memória, CAD, Núcleo 3D | chamar Java, `require` de Electron, abrir arquivo do sistema |
| `plataforma.js` | detectar Android/iOS/desktop/web e expor capacidades | decidir comportamento de negócio |
| `platforms/desktop` | janela, `ipcMain`, cofre de chaves (safeStorage), pasta do usuário, Obsidian, captura de tela | avaliar comando do renderer ou abrir shell livre |
| Android (Java) | microfone em segundo plano, TTS, notificações, atualização do APK | guardar chave em texto puro |
| `platforms/ios` | configuração do Capacitor | prometer recurso que não existe |
| `platforms/web` | manifesto PWA | microfone em segundo plano |

## O que cada plataforma entrega hoje

- **Android (APK):** voz nativa e escuta em segundo plano, serviço em primeiro plano, atualizador interno, status do aparelho, notificações, câmera. CAD e memória completos. Obsidian: pacote `.md` (o app não abre pastas do Obsidian sem plugin de armazenamento).
- **Desktop (Electron):** tudo do núcleo + arquivos do PC, status do sistema, Obsidian em pasta real, captura de tela para a visão, cofre de chaves do SO. Voz usa o motor do navegador embutido.
- **Web/PWA:** núcleo completo, voz do navegador, câmera com permissão do navegador; sem segundo plano e sem arquivos locais.
- **iOS:** configuração pronta, **não compilado nem testado** — exige macOS com Xcode.

## Camada Windows

`WINDOWS.md` documenta a expansão de PC: arquitetura compartilhada, matriz por formato de
arquivo e de CAD, segurança, testes executados, pendências e como gerar o instalador NSIS.
O código de PC vive em `platforms/desktop` (motores) e em `pc.js` (interface), ambos
inertes fora do Electron.
