# Web / PWA

O núcleo roda no navegador. Diferenças reais:

- sem escuta em segundo plano e sem atualizador de APK;
- voz pelo motor do navegador (`speechSynthesis`), com as mesmas preferências salvas;
- câmera só com HTTPS e permissão explícita;
- memória e CAD ficam no `localStorage` do navegador (mesmos limites do app).

Para publicar como PWA, basta servir a raiz do projeto com HTTPS; o manifesto fica aqui.
