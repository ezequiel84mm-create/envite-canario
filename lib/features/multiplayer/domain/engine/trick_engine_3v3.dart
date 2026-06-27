import '../../../../core/enums/suit.dart';
import '../../../../core/enums/card_value.dart';
import '../../../game/data/models/card_model.dart';
import 'trick_engine_2v2.dart' show CartaJugada2v2;

/// Motor de manos para el modo 3vs3.
///
/// Jerarquía especial (de mayor a menor):
///   1. 3 de bastos      (fija, NO arrastra: es la más alta)
///   2. caballo de bastos (fija, arrastra como triunfo)
///   3. sota de oros/Perica (fija, arrastra como triunfo)
///   4. malilla (2 del palo virado)
///   5. rey  > caballo > sota > as > 7 > 6 > 5 > 4 > 3 del palo virado
///   (no-triunfos: orden normal en su palo)
///
/// Las 3 fijas mandan SIEMPRE, aunque sean de otro palo. Cada carta
/// aparece una sola vez: si el palo virado es bastos u oros, las fijas
/// de ese palo NO se cuentan otra vez como triunfos normales.
class TrickEngine3v3 {
  // ¿Es la 3 de bastos? (la carta más alta; no arrastra)
  static bool esTresBastos(CardModel c) =>
      c.suit == Suit.bastos && c.value == CardValue.tres;

  // ¿Es alguna de las 3 cartas fijas?
  static bool esFija(CardModel c) {
    if (c.suit == Suit.bastos && c.value == CardValue.tres) return true;
    if (c.suit == Suit.bastos && c.value == CardValue.caballo) return true;
    if (c.suit == Suit.oros && c.value == CardValue.sota) return true;
    return false;
  }

  /// Puntuación global de una carta para comparar quién gana la baza.
  /// Mayor = más fuerte. Cartas que no compiten devuelven un valor bajo.
  /// Necesita el palo inicial de la baza para puntuar los no-triunfos.
  static int _puntuacion(CardModel c, Suit paloVirado, Suit paloInicial) {
    // Puestos fijos (los más altos de todo): 1000+.
    if (c.suit == Suit.bastos && c.value == CardValue.tres) return 1003;
    if (c.suit == Suit.bastos && c.value == CardValue.caballo) return 1002;
    if (c.suit == Suit.oros && c.value == CardValue.sota) return 1001;

    // Triunfos (palo virado), debajo de las fijas: 500+.
    if (c.suit == paloVirado) {
      return 500 + _fuerzaTriunfo(c.value);
    }

    // No-triunfo que sigue al palo inicial: 100+.
    if (c.suit == paloInicial) {
      return 100 + _fuerzaNormal(c.value);
    }

    // Carta de otro palo que no compite por la baza.
    return _fuerzaNormal(c.value);
  }

  // Fuerza dentro del triunfo (malilla la más alta). Las fijas que son
  // del palo virado NO usan esto (ya se puntúan arriba como fijas).
  static int _fuerzaTriunfo(CardValue v) {
    switch (v) {
      case CardValue.dos:
        return 11; // malilla
      case CardValue.rey:
        return 10;
      case CardValue.caballo:
        return 9;
      case CardValue.sota:
        return 8;
      case CardValue.uno:
        return 7;
      case CardValue.siete:
        return 6;
      case CardValue.seis:
        return 5;
      case CardValue.cinco:
        return 4;
      case CardValue.cuatro:
        return 3;
      case CardValue.tres:
        return 2;
    }
  }

  static int _fuerzaNormal(CardValue v) {
    switch (v) {
      case CardValue.rey:
        return 10;
      case CardValue.caballo:
        return 9;
      case CardValue.sota:
        return 8;
      case CardValue.uno:
        return 7;
      case CardValue.siete:
        return 6;
      case CardValue.seis:
        return 5;
      case CardValue.cinco:
        return 4;
      case CardValue.cuatro:
        return 3;
      case CardValue.tres:
        return 2;
      case CardValue.dos:
        return 1;
    }
  }

  /// Determina qué cartas puede jugar un jugador.
  /// Reglas:
  ///  - Si la baza está vacía (eres mano): cualquier carta.
  ///  - Prioridad 1: asistir al palo de salida si lo tienes.
  ///  - Si no tienes el palo: si tu equipo ya va ganando la baza,
  ///    puedes tirar libre; si no, debes montar triunfo/fija si tienes.
  ///  - La 3 de bastos NO sirve al arrastre: se puede guardar siempre.
  static List<CardModel> cartasValidas({
    required List<CardModel> mano,
    required Suit? paloInicialBaza,
    required Suit paloVirado,
    List<CartaJugada2v2> baza = const [],
    int asiento = -1,
  }) {
    if (paloInicialBaza == null) {
      return mano;
    }

    // Cartas "de triunfo" a efectos de arrastre: las del palo virado MÁS
    // las fijas (caballo bastos y perica), porque arrastran. La 3 de
    // bastos NO arrastra (se puede guardar).
    bool esTriunfoArrastre(CardModel c) {
      if (esTresBastos(c)) return false; // la más alta no arrastra
      if (c.suit == paloVirado) return true;
      if (c.suit == Suit.bastos && c.value == CardValue.caballo) return true;
      if (c.suit == Suit.oros && c.value == CardValue.sota) return true;
      return false;
    }

    // Caso arrastre de triunfo (la baza se abrió con triunfo o con una fija).
    final baseEsTriunfo = paloInicialBaza == paloVirado;
    if (baseEsTriunfo) {
      final triunfos = mano.where(esTriunfoArrastre).toList();
      if (triunfos.isNotEmpty) {
        // Puede jugar cualquier triunfo que arrastre; la 3 de bastos
        // (si la tiene) también es jugable pero no obligada.
        final tresBastos =
            mano.where(esTresBastos).toList();
        return [...triunfos, ...tresBastos];
      }
      return mano;
    }

    // Sale un palo que NO es triunfo. Las cartas validas son:
    //   palo de salida  +  triunfos (palo virado)  +  fijas.
    // El jugador elige libremente entre todas ellas.
    final delPaloInicial =
        mano.where((c) => c.suit == paloInicialBaza && !esFija(c)).toList();
    if (delPaloInicial.isNotEmpty) {
      final triunfosYFijas = mano.where((c) {
        if (esFija(c)) return true;
        if (c.suit == paloVirado) return true;
        return false;
      }).toList();
      final set = <CardModel>{...delPaloInicial, ...triunfosYFijas};
      return set.toList();
    }

    // No tengo el palo de salida.
    if (asiento >= 0 &&
        baza.isNotEmpty &&
        _miEquipoVaGanando(
            baza: baza, asiento: asiento, paloVirado: paloVirado)) {
      return mano; // mi equipo ya gana: puedo tirar libre
    }

    // Debo montar triunfo/fija que arrastre si tengo.
    final triunfos = mano.where(esTriunfoArrastre).toList();
    if (triunfos.isNotEmpty) {
      final tresBastos = mano.where(esTresBastos).toList();
      return [...triunfos, ...tresBastos];
    }

    // No tengo con qué arrastrar: tiro libre.
    return mano;
  }

  static bool _miEquipoVaGanando({
    required List<CartaJugada2v2> baza,
    required int asiento,
    required Suit paloVirado,
  }) {
    if (baza.isEmpty) return false;
    final paloInicial = baza.first.carta.suit;
    CartaJugada2v2 lider = baza.first;
    for (final j in baza.skip(1)) {
      final mejor = _puntuacion(j.carta, paloVirado, paloInicial) >
          _puntuacion(lider.carta, paloVirado, paloInicial);
      if (mejor) lider = j;
    }
    // Equipos en 3v3: asientos pares {0,2,4} vs impares {1,3,5}.
    return (lider.asiento % 2) == (asiento % 2);
  }

  /// Determina quién gana la baza completa.
  static CartaJugada2v2 determinarGanador({
    required List<CartaJugada2v2> jugadas,
    required Suit paloVirado,
  }) {
    final paloInicial = jugadas.first.carta.suit;
    CartaJugada2v2 ganador = jugadas.first;
    int mejor = _puntuacion(ganador.carta, paloVirado, paloInicial);
    for (final j in jugadas.skip(1)) {
      final p = _puntuacion(j.carta, paloVirado, paloInicial);
      if (p > mejor) {
        mejor = p;
        ganador = j;
      }
    }
    return ganador;
  }
}
