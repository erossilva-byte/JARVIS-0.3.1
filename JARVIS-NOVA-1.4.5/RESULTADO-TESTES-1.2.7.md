# Resultado dos testes — J.A.R.V.I.S. Nova 1.2.7

Data: 2026-10-16

## Aprovado neste ambiente
- `npm run test:syntax`: sintaxe de `app.js`, `main.js`, `apps.js` e testes de rotas de voz WhatsApp aprovados.
- `python3 tests/validate_project.py`: aprovado; 142 IDs únicos, identidade `com.jarvis.nova`, versão 1.2.7.
- `python3 tests/test_release_readiness.py`: aprovado; workflow, rótulos da wake word e salvamento seguro de chaves verificados.
- Patch de versão executado duas vezes em Gradle de teste sem falhar; patch de manifesto gerou XML válido e não duplicou componentes.
- Corrigido o escape do comando `find -exec` do workflow antes da entrega ao novo repositório.
- `python3 -m py_compile patch_manifest.py patch_visual.py patch_android_version.py patch_gradle.py`: aprovado.
- Teste de roteamento de comandos: abrir conversa, chamada de voz/vídeo e preparar áudio encaminham para abrir o chat; o envio/chamada não é realizado silenciosamente.
- Arquivo ZIP final: integridade confirmada com `unzip -t`.

## Build confirmado; validações físicas pendentes
- Compilação Gradle real e APK debug foram concluídos no GitHub Actions (execução #3, run ID `38973408843`). O artefato `JARVIS-Nova-1.2.7-APK` contém `app-debug.apk`; SHA-256: `bcec4f65593abd9a5084610e30cbb1b370c018c9946f7e9e2126334b54f4925f`.
- Instalação, permissões e compatibilidade no dispositivo Android-alvo.
- Falsos acionamentos, taxa de detecção e consumo de bateria do openWakeWord.
- Chaves e cotas reais dos provedores, notificações, WhatsApp e ações em segundo plano.

**Conclusão atualizada:** testes estáticos aprovados e compilação Android debug confirmada. Isso não garante ausência total de defeitos nem substitui a instalação e os testes físicos no aparelho-alvo.

- `python3 tests/test_patch_gradle.py`: aprovado; API mínima 26, dependência e JitPack idempotentes em Gradle Groovy/Kotlin.
