"""Trava a leitura sem perdas do formato .cad e a recusa de arquivo malformado.

O arquivo de teste é sintético, montado com a mesma gramática observada em exemplos públicos:
cabeçalho, registro normal, texto tipo 8 sem separador e fio. Ele não prova que o CADe_SIMU abre
o resultado; prova que a sonda não perde nem inventa bytes.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CAMINHO = RAIZ / "tools" / "cadesimu_sonda.py"
_spec = importlib.util.spec_from_file_location("cadesimu_sonda", CAMINHO)
assert _spec and _spec.loader
sonda = importlib.util.module_from_spec(_spec)
sys.modules["cadesimu_sonda"] = sonda
_spec.loader.exec_module(sonda)

CHECKS = 0


def ok(nome: str) -> None:
    global CHECKS
    CHECKS += 1
    print(f"OK: {nome}")


AMOSTRA = (
    "CADe_SIMU*0*3004#-X#########"
    "*0*0*0*0*0*0*0*0*69*51*0*0*-12*-9*18*3*0*0*0*1*0*0*0#"
    "*1*8##########*0*0*0*0*0*0*0*0*63*30*73*33*0*0*0*0*0*0*0*0*0*0*0#FUERZA"
    "*2*4000#*0*0*0*0*0*0*0*0*69*51*69*87*0*0*0*0*0*0*0*0*0*0*0"
    "#$$$&&&"
)


def main() -> int:
    documento = sonda.Documento.ler(AMOSTRA)
    assert documento.escrever() == AMOSTRA, "round-trip alterou o arquivo"
    assert [r.tipo for r in documento.registros] == [3004, 8, 4000]
    assert [r.indice for r in documento.registros] == [0, 1, 2]
    ok("ida e volta byte a byte")

    alimentacao = documento.registros[0]
    assert alimentacao.rotulo == "-X"
    assert alimentacao.x == 69 and alimentacao.y == 51
    assert alimentacao.pinos == ()
    assert documento.registros[2].x2 == 69 and documento.registros[2].y2 == 87
    ok("rótulo e geometria do símbolo e do fio")

    assert documento.registros[1].texto == "FUERZA"
    assert documento.textos == ("FUERZA",)
    assert documento.tem_rodape
    ok("texto livre e rodapé")

    resumo = documento.resumo()
    assert resumo["simbolos"] == 1, resumo
    assert resumo["fios"] == 1, resumo
    assert resumo["juncoes"] == 0, resumo
    assert resumo["redes_geometricas"] == 1, resumo
    assert resumo["simbolos_com_fio_na_origem"] == 1, resumo
    ok("resumo do documento")

    # Latin-1 e um campo desconhecido não podem ser perdidos.
    acentuado = AMOSTRA.replace("#-X#", "#-MÁ#").replace("*0*0*0*0*0*0*0*0*69*51", "*0*0*0*0*0*0*0*0*69*51")
    doc2 = sonda.Documento.ler(acentuado)
    assert doc2.escrever() == acentuado
    assert doc2.registros[0].rotulo == "-MÁ"
    ok("texto latin-1 preservado")

    for invalido in ("", "CADe_SIMU", "CADe_SIMU*0*"):
        try:
            sonda.Documento.ler(invalido)
        except sonda.ErroFormato:
            pass
        else:
            raise AssertionError(f"aceitou documento inválido: {invalido!r}")
    ok("arquivo malformado recusado")

    print(f"\nSonda CADeSIMU: {CHECKS} grupos de verificação aprovados.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
