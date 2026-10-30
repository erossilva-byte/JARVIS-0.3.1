"""Personalidade 2.0 e auditoria de IA local."""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
css = texto('style.css')
doc = texto('MODELOS-IA-LOCAL.md')
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Persona ----------
checar('Persona define humor para respostas técnicas',
      'inclusive em pesquisa, explicação técnica, código, diagnóstico' in app)
checar('Persona exige variação de construção',
      'nunca repita a mesma construção' in app)
checar('Persona zera humor em assunto sensível',
      'o humor desaparece por completo' in app)
checar('Prompt manda humor na maioria das respostas',
      'O humor deve ser perceptível na maioria das respostas' in app)
checar('Proibição de copiar franquia preservada',
      'não copie falas, bordões ou diálogos dos filmes' in app)
checar('Tratamento personalizável preservado', '{tratamento}' in app)

# ---------- 2. Seis eixos configuráveis ----------
for k in ['sarcasmo', 'brincadeiras', 'ironia', 'espontaneidade', 'provocacao', 'formalidade']:
    checar('Eixo no HTML: ' + k, ('id="c-pers-%s"' % k) in html)
    checar('Eixo no padrão: ' + k, ('%s:' % k) in app)
    checar('Eixo persistido: ' + k, ("store.set('pers_' + k" in app) and ("store.get('pers_' + k" in app))
checar('Padrões favorecem humor', "sarcasmo: 80" in app and "ironia: 80" in app
      and "brincadeiras: 75" in app and "formalidade: 20" in app)
checar('Botão de restaurar padrão', 'id="c-pers-padrao"' in html and 'PERFIL_PADRAO[k]' in app)
checar('Calibragem entra no prompt', '${perfilHumor()}' in app)
checar('Formalidade muda o tom', 'frases medidas' in app and 'conversa solta' in app)
checar('Valores limitados a 0-100', 'Math.max(0, Math.min(100' in app)
checar('Humor padrão em 70', "store.get('humor', '70')" in app and 'value="70"' in html)

# ---------- 3. Interface ----------
checar('Bloco de ajuste fino presente', 'pers-controles' in html and '.pers-controles' in css)
checar('Sliders têm saída de valor', 'id="c-pers-sarcasmo-valor"' in html)
checar('Sem ids duplicados',
      len(re.findall(r'id="([^"]+)"', html)) == len(set(re.findall(r'id="([^"]+)"', html))))
checar('UI é ligada na carga', 'ligarPerfilNaUI();' in app)

# ---------- 4. Auditoria de IA local ----------
checar('Auditoria documentada', '## Auditoria de compatibilidade' in doc)
checar('Diz que nada foi medido', 'nenhum modelo foi carregado, executado ou medido' in doc)
checar('Separa estimativa de medição', 'estimativa' in doc.lower() and 'previsão' in doc.lower())
checar('Cita o aparelho de referência', 'Poco X7, 8 GB' in doc)
checar('Traz as quatro classificações',
      all(x in doc for x in ['COMPATÍVEL COM ADAPTAÇÕES', 'PARCIALMENTE COMPATÍVEL', 'INCOMPATÍVEL']))
checar('Explica que GGUF não carrega', 'GGUF' in doc and 'INCOMPATÍVEL' in doc)
checar('Registra a versão do motor', '0.10.24' in doc)

# ---------- 5. Suíte ----------
pkg = json.loads(texto('package.json'))
checar('Suíte roda este teste', 'python3 tests/test_personalidade_2.py' in pkg['scripts']['test:all'])

if falhas:
    print('\n%d verificação(ões) da personalidade 2.0 falharam.' % len(falhas))
    sys.exit(1)
print('Personalidade 2.0: persona, seis eixos e auditoria de IA local verificados.')
