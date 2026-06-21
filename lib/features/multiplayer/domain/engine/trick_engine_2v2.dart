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

    final delPaloInicial =
        mano.where((c) => c.suit == paloInicialBaza).toList();
    final delTriunfo = mano.where((c) => c.suit == paloVirado).toList();
    final validas = <CardModel>{...delPaloInicial, ...delTriunfo}.toList();

    if (validas.isNotEmpty) {
      return validas;
    }

    return mano;
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