# Limpeza e preservação — 1.33.0

## Backup antes da mudança estrutural

- `artifacts/pre-1.33.0-src.tar.gz`: fonte, configurações, testes e documentação da árvore antes desta revisão, excluindo `node_modules`, `android/`, `dist/`, `release/`, APKs e `.git`.
- Branch local anterior: `backup/1.31.2`, no commit-base `33d8c6d`.
- APK de referência preservado: `jarvis-nova-1.32.0-10320.apk` (81.144.357 bytes) e seu checksum.

## Removido

| Item | Tamanho aproximado | Justificativa |
|---|---:|---|
| APKs 1.24.0 a 1.31.2 na raiz e checksums | ~860 MB | Artefatos de build superados; regeneráveis e já publicados no histórico |
| Binários em `release/` (APKs, EXEs, ZIPs e checksums antigos) | ~1,2 GB | Artefatos de release antigos; documentos `RELEASE-*.md` foram mantidos |
| `dist/` | 276 MB | Build Electron antigo, regenerável; não é fonte |
| `android/app/build/` | 452 MB | Saída Gradle regenerável; `android/` é ignorado pelo Git |
| `__pycache__/` | pequeno | Cache Python regenerável |

O workspace caiu de aproximadamente **3,1 GB para 471 MB** após a limpeza, mantendo `node_modules` e o APK 1.32 de referência. O tamanho pode variar conforme o ambiente.

## Preservado

- Todo o código-fonte web, Java, Gradle, CI, testes e documentação.
- `android/` (estrutura nativa), inclusive o patch de manifesto e o serviço de acessibilidade.
- `node_modules/` e lockfile, para permitir a suíte e o build.
- `release/RELEASE-*.md` como histórico textual.
- APK 1.32.0 e checksum como referência verificável.
- Todos os painéis: configuração, sistema, log, tarefas, visão, informações, memória, arquivos, pessoas, dev e PC.
- HUD, plasma, órbita 3D, tela de bloqueio, personalidade, voz, memória, CAD e integrações existentes.

## Regra de rollback

1. Restaurar a fonte: `tar -xzf artifacts/pre-1.33.0-src.tar.gz`.
2. Ou usar o commit-base `33d8c6d` / branch `backup/1.31.2`.
3. O APK 1.32.0 pode ser instalado como referência. O APK 1.33.0 já foi gerado e verificado por dentro; a instalação física ainda precisa ser feita.

Nenhum arquivo de funcionalidade foi removido nesta limpeza. A única remoção de código foi a troca de um seletor CSS inválido na nova camada por um seletor válido; os painéis antigos não foram alterados.
