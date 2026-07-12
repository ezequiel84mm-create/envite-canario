import '../../../../core/enums/suit.dart';
import '../../../../core/enums/card_value.dart';
import '../../../game/data/models/card_model.dart';
import 'trick_engine_2v2.dart' show CartaJugada2v2;

/// Motor de manos para el modo 4vs4.
///
/// Jerarquía (de mayor a menor):
///   1. 5 de oros        (fija, NO arrastra: la más alta de todas)
///   2. 3 de bastos      (fija, NO arrastra)
///   3. caballo de bastos (fija, arrastra)
///   4. sota de oros/Perica (fija, arrastra)
///   5. malilla (2 del palo virado)
///   6. rey > caballo > sota > as > 7..3 del palo virado
///   (no-triunfos: orden normal en su palo)
///
/// Las 4 fijas mandan SIEMPRE. El 5 de oros y el 3 de bastos NO arrastran
/// (se pueden guardar); el caballo de bastos y la perica sí arrastran.
class TrickEngine4v4 {
  static bool esCincoOros(CardModel c) =>
      c.suit == Suit.oros && c.value == CardValue.cinco;

  static bool esTresBastos(CardModel c) =>
      c.suit == Suit.bastos && c.value == CardValue.tres;

  // Las dos fijas que NO arrastran (se pueden guardar).
  static bool esFijaNoArrastra(CardModel c) =>
      esCincoOros(c) || esTresBastos(c);

  // ¿Es alguna de las 4 cartas fijas?
  static bool esFija(CardModel c) {
    if (c.suit == Suit.oros && c.value == CardValue.cinco) return true;
    if (c.suit == Suit.bastos && c.value == CardValue.tres) return true;
    if (c.suit == Suit.bastos && c.value == CardValue.caballo) return true;
    if (c.suit == Suit.oros && c.value == CardValue.sota) return true;
    return false;
  }

  static int _puntuacion(CardModel c, Suit paloVirado, Suit paloInicial) {
    // Fijas (las más altas de todo): 1000+.
    if (c.suit == Suit.oros && c.value == CardValue.cinco) return 1004;
    if (c.suit == Suit.bastos && c.value == CardValue.tres) return 1003;
    if (c.suit == Suit.bastos && c.value == CardValue.caballo) return 1002;
    if (c.suit == Suit.oros && c.value == CardValue.sota) return 1001;

    // Triunfos (palo virado): 500+.
    if (c.suit == paloVirado) {
      return 500 + _fuerzaTriunfo(c.value);
    }

    // No-triunfo que sigue al palo inicial: 100+.
    if (c.suit == paloInicial) {
      return 100 + _fuerzaNormal(c.value);
    }

    return _fuerzaNormal(c.value);
  }

  static int puntuacionPublica(CardModel c, Suit paloVirado, Suit paloInicial) =>
      _puntuacion(c, paloVirado, paloInicial);

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

  static List<CardModel> cartasValidas({
    required List<CardModel> mano,
    required Suit? paloInicialBaza,
    required Suit paloVirado,
    List<CartaJugada2v2> baza = const [],
    int asiento = -1,
    int Function(int)? equipoDe,
    int Function(int)? siguienteAsiento, // orden de juego (para saber quién falta)
    int numJugadores = 4,
  }) {
    if (paloInicialBaza == null) {
      return mano;
    }

    // Triunfos a efectos de arrastre: palo virado + fijas que arrastran
    // (caballo bastos y perica). Las fijas que NO arrastran (5 oros,
    // 3 bastos) se pueden guardar.
    bool esTriunfoArrastre(CardModel c) {
      if (esFijaNoArrastra(c)) return false;
      if (c.suit == paloVirado) return true;
      if (c.suit == Suit.bastos && c.value == CardValue.caballo) return true;
      if (c.suit == Suit.oros && c.value == CardValue.sota) return true;
      return false;
    }

    // La baza se abrió con triunfo O con una fija (aunque su palo natural no
    // sea el virado). Toda fija que sale de primera obliga a arrastrar. Las
    // más altas (5 oros / 3 bastos) siguen sin poder forzarse como asistencia
    // cuando arrastra otro (se pueden guardar); eso se resuelve más abajo con
    // esTriunfoArrastre.
    final cartaSalida = baza.isNotEmpty ? baza.first.carta : null;
    final baseEsTriunfo = paloInicialBaza == paloVirado ||
        (cartaSalida != null && esFija(cartaSalida));
    if (baseEsTriunfo) {
      final triunfos = mano.where(esTriunfoArrastre).toList();
      if (triunfos.isNotEmpty) {
        final libres = mano.where(esFijaNoArrastra).toList();
        return [...triunfos, ...libres];
      }
      return mano;
    }

    // Sale palo no-triunfo. Válidas = palo de salida + triunfos + fijas.
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
            baza: baza, asiento: asiento, paloVirado: paloVirado,
            equipoDe: equipoDe)) {
      return mano; // mi equipo ya gana: tiro libre
    }

    // Si todavía queda un COMPAÑERO por tirar detrás de mí en esta baza,
    // no estoy obligado a montar: puede ganar él. Tiro libre.
    if (asiento >= 0 &&
        equipoDe != null &&
        siguienteAsiento != null &&
        _quedaCompaneroPorTirar(
          baza: baza,
          asiento: asiento,
          numJugadores: numJugadores,
          equipoDe: equipoDe,
          siguienteAsiento: siguienteAsiento,
        )) {
      return mano;
    }

    // Montar solo si SUPERA al que va ganando.
    final lider = _cartaLider(baza, paloVirado);
    final puntLider = lider == null
        ? -1
        : _puntuacion(lider.carta, paloVirado, baza.first.carta.suit);
    final triunfos = mano.where(esTriunfoArrastre).toList();
    final libres = mano.where(esFijaNoArrastra).toList();
    final candidatos = [...triunfos, ...libres];
    final ganadores = candidatos.where((c) {
      return _puntuacion(c, paloVirado, baza.first.carta.suit) > puntLider;
    }).toList();
    if (ganadores.isNotEmpty) {
      return ganadores;
    }
    return mano;
  }

  static CartaJugada2v2? _cartaLider(
      List<CartaJugada2v2> baza, Suit paloVirado) {
    if (baza.isEmpty) return null;
    final paloInicial = baza.first.carta.suit;
    CartaJugada2v2 lider = baza.first;
    for (final j in baza.skip(1)) {
      if (_puntuacion(j.carta, paloVirado, paloInicial) >
          _puntuacion(lider.carta, paloVirado, paloInicial)) {
        lider = j;
      }
    }
    return lider;
  }

  /// ¿Queda algún COMPAÑERO de mi equipo por jugar todavía en esta baza?
  /// Recorre el orden de juego desde el siguiente asiento hasta completar la
  /// baza (numJugadores cartas). Si alguno de los que faltan es de mi equipo,
  /// no estoy obligado a montar: puede ganar él.
  static bool _quedaCompaneroPorTirar({
    required List<CartaJugada2v2> baza,
    required int asiento,
    required int numJugadores,
    required int Function(int) equipoDe,
    required int Function(int) siguienteAsiento,
  }) {
    // Cuántos faltan por tirar después de que yo juegue.
    final faltanTrasMi = numJugadores - baza.length - 1;
    if (faltanTrasMi <= 0) return false; // soy el último: nadie detrás

    int a = siguienteAsiento(asiento);
    for (int i = 0; i < faltanTrasMi; i++) {
      if (equipoDe(a) == equipoDe(asiento)) return true; // hay compañero detrás
      a = siguienteAsiento(a);
    }
    return false;
  }

  static bool _miEquipoVaGanando({
    required List<CartaJugada2v2> baza,
    required int asiento,
    required Suit paloVirado,
    int Function(int)? equipoDe,
  }) {
    if (baza.isEmpty) return false;
    final paloInicial = baza.first.carta.suit;
    CartaJugada2v2 lider = baza.first;
    for (final j in baza.skip(1)) {
      if (_puntuacion(j.carta, paloVirado, paloInicial) >
          _puntuacion(lider.carta, paloVirado, paloInicial)) {
        lider = j;
      }
    }
    final eq = equipoDe ?? ((int a) => a % 2);
    return eq(lider.asiento) == eq(asiento);
  }

  /// ¿La baza en curso ya está perdida para [equipo]? Es decir: la carta que
  /// va ganando pertenece al equipo rival y ninguna de las [cartasEquipo]
  /// (las que aún pueden jugar los miembros de [equipo] en esta baza) la
  /// supera. La IA lo usa para no cantar/subir de farol cuando la carta
  /// máxima ya está en la mesa del rival.
  static bool bazaPerdidaPara({
    required List<CartaJugada2v2> baza,
    required int equipo,
    required List<CardModel> cartasEquipo,
    required Suit paloVirado,
    required int Function(int) equipoDe,
  }) {
    final lider = _cartaLider(baza, paloVirado);
    if (lider == null) return false; // baza vacía: nada perdido
    if (equipoDe(lider.asiento) == equipo) return false; // vamos ganando
    final paloInicial = baza.first.carta.suit;
    final puntLider = _puntuacion(lider.carta, paloVirado, paloInicial);
    for (final c in cartasEquipo) {
      if (_puntuacion(c, paloVirado, paloInicial) > puntLider) {
        return false; // alguien de mi equipo aún puede superarla
      }
    }
    return true; // la carta ganadora es del rival y nadie de mi equipo la supera
  }

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
