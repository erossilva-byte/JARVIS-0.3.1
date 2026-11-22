"""Sonda de leitura do formato nativo .cad do CADe_SIMU.

O formato não tem especificação oficial. As notas públicas de engenharia reversa mostram que o
arquivo é texto ISO-8859-1, sem quebras de linha, com cabeçalho ``CADe_SIMU``, registros
``*índice*tipo#rótulos*campos`` e rodapé ``#$$$``. Esta sonda lê e reescreve os registros sem
interpretar os campos desconhecidos; assim o arquivo original é preservado byte a byte.

Ela não é um importador elétrico: não associa pinos a fios nem calcula a netlist de simulação.
Serve para medir o que existe e para impedir que a leitura perca dados.

Uso:
    python3 tools/cadesimu_sonda.py arquivo.cad [outro.cad ...] [--json] [--exigir-rodape]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

CABECALHO = "CADe_SIMU"
MARCA_RODAPE = "#$$$"
_TEXTO = 8
_TIPOS_FIO = frozenset({4000, 4009, 4010, 4018, 4019})
_TIPOS_MARCADOR = frozenset({4001, 4002, 4003, 4004, 10104, 10105, 10106, 10112})
_INICIO = re.compile(r"\*(\d+)\*(\d+)#")
_PROXIMO = re.compile(r"#\*(\d+)\*(\d+)#")
_QUALQUER = re.compile(r"\*(\d+)\*(\d+)#")


class ErroFormato(ValueError):
    """O texto não tem a estrutura mínima de um documento CADe_SIMU."""


def _inteiro(valor: str | None) -> int | None:
    if valor is None:
        return None
    try:
        return int(valor)
    except ValueError:
        return None


@dataclass(frozen=True)
class Registro:
    """Um registro bruto, com o separador que o antecedia."""

    indice: int
    tipo: int
    bruto: str
    separador: str = ""

    @property
    def rotulos(self) -> tuple[str, ...]:
        corpo = self.bruto.split("#", 1)[1]
        cabeca = corpo.split("*", 1)[0]
        return tuple(cabeca.split("#"))

    @property
    def campos(self) -> tuple[str, ...]:
        corpo = self.bruto.split("#", 1)[1]
        _, separador, cauda = corpo.partition("*")
        if not separador:
            return ()
        return tuple(cauda.split("*"))

    @property
    def rotulo(self) -> str:
        return self.rotulos[0] if self.rotulos else ""

    @property
    def pinos(self) -> tuple[str, ...]:
        return tuple(p for p in self.rotulos[2:] if p)

    @property
    def x(self) -> int | None:
        return _inteiro(self.campos[8]) if len(self.campos) > 8 else None

    @property
    def y(self) -> int | None:
        return _inteiro(self.campos[9]) if len(self.campos) > 9 else None

    @property
    def x2(self) -> int | None:
        return _inteiro(self.campos[10]) if len(self.campos) > 10 else None

    @property
    def y2(self) -> int | None:
        return _inteiro(self.campos[11]) if len(self.campos) > 11 else None

    @property
    def texto(self) -> str:
        """Texto livre dos registros tipo 8; vazio nos demais."""
        if self.tipo != _TEXTO:
            return ""
        return self.bruto.rsplit("#", 1)[-1]

    @property
    def eh_fio(self) -> bool:
        return self.tipo in _TIPOS_FIO

    @property
    def eh_marcador(self) -> bool:
        return self.tipo in _TIPOS_MARCADOR


def _proximo_texto(corpo: str, inicio: int) -> re.Match[str] | None:
    """O texto tipo 8 não tem ``#`` antes do próximo registro."""
    cabeca = _INICIO.match(corpo, inicio)
    if cabeca is None:
        return None
    primeiro_campo = corpo.find("*", cabeca.end())
    if primeiro_campo < 0:
        return None
    fim_campos = corpo.find("#", primeiro_campo)
    if fim_campos < 0:
        return None
    return _QUALQUER.search(corpo, fim_campos + 1)


@dataclass(frozen=True)
class Documento:
    registros: tuple[Registro, ...]
    rodape: str

    @classmethod
    def ler(cls, texto: str) -> "Documento":
        if not texto.startswith(CABECALHO):
            raise ErroFormato("cabeçalho CADe_SIMU ausente")
        posicao_rodape = texto.find(MARCA_RODAPE, len(CABECALHO))
        if posicao_rodape < 0:
            corpo, rodape = texto[len(CABECALHO) :], ""
        else:
            corpo, rodape = texto[len(CABECALHO) : posicao_rodape], texto[posicao_rodape:]

        if not corpo:
            raise ErroFormato("documento sem registros")
        registros: list[Registro] = []
        inicio = 0
        separador = ""
        while inicio < len(corpo):
            cabeca = _INICIO.match(corpo, inicio)
            if cabeca is None:
                trecho = corpo[inicio : inicio + 40]
                raise ErroFormato(f"registro malformado na posição {inicio}: {trecho!r}")
            indice, tipo = int(cabeca.group(1)), int(cabeca.group(2))
            if tipo == _TEXTO:
                proximo = _proximo_texto(corpo, inicio)
                fim = proximo.start() if proximo else len(corpo)
                proximo_separador = ""
            else:
                proximo = _PROXIMO.search(corpo, cabeca.end())
                fim = proximo.start() if proximo else len(corpo)
                proximo_separador = "#"
            registros.append(Registro(indice, tipo, corpo[inicio:fim], separador))
            if proximo is None:
                break
            inicio = proximo.start() if tipo == _TEXTO else proximo.start() + 1
            separador = proximo_separador
        return cls(tuple(registros), rodape)

    def escrever(self) -> str:
        return CABECALHO + "".join(r.separador + r.bruto for r in self.registros) + self.rodape

    @property
    def tem_rodape(self) -> bool:
        return self.rodape.startswith(MARCA_RODAPE)

    @property
    def simbolos(self) -> tuple[Registro, ...]:
        return tuple(
            r for r in self.registros if r.tipo not in _TIPOS_FIO and r.tipo not in _TIPOS_MARCADOR and r.tipo != _TEXTO
        )

    @property
    def fios(self) -> tuple[Registro, ...]:
        return tuple(r for r in self.registros if r.eh_fio)

    @property
    def textos(self) -> tuple[str, ...]:
        return tuple(r.texto for r in self.registros if r.tipo == _TEXTO)

    def redes_geometricas(self) -> int:
        """Conta grupos de fios ligados por extremidade exata ou junção 4001.

        É uma leitura geométrica, não a netlist elétrica: os pinos dos símbolos não entram
        porque seus deslocamentos dependem da classe e da orientação.
        """
        fios = self.fios
        if not fios:
            return 0
        pai = list(range(len(fios)))

        def achar(i: int) -> int:
            while pai[i] != i:
                pai[i] = pai[pai[i]]
                i = pai[i]
            return i

        def unir(a: int, b: int) -> None:
            ra, rb = achar(a), achar(b)
            if ra != rb:
                pai[rb] = ra

        extremos: dict[tuple[int, int], int] = {}
        segmentos: list[tuple[tuple[int, int], tuple[int, int]]] = []
        for i, fio in enumerate(fios):
            if fio.x is None or fio.y is None or fio.x2 is None or fio.y2 is None:
                continue
            a, b = (fio.x, fio.y), (fio.x2, fio.y2)
            segmentos.append((a, b))
            for ponto in (a, b):
                if ponto in extremos:
                    unir(i, extremos[ponto])
                else:
                    extremos[ponto] = i
        for marcador in self.registros:
            if marcador.tipo != 4001 or marcador.x is None or marcador.y is None:
                continue
            ponto = (marcador.x, marcador.y)
            tocados = [
                i
                for i, (a, b) in enumerate(segmentos)
                if (a[0] == b[0] == ponto[0] and min(a[1], b[1]) <= ponto[1] <= max(a[1], b[1]))
                or (a[1] == b[1] == ponto[1] and min(a[0], b[0]) <= ponto[0] <= max(a[0], b[0]))
            ]
            for i in tocados[1:]:
                unir(tocados[0], i)
        return len({achar(i) for i in range(len(fios))})

    def resumo(self) -> dict[str, object]:
        tipos = Counter(r.tipo for r in self.registros)
        extremos = {
            ponto
            for fio in self.fios
            if fio.x is not None and fio.y is not None and fio.x2 is not None and fio.y2 is not None
            for ponto in ((fio.x, fio.y), (fio.x2, fio.y2))
        }
        com_fio_na_origem = sum(1 for s in self.simbolos if s.x is not None and s.y is not None and (s.x, s.y) in extremos)
        return {
            "registros": len(self.registros),
            "tipos": dict(sorted(tipos.items())),
            "simbolos": len(self.simbolos),
            "fios": len(self.fios),
            "juncoes": tipos.get(4001, 0),
            "textos": list(self.textos),
            "redes_geometricas": self.redes_geometricas(),
            "simbolos_com_fio_na_origem": com_fio_na_origem,
            "rodape": self.tem_rodape,
        }


def analisar(caminho: Path) -> dict[str, object]:
    dados = caminho.read_bytes()
    texto = dados.decode("latin-1")
    documento = Documento.ler(texto)
    if documento.escrever() != texto:
        raise ErroFormato("a reescrita não devolveu o arquivo original")
    resumo = documento.resumo()
    resumo.update(
        {
            "arquivo": caminho.name,
            "bytes": len(dados),
            "sha256": hashlib.sha256(dados).hexdigest(),
            "round_trip": True,
        }
    )
    return resumo


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lê e confere arquivos .cad do CADe_SIMU sem alterá-los.")
    parser.add_argument("arquivos", nargs="+", type=Path)
    parser.add_argument("--json", action="store_true", help="imprime um objeto JSON por arquivo")
    parser.add_argument("--exigir-rodape", action="store_true", help="recusa arquivo sem #$$$")
    args = parser.parse_args(argv)

    falhou = False
    for caminho in args.arquivos:
        try:
            resumo = analisar(caminho)
            if args.exigir_rodape and not resumo["rodape"]:
                raise ErroFormato("rodapé #$$$ ausente")
        except (OSError, ErroFormato) as erro:
            falhou = True
            print(f"FALHOU: {caminho}: {erro}", file=sys.stderr)
            continue
        if args.json:
            print(json.dumps(resumo, ensure_ascii=False, sort_keys=True))
        else:
            print(f"{caminho.name}: {resumo['bytes']} bytes, {resumo['registros']} registros")
            print(f"  símbolos={resumo['simbolos']} fios={resumo['fios']} junções={resumo['juncoes']} textos={len(resumo['textos'])}")
            print(f"  redes geométricas={resumo['redes_geometricas']} rodapé={'sim' if resumo['rodape'] else 'não'}")
            print(f"  round-trip byte a byte: OK · sha256={resumo['sha256'][:16]}…")
    return 1 if falhou else 0


if __name__ == "__main__":
    sys.exit(main())
