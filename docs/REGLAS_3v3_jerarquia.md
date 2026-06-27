# Jerarquía de cartas — Modo 3v3 (Envite canario)

Especificación para el motor del 3v3. Distinta del 2v2.

## Jerarquía completa (de mayor a menor)

### Cartas FIJAS (mandan SIEMPRE, sea cual sea el palo virado)
1. **3 de bastos** — la más alta de todas
2. **Caballo de bastos**
3. **Sota de oros (Perica)**

### Triunfos (cartas del palo virado)
4. **Malilla** = 2 del palo virado
5. **Rey** del palo virado
6. **Caballo** del palo virado
7. **Sota** del palo virado
8. **As** (1) del palo virado
9. **7** del palo virado
10. **6** del palo virado
11. **5** del palo virado
12. **4** del palo virado
13. **3** del palo virado

### No-triunfos (resto de palos)
Orden normal dentro de cada palo (de mayor a menor):
Rey, Caballo, Sota, As, 7, 6, 5, 4, 3, 2.
Una carta que siguió al palo inicial gana a otra de palo distinto que no
es ni triunfo ni del palo inicial.

## Regla de no-duplicado (IMPORTANTE)
Cada carta física aparece UNA sola vez en la jerarquía.

- Las 3 fijas (3 bastos, caballo bastos, perica) ocupan SIEMPRE los
  puestos 1-2-3, pase lo que pase.
- Si el palo virado es bastos: el 3 y el caballo de bastos NO se
  repiten entre los triunfos (ya están arriba como fijas). El resto de
  bastos (malilla, rey, sota, as, 7, 6, 5, 4) sí son triunfos normales.
- Si el palo virado es oros: la sota de oros (perica) NO se repite
  entre los triunfos. El resto de oros sí son triunfos normales.
- Si el palo virado es copas o espadas: las 3 fijas son de otros
  palos; mandan igual por encima de todo, y los triunfos de
  copas/espadas van completos debajo de la malilla.

## Regla de arrastre
Hay arrastre (obligación de asistir con triunfo). La UNICA carta que no
sirve al arrastre (se puede guardar) es la MAS ALTA del modo.

- 1v1: la más alta es el Rey de lo virado (no arrastra).
- 2v2: la más alta es la malilla (no arrastra).
- 3v3: la más alta es el 3 de bastos (no arrastra).

El caballo de bastos y la perica SI arrastran como triunfos normales.

## Cartas fijas (detección por palo+valor absolutos)
- 3 de bastos    = (bastos, tres)
- caballo bastos = (bastos, caballo)
- perica         = (oros, sota)

## Orden de evaluación de una carta
1. Es fija? -> puestos 1-3 (3 bastos > caballo bastos > perica)
2. Es triunfo (palo virado)? -> malilla > rey > caballo > sota > as > 7..3
3. Sigue al palo inicial? -> orden no-triunfo
4. Si no, no compite por la baza.

## 4v4
Pendiente: el usuario aclarará su jerarquía al llegar. De momento 4v4
hereda el motor 2v2.
