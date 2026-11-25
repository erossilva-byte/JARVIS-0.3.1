"""Bloco 110 — exportar contatos, recorrência e palco adaptativo.

Contrato estático de três entregas:
  1. exportação de contatos em vCard, gravada na pasta do app e compartilhada
     pelo FileProvider (sem permissão ampla de armazenamento);
  2. rotinas, automações e tarefas com semana, mês e dia do ano, com horário, e
     com edição do que já existe;
  3. palco que muda a moldura conforme a forma da imagem, do vídeo e da notícia.
Não compila Kotlin nem abre tela: só confere o caminho e as travas.
"""

from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"
ANDROID = APP / "android"


def ler(caminho: Path) -> str:
    assert caminho.is_file(), f"arquivo ausente: {caminho}"
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    assert condicao, mensagem


aparelho = ler(ANDROID / "JarvisAparelho.kt")
agenda = ler(ANDROID / "JarvisAgenda.kt")
service = ler(LIB / "services" / "aparelho_service.dart")
pagina_aparelho = ler(LIB / "services" / "aparelho_page.dart")
tarefas = ler(LIB / "core" / "tarefas.dart")
pagina_tarefas = ler(LIB / "services" / "tarefas_page.dart")
agenda_dart = ler(LIB / "services" / "agenda_service.dart")
palco = ler(LIB / "core" / "palco.dart")
pagina_palco = ler(LIB / "services" / "palco_page.dart")
arquivos_xml = ler(ANDROID / "sistema" / "res" / "xml" / "jarvis_arquivos.xml")

# 1. Exportação de contatos ---------------------------------------------------
for termo in ("\"exportarContatos\"", "BEGIN:VCARD", "VERSION:3.0",
              "END:VCARD", "TEL;TYPE=CELL:", "EMAIL;TYPE=OTHER:"):
    exigir(termo in aparelho, f"JarvisAparelho.kt sem {termo}")
exigir("getExternalFilesDir(null), \"exports\"" in aparelho,
       "exportação não grava na pasta exports do app")
exigir("READ_CONTACTS" in aparelho and "Sem permissão para ler os contatos" in aparelho,
       "exportação sem checagem de permissão")
exigir("replace(\"\\\\\", \"\\\\\\\\\")" in aparelho,
       "vCard sem escape de barra invertida")
exigir("\"compartilharArquivo\"" in aparelho and "FileProvider.getUriForFile" in aparelho,
       "compartilhamento do .vcf não usa FileProvider")
exigir("external-files-path" in arquivos_xml and "exports/" in arquivos_xml,
       "FileProvider sem o caminho de exportação")
exigir("exportarContatos" in service and "compartilharArquivo" in service,
       "AparelhoService sem as chamadas de exportação")
exigir("'contatos-exportar'" in pagina_aparelho,
       "tela do aparelho sem botão de exportar")
exigir("'contatos-compartilhar'" in pagina_aparelho,
       "tela do aparelho sem botão de compartilhar o .vcf")

# 2. Recorrência --------------------------------------------------------------
exigir("enum Recorrencia" in tarefas, "core/tarefas.dart sem o enum Recorrencia")
for campo in ("recorrencia", "diasSemana", "diaDoMes", "mesAno", "diaAno"):
    exigir(f"this.{campo}" in tarefas or f"final " in tarefas,
           f"campo {campo} ausente")
    exigir(campo in tarefas, f"core/tarefas.dart sem {campo}")
exigir("bool diaCombinaCom(" in tarefas, "sem regra de dia da semana/mês/ano")
exigir("DateTime? proximaOcorrenciaAutomacao(" in tarefas,
       "sem cálculo da próxima ocorrência")
exigir("DateTime proximaDataTarefa(" in tarefas, "sem próxima data de tarefa")
exigir("if (!diaCombinaCom(automacao, agora)) return false;" in tarefas,
       "automacaoVencida não respeita a recorrência")
exigir("'recorrencia': recorrencia.name" in tarefas and
       "'diasSemana': diasSemana" in tarefas,
       "automação não persiste a recorrência")

for termo, onde in (
    ("'automacao-recorrencia-", "seletor de recorrência da automação"),
    ("'automacao-dia-semana-", "escolha dos dias da semana"),
    ("'automacao-dia-mes'", "campo do dia do mês"),
    ("'automacao-dia-ano'", "campo do dia e mês do ano"),
    ("'tarefa-recorrencia-", "seletor de recorrência da tarefa"),
    ("'automacao-editar-", "botão de editar automação"),
    ("'tarefa-editar-", "botão de editar tarefa"),
):
    exigir(termo in pagina_tarefas, f"tela de tarefas sem {onde}")
exigir("Recorrencia repeticao = Recorrencia.umaVez" in agenda_dart,
       "AgendaService não recebe a recorrência")
exigir("'repeticao': repeticao.name" in agenda_dart,
       "AgendaService não envia a recorrência ao Android")
for termo in ("normalizarRepeticao", "proximoCiclo", "putExtra(\"repeticao\""):
    exigir(termo in agenda, f"JarvisAgenda.kt sem {termo}")
exigir("proximaDataTarefa(tarefa.prazo!, tarefa.recorrencia)" in pagina_tarefas,
       "concluir tarefa que repete não cria a próxima")

# 3. Palco adaptativo ---------------------------------------------------------
exigir("enum MolduraPalco" in palco, "core/palco.dart sem MolduraPalco")
exigir("Moldura molduraDoItem(" in palco, "sem escolha de moldura")
for tipo in ("capaLarga", "retratoAlto", "quadrada", "capaVideo",
             "capaNoticia", "semImagem"):
    exigir(tipo in palco, f"moldura {tipo} ausente")
exigir("this.largura = 0" in palco and "this.altura = 0" in palco,
       "ItemPalco não guarda o tamanho da mídia")
exigir("molduraDoItem(item" in pagina_palco,
       "tela do palco não usa a moldura")
exigir("BoxFit.contain : BoxFit.cover" in pagina_palco,
       "tela do palco sem recorte adaptativo")
exigir("height: 210," not in pagina_palco,
       "altura fixa de 210 px ainda no palco")

# 4. Versão e suíte -----------------------------------------------------------
exigir("version: 1.109.0+110900" in ler(APP / "pubspec.yaml"),
       "versão não atualizada para 1.89.0")
pacote = ler(RAIZ / "package.json")
exigir("python3 tests/test_bloco_110.py" in pacote,
       "contrato do bloco fora da suíte")
exigir((APP / "tool" / "recorrencia_test.dart").is_file(),
       "falta o teste puro da recorrência")
exigir((APP / "tool" / "palco_enquadramento_test.dart").is_file(),
       "falta o teste puro da moldura do palco")
exigir("tool/recorrencia_test.dart" in ler(RAIZ / "tests" / "test_dart_core.py"),
       "teste da recorrência fora da suíte Dart")

print("OK: contatos exportáveis, recorrência semanal/mensal/anual e palco adaptativo")
