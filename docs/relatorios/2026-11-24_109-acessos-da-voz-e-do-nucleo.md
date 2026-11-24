# Bloco 109 — a voz externa e o núcleo com acesso direto

Data: 2026-11-24 · versão **1.88.7**

## O problema

Duas telas existiam, funcionavam e estavam testadas, mas não tinham caminho
visível:

- **Voz externa (ID + chave)**: só se chegava por gaveta → Timbre → módulo
  "Perfis de timbre" → botão, ou pelo módulo "Voz e KWS". A gaveta → Voz abre a
  tela de palavra de ativação, que não tinha link para a voz externa.
- **Núcleo flutuante**: o único atalho morava dentro da tela do Avatar 3D. A
  gaveta não tem entrada de Avatar nem de Núcleo.

O efeito para quem usa: os campos da API e o interruptor do núcleo "não existem".

## O que mudou

| Arquivo | Mudança |
|---|---|
| `flutter_app/lib/drawer.dart` | Itens **Voz externa** e **Núcleo flutuante**, com callbacks próprios (`onVozExterna`, `onNucleo`) |
| `flutter_app/lib/home_screen.dart` | `_openVozExterna()` e `_openNucleo()` ligados à gaveta |
| `flutter_app/lib/services/kws_settings_page.dart` | Cartão "Voz externa (ID)" no topo da tela de Voz |
| `flutter_app/test/gaveta_acessos_test.dart` (novo) | A gaveta mostra os dois itens e cada um dispara o callback certo, sem abrir módulo; os itens antigos continuam |
| `tests/test_acessos_escondidos.py` (novo) | Contrato estático: itens na gaveta, ligação na tela principal, botão na tela de Voz, campos da voz externa e interruptor do núcleo presentes |

## Verificação

- `python3 tests/test_acessos_escondidos.py` — OK
- `python3 tests/test_nucleo_flutuante.py` — OK
- `python3 tests/test_assinatura_release.py` — aprovado
- `python3 tests/test_empacotamento.py` — OK
- `python3 tests/validate_project.py` — projeto validado
- `flutter analyze` e `flutter test` rodam no CI da esteira; o resultado do run
  fica registrado no commit.

## Limites

- Nada foi aberto em aparelho nesta sessão. O teste de widget prova que a gaveta
  leva às telas; o toque real e o aspecto no celular continuam por conferir.
- Nenhuma permissão nova e nenhum campo novo: a mudança é de caminho.
