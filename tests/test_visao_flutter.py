"""Confere por leitura estática a visão de imagem da interface Flutter.

O que se prova aqui é o contrato: consentimento explícito, limite de tamanho, envio multimodal
somente a provedor com visão, ausência de reconhecimento facial e nenhuma gravação da imagem. A
precisão do modelo depende de chave real e não é medida neste ambiente.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CORE = RAIZ / "flutter_app" / "lib" / "core" / "visao.dart"
SERVICO = RAIZ / "flutter_app" / "lib" / "services" / "visao_service.dart"
PAGINA = RAIZ / "flutter_app" / "lib" / "services" / "visao_page.dart"
CAMERA = RAIZ / "flutter_app" / "lib" / "services" / "visao_camera.dart"
IMAGEM = RAIZ / "flutter_app" / "lib" / "services" / "visao_imagem.dart"
ESTRUTURADA = RAIZ / "flutter_app" / "lib" / "core" / "visao_estruturada.dart"
CONSENTIMENTO = RAIZ / "flutter_app" / "lib" / "services" / "consentimento_visao.dart"
VIDEO = RAIZ / "flutter_app" / "lib" / "services" / "video_quadros.dart"
MAIN = RAIZ / "flutter_app" / "android" / "MainActivity.kt"
HOME = RAIZ / "flutter_app" / "lib" / "home_screen.dart"
PUBSPEC = RAIZ / "flutter_app" / "pubspec.yaml"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, SERVICO, PAGINA, CAMERA, IMAGEM, ESTRUTURADA, CONSENTIMENTO, VIDEO, MAIN, HOME, PUBSPEC):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    servico = SERVICO.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    camera = CAMERA.read_text(encoding="utf-8")
    imagem = IMAGEM.read_text(encoding="utf-8")
    estruturada = ESTRUTURADA.read_text(encoding="utf-8")
    consentimento = CONSENTIMENTO.read_text(encoding="utf-8")
    video = VIDEO.read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    home = HOME.read_text(encoding="utf-8")
    pubspec = PUBSPEC.read_text(encoding="utf-8")

    # 1. Limites antes do envio.
    if "limiteBytesVisao" not in core or "4 * 1024 * 1024" not in core:
        falhas.append("limite de 4 MB ausente")
    for mime in ("image/jpeg", "image/png", "image/webp"):
        if mime not in core:
            falhas.append(f"formato {mime} não declarado")

    # 2. Sem reconhecimento facial e sem identificação de pessoas.
    for termo in ("Não identifique pessoas", "reconhecimento facial", "Não invente", "atributo sensível"):
        if termo not in core:
            falhas.append(f"prompt sem a proteção: {termo}")

    # 3. Só provedor com visão, sem cair em modelo textual.
    for proibido in ("deepseek", "gpt-oss", "mistral-small"):
        if proibido in core:
            falhas.append(f"modelo sem visão listado: {proibido}")
    if "Authorization" not in servico:
        falhas.append("serviço não autentica no provedor")
    if "api_key=" in servico or "?key=" in servico:
        falhas.append("chave na URL em vez do cabeçalho")

    # 4. Consentimento explícito e nenhuma gravação da imagem.
    if "Autorizo enviar esta imagem" not in pagina:
        falhas.append("consentimento explícito ausente")
    if "não guarda a foto" not in pagina or "não mantém cópia" not in pagina:
        falhas.append("tela não declara que a imagem não é guardada")
    if "Sem reconhecimento facial" not in pagina:
        falhas.append("tela não declara ausência de reconhecimento facial")
    for proibido in ("writeAsBytes", "SharedPreferences", "FlutterSecureStorage", "File("):
        if proibido in pagina:
            falhas.append(f"possível gravação de imagem na tela: {proibido}")

    # 5. A imagem só sai depois do consentimento (o botão depende dele).
    if "imagem != null && consentimento" not in pagina:
        falhas.append("análise não exige imagem e consentimento juntos")

    # 6. Dependência real de seleção de imagem e menu apontando para a tela.
    if "image_picker:" not in pubspec:
        falhas.append("image_picker não declarado no pubspec")
    if "Visão e OCR" not in home or "VisaoPage" not in home:
        falhas.append("menu de Visão não abre a tela real")

    # 7. O teste puro está registrado e o serviço não grava arquivo.
    package = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    if "tests/test_visao_flutter.py" not in package["scripts"]["test:all"]:
        falhas.append("teste estático de visão fora da suíte")
    if "visao_test.dart" not in (RAIZ / "tests" / "test_dart_core.py").read_text(encoding="utf-8"):
        falhas.append("teste puro de visão fora do núcleo Dart")
    if "dart:io" in servico:
        falhas.append("serviço de visão importa dart:io sem precisar")

    # 8. Câmera ao vivo, captura, vídeo e fallback de galeria.
    for dependencia in ("camera:", "gal:", "image:"):
        if dependencia not in pubspec:
            falhas.append(f"dependência de câmera/salvamento ausente: {dependencia}")
    for termo in ("availableCameras", "CameraPreview", "startVideoRecording", "stopVideoRecording"):
        if termo not in camera:
            falhas.append(f"câmera ao vivo sem {termo}")
    for termo in ("abrir-camera", "capturar-foto", "gravar-video", "trocar-camera", "flash-camera"):
        if termo not in pagina:
            falhas.append(f"controle de câmera ausente: {termo}")

    # 9. Imagem comprimida, JSON estruturado, balões e salvamento.
    if "1024" not in imagem or "quality: 80" not in imagem or "encodeJpg" not in imagem:
        falhas.append("imagem não é redimensionada para 1024 px em JPEG 80%")
    for termo in ("interpretarAnaliseVisao", "bbox", "layoutBaloesVisao", "rotuloSeguro"):
        if termo not in estruturada:
            falhas.append(f"análise estruturada sem {termo}")
    for termo in ("balao-", "CustomPaint", "salvar-baloes", "layoutBaloesVisao"):
        if termo not in pagina:
            falhas.append(f"balões/tela sem {termo}")
    for termo in ("Gal.putImageBytes", "Gal.putVideo", "imagemComBaloes"):
        if termo not in imagem:
            falhas.append(f"salvamento na galeria sem {termo}")

    # 10. Consentimento persistente, uma vez, com revogação; sem checkbox por foto.
    if "ConsentimentoVisao" not in pagina or "Switch(" not in pagina:
        falhas.append("consentimento persistente com switch ausente")
    if "Checkbox" in pagina:
        falhas.append("checkbox por foto ainda presente")
    if "visao_consentimento_v1" not in consentimento:
        falhas.append("chave de consentimento não persistida")
    if "SharedPreferences" in pagina:
        falhas.append("tela de visão guarda preferência diretamente")

    # 11. Vídeo: extração nativa, linha do tempo e balões por quadro.
    for termo in ("MediaMetadataRetriever", "extrairQuadrosVideo", "CANAL_VIDEO"):
        if termo not in main:
            falhas.append(f"extração de quadros ausente no Android: {termo}")
    for termo in ("ExtratorQuadros", "invokeMethod", "extrairQuadros"):
        if termo not in video:
            falhas.append(f"serviço de quadros sem {termo}")
    for termo in ("analisar-video", "quadro-", "_mostrarQuadro"):
        if termo not in pagina:
            falhas.append(f"linha do tempo de vídeo ausente: {termo}")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"Visão Flutter: {len(falhas)} problema(s).")
        return 1
    print("OK: visão — consentimento, limite, provedor com visão, sem rosto e sem gravação da imagem")
    return 0


if __name__ == "__main__":
    sys.exit(main())
