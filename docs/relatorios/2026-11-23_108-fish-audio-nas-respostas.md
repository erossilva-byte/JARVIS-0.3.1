# 108 — Fish Audio nas respostas (2026-11-23)

## O que mudou

A tela **Voz externa (ID)** já existia e guardava o ID e a chave, mas a conversa
nunca pedia áudio ao Fish Audio: o JARVIS continuava falando só pela voz do
Android. Agora `FalaJarvis` fica entre a conversa e as duas vozes:

1. se a voz externa está **ligada**, gera o MP3 em `api.fish.audio/v1/tts` com
   `reference_id` no corpo e `Authorization: Bearer` no cabeçalho;
2. toca o MP3 pelo `MediaPlayer` do Android (`falarAudio`);
3. se faltar chave, a rede falhar, a cota acabar ou o aparelho não tocar,
   **cai para a voz local** em vez de ficar mudo, guardando o motivo em
   `ultimoErro`.

`parar()` interrompe as duas vozes — inclusive no gesto de virar o celular para
baixo. O botão de silenciar da conversa também para o MP3 externo, não só a
síntese local.

## Como configurar (sem colar chave em conversa)

1. Abra a gaveta → **Voz** → **Voz externa (ID)**.
2. No Fish Audio, copie o ID da voz clonada (`reference_id`) e cole em **ID de
   voz**; o padrão do projeto continua preenchido.
3. Em **Chave da API (Fish Audio)**, cole a chave criada em `fish.audio →
   API keys`. Ela vai para o `FlutterSecureStorage` e não volta para a tela.
4. Ligue **Usar esta voz nas respostas** e use **Testar voz**.

A chave é sua: o app não traz nem inventa credencial. Sem chave, o teste diz
que falta a chave e a voz do aparelho continua valendo.

## Verificação

- `flutter analyze` limpo; **396 testes** Flutter; **109/109** contratos.
- Sete testes novos de `FalaJarvis`: externa desligada, externa tocando, erro de
  chave/rede com volta para a voz local, MP3 que não toca, `parar()` nas duas
  vozes, texto vazio sem chamada e o retrato de configuração.
- Contrato passou a exigir a ponte e a ligação na conversa.

## Limites, sem rodeio

- **A chave não existe nesta sessão**: nenhuma chamada real ao Fish Audio foi
  feita, nenhum áudio foi ouvido e a qualidade da voz clonada não foi avaliada.
- Sem Android SDK, o `MediaPlayer`/`falarAudio` não foi compilado nem tocado em
  aparelho.
- A voz externa vale nas respostas da conversa; a fala de fundo do serviço em
  primeiro plano continua na voz do Android.
- O texto da resposta sai do aparelho quando a voz externa está ligada — o
  contrário da voz local. A tela avisa isso.
