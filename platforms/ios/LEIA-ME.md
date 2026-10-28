# iOS

Não compilado nem testado neste projeto (exige macOS + Xcode). O que já está pronto:

- núcleo web compartilhado roda no `WKWebView` sem alteração;
- `plataforma.js` já detecta `ios` e expõe as capacidades reais;
- `capacitor.config.json` é o mesmo para Android e iOS.

Checklist para portar: `npx cap add ios`, microfone (`NSMicrophoneUsageDescription`), câmera
(`NSCameraUsageDescription`), voz nativa via plugin de TTS, e reescrever a escuta em segundo plano
(o iOS não permite serviço de microfone contínuo como o Android).
