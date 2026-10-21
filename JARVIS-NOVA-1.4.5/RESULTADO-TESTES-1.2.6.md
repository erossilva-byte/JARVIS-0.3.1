# Resultado dos testes — J.A.R.V.I.S. Nova 1.2.6

## Resultado local

- `npm run test:syntax`: aprovado.
- `python3 tests/validate_project.py`: aprovado; 139 IDs únicos, identidade `com.jarvis.nova`, versão 1.2.6.
- `python3 -m py_compile patch_manifest.py patch_visual.py patch_android_version.py patch_gradle.py`: aprovado.
- Verificação da integração openWakeWord no código e no patch Gradle: incluída no validador.

## O que estes testes não provam

Os testes estáticos não substituem compilação Gradle nem execução em aparelho. Permanecem pendentes: resolução da dependência JitPack, compilação Java/Android, instalação, permissão de microfone, detecção real de “Hey Jarvis”, falsos acionamentos, consumo de bateria, funcionamento com tela bloqueada e temperatura/armazenamento em diferentes fabricantes.

## Critério para declarar APK pronto

Só marcar como concluído quando o GitHub Actions finalizar com sucesso, o artefato `JARVIS-Nova-1.2.6-APK` existir e o APK for instalado e validado em um aparelho físico.
