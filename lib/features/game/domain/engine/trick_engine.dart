import '../../../../core/enums/suit.dart';
import '../../../../core/enums/card_value.dart';
import '../../data/models/card_model.dart';

class PlayedCard {
  final String playerId;
  final CardModel card;

  PlayedCard({required this.playerId, required this.card});
}

class TrickEngine {
  /// La carta "máxima" de cada modalidad NO sirve para el arrastre
  /// (se puede guardar). En 1vs1 es el Rey de lo virado.
  /// (En otras modalidades será otra carta - se ajustará más adelante).
  static const CardValue maximaPorDefecto = CardValue.rey;

  /// Determina qué cartas son válidas para jugar dado lo que ya se jugó
  /// en la baza y la mano del jugador.
  static List<CardModel> cartasValidas({
    required List<CardModel> mano,
    required Suit? paloInicialBaza,
    required Suit paloDeLaMano,
    CardValue maxima = maximaPorDefecto,
  }) {
    if (paloInicialBaza == null) {
      // Es el primero en jugar, puede tirar lo que quiera
      return mano;
    }

    // Si se abrió la baza con triunfo (lo virado), hay arrastre:
    // se obliga a responder con triunfo si se tiene, EXCEPTO que
    // la carta máxima no cuenta para esta obligación (no arrastra).
    if (paloInicialBaza == paloDeLaMano) {
      final triunfosQueArrastran = mano
          .where((c) => c.suit == paloDeLaMano && c.value != maxima)
          .toList();

      if (triunfosQueArrastran.isNotEmpty) {
        final maximaTriunfo = mano
            .where((c) => c.suit == paloDeLaMano && c.value == maxima)
            .toList();
        return [...triunfosQueArrastran, ...maximaTriunfo];
      }

      // No tiene triunfos que arrastren (puede tener la máxima, o ninguno):
      return mano;
    }

    final delPaloInicial =
        mano.where((c) => c.suit == paloInicialBaza).toList();
    final delTriunfo =
        mano.where((c) => c.suit == paloDeLaMano).toList();

    final validas = <CardModel>{...delPaloInicial, ...delTriunfo}.toList();

    if (validas.isNotEmpty) {
      return validas;
    }

    // No tiene ni del palo inicial ni triunfo, puede jugar cualquiera
    return mano;
  }

  /// Determina el ganador de una baza ya completa.
  static PlayedCard determinarGanador({
    required List<PlayedCard> jugadas,
    required Suit paloDeLaMano,
  }) {
    final paloInicial = jugadas.first.card.suit;

    PlayedCard ganador = jugadas.first;

    for (final jugada in jugadas.skip(1)) {
      if (_esMejor(
        candidata: jugada.card,
        actual: ganador.card,
        paloDeLaMano: paloDeLaMano,
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
    required Suit paloDeLaMano,
    required Suit paloInicial,
  }) {
    final candidataEsTriunfo = candidata.suit == paloDeLaMano;
    final actualEsTriunfo = actual.suit == paloDeLaMano;

    if (candidataEsTriunfo && !actualEsTriunfo) return true;
    if (!candidataEsTriunfo && actualEsTriunfo) return false;

    if (candidataEsTriunfo && actualEsTriunfo) {
      return candidata.value.fuerza > actual.value.fuerza;
    }

    final candidataSigue = candidata.suit == paloInicial;
    final actualSigue = actual.suit == paloInicial;

    if (candidataSigue && !actualSigue) return true;
    if (!candidataSigue && actualSigue) return false;
    if (candidataSigue && actualSigue) {
      return candidata.value.fuerza > actual.value.fuerza;
    }

    return false;
  }
}
