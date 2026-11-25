"""Roda os testes Dart puros do núcleo da interface, quando há SDK do Dart.

O núcleo da conversa (agrupamento de tokens do streaming) não depende do Flutter, então pode
ser testado sem emulador e sem `flutter test`. Este passo procura o Dart no PATH, em DART_SDK
ou no SDK temporário usado no desenvolvimento; se não encontrar, avisa e não reprova — o CI
com Flutter roda `flutter analyze` e `flutter test`, e o workflow nativo chama o teste puro
diretamente.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent


def localizar_dart() -> str | None:
    no_path = shutil.which("dart")
    if no_path:
        return no_path
    candidatos = []
    sdk = os.environ.get("DART_SDK")
    if sdk:
        candidatos.append(Path(sdk) / "bin" / "dart")
    candidatos.append(Path("/tmp/dart-sdk/bin/dart"))
    candidatos.append(Path("/tmp/flutter/bin/dart"))
    for caminho in candidatos:
        if caminho.is_file():
            return str(caminho)
    return None


CASOS = (
    ("tool/stream_buffer_test.dart", "agrupamento de tokens (32 ms)"),
    ("tool/sse_test.dart", "parser SSE do streaming"),
    ("tool/conversa_test.dart", "modelo de conversa e título automático"),
    ("tool/memoria_test.dart", "memória: Markdown, busca, citação e orçamento"),
    ("tool/memoria_sync_test.dart", "sincronização: envio, recebimento, conflito e ausência"),
    ("tool/memoria_conflito_test.dart", "resolução de conflito: escolha e backup preservado"),
    ("tool/pessoas_test.dart", "pessoas: consentimento, ambiguidade e contexto seguro"),
    ("tool/pessoas_conversa_test.dart", "pessoas na conversa: bloco seguro, ausência e transparência"),
    ("tool/personalidade_test.dart", "personalidade: níveis, tom sensível, pressa e prompt"),
    ("tool/visao_test.dart", "visão: limite, prompt sem rosto, pedido multimodal e resposta"),
    ("tool/arquivos_test.dart", "arquivos: nome seguro, caminho confinado e operações reais"),
    ("tool/comandos_android_test.dart", "comandos Android: registro, interpretação e perguntas preservadas"),
    ("tool/circuito_test.dart", "simulador de circuitos: MNA, proteção e avisos elétricos"),
    ("tool/fundo_test.dart", "segundo plano: pronto, pendências, resumo e limites"),
    ("tool/seguranca_test.dart", "segurança: PIN, derivação, tentativas e biometria"),
    ("tool/localizacao_test.dart", "localização: estado, leitura, honestidade e comando"),
    ("tool/historico_voz_test.dart", "histórico de execuções: horário, origem, resultado e limites"),
    ("tool/ativacao_sensibilidade_test.dart", "sensibilidade da ativação: faixa, passo, limiar e rótulos"),
    ("tool/aparelho_resposta_test.dart", "sentinela de mensagens: chave, resposta direta e leitura"),
    ("tool/pergunta_livre_test.dart", "pergunta livre: pedido, personalidade, limpeza e corte"),
    ("tool/resumo_tatico_test.dart", "resumo tático: urgência, ruído, pedido, leitura e fala"),
    ("tool/habilidades_test.dart", "habilidades: caminho, frontmatter, casamento, bloco e registro"),
    ("tool/gestos_test.dart", "gestos: eixos, histerese, brilho, estado, resumo e limites"),
    ("tool/timbre_voz_test.dart", "timbre: perfis, paridade do grave, faixas e limites"),
    ("tool/circuito_no_chat_test.dart", "circuito no chat: decisão, montagem e recusa"),
    ("tool/edicao_circuito_test.dart", "edição do circuito em uso: valor, recálculo e recusas"),
    ("tool/especialidades_test.dart", "especialidades: CADeSIMU, programação e limites"),
    ("tool/palco_test.dart", "palco: pedido, fontes sem chave, leitores e links"),
    ("tool/estado_modulos_test.dart", "estado dos módulos: cobertura, motivos e contagem"),
    ("tool/hermes_plano_test.dart", "hermes: agentes, roteamento, planos e mensagens"),
    ("tool/projetista_test.dart", "projetista: famílias, montagem simulada e recusas"),
    ("tool/voz_externa_test.dart", "voz externa: ID padrão, validação, URL e limites"),
    ("tool/modo_visita_test.dart", "modo de visita: prompt, respostas locais, ajustes vazios e limites"),
    ("tool/programacao_test.dart", "programação: tarefas, validação, blocos, arquivo e prompt"),
    ("tool/recorrencia_test.dart", "recorrência: dia da semana, mês, ano e próxima data"),
    ("tool/palco_enquadramento_test.dart", "palco: moldura por forma da imagem, vídeo e notícia"),
    ("tool/fala_em_fluxo_test.dart", "fala em fluxo: frases durante a resposta e resto no fim"),
    ("tool/palco_regras_test.dart", "palco: regras por tipo, limiares e JSON"),
    ("tool/avatar3d_test.dart", "avatar 3D: giro, perspectiva, malha, rosto e órbitas"),
    ("tool/pedido_abrir_test.dart", "abrir telas por voz: tela certa, app de terceiro e perguntas"),
    ("tool/pedido_app_test.dart", "abrir app com ação: conversa, rascunho, busca, rota e recusa"),
    ("tool/nome_contato_test.dart", "nomes de contato: apelido, emoji, erro de fala e empate"),
    ("tool/pedido_apelido_test.dart", "apelido de contato: ensinar, esquecer e não sequestrar conversa"),
    ("tool/mapa_voz_test.dart", "mapa da voz: pergunta, catálogo e total de telas"),
    ("tool/segredo_pedido_test.dart", "PIN no histórico: 4 a 8 dígitos mascarados, telefone preservado"),
    ("tool/pin_sem_colisao_test.dart", "máscara de PIN não atrapalha apelido com número nem envio com número"),
)


def main() -> int:
    dart = localizar_dart()
    if dart is None:
        print("AVISO: Dart não encontrado — testes puros do núcleo não rodaram.")
        return 0
    for caminho, rotulo in CASOS:
        r = subprocess.run(
            [dart, "run", caminho],
            cwd=RAIZ / "flutter_app",
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if r.returncode != 0:
            print((r.stdout or "") + (r.stderr or ""))
            print(f"FALHOU: {rotulo}.")
            return 1
    print("OK: núcleo Dart — " + "; ".join(rotulo for _, rotulo in CASOS))
    return 0

if __name__ == "__main__":
    sys.exit(main())
