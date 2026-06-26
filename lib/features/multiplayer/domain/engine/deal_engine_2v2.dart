import '../../../../core/enums/suit.dart';
import '../../../../core/utils/deck_generator.dart';
import '../../../game/data/models/card_model.dart';

/// Resultado de un reparto de 2vs2: las manos de los 4 jugadores,
/// la carta virada (define el triunfo) y el mazo restante.
class Reparto2v2 {
  /// Manos por asiento: manos[0] es la mano del asiento 0, etc.
  final List<List<CardModel>> manos;

  /// La carta virada (boca arriba), define el palo de triunfo.
  final CardModel vira;

  /// Palo de triunfo (el de la vira).
  Suit get paloVirado => vira.suit;

  /// Cartas que quedan en el mazo tras repartir y voltear la vira.
  final List<CardModel> resto;

  Reparto2v2({
    required this.manos,
    required this.vira,
    required this.resto,
  });
}

/// Repartidor para el modo 2vs2.
class DealEngine2v2 {
  /// Número de jugadores en 2vs2.
  static const int numJugadores = 4;

  /// Cartas que recibe cada jugador.
  static const int cartasPorJugador = 3;

  /// Reparte una mano nueva de 2vs2.
  ///
  /// Da 3 cartas a cada uno de los 4 jugadores y voltea la siguiente
  /// carta como vira (triunfo).
  static Reparto2v2 repartir() {
    return repartirPara(numJugadores);
  }

  /// Reparte para [n] jugadores (4, 6 u 8 en el modo sala).
  /// Da 3 cartas a cada uno y voltea la vira.
  static Reparto2v2 repartirPara(int n) {
    final mazo = DeckGenerator.generateShuffledDeck();

    final manos = List.generate(n, (_) => <CardModel>[]);

    int indice = 0;
    for (int ronda = 0; ronda < cartasPorJugador; ronda++) {
      for (int asiento = 0; asiento < n; asiento++) {
        manos[asiento].add(mazo[indice]);
        indice++;
      }
    }

    final vira = mazo[indice];
    indice++;

    final resto = mazo.sublist(indice);

    return Reparto2v2(manos: manos, vira: vira, resto: resto);
  }
}