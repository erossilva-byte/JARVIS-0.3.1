# Medição no Poco X7 — abertura, fps e travadas (Fase 5, Gate B)

Campo em branco vale mais que número inventado. Se um cenário não puder ser medido, escreva
“não medido” e o motivo.

## Antes de medir

- [ ] Aparelho com **20–80% de bateria**, fora do carregador (carregando esquenta e derruba fps).
- [ ] Economia de bateria **desligada** e o app em “sem restrições” no HyperOS
      (Ajustes ▸ Apps ▸ J.A.R.V.I.S. Nova ▸ Economia de bateria ▸ Sem restrições).
- [ ] Anote a taxa de atualização configurada (60/90/120 Hz) e o brilho. Não mude no meio.
- [ ] Feche jogos, loja de apps e atualizações. Nada de gravação de tela durante a medição.
- [ ] **Anote se o APK é debug ou release.** Debug é bem mais lento; números de debug só servem
      para comparar com outra medição de debug. O artefato do CI hoje é debug; para número de
      produção, gere `flutter build apk --release`.

Confira o alvo antes de tudo:

```
adb devices
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell dumpsys package com.jarvis.nova | grep -E "versionName|versionCode"
adb shell settings get system peak_refresh_rate
```

Anote modelo, Android/HyperOS, versão do app, tipo de build e taxa de atualização.

## 1. Abertura fria

Cada execução parte do zero:

```
adb shell am force-stop com.jarvis.nova
adb shell am start -W -n com.jarvis.nova/.MainActivity
```

Repita **5 vezes**, com 5 segundos entre elas. A saída traz `ThisTime`, `TotalTime` e
`WaitTime`; use `TotalTime`.

- Descarte a primeira (instalação/JIT) e registre as outras quatro.
- Registre **mediana** e **pior caso**, não a média.

Meta provisória: `TotalTime` abaixo de **2 s** no release; abaixo de **4 s** no debug.
Ajuste a meta se o prompt mestre definir outro número — o que não pode é escolher a meta depois
de ver o resultado.

## 2. Abertura morna

Com o app já aberto, pressione Home e traga de volta:

```
adb shell input keyevent KEYCODE_HOME
adb shell am start -W -n com.jarvis.nova/.MainActivity
```

5 vezes, registre mediana e pior. Comparar fria × morna mostra se o custo está na inicialização
do Flutter ou no trabalho da primeira tela.

## 3. Quadros do núcleo animado (60 s parado na tela principal)

```
adb shell dumpsys gfxinfo com.jarvis.nova reset
# fique 60 s na tela principal, sem tocar em nada
adb shell dumpsys gfxinfo com.jarvis.nova > gfxinfo-nucleo.txt
```

No arquivo, registre:

| Campo do `gfxinfo` | O que significa |
|---|---|
| `Total frames rendered` | quantos quadros foram desenhados |
| `Janky frames` | quantos passaram do prazo — registre a **porcentagem** |
| `90th / 95th / 99th percentile` | tempo de quadro no percentil |
| `Number of slow frames` | travadas médias |
| `Number of frozen frames` | travadas graves |

Meta provisória: janky frames **abaixo de 5%** e p95 abaixo de **16,7 ms** (60 Hz) ou
**8,3 ms** (120 Hz).

## 4. Quadros durante uso real (60 s)

Mesmo comando, mas agora use o app: abra a conversa, role o histórico, abra e feche a gaveta,
volte, abra o modo voz e encerre.

```
adb shell dumpsys gfxinfo com.jarvis.nova reset
# 60 s de uso como acima
adb shell dumpsys gfxinfo com.jarvis.nova > gfxinfo-uso.txt
```

Registre os mesmos campos. Esse é o número que importa para “parece travado?”; o do item 3 é o
piso do app parado.

## 5. fps e tempo de quadro por camada

Primeiro descubra o nome da camada do app:

```
adb shell dumpsys SurfaceFlinger --list | grep com.jarvis.nova
```

Use o nome exato (normalmente `SurfaceView[com.jarvis.nova/com.jarvis.nova.MainActivity]#0`),
entre aspas:

```
adb shell dumpsys SurfaceFlinger --latency "SurfaceView[com.jarvis.nova/com.jarvis.nova.MainActivity]#0" > latencia.txt
```

O arquivo tem uma linha de cabeçalho e até 128 linhas com três números (ns). A coluna do meio é
o momento em que o quadro foi apresentado. Salve o trecho abaixo como `latencia.py` no computador
e rode sobre o arquivo coletado:

```python
import sys

tempos = []
for linha in sys.stdin:
    partes = linha.split()
    if len(partes) == 3 and partes[0].isdigit():
        ns = int(partes[1])
        if ns > 0:
            tempos.append(ns)
tempos.sort()

if len(tempos) > 2:
    janela = (tempos[-1] - tempos[0]) / 1e9
    fps = (len(tempos) - 1) / janela
    intervalos = sorted((b - a) / 1e6 for a, b in zip(tempos, tempos[1:]))
    p95 = intervalos[int(len(intervalos) * 0.95)]
    print(f"{len(tempos)} quadros em {janela:.2f} s → {fps:.1f} fps; p95 {p95:.1f} ms")
else:
    print("amostra insuficiente; repita com 60 s de uso")
```

```
python3 latencia.py < latencia.txt
```

Registre fps médio e p95. Repita no modo voz com a escuta ligada (o núcleo animado é o cenário
mais pesado da interface).

## 6. Modo voz com KWS escutando (60 s)

- [ ] Inicie a escuta, fique 60 s na tela de voz, repita os itens 3 e 5.
- [ ] Anote se o aparelho esquentou ou se o sistema mostrou aviso de consumo.
- [ ] Registre se o widget mudou de estado durante a escuta.

## Ficha para preencher

| Cenário | Medida | Valor | Meta | Observação |
|---|---|---|---|---|
| Abertura fria (4 execuções) | mediana / pior `TotalTime` | | ≤ 2 s (release) | |
| Abertura morna (5) | mediana / pior | | — | |
| Tela principal 60 s | janky % | | < 5% | |
| Tela principal 60 s | p95 quadro | | ≤ 16,7 ms (60 Hz) | |
| Uso real 60 s | janky % / p95 | | < 5% / ≤ 16,7 ms | |
| Uso real 60 s | fps médio (SurfaceFlinger) | | ≥ 55 fps | |
| Modo voz 60 s | janky % / fps / p95 | | < 5% / ≥ 55 fps | |
| Modo voz 60 s | temperatura/aviso do sistema | | — | |

## Como saber se o número é confiável

- Repita o mesmo cenário duas vezes. Se variar mais de 20%, refaça — provavelmente algo rodava
  em segundo plano.
- Meça sempre na mesma taxa de atualização e brilho.
- Números de debug e release **não se comparam**; registre o tipo de build em cada linha.
- Se o `gfxinfo` mostrar `Total frames rendered` muito baixo (menos de ~600 em 60 s), a tela ficou
  parada e o teste não mediu animação: refaça.

## Se algo travar ou fechar

```
adb logcat -d -s flutter:I AndroidRuntime:E ActivityManager:E > falha-medicao.txt
```

Junte o arquivo, o cenário e o horário. Sem isso, “travou” não vira correção.
