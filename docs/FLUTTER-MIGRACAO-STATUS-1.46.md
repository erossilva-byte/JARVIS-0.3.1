# Flutter nativo — etapa inicial 1.46+

## Workspace
A interface Flutter vive em `flutter_app/` de propósito. O Android legado do Capacitor/Electron permanece isolado enquanto os serviços nativos são migrados e testados; não executar `flutter create` na raiz, pois isso poderia sobrescrever a plataforma Android existente.

## Implementado nesta etapa
- Aplicativo Flutter com tema escuro tecnológico.
- Núcleo circular animado por CustomPainter e AnimationController.
- Resposta ao toque no núcleo.
- Navegação animada entre Núcleo e Sistemas.
- Catálogo inicial de 21 módulos, agrupados por domínio.
- Tela individual de módulo que distingue catálogo de integração funcional.
- Teste de widget para inicialização e navegação.
- Workflow separado para analyze, testes e build APK/Windows.

## Limitações explícitas
- O núcleo é uma primeira implementação 2D vetorial animada; ainda não é uma cena 3D real.
- O catálogo não significa que os serviços já estejam conectados à interface Flutter.
- A tela Flutter de credenciais ainda não está ligada ao cofre Android/Windows.
- O shell antigo ainda não foi removido nem substituído no APK principal.
- O workflow gera runners nativos temporariamente no CI; a integração permanente das pastas de plataforma e dos canais nativos ainda está pendente.

## Próximas etapas
1. Executar e corrigir o workflow Flutter.
2. Criar adaptadores versionados para cofre seguro, voz/KWS, Hermes/Core e estado do dispositivo.
3. Migrar as telas de configurações e salvar/remover/testar chaves sem expor segredos.
4. Migrar módulo por módulo com testes de contrato e integração.
5. Comparar inventário de recursos do código com o catálogo e eliminar recursos sem implementação comprovada.
6. Somente depois trocar o ponto de entrada do APK e remover a interface antiga.
