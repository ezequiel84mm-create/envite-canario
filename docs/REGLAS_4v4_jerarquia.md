# Jerarquía de cartas — Modo 4v4

De mayor a menor:
1. **5 de oros**       (fija, NO arrastra: la más alta de todas)
2. **3 de bastos**     (fija, NO arrastra)
3. **caballo de bastos** (fija, arrastra)
4. **perica / sota de oros** (fija, arrastra)
5. malilla (2 del palo virado)
6. rey > caballo > sota > as > 7 > 6 > 5 > 4 > 3 del palo virado
7. no-triunfos: orden normal en su palo

## Cartas fijas (detección por palo+valor absolutos)
- 5 de oros      = (oros, cinco)
- 3 de bastos    = (bastos, tres)
- caballo bastos = (bastos, caballo)
- perica         = (oros, sota)

Las 4 fijas mandan SIEMPRE, sea cual sea el palo virado, y aparecen una
sola vez (si vira oros, el 5 y la perica solo cuentan como fijas; si vira
bastos, el 3 y el caballo solo como fijas).

## Arrastre
- El **5 de oros** y el **3 de bastos** NO arrastran: se pueden guardar.
- El **caballo de bastos** y la **perica** SÍ arrastran (como triunfo).

## Puntuación interna del motor
- 5 oros = 1004, 3 bastos = 1003, caballo bastos = 1002, perica = 1001
- triunfos = 500 + fuerza (malilla=11 la más alta)
- palo inicial = 100 + fuerza ; otros = fuerza
