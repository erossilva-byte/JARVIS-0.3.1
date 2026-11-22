# Ajuste 024 — limite de bateria escolhível

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que faltava

O ajuste 023 fixou a redução da escuta em 15% de bateria. O usuário não podia escolher um
limite mais cedo (20%) nem mais tarde (10%), e o valor não aparecia na tela.

## O que foi feito

**`JarvisPrefs.java`**

- `LIMITES_BATERIA = { 10, 15, 20 }`; `limiteBateria()` devolve o escolhido ou 15% se o valor
  gravado não for um dos três (protege contra preferência antiga ou corrompida).

**`JarvisService.java`**

- `bloqueioBateria()` usa `JarvisPrefs.limiteBateria(c)` em vez da constante fixa; a mensagem
  da notificação cita o limite vigente ("bateria em 12% (limite 20%)").

**`JarvisBackgroundPlugin.java`**

- `definirPerfilEnergia` aceita `limiteBateria`; `estadoEnergia` e o diagnóstico devolvem
  `limiteBateria`.

**`perfil_energia.js` / `index.html` / `app.js`**

- Seletor "Reduzir a escuta com bateria em" com 10%, 15% (padrão) e 20%.
- O pedido só envia o limite quando há escolha; `normalizarLimite` recusa valor fora da lista
  e cai em 15% — a validação acontece antes de chamar o Android.
- O resumo mostra "Limite de redução: 15% de bateria."

## Evidência

| Verificação | Resultado |
|---|---|
| `node tests/test_perfil_energia.js` | exit 0, **20 verificações** |
| `npm run test:all` | **exit 0, suíte completa** |
| `python3 tests/test_empacotamento.py` | exit 0 |
| Normalização | "10" → 10; 20 → 20; 12 → 15; null → 15; "abc" → 15 |
| Pedido | limite enviado só quando escolhido; sem escolha, o serviço mantém o atual |
| Persistência no Java | lista 10/15/20 e leitura com fallback de 15% |
| Tela (360×740) | seletor de perfil 320×44 e de limite 320×44; sem rolagem lateral (360/360) |

## O que não foi verificado

- **Não compilado** e **não medido**: sem SDK e sem aparelho. O valor gravado e a mensagem da
  notificação só podem ser confirmados no Poco X7.
- O efeito do limite no consumo real de bateria continua pendente do teste de 8 horas.
