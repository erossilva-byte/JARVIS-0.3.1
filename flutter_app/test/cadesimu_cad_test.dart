import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/cadesimu_cad.dart';

const amostra = 'CADe_SIMU*0*3004#-X#########'
    '*0*0*0*0*0*0*0*0*69*51*0*0*-12*-9*18*3*0*0*0*1*0*0*0#'
    '*1*8##########*0*0*0*0*0*0*0*0*63*30*73*33*0*0*0*0*0*0*0*0*0*0*0#FUERZA'
    '*2*4000#*0*0*0*0*0*0*0*0*69*51*69*87*0*0*0*0*0*0*0*0*0*0*0'
    '#\$\$\$&&&';

void main() {
  test('lê e reescreve o .cad byte a byte', () {
    final doc = DocumentoCad.ler(amostra);
    expect(doc.escrever(), amostra);
    expect(doc.registros.map((r) => r.tipo), [3004, 8, 4000]);
    expect(doc.registros.map((r) => r.indice), [0, 1, 2]);
  });

  test('extrai rótulo, geometria, texto e rodapé', () {
    final doc = DocumentoCad.ler(amostra);
    final simbolo = doc.registros.first;
    expect(simbolo.rotulo, '-X');
    expect(simbolo.x, 69);
    expect(simbolo.y, 51);
    expect(simbolo.pinos, isEmpty);
    expect(doc.registros[2].x2, 69);
    expect(doc.registros[2].y2, 87);
    expect(doc.registros[1].texto, 'FUERZA');
    expect(doc.textos, ['FUERZA']);
    expect(doc.temRodape, isTrue);
  });

  test('resume símbolos, fios e redes geométricas', () {
    final resumo = DocumentoCad.ler(amostra).resumo();
    expect(resumo.simbolos, 1);
    expect(resumo.fios, 1);
    expect(resumo.juncoes, 0);
    expect(resumo.redesGeometricas, 1);
    expect(resumo.simbolosComFioNaOrigem, 1);
  });

  test('preserva Latin-1 e campo desconhecido', () {
    final acentuado = amostra.replaceFirst('#-X#', '#-MÁ#');
    final doc = DocumentoCad.ler(acentuado);
    expect(doc.escrever(), acentuado);
    expect(doc.registros.first.rotulo, '-MÁ');
  });

  test('recusa documento malformado', () {
    for (final invalido in ['', 'CADe_SIMU', 'CADe_SIMU*0*']) {
      expect(() => DocumentoCad.ler(invalido), throwsA(isA<CadesimuErro>()));
    }
  });

  test('analisarArquivoCad devolve o mesmo conteúdo', () {
    final arquivo =
        ArquivoCad('teste.cad', Uint8List.fromList(amostra.codeUnits));
    expect(analisarArquivoCad(arquivo).nome, 'teste.cad');
  });
}
