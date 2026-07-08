import '../../../../core/enums/suit.dart';
import '../../../../core/enums/card_value.dart';
import '../../../../core/enums/fuerza_2v2.dart';
import '../../../game/data/models/card_model.dart';

/// Una carta jugada por un jugador concreto (identificado por su asiento).
class CartaJugada2v2 {
  final int asiento;
  final CardModel carta;

  CartaJugada2v2({required this.asiento, required this.carta});
}

/// Motor de manos para el modo 2vs2.
///
/// Diferencias con el 1vs1:
///  - La carta máxima (la que NO arrastra) es la MALILLA (2 de lo virado).
///  - La fuerza de los triunfos usa Fuerza2v2 (malilla por encima del Rey).
class TrickEngine2v2 {
  /// En 2vs2 la carta máxima del triunfo es la malilla (el 2).
  static const CardValue maxima = CardValue.dos;

  /// Determina qué cartas puede jugar un jugador, según lo abierto en la baza.
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

    if (paloInicialBaza == paloVirado) {
      final triunfosQueArrastran = mano
          .where((c) => c.suit == paloVirado && c.value != maxima)
          .toList();

      if (triunfosQueArrastran.isNotEmpty) {
        final malilla = mano
            .where((c) => c.suit == paloVirado && c.value == maxima)
            .toList();
        return [...triunfosQueArrastran, ...malilla];
      }
      return mano;
    }

    // Sale un palo. Las cartas validas son el palo de salida MAS los
    // triunfos (palo virado); el jugador elige libremente entre ellos.
    final delPaloInicial =
        mano.where((c) => c.suit == paloInicialBaza).toList();
    if (delPaloInicial.isNotEmpty) {
      final triunfos = mano.where((c) => c.suit == paloVirado).toList();
      final set = <CardModel>{...delPaloInicial, ...triunfos};
      return set.toList();
    }
    // No tengo el palo de salida. Si mi EQUIPO ya va ganando la baza,
    // puedo tirar lo que quiera (jugar mal, sin montar triunfo).
    if (asiento >= 0 &&
        baza.isNotEmpty &&
        _miEquipoVaGanando(
            baza: baza, asiento: asiento, paloVirado: paloVirado,
            equipoDe: equipoDe)) {
      return mano;
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
    // Mi equipo no va ganando. Solo me obligan a montar con un triunfo
    // que SUPERE al que va ganando. Si no puedo superarlo, tiro libre.
    final lider = _cartaLider(baza, paloVirado);
    final puntLider = lider == null
        ? -1
        : _puntuacion(lider.carta, paloVirado, baza.first.carta.suit);
    final triunfos = mano.where((c) => c.suit == paloVirado).toList();
    final ganadores = triunfos.where((c) =>
        _puntuacion(c, paloVirado, baza.first.carta.suit) > puntLider).toList();
    if (ganadores.isNotEmpty) {
      return ganadores; // obligado a montar uno que gane
    }
    // No puedo superar al que va ganando: tiro libre.
    return mano;
  }

  // Puntuacion global de una carta para comparar en la baza (mayor=gana).
  static int _puntuacion(CardModel c, Suit paloVirado, Suit paloInicial) {
    if (c.suit == paloVirado) {
      return 500 + Fuerza2v2.comoTriunfo(c.value);
    }
    if (c.suit == paloInicial) {
      return 100 + Fuerza2v2.comoNoTriunfo(c.value);
    }
    return Fuerza2v2.comoNoTriunfo(c.value);
  }

  // Carta que va ganando la baza parcial (o null si esta vacia).
  static CartaJugada2v2? _cartaLider(List<CartaJugada2v2> baza, Suit paloVirado) {
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

  /// Va ganando la baza parcial el equipo del jugador en [asiento].
  /// ¿Queda algún COMPAÑERO de mi equipo por jugar todavía en esta baza?
  static bool _quedaCompaneroPorTirar({
    required List<CartaJugada2v2> baza,
    required int asiento,
    required int numJugadores,
    required int Function(int) equipoDe,
    required int Function(int) siguienteAsiento,
  }) {
    final faltanTrasMi = numJugadores - baza.length - 1;
    if (faltanTrasMi <= 0) return false;
    int a = siguienteAsiento(asiento);
    for (int i = 0; i < faltanTrasMi; i++) {
      if (equipoDe(a) == equipoDe(asiento)) return true;
      a = siguienteAsiento(a);
    }
    return false;
  }

  static bool _miEquipoVaGanando({
    required List<CartaJugada2v2> baza,
    required int asiento,
    int Function(int)? equipoDe,
    required Suit paloVirado,
  }) {
    if (baza.isEmpty) return false;
    final paloInicial = baza.first.carta.suit;
    CartaJugada2v2 lider = baza.first;
    for (final j in baza.skip(1)) {
      if (_esMejor(
        candidata: j.carta,
        actual: lider.carta,
        paloVirado: paloVirado,
        paloInicial: paloInicial,
      )) {
        lider = j;
      }
    }
    final eq = equipoDe ?? (int a) => a % 2;
    return eq(lider.asiento) == eq(asiento);
  }

  /// Determina quién gana una mano completa.
  static CartaJugada2v2 determinarGanador({
    required List<CartaJugada2v2> jugadas,
    required Suit paloVirado,
  }) {
    final paloInicial = jugadas.first.carta.suit;
    CartaJugada2v2 ganador = jugadas.first;

    for (final jugada in jugadas.skip(1)) {
      if (_esMejor(
        candidata: jugada.carta,
        actual: ganador.carta,
        paloVirado: paloVirado,
        paloInicial: paloInicial,
      )) {
        ganador = jugada;
      }
    }
    return ganador;
  }

  static bool _esMejor({
    required CardModel candidata,
    required CardModel actual,
    required Suit paloVirado,
    required Suit paloInicial,
  }) {
    final candidataEsTriunfo = candidata.suit == paloVirado;
    final actualEsTriunfo = actual.suit == paloVirado;

    if (candidataEsTriunfo && !actualEsTriunfo) return true;
    if (!candidataEsTriunfo && actualEsTriunfo) return false;

    if (candidataEsTriunfo && actualEsTriunfo) {
      return Fuerza2v2.comoTriunfo(candidata.value) >
          Fuerza2v2.comoTriunfo(actual.value);
    }

    final candidataSigue = candidata.suit == paloInicial;
    final actualSigue = actual.suit == paloInicial;

    if (candidataSigue && !actualSigue) return true;
    if (!candidataSigue && actualSigue) return false;
    if (candidataSigue && actualSigue) {
      return Fuerza2v2.comoNoTriunfo(candidata.value) >
          Fuerza2v2.comoNoTriunfo(actual.value);
    }

    return false;
  }
}